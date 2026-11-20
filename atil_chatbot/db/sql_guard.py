"""SQL xavfsizlik filtri — bazaga FAQAT SELECT yetib borishini kafolatlaydi.

Bu himoyaning BIRINCHI qatlami (kod darajasi). Ikkinchi qatlam
`connect_db_for_server.py` da: har bir query READ ONLY tranzaksiyada bajariladi,
ya'ni filtr aylanib o'tilsa ham PostgreSQL yozishni rad etadi. Uchinchi qatlam —
baza foydalanuvchisiga faqat SELECT huquqi berilgani (`.env` dagi `ATIL_DB_USER`).

LLM'ga ishonilmaydi: query bajarilishdan oldin har doim shu yerdan o'tadi.
"""

from __future__ import annotations

import re

# Bitta statement ichida ham bo'lmasligi kerak bo'lgan kalit so'zlar.
# Faqat butun so'z sifatida qidiriladi — masalan "updated_at" ustuni
# "UPDATE" deb xato aniqlanmaydi.
FORBIDDEN_KEYWORDS = (
    "insert", "update", "delete", "drop", "alter", "create", "truncate",
    "grant", "revoke", "merge", "upsert", "replace",
    "call", "do", "copy", "vacuum", "reindex", "cluster", "lock",
    "set", "reset", "discard", "listen", "notify", "unlisten",
    "prepare", "execute", "deallocate", "declare", "fetch", "move",
    "begin", "commit", "rollback", "savepoint", "start",
    "refresh", "analyze", "checkpoint", "load", "import",
)

# DIQQAT: `comment` ATAYLAB ro'yxatga KIRITILMAGAN.
# U ATIL bazasida haqiqiy ustun nomi (transport_request, transport_request_audit,
# waybill jadvallarida) va uni taqiqlash to'g'ri SELECT'larni bloklardi.
# Xavfsizlik yo'qolmaydi, chunki `COMMENT ON ...` faqat ALOHIDA statement bo'la
# oladi: query SELECT/WITH bilan boshlanishi majburiy va ko'p statement
# bloklangan, CTE ichida esa faqat INSERT/UPDATE/DELETE/MERGE yozish mumkin —
# ular ro'yxatda qolgan.

# Fayl tizimi, tarmoq yoki serverni boshqarish imkonini beruvchi funksiyalar.
FORBIDDEN_FUNCTIONS = (
    "pg_read_file", "pg_read_binary_file", "pg_ls_dir", "pg_stat_file",
    "lo_import", "lo_export", "lo_get", "lo_put",
    "dblink", "dblink_exec", "postgres_fdw_handler",
    "pg_sleep", "pg_sleep_for", "pg_sleep_until",
    "pg_terminate_backend", "pg_cancel_backend", "pg_reload_conf",
    "pg_rotate_logfile", "pg_promote",
    "set_config", "current_setting",
    "query_to_xml", "xmlparse",
)

_ALLOWED_STARTS = ("select", "with")

_IDENTIFIER_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_$]*")


class UnsafeSQLError(ValueError):
    """Query xavfsizlik tekshiruvidan o'tmadi."""

    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


