"""Suhbat xotirasi — davomli savollar («ulardan qaysilari o'tgan oyda?») va savollar tarixi.

Ikki xil saqlash (bir xil interfeys: history / add / ping / close):
  * PgChatMemory — alohida PostgreSQL bazasi (CHAT_DB_*). LIMS bazasi READ-ONLY,
    shuning uchun tarix yozish huquqi bor boshqa bazaga yoziladi. HAR BIR savol
    (javob, SQL, yo'nalish, vaqt bilan) saqlanadi; kontekst uchun faqat
    muvaffaqiyatli `database` savollari o'qiladi.
  * ChatMemory — jarayon xotirasi (CHAT_DB_HOST bo'sh bo'lsa, testlar). Server
    qayta ishga tushsa tarix yo'qoladi.

Jadvallar (<prefix> = CHAT_DB_TABLE_PREFIX, standart `atil_chatbot`) birinchi
murojaatda o'zi yaratiladi:

    <prefix>_sessions   suhbat: id (= session_id), title, message_count, vaqtlar
    <prefix>_messages   bitta savol-javob — bitta satr

Samaradorlik:
  * Savol va javob BITTA satrda — satrlar ham, yozuvlar ham ikki barobar kam.
  * Yozuv — BITTA so'rov (CTE: sessiya upsert + xabar insert), bitta round-trip.
  * Kontekst — (session_id, id) indeksi bo'yicha LIMIT: jadval qancha o'smasin,
    bir necha sahifa o'qiladi.
  * created_at ustida BRIN indeks — vaqt oralig'i bo'yicha tahlil/tozalash uchun;
    jadval faqat qo'shiladi (vaqt tartibli), shuning uchun B-tree dan yuzlab
    marta kichik.
  * Ulanishlar puli: har so'rovda yangi ulanish ochilmaydi; min_size=0 — baza
    kerak bo'lmaguncha ulanish ham yo'q.
  * Natija satrlari SAQLANMAYDI (katta va maxfiy bo'lishi mumkin) — SQL yetarli.

Xotira bazasi ishlamasa chat to'xtamaydi: tarix bo'sh qaytadi, xato logga yoziladi
va keyingi RETRY_AFTER_SECONDS davomida bazaga murojaat qilinmaydi (so'rovlar kutmaydi).
"""
from __future__ import annotations

import json
import logging
import threading
import time
from collections import OrderedDict, deque
from dataclasses import dataclass, field
from typing import Any

import anyio
from psycopg import sql
from psycopg_pool import ConnectionPool

from .config import Settings

logger = logging.getLogger("memory")

MAX_TURNS = 4          # kontekst uchun olinadigan oxirgi savollar
MAX_SESSIONS = 2000    # jarayon xotirasi chegarasi (eng eskisi o'chiriladi)
TTL_SECONDS = 2 * 3600  # jarayon xotirasida shuncha vaqt faoliyatsiz sessiya o'chiriladi
TITLE_CHARS = 200      # sessiya sarlavhasi — birinchi savolning boshi

POOL_MAX = 5
POOL_TIMEOUT = 3.0     # puldan ulanish kutish (s): baza o'chiq bo'lsa chat uzoq kutmasin
STATEMENT_TIMEOUT_MS = 5000
RETRY_AFTER_SECONDS = 30  # baza javob bermasa shuncha vaqt murojaat qilinmaydi — har savol 3 s kutmasin


@dataclass(slots=True)
class Turn:
    """Bitta savol-javob."""
    question: str
    answer: str
    route: str
    sql: str | None = None
    row_count: int | None = None
    error: str | None = None
    duration_ms: int | None = None
    meta: dict[str, Any] = field(default_factory=dict)

    @property
    def is_context(self) -> bool:
        """Davomli savol uchun kontekst bo'la oladimi (muvaffaqiyatli SQL)."""
        return self.route == "database" and not self.error and bool(self.sql or self.meta.get("clarification"))


class ChatMemory:
    """Jarayon xotirasi: faqat kontekst uchun kerakli savollar saqlanadi."""

    backend = "process"

    def __init__(self) -> None:
        self._data: OrderedDict[str, tuple[float, deque[dict[str, Any]]]] = OrderedDict()
        self._lock = threading.Lock()

    def open(self) -> None:
        pass

    async def close(self) -> None:
        pass

    async def ping(self) -> bool:
        return True

    async def clear(self, session_id: str) -> None:
        with self._lock:
            self._data.pop(session_id, None)

    async def history(self, session_id: str | None) -> list[dict[str, Any]]:
        if not session_id:
            return []
        with self._lock:
            item = self._data.get(session_id)
            if item is None:
                return []
            ts, turns = item
            if time.monotonic() - ts > TTL_SECONDS:
                del self._data[session_id]
                return []
            return list(turns)

    async def add(self, session_id: str | None, turn: Turn) -> None:
        if not session_id or not turn.is_context:
            return
        with self._lock:
            _, turns = self._data.pop(session_id, (0.0, deque(maxlen=MAX_TURNS)))
            context = {"question": turn.question, "sql": turn.sql}
            if turn.meta.get("clarification"):
                context["clarification"] = turn.meta["clarification"]
            turns.append(context)
            self._data[session_id] = (time.monotonic(), turns)
            while len(self._data) > MAX_SESSIONS:
                self._data.popitem(last=False)


