"""Ehtiyot qismlarga talab prognozi — yaqin davrda qaysi qism qancha kerak.

IKKI USUL, ALOHIDA ko'rsatiladi (aralashtirilmaydi — vazn o'ylab topilmaydi):
  1. MUDDATI BO'YICHA — har bir o'rnatilgan shina/akkumulyatorning taxminiy
     tugash sanasi (pasport, `components[].parts`): resursi tugagani —
     "hozir", davr ichida tugaydigani — "davrda". Vaqti yaqin, lekin sanasi
     noma'lum (kunlik yurish yo'q) — alohida sanaladi, davrga qo'shilmaydi.
  2. O'TGAN SARF BO'YICHA — so'nggi 12 oyda shu o'lchamdan nechta qo'yilgan
     (`vehicle_part.installed_at`, bazaga kiritilgan kun emas) — oyiga
     o'rtacha. Almashtirilgan eski shina yozuvi bazada qolmaydi (`removed_at`
     bo'sh), shuning uchun bu sarfni KAM ko'rsatishi mumkin.

Ombor (`inventory_stock`) bilan o'lcham bo'yicha solishtiriladi: shina —
o'lcham kaliti (`rules.tire_size_key`: "12,00 -R20" = "12.00R20"),
akkumulyator — sig'im (Ah). Mos kelmasa "omborda shu o'lcham yo'q" —
o'xshashi taklif qilinmaydi.

Boshqa qismlar (moy, filtr, kolodka) — MIQDOR emas, XIZMAT soni: necha
mashinada vaqti keladi. Moy necha litr ketishi bazada yo'q.

Rejalashtirilgan ta'mirlardan — tasdiqlangan, lekin hali berilmagan qism
so'rovlari (`repair_order_part_request`) ro'yxati.
"""

from __future__ import annotations

import time
from collections import Counter, defaultdict
from datetime import date, datetime, timedelta
from typing import Any

from parts_control import config, passport, queries, rules, texts
from parts_control.passport import DUE_SOON, NO_INTERVAL, OVERDUE, UNKNOWN
from parts_control.texts import t
from vehicle_reference import components as cat

HISTORY_DAYS = 365
DEVICES = {"TIRES": "TIRE", "BATTERY": "BATTERY"}
#: Hali berilmagan so'rov — talab; yopilgan yoki rad etilgani — emas.
NOT_PENDING = (*config.CLOSED_REQUEST_STATUSES, "REJECTED", "CANCELLED")


def spec_of(category: str, name: str | None, size: str | None = None) -> str | None:
    if category == "TIRE":
        return rules.tire_size_key(size, name)
    ah = rules.battery_ah(name)
    return f"{ah} Ah" if ah else None


def when(status: str, due: date | None, until: date) -> str | None:
    """"now" — resursi tugagan; "horizon" — davr ichida tugaydi; "undated" —
    vaqti yaqin (80%+), lekin sanasi noma'lum; None — davrda kerak emas."""
    if status == OVERDUE:
        return "now"
    if due is not None and due <= until:
        return "horizon"
    if status == DUE_SOON and due is None:
        return "undated"
    return None


def _due(state: dict[str, Any]) -> date | None:
    dates = [d for d in (state.get("next_due_date"), state.get("estimated_due_date")) if d]
    return min(dates) if dates else None


def _counter() -> dict[str, Any]:
    return {"now": 0, "horizon": 0, "undated": 0, "vehicles": {}}


def _add_vehicle(group: dict[str, Any], plate: str, name: str, due: date | None,
                 status: str) -> None:
    row = group["vehicles"].setdefault(plate, {"plate_number": plate, "vehicle": name,
                                               "count": 0, "earliest_date": None,
                                               "overdue": 0})
    row["count"] += 1
    row["overdue"] += status == OVERDUE
    if due and (row["earliest_date"] is None or due < row["earliest_date"]):
        row["earliest_date"] = due


def collect(fleet: passport.Fleet, *, today: date, until: date, category: str | None,
            model: str | None) -> dict[str, Any]:
    """Park bo'yicha: o'lcham → kerakli donalar, qism → xizmatlar."""
    devices: dict[tuple[str, str | None], dict[str, Any]] = {}
    services: dict[str, dict[str, Any]] = {}
    unknown: Counter[str] = Counter()
    names: dict[str, str] = {}
    for vehicle in fleet.vehicles:
        name = passport._vehicle_name(vehicle)
        if model and model.lower() not in name.lower():
            continue
        names[vehicle["vehicle_id"]] = name
        plate = vehicle.get("plate_number") or vehicle["vehicle_id"][:8]
        for state in passport.vehicle_states(vehicle, fleet, today=today)["states"]:
            key = state["key"]
            device = DEVICES.get(key)
            if device and state.get("pieces"):
                if category and category != device:
                    continue
                for piece in state["pieces"]:
                    slot = when(piece["status"], piece["estimated_due_date"], until)
                    if slot is None:
                        continue
                    group = devices.setdefault(
                        (device, spec_of(device, piece["name"], piece["size"])), _counter())
                    group[slot] += 1
                    _add_vehicle(group, plate, name, piece["estimated_due_date"],
                                 piece["status"])
                continue
            if category:
                continue
            if state["status"] in (UNKNOWN, NO_INTERVAL):
                unknown[key] += 1
            slot = when(state["status"], _due(state), until)
            if slot is None:
                continue
            group = services.setdefault(key, _counter())
            group[slot] += 1
            _add_vehicle(group, plate, name, _due(state), state["status"])
    return {"devices": devices, "services": services, "unknown": unknown, "names": names}


