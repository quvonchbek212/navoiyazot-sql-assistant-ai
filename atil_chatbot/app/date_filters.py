"""Conservative checks for literal calendar-day bounds on timestamp columns."""
from __future__ import annotations

import datetime as dt
import re

from sqlglot import exp

from .schema_catalog import short_type

TASHKENT = dt.timezone(dt.timedelta(hours=5))

_CALENDAR = re.compile(
    r"\d{4}-\d{2}-\d{2}|\b(?:bugun|kecha|kun\w*|hafta\w*|oy\w*|sana\w*"
    r"|yanvar\w*|fevral\w*|mart\w*|aprel\w*|may|iyun\w*|iyul\w*|avgust\w*"
    r"|sentabr\w*|sentyabr\w*|oktabr\w*|oktyabr\w*|noyabr\w*|dekabr\w*"
    r"|today|yesterday|days?|weeks?|months?|dates?"
    r"|january|february|march|april|june|july|august|september|october|november|december"
    r"|сегодня|вчера|день|дня|дней|даты?\w*|недел\w*|месяц\w*"
    r"|январ\w*|феврал\w*|март\w*|апрел\w*|ма[йя]|июн\w*|июл\w*|август\w*"
    r"|сентябр\w*|октябр\w*|ноябр\w*|декабр\w*)\b", re.I,
)
# Explicit times, elapsed hours and requested alternative time zones need a
# different interpretation. Leave those to the model instead of guessing.
_TIME_OR_ZONE = re.compile(
    r"\b\d{1,2}:\d{2}|\b(?:soat\w*|daqiqa\w*|soniya\w*|hours?|minutes?|seconds?"
    r"|час\w*|минут\w*|секунд\w*|utc|gmt|timezone|time\s+zone|vaqt\s+mintaqa\w*"
    r"|часов\w*\s+пояс\w*|moskva|moscow|москв\w*)\b|\b[A-Za-z_]+/[A-Za-z_]+\b",
    re.I,
)
_ISO_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}(?:$|[T ])")
_HINT = (
    "Kun bo'yicha sana chegarasi noto'g'ri: standart vaqt Asia/Tashkent (UTC+05:00). "
    "timestamptz uchun boshlanish >= mahalliy kun 00:00:00, tugash esa "
    "< oxirgi kundan KEYINGI kun 00:00:00 bo'lsin. Sanalarni savoldagidek saqlang. "
    "+00 yozilsa, o'sha lahzani to'g'ri aylantiring: Toshkentdagi 00:00 UTCda "
    "OLDINGI kun 19:00 bo'ladi. <= 23:59:59 kasr soniyalarni tushirib qoldiradi."
)


def calendar_question(question: str) -> bool:
    return bool(_CALENDAR.search(question) and not _TIME_OR_ZONE.search(question))


def _unparen(node):
    while isinstance(node, exp.Paren):
        node = node.this
    return node


def _literal_time(node, zone) -> dt.datetime | None:
    node = _unparen(node)
    cast = None
    if isinstance(node, exp.Cast):
        cast = node.args["to"].this
        if cast not in (exp.DataType.Type.DATE, exp.DataType.Type.TIMESTAMP, exp.DataType.Type.TIMESTAMPTZ):
            return None
        node = _unparen(node.this)
    if not isinstance(node, exp.Literal) or not node.is_string or not _ISO_DATE.match(node.this):
        return None
    try:
        value = dt.datetime.fromisoformat(node.this.replace("Z", "+00:00"))
    except ValueError:
        return None
    if cast == exp.DataType.Type.DATE:
        value = dt.datetime.combine(value.date(), dt.time())
    elif cast == exp.DataType.Type.TIMESTAMP:
        # PostgreSQL ignores offsets in TIMESTAMP WITHOUT TIME ZONE literals.
        value = value.replace(tzinfo=None)
    return (value if value.tzinfo else value.replace(tzinfo=zone)).astimezone(TASHKENT)


def calendar_problems(scope, resolve) -> list[str]:
    """Check only known timestamptz columns with literal calendar boundaries.

    Compare instants in local time, so correctly converted UTC boundaries stay
    valid. DATE casts, expressions, unknown columns and nonliteral bounds are
    left alone. Existing scope resolution also handles plain CTE aliases.
    """
    problems = []
    for node in scope.walk():
        if isinstance(node, exp.Between):
            comparisons = [(node.this, node.args["low"], exp.GTE),
                           (node.this, node.args["high"], exp.LTE)]
        elif isinstance(node, (exp.GTE, exp.GT, exp.LT, exp.LTE)):
            left, right, op = _unparen(node.left), _unparen(node.right), type(node)
            if isinstance(right, (exp.Column, exp.AtTimeZone)):
                left, right = right, left
                op = {exp.GTE: exp.LTE, exp.GT: exp.LT, exp.LT: exp.GT, exp.LTE: exp.GTE}[op]
            comparisons = [(left, right, op)]
        else:
            continue
        for field, literal, op in comparisons:
            field, zone = _unparen(field), TASHKENT
            if isinstance(field, exp.AtTimeZone):
                tz = field.args.get("zone")
                # Naive values after AT TIME ZONE are interpreted in that zone.
                if not isinstance(tz, exp.Literal) or tz.this.lower() not in ("utc", "asia/tashkent"):
                    continue
                if any(c.args["to"].this == exp.DataType.Type.TIMESTAMPTZ for c in literal.find_all(exp.Cast)):
                    continue
                zone = dt.timezone.utc if tz.this.lower() == "utc" else TASHKENT
                field = _unparen(field.this)
            if not isinstance(field, exp.Column):
                continue
            table, column = resolve(scope, field)
            if column is None or short_type(column.type) != "timestamptz":
                continue
            value = _literal_time(literal, zone)
            if value is None:
                continue
            # Whole days form a half-open interval. The microsecond-precision
            # equivalent using the previous day's last instant is valid too.
            expected = dt.time.min if op in (exp.GTE, exp.LT) else dt.time.max
            if value.time() != expected:
                problems.append(f"{table.name}.{column.name}: {_HINT}")
    return problems