class PgChatMemory:
    """Suhbat tarixi alohida PostgreSQL bazasida (CHAT_DB_*)."""

    backend = "postgres"

    def __init__(self, settings: Settings) -> None:
        s = settings
        self._schema = s.chat_db_schema or "public"
        prefix = s.chat_db_table_prefix
        self._tables = [f"{prefix}_sessions", f"{prefix}_messages"]
        names = {
            "sessions": sql.Identifier(self._schema, self._tables[0]),
            "messages": sql.Identifier(self._schema, self._tables[1]),
            "session_idx": sql.Identifier(f"{prefix}_messages_session_idx"),
            "created_idx": sql.Identifier(f"{prefix}_messages_created_brin"),
        }

        self._ddl = [sql.SQL(q).format(**names) for q in (
            """
            CREATE TABLE IF NOT EXISTS {sessions} (
                id            text PRIMARY KEY,
                title         text NOT NULL,
                message_count integer NOT NULL DEFAULT 0,
                created_at    timestamptz NOT NULL DEFAULT now(),
                updated_at    timestamptz NOT NULL DEFAULT now()
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS {messages} (
                id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                session_id  text NOT NULL REFERENCES {sessions} (id) ON DELETE CASCADE,
                question    text NOT NULL,
                answer      text NOT NULL DEFAULT '',
                route       text NOT NULL,
                sql_query   text,
                row_count   integer,
                error       text,
                duration_ms integer,
                meta        jsonb NOT NULL DEFAULT '{{}}',
                created_at  timestamptz NOT NULL DEFAULT now()
            )
            """,
            # Kontekst o'qish va ON DELETE CASCADE shu indeks bilan ishlaydi.
            "CREATE INDEX IF NOT EXISTS {session_idx} ON {messages} (session_id, id)",
            # autosummarize — to'lgan sahifa oralig'i VACUUM kutmasdan indeksga qo'shiladi.
            "CREATE INDEX IF NOT EXISTS {created_idx} ON {messages} USING brin (created_at)"
            " WITH (autosummarize = on)",
        )]

        # Sessiya upsert + xabar insert — bitta so'rovda.
        self._q_add = sql.SQL("""
            WITH sess AS (
                INSERT INTO {sessions} AS t (id, title, message_count)
                VALUES (%(session_id)s, %(title)s, 1)
                ON CONFLICT (id) DO UPDATE
                    SET message_count = t.message_count + 1, updated_at = now()
                RETURNING id
            )
            INSERT INTO {messages}
                (session_id, question, answer, route, sql_query, row_count, error, duration_ms, meta)
            SELECT id, %(question)s, %(answer)s, %(route)s, %(sql)s, %(row_count)s,
                   %(error)s, %(duration_ms)s, %(meta)s::jsonb
            FROM sess
        """).format(**names)

        self._q_history = sql.SQL("""
            SELECT question, sql_query, meta->>'clarification' FROM {messages}
            WHERE session_id = %s AND route = 'database' AND error IS NULL
              AND (sql_query IS NOT NULL OR meta->>'clarification' IS NOT NULL)
            ORDER BY id DESC
            LIMIT %s
        """).format(**names)
        self._q_clear = sql.SQL("DELETE FROM {sessions} WHERE id = %s").format(**names)

        self._pool = ConnectionPool(
            kwargs={
                "host": s.chat_db_host,
                "port": s.chat_db_port,
                "dbname": s.chat_db_name,
                "user": s.chat_db_user,
                "password": s.chat_db_password,
                "sslmode": s.chat_db_sslmode,
                "connect_timeout": 5,
                "application_name": "atil-ai-memory",
                "options": f"-c statement_timeout={STATEMENT_TIMEOUT_MS}",
                # VPN/NAT bo'sh ulanishni jimgina uzmasin.
                "keepalives": 1,
                "keepalives_idle": 30,
                "keepalives_interval": 10,
                "keepalives_count": 3,
            },
            min_size=0,
            max_size=POOL_MAX,
            timeout=POOL_TIMEOUT,
            # Berishdan oldin tekshiradi (~1 ms): LLM javobini kutish paytida uzilgan
            # ulanish yozuvni yo'qotmaydi — tashlanadi va yangisi olinadi.
            check=ConnectionPool.check_connection,
            open=False,
            name="chat-memory",
        )
        self._ready = False
        self._init_lock = threading.Lock()
        self._down_until = 0.0  # monotonic: shu vaqtgacha baza ishlamayapti deb hisoblanadi

    # ------------------- hayot sikli -------------------
    def open(self) -> None:
        self._pool.open(wait=False)

    async def close(self) -> None:
        await anyio.to_thread.run_sync(self._pool.close)

    # ------------------- sinxron ichki metodlar -------------------
    def _ensure_schema(self) -> None:
        """Jadvallar yo'q bo'lsa yaratadi (jarayon davomida bir marta).

        Avval mavjudligi tekshiriladi: jadvallarni DBA oldindan yaratgan bo'lsa,
        foydalanuvchiga sxemada CREATE huquqi shart emas.
        """
        if self._ready:
            return
        with self._init_lock:
            if self._ready:
                return
            with self._pool.connection() as conn:
                found = conn.execute(
                    "SELECT count(*) FROM pg_tables WHERE schemaname = %s AND tablename = ANY(%s)",
                    (self._schema, self._tables),
                ).fetchone()[0]
                if found < len(self._tables):
                    # Bir nechta worker bir vaqtda ishga tushsa — bittasi yaratadi.
                    conn.execute("SELECT pg_advisory_xact_lock(hashtext(%s))", (".".join(self._tables),))
                    for stmt in self._ddl:
                        conn.execute(stmt)
                    logger.info("Suhbat xotirasi jadvallari yaratildi: %s.%s",
                                self._schema, ", ".join(self._tables))
            self._ready = True

    def _ping_sync(self) -> bool:
        self._ensure_schema()
        with self._pool.connection() as conn:
            conn.execute("SELECT 1")
        return True

    def _history_sync(self, session_id: str) -> list[dict[str, Any]]:
        self._ensure_schema()
        with self._pool.connection() as conn:
            rows = conn.execute(self._q_history, (session_id, MAX_TURNS)).fetchall()
        return [{"question": q, "sql": s, **({"clarification": c} if c else {})}
                for q, s, c in reversed(rows)]

    def _add_sync(self, session_id: str, turn: Turn) -> None:
        self._ensure_schema()
        params = {
            "session_id": session_id,
            "title": turn.question[:TITLE_CHARS],
            "question": turn.question,
            "answer": turn.answer,
            "route": turn.route,
            "sql": turn.sql,
            "row_count": turn.row_count,
            "error": turn.error,
            "duration_ms": turn.duration_ms,
            "meta": json.dumps(turn.meta, ensure_ascii=False, default=str),
        }
        with self._pool.connection() as conn:
            conn.execute(self._q_add, params)

    # ------------------- async fasadlar (xato chatni to'xtatmaydi) -------------------
    # Baza javob bermasa RETRY_AFTER_SECONDS davomida unga murojaat qilinmaydi (circuit
    # breaker): aks holda har bir savol tarixni o'qishda va yozishda POOL_TIMEOUT kutardi.
    def _down(self) -> bool:
        return time.monotonic() < self._down_until

    def _failed(self, what: str, exc: BaseException) -> None:
        self._down_until = time.monotonic() + RETRY_AFTER_SECONDS
        logger.warning("%s: %s — xotira bazasi %d s chetlab o'tiladi", what, exc, RETRY_AFTER_SECONDS)

    async def ping(self) -> bool:
        """Har doim haqiqatan tekshiradi (/healthz); muvaffaqiyat breaker'ni ochadi."""
        try:
            ok = await anyio.to_thread.run_sync(self._ping_sync)
        except Exception as exc:  # noqa: BLE001
            self._failed("Suhbat xotirasi bazasi ishlamayapti", exc)
            return False
        self._down_until = 0.0
        return ok

    async def history(self, session_id: str | None) -> list[dict[str, Any]]:
        if not session_id or self._down():
            return []
        try:
            return await anyio.to_thread.run_sync(self._history_sync, session_id)
        except Exception as exc:  # noqa: BLE001
            self._failed(f"Suhbat tarixi o'qilmadi ({session_id})", exc)
            return []

    def _clear_sync(self, session_id: str) -> None:
        self._ensure_schema()
        with self._pool.connection() as conn:
            conn.execute(self._q_clear, (session_id,))

    async def clear(self, session_id: str) -> None:
        await anyio.to_thread.run_sync(self._clear_sync, session_id)

    async def add(self, session_id: str | None, turn: Turn) -> None:
        if not session_id:
            return
        if self._down():
            logger.warning("Savol xotiraga yozilmadi (%s): xotira bazasi ishlamayapti", session_id)
            return
        try:
            await anyio.to_thread.run_sync(self._add_sync, session_id, turn)
        except Exception as exc:  # noqa: BLE001
            self._failed(f"Savol xotiraga yozilmadi ({session_id})", exc)


def create_memory(settings: Settings) -> ChatMemory | PgChatMemory:
    """CHAT_DB_* sozlangan bo'lsa — PostgreSQL, aks holda jarayon xotirasi."""
    if settings.chat_db_enabled:
        return PgChatMemory(settings)
    return ChatMemory()
