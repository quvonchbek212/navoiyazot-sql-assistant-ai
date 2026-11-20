"""PostgreSQL ulanishi — faqat o'qish, connection pool bilan.

XAVFSIZLIK uch qatlamli:
  1. `sql_guard.ensure_read_only` — query bazaga bormasdan tekshiriladi;
  2. har bir query READ ONLY tranzaksiyada bajariladi — filtr aylanib
     o'tilsa ham PostgreSQL yozishni rad etadi (`25006` xatosi);
  3. bazadagi foydalanuvchining faqat SELECT huquqi.

NIMA UCHUN POOL KERAK (30.07.2026 o'lchovi, ATIL baza serveri):
    yangi ulanish ochish:   TCP 35%, PostgreSQL 60% muvaffaqiyat
    ochiq ulanishda so'rov: 15/15 = 100%
Ya'ni tarmoqda ulanish O'RNATISH beqaror, o'rnatilgan ulanish esa barqaror.
Har so'rovga yangi ulanish ochish bu tarmoqda eng yomon usul edi. Shuning uchun
ulanishlar pool'da ushlab turiladi, TCP keepalive yoqilgan va ulanish olishda
qayta urinish bor.
"""

from __future__ import annotations

import logging
import threading
import time
from contextlib import contextmanager
from typing import Any, Iterator

import psycopg2
import psycopg2.extras
from psycopg2 import pool as pg_pool

from config import (
    DB_CONNECT_TIMEOUT,
    DB_HOST,
    DB_NAME,
    DB_PASSWORD,
    DB_PORT,
    DB_READ_ONLY,
    DB_SCHEMA,
    DB_STATEMENT_TIMEOUT_MS,
    DB_USER,
    db_config_missing,
)

from .sql_guard import UnsafeSQLError, ensure_read_only

logger = logging.getLogger(__name__)

POOL_MIN = 1
POOL_MAX = 4

#: Ulanish olishda necha marta qayta urinish (tarmoq beqarorligi uchun).
#: DIQQAT: qayta urinish FAQAT shu yerda — `_ensure_pool` ichida takrorlanmaydi.
#: Aks holda urinishlar ko'payib ketadi: 3 (query) x 3 (pool) x 10s = 90s+.
CONNECT_RETRIES = 2
RETRY_BACKOFF_SECONDS = 0.8

#: Bitta run_query chaqiruvi uchun umumiy chegara.
#: 31.07.2026: chegara 25 s edi va uzilish paytida execute_sql 45 soniyagacha
#: cho'zilardi (pool qayta ochish urinishlari qo'shilib ketardi). Fonda
#: keepalive oqimi baribir ulanishni tiklaydi, shuning uchun foydalanuvchini
#: uzoq kuttirishning ma'nosi yo'q — tezroq "texnik nosozlik" deb aytib,
#: qayta so'rashni taklif qilgan afzal.
QUERY_DEADLINE_SECONDS = 12.0

_pool: pg_pool.ThreadedConnectionPool | None = None
_pool_lock = threading.Lock()


class DatabaseNotConfigured(RuntimeError):
    pass


def _connection_kwargs() -> dict[str, Any]:
    options = " ".join(
        part
        for part in (
            f"-c statement_timeout={DB_STATEMENT_TIMEOUT_MS}",
            f"-c search_path={DB_SCHEMA}",
            "-c default_transaction_read_only=on" if DB_READ_ONLY else "",
            "-c idle_in_transaction_session_timeout=30000",
        )
        if part
    )
    return {
        "host": DB_HOST,
        "port": DB_PORT,
        "dbname": DB_NAME,
        "user": DB_USER,
        "password": DB_PASSWORD,
        "connect_timeout": DB_CONNECT_TIMEOUT,
        "options": options,
        "application_name": "atil_chatbot",
        # TCP keepalive: ulanish bo'sh turganda tarmoq uni uzib yubormasin
        "keepalives": 1,
        "keepalives_idle": 30,
        "keepalives_interval": 5,
        "keepalives_count": 3,
    }


