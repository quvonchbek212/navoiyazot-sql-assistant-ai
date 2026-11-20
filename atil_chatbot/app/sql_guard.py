"""SQL xavfsizlik qatlami — bazaga zarar yetkazmaslikning dastur darajasidagi kafolati.

Strategiya (defense-in-depth):
  1. So'rov `sqlglot` bilan AST ga aylantiriladi (PostgreSQL dialekti).
  2. Faqat BITTA statement (ko'p statement → rad).
  3. Ildiz tugun faqat read-query (SELECT / UNION / INTERSECT / EXCEPT).
  4. AST ichida taqiqlangan tugun bo'lsa → rad:
       INSERT/UPDATE/DELETE/MERGE/CREATE/DROP/ALTER/TRUNCATE,
       Command (SET, VACUUM, COPY, CALL, GRANT, ...),
       Into  (`SELECT ... INTO t` — PostgreSQL'da JADVAL YARATADI!),
       Lock  (`FOR UPDATE/SHARE` — qulflaydi).
  5. Xavfli funksiyalar (pg_sleep, pg_read_file, dblink, lo_*) → rad.
  6. Maxfiy jadval/ustunlar (pg_authid, password, token, ...) → rad.
  7. So'rov AST'dan QAYTA RENDER qilinadi — izoh yoki yashirin qo'shimcha
     statementlar butunlay yo'qoladi.
  8. Natija majburiy LIMIT bilan o'raladi.

Bu read-only DB foydalanuvchi va read-only tranzaksiyaga QO'SHIMCHA himoya.
"""
from __future__ import annotations

import sqlglot
import re
import unicodedata
from sqlglot import exp

# AST ichida uchrashi taqiqlangan tugunlar → foydalanuvchiga ko'rsatiladigan nom.
FORBIDDEN_NODE_LABEL = {
    exp.Insert: "INSERT", exp.Update: "UPDATE", exp.Delete: "DELETE",
    exp.Merge: "MERGE", exp.Create: "CREATE", exp.Drop: "DROP",
    exp.Alter: "ALTER", exp.TruncateTable: "TRUNCATE",
    exp.Command: "boshqaruv buyrug'i (SET/COPY/GRANT/...)",
    exp.Into: "SELECT ... INTO (jadval yaratadi)",
    exp.Lock: "FOR UPDATE/SHARE (qulflash)",
}

# Umuman murojaat qilib bo'lmaydigan jadvallar (parol xeshlari).
FORBIDDEN_TABLES = {"pg_authid", "pg_shadow", "pg_user_mapping", "pg_user_mappings"}

# Maxfiy ustun nomlari (qism satr bo'yicha tekshiriladi).
SENSITIVE_COLUMN_PARTS = (
    "password", "passwd", "rolpassword", "secret",
    "api_key", "apikey", "private_key", "credential", "access_token",
    "refresh_token", "verification_token", "auth_token", "session_token", "token", "authorization", "cookie",
)

# Unknown functions fail closed, including custom/security-definer functions.
SAFE_FUNCTIONS = set("""
count sum avg min max coalesce nullif greatest least round abs ceil ceiling floor
sqrt power pow mod sign trunc current_date current_timestamp current_time
localtime localtimestamp timestamp_trunc date_trunc extract date_part
to_char time_to_str to_date to_timestamp str_to_time str_to_date
lower upper length char_length trim ltrim rtrim substring replace concat concat_ws
split_part left right position str_position row_number rank dense_rank lag lead
first_value last_value nth_value ntile bool_and bool_or every
and or case if cast try_cast exists date timestamp interval
""".split())


class SqlNotAllowed(Exception):
    pass


def is_sensitive_column(name: str) -> bool:
    low = unicodedata.normalize("NFKC", name or "").lower()
    folded = re.sub(r"[^a-z0-9]", "", low)
    return any(part in low or part.replace("_", "") in folded for part in SENSITIVE_COLUMN_PARTS)


def sanitize_select(sql: str, row_limit: int) -> str:
    """So'rovni tekshiradi va xavfsiz, LIMIT bilan o'ralgan SELECT qaytaradi.

    Xato bo'lsa SqlNotAllowed ko'taradi.
    """
    return wrap_limit(check_select(sql), row_limit)


