"""`schema/schema.json` va `schema/ddl.sql` ni HAQIQIY bazadan (FAQAT O'QIB) yaratadi.

Ishga tushirish (loyiha ildizidan, baza tarmog'ida — kerak bo'lsa VPN orqali):
    python -m atil_chatbot.tools.generate_ddl
    python -m atil_chatbot.tools.generate_ddl --render-only   # bazasiz: izohlar o'zgarganda
                                                              # ddl.sql ni schema.json dan qayta chizadi

Ulanish `default_transaction_read_only=on` bilan ochiladi — bazaga birorta
yozuv amali bormaydi.

NIMA YOZILADI VA NIMA UCHUN
  * Faqat read-user O'QIY OLADIGAN jadvallar. Boshqasi faylda tursa, model
    uni tanlaydi va so'rov "permission denied" bilan yiqiladi.
  * Ustunlar, turlar, PK, FK (JOIN yo'llari), CHECK cheklovlari.
  * Status/tur ustunlarining RUXSAT etilgan va bazada HAQIQATDA uchraydigan
    qiymatlari (sonlari bilan). Busiz model `status = 'approved'` deb
    taxmin qiladi va "0 ta" javobini oladi — foydalanuvchi esa uni haqiqat
    deb o'ylaydi.
  * `status_id` → `status_dictionary` bog'lanishlari uchun bazadagi kodlar.
  * Doim NULL ustunlar (masalan `analysisStatus` / `analysis_status`
    juftliklarining bo'sh nusxasi) — model ularni tanlamasin.
  * Sana ustunlarining oralig'i — model ma'lumot qaysi davrga tegishli
    ekanini bilsin.

NIMA YOZILMAYDI: ism, email, telefon, izoh matnlari kabi SHAXSIY yoki erkin
matnli ustunlarning qiymatlari. Faqat past kardinallikdagi kod/holat
ustunlari (ro'yxat pastda) — fayl repoga kiradi va modelga yuboriladi.
"""
from __future__ import annotations

import argparse
import datetime as dt
import pathlib
import re
import sys
from typing import Any

import psycopg

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]))

from atil_chatbot.app import domain  # noqa: E402
from atil_chatbot.app.config import get_settings  # noqa: E402
from atil_chatbot.app.db_client import DbClient  # noqa: E402
from atil_chatbot.app.schema_catalog import Column, SchemaCatalog, Table  # noqa: E402
from atil_chatbot.app.sql_guard import is_sensitive_column  # noqa: E402

#: Qiymatlari yig'iladigan ustunlar: nomining biror BO'LAGI shu so'zlardan biri
#: bo'lsa (`priority_level` → "level", `measurement_unit` → "unit").
VALUE_WORDS = {
    "status", "state", "type", "kind", "category", "level", "priority", "role", "mode",
    "direction", "outcome", "severity", "grade", "reason", "decision", "evaluation",
    "frequency", "periodicity", "unit", "slot", "scope", "system", "transport",
    "environment", "family", "relation", "action", "event", "entity", "group", "rule",
    "norm", "control", "resource", "attachment",
}
#: Hech qachon qiymati yig'ilmaydigan ustunlar (shaxsiy yoki erkin matn).
PRIVATE_COLUMN_RE = re.compile(
    r"(name|email|phone|person|fio|user|_by$|_by_|author|inspector|receiver|"
    r"member|requester|approver|preparer|sampler|analyst|laborant|employee|address|"
    r"comment|note|description|text|html|json|url|storage_key|hash|checksum|token|"
    r"password|secret|serial|_ref$|external|number|_no$|_raw$|reason$|containment|"
    r"^scope$|^norm$|_norm$)",
    re.IGNORECASE,
)
_UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-", re.IGNORECASE)
_CAMEL_RE = re.compile(r"(?<=[a-z])(?=[A-Z])")


def wants_values(name: str) -> bool:
    low = name.lower()
    if low == "id" or low.endswith("_id") or low.endswith("id") and name != low:
        return False
    if PRIVATE_COLUMN_RE.search(name):
        return False
    parts = set(_CAMEL_RE.sub("_", name).lower().split("_"))
    return bool(parts & VALUE_WORDS)


MAX_DISTINCT = 40
REFERENCE_MAX_ROWS = 80
DATE_TYPES = ("date", "timestamp")

