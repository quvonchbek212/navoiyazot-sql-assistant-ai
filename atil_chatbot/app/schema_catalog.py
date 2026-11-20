"""Baza sxemasi modeli — `schema/schema.json` ni o'qish va LLM uchun DDL matnini chizish.

`schema.json` — yagona manba. Uni `tools/generate_ddl.py` HAQIQIY bazadan
(faqat o'qib) yaratadi. Undan ikki narsa olinadi:
  * kod uchun: jadval/ustun ro'yxati, ruxsat etilgan va bazada uchraydigan
    qiymatlar — SQL bajarilishidan OLDIN tekshirish shular bo'yicha;
  * model uchun: har jadvalning DDL bloki (`render_table`) — domen izohlari
    (`domain.py`) bilan birga.

`schema/ddl.sql` — xuddi shu bloklarning to'liq fayli (odam o'qishi uchun).
"""
from __future__ import annotations

import json
import pathlib
import re
from dataclasses import dataclass, field
from typing import Any

from . import domain

_SIMPLE_IDENT = re.compile(r"^[a-z_][a-z0-9_]*$")
# PostgreSQL'da qo'shtirnoqsiz yozib bo'lmaydigan so'zlar (sxemada uchraganlari).
_RESERVED = {"group", "order", "user", "limit", "offset", "table", "check", "default", "end"}


def quote_ident(name: str) -> str:
    """Ustun/jadval nomini SQL'da qanday yozish kerak bo'lsa, shunday qaytaradi."""
    if _SIMPLE_IDENT.match(name) and name not in _RESERVED:
        return name
    return '"' + name.replace('"', '""') + '"'


def short_type(t: str) -> str:
    """Turni qisqa ko'rinishga keltiradi — prompt kichrayadi, ma'no o'zgarmaydi."""
    t = re.sub(r"character varying\(\d+\)", "varchar", t)
    t = t.replace("character varying", "varchar").replace("character(", "char(")
    t = re.sub(r"timestamp(\(\d+\))? with time zone", "timestamptz", t)
    t = re.sub(r"timestamp(\(\d+\))? without time zone", "timestamp", t)
    t = re.sub(r"time(\(\d+\))? without time zone", "time", t)
    t = t.replace("double precision", "float8")
    return t


@dataclass
class Column:
    name: str
    type: str
    notnull: bool = False
    comment: str | None = None
    sensitive: bool = False
    always_null: bool = False
    allowed: list[str] | None = None          # CHECK (col IN (...)) qiymatlari
    values: list[list[Any]] | None = None     # bazada uchraydigan qiymatlar: [[qiymat, soni], ...]
    values_complete: bool = False              # values — BARCHA qiymatlarmi
    status_ref: bool = False                   # status_dictionary.id ga FK (qiymatlar = kodlar)
    date_min: str | None = None
    date_max: str | None = None

    @property
    def is_blob(self) -> bool:
        return self.type == "oid"

    @property
    def is_json(self) -> bool:
        return self.type.rstrip("[]") in ("json", "jsonb") or self.name.lower().endswith("_json")

    def known_values(self) -> set[str] | None:
        """Ustunda uchrashi MUMKIN bo'lgan barcha qiymatlar (to'liq ma'lum bo'lsa)."""
        if self.status_ref:
            return None  # status_id — id saqlaydi, kod emas; kod status_dictionary.code da
        if self.allowed:
            return set(self.allowed)
        # Sampled values describe a snapshot, never a constraint on future rows.
        return None


@dataclass
class Table:
    name: str
    rows: int | None
    columns: list[Column]
    pk: list[str] = field(default_factory=list)
    fks: list[dict[str, str]] = field(default_factory=list)
    checks: list[str] = field(default_factory=list)
    comment: str | None = None

    def column(self, name: str) -> Column | None:
        low = name.lower()
        for c in self.columns:
            if c.name == name or c.name.lower() == low:
                return c
        return None

    @property
    def column_names(self) -> set[str]:
        return {c.name.lower() for c in self.columns}


