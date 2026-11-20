"""Foydalanuvchiga ko'rinadigan javob matni — toza oddiy matn (markdown, emoji va ortiqcha belgilarsiz).

  * display_value — qiymatni o'qishga qulay ko'rinishga keltiradi: sana 18.09.2026,
    vaqt 10:23, 77.50 → 77.5, true → ha.
  * format_rows — natija satrlarini raqamlangan ro'yxatga aylantiradi. Ro'yxatni LLM
    emas, kod yozadi: har bir nom va son bazadagidek, hech biri tushib qolmaydi.
  * fallback_answer — LLM javob bermasa yoki xulosada natijada yo'q son chiqsa.
  * clean_text / strip_symbols — LLM matnidan markdown, emoji va qo'shtirnoqlarni olib tashlaydi.

Kod yozadigan so'zlar («jami 900 ta», «ko'rsatilmagan», «ha») javob tilida — TEXTS (uz/ru/en).
"""
from __future__ import annotations

import json
import re
from typing import Any

LIST_MAX = 20    # javob matnidagi ro'yxat uzunligi (to'liq natija — `rows` da)
VALUE_MAX = 120  # ro'yxatdagi bitta qiymatning uzunligi

REDACTED = "***"

# Kod yozadigan matn bo'laklari — javob tili bo'yicha (uz/ru/en).
TEXTS: dict[str, dict[str, str]] = {
    "uz": {
        "no_data": "So'rov bo'yicha ma'lumot topilmadi.", "missing": "ko'rsatilmagan",
        "yes": "ha", "no": "yo'q", "count": "{n} ta", "more_than": "{n} tadan ortiq",
        "shown": "Birinchi {n} tasi ko'rsatildi, jami {total}.", "found": "Jami {total} yozuv topildi.",
        "totals": "Jami: {fields}",
    },
    "ru": {
        "no_data": "По запросу данные не найдены.", "missing": "не указано",
        "yes": "да", "no": "нет", "count": "{n}", "more_than": "более {n}",
        "shown": "Показаны первые {n}, всего {total}.", "found": "Всего найдено записей: {total}.",
        "totals": "Итого: {fields}",
    },
    "en": {
        "no_data": "No data found for this request.", "missing": "not specified",
        "yes": "yes", "no": "no", "count": "{n}", "more_than": "more than {n}",
        "shown": "Showing the first {n} of {total}.", "found": "Records found: {total}.",
        "totals": "Total: {fields}",
    },
}


def phrase(key: str, lang: str = "uz", **kw: Any) -> str:
    return (TEXTS.get(lang) or TEXTS["uz"])[key].format(**kw)


_DATE = re.compile(r"^(\d{4})-(\d{2})-(\d{2})$")
_DATETIME = re.compile(r"^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})")
_TIME = re.compile(r"^(\d{2}):(\d{2}):\d{2}(?:\.\d+)?$")

# LLM matnidagi keraksiz belgilar: markdown (*), «» qo'shtirnoqlar, emoji va piktogrammalar.
_SYMBOLS = re.compile(
    "[*\u00ab\u00bb\u2600-\u27bf\u2b00-\u2bff\ufe0f\u200d\U0001f000-\U0001faff]"
)
# Apostrof variantlari (o`, o‘, oʻ ...) o'chirilmaydi — oddiy ' ga keltiriladi: «o'tkazilgan».
_APOSTROPHES = {ord("`"): "'", 0x2018: "'", 0x2019: "'", 0x02BB: "'", 0x02BC: "'"}
_HEADING = re.compile(r"^[ \t]*#{1,6}[ \t]*", re.MULTILINE)
_BULLET = re.compile(r"^([ \t]*)[*•][ \t]+", re.MULTILINE)
_INNER_SPACES = re.compile(r"(?<=\S)[ \t]{2,}")  # olib tashlangan belgi o'rnida qolgan bo'shliq
_TRAILING_SPACES = re.compile(r"[ \t]+\n")
_BLANK_LINES = re.compile(r"\n{3,}")


def strip_symbols(text: str) -> str:
    """Belgilarni olib tashlaydi — oqim bo'laklari uchun ham xavfsiz (belgi-belgi ishlaydi)."""
    return _SYMBOLS.sub("", text or "").translate(_APOSTROPHES)


def clean_text(text: str) -> str:
    """LLM yozgan yakuniy matn → toza oddiy matn."""
    text = _HEADING.sub("", text or "")
    text = _BULLET.sub(r"\1- ", text)
    text = _INNER_SPACES.sub(" ", strip_symbols(text))
    text = _TRAILING_SPACES.sub("\n", text)
    return _BLANK_LINES.sub("\n\n", text).strip()


def _number(value: float) -> str:
    if value.is_integer():
        return str(int(value))
    text = f"{value:.2f}" if abs(value) >= 1 else f"{value:.4f}"
    return text.rstrip("0").rstrip(".")


