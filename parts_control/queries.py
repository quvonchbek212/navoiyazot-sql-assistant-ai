"""Bazadan o'qish — FAQAT SELECT, parametrli.

Manbalar (28.10.2026 holati):
    vehicle_part               769  o'rnatilgan shina va akkumulyatorlar
    repair_order_part_request   11  ta'mirga berilgan qismlar
    inventory_stock            469  ombordagi JORIY qoldiq
    material_movement            0  kirim-chiqim harakati — bo'sh
    inventory_receipt            0  kirim — bo'sh
"""

from __future__ import annotations

import logging
import sys
from datetime import date
from pathlib import Path
from typing import Any, Sequence

_CHATBOT_DIR = Path(__file__).resolve().parent.parent / "atil_chatbot"
if str(_CHATBOT_DIR) not in sys.path:
    sys.path.insert(0, str(_CHATBOT_DIR))

import psycopg2  # noqa: E402

from db.connect_db_for_server import read_only_cursor  # noqa: E402

from parts_control import config  # noqa: E402
from parts_control.config import TIMEZONE  # noqa: E402

logger = logging.getLogger(__name__)

SOURCE_TABLES = ("vehicle_part", "repair_order_part_request", "inventory_stock",
                 "material_movement", "inventory_receipt")


class PartsDataError(RuntimeError):
    """Bazadan o'qib bo'lmadi — router buni 503 ga aylantiradi."""


def _select(sql: str, params: Sequence[Any] | None = None) -> list[dict[str, Any]]:
    try:
        with read_only_cursor() as cur:
            cur.execute(sql, tuple(params or ()))
            return [dict(row) for row in cur.fetchall()]
    except psycopg2.Error as exc:
        message = (getattr(exc, "pgerror", None) or str(exc)).strip().splitlines()[0]
        logger.warning("Qismlar so'rovi bajarilmadi: %s", message[:300])
        raise PartsDataError(message[:300]) from exc
    except Exception as exc:  # noqa: BLE001
        logger.exception("Bazaga ulanishda kutilmagan xato")
        raise PartsDataError(f"{type(exc).__name__}: {exc}"[:300]) from exc


def row_counts() -> dict[str, int]:
    """Haqiqiy `count(*)` — statistika bu bazada ishonchsiz (`atil_agent/README.md`)."""
    rows = _select(
        "select " + ", ".join(f"(select count(*) from {t}) as {t}" for t in SOURCE_TABLES)
    )
    return {k: int(v or 0) for k, v in (rows[0] if rows else {}).items()}


_VEHICLE_COLUMNS = """
    v.plate_number, v.brand, v.model, v.transport_type
"""


def fetch_installed(vehicle_ids: Sequence[str] | None = None) -> list[dict[str, Any]]:
    """O'rnatilgan qismlar. `vehicle_ids` berilmasa — butun park (resurs
    jadvali va rusum bo'yicha solishtirish uchun hammasi kerak)."""
    where = "where p.vehicle_id = any(%s::uuid[])" if vehicle_ids else ""
    params: list[Any] = [list(vehicle_ids)] if vehicle_ids else []
    params.append(config.MAX_ROWS)
    return _select(
        f"""
        select p.id::text as part_id, p.vehicle_id::text as vehicle_id, p.category,
               p.name, p.part_number, p.status, p.installed_at, p.created_at,
               p.installed_at_km, p.current_odometer_km, p.expected_life_km,
               p.expected_life_months, p.installed_at_engine_hours,
               p.current_engine_hours, p.expected_life_engine_hours, p.tire_size,
               p.primary_battery, p.warning_at_percent, p.replace_at_percent,
               {_VEHICLE_COLUMNS}
        from vehicle_part p
        join transport_vehicle v on v.id = p.vehicle_id
        {where}
        order by p.vehicle_id, p.category, p.installed_at
        limit %s
        """,
        params,
    )


def fetch_life_values() -> dict[str, set[float]]:
    """Park bo'yicha qism turi → korxona resurslari (km). "4 000" yonida
    "40 000" bo'lsa — nol tushib qolgan (LIFE_VALUE_SUSPECT). Bitta mashina
    pasporti ham BUTUN park bilan solishtiradi, rusumi bilan emas."""
    rows = _select(
        """
        select upper(category) as category, expected_life_km
        from vehicle_part
        where expected_life_km > 0
        group by 1, 2
        """
    )
    out: dict[str, set[float]] = {}
    for row in rows:
        out.setdefault(row["category"] or "", set()).add(float(row["expected_life_km"]))
    return out


