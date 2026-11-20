"""Almashtirish tekshiruvi — qism so'ralganda: asosli yoki avval tekshirish kerakmi.

NIMA UCHUN. Qism o'zlashtirilishining bir yo'li — resursi tugamagan qismni
"almashtirish": 85058GAA ning 4 ta shinasi 2026-04-10 da qo'yilgan, 4 760 km
yurgan (60 000 km resursning 7.9%). Yana 4 ta shina so'ralsa tizim "oxirgi
marta qachon, qancha yurgan, yana qancha yurishi kerak edi" deb aytishi kerak
— BERISHDAN OLDIN, so'rov ATIL ga tushib, `/scan` ushlaguncha emas.

XULOSA (har dona yoki qism):
  * JUSTIFIED (asosli) — resursi tugagan, ATIL da "yeyilgan" deb belgilangan
    yoki korxona chegarasidan (80%, `warning_at_percent`) o'tgan;
  * CHECK (tekshiring) — chegaradan past: yaqinda almashtirilgan;
  * NO_DATA — oldingi almashtirish yoki oraliq yo'q (taxmin qilinmaydi).
"Berma" deyilmaydi: shikast (teshilish, yorilish) haqiqiy sabab bo'lishi
mumkin — xulosa "avval tekshiring" va nima talab qilishni aytadi.

Bir nechta dona so'ralsa (4 ta shina) — avval asoslilari, keyin ma'lumoti
yo'qlari, oxirida yaqinda qo'yilganlari olinadi: 2 tasi asosli bo'lsa ham
qolgan 2 tasi uchun "tekshiring".
"""

from __future__ import annotations

import time
from datetime import date, datetime
from typing import Any

from parts_control import passport, queries, rules, texts
from parts_control.passport import DUE_SOON, NO_INTERVAL, OK, OVERDUE, UNKNOWN
from parts_control.texts import t
from vehicle_reference import components as cat

JUSTIFIED, CHECK, NO_DATA = "JUSTIFIED", "CHECK", "NO_DATA"
#: Bir nechta dona so'ralganda qaysi biri birinchi "almashtiriladi".
_ORDER = {JUSTIFIED: 0, NO_DATA: 1, CHECK: 2}
DEVICES = {"TIRES": "TIRE", "BATTERY": "BATTERY"}


def piece_verdict(piece: dict[str, Any]) -> str:
    if (piece.get("record_status") or "").upper() == "WORN" \
            or piece["status"] in (OVERDUE, DUE_SOON):
        return JUSTIFIED
    if piece.get("used_pct") is None:
        return NO_DATA
    return CHECK


def state_verdict(status: str) -> str:
    if status in (OVERDUE, DUE_SOON):
        return JUSTIFIED
    return CHECK if status == OK else NO_DATA


def _ago(day: date | None, today: date, lang: str) -> str:
    if day is None:
        return "—"
    days = (today - day).days
    if days < 31:
        return t(lang, "check.ago", v=t(lang, "check.days", v=days))
    return t(lang, "check.ago", v=t(lang, "unit.months", v=rules.fmt(round(days / 30.4375, 1))))


def _unit(axis: str, value: float | None, lang: str) -> str:
    if value is None:
        return "—"
    v = rules.fmt(round(value, 1)) if axis == "months" else f"{value:,.0f}".replace(",", " ")
    return t(lang, f"unit.{axis}", v=v)


def _source_title(source: dict[str, str] | None) -> str:
    """Xulosada qisqa nom (ikki nuqtagacha); to'liq tavsif va havola — `sources` da."""
    return ((source or {}).get("title") or "—").split(":")[0].strip()


def _warranty(device: str, transport_type: str | None, months_used: float | None,
              lang: str) -> str | None:
    """Kafolat ichidami: akkumulyator — GOST R 53165 (24 oy), yengil avtomobil
    shinasi — GOST 4754 (5 yil). Boshqasi uchun manba yo'q — aytilmaydi."""
    life = rules.life_of({"category": device}, transport_type)
    months = life.get("warranty_months", (None, None))[0]
    if months_used is None or not months or months_used >= months:
        return None
    return t(lang, "check.rec.warranty", used=_unit("months", months_used, lang),
             warranty=_unit("months", months, lang))