HEADER = """\
-- =====================================================================
--  ATIL — baza sxemasi (DDL)
--  AVTOMATIK YARATILGAN: {now}   |   Manba: {db}   |   Jadvallar: {tables}
--
--  Chatbot bazani AYNAN shu ma'lumot orqali "ko'radi": model shundan SQL
--  yozadi, SQL tekshiruvchisi ham jadval/ustun/qiymatlarni shunga qarab
--  tekshiradi. QO'LDA TAHRIRLAMANG — baza o'zgarganda qayta yarating:
--      python -m atil_chatbot.tools.generate_ddl
--  Domen izohlari (`-- ` qatorlari jadval ustida) atil_chatbot/app/domain.py
--  da yoziladi; ularni o'zgartirgach:  ... generate_ddl --render-only
--
--  Belgilar:
--    RUXSAT: …        — CHECK bo'yicha ruxsat etilgan qiymatlar
--    BAZADA: 'X' N    — bazada haqiqatda uchraydigan qiymat va soni
--    ISHLATILMAGAN: … — ruxsat etilgan, lekin bazada YO'Q (filtr doim 0 beradi)
--    [har doim NULL]  — ustun bo'sh, ishlatmang
--    oraliq: A … B    — sana ustunidagi eng kichik va eng katta qiymat
-- =====================================================================

"""

_ANY_RE = re.compile(
    r"CHECK\s*\(+\s*\(?\s*\(?(?P<col>\"?\w+\"?)\)?(?:::\w+(?: varying)?)?\s*=\s*ANY\s*\(+\s*ARRAY\s*\[(?P<vals>.*?)\]",
    re.S,
)
_LIT_RE = re.compile(r"'((?:[^']|'')*)'")


def parse_enum_check(definition: str) -> tuple[str, list[str]] | None:
    """`CHECK ((status)::text = ANY (ARRAY['A'::varchar, ...]))` → ("status", ["A", ...])."""
    m = _ANY_RE.search(definition)
    if not m:
        return None
    vals = [v.replace("''", "'") for v in _LIT_RE.findall(m.group("vals"))]
    return (m.group("col").strip('"'), vals) if vals else None


def compact_check(definition: str) -> str:
    d = re.sub(r"^CHECK\s*", "", definition.strip())
    d = re.sub(r"::(text|character varying|numeric|integer|bigint)\b", "", d)
    d = re.sub(r"\s+", " ", d).strip()
    while d.startswith("((") and d.endswith("))"):
        d = d[1:-1]
    return d.strip("()") if d.count("(") < d.count(")") + 1 else d