def history(fleet: passport.Fleet, *, today: date, category: str | None,
            names: dict[str, str]) -> tuple[Counter, int]:
    """So'nggi 12 oyda o'lcham bo'yicha nechta qo'yilgan. Kelajakdagi sana
    (bazada 2027-04-02 da "qo'yilgan" shina) — xato, sanaladi, kirmaydi."""
    since = today - timedelta(days=HISTORY_DAYS)
    counts: Counter[tuple[str, str | None]] = Counter()
    future = 0
    for vehicle_id, parts in fleet.parts.items():
        if vehicle_id not in names:
            continue
        for part in parts:
            device = (part.get("category") or "").upper()
            if device not in ("TIRE", "BATTERY") or (category and device != category):
                continue
            day = passport._day(part.get("installed_at"))
            if day is None or rules.is_entry_date(part):
                continue
            if day > today:
                future += 1
            elif day >= since:
                counts[(device, spec_of(device, part.get("name"), part.get("tire_size")))] += 1
    return counts, future


def stock_by_spec() -> dict[tuple[str, str], dict[str, Any]]:
    out: dict[tuple[str, str], dict[str, Any]] = defaultdict(lambda: {"quantity": 0.0,
                                                                     "items": []})
    for row in queries.fetch_stock():
        device = rules.category_of(row.get("item_name"))
        if device not in ("TIRE", "BATTERY"):
            continue
        spec = spec_of(device, row.get("item_name"))
        qty = rules.num(row.get("quantity"))
        if spec is None or not qty:
            continue
        entry = out[(device, spec)]
        entry["quantity"] += qty
        entry["items"].append({"name": row.get("item_name"), "quantity": qty,
                               "unit": row.get("unit_of_measure"),
                               "warehouse": row.get("warehouse_name")})
    return out


def pending_requests(fleet: passport.Fleet, names: dict[str, str],
                     plates: dict[str, str]) -> list[dict[str, Any]]:
    rows = []
    for vehicle_id, requests in fleet.requests.items():
        if vehicle_id not in names:
            continue
        for r in requests:
            if (r.get("status") or "").upper() in NOT_PENDING:
                continue
            rows.append({"item_name": r.get("item_name"), "status": r.get("status"),
                         "requested_at": passport._day(r.get("requested_at")),
                         "plate_number": plates.get(vehicle_id), "vehicle": names[vehicle_id]})
    return sorted(rows, key=lambda r: r["requested_at"] or date.min)


def _vehicles(group: dict[str, Any]) -> list[dict[str, Any]]:
    return sorted(group["vehicles"].values(),
                  key=lambda v: (-v["overdue"], v["earliest_date"] or date.max))


