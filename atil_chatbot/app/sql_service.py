"""Text-to-SQL xizmati — savoldan xavfsiz SELECT yasab, read-only bazada bajaradi.

Quvur:
  1. TEZ YO'L — savol tekshirilgan katalog shabloniga aniq mos kelsa, SQL
     LLM'siz olinadi (sql_catalog.find_match).
  2. Aks holda: router tanlagan jadvallar + eng o'xshash 3 ta tekshirilgan
     misol + suhbat tarixi bilan LLM SQL yozadi.
  3. SQL bajarilishidan OLDIN: sql_guard (faqat o'qish) + sql_validator
     (jadval/ustun/qiymat sxemada bormi).
  4. Xato bo'lsa — model BITTA suhbat ichida qayta yozadi: u savolni, o'zining
     oldingi SQL ini va aniq xatoni ko'radi. Bir xil xato takrorlansa — to'xtaydi.
     Bazaga ULANIB bo'lmasa qayta urinilmaydi (SQL aybdor emas) — darhol xabar.
  5. Natija LIMIT+1 bilan olinadi: kesilgan bo'lsa (yoki modelning o'z LIMIT i
     to'lgan bo'lsa) jami son alohida hisoblanadi. Foydalanuvchiga ko'pi bilan
     ROWS_SHOWN (20) satr qaytadi; jami son va «Jami» qatori hamma satrdan.
"""
from __future__ import annotations

import datetime as dt
import logging
import re
from typing import Any

import psycopg
import sqlglot
from sqlglot import exp

from . import sql_catalog
from .answer_format import LIST_MAX
from .config import Settings
from .db_client import DataAccessUnavailable, DbClient
from .llm import LlmClient
from .prompts import DEFAULT_LANG, FIX_HINT, SQL_LANGUAGE_HINT, build_sql_system_prompt
from .schema_provider import SchemaProvider
from .sql_guard import SqlNotAllowed, additive_columns, check_select, split_limit
from .sql_validator import reference_filters, tables_in, validate

logger = logging.getLogger("sql_service")

SQL_MAX_TOKENS = 700  # bitta SELECT uchun yetarli; ortiqcha izoh yozishga yo'l qo'ymaydi
OWN_LIMIT_MIN = 10    # bundan kichik LIMIT — «top-N» savoli, jami son hisoblanmaydi
ROWS_SHOWN = LIST_MAX  # foydalanuvchiga qaytariladigan satrlar (jami va «Jami» qatori — hammasidan)

_SQL_FENCE = re.compile(r"```(?:sql)?\s*(.+?)```", re.IGNORECASE | re.DOTALL)
_SELECT_RE = re.compile(r"\b(WITH|SELECT)\b.*", re.IGNORECASE | re.DOTALL)
_CLARIFY_PREFIX = re.compile(r"^\s*SAVOL\s*:", re.IGNORECASE)
# Foydalanuvchi o'zi faqat faollarini so'rasa — ma'lumotnomaga is_active filtri to'g'ri.
_ACTIVE_RE = re.compile(r"faol|aktiv|active|актив|действ|ishlayotgan", re.IGNORECASE)
_TOTAL_COUNT_RE = re.compile(
    r"\b(?:jami|umumiy)\s+(?:nechta|qancha|soni|sonini)\b"
    r"|\btotal\s+(?:number|count)\b|\bhow many\b[^?]{0,160}\bin total\b"
    r"|\b(?:сколько\s+всего|всего\s+сколько|общее\s+количество)\b",
    re.IGNORECASE,
)
_BREAKDOWN_RE = re.compile(
    r"\b(?:kesimida|guruhlab)\b|\bhar bir\s+[\w']+(?:da|ga)\b"
    r"|\bhar bir\b[^?.;]{0,60}\b(?:uchun|bo'yicha)\b"
    r"|\b(?:for each|per|для каждого|по каждой|по каждому)\b",
    re.IGNORECASE,
)


