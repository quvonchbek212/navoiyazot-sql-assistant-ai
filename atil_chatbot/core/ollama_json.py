"""Model javobidan JSON ajratish.

Asl fayl 157 qator edi va Gemini'ga o'tish, structured output, sinxron
variantlar kabi funksiyalarni saqlardi. Ularning hech biri chaqirilmasdi
(chatbot JSON'ni faqat jadval tanlash va sarlavha uchun ishlatadi), shuning
uchun faqat haqiqatan kerak bo'lgan qism qoldirildi.
"""

from __future__ import annotations

import json
import re
from typing import Any


def extract_json(text: str) -> Any:
    """Model javobidan JSON ajratadi.

    Model JSON'ni ```json blokka o'rashi, oldiga izoh yozishi yoki matn ichiga
    joylashtirib yuborishi mumkin — shu holatlarning hammasi qamrab olingan.
    """
    cleaned = (text or "").strip()

    if cleaned.startswith("```"):
        parts = cleaned.split("```")
        if len(parts) >= 3:
            cleaned = parts[1].strip()
            if cleaned.lower().startswith("json"):
                cleaned = cleaned[4:].strip()

    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        pass

    # Matn ichidan eng tashqi { ... } yoki [ ... ] ni ajratib ko'ramiz
    candidates: list[str] = []
    obj_start, obj_end = cleaned.find("{"), cleaned.rfind("}")
    arr_start, arr_end = cleaned.find("["), cleaned.rfind("]")
    if obj_start != -1 and obj_end > obj_start:
        candidates.append(cleaned[obj_start : obj_end + 1])
    if arr_start != -1 and arr_end > arr_start:
        candidates.append(cleaned[arr_start : arr_end + 1])

    for candidate in candidates:
        try:
            return json.loads(candidate)
        except json.JSONDecodeError:
            continue

    fenced = re.search(r"```(?:json)?\s*([\s\S]*?)\s*```", cleaned, flags=re.IGNORECASE)
    if fenced:
        return extract_json(fenced.group(1))

    raise ValueError(f"Model javobidan valid JSON ajratib bo'lmadi: {cleaned[:200]!r}")
