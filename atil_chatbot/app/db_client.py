"""PostgreSQL bilan READ-ONLY aloqa qatlami.

Kafolatlar:
  * `lims-user` (read-only) bilan ulanadi.
  * Ulanishda libpq darajasida `default_transaction_read_only=on` va
    `statement_timeout` o'rnatiladi — hatto birinchi so'rov ham yoza olmaydi.
  * Faqat sanitize_select() dan o'tgan so'rov bajariladi.
  * Natijadagi maxfiy ustunlar (password, token, ...) NIQOBLANADI.
  * Natija JSON-xavfsiz turlarga keltiriladi (UUID/sana/Decimal → str/float).

Sinxron psycopg + thread-pool ishlatiladi (Windows/Linux'da barqaror; async
psycopg Windows ProactorEventLoop bilan mos emas).
"""
from __future__ import annotations

import datetime as dt
import decimal
import ipaddress
import logging
import json
import uuid
import time
from typing import Any

import anyio
import psycopg
from psycopg.rows import dict_row

from .config import Settings
from .domain import JSON_LARGE_OBJECT_COLUMNS
from .sql_guard import SqlNotAllowed, check_select, is_sensitive_column, wrap_count, wrap_limit

logger = logging.getLogger("db_client")

REDACTED = "***"
MAX_TEXT = 400  # natijadagi uzun matnlar (JSON, izohlar) shu uzunlikda kesiladi
MAX_NESTED_ITEMS = 100
MAX_DEPTH = 8
MAX_RESULT_BYTES = 1_000_000
MAX_JSON_OBJECT_BYTES = 100_000


def decode_json_object(data: bytes) -> Any:
    if len(data) > MAX_JSON_OBJECT_BYTES:
        raise ResultTooLarge("JSON obyekt juda katta; so'rovni toraytiring.")
    try:
        value = json.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError, RecursionError):
        raise ValueError("Obyekt xavfsiz JSON formatida emas") from None
    return jsonable(value)


class ResultTooLarge(ValueError):
    pass


class DataAccessUnavailable(PermissionError):
    """A required DB privilege is missing; rewriting SQL cannot restore it."""


def jsonable(value: Any, _depth: int = 0) -> Any:
    """Psycopg qaytargan qiymatni JSON-xavfsiz ko'rinishga keltiradi."""
    if _depth > MAX_DEPTH:
        raise ResultTooLarge("Natija ichma-ich tuzilishi juda chuqur.")
    if isinstance(value, str):
        if value.lstrip().startswith(("{", "[")):
            try:
                return jsonable(json.loads(value), _depth + 1)
            except (json.JSONDecodeError, RecursionError):
                # Malformed serialized data must not bypass nested redaction.
                return "<JSON ma'lumot o'qilmadi>"
        return value if len(value) <= MAX_TEXT else value[:MAX_TEXT] + "…"
    if value is None or isinstance(value, (int, float, bool)):
        return value
    if isinstance(value, decimal.Decimal):
        return float(value)
    if isinstance(value, (dt.datetime, dt.date, dt.time)):
        return value.isoformat()
    if isinstance(value, dt.timedelta):
        return str(value)
    if isinstance(value, uuid.UUID):
        return str(value)
    if isinstance(value, (bytes, bytearray, memoryview)):
        return f"<{len(bytes(value))} bayt>"
    if isinstance(value, (ipaddress.IPv4Address, ipaddress.IPv6Address)):
        return str(value)
    if isinstance(value, (list, tuple, set)):
        if len(value) > MAX_NESTED_ITEMS:
            raise ResultTooLarge("Ichki natija juda katta; so'rovni toraytiring.")
        return [jsonable(v, _depth + 1) for v in value]
    if isinstance(value, dict):
        if len(value) > MAX_NESTED_ITEMS:
            raise ResultTooLarge("Ichki natija ustunlari juda ko'p.")
        return {str(k): REDACTED if is_sensitive_column(str(k)) else jsonable(v, _depth + 1)
                for k, v in value.items()}
    return str(value)


