"""Mashinaning ish profili — qancha yurgan, ishlagan, turgan va qancha yuk tashigan.

NIMA UCHUN KERAK. Qism qachon almashtirilishi yurishga bog'liq: "shina
qachongacha chidaydi?" degan savolga mashina kuniga qancha yurishini
bilmasdan javob berib bo'lmaydi.

MANBALAR (bazada 29.10.2026):
  * km — ikki manbadan, IKKALASI ham ko'rsatiladi: spidometr o'lchovlari
    (yo'l varaqasi, texnik ko'rik) va reyslar yig'indisi (`trip`). Ular mos
    kelmasligi mumkin (85681DBA Damas: 30 kunda 2 123 / 1 715 km) — qaysi
    biri to'g'riligini tizim bilmaydi;
  * ishlagan kun — bajarilgan reys yoki yo'l varaqasi bor kun; ta'mirda
    turgan kun — `vehicle_repair` ochilgan-yopilgan oraliq;
  * yuk — yo'l varaqasi yoki uning topshiriqlarida (4 011 dan 23 tasida).

Reys yozila boshlagan kundan (2026-08-19) oldingi kunlar "turgan" emas —
"ma'lumot yo'q". Rejadagi muddatiga sutkasiga `MAX_KM_PER_DAY` dan ko'p
to'g'ri keladigan reys yig'indiga kirmaydi.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Any, Sequence

from parts_control import config, rules

#: Ish profili qaysi davrlar bo'yicha (kun) — o'lchov oynasi, me'yor emas.
PERIODS = (30, 90)

DONE_TRIP = "COMPLETED"
CLOSED_REPAIR = ("CANCELLED", "REJECTED")

Series = Sequence[tuple[date, float]]
Spans = Sequence[tuple[date, date]]


def _day(value: Any) -> date | None:
    if isinstance(value, datetime):
        return value.date()
    return value if isinstance(value, date) else None


def repair_days(repairs: Sequence[dict[str, Any]], today: date) -> set[date]:
    """Ta'mirda turgan kunlar: ochilgandan yopilguncha (ochiq bo'lsa — bugungacha)."""
    days: set[date] = set()
    for row in repairs:
        if (row.get("status") or "").upper() in CLOSED_REPAIR:
            continue
        start = _day(row.get("opened_at")) or _day(row.get("detected_at"))
        end = _day(row.get("completed_at")) or _day(row.get("repaired_at")) or today
        if start is None or end < start:
            continue
        days.update(start + timedelta(days=i) for i in range((min(end, today) - start).days + 1))
    return days


def span_days(row: dict[str, Any]) -> int:
    """Reys necha kalendar kun — REJA bo'yicha (bo'lmasa haqiqiy). Reys kech
    yopilishi mumkin: R-000905 (85019GAA) rejada 09.09 03:00–14:00, yopilgani
    15.09 — 7 kunga 6 204 km "imkonli" ko'rinardi, aslida spidometr sakrashi."""
    for a, b in (("plan_day", "plan_end"), ("day", "end_day")):
        start, end = _day(row.get(a)), _day(row.get(b))
        if start and end and end >= start:
            return (end - start).days + 1
    return 1


def _trusted(value: float | None, days: int, per_day: float) -> bool | None:
    """None — qiymat yo'q; False — sutkasiga jismonan imkonsiz."""
    if value is None or value <= 0:
        return None
    return value <= days * per_day


def _delta(series: Series, jumps: Spans, start: date, end: date) -> float | None:
    """Davrdagi ko'rsatkich farqi — tozalangan zanjirdan. Noma'lum (None): davr
    ichida uzilish bor, boshida o'lchov yo'q yoki davrda YANGI o'lchov yo'q
    (85019GAA: oxirgisi 30.09 — "0 km" yurmagan degani emas)."""
    if any(b >= start for _, b in jumps):
        return None
    before = [(d, v) for d, v in series if d <= start]
    limit = start + timedelta(days=config.READING_FALLBACK_DAYS)
    first = before[-1] if before else next(((d, v) for d, v in series if start < d <= limit),
                                            None)
    last = next(((d, v) for d, v in reversed(series) if d <= end), None)
    if first is None or last is None or last[0] <= first[0]:
        return None
    return round(last[1] - first[1], 1)