def fetch_requests(date_to: date, vehicle_id: str | None = None) -> list[dict[str, Any]]:
    """Qism so'rovlari `date_to` gacha — HAMMASI: davrdagi so'rovni oldingisi
    bilan solishtirish (erta almashtirish) uchun tarix ham kerak."""
    vehicle_sql = "and r.vehicle_id = %s::uuid" if vehicle_id else ""
    params: list[Any] = [TIMEZONE, TIMEZONE, date_to]
    if vehicle_id:
        params.append(vehicle_id)
    params.append(config.MAX_ROWS)
    return _select(
        f"""
        select r.id::text as request_id, r.vehicle_id::text as vehicle_id,
               r.repair_order_id::text as repair_order_id, r.item_id::text as item_id,
               r.item_name, r.unit_of_measure, r.status,
               r.requested_quantity, r.issued_quantity, r.used_quantity,
               r.returned_quantity, r.requested_at, r.issued_at, r.used_at,
               r.requested_by::text as requested_by, r.issued_by::text as issued_by,
               (r.requested_at at time zone %s)::date as requested_day,
               {_VEHICLE_COLUMNS}
        from repair_order_part_request r
        left join transport_vehicle v on v.id = r.vehicle_id
        where (r.requested_at at time zone %s)::date <= %s
          {vehicle_sql}
        order by r.requested_at
        limit %s
        """,
        params,
    )


def fetch_odometer_days(vehicle_ids: Sequence[str]) -> list[dict[str, Any]]:
    """Kun bo'yicha spidometr — so'rov paytida mashina necha km da edi."""
    if not vehicle_ids:
        return []
    return _select(
        """
        select vehicle_id::text as vehicle_id,
               (coalesce(actual_return_at, actual_departure_at, planned_departure_at)
                    at time zone %s)::date as day,
               max(odometer_end_km) as odometer_km
        from waybill
        where vehicle_id = any(%s::uuid[]) and odometer_end_km is not null
          and status not in ('CANCELLED', 'DRAFT')
        group by 1, 2
        order by 1, 2
        """,
        (TIMEZONE, list(vehicle_ids)),
    )


def fetch_stock() -> list[dict[str, Any]]:
    """Ombordagi shina va akkumulyator qoldig'i (joriy holat)."""
    return _select(
        r"""
        select item_name, quantity, unit_of_measure, unit_price, warehouse_name, group_code
        from inventory_stock
        where item_name ~* '(шин|shina|аккумул|akkumul|батаре|balon)'
          and quantity > 0
        order by quantity desc
        limit %s
        """,
        (config.MAX_ROWS,),
    )


# ======================================================== Mashina pasporti
#
# Pasport bitta mashina (yoki butun park) uchun HAMMA manbani o'qiydi:
# ta'mirlar, qism so'rovlari, o'rnatilgan qismlar, texnik xizmat rejasi,
# spidometr/motosoat ko'rsatkichlari va haydovchilar. `vehicle_ids=None`
# — butun park (161 mashina; jadvallar kichik, bitta so'rovda olinadi).


def _vehicle_filter(column: str, vehicle_ids: Sequence[str] | None) -> tuple[str, list[Any]]:
    if vehicle_ids is None:
        return "", []
    return f"and {column} = any(%s::uuid[])", [list(vehicle_ids)]


def fetch_vehicles(vehicle_ids: Sequence[str] | None = None) -> list[dict[str, Any]]:
    where, params = _vehicle_filter("v.id", vehicle_ids)
    return _select(
        f"""
        select v.id::text as vehicle_id, v.plate_number, v.brand, v.model,
               v.transport_type, v.usage_mode, v.current_status, v.category,
               v.release_date, v.commissioning_date, v.vin,
               v.assigned_driver_id::text as assigned_driver_id
        from transport_vehicle v
        where true {where}
        order by v.brand, v.model, v.plate_number
        """,
        params,
    )


def fetch_repairs(vehicle_ids: Sequence[str] | None = None) -> list[dict[str, Any]]:
    """Ta'mirlar va ularning ish bandlari (bitta matn bo'lib)."""
    where, params = _vehicle_filter("r.vehicle_id", vehicle_ids)
    return _select(
        f"""
        select r.id::text as repair_id, r.vehicle_id::text as vehicle_id, r.repair_number,
               r.status, r.component_category, r.defect_area, r.title, r.description,
               r.work_performed, r.final_conclusion, r.driver_name,
               r.detected_at, r.opened_at, r.repaired_at, r.completed_at,
               (select string_agg(w.description, ' | ')
                from vehicle_repair_work_items w where w.repair_id = r.id) as work_items
        from vehicle_repair r
        where true {where}
        order by coalesce(r.repaired_at, r.completed_at, r.detected_at, r.opened_at)
        """,
        params,
    )