def _ensure_pool() -> pg_pool.ThreadedConnectionPool:
    global _pool
    missing = db_config_missing()
    if missing:
        raise DatabaseNotConfigured(
            f".env da baza sozlamalari to'ldirilmagan: {', '.join(missing)}"
        )

    with _pool_lock:
        if _pool is not None and not getattr(_pool, "closed", False):
            return _pool

        # Bitta urinish — qayta urinish yuqoridagi `run_query` da.
        _pool = pg_pool.ThreadedConnectionPool(POOL_MIN, POOL_MAX, **_connection_kwargs())
        logger.info("Baza pool ochildi (%d-%d ulanish)", POOL_MIN, POOL_MAX)
        return _pool


def _close_pool() -> None:
    global _pool
    with _pool_lock:
        if _pool is not None:
            try:
                _pool.closeall()
            except Exception:  # noqa: BLE001
                pass
            _pool = None


@contextmanager
def _borrow() -> Iterator[Any]:
    """Pool'dan ulanish oladi; buzilgan ulanishni pool'ga qaytarmaydi."""
    pool = _ensure_pool()
    conn = None
    broken = False
    try:
        conn = pool.getconn()
        if conn.closed:
            broken = True
            raise psycopg2.OperationalError("Pool'dagi ulanish yopilgan")
        yield conn
    except psycopg2.Error:
        broken = True
        raise
    finally:
        if conn is not None:
            try:
                if broken:
                    pool.putconn(conn, close=True)
                else:
                    conn.rollback()  # o'qish tranzaksiyasi — commit kerak emas
                    pool.putconn(conn)
            except Exception:  # noqa: BLE001
                try:
                    pool.putconn(conn, close=True)
                except Exception:  # noqa: BLE001
                    pass


def warmup() -> bool:
    """Pool'ni oldindan ochadi (startda va fonda chaqiriladi).

    Tarmoqdagi uzilishlar "portlash" ko'rinishida: bir necha o'n soniya
    ulanib bo'lmaydi, keyin yana ishlaydi. Foydalanuvchi savol berganda aynan
    o'sha oynaga tushib qolmasligi uchun pool fonda tirik ushlab turiladi.
    """
    try:
        with read_only_cursor() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
        return True
    except Exception as exc:  # noqa: BLE001 — fon vazifasi hech qachon otmasin
        logger.debug("Pool warmup muvaffaqiyatsiz: %s", str(exc).strip()[:120])
        return False


def start_keepalive(interval_seconds: int = 60) -> threading.Thread:
    """Fonda pool'ni tirik ushlab turadigan oqim."""

    def loop() -> None:
        while True:
            warmup()
            time.sleep(interval_seconds)

    thread = threading.Thread(target=loop, name="db-keepalive", daemon=True)
    thread.start()
    return thread


@contextmanager
def read_only_cursor() -> Iterator[Any]:
    """READ ONLY tranzaksiyadagi kursor (pool'dan)."""
    with _borrow() as conn:
        # DB_READ_ONLY eski sozlamada o'chirilgan bo'lsa ham, shu interfeys
        # har doim faqat o'qishi kerak. Pool ulanishida ham qayta o'rnatiladi.
        conn.set_session(readonly=True)
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            yield cur


def check_connection() -> dict[str, Any]:
    """Health-check: baza tirikmi, read-only rejim ishlayaptimi."""
    missing = db_config_missing()
    if missing:
        return {"database": "not_configured", "missing_env": missing}

    try:
        with read_only_cursor() as cur:
            cur.execute(
                "SELECT current_database() AS db, current_user AS usr, "
                "current_setting('transaction_read_only') AS read_only, "
                "current_setting('statement_timeout') AS stmt_timeout"
            )
            row = dict(cur.fetchone() or {})
            cur.execute(
                "SELECT count(*) AS n FROM pg_catalog.pg_class c "
                "JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace "
                "WHERE n.nspname = %s AND c.relkind IN ('r','p') "
                "AND has_table_privilege(c.oid, 'SELECT')",
                (DB_SCHEMA,),
            )
            row["tables_in_schema"] = (cur.fetchone() or {}).get("n")
        return {
            "database": "ok",
            "host": DB_HOST,
            "schema": DB_SCHEMA,
            "pool": f"{POOL_MIN}-{POOL_MAX}",
            **row,
        }
    except Exception as exc:  # noqa: BLE001 — health hech qachon 500 bermasin
        return {
            "database": "unreachable",
            "host": DB_HOST,
            "port": DB_PORT,
            "error": f"{type(exc).__name__}: {exc}".strip()[:400],
        }


