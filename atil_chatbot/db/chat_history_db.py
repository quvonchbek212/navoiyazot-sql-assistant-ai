"""Suhbat tarixi bazasi — ALOHIDA PostgreSQL, yozishga ochiq.

Nima uchun alohida: ATIL bazasiga ulanish READ ONLY
(`default_transaction_read_only=on`) va foydalanuvchida faqat SELECT huquqi
bor — INSERT baza darajasida rad etiladi. Tarix uchun shu sababli boshqa
server (`CHAT_DB_*`) ishlatiladi.

`connect_db_for_server.py` dan farqlari:
  * bu yerda tranzaksiya YOZILADIGAN (read-only emas) va commit qilinadi;
  * `sslmode` sozlanadi — tarix serveri SSL muzokarasida ulanishni uzadi
    (10053 "connection abort"), shuning uchun sukut bo'yicha `disable`;
  * xatolar hech qachon yuqoriga otilmaydi: tarix yozilmagani foydalanuvchi
    javobini yo'qotishga arzimaydi, faqat log yoziladi.
"""

from __future__ import annotations

import logging
import queue
import threading
import time
from contextlib import contextmanager
from typing import Any, Iterator

import psycopg2
import psycopg2.extras
from psycopg2 import pool as pg_pool
from psycopg2 import sql as pg_sql

from config import (
    CHAT_DB_AUTO_CREATE,
    CHAT_DB_CONNECT_TIMEOUT,
    CHAT_DB_HOST,
    CHAT_DB_NAME,
    CHAT_DB_PASSWORD,
    CHAT_DB_PORT,
    CHAT_DB_SCHEMA,
    CHAT_DB_SSLMODE,
    CHAT_DB_STATEMENT_TIMEOUT_MS,
    CHAT_DB_TABLE,
    CHAT_DB_USER,
    chat_db_config_missing,
)

logger = logging.getLogger(__name__)

POOL_MIN = 1
POOL_MAX = 4

#: Pool'dan joy kutish muddati.
#: NIMA UCHUN KERAK: `psycopg2` pool'i bo'sh ulanish qolmaganda NAVBAT
#: KUTMAYDI — darhol "connection pool exhausted" xatosini otadi. FastAPI
#: sync endpointlarni threadpool'da (sukut bo'yicha 40 oqim) bajaradi, ya'ni
#: bir necha foydalanuvchi bir vaqtda savol berса yozuvlar JIMGINA yo'qolardi
#: (o'lchov: 8 oqimda 24 yozuvdan 15 tasi yo'qoldi). Semafor chaqiruvchini
#: navbatga qo'yadi; INSERT ~10 ms bo'lgani uchun kutish sezilmaydi.
SLOT_WAIT_SECONDS = 3.0
_slots = threading.Semaphore(POOL_MAX)

#: Ulanish OCHISHda necha marta urinish. Bu tarmoqda yangi ulanish ochish
#: beqaror (o'lchov: 1-3 urinish kerak bo'ladi), ochilgan ulanish esa barqaror —
#: shuning uchun qayta urinish faqat pool ochilayotgan paytda ma'noga ega.
CONNECT_RETRIES = 3
RETRY_BACKOFF_SECONDS = 0.4

_pool: pg_pool.ThreadedConnectionPool | None = None
_pool_lock = threading.Lock()

#: Jadval bir marta tekshiriladi/yaratiladi — har INSERT da emas.
_schema_ready = False
#: Ulanish uzilganda shu vaqtgacha bazaga umuman urinilmaydi.
#: NIMA UCHUN: bitta `/chat` tarixni 3-4 marta o'qiydi/yozadi. Baza yotganda
#: har urinish `connect_timeout` (~2 s) yeydi va foydalanuvchi javobi 6-8
#: soniyaga kechikadi — holbuki natija baribir xotiradagi nusxadan olinadi.
UNAVAILABLE_COOLDOWN_SECONDS = 30.0
_unavailable_until = 0.0

#: RLock, oddiy Lock EMAS: `ensure_schema` qulfni ushlab turib `_close_pool`
#: ni chaqiradi, u esa `_schema_ready` ni tozalash uchun o'sha qulfni yana
#: oladi. Oddiy Lock bilan bu o'z-o'zini bloklash (deadlock) edi.
_schema_lock = threading.RLock()