def _piece_item(p: dict[str, Any], today: date, lang: str) -> dict[str, Any]:
    verdict = piece_verdict(p)
    # Sanasi bazaga kiritilgan kun bo'lsa "N kun oldin" demaymiz — u qo'yilgan kun emas.
    entry = bool(p.get("entry_date"))
    return {"name": p.get("name"), "installed_at": p.get("installed_at"), "entry_date": entry,
            "ago": None if entry else _ago(p.get("installed_at"), today, lang),
            "status": p["status"],
            "verdict": verdict, "used_pct": p.get("used_pct"),
            "since_km": p.get("since_km"), "since_months": p.get("since_months"),
            "since_hours": p.get("since_hours"), "remaining_km": p.get("remaining_km"),
            "remaining_months": p.get("remaining_months"),
            "remaining_hours": p.get("remaining_hours"),
            "life_source": p.get("life_source"), "text": p.get("text") or ""}


def _component_text(c: dict[str, Any], verdict: str, today: date, lang: str,
                    axes: tuple[bool, bool], deciding: str | None = None) -> str:
    """`deciding` — foizni qaysi o'lchov bergan (pasport `by`): km, months, hours."""
    last = c.get("last_replaced") or {}
    day = last.get("date")
    if verdict == JUSTIFIED:
        return t(lang, "check.due", detail=c["detail"])
    if c["status"] == NO_INTERVAL:
        if day:
            return t(lang, "check.no_interval", date=day, ago=_ago(day, today, lang))
        return t(lang, "check.no_history", standard="")
    by = None
    for axis in ("km", "months", "hours"):
        if c.get(f"interval_{axis}") and (axis != "km" or axes[0]) \
                and (axis != "hours" or axes[1]):
            by = by or axis
    if c["status"] == UNKNOWN or by is None:
        standard = (t(lang, "check.standard", life=_unit(by, c[f"interval_{by}"], lang),
                      source=_source_title(c.get("interval_source"))) if by else "")
        return t(lang, "check.no_history", standard=standard)
    # OK — yaqinda almashtirilgan. Qaysi o'lchov hal qilsa o'sha bilan.
    used = {"km": c.get("since_km"), "months": c.get("since_months"),
            "hours": c.get("since_hours")}
    if deciding not in used or used.get(deciding) is None:
        deciding = next((a for a in ("km", "months", "hours")
                         if c.get(f"interval_{a}") and used[a] is not None), by)
    life = c.get(f"interval_{deciding}")
    left = life - used[deciding] if life and used[deciding] is not None else None
    return t(lang, "check.early", date=day, ago=_ago(day, today, lang),
             since=_unit(deciding, used[deciding], lang), life=_unit(deciding, life, lang),
             source=_source_title(c.get("interval_source")), left=_unit(deciding, left, lang),
             pct=rules.fmt(c.get("used_pct")))


