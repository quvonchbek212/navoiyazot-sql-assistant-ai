"""SQL ni bazaga yubormasdan OLDIN sxema bo'yicha tekshirish.

Nima uchun: model mavjud bo'lmagan jadval/ustunni yozsa, baza umumiy xato
qaytaradi va model uni tuzatish uchun yetarli ma'lumot olmaydi. Yana ham
yomoni — `status = 'approved'` kabi bazada UCHRAMAYDIGAN qiymat bilan filtr
xato bermaydi, jimgina "0 ta" qaytaradi va foydalanuvchi uni haqiqat deb
qabul qiladi.

Tekshiruvlar (faqat ANIQ holatlar — shubhali holatda o'tkazib yuboriladi,
chunki noto'g'ri rad etish to'g'ri so'rovni buzadi):
  1. jadval katalogda bormi (CTE nomlari hisobga olinadi);
  2. `alias.ustun` — ustun o'sha jadvalda bormi; camelCase ustun qo'shtirnoqsiz
     yozilganmi (PostgreSQL uni kichik harfga o'giradi va topolmaydi);
  3. qo'shtirnoqsiz ustun — so'rovdagi birorta jadvalda bormi;
  4. `ustun = 'qiymat'` / `IN (...)` — qiymat ustunning ma'lum qiymatlari
     orasida bormi (CHECK yoki bazadagi to'liq ro'yxat bo'yicha).
  5. Savol berilganda hujjat turi va shablon identifikatori ma'nosi adashmaganmi.
  6. Kalendar kunlar so'ralganda timestamptz chegaralari Toshkent kuniga mosmi.
Har bir muammo model tushunadigan tilda, to'g'ri variantlar bilan qaytariladi.
"""
from __future__ import annotations

import difflib
import re

import sqlglot
from sqlglot import exp
from sqlglot.optimizer.scope import Scope, traverse_scope

from .schema_catalog import SchemaCatalog, Table, quote_ident
from .date_filters import calendar_problems, calendar_question
from .domain import JSON_LARGE_OBJECT_COLUMNS
from .sql_catalog import normalize

_DOCUMENT_TYPE_QUESTION = re.compile(
    r"\bhujjat\w*\s+tur\w*\b|\bdocument[ _-]+types?\b|\b(?:тип|вид)\w*\s+документ\w*\b",
    re.IGNORECASE,
)
_TEMPLATE_CODE_QUESTION = re.compile(
    r"\bshablon\w*\s+(?:(?:o'z|ichki)\s+)?kod\w*\b|\btemplates?\s+codes?\b"
    r"|\bcodes?\s+of\s+(?:the\s+)?templates?\b|\bкод\w*\s+шаблон\w*\b"
    r"|\bшаблон\w*\s+код\w*\b|\bdocument_template\.code\b",
    re.IGNORECASE,
)


def _document_type_problem(scope: Scope, resolve) -> str | None:
    """Inspect displayed/grouped fields, tracing CTE aliases back to their columns."""
    if not scope.is_root or not isinstance(scope.expression, exp.Select):
        return None
    projections = scope.expression.expressions
    aliases = {p.alias.lower(): p.this for p in projections if isinstance(p, exp.Alias)}

    def fields(expression):
        refs = set()
        for col in expression.find_all(exp.Column):
            table, column = resolve(scope, col)
            if table is not None and column is not None:
                refs.add((table.name.rsplit(".", 1)[-1], column.name))
        return refs

    displayed = set()
    for projection in projections:
        if projection.find(exp.AggFunc) is None:
            displayed.update(fields(projection))
    grouped = set()
    group = scope.expression.args.get("group")
    for expression in (group.expressions if group else []):
        if isinstance(expression, exp.Literal) and expression.is_int:
            position = int(expression.to_py()) - 1
            if 0 <= position < len(projections):
                expression = projections[position]
        elif isinstance(expression, exp.Column) and not expression.table:
            # PostgreSQL GROUP BY prefers a source column over an output alias.
            if resolve(scope, expression)[1] is None:
                expression = aliases.get(expression.name.lower(), expression)
        grouped.update(fields(expression))
    code = ("document_template", "code")
    kind = ("document_template", "document_type")
    if code in grouped or (code in displayed and kind not in displayed):
        return (
            "Hujjat turi so'ralgan: document_template.document_type dan foydalaning. "
            "document_template.code shablonning o'z identifikatori; u hujjat turi emas. "
            "SELECT/GROUP BY ni document_type bo'yicha tuzating; active va boshqa filtrlarni saqlang."
        )
    return None


def _suggest(name: str, options: list[str], n: int = 5) -> str:
    close = difflib.get_close_matches(name.lower(), [o.lower() for o in options], n=n, cutoff=0.5)
    mapping = {o.lower(): o for o in options}
    return ", ".join(mapping[c] for c in close)