def _scalar_total_sql(clean: str, question: str) -> str:
    """Collapse a per-key 0/1 DISTINCT count only when one total is requested.

    COUNT(DISTINCT key) GROUP BY key is 1 for each non-NULL key and 0 for
    the NULL group. Summing those counts preserves WHERE/HAVING, excludes
    NULL keys and returns 0 when no groups qualify. Labeled breakdowns,
    other metrics and limited queries retain their original SQL.
    """
    question = sql_catalog.normalize(question)
    if not _TOTAL_COUNT_RE.search(question) or _BREAKDOWN_RE.search(question):
        return clean
    stmt = sqlglot.parse_one(clean, dialect="postgres")
    if not isinstance(stmt, exp.Select) or len(stmt.expressions) != 1:
        return clean
    group = stmt.args.get("group")
    if group is None or len(group.expressions) != 1 or any(
        stmt.args.get(key) is not None for key in ("distinct", "limit", "offset", "qualify", "windows")
    ):
        return clean
    projection = stmt.expressions[0]
    count = projection.this if isinstance(projection, exp.Alias) else projection
    if not isinstance(count, exp.Count) or not isinstance(count.this, exp.Distinct):
        return clean
    keys = count.this.expressions
    key = group.expressions[0]
    if len(keys) != 1 or not isinstance(keys[0], exp.Column) or not isinstance(key, exp.Column):
        return clean
    counted = keys[0]
    if key.name != counted.name or (key.table and counted.table and key.table != counted.table):
        return clean
    # ROLLUP/CUBE/GROUPING SETS produce extra subtotal groups; do not collapse them.
    if any(value for name, value in group.args.items() if name != "expressions"):
        return clean
    inner = stmt.copy()
    inner.set("expressions", [count.copy().as_("_group_count")])
    inner.set("order", None)
    total = exp.cast(exp.func("COALESCE", exp.func("SUM", exp.column(
        "_group_count", table="_count_groups",
    )), exp.Literal.number(0)), "BIGINT")
    if isinstance(projection, exp.Alias):
        total = exp.Alias(this=total, alias=projection.args["alias"].copy())
    else:
        total = total.as_("jami_soni")
    return exp.select(total).from_(inner.subquery("_count_groups")).sql(dialect="postgres")


def extract_sql(text: str) -> tuple[str | None, str | None]:
    """Model javobidan (sql, aniqlashtiruvchi_savol) ajratadi."""
    if not text:
        return None, None
    s = text.strip()
    if _CLARIFY_PREFIX.match(s):
        return None, _CLARIFY_PREFIX.sub("", s, count=1).strip()
    m = _SQL_FENCE.search(s)
    if m:
        return m.group(1).strip(), None
    m2 = _SELECT_RE.search(s)
    if m2:
        return m2.group(0).strip(), None
    return None, s


DB_UNAVAILABLE = "Bazaga ulanib bo'lmadi"

# Baza Asia/Tashkent vaqtida (CURRENT_DATE). Server (Docker) UTC da bo'lishi mumkin —
# promptdagi «bugungi sana» bazadagi bilan bir xil bo'lsin. O'zbekistonda yozgi vaqt yo'q.
TASHKENT = dt.timezone(dt.timedelta(hours=5))


def _own_limit_filled(clean: str, n_rows: int, question: str) -> str | None:
    """Model o'zi qo'ygan LIMIT to'lgan bo'lsa — jami sonni hisoblash uchun LIMIT siz so'rov.

    «Chetlanishlar ro'yxati» → LIMIT 100 → 100 ta satr: bu jami son EMAS, foydalanuvchiga
    «jami 100 ta» deyilmasin. Kichik yoki savolda so'ralgan LIMIT (top-5, «oxirgi 20 ta») —
    foydalanuvchining o'z niyati, hisoblanmaydi.
    """
    split = split_limit(clean)
    if split is None:
        return None
    n, unlimited = split
    if n_rows != n or n <= OWN_LIMIT_MIN or str(n) in re.findall(r"\d+", question):
        return None
    return unlimited


def _totals(clean: str, columns: list[str], rows: list[dict[str, Any]]) -> dict[str, Any]:
    """Guruhlangan sanoq/yig'indi ustunlari bo'yicha jami — «Shu oy jami 156 ta tahlil».

    LLM ga qo'shish taqiqlangan (son o'ylab topmasin), shuning uchun jamini kod hisoblaydi.
    """
    by_name = {c.lower(): c for c in columns}
    totals: dict[str, Any] = {}
    for name in additive_columns(clean):
        col = by_name.get(name.lower())
        values = [r.get(col) for r in rows] if col else []
        if values and all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in values):
            totals[col] = sum(values)
    return totals


def _fail(result: dict[str, Any], error: str, kind: str) -> dict[str, Any]:
    """error — texnik sabab (log, xotira); kind — foydalanuvchiga qaysi xabar (prompts.MESSAGES):
    db_unavailable / service_error / not_understood."""
    result["error"] = error
    result["error_kind"] = kind
    return result


def is_connection_error(exc: BaseException) -> bool:
    """Bazaga ULANISH xatosi (SQL xatosi emas) — SQL ni qayta yozdirish foyda bermaydi.

    SQLSTATE yo'q (ulanish timeout/rad etildi/uzildi), 08xxx (connection exception)
    yoki 57P0x (server to'xtatilmoqda). 57014 (statement_timeout) bunga KIRMAYDI —
    u holda model tezroq SQL yozib ko'rishi mumkin.
    """
    if not isinstance(exc, psycopg.OperationalError):
        return False
    return exc.sqlstate is None or exc.sqlstate.startswith(("08", "57P"))