def evaluate(vehicle_id: str, component: str, *, quantity: int | None = None,
             lang: str = texts.DEFAULT_LANG, today: date | None = None) -> dict[str, Any]:
    started = time.perf_counter()
    lang = texts.normalize(lang)
    today = today or date.today()
    component = component.upper()
    vehicles = queries.fetch_vehicles([vehicle_id])
    if not vehicles:
        raise passport.NotFound(f"Mashina topilmadi: {vehicle_id}")
    vehicle = vehicles[0]
    fleet = passport.load_fleet([vehicle_id], vehicles=vehicles)
    result = passport.vehicle_states(vehicle, fleet, today=today)
    axes = passport.usage_axes(vehicle.get("usage_mode"))
    plate = vehicle.get("plate_number") or vehicle_id[:8]
    name = passport._vehicle_name(vehicle)
    comp = cat.COMPONENTS.get(component)
    comp_name = comp.name(lang) if comp else component
    head_vehicle = {"vehicle_id": vehicle_id, "plate_number": plate, "vehicle": name,
                    "class": result["class"]}

    state = next((s for s in result["states"] if s["key"] == component), None)
    if state is None:
        return {"generated_at": datetime.now(), "vehicle": head_vehicle, "component": component,
                "name": comp_name, "requested_quantity": quantity or 1, "verdict": NO_DATA,
                "verdict_text": t(lang, "check.verdict.NO_DATA"), "counts": {}, "items": [],
                "conclusion": t(lang, "check.not_tracked", name=comp_name),
                "recommendations": [t(lang, "check.rec.inspect")], "sources": [],
                "elapsed_seconds": round(time.perf_counter() - started, 3)}
    rendered = passport.render_state(state, lang, axes)
    device = DEVICES.get(component)
    lines: list[str] = []
    recs: list[str] = []
    sources: list[dict[str, str]] = []

    if device and rendered["parts"]:
        pairs = sorted(((_piece_item(p, today, lang), p) for p in rendered["parts"]),
                       key=lambda ip: (_ORDER[ip[0]["verdict"]], -(ip[0]["used_pct"] or 0)))
        items = [i for i, _ in pairs]
        count = quantity or len(items)
        taken = items[:count]
        extra = max(0, count - len(items))
        counts = {v: sum(1 for i in taken if i["verdict"] == v) for v in _ORDER}
        counts["extra"] = extra
        verdict = CHECK if counts[CHECK] or extra else NO_DATA if counts[NO_DATA] else JUSTIFIED

        def ago(p: dict[str, Any]) -> str:
            return "" if p.get("entry_date") else f" ({_ago(p.get('installed_at'), today, lang)})"

        for group in (JUSTIFIED, CHECK, NO_DATA):
            chosen = [p for i, p in pairs[:count] if i["verdict"] == group]
            if chosen:
                lines.append(t(lang, f"check.group.{group}", count=len(chosen)))
                lines += [f"- {line}" for line in passport.group_pieces(
                    chosen, lang, axes, rate_note=False, suffix=ago)]
        if any(passport.needs_rate_note(p) for _, p in pairs[:count]):
            lines.append(t(lang, "piece.no_rate_once"))
        if extra:
            lines.append(t(lang, "check.extra", installed=len(items), count=count, extra=extra))
        months_used = min((i["since_months"] for i in taken
                           if i["verdict"] == CHECK and i["since_months"] is not None),
                          default=None)
        sources = [i["life_source"] for i in taken if i.get("life_source")]
        head = t(lang, "check.head", plate=plate, vehicle=name, name=comp_name, count=count,
                 verdict=t(lang, f"check.verdict.{verdict}"))
        out_items = items
    else:
        verdict = state_verdict(rendered["status"])
        counts = {JUSTIFIED: int(verdict == JUSTIFIED), CHECK: int(verdict == CHECK),
                  NO_DATA: int(verdict == NO_DATA), "extra": 0}
        lines.append(_component_text(rendered, verdict, today, lang, axes, state.get("by")))
        months_used = rendered.get("since_months")
        if rendered.get("interval_source"):
            sources = [rendered["interval_source"]]
        head = t(lang, "check.head_one", plate=plate, vehicle=name, name=comp_name,
                 verdict=t(lang, f"check.verdict.{verdict}"))
        last = rendered.get("last_replaced") or {}
        out_items = [{"name": comp_name, "installed_at": last.get("date"), "entry_date": False,
                      "ago": _ago(last.get("date"), today, lang), "status": rendered["status"],
                      "verdict": verdict, "used_pct": rendered.get("used_pct"),
                      "since_km": rendered.get("since_km"),
                      "since_months": rendered.get("since_months"),
                      "since_hours": rendered.get("since_hours"),
                      "remaining_km": rendered.get("remaining_km"), "remaining_months": None,
                      "remaining_hours": None, "life_source": rendered.get("interval_source"),
                      "text": lines[-1]}]
        count = 1

    if verdict == CHECK:
        recs += [t(lang, "check.rec.inspect"), t(lang, "check.rec.act")]
        warranty = _warranty(device, vehicle.get("transport_type"), months_used, lang) \
            if device else None
        if warranty:
            recs.append(warranty)
    elif verdict == NO_DATA:
        recs.append(t(lang, "check.rec.inspect"))
    recs += [t(lang, "check.rec.return_old"), t(lang, "check.rec.record")]
    unique_sources = list({s["title"]: s for s in sources if s}.values())
    return {
        "generated_at": datetime.now(), "vehicle": head_vehicle, "component": component,
        "name": comp_name, "requested_quantity": count, "verdict": verdict,
        "verdict_text": t(lang, f"check.verdict.{verdict}"),
        "counts": {k.lower(): v for k, v in counts.items()}, "items": out_items,
        "conclusion": "\n".join([head, *lines]), "recommendations": recs,
        "sources": unique_sources, "elapsed_seconds": round(time.perf_counter() - started, 3),
    }


def early_warning(vehicle_id: str, component: str, *, lang: str = texts.DEFAULT_LANG,
                  today: date | None = None) -> list[str]:
    """POST da almashtirish yozilayotganda: avvalgisi hali yaroqli bo'lsa —
    ogohlantirish (yozuv RAD ETILMAYDI, shikast haqiqiy sabab bo'lishi mumkin)."""
    result = evaluate(vehicle_id, component, lang=lang, today=today)
    if result["verdict"] != CHECK:
        return []
    return [t(lang, "check.warning", text=result["conclusion"])]