class DbClient:
    def __init__(self, settings: Settings):
        self._s = settings
        self._catalog_cache = None
        self._catalog_loaded_at = 0.0

    def conn_kwargs(self, statement_timeout_ms: int | None = None) -> dict[str, Any]:
        timeout = int(statement_timeout_ms or self._s.statement_timeout_ms)
        opts = (
            f"-c default_transaction_read_only=on "
            f"-c statement_timeout={timeout} "
            f"-c idle_in_transaction_session_timeout={timeout} "
            "-c timezone=Asia/Tashkent "
            "-c search_path=pg_catalog"
        )
        return {
            "host": self._s.db_host,
            "port": self._s.db_port,
            "dbname": self._s.db_name,
            "user": self._s.db_user,
            "password": self._s.db_password,
            "options": opts,
            "connect_timeout": self._s.db_connect_timeout,
            "application_name": "atil-ai-assistant",
        }

    # ------------------- sinxron ichki metodlar -------------------
    def _ping_sync(self) -> bool:
        with psycopg.connect(**self.conn_kwargs()) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                cur.fetchone()
        return True

    def _introspect_sync(self) -> dict[str, list[tuple[str, str]]]:
        """Yengil introspeksiya (zaxira variant — ddl.sql bo'lmaganda)."""
        catalog = self._catalog_sync()
        return {name: [(c.name, c.type) for c in table.columns] for name, table in catalog.tables.items()}

    def _introspect_full_sync(self, with_counts: bool = True) -> dict[str, dict[str, Any]]:
        catalog = self._catalog_sync()
        tables = catalog.to_dict()["tables"]
        if with_counts:
            from psycopg import sql
            with psycopg.connect(**self.conn_kwargs(), autocommit=True) as conn:
                for name, meta in tables.items():
                    schema, table = name.split(".", 1) if "." in name else ("public", name)
                    try:
                        query = sql.SQL("SELECT count(*) FROM {}.{}").format(sql.Identifier(schema), sql.Identifier(table))
                        meta["rows"] = conn.execute(query).fetchone()[0]
                    except psycopg.Error:
                        meta["rows"] = None
        return tables

    def _count_sync(self, count_sql: str) -> int:
        count_sql = wrap_count(self._checked_sync(count_sql))
        with psycopg.connect(**self.conn_kwargs()) as conn:
            with conn.cursor() as cur:
                cur.execute(count_sql)  # type: ignore[arg-type]
                return int(cur.fetchone()[0])

    def _run_select_sync(self, safe_sql: str) -> dict[str, Any]:
        # Every caller, including future endpoints, crosses this boundary.
        safe_sql = wrap_limit(self._checked_sync(safe_sql), self._s.sql_row_limit + 1)
        with psycopg.connect(**self.conn_kwargs()) as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(safe_sql)  # type: ignore[arg-type]
                raw_rows = cur.fetchmany(self._s.sql_row_limit + 2)
                columns = [d.name for d in cur.description] if cur.description else []
                if len(columns) != len(set(columns)):
                    raise ValueError("Natija ustun taxalluslari takrorlanmas bo'lishi kerak")
                object_columns = []
                for index, description in enumerate(cur.description or []):
                    if description.type_code != 26:  # PostgreSQL oid
                        continue
                    origin = conn.execute(
                        "SELECT n.nspname,c.relname,a.attname FROM pg_class c "
                        "JOIN pg_namespace n ON n.oid=c.relnamespace "
                        "JOIN pg_attribute a ON a.attrelid=c.oid "
                        "WHERE c.oid=%s AND a.attnum=%s",
                        (cur.pgresult.ftable(index), cur.pgresult.ftablecol(index)),
                    ).fetchone()
                    if not origin or origin[0] != "public" or tuple(origin[1:]) not in JSON_LARGE_OBJECT_COLUMNS:
                        raise ValueError("Bu OID ustunni o'qish taqiqlangan")
                    object_columns.append(description.name)
            redacted = [c for c in columns if is_sensitive_column(c)]
            rows = []
            size = 0
            for row in raw_rows:
                for col in object_columns:
                    if row.get(col) is not None:
                        try:
                            data = conn.execute("SELECT pg_catalog.lo_get(%s::oid, 0, %s)",
                                                (row[col], MAX_JSON_OBJECT_BYTES + 1)).fetchone()[0]
                        except psycopg.errors.InsufficientPrivilege:
                            raise DataAccessUnavailable("JSON obyektni o'qish huquqi yetarli emas") from None
                        row[col] = decode_json_object(bytes(data))
                safe = {col: REDACTED if col in redacted else jsonable(value) for col, value in row.items()}
                size += len(json.dumps(safe, ensure_ascii=False, default=str).encode("utf-8"))
                if size > MAX_RESULT_BYTES:
                    raise ResultTooLarge("Natija hajmi juda katta; filtrlarni toraytiring.")
                rows.append(safe)
        return {"columns": columns, "rows": rows, "redacted_columns": redacted}

    # ------------------- async fasadlar -------------------
    async def ping(self) -> bool:
        return await anyio.to_thread.run_sync(self._ping_sync)

    async def introspect_schema(self) -> dict[str, list[tuple[str, str]]]:
        return await anyio.to_thread.run_sync(self._introspect_sync)

    def _catalog_sync(self):
        from atil_chatbot.tools.generate_ddl import introspect
        # Metadata has fixed SQL and can be slower than user SELECTs on a large
        # catalog. Keep its bounded timeout separate from the query budget.
        with psycopg.connect(**self.conn_kwargs(statement_timeout_ms=max(self._s.statement_timeout_ms, 60_000))) as conn:
            catalog = introspect(conn, self._s.include_schemas_list or ["public"])
        catalog.generated_at = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
        catalog.source = "live-metadata"
        self._catalog_cache = catalog
        self._catalog_loaded_at = time.monotonic()
        return catalog

    def _checked_sync(self, query: str) -> str:
        from .sql_validator import validate
        import sqlglot
        from sqlglot import exp
        from sqlglot.optimizer.scope import traverse_scope
        clean = check_select(query)
        catalog = self._catalog_cache
        if catalog is None or time.monotonic() - self._catalog_loaded_at > max(self._s.schema_refresh_seconds, 1):
            catalog = self._catalog_sync()
        problems = validate(clean, catalog)
        if problems:
            raise SqlNotAllowed("; ".join(problems))
        # Tables are explicit; function/operator lookup never falls back to an
        # application schema where a same-named overload could execute code.
        statement = sqlglot.parse_one(clean, dialect="postgres")
        for scope in traverse_scope(statement):
            for source in scope.sources.values():
                if isinstance(source, exp.Table) and source.name and not source.db:
                    source.set("db", exp.to_identifier("public"))
        return statement.sql(dialect="postgres")

    async def introspect_catalog(self):
        return await anyio.to_thread.run_sync(self._catalog_sync)

    async def introspect_full(self, with_counts: bool = True) -> dict[str, dict[str, Any]]:
        return await anyio.to_thread.run_sync(self._introspect_full_sync, with_counts)

    async def run_select(self, safe_sql: str) -> dict[str, Any]:
        return await anyio.to_thread.run_sync(self._run_select_sync, safe_sql)

    async def count(self, count_sql: str) -> int:
        return await anyio.to_thread.run_sync(self._count_sync, count_sql)