class ChatDatabaseNotConfigured(RuntimeError):
    pass


def is_configured() -> bool:
    return not chat_db_config_missing()


def _table() -> pg_sql.Composed:
    """Sxema.jadval — identifikatorlar `psycopg2.sql` bilan qochiriladi."""
    return pg_sql.SQL("{}.{}").format(
        pg_sql.Identifier(CHAT_DB_SCHEMA), pg_sql.Identifier(CHAT_DB_TABLE)
    )


def _connection_kwargs() -> dict[str, Any]:
    options = " ".join(
        (
            f"-c statement_timeout={CHAT_DB_STATEMENT_TIMEOUT_MS}",
            f"-c search_path={CHAT_DB_SCHEMA}",
            "-c idle_in_transaction_session_timeout=30000",
        )
    )
    return {
        "host": CHAT_DB_HOST,
        "port": CHAT_DB_PORT,
        "dbname": CHAT_DB_NAME,
        "user": CHAT_DB_USER,
        "password": CHAT_DB_PASSWORD,
        "connect_timeout": CHAT_DB_CONNECT_TIMEOUT,
        "sslmode": CHAT_DB_SSLMODE,
        "options": options,
        "application_name": "atil_chat_history",
        "keepalives": 1,
        "keepalives_idle": 30,
        "keepalives_interval": 5,
        "keepalives_count": 3,
    }


def _ensure_pool() -> pg_pool.ThreadedConnectionPool:
    global _pool
    missing = chat_db_config_missing()
    if missing:
        raise ChatDatabaseNotConfigured(
            f".env da tarix bazasi sozlamalari to'ldirilmagan: {', '.join(missing)}"
        )

    with _pool_lock:
        if _pool is not None and not getattr(_pool, "closed", False):
            return _pool
        _pool = pg_pool.ThreadedConnectionPool(POOL_MIN, POOL_MAX, **_connection_kwargs())
        logger.info(
            "Tarix bazasi pool ochildi (%s:%s/%s)", CHAT_DB_HOST, CHAT_DB_PORT, CHAT_DB_NAME
        )
        return _pool


def _close_pool() -> None:
    global _pool, _schema_ready, _unavailable_until
    _unavailable_until = time.monotonic() + UNAVAILABLE_COOLDOWN_SECONDS
    with _pool_lock:
        if _pool is not None:
            try:
                _pool.closeall()
            except Exception:  # noqa: BLE001
                pass
            _pool = None
    with _schema_lock:
        _schema_ready = False


class ChatHistoryBusy(RuntimeError):
    """Pool band va navbat kutish muddati tugadi."""


@contextmanager
def _cursor(commit: bool = False) -> Iterator[Any]:
    """Pool'dan kursor; buzilgan ulanish pool'ga qaytarilmaydi."""
    pool = _ensure_pool()
    if not _slots.acquire(timeout=SLOT_WAIT_SECONDS):
        # Navbat kutib bo'lmadi — javobni ushlab turgandan ko'ra tarixni
        # xotirada qoldirgan afzal.
        raise ChatHistoryBusy(f"tarix pool'i {SLOT_WAIT_SECONDS} s ichida bo'shamadi")
    conn = None
    broken = False
    try:
        conn = pool.getconn()
        if conn.closed:
            broken = True
            raise psycopg2.OperationalError("Pool'dagi ulanish yopilgan")
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            yield cur
        if commit:
            conn.commit()
        else:
            conn.rollback()
    except psycopg2.Error:
        broken = True
        if conn is not None:
            try:
                conn.rollback()
            except Exception:  # noqa: BLE001
                pass
        raise
    finally:
        if conn is not None:
            try:
                pool.putconn(conn, close=broken)
            except Exception:  # noqa: BLE001
                pass
        _slots.release()


@contextmanager
def write_cursor() -> Iterator[Any]:
    """Shu serverdagi BOSHQA jadvalga yozish uchun (`repair_assistant/log.py`).

    O'sha pool va semafor; baza yaqinda javob bermagan bo'lsa urinilmaydi,
    ulanish uzilsa pool yopiladi — tarix yozuvidagi bilan bir xil xulq.
    """
    if time.monotonic() < _unavailable_until:
        raise ChatHistoryBusy("tarix bazasi yaqinda javob bermadi")
    try:
        with _cursor(commit=True) as cur:
            yield cur
    except psycopg2.OperationalError:
        _close_pool()
        raise