@dataclass
class SchemaCatalog:
    tables: dict[str, Table]
    source: str = ""
    generated_at: str = ""

    # ---------------- yuklash / saqlash ----------------
    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "SchemaCatalog":
        tables: dict[str, Table] = {}
        for name, t in data["tables"].items():
            cols = [Column(**c) for c in t["columns"]]
            tables[name] = Table(
                name=name, rows=t.get("rows"), columns=cols, pk=t.get("pk", []),
                fks=t.get("fks", []), checks=t.get("checks", []), comment=t.get("comment"),
            )
        return cls(tables=tables, source=data.get("source", ""), generated_at=data.get("generated_at", ""))

    @classmethod
    def load(cls, path: str | pathlib.Path) -> "SchemaCatalog":
        return cls.from_dict(json.loads(pathlib.Path(path).read_text(encoding="utf-8")))

    def to_dict(self) -> dict[str, Any]:
        return {
            "generated_at": self.generated_at,
            "source": self.source,
            "tables": {
                name: {
                    "rows": t.rows, "comment": t.comment, "pk": t.pk, "fks": t.fks,
                    "checks": t.checks,
                    "columns": [
                        {k: v for k, v in c.__dict__.items()} for c in t.columns
                    ],
                }
                for name, t in sorted(self.tables.items())
            },
        }

    def table(self, name: str) -> Table | None:
        if name.startswith("public."):
            name = name[7:]
        return self.tables.get(name) or self.tables.get(name.lower())

    # ---------------- model uchun matn ----------------
    def render_table(self, name: str) -> str:
        t = self.tables[name]
        rows = "noma'lum" if t.rows is None else str(t.rows)
        head = [f"-- TABLE: {name}  (satrlar: {rows}{' — BO`SH' if t.rows == 0 else ''})"]
        note = domain.TABLE_NOTES.get(name)
        if note:
            head += [f"-- {line}".rstrip() for line in note.strip().splitlines()]

        body: list[str] = []
        for c in t.columns:
            line = f"    {quote_ident(c.name)} {short_type(c.type)}"
            if c.notnull:
                line += " NOT NULL"
            notes = _column_notes(name, c)
            if notes:
                line += "  -- " + "; ".join(notes)
            body.append(line)
        if t.pk:
            body.append(f"    PRIMARY KEY ({', '.join(quote_ident(p) for p in t.pk)})")
        for fk in t.fks:
            line = (
                f"    FOREIGN KEY ({quote_ident(fk['column'])}) REFERENCES "
                f"{fk['ref_table']}({quote_ident(fk['ref_column'])})"
            )
            if fk.get("logical"):
                line += "  -- mantiqiy bog'lanish (FK e'lon qilinmagan)"
            body.append(line)
        for chk in t.checks:
            body.append(f"    CHECK ({chk})")
        # vergullar — faqat haqiqiy ta'riflar orasida (izoh ichiga tushmasin)
        rendered = []
        for i, line in enumerate(body):
            comma = "," if i < len(body) - 1 else ""
            if "  -- " in line:
                code, comment = line.split("  -- ", 1)
                rendered.append(f"{code}{comma}  -- {comment}")
            else:
                rendered.append(line + comma)
        return "\n".join(head + [f"CREATE TABLE {name} ("] + rendered + [");"])

    def catalog_line(self, name: str) -> str:
        """Jadval tanlash uchun bir qatorli ta'rif."""
        t = self.tables[name]
        rows = "?" if t.rows is None else str(t.rows)
        note = domain.TABLE_NOTES.get(name, "").strip().splitlines()
        desc = note[0] if note else _auto_description(t)
        empty = " [BO'SH]" if t.rows == 0 else ""
        return f"{name} ({rows}){empty}: {desc}"

    def render_full(self) -> str:
        return "\n\n".join(self.render_table(n) for n in sorted(self.tables))


def _fmt_values(values: list[list[Any]], limit: int = 25) -> str:
    shown = ", ".join(f"'{v}' {n}" for v, n in values[:limit])
    if len(values) > limit:
        shown += f", … yana {len(values) - limit} ta"
    return shown


def _column_notes(table: str, c: Column) -> list[str]:
    notes: list[str] = []
    if c.sensitive:
        notes.append("[MAXFIY — o'qish taqiqlangan]")
    if c.always_null:
        notes.append("[har doim NULL — ishlatmang]")
    elif c.is_blob:
        if (table, c.name) in domain.JSON_LARGE_OBJECT_COLUMNS:
            notes.append("[katta obyekt (oid), xavfsiz JSON o'qish — faqat alohida ustun sifatida SELECT]")
        else:
            notes.append("[katta obyekt (oid) — SELECT qilmang]")
    elif c.is_json:
        notes.append("[JSON matn]")
    manual = domain.COLUMN_NOTES.get(f"{table}.{c.name}")
    if manual:
        notes.append(manual)
    if c.status_ref:
        codes = _fmt_values(c.values) if c.values else "yo'q"
        notes.append(
            "status_dictionary.id ga bog'langan — holatni JOIN status_dictionary sd "
            f"ON sd.id = {c.name} orqali sd.code bo'yicha filtrlang. BAZADA (sd.code): {codes}"
        )
        return notes
    if c.allowed:
        notes.append("RUXSAT: " + ", ".join(f"'{v}'" for v in c.allowed))
        used = {str(v) for v, _ in (c.values or [])}
        if c.values is not None:
            notes.append("BAZADA: " + (_fmt_values(c.values) if c.values else "yo'q"))
            unused = [v for v in c.allowed if v not in used]
            if unused:
                notes.append("ISHLATILMAGAN: " + ", ".join(unused))
    elif c.values:
        prefix = "BAZADA" if c.values_complete else "BAZADA (eng ko'p uchraydiganlari)"
        notes.append(f"{prefix}: {_fmt_values(c.values)}")
    if c.date_min and c.date_max:
        notes.append(f"oraliq: {c.date_min} … {c.date_max}")
    if c.comment:
        notes.append(c.comment.replace("\n", " ")[:160])
    return notes


def _auto_description(t: Table) -> str:
    cols = [c.name for c in t.columns if c.name not in ("id", "created_at", "updated_at")]
    return "ustunlar: " + ", ".join(cols[:8]) + (" …" if len(cols) > 8 else "")