def run_query(sql_query: str) -> dict[str, Any]:
    """Query'ni tekshirib bajaradi.

    Qaytadi:
        {"columns": [...], "rows": [...], "row_count": N}
        yoki xato bo'lsa {"error": "...", "error_type": "..."}
    """
    try:
        safe_sql = ensure_read_only(sql_query)
    except UnsafeSQLError as exc:
        logger.warning("SQL guard query'ni bloklad: %s", exc.reason)
        return {"error": exc.reason, "error_type": "unsafe_sql", "rows": [], "columns": []}

    last_error: dict[str, Any] | None = None
    deadline = time.monotonic() + QUERY_DEADLINE_SECONDS

    # Ulanish uzilib qolsa qayta urinamiz — SQL o'zgarmaydi, faqat ulanish yangilanadi
    for attempt in range(1, CONNECT_RETRIES + 1):
        if time.monotonic() > deadline and attempt > 1:
            logger.warning("run_query umumiy chegarasi (%.0fs) tugadi", QUERY_DEADLINE_SECONDS)
            break
        try:
            with read_only_cursor() as cur:
                cur.execute(safe_sql)
                rows = [dict(row) for row in cur.fetchall()]
                columns = [desc[0] for desc in (cur.description or [])]
            return {"columns": columns, "rows": rows, "row_count": len(rows)}

        except DatabaseNotConfigured as exc:
            return {"error": str(exc), "error_type": "not_configured", "rows": [], "columns": []}

        except psycopg2.errors.ReadOnlySqlTransaction as exc:  # type: ignore[attr-defined]
            # Guard aylanib o'tilgan bo'lsa ham baza to'sib qoldi — jiddiy signal
            logger.error("READ ONLY tranzaksiya yozuv amalini to'sdi: %s", exc)
            return {
                "error": "Yozuv amali bazada bloklandi (READ ONLY tranzaksiya).",
                "error_type": "read_only_violation",
                "rows": [],
                "columns": [],
            }

        except psycopg2.OperationalError as exc:
            # Ulanish muammosi — pool'ni tashlab qayta urinamiz
            message = str(exc).strip().splitlines()[0][:200]
            last_error = {
                "error": message,
                "error_type": "connection_error",
                "rows": [],
                "columns": [],
            }
            _close_pool()
            if attempt < CONNECT_RETRIES and time.monotonic() < deadline:
                delay = RETRY_BACKOFF_SECONDS * attempt
                logger.warning(
                    "Ulanish uzildi (%d/%d), %.1fs dan keyin qayta urinaman: %s",
                    attempt, CONNECT_RETRIES, delay, message,
                )
                time.sleep(delay)
                continue
            break

        except psycopg2.Error as exc:
            # SQL xatosi — qayta urinishning ma'nosi yo'q, model tuzatishi kerak
            message = (getattr(exc, "pgerror", None) or str(exc)).strip()
            logger.warning("SQL bajarilmadi: %s", message[:300])
            return {
                "error": message[:600],
                "error_type": getattr(getattr(exc, "diag", None), "sqlstate", None) or "sql_error",
                "rows": [],
                "columns": [],
            }

        except Exception as exc:  # noqa: BLE001
            logger.exception("Bazaga ulanishda kutilmagan xato")
            return {
                "error": f"{type(exc).__name__}: {exc}"[:400],
                "error_type": "connection_error",
                "rows": [],
                "columns": [],
            }

    return last_error or {
        "error": "Bazaga ulanib bo'lmadi.",
        "error_type": "connection_error",
        "rows": [],
        "columns": [],
    }