def build(*, days: int = 90, category: str | None = None, model: str | None = None,
          lang: str = texts.DEFAULT_LANG) -> dict[str, Any]:
    started = time.perf_counter()
    lang = texts.normalize(lang)
    today = date.today()
    until = today + timedelta(days=days)
    category = category.upper() if category else None
    fleet = passport.load_fleet()
    plates = {v["vehicle_id"]: v.get("plate_number") or v["vehicle_id"][:8]
              for v in fleet.vehicles}
    found = collect(fleet, today=today, until=until, category=category, model=model)
    installed, future = history(fleet, today=today, category=category, names=found["names"])
    stock = stock_by_spec()

    items = []
    for key in set(found["devices"]) | set(installed):
        device, spec = key
        group = found["devices"].get(key) or _counter()
        total = group["now"] + group["horizon"]
        stock_qty = stock[key]["quantity"] if spec and key in stock else (0.0 if spec else None)
        past = installed.get(key, 0)
        avg = past / 12
        item = {
            "category": device, "spec": spec,
            "needed_now": group["now"], "needed_in_period": group["horizon"],
            "needed_total": total, "due_soon_undated": group["undated"],
            "vehicles": _vehicles(group),
            "stock_quantity": stock_qty,
            "stock_items": stock[key]["items"] if spec and key in stock else [],
            "shortage": max(0.0, total - stock_qty) if stock_qty is not None else None,
            "installed_last_12m": past, "avg_per_month": round(avg, 1),
            "expected_by_history": round(avg * days / 30.4375, 1),
        }
        item["text"] = item_text(item, days, lang)
        items.append(item)
    items.sort(key=lambda i: (-i["needed_total"], -i["expected_by_history"], i["spec"] or "~"))

    services = []
    for key, group in found["services"].items():
        name = cat.COMPONENTS[key].name(lang) if key in cat.COMPONENTS else key
        row = {"component": key, "name": name, "needed_now": group["now"],
               "needed_in_period": group["horizon"], "due_soon_undated": group["undated"],
               "vehicles": _vehicles(group)}
        row["text"] = t(lang, "forecast.service", name=name, now=row["needed_now"],
                        horizon=row["needed_in_period"], days=days,
                        undated=t(lang, "forecast.undated_tail", count=row["due_soon_undated"])
                        if row["due_soon_undated"] else "")
        services.append(row)
    services.sort(key=lambda s: -(s["needed_now"] + s["needed_in_period"]))

    not_forecast = [
        {"component": key, "name": cat.COMPONENTS[key].name(lang) if key in cat.COMPONENTS
         else key, "vehicles": count}
        for key, count in found["unknown"].most_common()
    ]
    notes = [t(lang, "note.forecast_method", days=days), t(lang, "note.forecast_history_low")]
    if not_forecast:
        notes.append(t(lang, "note.forecast_no_data", count=len(not_forecast)))
    if future:
        notes.append(t(lang, "note.forecast_future_dates", count=future))
    if fleet.manual_error:
        notes.append(t(lang, "note.passport_history_error", error=fleet.manual_error))

    summary = {
        "vehicles": len(found["names"]),
        "tires_needed": sum(i["needed_total"] for i in items if i["category"] == "TIRE"),
        "batteries_needed": sum(i["needed_total"] for i in items if i["category"] == "BATTERY"),
        "shortage_specs": sum(1 for i in items if i["shortage"]),
        "services_due": sum(s["needed_now"] + s["needed_in_period"] for s in services),
    }
    if category:
        # Faqat bir tur so'ralgan — "0 dona shina kerak" deb chalg'itmasin.
        summary["text"] = t(lang, "forecast.summary_one", days=days,
                            vehicles=summary["vehicles"],
                            what=t(lang, f"forecast.cat.{category}"),
                            count=summary["tires_needed" if category == "TIRE"
                                          else "batteries_needed"],
                            shortage=summary["shortage_specs"])
    else:
        summary["text"] = t(lang, "forecast.summary", days=days, vehicles=summary["vehicles"],
                            tires=summary["tires_needed"],
                            batteries=summary["batteries_needed"],
                            shortage=summary["shortage_specs"],
                            services=summary["services_due"])
    return {
        "generated_at": datetime.now(), "days": days, "from": today, "until": until,
        "category": category, "model": model, "summary": summary, "items": items,
        "services": services,
        "pending_requests": pending_requests(fleet, found["names"], plates),
        "not_forecast": not_forecast, "notes": notes,
        "elapsed_seconds": round(time.perf_counter() - started, 3),
    }


def item_text(item: dict[str, Any], days: int, lang: str) -> str:
    """"Shina 215/75R17.5: 12 dona kerak (8 tasi hozir, 4 tasi 90 kun ichida);
    omborda 48 — yetadi; o'tgan 12 oyda 30 ta qo'yilgan — oyiga ~2.5"."""
    def n(value: float) -> str:
        return rules.fmt(value)

    head = f"{t(lang, 'forecast.cat.' + item['category'])} " \
           f"{item['spec'] or t(lang, 'forecast.spec_unknown')}"
    parts = []
    if item["needed_total"]:
        detail = ([t(lang, "forecast.need_now", count=item["needed_now"])]
                  if item["needed_now"] else []) + \
                 ([t(lang, "forecast.need_period", count=item["needed_in_period"], days=days)]
                  if item["needed_in_period"] else [])
        parts.append(t(lang, "forecast.need", total=item["needed_total"],
                       detail=", ".join(detail)))
    else:
        parts.append(t(lang, "forecast.none_due", days=days))
    if item["due_soon_undated"]:
        parts.append(t(lang, "forecast.undated", count=item["due_soon_undated"]))
    if item["stock_quantity"] is None:
        parts.append(t(lang, "forecast.stock_unknown"))
    elif item["stock_quantity"] == 0:
        parts.append(t(lang, "forecast.stock_none"))
    else:
        parts.append(t(lang, "forecast.stock", qty=n(item["stock_quantity"])))
    if item["shortage"]:
        parts.append(t(lang, "forecast.shortage", qty=n(item["shortage"])))
    elif item["needed_total"] and item["stock_quantity"]:
        parts.append(t(lang, "forecast.enough"))
    if item["installed_last_12m"]:
        parts.append(t(lang, "forecast.history", count=item["installed_last_12m"],
                       avg=n(item["avg_per_month"]), days=days,
                       expected=n(item["expected_by_history"])))
    return f"{head}: " + "; ".join(parts)