def _ident(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def introspect(conn: psycopg.Connection, schemas: list[str]) -> SchemaCatalog:
    cur = conn.cursor()
    cur.execute(
        """
        SELECT CASE WHEN n.nspname = 'public' THEN c.relname ELSE n.nspname || '.' || c.relname END,
               d.description, c.oid
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        LEFT JOIN pg_description d ON d.objoid = c.oid
          AND d.classoid = 'pg_class'::regclass AND d.objsubid = 0
        WHERE n.nspname = ANY(%s) AND c.relkind IN ('r', 'p', 'v', 'm')
          AND has_table_privilege(c.oid, 'SELECT')
        ORDER BY c.relname
        """,
        (schemas,),
    )
    relations = [r for r in cur.fetchall() if r[0] not in domain.EXCLUDED_TABLES]
    table_names = [(r[0], r[1]) for r in relations]
    relation_oids = [r[2] for r in relations]

    cur.execute(
        """
        SELECT CASE WHEN n.nspname = 'public' THEN c.relname ELSE n.nspname || '.' || c.relname END, a.attname, format_type(a.atttypid, a.atttypmod), a.attnotnull,
               d.description
        FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        LEFT JOIN pg_description d ON d.objoid = c.oid
          AND d.classoid = 'pg_class'::regclass AND d.objsubid = a.attnum
        WHERE c.oid = ANY(%s) AND a.attnum > 0 AND NOT a.attisdropped
        ORDER BY c.relname, a.attnum
        """,
        (relation_oids,),
    )
    columns: dict[str, list[Column]] = {}
    for tbl, col, typ, notnull, comment in cur.fetchall():
        columns.setdefault(tbl, []).append(
            Column(name=col, type=typ, notnull=bool(notnull), comment=comment,
                   sensitive=is_sensitive_column(col))
        )

    cur.execute(
        """
        SELECT CASE WHEN n.nspname = 'public' THEN c.relname ELSE n.nspname || '.' || c.relname END, con.contype, pg_get_constraintdef(con.oid),
               (SELECT array_agg(a.attname ORDER BY k.ord) FROM unnest(con.conkey) WITH ORDINALITY k(attnum, ord)
                  JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = k.attnum),
               CASE WHEN nf.nspname = 'public' THEN cf.relname ELSE nf.nspname || '.' || cf.relname END,
               (SELECT array_agg(a.attname ORDER BY k.ord) FROM unnest(con.confkey) WITH ORDINALITY k(attnum, ord)
                  JOIN pg_attribute a ON a.attrelid = con.confrelid AND a.attnum = k.attnum)
        FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        LEFT JOIN pg_class cf ON cf.oid = con.confrelid
        LEFT JOIN pg_namespace nf ON nf.oid = cf.relnamespace
        WHERE con.conrelid = ANY(%s) AND con.contype IN ('p', 'f', 'c')
        ORDER BY c.relname, con.contype, con.conname
        """,
        (relation_oids,),
    )
    constraints: dict[str, list[tuple]] = {}
    for row in cur.fetchall():
        constraints.setdefault(row[0], []).append(row[1:])

    tables: dict[str, Table] = {}
    for name, comment in table_names:
        t = Table(name=name, rows=None, columns=columns.get(name, []), comment=comment)
        seen_fk: set[tuple[str, str, str]] = set()
        for contype, definition, cols, ref_table, ref_cols in constraints.get(name, []):
            if contype == "p":
                t.pk = list(cols or [])
            elif contype == "f" and cols and ref_cols:
                for col, rcol in zip(cols, ref_cols):
                    key = (col, ref_table, rcol)
                    if key not in seen_fk:  # bazada bir xil FK ikki marta bor (tnb_sample)
                        seen_fk.add(key)
                        t.fks.append({"column": col, "ref_table": ref_table, "ref_column": rcol})
            elif contype == "c":
                enum = parse_enum_check(definition)
                col = t.column(enum[0]) if enum else None
                if enum and col is not None:
                    col.allowed = enum[1]
                else:
                    t.checks.append(compact_check(definition))
        for tbl, col, ref_table, ref_col in domain.LOGICAL_FKS:
            if tbl == name and t.column(col) is not None and (col, ref_table, ref_col) not in seen_fk:
                seen_fk.add((col, ref_table, ref_col))
                t.fks.append({"column": col, "ref_table": ref_table, "ref_column": ref_col, "logical": True})
        for fk in t.fks:
            if fk["ref_table"] == "status_dictionary":
                col = t.column(fk["column"])
                if col is not None:
                    col.status_ref = True
        tables[name] = t
    cur.close()
    missing = [f"{t}.{c}" for t, c, *_ in domain.LOGICAL_FKS if t not in tables or tables[t].column(c) is None]
    if missing:
        print("DIQQAT: LOGICAL_FKS dagi ustunlar bazada yo'q:", ", ".join(missing))
    return SchemaCatalog(tables=tables)


def collect_stats(conn: psycopg.Connection, catalog: SchemaCatalog, schema: str) -> None:
    """Satr soni, doim-NULL ustunlar, sana oraliqlari va qiymatlar taqsimoti."""
    cur = conn.cursor()
    for name, t in catalog.tables.items():
        try:
            with conn.transaction():
                table_schema, table_name = name.split('.', 1) if '.' in name else (schema, name)
                ident = f"{_ident(table_schema)}.{_ident(table_name)}"
                parts = ["count(*)"]
                for c in t.columns:
                    parts.append(f"count({_ident(c.name)})")
                dates = [c for c in t.columns if short_starts(c.type, DATE_TYPES)]
                for c in dates:
                    parts.append(f"min({_ident(c.name)})::date::text")
                    parts.append(f"max({_ident(c.name)})::date::text")
                cur.execute(f"SELECT {', '.join(parts)} FROM {ident}")  # noqa: S608 — identifikatorlar katalogdan
                row = cur.fetchone()
                t.rows = row[0]
                for i, c in enumerate(t.columns, start=1):
                    c.always_null = t.rows > 0 and row[i] == 0
                base = 1 + len(t.columns)
                for j, c in enumerate(dates):
                    c.date_min, c.date_max = row[base + 2 * j], row[base + 2 * j + 1]

                if not t.rows:
                    continue
                for c in t.columns:
                    if c.sensitive or c.always_null or c.is_blob:
                        continue
                    if c.status_ref:
                        cur.execute(
                            f"SELECT sd.code, count(*) FROM {ident} x "  # noqa: S608
                            f"JOIN {_ident(table_schema)}.status_dictionary sd ON sd.id = x.{_ident(c.name)} "
                            "GROUP BY 1 ORDER BY 2 DESC, 1"
                        )
                        c.values = [[v, n] for v, n in cur.fetchall()]
                        c.values_complete = True
                        continue
                    # status_dictionary kodlari to'liq kerak: `sd.code = '...'` filtri shular bo'yicha tekshiriladi.
                    dictionary = name == "status_dictionary" and c.name in ("code", "entity_type")
                    # Kichik ma'lumotnoma jadvallarining kodlari (role.code, lab_type ...): model filtrda
                    # ishlatadi — bazadagi aniq qiymatlar ko'rinsin va tekshiruvchi ularni bilsin.
                    reference_code = c.name == "code" and t.rows <= REFERENCE_MAX_ROWS
                    wanted = dictionary or reference_code or c.allowed is not None or (
                        wants_values(c.name) and short_starts(c.type, ("character", "text", "varchar"))
                    )
                    if not wanted:
                        continue
                    limit = 300 if dictionary else (REFERENCE_MAX_ROWS if reference_code else MAX_DISTINCT)
                    cur.execute(
                        f"SELECT {_ident(c.name)}::text, count(*) FROM {ident} "  # noqa: S608
                        f"WHERE {_ident(c.name)} IS NOT NULL GROUP BY 1 ORDER BY 2 DESC, 1 LIMIT {limit + 1}"
                    )
                    vals = cur.fetchall()
                    if c.allowed is None and len(vals) > limit:
                        continue  # ko'p xilli ustun — ro'yxat foydasiz
                    if any(len(v) > 80 or _UUID_RE.match(v) for v, _ in vals):
                        continue
                    c.values = [[v, n] for v, n in vals[:limit]]
                    c.values_complete = len(vals) <= limit
        except psycopg.Error as exc:
            t.rows = None
            for c in t.columns:
                c.always_null = False
                c.values = None
                c.values_complete = False
                c.date_min = c.date_max = None
            print(f"Statistika olinmadi: {name} ({type(exc).__name__})")
    cur.close()


def short_starts(typ: str, prefixes: tuple[str, ...]) -> bool:
    return typ.startswith(prefixes)


def write_outputs(catalog: SchemaCatalog, json_path: pathlib.Path, ddl_path: pathlib.Path) -> None:
    import json

    json_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json.dumps(catalog.to_dict(), ensure_ascii=False, indent=1), encoding="utf-8")
    header = HEADER.format(now=catalog.generated_at, db=catalog.source, tables=len(catalog.tables))
    ddl_path.write_text(header + catalog.render_full() + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="ATIL baza sxemasidan schema.json va ddl.sql yaratish")
    parser.add_argument("--metadata-only", action="store_true", help="Faqat ustun/PK/FK/CHECK; qatorlarni skan qilmaydi")
    parser.add_argument("--render-only", action="store_true",
                        help="Bazaga ulanmasdan ddl.sql ni mavjud schema.json dan qayta chizish")
    args = parser.parse_args()

    settings = get_settings()
    json_path = pathlib.Path(settings.schema_file)
    ddl_path = pathlib.Path(settings.ddl_file)

    if args.render_only:
        catalog = SchemaCatalog.load(json_path)
    else:
        db = DbClient(settings)
        label = f"{settings.db_host}:{settings.db_port}/{settings.db_name}"
        print(f"Bazaga ulanmoqda (read-only): {label} …")
        try:
            with psycopg.connect(**db.conn_kwargs(statement_timeout_ms=120_000)) as conn:
                catalog = introspect(conn, settings.include_schemas_list or ["public"])
                if not args.metadata_only:
                    collect_stats(conn, catalog, "public")
        except Exception as exc:  # noqa: BLE001
            print(f"XATO: {exc}")
            return 1
        if not catalog.tables:
            print("XATO: jadvallar topilmadi (sxema bo'sh yoki ruxsat yo'q).")
            return 1
        catalog.source = label
        catalog.generated_at = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")

    write_outputs(catalog, json_path, ddl_path)
    stats: dict[str, Any] = {
        "jadval": len(catalog.tables),
        "ustun": sum(len(t.columns) for t in catalog.tables.values()),
        "fk": sum(len(t.fks) for t in catalog.tables.values()),
        "qiymatli ustun": sum(1 for t in catalog.tables.values() for c in t.columns if c.values),
        "doim NULL": sum(1 for t in catalog.tables.values() for c in t.columns if c.always_null),
        "izohli jadval": sum(1 for n in catalog.tables if n in domain.TABLE_NOTES),
    }
    print(f"OK {json_path}\nOK {ddl_path}  ({ddl_path.stat().st_size:,} bayt)")
    print("   " + " | ".join(f"{k}: {v}" for k, v in stats.items()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