def _db_unavailable(result: dict[str, Any], exc: BaseException) -> dict[str, Any]:
    logger.warning("Bazaga ulanib bo'lmadi, qayta urinilmaydi: %s", exc)
    result.update(sql=None, columns=[], rows=[], row_count=0, total_count=None, truncated=False)
    return _fail(result, DB_UNAVAILABLE, "db_unavailable")


def history_block(history: list[dict[str, Any]] | None) -> str:
    """Oldingi savol-javoblar (davomli savollar uchun: «ulardan qaysilari ...»)."""
    if not history:
        return ""
    lines = ["OLDINGI SUHBAT (joriy savol shunga tayanishi mumkin):"]
    for turn in history[-4:]:
        lines.append(f"- Savol: {turn.get('question', '')}")
        if turn.get("sql"):
            lines.append(f"  SQL: {' '.join(str(turn['sql']).split())}")
        if turn.get("clarification"):
            lines.append(f"  Aniqlashtiruvchi savol: {turn['clarification']}")
    return "\n".join(lines) + "\n\n"


class SqlService:
    def __init__(
        self,
        settings: Settings,
        llm: LlmClient,
        db: DbClient,
        schema_provider: SchemaProvider | None = None,
    ):
        self._s = settings
        self._llm = llm
        self._db = db
        self._schema = schema_provider or SchemaProvider(settings, db)

    async def run(
        self,
        question: str,
        tables: list[str] | None = None,
        history: list[dict[str, Any]] | None = None,
        lang: str = DEFAULT_LANG,
    ) -> dict[str, Any]:
        """{sql, columns, rows, row_count, total_count, truncated, clarify, error, warnings, ...}

        lang — javob tili: ustun taxalluslari (ro'yxat sarlavhalari) va aniqlashtiruvchi savol shu tilda.
        """
        result: dict[str, Any] = {
            "sql": None, "columns": [], "rows": [], "row_count": 0, "total_count": None,
            "truncated": False, "totals": {}, "clarify": None, "error": None, "error_kind": None, "warnings": [],
            "schema_source": None, "attempts": 0, "fast_path": False, "tables": [],
        }

        # 1) Tez yo'l — tekshirilgan shablon (taxalluslari o'zbekcha — faqat uz javob uchun).
        entry = sql_catalog.find_match(question) if not history and lang == DEFAULT_LANG else None
        if entry is not None:
            try:
                await self._execute(entry.sql, result, question)
                result["fast_path"] = True
                result["tables"] = list(entry.tables)
                return result
            except Exception as exc:  # noqa: BLE001 — sxema o'zgargan bo'lishi mumkin: LLM ga o'tamiz
                if isinstance(exc, (DataAccessUnavailable, psycopg.errors.InsufficientPrivilege)):
                    return _fail(result, "So'ralgan ma'lumotni o'qish huquqi yetarli emas", "data_access_unavailable")
                if is_connection_error(exc):
                    return _db_unavailable(result, exc)
                logger.warning("Katalog shabloni ishlamadi (%s): %s", entry.question, exc)
                result.update(sql=None, columns=[], rows=[], row_count=0, total_count=None, truncated=False,
                              totals={})

        # 2) LLM bilan.
        examples = sql_catalog.similar(question, 3)
        try:
            bundle = await self._schema.bundle(
                question, tables, extra=[t for e in examples for t in e.tables]
            )
            catalog = await self._schema.catalog()
        except Exception as exc:  # noqa: BLE001
            logger.warning("Sxema olinmadi: %s", exc)
            return _fail(result, f"Baza sxemasini olib bo'lmadi: {exc}", "service_error")
        result["schema_source"] = bundle.source
        result["tables"] = bundle.tables

        system = build_sql_system_prompt(
            bundle.text, dt.datetime.now(TASHKENT).date().isoformat(), [(e.question, e.sql) for e in examples]
        )
        messages: list[dict[str, str]] = [
            {"role": "system", "content": system},
            {"role": "user", "content": history_block(history) + f"Savol: {question}"
                                        + SQL_LANGUAGE_HINT.get(lang, "")},
        ]
        last_error: str | None = None
        # «Yumshoq» tekshiruv (ma'lumotnomaga faol-filtr): model bir marta tuzatadi; takrorlasa ham
        # SQL bajariladi — javobsiz qolgandan ko'ra shu yaxshi.
        soft_checked = bool(_ACTIVE_RE.search(question))

        for attempt in range(1, self._s.max_sql_attempts + 1):
            result["attempts"] = attempt
            try:
                raw = await self._llm.chat_messages(messages, temperature=0, max_tokens=SQL_MAX_TOKENS)
            except Exception as exc:  # noqa: BLE001
                logger.exception("LLM xatosi")
                return _fail(result, f"Model bilan aloqa xatosi: {exc}", "service_error")

            sql, clarify = extract_sql(raw)
            if sql is None:
                result["clarify"] = clarify or raw
                return result

            error, extra = await self._check(sql, catalog, bundle.tables, question)
            if error is None and not soft_checked:
                soft_checked = True
                if soft := reference_filters(sql):
                    error = "\n".join(f"- {p}" for p in soft)
            if error is None:
                try:
                    await self._execute(sql, result, question)
                    return result
                except Exception as exc:  # noqa: BLE001
                    if isinstance(exc, (DataAccessUnavailable, psycopg.errors.InsufficientPrivilege)):
                        return _fail(result, "So'ralgan ma'lumotni o'qish huquqi yetarli emas", "data_access_unavailable")
                    if is_connection_error(exc):
                        return _db_unavailable(result, exc)
                    error = f"Baza xatosi: {str(exc).strip().splitlines()[0]}"

            logger.info("SQL rad etildi (urinish %d): %s", attempt, error)
            if error == last_error:
                break  # model bir xil xatoni takrorlayapti — foydasiz
            last_error = error
            messages += [
                {"role": "assistant", "content": raw},
                {"role": "user", "content": FIX_HINT.format(error=error, extra=extra)},
            ]

        return _fail(result, f"To'g'ri SQL shakllantirib bo'lmadi. Oxirgi sabab: {last_error}",
                     "not_understood")

    async def _check(self, sql: str, catalog, bundle_tables: list[str], question: str = "") -> tuple[str | None, str]:
        """(xato matni yoki None, modelga qo'shimcha sxema)."""
        try:
            clean = check_select(sql)
        except SqlNotAllowed as exc:
            return str(exc), ""
        problems = validate(clean, catalog, question)
        if not problems:
            return None, ""
        # Model promptda bo'lmagan jadvalni ishlatgan bo'lsa — uning DDL ini ko'rsatamiz.
        extra_blocks = []
        for t in tables_in(clean):
            if t not in bundle_tables and t in catalog.tables and len(extra_blocks) < 2:
                extra_blocks.append(catalog.render_table(t))
        extra = ("\nQo'shimcha sxema:\n" + "\n\n".join(extra_blocks) + "\n") if extra_blocks else ""
        return "\n".join(f"- {p}" for p in problems), extra

    async def _execute(self, sql: str, result: dict[str, Any], question: str = "") -> None:
        clean = check_select(sql)
        catalog = await self._schema.catalog()
        problems = validate(clean, catalog, question)
        if problems:
            raise SqlNotAllowed("; ".join(problems))
        corrected = _scalar_total_sql(clean, question)
        if corrected != clean:
            clean = check_select(corrected)
            problems = validate(clean, catalog, question)
            if problems:
                raise SqlNotAllowed("; ".join(problems))
            sql = clean
            logger.info("Bitta jami sanoq uchun guruhlangan DISTINCT count tuzatildi")
        limit = int(self._s.sql_row_limit)
        run = await self._db.run_select(clean)
        rows = run["rows"][:limit]
        over_limit = len(run["rows"]) > limit
        count_sql = clean if over_limit else _own_limit_filled(clean, len(rows), question)
        total = None
        if count_sql:
            try:
                total = await self._db.count(count_sql)
            except Exception as exc:  # noqa: BLE001
                logger.info("Jami sonni hisoblab bo'lmadi: %s", exc)
        truncated = over_limit or (count_sql is not None and total is None) or (total is not None and total > len(rows))
        if len(rows) > 1 and not truncated:
            result["totals"] = _totals(clean, run["columns"], rows)  # hamma satr bo'yicha
        # Foydalanuvchiga (javob matni ham, API `rows` / UI jadvali ham) ko'pi bilan ROWS_SHOWN satr.
        if len(rows) > ROWS_SHOWN:
            total = total if truncated else len(rows)
            rows, truncated = rows[:ROWS_SHOWN], True
        if truncated:
            result["total_count"] = total
            result["warnings"].append(
                f"Natija to'liq emas: birinchi {len(rows)} ta satr ko'rsatildi"
                + (f" (jami {total} ta)." if total is not None else ".")
            )
        result["sql"] = sql
        result["columns"] = run["columns"]
        result["rows"] = rows
        result["row_count"] = len(rows)
        result["truncated"] = truncated
        result["pagination_sql"] = count_sql or clean
        if run.get("redacted_columns"):
            result["warnings"].append("Maxfiy ustunlar niqoblandi: " + ", ".join(run["redacted_columns"]))
