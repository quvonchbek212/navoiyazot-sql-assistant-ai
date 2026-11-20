"""Qismlar hisobotini bir xatboshi xulosaga aylantirish — shablon va LLM.

Aniqlashni `rules.py` qiladi; LLM faqat tayyor topilmalarni gapga soladi.
LLM ishlamasa shablon xulosa qoladi.
"""

from __future__ import annotations

import json
import logging
import sys
from pathlib import Path
from typing import Any

_CHATBOT_DIR = Path(__file__).resolve().parent.parent / "atil_chatbot"
if str(_CHATBOT_DIR) not in sys.path:
    sys.path.insert(0, str(_CHATBOT_DIR))

from parts_control import config, texts  # noqa: E402
from parts_control.texts import t  # noqa: E402

logger = logging.getLogger(__name__)

PROMPT = """Sen korxona avtoparkida ehtiyot qismlar o'zlashtirilishini
tekshiradigan auditorning yordamchisisan.

Quyida ALLAQACHON TOPILGAN holatlar berilgan: mashinaga mos kelmaydigan
qism (MISMATCH), resursidan oldin almashtirish (EARLY), berilgan lekin
hisobdan o'tmagan qism (CONTROL). Ularni qayta hisoblamaysan.

Vazifang: 3 ta qisqa jumla yoz.
1-jumla: umumiy manzara.
2-jumla: birinchi navbatda qaysi so'rov va qaysi mashinani tekshirish
         kerak — davlat raqami va qism nomi bilan, sababini qisqa ayt.
3-jumla: "tekshirilmagan" bo'sh bo'lmasa — nima tekshirilmaganini ayt.

{language_rule}

QAT'IY QOIDALAR:
- Faqat berilgan ma'lumotdan foydalan, yangi raqam O'YLAB TOPMA.
- Hech kimni o'g'ri DEMA: "tekshirish kerak", "izohlab berishi kerak" de.
- Sarlavha va ro'yxat belgisi yozma.

MA'LUMOT (JSON):
{facts}

XULOSA:"""


def template_analysis(report: dict[str, Any], lang: str = texts.DEFAULT_LANG) -> str:
    summary = report.get("summary") or {}
    notes = (report.get("data_quality") or {}).get("notes") or []
    by_kind = _kinds_per_request(report.get("requests") or [])
    lines: list[str] = []
    if not summary.get("flagged_requests") and not summary.get("flagged_installed"):
        lines.append(t(lang, "analysis.nothing", requests=summary.get("requests") or 0,
                       parts=summary.get("installed_parts") or 0))
    else:
        if summary.get("flagged_requests"):
            lines.append(t(lang, "analysis.found", requests=summary.get("requests") or 0,
                           flagged=summary["flagged_requests"],
                           mismatch=by_kind.get("MISMATCH", 0), early=by_kind.get("EARLY", 0),
                           control=by_kind.get("CONTROL", 0)))
        codes = summary.get("by_code") or {}
        if codes.get("WORN_EARLY") or codes.get("OVER_LIFE"):
            lines.append(t(lang, "analysis.installed", early=codes.get("WORN_EARLY", 0),
                           over=codes.get("OVER_LIFE", 0)))
    unchecked = [n for n in notes if texts.is_unchecked(n)]
    if unchecked:
        lines.append(t(lang, "analysis.attention", note=unchecked[0]))
    return " ".join(lines)


def _kinds_per_request(items: list[dict[str, Any]]) -> dict[str, int]:
    """So'rovlar bo'yicha tur soni — bitta so'rov bir turda bir marta."""
    out: dict[str, int] = {}
    for item in items:
        for kind in {f["kind"] for f in item.get("flags") or []}:
            out[kind] = out.get(kind, 0) + 1
    return out


def fill_template(report: dict[str, Any], lang: str = texts.DEFAULT_LANG) -> None:
    report["analysis"] = {
        "text": template_analysis(report, lang),
        "source": "template",
        "items_considered": len(report.get("requests") or []),
    }


def _facts(report: dict[str, Any], limit: int) -> dict[str, Any]:
    notes = (report.get("data_quality") or {}).get("notes") or []
    return {
        "sorovlar": [
            {"mashina": i.get("plate_number"), "rusum": i.get("vehicle"),
             "qism": i.get("item_name"), "belgilar": [f["title"] + ": " + f["detail"]
                                                      for f in i["flags"]]}
            for i in (report.get("requests") or []) if i.get("flags")
        ][:limit],
        "ornatilgan": [
            {"mashina": i.get("plate_number"), "qism": i.get("name"),
             "belgilar": [f["title"] for f in i["flags"]]}
            for i in (report.get("installed") or [])
        ][:limit],
        "jami": report.get("summary"),
        "tekshirilmagan": [n for n in notes if texts.is_unchecked(n)],
    }


async def analyze(report: dict[str, Any], *, lang: str = texts.DEFAULT_LANG) -> None:
    summary = report.get("summary") or {}
    if not summary.get("flagged_requests") and not summary.get("flagged_installed"):
        return

    from config import DEFAULT_NUM_CTX  # chatbot config (atil_chatbot/config.py)
    from ollama_client import ask_llm

    prompt = PROMPT.format(
        language_rule=texts.llm_instruction(lang),
        facts=json.dumps(_facts(report, config.LLM_ANALYZE_LIMIT), ensure_ascii=False,
                         indent=2, default=str),
    )
    try:
        text = await ask_llm(prompt, {
            "options": {"temperature": 0.2, "num_predict": 220, "num_ctx": DEFAULT_NUM_CTX},
            "think": False,
        })
    except Exception as exc:  # noqa: BLE001
        logger.warning("LLM xulosasi olinmadi (%s) — shablon qoldi", str(exc)[:160])
        return
    cleaned = (text or "").strip()
    if cleaned:
        report["analysis"] = {"text": cleaned, "source": "llm",
                              "items_considered": summary.get("flagged_requests") or 0}