def _plain_projection(column: exp.Column) -> bool:
    """A JSON/OID value may travel through projections, never scalar operations."""
    node = column
    while node.parent is not None:
        parent = node.parent
        if isinstance(parent, exp.Alias) and parent.this is node:
            node = parent
        elif isinstance(parent, exp.Select) and node in parent.expressions:
            node = parent
        elif isinstance(parent, (exp.Union, exp.Intersect, exp.Except, exp.Subquery)):
            node = parent
        elif isinstance(parent, (exp.From, exp.Join, exp.CTE)):
            # Relation consumers are validated separately, with column lineage.
            return True
        else:
            return False
    return True


def validate(sql: str, catalog: SchemaCatalog, question: str = "") -> list[str]:
    """Resolve columns in scope; an optional question enables domain meaning checks."""
    try:
        stmt = sqlglot.parse_one(sql, dialect="postgres")
        scopes = list(traverse_scope(stmt)) if stmt else []
    except Exception:
        return ["SQL sxema tahlili bajarilmadi; oddiy SELECT yozing."]
    problems: list[str] = []
    normalized_question = normalize(question)
    wants_document_type = (
        bool(_DOCUMENT_TYPE_QUESTION.search(normalized_question))
        and not _TEMPLATE_CODE_QUESTION.search(normalized_question)
    )
    maps = {}
    for scope in scopes:
        aliases = {}
        for alias, source in scope.sources.items():
            if isinstance(source, exp.Table):
                name = f"{source.db}.{source.name}" if source.db else source.name
                table = catalog.table(name)
                if table is None:
                    hint = _suggest(name, list(catalog.tables))
                    problems.append(f"'{name}' jadvali ruxsatli sxemada yo'q. O'xshashlari: {hint}.")
                aliases[alias.lower()] = table
            else:
                aliases[alias.lower()] = source if isinstance(source, Scope) else None
        maps[id(scope)] = aliases

    def derived(source, name, seen):
        branches = (getattr(source, "set_operation_scopes", None)
                    or getattr(source, "union_scopes", None) or [source])
        position = next((i for i, p in enumerate(source.expression.selects)
                         if p.alias_or_name.lower() == name.lower()), None)
        if position is None:
            return None, None
        result = (None, None)
        for branch in branches:
            projections = branch.expression.selects
            if position >= len(projections):
                continue
            projection = projections[position]
            if isinstance(branch.expression, (exp.Union, exp.Intersect, exp.Except)):
                table, column = derived(branch, projection.alias_or_name, seen.copy())
            else:
                expression = projection.this if isinstance(projection, exp.Alias) else projection
                table, column = resolve(branch, expression, seen.copy()) if isinstance(expression, exp.Column) else (None, None)
            if column is not None:
                result = table, column
                if column.is_json or column.is_blob or column.sensitive:
                    return result
        return result

    def resolve(scope, col, seen=None):
        seen = set() if seen is None else seen
        key = (id(scope), col.table.lower(), col.name.lower())
        if key in seen:
            return None, None
        seen.add(key)
        current = scope
        while current is not None:
            aliases = maps.get(id(current), {})
            if col.table:
                key = col.table.lower()
                if key in aliases:
                    table = aliases[key]
                    if isinstance(table, Scope):
                        return derived(table, col.name, seen)
                    return (table, table.column(col.name)) if table else (None, None)
            else:
                tables = {t.name: t for t in aliases.values() if isinstance(t, Table)}
                owners = [t for t in tables.values() if t.column(col.name)]
                derived_owners = [derived(t, col.name, seen.copy()) for t in aliases.values() if isinstance(t, Scope)]
                derived_owners = [pair for pair in derived_owners if pair[1] is not None]
                if not owners and len(derived_owners) == 1:
                    return derived_owners[0]
                if len(owners) == 1:
                    return owners[0], owners[0].column(col.name)
                if owners or any(not isinstance(t, Table) for t in aliases.values()):
                    return None, None
            current = current.parent if scope.can_be_correlated else None
        return None, None

    for scope in scopes:
        aliases = maps[id(scope)]
        tables = {t.name: t for t in aliases.values() if isinstance(t, Table)}
        opaque = any(not isinstance(t, Table) for t in aliases.values())
        output_aliases = {e.alias.lower() for e in scope.expression.selects if e.alias}
        for col in scope.columns:
            name = col.name
            if not name or name == "*":
                continue
            table, column = resolve(scope, col)
            if column is None:
                if table is not None:
                    hint = _suggest(name, [c.name for c in table.columns])
                    problems.append(f"'{table.name}' jadvalida '{name}' ustuni yo'q. O'xshash ustunlar: {hint}.")
                elif not col.table and not opaque and tables and name.lower() not in output_aliases:
                    problems.append(f"'{name}' ustuni so'rovdagi jadvallarning birortasida ham yo'q.")
                continue
            ident = col.this
            if column.sensitive:
                problems.append(f"Maxfiy ustunni o'qish taqiqlangan: {table.name}.{column.name}.")
            null_test = isinstance(col.parent, exp.Is) and isinstance(col.parent.expression, exp.Null)
            if column.is_blob:
                if (table.name, column.name) not in JSON_LARGE_OBJECT_COLUMNS or not (_plain_projection(col) or null_test):
                    problems.append(f"{table.name}.{column.name}: OID mazmunini bu shaklda o'qish taqiqlangan.")
            if column.is_json and not (_plain_projection(col) or null_test):
                problems.append(f"{table.name}.{column.name}: JSONni faqat alohida ustun sifatida o'qing; transformatsiya taqiqlangan.")
            if column.name != column.name.lower() and (not ident.quoted or ident.this != column.name):
                problems.append(f"'{column.name}' ustunini qo'shtirnoqda yozing: {quote_ident(column.name)}.")

        # Walk only this scope. NEQ and NOT IN are valid negative filters, not equality.
        for node in scope.walk():
            pairs = []
            if isinstance(node, exp.EQ):
                left, right = node.left, node.right
                if isinstance(left, exp.Literal) and isinstance(right, exp.Column):
                    left, right = right, left
                if isinstance(left, exp.Column) and isinstance(right, exp.Literal) and right.is_string:
                    pairs = [(left, [right.this])]
            elif isinstance(node, exp.In) and not isinstance(node.parent, exp.Not):
                if isinstance(node.this, exp.Column) and node.expressions and all(
                    isinstance(v, exp.Literal) and v.is_string for v in node.expressions
                ):
                    pairs = [(node.this, [v.this for v in node.expressions])]
            for col, literals in pairs:
                table, column = resolve(scope, col)
                known = column.known_values() if column else None
                if not known:
                    continue
                for literal in literals:
                    if literal not in known:
                        near = next((k for k in known if k.lower() == literal.lower()), None)
                        hint = f" Ehtimol: '{near}'." if near else ""
                        options = ", ".join(repr(k) for k in sorted(known)[:30])
                        problems.append(f"{table.name}.{column.name}: '{literal}' CHECK qiymatlari orasida yo'q.{hint} Mavjud qiymatlar: {options}.")
    if wants_document_type:
        for scope in scopes:
            if problem := _document_type_problem(scope, resolve):
                problems.append(problem)
    if calendar_question(question):
        for scope in scopes:
            problems.extend(calendar_problems(scope, resolve))
    return list(dict.fromkeys(problems))