def fetch_all_requests(vehicle_ids: Sequence[str] | None = None) -> list[dict[str, Any]]:
    where, params = _vehicle_filter("r.vehicle_id", vehicle_ids)
    return _select(
        f"""
        select r.id::text as request_id, r.vehicle_id::text as vehicle_id, r.item_name,
               r.status, r.unit_of_measure, r.issued_quantity, r.used_quantity,
               r.requested_at, r.issued_at, r.used_at
        from repair_order_part_request r
        where true {where}
        order by r.requested_at
        """,
        params,
    )


def fetch_tire_norms(vehicle_ids: Sequence[str] | None = None) -> list[dict[str, Any]]:
    where, params = _vehicle_filter("n.vehicle_id", vehicle_ids)
    return _select(
        f"""
        select n.vehicle_id::text as vehicle_id, n.tire_size, n.expected_life_km,
               n.expected_life_engine_hours, n.expected_life_months
        from vehicle_tire_norm n
        where true {where}
        """,
        params,
    )


def fetch_plans(vehicle_ids: Sequence[str] | None = None) -> list[dict[str, Any]]:
    """ATIL texnik xizmat rejasi — korxona kiritgan oraliq va oxirgi xizmat."""
    where, params = _vehicle_filter("m.vehicle_id", vehicle_ids)
    return _select(
        f"""
        select m.vehicle_id::text as vehicle_id, m.kind, m.maintenance_type, m.status,
               m.interval_km, m.interval_days, m.interval_engine_hours,
               m.last_serviced_at, m.last_serviced_at_km, m.last_serviced_engine_hours
        from maintenance_plan m
        where true {where}
        """,
        params,
    )


def fetch_readings(vehicle_ids: Sequence[str] | None = None) -> list[dict[str, Any]]:
    """Spidometr va motosoat — yo'l varaqalari va texnik ko'riklardan, kun bo'yicha."""
    w_where, w_params = _vehicle_filter("vehicle_id", vehicle_ids)
    i_where, i_params = _vehicle_filter("vehicle_id", vehicle_ids)
    return _select(
        f"""
        select vehicle_id::text as vehicle_id,
               (coalesce(actual_return_at, actual_departure_at, planned_departure_at)
                    at time zone %s)::date as day,
               odometer_end_km as km, coalesce(moto_hours_end, post_trip_motohours) as hours
        from waybill
        where status not in ('CANCELLED', 'DRAFT')
          and (odometer_end_km > 0 or coalesce(moto_hours_end, post_trip_motohours) > 0)
          {w_where}
        union all
        select vehicle_id::text, (inspected_at at time zone %s)::date,
               case when {_quarantined('ODOMETER_KM', 'i.probeg')} then null else probeg end,
               case when {_quarantined('ENGINE_HOURS', 'i.moto_hours')} then null
                    else moto_hours end
        from vehicle_technical_inspection i
        where (probeg > 0 or moto_hours > 0) {i_where}
        """,
        [TIMEZONE, *w_params, TIMEZONE, *i_params],
    )


def _quarantined(counter: str, column: str) -> str:
    """ATIL o'zi shubhali deb karantinga olgan ko'rik o'lchovi (`vehicle_usage_reading`,
    92 ta, 89 tasi ko'rik qatoriga mos — 85058GAA dagi "1 138 km", 29.10.2026)."""
    return f"""exists (select 1 from vehicle_usage_reading u
        where u.vehicle_id = i.vehicle_id and u.quality = 'QUARANTINED'
          and u.counter = '{counter}' and u.absolute_value = {column}
          and (u.observed_at at time zone '{TIMEZONE}')::date
              = (i.inspected_at at time zone '{TIMEZONE}')::date)"""


def fetch_usage_trips(vehicle_ids: Sequence[str]) -> list[dict[str, Any]]:
    """Ish profili: reyslar — kun, masofa, motosoat. Vaqt ustunlari mahalliy
    (`timestamp without time zone`)."""
    return _select(
        """
        select vehicle_id::text as vehicle_id, status,
               coalesce(actual_departure_at, scheduled_departure_at)::date as day,
               coalesce(actual_arrival_at, scheduled_arrival_at)::date as end_day,
               scheduled_departure_at::date as plan_day, scheduled_arrival_at::date as plan_end,
               actual_distance_km as km, actual_engine_hours as hours
        from trip
        where vehicle_id = any(%s::uuid[]) and status <> 'CANCELLED'
        """,
        (list(vehicle_ids),),
    )