def ensure_schema(force: bool = False) -> bool:
    """Jadval va indeksni yaratadi (bir marta). Muvaffaqiyatni qaytaradi."""
    global _schema_ready, _unavailable_until
    if _schema_ready and not force:
        return True
    if not is_configured():
        return False
    if not force and time.monotonic() < _unavailable_until:
        # Baza yaqinda javob bermadi — kutmasdan xotiradagi nusxaga o'tamiz.
        return False

    with _schema_lock:
        if _schema_ready and not force:
            return True

        if not CHAT_DB_AUTO_CREATE:
            # Jadval qo'lda yaratilgan deb hisoblaymiz — faqat mavjudligini tekshiramiz.
            try:
                with _cursor() as cur:
                    cur.execute(
                        "SELECT to_regclass(%s) AS t",
                        (f"{CHAT_DB_SCHEMA}.{CHAT_DB_TABLE}",),
                    )
                    exists = bool((cur.fetchone() or {}).get("t"))
                _schema_ready = exists
                if not exists:
                    logger.error(
                        "Tarix jadvali %s.%s topilmadi (CHAT_DB_AUTO_CREATE=false)",
                        CHAT_DB_SCHEMA,
                        CHAT_DB_TABLE,
                    )
                return exists
            except Exception as exc:  # noqa: BLE001
                logger.warning("Tarix jadvalini tekshirib bo'lmadi: %s", str(exc).strip()[:200])
                return False

        # Qayta urinish FAQAT `force` da (start/warmup). So'rov ichida esa
        # bitta urinish — aks holda baza yotganda foydalanuvchi 3 x
        # `connect_timeout` (~7 s) kutardi, natija baribir xotiradan olinadi.
        return _create_schema_with_retry(CONNECT_RETRIES if force else 1)


def _create_schema_with_retry(attempts: int = 1) -> bool:
    """Jadvalni yaratadi; ulanish ochilmasa `attempts` marta urinadi."""
    global _schema_ready, _unavailable_until

    for attempt in range(1, attempts + 1):
        try:
            with _cursor(commit=True) as cur:
                cur.execute(
                    pg_sql.SQL(
                        "CREATE TABLE IF NOT EXISTS {} ("
                        " id BIGSERIAL PRIMARY KEY,"
                        " session_id TEXT NOT NULL,"
                        " question TEXT NOT NULL,"
                        " answer TEXT NOT NULL,"
                        " route TEXT,"
                        " sql_query TEXT,"
                        " created_at TIMESTAMPTZ NOT NULL DEFAULT now()"
                        ")"
                    ).format(_table())
                )
                # Oxirgi N ta turni olish uchun: (session_id, id DESC)
                cur.execute(
                    pg_sql.SQL("CREATE INDEX IF NOT EXISTS {} ON {} (session_id, id DESC)").format(
                        pg_sql.Identifier(f"{CHAT_DB_TABLE}_session_id_idx"), _table()
                    )
                )
            _schema_ready = True
            _unavailable_until = 0.0
            logger.info("Tarix jadvali tayyor: %s.%s", CHAT_DB_SCHEMA, CHAT_DB_TABLE)
            return True
        except psycopg2.OperationalError as exc:
            _close_pool()
            if attempt < attempts:
                time.sleep(RETRY_BACKOFF_SECONDS * attempt)
                continue
            logger.warning(
                "Tarix bazasiga %d urinishda ham ulanib bo'lmadi: %s",
                attempts,
                str(exc).strip().splitlines()[0][:200],
            )
            return False
        except Exception as exc:  # noqa: BLE001
            logger.error("Tarix jadvalini yaratib bo'lmadi: %s", str(exc).strip()[:300])
            return False

    return False