_STATE_COLUMNS = {"is_active", "archived_at"}


def reference_filters(sql: str) -> list[str]:
    """Guruhlash uchun qo'shilgan jadvalga «faol/arxivsiz» filtri — hisobdan yozuv tushib qoladi.

    «Har bir laboratoriyada nechtadan asbob?» → count(i.id) ... GROUP BY l.name WHERE l.is_active:
    nofaol laboratoriyadagi asboblar sanalmay qoladi (domen qoidasi 5). Faqat aniq holat:
    sanalayotgan jadval agregat ichida alias bilan ko'rsatilgan (count(i.id), sum(i.x)) va
    filtr boshqa — faqat GROUP BY dagi — jadvalga qo'yilgan.
    """
    try:
        stmt = sqlglot.parse_one(sql, dialect="postgres")
    except Exception:  # noqa: BLE001
        return []
    if not isinstance(stmt, exp.Select) or not stmt.args.get("group") or not stmt.args.get("where"):
        return []
    counted = {
        col.table.lower()
        for agg in stmt.find_all(exp.Count, exp.Sum)
        for col in agg.find_all(exp.Column) if col.table
    }
    if not counted:
        return []
    grouped = {c.table.lower() for c in stmt.args["group"].find_all(exp.Column) if c.table} - counted
    aliases = {(t.alias_or_name or "").lower(): t.name for t in stmt.find_all(exp.Table)}
    problems: list[str] = []
    for col in stmt.args["where"].find_all(exp.Column):
        alias = (col.table or "").lower()
        if alias in grouped and col.name.lower() in _STATE_COLUMNS:
            table = aliases.get(alias, alias)
            problems.append(
                f"'{table}' jadvali faqat guruhlash uchun qo'shilgan — unga {col.name} filtrini qo'yma: "
                f"nofaol/arxivlangan {table} ga bog'langan yozuvlar hisobdan tushib qoladi "
                "(foydalanuvchi faqat faollarini so'ramagan)."
            )
            grouped.discard(alias)
    return problems


def tables_in(sql: str) -> list[str]:
    """So'rovdagi (CTE bo'lmagan) jadval nomlari."""
    try:
        stmt = sqlglot.parse_one(sql, dialect="postgres")
    except Exception:  # noqa: BLE001
        return []
    ctes = {c.alias_or_name.lower() for c in stmt.find_all(exp.CTE)}
    out: list[str] = []
    for t in stmt.find_all(exp.Table):
        if t.name and t.name.lower() not in ctes and t.name not in out:
            out.append(t.name)
    return out
