"""Orkestratsiya — qism so'rovlari, o'rnatilgan qismlar va rusum resursi.

BU FAYLDA SQL YO'Q (`queries.py`) va HISOB YO'Q (`rules.py`).
"""

from __future__ import annotations

import logging
import time
from collections import Counter, defaultdict
from datetime import date, datetime
from typing import Any

from parts_control import config, queries, rules, texts
from parts_control.texts import t
from vehicle_reference import specs

logger = logging.getLogger(__name__)


def _source(key: str | None) -> dict[str, str] | None:
    return specs.source_info(key)


def _vehicle(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "vehicle_id": row.get("vehicle_id"),
        "plate_number": row.get("plate_number"),
        "vehicle": rules.vehicle_name(row.get("brand"), row.get("model")),
        "transport_type": row.get("transport_type"),
    }


def scan(
    *,
    date_from: date,
    date_to: date,
    vehicle_id: str | None = None,
    category: str | None = None,
    limit: int = config.DEFAULT_LIMIT,
    lang: str = texts.DEFAULT_LANG,
) -> dict[str, Any]:
    """Davrdagi qism so'rovlari + hozir o'rnatilgan qismlarning holati."""
    started = time.perf_counter()
    lang = texts.normalize(lang)
    today = date.today()
    category = (category or "").upper() or None

    requests_all = queries.fetch_requests(date_to, vehicle_id)
    # Rusum bo'yicha solishtirish (akkumulyator sig'imi) uchun butun park kerak.
    parts_all = queries.fetch_installed()
    parts_by_vehicle: dict[str, list[dict[str, Any]]] = defaultdict(list)
    parts_by_model: dict[str, list[dict[str, Any]]] = defaultdict(list)
    parts_by_type: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for part in parts_all:
        parts_by_vehicle[part["vehicle_id"]].append(part)
        parts_by_model[rules.model_key(part.get("brand"), part.get("model"))].append(part)
        parts_by_type[(part.get("transport_type") or "").upper()].append(part)

    vehicle_ids = sorted({r["vehicle_id"] for r in requests_all if r.get("vehicle_id")})
    odometer: dict[str, list[tuple[date, float]]] = defaultdict(list)
    for row in queries.fetch_odometer_days(vehicle_ids):
        km = rules.num(row.get("odometer_km"))
        if km is not None:
            odometer[row["vehicle_id"]].append((row["day"], km))

    # ------------------------------------------------ 1. Qism so'rovlari
    request_items: list[dict[str, Any]] = []
    history: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    in_window = 0
    for request in requests_all:
        vid = request.get("vehicle_id") or ""
        cat = rules.category_of(request.get("item_name"))
        key = (vid, cat)
        day = request.get("requested_day")
        if day is not None and day >= date_from:
            in_window += 1
            if not category or cat == category:
                flags = rules.check_request(
                    request,
                    vehicle_parts=parts_by_vehicle.get(vid, []),
                    peer_parts=parts_by_model.get(
                        rules.model_key(request.get("brand"), request.get("model")), []),
                    previous=history[key],
                    odometer_days=odometer.get(vid, []),
                    lang=lang,
                    type_parts=parts_by_type.get((request.get("transport_type") or "").upper(), []),
                )
                request_items.append({
                    **_vehicle(request),
                    "request_id": request["request_id"],
                    "repair_order_id": request.get("repair_order_id"),
                    "item_name": request.get("item_name"),
                    "category": cat,
                    "status": request.get("status"),
                    "unit": request.get("unit_of_measure"),
                    "requested_quantity": rules.num(request.get("requested_quantity")),
                    "issued_quantity": rules.num(request.get("issued_quantity")),
                    "used_quantity": rules.num(request.get("used_quantity")),
                    "returned_quantity": rules.num(request.get("returned_quantity")),
                    "requested_at": request.get("requested_at"),
                    "issued_at": request.get("issued_at"),
                    "requested_by": request.get("requested_by"),
                    "issued_by": request.get("issued_by"),
                    "battery_ah": rules.battery_ah(request.get("item_name")) if cat == "BATTERY" else None,
                    "tire_rim": rules.tire_rim(request.get("item_name")) if cat == "TIRE" else None,
                    "voltage": rules.voltage_system(request.get("item_name")),
                    "flags": flags,
                })
        history[key].append(request)

    # ------------------------------------------- 2. O'rnatilgan qismlar
    life_values = rules.life_values_by_category(parts_all)
    scoped = [p for p in parts_all
              if (not vehicle_id or p["vehicle_id"] == vehicle_id)
              and (not category or (p.get("category") or "").upper() == category)]
    installed_items: list[dict[str, Any]] = []
    entry_dates = no_life = 0
    for part in scoped:
        result = rules.evaluate_part(
            part, today=today, lang=lang,
            life_values=life_values.get((part.get("category") or "").upper(), set()))
        entry_dates += rules.is_entry_date(part)
        if result["ratio"] is None:
            no_life += 1
        if not result["flags"]:
            continue
        life = result["life"]
        installed_items.append({
            **_vehicle(part),
            "part_id": part["part_id"],
            "category": part.get("category"),
            "name": part.get("name"),
            "status": part.get("status"),
            "installed_at": part.get("installed_at"),
            "install_date_is_entry_date": rules.is_entry_date(part),
            "used_km": _round(result["usage"]["km"]),
            "used_months": _round(result["usage"]["months"]),
            "used_hours": _round(result["usage"]["hours"]),
            "life_km": life["km"][0],
            "life_months": life["months"][0],
            "life_hours": life["hours"][0],
            "warranty_months": life["warranty_months"][0],
            "life_source": _source(result["ratio"]["life_source"]) if result["ratio"] else None,
            "used_pct": result["ratio"]["pct"] if result["ratio"] else None,
            "remaining_km": result["remaining_km"],
            "remaining_months": result["remaining_months"],
            "flags": result["flags"],
        })

    # --------------------------------------------------------- Yig'ish
    by_code: Counter[str] = Counter()
    by_kind: Counter[str] = Counter()
    for item in request_items + installed_items:
        for flag in item["flags"]:
            by_code[flag["code"]] += 1
            by_kind[flag["kind"]] += 1

    kind_rank = {"MISMATCH": 0, "CONTROL": 1, "EARLY": 2, "MAINTENANCE": 3, "DATA": 4}
    request_items.sort(key=lambda i: (min((kind_rank[f["kind"]] for f in i["flags"]), default=9),
                                      str(i.get("requested_at") or "")))
    installed_items.sort(key=lambda i: (min(kind_rank[f["kind"]] for f in i["flags"]),
                                        i.get("used_pct") or 0))

    stock = [
        {"item_name": s.get("item_name"), "category": rules.category_of(s.get("item_name")),
         "quantity": rules.num(s.get("quantity")), "unit": s.get("unit_of_measure"),
         "unit_price": rules.num(s.get("unit_price")), "warehouse": s.get("warehouse_name"),
         "battery_ah": rules.battery_ah(s.get("item_name")),
         "tire_rim": rules.tire_rim(s.get("item_name"))}
        for s in queries.fetch_stock()
        if not category or rules.category_of(s.get("item_name")) == category
    ]

    counts = queries.row_counts()
    notes = [t(lang, "note.categories"), t(lang, "note.no_removal_history")]
    if not counts.get("material_movement") and not counts.get("inventory_receipt"):
        notes.append(t(lang, "note.no_movement"))
    if entry_dates:
        notes.append(t(lang, "note.entry_dates", count=entry_dates))
    if no_life:
        notes.append(t(lang, "note.no_life", count=no_life))
    notes.append(t(lang, "note.few_requests", count=in_window))

    flagged_requests = [i for i in request_items if i["flags"]]
    return {
        "generated_at": datetime.now(),
        "scope": {"date_from": date_from, "date_to": date_to,
                  "filters": {"vehicle_id": vehicle_id, "category": category}},
        "summary": {
            "requests": len(request_items),
            "flagged_requests": len(flagged_requests),
            "installed_parts": len(scoped),
            "flagged_installed": len(installed_items),
            "by_code": dict(by_code.most_common()),
            "by_kind": dict(by_kind.most_common()),
            "stock_items": len(stock),
        },
        "analysis": {"text": "", "source": "template", "items_considered": 0},
        "requests": request_items[:limit],
        "installed": installed_items[:limit],
        "stock": stock[:limit],
        "data_quality": {"row_counts": counts, "notes": notes},
        "elapsed_seconds": round(time.perf_counter() - started, 3),
    }


def _round(value: float | None) -> float | None:
    return None if value is None else round(value, 1)


def norms(*, category: str | None = None, lang: str = texts.DEFAULT_LANG) -> dict[str, Any]:
    """Rusum va qism turi bo'yicha resurs jadvali."""
    started = time.perf_counter()
    lang = texts.normalize(lang)
    category = (category or "").upper() or None
    parts = [p for p in queries.fetch_installed()
             if not category or (p.get("category") or "").upper() == category]
    rows = rules.model_norms(parts, today=date.today(), lang=lang)
    for row in rows:
        row["life_km_source"] = _source(row["life_km_source"])
        row["life_months_source"] = _source(row["life_months_source"])
        row["warranty_source"] = _source(row["warranty_source"])
    return {
        "generated_at": datetime.now(),
        "rows": rows,
        "sources": [{"key": k, **v} for k, v in specs.SOURCES.items()
                    if k in ("gost_53165", "gost_4754", "mintrans_tires")],
        "elapsed_seconds": round(time.perf_counter() - started, 3),
    }