def period(
    days: int, *, today: date, data_start: date | None, trips: Sequence[dict[str, Any]],
    waybills: Sequence[dict[str, Any]], repairs: set[date], km: Series, hours: Series,
    km_jumps: Spans, hours_jumps: Spans,
) -> dict[str, Any]:
    """Bitta davr (`days` kun, bugun ham kiradi). `km`/`hours` — tozalangan
    o'lchovlar zanjiri, `*_jumps` — undagi fizik uzilishlar."""
    start = today - timedelta(days=days - 1)
    covered_from = max(start, data_start) if data_start else start
    covered = max(0, (today - covered_from).days + 1)

    def inside(d: date | None) -> bool:
        return d is not None and covered_from <= d <= today

    done = [t for t in trips if (t.get("status") or "").upper() == DONE_TRIP
            and inside(_day(t.get("day")))]
    km_trips, hours_trips, suspicious = 0.0, 0.0, 0
    km_seen = hours_seen = False
    for t in done:
        span = span_days(t)
        km_value, hours_value = rules.num(t.get("km")), rules.num(t.get("hours"))
        ok_km = _trusted(km_value, span, config.MAX_KM_PER_DAY)
        ok_hours = _trusted(hours_value, span, config.HOURS_PER_DAY)
        suspicious += (ok_km is False) or (ok_hours is False)
        if ok_km:
            km_trips += km_value
            km_seen = True
        if ok_hours:
            hours_trips += hours_value
            hours_seen = True

    sheets = [w for w in waybills if inside(_day(w.get("day")))]
    active = {_day(t.get("day")) for t in done} | {_day(w.get("day")) for w in sheets}
    in_repair = {d for d in repairs if inside(d)}

    cargo = [rules.num(w.get("cargo_tons")) or rules.num(w.get("task_tons")) for w in sheets]
    cargo = [c for c in cargo if c]

    return {
        "days": days, "from": start, "to": today,
        "data_from": covered_from if covered else None, "covered_days": covered,
        # Spidometr ham reyslar bilan bir oraliqda — ma'lumot boshlangan kundan.
        "km_odometer": _delta(km, km_jumps, covered_from, today) if covered else None,
        "km_trips": round(km_trips, 1) if km_seen else None,
        "engine_hours_odometer": _delta(hours, hours_jumps, covered_from, today)
        if covered else None,
        "engine_hours_trips": round(hours_trips, 1) if hours_seen else None,
        "trips": len(done), "waybills": len(sheets),
        "active_days": len(active), "repair_days": len(in_repair),
        "idle_days": max(0, covered - len(active | in_repair)),
        "suspicious_trips": suspicious,
        "cargo_waybills": len(cargo), "cargo_tons": round(sum(cargo), 2) if cargo else None,
        "daily_km_trips": round(km_trips / covered, 1) if km_seen and covered else None,
    }


def period_text(p: dict[str, Any], lang: str, axes: tuple[bool, bool] = (True, True)) -> str:
    """Bitta davr — bir gap. Motosoat texnikasida km emas, motosoat."""
    from parts_control.texts import t

    unit = "km" if axes[0] or not axes[1] else "hours"
    odometer = p["km_odometer"] if unit == "km" else p["engine_hours_odometer"]
    by_trips = p["km_trips"] if unit == "km" else p["engine_hours_trips"]

    def value(v: float | None) -> str:
        if v is None:
            return t(lang, "word.unknown")
        return t(lang, f"unit.{unit}", v=f"{v:,.0f}".replace(",", " "))

    since = (t(lang, "usage.since", day=p["data_from"])
             if p["data_from"] and p["data_from"] > p["from"] else "")
    cargo = (t(lang, "usage.cargo", tons=p["cargo_tons"], count=p["cargo_waybills"])
             if p["cargo_tons"] else t(lang, "usage.cargo_none"))
    return t(lang, "usage.period", days=p["days"], since=since, meter=t(lang, f"usage.meter_{unit}"),
             km_odometer=value(odometer), km_trips=value(by_trips), trips=p["trips"],
             active=p["active_days"], idle=p["idle_days"], repair=p["repair_days"], cargo=cargo)


def profile(
    *, today: date, data_start: date | None, trips: Sequence[dict[str, Any]],
    waybills: Sequence[dict[str, Any]], repairs: Sequence[dict[str, Any]],
    km: Series, hours: Series, km_jumps: Spans, hours_jumps: Spans,
    periods: Sequence[int] = PERIODS,
) -> dict[str, Any]:
    in_repair = repair_days(repairs, today)
    return {
        "data_start": data_start,
        "periods": [period(d, today=today, data_start=data_start, trips=trips,
                           waybills=waybills, repairs=in_repair, km=km, hours=hours,
                           km_jumps=km_jumps, hours_jumps=hours_jumps) for d in periods],
    }