def check_select(sql: str) -> str:
    """So'rovni tekshiradi va AST'dan qayta render qilingan toza SELECT qaytaradi.

    Xato bo'lsa SqlNotAllowed ko'taradi.
    """
    sql = (sql or "").strip().rstrip(";").strip()
    if not sql:
        raise SqlNotAllowed("Bo'sh so'rov.")

    try:
        statements = sqlglot.parse(sql, dialect="postgres")
    except Exception as exc:  # noqa: BLE001
        raise SqlNotAllowed(f"SQL sintaksis xatosi: {exc}") from exc

    statements = [s for s in statements if s is not None]
    if len(statements) != 1:
        raise SqlNotAllowed("Faqat bitta SELECT so'roviga ruxsat beriladi.")

    stmt = statements[0]
    if not isinstance(stmt, (exp.Select, exp.Union, exp.Intersect, exp.Except, exp.Subquery)):
        raise SqlNotAllowed("Faqat SELECT (o'qish) so'rovlariga ruxsat beriladi.")

    # Reject controls before walking projections so errors identify the unsafe operation.
    for forbidden, label in FORBIDDEN_NODE_LABEL.items():
        if stmt.find(forbidden) is not None:
            raise SqlNotAllowed(f"Taqiqlangan amal aniqlandi: {label}. Faqat o'qishga ruxsat.")
    row_names = {t.alias_or_name.lower() for t in stmt.find_all(exp.Table)}
    row_names.update(a.name.lower() for a in stmt.find_all(exp.TableAlias))
    for node in stmt.walk():
        # 1) Taqiqlangan tugunlar
        for forbidden, label in FORBIDDEN_NODE_LABEL.items():
            if isinstance(node, forbidden):
                raise SqlNotAllowed(f"Taqiqlangan amal aniqlandi: {label}. Faqat o'qishga ruxsat.")
        # 2) Xavfli funksiyalar
        if isinstance(node, exp.Func):
            name = (str(node.this) if isinstance(node, exp.Anonymous) else node.sql_name()).lower()
            if name not in SAFE_FUNCTIONS or isinstance(node.parent, exp.Dot):
                raise SqlNotAllowed(f"Ruxsat berilmagan funksiya: {name}.")
        if isinstance(node, exp.Star) and not isinstance(node.parent, exp.Count):
            raise SqlNotAllowed("SELECT * taqiqlangan: kerakli xavfsiz ustunlarni aniq yozing.")
        # 3) Maxfiy jadvallar
        if isinstance(node, exp.Table):
            if node.catalog:
                raise SqlNotAllowed("Boshqa bazaga murojaat taqiqlangan.")
            tname = (node.name or "").lower()
            if tname in FORBIDDEN_TABLES:
                raise SqlNotAllowed(f"Bu jadvalga murojaat taqiqlangan: {tname}.")
        # 4) Maxfiy ustunlar
        if isinstance(node, exp.Column):
            if node.name.lower() in row_names and (not node.table or any(
                t.name.lower() == node.name.lower() and t.db.lower() == node.table.lower()
                for t in stmt.find_all(exp.Table)
            )):
                raise SqlNotAllowed("Butun jadval qatorini o'qish taqiqlangan; ustunlarni aniq yozing.")
            if is_sensitive_column(node.name):
                raise SqlNotAllowed(
                    f"Maxfiy ustunni o'qish taqiqlangan: {node.name}."
                )
        if isinstance(node, exp.Cast):
            target = node.args.get("to")
            if target is not None and target.args.get("kind"):
                raise SqlNotAllowed("Maxsus turga CAST taqiqlangan.")
        if isinstance(node, exp.TableAlias) and node.args.get("columns"):
            raise SqlNotAllowed("Jadval ustunlarini pozitsiya bo'yicha qayta nomlash taqiqlangan.")
        if isinstance(node, exp.Operator):
            raise SqlNotAllowed("Maxsus OPERATOR taqiqlangan.")

    # AST'dan qayta render — yashirin izoh/qo'shimcha statementlar yo'qoladi.
    clean = stmt.sql(dialect="postgres")

    # Qo'shimcha ishonch: render natijasida ';' qolmasligi kerak.
    if ";" in clean:
        raise SqlNotAllowed("So'rovda ruxsat etilmagan ajratuvchi (;) aniqlandi.")

    return clean


def wrap_limit(clean: str, row_limit: int) -> str:
    return f"SELECT * FROM (\n{clean}\n) AS _lims_sub LIMIT {int(row_limit)}"


def wrap_count(clean: str) -> str:
    return f"SELECT count(*) FROM (\n{clean}\n) AS _lims_cnt"


def split_limit(clean: str) -> tuple[int, str] | None:
    """So'rovning o'z `LIMIT N` i va LIMIT siz varianti (N ta satr qaytsa — jami sonni bilish uchun).

    OFFSET li, UNION li yoki LIMIT i son bo'lmagan so'rov uchun None.
    """
    try:
        stmt = sqlglot.parse_one(clean, dialect="postgres")
    except Exception:  # noqa: BLE001
        return None
    limit = stmt.args.get("limit") if isinstance(stmt, exp.Select) else None
    if limit is None or stmt.args.get("offset") is not None:
        return None
    value = limit.expression
    if not isinstance(value, exp.Literal) or not value.is_int:
        return None
    unlimited = stmt.copy()
    unlimited.set("limit", None)
    return int(value.to_py()), unlimited.sql(dialect="postgres")


def additive_columns(clean: str) -> list[str]:
    """Guruhlar bo'yicha qo'shsa bo'ladigan ustunlar: count(*), count(...) FILTER, sum(...).

    Faqat oddiy `GROUP BY` so'rovida (LIMIT/HAVING siz — aks holda yig'indi hamma
    guruhlarniki emas). count(DISTINCT ...), avg, foiz — qo'shib bo'lmaydi.
    """
    try:
        stmt = sqlglot.parse_one(clean, dialect="postgres")
    except Exception:  # noqa: BLE001
        return []
    if not isinstance(stmt, exp.Select) or not stmt.args.get("group") or any(
        stmt.args.get(k) is not None for k in ("limit", "having", "offset")
    ):
        return []
    out = []
    for e in stmt.expressions:
        agg = e.this if isinstance(e, exp.Alias) else e
        if isinstance(agg, exp.Filter):
            agg = agg.this
        if isinstance(agg, exp.Sum) or (isinstance(agg, exp.Count) and not isinstance(agg.this, exp.Distinct)):
            out.append(e.alias_or_name)
    return out
