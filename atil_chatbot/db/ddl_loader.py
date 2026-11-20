"""ddl.sql ni o'qish — jadval bloklari, izohlari va ustunlari.

ASL KODDAGI XATO VA UNING TUZATILISHI
Ko'chirib olingan kodda jadval bloki shu regex bilan ajratilgan edi:

    (create\\s+table\\s+(\\w+)[\\s\\S]*?)(?=\\n\\s*create\\s+table\\s+|\\Z)

Blok `create table` dan boshlangani uchun jadvalning USTIDA yozilgan `--`
izohlari oldingi jadvalning blokiga tushib qolardi. Natijada model har bir
jadvalni qo'shnisining izohi bilan ko'rar edi — xato bermaydigan, jimgina
buziladigan holat.

Shu modulda blok `create table` dan oldingi izoh qatorlarini ham qamrab oladi.
"""

from __future__ import annotations

import re
from functools import lru_cache
from pathlib import Path

from config import DDL_PATH

#: Jadval bloki: oldidagi `--` izoh qatorlari + create table ... );
_TABLE_BLOCK_RE = re.compile(
    r"""
    (?P<comment>(?:^[ \t]*--[^\n]*\n)*)      # bloк oldidagi izoh qatorlari
    (?P<body>^[ \t]*create\s+table\s+
        (?:"?[\w$]+"?\.)?                    # ixtiyoriy schema prefiksi
        "?(?P<name>[\w$]+)"?
        [\s\S]*?\n\s*\);)                    # jadval tanasi ");" gacha
    """,
    re.IGNORECASE | re.MULTILINE | re.VERBOSE,
)

_COLUMN_RE = re.compile(r'^\s{2,}"?(?P<col>[a-zA-Z_][\w$]*)"?\s+\S')

#: Ustun nomi deb qabul qilinmaydigan tokenlar (jadval-darajasidagi konstruksiyalar)
_NOT_A_COLUMN = {
    "constraint", "primary", "foreign", "unique", "check", "references",
    "exclude", "like", "inherits", "partition", "using", "with",
}


def _dedent_comment(comment_block: str) -> str:
    lines = []
    for line in comment_block.splitlines():
        stripped = line.strip()
        if not stripped.startswith("--"):
            continue
        text = stripped[2:].strip()
        # Ajratuvchi chiziqlarni ("-----") tashlab ketamiz
        if text and set(text) <= {"-"}:
            continue
        lines.append(text)
    return "\n".join(lines).strip()


@lru_cache(maxsize=4)
def _read_ddl(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


@lru_cache(maxsize=4)
def load_tables(ddl_path: str | None = None) -> dict[str, dict[str, object]]:
    """Har bir jadval uchun {izoh, DDL kodi, ustunlar} qaytaradi."""
    text = _read_ddl(str(ddl_path or DDL_PATH))
    tables: dict[str, dict[str, object]] = {}

    for match in _TABLE_BLOCK_RE.finditer(text):
        name = match.group("name").lower()
        body = match.group("body").strip()
        description = _dedent_comment(match.group("comment") or "")

        columns: list[str] = []
        for line in body.splitlines()[1:]:
            column_match = _COLUMN_RE.match(line)
            if not column_match:
                continue
            column = column_match.group("col")
            if column.lower() in _NOT_A_COLUMN:
                continue
            if column not in columns:
                columns.append(column)

        tables[name] = {"description": description, "ddl": body, "columns": columns}

    return tables


#: `-- <ustun> BAZADA: A 74, B 16 | ISHLATILMAGAN: C, D` qatori.
#: `regenerate_ddl.py` uni bazadagi haqiqiy taqsimotdan yozadi.
_DIST_RE = re.compile(
    r"^\s*--\s*(?P<col>[a-zA-Z_]\w*)\s+BAZADA:\s*(?P<bor>[^|\n]*)"
    r"(?:\|\s*ISHLATILMAGAN:\s*(?P<yoq>[^\n]*))?$",
    re.MULTILINE,
)

#: "COMPLETED 74" -> ("COMPLETED", 74)
_QIYMAT_RE = re.compile(r"(?P<q>[A-Za-z_]\w*)\s+(?P<n>\d+)")


@lru_cache(maxsize=4)
def enum_distributions(ddl_path: str | None = None) -> dict[str, dict[str, dict]]:
    """Jadval -> ustun -> {"bor": {qiymat: son}, "yoq": [qiymat, ...]}.

    NIMA UCHUN: `check (...)` bazaga yozilishi MUMKIN bo'lgan qiymatlarni
    beradi, HAQIQATDA uchraydiganini emas. Model ro'yxatdagi birinchi mos
    so'zni tanlaydi va bazada u bo'lmasa "0" javobini oladi — son to'g'ri,
    xulosa noto'g'ri (29.08.2026 o'lchovi: `trip.status = 'PLANNED'` va
    `transport_request.status = 'APPROVED'` — ikkalasi ham 0 qator, holbuki
    tegishli ish bazada bor edi).

    Promptga qoida yozish YETARLI EMAS: umumiy qoida aniq ko'rsatma bilan
    zid kelganda model aniq ko'rsatmaga bo'ysundi (`"tasdiqlangan" ->
    APPROVED`). Shuning uchun tekshiruv KODDA bajariladi.
    """
    out: dict[str, dict[str, dict]] = {}
    for name, info in load_tables(ddl_path).items():
        ustunlar: dict[str, dict] = {}
        for m in _DIST_RE.finditer(str(info["ddl"])):
            bor = {
                q.group("q"): int(q.group("n"))
                for q in _QIYMAT_RE.finditer(m.group("bor") or "")
            }
            xom = (m.group("yoq") or "").strip()
            # "va yana N ta" — ro'yxat qisqartirilgan, qolganini bilmaymiz,
            # shuning uchun ular "yo'q" deb hisoblanmaydi.
            yoq = [
                v.strip() for v in xom.split(",")
                if v.strip() and not v.strip().startswith("va yana")
            ]
            if bor or yoq:
                ustunlar[m.group("col")] = {"bor": bor, "yoq": yoq}
        if ustunlar:
            out[name] = ustunlar
    return out


def table_names(ddl_path: str | None = None) -> set[str]:
    return set(load_tables(ddl_path))


def table_columns(ddl_path: str | None = None) -> dict[str, set[str]]:
    return {name: set(info["columns"]) for name, info in load_tables(ddl_path).items()}  # type: ignore[arg-type]


def table_descriptions(ddl_path: str | None = None) -> dict[str, str]:
    """Jadval nomi → izoh. Izoh bo'lmasa DDL kodining o'zi qaytariladi."""
    out: dict[str, str] = {}
    for name, info in load_tables(ddl_path).items():
        out[name] = str(info["description"] or info["ddl"])
    return out


def table_ddls(ddl_path: str | None = None) -> dict[str, str]:
    """Jadval nomi → izoh + to'liq CREATE TABLE kodi (promptga beriladigan matn)."""
    out: dict[str, str] = {}
    for name, info in load_tables(ddl_path).items():
        description = str(info["description"] or "")
        comment = "\n".join(f"-- {line}" for line in description.splitlines()) if description else ""
        out[name] = f"{comment}\n{info['ddl']}".strip()
    return out