def strip_sql_literals_and_comments(sql: str) -> str:
    """Tahlil uchun matnni tozalaydi: satr literallari, izohlar va identifikatorlar.

    Nima uchun kerak: `-- DROP` izoh ichida bo'lsa xato ogohlantirish bermasin,
    ammo `'; DROP TABLE x --'` kabi satr ichidagi matn ham kalit so'z deb
    hisoblanmasin. Shu bilan birga izoh ichida yashiringan haqiqiy statement
    ham o'tib ketmasin — buning uchun izohlar o'chiriladi, ya'ni ular hech
    qachon bajarilmaydigan matn sifatida qoladi.
    """
    out: list[str] = []
    i, n = 0, len(sql or "")

    while i < n:
        ch = sql[i]
        nxt = sql[i + 1] if i + 1 < n else ""

        # -- bir qatorlik izoh
        if ch == "-" and nxt == "-":
            while i < n and sql[i] != "\n":
                i += 1
            out.append(" ")
            continue

        # /* ... */ blok izoh (ichma-ich bo'lishi mumkin)
        if ch == "/" and nxt == "*":
            depth, i = 1, i + 2
            while i < n and depth:
                if sql[i] == "/" and i + 1 < n and sql[i + 1] == "*":
                    depth += 1
                    i += 2
                elif sql[i] == "*" and i + 1 < n and sql[i + 1] == "/":
                    depth -= 1
                    i += 2
                else:
                    i += 1
            out.append(" ")
            continue

        # 'satr literal' — ichida '' qochish belgisi bo'lishi mumkin
        if ch == "'":
            i += 1
            while i < n:
                if sql[i] == "'" and i + 1 < n and sql[i + 1] == "'":
                    i += 2
                    continue
                if sql[i] == "'":
                    i += 1
                    break
                i += 1
            out.append(" 'X' ")
            continue

        # $$ ... $$ yoki $tag$ ... $tag$ (dollar-quoted) — funksiya tanasi
        if ch == "$":
            match = re.match(r"\$([A-Za-z_][A-Za-z0-9_]*)?\$", sql[i:])
            if match:
                tag = match.group(0)
                end = sql.find(tag, i + len(tag))
                i = n if end == -1 else end + len(tag)
                out.append(" 'X' ")
                continue

        # "quoted identifier" — ustun/jadval nomi, kalit so'z emas
        if ch == '"':
            i += 1
            while i < n:
                if sql[i] == '"' and i + 1 < n and sql[i + 1] == '"':
                    i += 2
                    continue
                if sql[i] == '"':
                    i += 1
                    break
                i += 1
            out.append(" ident ")
            continue

        out.append(ch)
        i += 1

    return "".join(out)


def _statements(cleaned: str) -> list[str]:
    return [part.strip() for part in cleaned.split(";") if part.strip()]


def ensure_read_only(sql: str) -> str:
    """Query'ni tekshiradi va tozalangan (trailing `;` siz) SQL qaytaradi.

    Xavfsiz bo'lmasa `UnsafeSQLError` otadi.
    """
    raw = (sql or "").strip()
    if not raw:
        raise UnsafeSQLError("Bo'sh SQL query.")

    cleaned = strip_sql_literals_and_comments(raw)
    statements = _statements(cleaned)

    if not statements:
        raise UnsafeSQLError("SQL faqat izohdan iborat — bajariladigan buyruq yo'q.")

    if len(statements) > 1:
        raise UnsafeSQLError(
            f"Bir nechta SQL buyruq berilgan ({len(statements)} ta). "
            "Faqat bitta SELECT query ruxsat etiladi."
        )

    statement = statements[0]
    lowered = statement.lower().lstrip("( \t\n")

    if not lowered.startswith(_ALLOWED_STARTS):
        first_word = (lowered.split() or ["?"])[0]
        raise UnsafeSQLError(
            f"Query '{first_word.upper()}' bilan boshlanadi. "
            "Faqat SELECT yoki WITH ruxsat etiladi."
        )

    tokens = {token.lower() for token in _IDENTIFIER_RE.findall(statement)}

    # WITH ... AS ( ... ) ichida ham yozuv amali bo'lishi mumkin:
    # WITH x AS (DELETE FROM t RETURNING *) SELECT * FROM x
    hits = sorted(tokens.intersection(FORBIDDEN_KEYWORDS))
    if hits:
        raise UnsafeSQLError(
            f"Query'da taqiqlangan kalit so'z(lar) bor: {', '.join(w.upper() for w in hits)}. "
            "Faqat o'qish (SELECT) amallari ruxsat etiladi."
        )

    func_hits = sorted(tokens.intersection(FORBIDDEN_FUNCTIONS))
    if func_hits:
        raise UnsafeSQLError(
            f"Query'da taqiqlangan funksiya(lar) bor: {', '.join(func_hits)}."
        )

    # SELECT ... INTO yangi jadval yaratadi (SELECT INTO)
    if re.search(r"\binto\b", statement, re.IGNORECASE):
        raise UnsafeSQLError("SELECT ... INTO ruxsat etilmaydi (yangi jadval yaratadi).")

    # FOR UPDATE / FOR SHARE qatorlarni bloklaydi
    if re.search(r"\bfor\s+(update|no\s+key\s+update|share|key\s+share)\b", statement, re.IGNORECASE):
        raise UnsafeSQLError("FOR UPDATE / FOR SHARE ruxsat etilmaydi.")

    return raw.rstrip().rstrip(";").rstrip()

