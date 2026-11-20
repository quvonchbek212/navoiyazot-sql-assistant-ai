"""Ehtiyot qismlar nazorati sozlamalari.

MEYOR O'YLAB TOPILMAYDI. Qism resursi bazadan (`vehicle_part.expected_life_*`
— korxonaning o'z siyosati), bo'lmasa manbali ma'lumotnomadan
(`vehicle_reference`: akkumulyator — GOST R 53165-2020, shina kafolati —
GOST 4754-97). "Mos kelmaydi" hukmi solishtirishdan chiqadi: so'ralgan
akkumulyator sig'imi shu mashinada (yoki shu rusumdagi boshqalarida)
o'rnatilganlarga to'g'ri kelmasa — bu chegara emas, to'plamga tegishlilik.
"""

from __future__ import annotations

import os
from datetime import timedelta, timezone, tzinfo
from pathlib import Path

from dotenv import load_dotenv

PROJECT_ROOT = Path(__file__).resolve().parent.parent

load_dotenv(PROJECT_ROOT / ".env")


def _int(name: str, default: int) -> int:
    raw = os.getenv(name)
    try:
        return int(raw) if raw not in (None, "") else default
    except ValueError:
        return default


def _flag(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


#: Sanalar shu zonada kesiladi (ATIL `calendarBasis` ham Toshkent).
TIMEZONE = os.getenv("PC_TIMEZONE") or "Asia/Tashkent"


def _local_tz() -> tzinfo:
    try:
        from zoneinfo import ZoneInfo

        return ZoneInfo(TIMEZONE)
    except Exception:  # noqa: BLE001
        # Windows'da `tzdata` o'rnatilmagan bo'lsa IANA nomlari topilmaydi.
        # Toshkentda yozgi vaqt yo'q — doimiy +05:00.
        return timezone(timedelta(hours=5))


LOCAL_TZ = _local_tz()

DEFAULT_LIMIT = _int("PC_DEFAULT_LIMIT", 100)
MAX_LIMIT = _int("PC_MAX_LIMIT", 1000)
MAX_ROWS = _int("PC_MAX_ROWS", 20000)

#: Qism so'rovi tugagan hisoblanadigan holatlar — berilgani shu paytgacha
#: ishlatilgan yoki qaytarilgan bo'lishi kerak.
CLOSED_REQUEST_STATUSES = ("USED", "RETURNED")

LLM_ANALYZE = _flag("PC_LLM_ANALYZE", True)
LLM_ANALYZE_LIMIT = _int("PC_LLM_ANALYZE_LIMIT", 8)

# ------------------------------------------------------------- Pasport
#: Qo'lda yozilgan qism voqealari jadvali (CHAT_DB bazasida — ATIL ga
#: yozib bo'lmaydi).
HISTORY_TABLE = os.getenv("PC_HISTORY_TABLE") or "parts_component_event"

#: Spidometr ko'rsatkichi shuncha oxirgi o'lchovning MEDIANASI olinadi:
#: ikkitagacha xato raqam ("2 499 956 km", "45 025 km") hisobni buzmasin.
#: O'lchov oynasi, meyor emas.
READING_WINDOW = _int("PC_READING_WINDOW", 5)

#: Voqea sanasidan oldin o'lchov bo'lmasa, keyingi o'lchov faqat shuncha kun
#: ichida bo'lsa olinadi (xato ≤ shuncha kunlik yurish). Uzoqrog'i olinsa
#: 2025-03-01 dagi almashtirishga 2026-10 dagi "120 000 km" qo'yilib,
#: "o'shandan beri 0 km yurgan" bo'lib chiqardi (85058GAA, 29.10.2026).
READING_FALLBACK_DAYS = _int("PC_READING_FALLBACK_DAYS", 7)

#: O'rtacha kunlik yurish shuncha oxirgi kun bo'yicha — "qachon vaqti
#: keladi" taxmini uchun.
DAILY_RATE_DAYS = _int("PC_DAILY_RATE_DAYS", 90)

#: Sutkada yurib bo'ladigan ENG KO'P masofa: 24 soat to'xtovsiz ~60 km/soat.
#: Meyor emas — ishonchlilik chegarasi (zavod va viloyat yo'llaridagi park
#: uchun undan ortig'i ko'rsatkich xatosi). Bazada (28.10.2026): 85019GAA 2
#: kunda 9 464 → 15 664 km, 85482DBA da "kunlik o'rtacha" 5 949 km chiqqan.
MAX_KM_PER_DAY = _int("PC_MAX_KM_PER_DAY", 1500)

#: Motosoat sutkada 24 dan oshmaydi — sozlanmaydi. Bazada 85818AA
#: akkumulyatori 10 oyda "22 843 motosoat" ishlagan bo'lib chiqqan edi.
HOURS_PER_DAY = 24

#: Pasportdagi tarix va haydovchi davrlari — oxirgi shunchasi.
HISTORY_LIMIT = _int("PC_HISTORY_LIMIT", 50)