def fetch_usage_waybills(vehicle_ids: Sequence[str]) -> list[dict[str, Any]]:
    """Ish profili: yo'l varaqalari — ishlagan kun va yuk (varaqaning o'zida yoki
    topshiriqlarida; bazada 4 011 dan 23 tasida, 507 topshiriqdan 91 tasida)."""
    return _select(
        """
        select w.vehicle_id::text as vehicle_id,
               (coalesce(w.actual_departure_at, w.planned_departure_at) at time zone %s)::date
                   as day,
               nullif(w.cargo_weight_tons, 0) as cargo_tons,
               (select nullif(sum(t.cargo_weight_tons), 0) from waybill_task t
                where t.waybill_id = w.id) as task_tons
        from waybill w
        where w.vehicle_id = any(%s::uuid[]) and w.status not in ('CANCELLED', 'DRAFT')
        """,
        (TIMEZONE, list(vehicle_ids)),
    )


def fetch_usage_start() -> date | None:
    """Reyslar yozila boshlagan kun (butun park) — undan oldingi kunlar "turgan"
    emas, "ma'lumot yo'q" (bazada 1969-12-31 kabi xato sanalar ham bor)."""
    rows = _select("select min(scheduled_departure_at)::date as day from trip "
                   "where scheduled_departure_at > '2000-01-01'")
    return rows[0]["day"] if rows else None


def fetch_driver_trips(vehicle_ids: Sequence[str]) -> list[dict[str, Any]]:
    """Mashinani kim haydagan — yo'l varaqalari bo'yicha, vaqt tartibida."""
    return _select(
        """
        select w.vehicle_id::text as vehicle_id, w.driver_id::text as driver_id,
               d.full_name as driver_name,
               (coalesce(w.actual_departure_at, w.planned_departure_at) at time zone %s)::date as day
        from waybill w
        left join driver d on d.id = w.driver_id
        where w.vehicle_id = any(%s::uuid[]) and w.status not in ('CANCELLED', 'DRAFT')
        order by w.vehicle_id, coalesce(w.actual_departure_at, w.planned_departure_at)
        """,
        (TIMEZONE, list(vehicle_ids)),
    )


def fetch_assigned_drivers(vehicle_ids: Sequence[str] | None = None) -> list[dict[str, Any]]:
    """Biriktirilgan haydovchilar: asosiysi (`transport_vehicle`) va ro'yxat."""
    where, params = _vehicle_filter("x.vehicle_id", vehicle_ids)
    return _select(
        f"""
        with x as (
            select vehicle_id, driver_id, false as primary_driver from vehicle_assigned_drivers
            union
            select vehicle_id, driver_id, false from driver_assigned_vehicles
            union
            select id, assigned_driver_id, true from transport_vehicle
            where assigned_driver_id is not null
        )
        select x.vehicle_id::text as vehicle_id, d.id::text as driver_id, d.full_name,
               d.phone, d.license_valid_until, d.medical_certificate_valid_until,
               d.employment_status, d.driver_availability_status,
               bool_or(x.primary_driver) as primary_driver
        from x join driver d on d.id = x.driver_id
        where true {where}
        group by 1, 2, 3, 4, 5, 6, 7, 8
        """,
        params,
    )


def fetch_status_history(vehicle_ids: Sequence[str]) -> list[dict[str, Any]]:
    return _select(
        """
        select vehicle_id::text as vehicle_id, previous_status, new_status, reason, changed_at
        from vehicle_status_history
        where vehicle_id = any(%s::uuid[])
        order by changed_at
        """,
        (list(vehicle_ids),),
    )


def find_vehicles_by_plate(plate: str) -> list[dict[str, Any]]:
    """Davlat raqami bo'yicha: avval aniq (bo'shliq va chiziqchasiz), keyin qism-moslik."""
    key = "".join(plate.split()).upper().replace("-", "")
    normalized = "upper(replace(replace(plate_number, ' ', ''), '-', ''))"
    rows = _select(
        f"""
        select id::text as vehicle_id, plate_number, brand, model
        from transport_vehicle where {normalized} = %s
        """,
        (key,),
    )
    if rows:
        return rows
    return _select(
        f"""
        select id::text as vehicle_id, plate_number, brand, model
        from transport_vehicle where {normalized} like %s
        order by plate_number limit 10
        """,
        (f"%{key}%",),
    )