#: Yozuv navbati. NIMA UCHUN FONDA:
#: tarix yozuvining foydalanuvchi javobiga aloqasi yo'q, lekin so'rov ichida
#: bajarilganda uni ~65-250 ms ushlab turadi va yuk ostida pool navbatiga
#: tushib qoladi (o'lchov: 40 oqimda 80 yozuvdan 13 tasi 3 s kutib yo'qoldi).
#: Navbatga qo'yish ~0 ms; yozuvni bitta fon oqimi ketma-ket bajaradi.
WRITE_QUEUE_MAXSIZE = 2000
#: `reset` fon navbati bo'shashini shuncha kutadi (tartib buzilmasligi uchun).
DELETE_WAIT_SECONDS = 5.0

_write_queue: queue.Queue = queue.Queue(maxsize=WRITE_QUEUE_MAXSIZE)
_writer_thread: threading.Thread | None = None
_writer_lock = threading.Lock()


def _writer_loop() -> None:
    while True:
        kind, payload, done = _write_queue.get()
        try:
            if kind == "insert":
                _write_turn(*payload)
            elif kind == "delete":
                _delete_session_now(payload)
        except Exception as exc:  # noqa: BLE001 — fon oqimi hech qachon o'lmasin
            logger.warning("Tarix fon yozuvi xatosi: %s", str(exc).strip()[:300])
        finally:
            if done is not None:
                done.set()
            _write_queue.task_done()


def _ensure_writer() -> None:
    global _writer_thread
    if _writer_thread is not None and _writer_thread.is_alive():
        return
    with _writer_lock:
        if _writer_thread is not None and _writer_thread.is_alive():
            return
        _writer_thread = threading.Thread(
            target=_writer_loop, name="chat-history-writer", daemon=True
        )
        _writer_thread.start()


def insert_turn(
    session_id: str,
    question: str,
    answer: str,
    route: str | None = None,
    sql_query: str | None = None,
) -> bool:
    """Savol-javobni yozuv navbatiga qo'yadi (bloklamaydi).

    `True` — navbatga tushdi (bazaga yozilishi keyinroq, fon oqimida).
    Navbat to'lib ketgan bo'lsa `False` — tarix xotirada qoladi.
    """
    if not session_id:
        return False
    _ensure_writer()
    try:
        _write_queue.put_nowait(("insert", (session_id, question, answer, route, sql_query), None))
        return True
    except queue.Full:
        logger.warning("Tarix navbati to'lib ketdi (%d) — yozuv tashlandi", WRITE_QUEUE_MAXSIZE)
        return False


def _write_turn(
    session_id: str,
    question: str,
    answer: str,
    route: str | None = None,
    sql_query: str | None = None,
) -> bool:
    """Haqiqiy INSERT — faqat fon oqimidan chaqiriladi."""
    if not ensure_schema():
        return False
    try:
        with _cursor(commit=True) as cur:
            cur.execute(
                pg_sql.SQL(
                    "INSERT INTO {} (session_id, question, answer, route, sql_query)"
                    " VALUES (%s, %s, %s, %s, %s)"
                ).format(_table()),
                (session_id, question or "", answer or "", route, sql_query),
            )
        return True
    except psycopg2.OperationalError as exc:
        _close_pool()
        logger.warning("Tarix yozilmadi (ulanish): %s", str(exc).strip().splitlines()[0][:200])
        return False
    except Exception as exc:  # noqa: BLE001 — tarix javobni buzmasin
        logger.warning("Tarix yozilmadi: %s", str(exc).strip()[:300])
        return False


def fetch_last_turns(session_id: str, limit: int) -> list[dict[str, str]] | None:
    """Oxirgi turlarni eskidan yangiga qarab qaytaradi.

    Xato bo'lsa `None` — chaqiruvchi xotiradagi nusxaga o'tishi uchun.
    Bo'sh ro'yxat esa "tarix yo'q" degani, bu boshqa holat.
    """
    if not session_id or not ensure_schema():
        return None
    try:
        with _cursor() as cur:
            cur.execute(
                pg_sql.SQL(
                    "SELECT question, answer FROM ("
                    " SELECT id, question, answer FROM {}"
                    " WHERE session_id = %s ORDER BY id DESC LIMIT %s"
                    ") AS oxirgi ORDER BY id ASC"
                ).format(_table()),
                (session_id, max(1, limit)),
            )
            rows = cur.fetchall()
        return [
            {"user_question": row["question"] or "", "assistant_answer": row["answer"] or ""}
            for row in rows
        ]
    except psycopg2.OperationalError as exc:
        _close_pool()
        logger.warning("Tarix o'qilmadi (ulanish): %s", str(exc).strip().splitlines()[0][:200])
        return None
    except Exception as exc:  # noqa: BLE001
        logger.warning("Tarix o'qilmadi: %s", str(exc).strip()[:300])
        return None