def display_value(value: Any, lang: str = "uz") -> str:
    """Qiymat → foydalanuvchiga ko'rsatiladigan matn (None → '')."""
    if value is None:
        return ""
    if isinstance(value, bool):
        return phrase("yes" if value else "no", lang)
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return _number(value)
    text = json.dumps(value, ensure_ascii=False) if isinstance(value, (dict, list)) else str(value)
    # Qator ko'chishi va ortiqcha bo'shliq ro'yxat qatorini buzmasin; bazadagi `Atsetal`degid` dagi
    # backtick apostrof — ekranda kod bo'lib ko'rinmasin.
    text = " ".join(text.split()).translate(_APOSTROPHES)
    if m := _DATE.match(text):
        return f"{m[3]}.{m[2]}.{m[1]}"
    if m := _DATETIME.match(text):
        date = f"{m[3]}.{m[2]}.{m[1]}"
        return date if m[4] == m[5] == "00" else f"{date} {m[4]}:{m[5]}"  # yarim tun — faqat sana
    if m := _TIME.match(text):
        return f"{m[1]}:{m[2]}"
    return text if len(text) <= VALUE_MAX else text[:VALUE_MAX].rstrip() + "..."


def display_rows(rows: list[Any], lang: str = "uz") -> list[Any]:
    """Satrlar LLM ga shu ko'rinishda beriladi — u sonlar va sanalarni ro'yxatdagidek yozadi."""
    return [
        {k: display_value(v, lang) or None for k, v in row.items()} if isinstance(row, dict)
        else display_value(row, lang)
        for row in rows
    ]


def label(column: str) -> str:
    """Ustun taxallusi → o'qiladigan nom: tahlillar_soni → tahlillar soni."""
    return " ".join(str(column).replace("_", " ").split())


def found_count(res: dict[str, Any], lang: str = "uz") -> str:
    """Topilgan yozuvlar soni matnda: «45 ta» (natija kesilgan bo'lsa — jami son)."""
    shown = res.get("row_count") or len(res.get("rows") or [])
    if not res.get("truncated"):
        return phrase("count", lang, n=shown)
    total = res.get("total_count")
    return phrase("count", lang, n=total) if total is not None else phrase("more_than", lang, n=shown)


def _row_line(row: Any, skip: set[str], lang: str) -> str:
    missing = phrase("missing", lang)
    if not isinstance(row, dict):
        return display_value(row, lang) or missing
    items = list(row.items())
    head = ""
    # Birinchi ustun matn (nom, kod, sana) bo'lsa — satr sarlavhasi: «Ammiak: tahlillar soni 1472».
    if items and (isinstance(items[0][1], str) or items[0][1] is None):
        head = display_value(items[0][1], lang) or missing
        items = items[1:]
    fields = [f"{label(k)} {text}" for k, v in items
              if k not in skip and v != REDACTED and (text := display_value(v, lang))]
    if head and fields:
        return f"{head}: {', '.join(fields)}"
    return head or ", ".join(fields) or missing


def _filtered_columns(rows: list[Any], sql: str) -> set[str]:
    """SQL da aniq qiymat bilan filtrlangan va har satrda bir xil ustunlar («holat Chetlanish»).

    Foydalanuvchi bu qiymatni savolidan biladi — har qatorda takrorlash shovqin.
    """
    first = rows[0] if rows and isinstance(rows[0], dict) else {}
    return {
        k for k, v in list(first.items())[1:]
        if isinstance(v, str) and f"'{v}'" in sql and all(isinstance(r, dict) and r.get(k) == v for r in rows)
    }


def format_rows(res: dict[str, Any], lang: str = "uz") -> str:
    """Natija satrlari — raqamlangan ro'yxat; ko'p bo'lsa birinchilari va jami soni."""
    rows = res.get("rows") or []
    skip = _filtered_columns(rows, res.get("sql") or "")
    lines = [f"{i}. {_row_line(row, skip, lang)}" for i, row in enumerate(rows[:LIST_MAX], start=1)]
    if res.get("totals"):
        fields = ", ".join(f"{label(k)} {display_value(v, lang)}" for k, v in res["totals"].items())
        lines.append(phrase("totals", lang, fields=fields))
    if res.get("truncated") or len(rows) > LIST_MAX:
        lines.append(phrase("shown", lang, n=min(len(rows), LIST_MAX), total=found_count(res, lang)))
    return "\n".join(lines)


def fallback_answer(res: dict[str, Any], lang: str = "uz") -> str:
    """LLM'siz, faqat natijadan tuzilgan to'liq javob."""
    rows = res.get("rows") or []
    if not rows:
        return phrase("no_data", lang)
    if len(rows) == 1 and isinstance(rows[0], dict):
        return "\n".join(
            f"{label(k).capitalize()}: {display_value(v, lang) or phrase('missing', lang)}"
            for k, v in rows[0].items() if v != REDACTED
        ) or phrase("no_data", lang)
    return f"{phrase('found', lang, total=found_count(res, lang))}\n\n{format_rows(res, lang)}"