def delete_session(session_id: str) -> bool:
    """Sessiya tarixini bazadan o'chiradi.

    Navbat ORQALI boradi: aks holda hali yozilmagan savol-javoblar o'chirishdan
    keyin bazaga tushib, "tozalandi" degan sessiya yana tarixli bo'lib qolardi.
    Chaqiruvchi natijani ko'rishi kerak, shuning uchun bajarilishini kutamiz.
    """
    if not session_id:
        return False
    _ensure_writer()
    done = threading.Event()
    try:
        _write_queue.put_nowait(("delete", session_id, done))
    except queue.Full:
        logger.warning("Tarix navbati to'lib ketdi — o'chirish bajarilmadi")
        return False
    return done.wait(timeout=DELETE_WAIT_SECONDS)


def _delete_session_now(session_id: str) -> bool:
    """Haqiqiy DELETE — faqat fon oqimidan chaqiriladi."""
    if not ensure_schema():
        return False
    try:
        with _cursor(commit=True) as cur:
            cur.execute(
                pg_sql.SQL("DELETE FROM {} WHERE session_id = %s").format(_table()),
                (session_id,),
            )
        return True
    except psycopg2.OperationalError as exc:
        # `_close_pool` sovish oynasini yoqadi — bu shart. Usiz tarmoq
        # uzilganda pool o'lik ulanish tarqatishda davom etardi va har
        # o'chirish qaytadan `connect_timeout` yerdi.
        _close_pool()
        logger.warning("Tarix o'chirilmadi (ulanish): %s", str(exc).strip().splitlines()[0][:200])
        return False
    except Exception as exc:  # noqa: BLE001
        logger.warning("Tarix o'chirilmadi: %s", str(exc).strip()[:300])
        return False


def flush(timeout: float = 5.0) -> bool:
    """Navbatdagi yozuvlar bazaga tushishini kutadi (server o'chayotganda)."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if _write_queue.unfinished_tasks == 0:
            return True
        time.sleep(0.05)
    qoldi = _write_queue.unfinished_tasks
    if qoldi:
        logger.warning("Tarix navbatida %d yozuv qoldi (flush muddati tugadi)", qoldi)
    return qoldi == 0


def warmup() -> bool:
    """Pool'ni oldindan ochadi va jadvalni tayyorlaydi (start va keepalive)."""
    if not is_configured():
        return False
    # `force=True`: keepalive aynan sovish oynasini sindirib, bazani
    # tiklanganini tekshirish uchun chaqiriladi.
    return ensure_schema(force=True)


def check_connection() -> dict[str, Any]:
    """Health-check uchun tarix bazasining holati."""
    missing = chat_db_config_missing()
    if missing:
        return {"status": "not_configured", "missing_env": missing}

    try:
        with _cursor() as cur:
            cur.execute("SELECT current_database() AS db, current_user AS usr")
            row = dict(cur.fetchone() or {})
            cur.execute("SELECT to_regclass(%s) AS t", (f"{CHAT_DB_SCHEMA}.{CHAT_DB_TABLE}",))
            table_exists = bool((cur.fetchone() or {}).get("t"))
            row["table"] = f"{CHAT_DB_SCHEMA}.{CHAT_DB_TABLE}"
            row["table_exists"] = table_exists
            if table_exists:
                cur.execute(
                    pg_sql.SQL(
                        "SELECT count(*) AS saved_turns,"
                        " count(DISTINCT session_id) AS sessions FROM {}"
                    ).format(_table())
                )
                row.update(dict(cur.fetchone() or {}))
        return {"status": "ok", "host": CHAT_DB_HOST, **row}
    except Exception as exc:  # noqa: BLE001 — health hech qachon 500 bermasin
        return {
            "status": "unreachable",
            "host": CHAT_DB_HOST,
            "port": CHAT_DB_PORT,
            "error": f"{type(exc).__name__}: {exc}".strip()[:400],
        }
