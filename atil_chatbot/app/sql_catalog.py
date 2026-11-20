"""Tekshirilgan SQL katalogi — chatbot "bilib turgan" savollar.

Ikki vazifa:
  1. MISOL — savolga eng o'xshash 3 ta yozuv SQL promptiga namuna sifatida
     qo'shiladi. Model jadval/ustun/JOIN yo'lini shulardan ko'chiradi — bu
     aniqlikni eng ko'p oshiradigan narsa.
  2. TEZ YO'L (`match`) — savol shablonga ANIQ mos kelsa, SQL LLM'siz shu
     yerdan olinadi (tezroq va xatosiz). `match` faqat bir ma'noli
     iboralarga yoziladi; shubha bo'lsa bo'sh qoldiriladi.

QAT'IY QOIDA: har bir `sql` haqiqiy bazada bajarilib tekshirilgan.
`tests/test_sql_catalog.py` ularni sxema bo'yicha (bazasiz) va baza
ulanganda bajarib ham tekshiradi — sxema o'zgarsa test yiqiladi.

Yangi yozuv qo'shish: SQL ni avval bazada ishlating, keyin shu yerga qo'shing.
"""
from __future__ import annotations

import re
from dataclasses import dataclass

_APOSTROPHES = re.compile(r"[‘’`ʻʼ']")
_WORD = re.compile(r"[a-zа-яёўқғҳ0-9']+", re.IGNORECASE)
_STOP = {
    "va", "bilan", "uchun", "bo'yicha", "qancha", "nechta", "qaysi", "ko'rsat", "ber",
    "menga", "bor", "ham", "the", "ro'yxati", "ro'yxatini", "soni", "sonini", "necha",
}


def normalize(text: str) -> str:
    """Kichik harf, apostrof variantlari → ' (o‘tgan, o`tgan → o'tgan)."""
    return _APOSTROPHES.sub("'", (text or "").lower()).strip()


def _stem(word: str) -> str:
    # O'zbekcha qo'shimchalarni qisqartirish uchun oddiy kesish (tahlillar → tahlil).
    return word[:6] if len(word) > 6 else word


def tokens(text: str) -> set[str]:
    return {_stem(w) for w in _WORD.findall(normalize(text)) if w not in _STOP and len(w) > 2}


@dataclass(frozen=True)
class CatalogEntry:
    question: str
    sql: str
    tables: tuple[str, ...]
    match: str = ""  # normalize() qilingan savolga qo'llanadigan regex (tez yo'l)

    def matches(self, question: str) -> bool:
        q = normalize(question).rstrip("?!. ")
        if q == normalize(self.question).rstrip("?!. "):
            return True
        return bool(self.match) and re.fullmatch(self.match, q) is not None


CATALOG: list[CatalogEntry] = [
    CatalogEntry(
        question='Qaysi reyslar kechikayapti?',
        sql="""SELECT
  t.trip_number AS "Reys",
  v.plate_number AS "Mashina",
  d.full_name AS "Haydovchi",
  CASE
    WHEN t.actual_departure_at IS NULL
    THEN 'Jo''nab ketmagan'
    ELSE 'Yo''lda kechikmoqda'
  END AS "Kechikish turi",
  t.status AS "Holat",
  t.scheduled_departure_at AS "Rejadagi jo'nash",
  t.scheduled_arrival_at AS "Reja bo'yicha kelish",
  ROUND(
    EXTRACT(EPOCH FROM (
      LOCALTIMESTAMP - CASE
        WHEN t.actual_departure_at IS NULL
        THEN t.scheduled_departure_at
        ELSE t.scheduled_arrival_at
      END
    )) / 60.0
  ) AS "Kechikish (daq)"
FROM public.trip AS t
LEFT JOIN public.transport_vehicle AS v
  ON v.id = t.vehicle_id
LEFT JOIN public.driver AS d
  ON d.id = t.driver_id
WHERE
  t.status IN ('PLANNED', 'ASSIGNED', 'STARTED', 'ARRIVED_AT_POINT', 'LOADED', 'UNLOADED')
  AND (
    (
      t.actual_departure_at IS NULL AND t.scheduled_departure_at < LOCALTIMESTAMP
    )
    OR (
      NOT t.actual_departure_at IS NULL
      AND t.actual_arrival_at IS NULL
      AND t.scheduled_arrival_at < LOCALTIMESTAMP
    )
  )
ORDER BY
  8 DESC
LIMIT 50;""",
        tables=('trip', 'transport_vehicle', 'driver'),
    ),
    CatalogEntry(
        question="Bo'sh turgan mashinalar ro'yxati",
        sql="""SELECT
  v.plate_number AS "Davlat raqami",
  v.brand || ' ' || v.model AS "Marka",
  v.transport_type AS "Turi",
  ROUND(v.payload_capacity_kg / 1000.0, 2) AS "Sig'im (t)",
  v.current_status AS "Holat"
FROM public.transport_vehicle AS v
WHERE
  v.current_status = 'ACTIVE'
  AND NOT EXISTS(
    SELECT
      1
    FROM public.trip AS t
    WHERE
      t.vehicle_id = v.id
      AND t.status IN ('PLANNED', 'ASSIGNED', 'STARTED', 'ARRIVED_AT_POINT', 'LOADED', 'UNLOADED')
  )
ORDER BY
  v.payload_capacity_kg DESC NULLS LAST
LIMIT 50;""",
        tables=('transport_vehicle', 'trip'),
    ),
    CatalogEntry(
        question="Hozir yo'lda (reysda) bo'lgan mashinalar",
        sql="""SELECT
  v.plate_number AS "Mashina",
  d.full_name AS "Haydovchi",
  t.trip_number AS "Reys",
  t.status AS "Holat",
  t.scheduled_departure_at AS "Rejadagi jo'nash",
  t.actual_departure_at AS "Amalda jo'nagan",
  COUNT(*) OVER (PARTITION BY t.vehicle_id) AS "Shu mashinadagi ochiq reys"
FROM public.trip AS t
LEFT JOIN public.transport_vehicle AS v
  ON v.id = t.vehicle_id
LEFT JOIN public.driver AS d
  ON d.id = t.driver_id
WHERE
  t.status IN ('STARTED', 'ARRIVED_AT_POINT', 'LOADED', 'UNLOADED')
ORDER BY
  t.scheduled_departure_at DESC
LIMIT 50;""",
        tables=('trip', 'transport_vehicle', 'driver'),
    ),
    CatalogEntry(
        question="Guvohnomasi yoki tibbiy ko'rigi tugayotgan haydovchilar",
        sql="""SELECT
  d.full_name AS "Haydovchi",
  d.driver_license_number AS "Guvohnoma",
  d.license_valid_until AS "Guvohnoma muddati",
  (
    d.license_valid_until - CURRENT_DATE
  ) AS "Guvohnomaga qolgan kun",
  d.medical_certificate_valid_until AS "Tibbiy ko'rik muddati",
  (
    d.medical_certificate_valid_until - CURRENT_DATE
  ) AS "Ko'rikka qolgan kun",
  d.employment_status AS "Bandlik"
FROM public.driver AS d
WHERE
  d.license_valid_until <= CURRENT_DATE + INTERVAL '30 DAY'
  OR d.medical_certificate_valid_until <= CURRENT_DATE + INTERVAL '30 DAY'
ORDER BY
  LEAST(
    COALESCE(d.license_valid_until, CAST('9999-12-31' AS DATE)),
    COALESCE(d.medical_certificate_valid_until, CAST('9999-12-31' AS DATE))
  )
LIMIT 50;""",
        tables=('driver',),
    ),
    CatalogEntry(
        question='Keyingi 30 kunda qaysi mashinalarning hujjatlari tugaydi?',
        sql="""SELECT
  v.plate_number AS "Davlat raqami",
  x.manba AS "Manba",
  x.turi AS "Hujjat turi",
  x.raqam AS "Raqami",
  x.muddat AS "Muddat",
  (
    x.muddat - CURRENT_DATE
  ) AS "Qolgan kun"
FROM (
  SELECT
    vd.vehicle_id,
    'vehicle_document' AS manba,
    vd.document_type AS turi,
    vd.document_number AS raqam,
    vd.expiry_date AS muddat
  FROM public.vehicle_document AS vd
  WHERE
    vd.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 DAY'
  UNION ALL
  SELECT
    ip.vehicle_id,
    'insurance_policy',
    ip.kind,
    ip.policy_number,
    ip.valid_to
  FROM public.insurance_policy AS ip
  WHERE
    ip.valid_to BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 DAY'
) AS x
LEFT JOIN public.transport_vehicle AS v
  ON v.id = x.vehicle_id
ORDER BY
  5
LIMIT 100;""",
        tables=('vehicle_document', 'insurance_policy', 'transport_vehicle'),
    ),
    CatalogEntry(
        question="Normadan ortiq yoqilg'i sarflagan mashinalar",
        sql="""SELECT
  v.plate_number AS "Mashina",
  fr.occurred_at AS "Sana",
  fr.liters AS "Litr",
  fr.actual_consumption_per100km AS "Amaldagi sarf (l/100km)",
  fr.norm_liters_per100km AS "Norma (l/100km)",
  fr.deviation_percent AS "Chetlanish (%)",
  fr.severity AS "Daraja"
FROM public.fuel_record AS fr
LEFT JOIN public.transport_vehicle AS v
  ON v.id = fr.vehicle_id
WHERE
  fr.deviation_percent > 0
ORDER BY
  fr.deviation_percent DESC NULLS LAST
LIMIT 50;""",
        tables=('fuel_record', 'transport_vehicle'),
    ),
    CatalogEntry(
        question="Tasdiq kutayotgan transport so'rovlari",
        sql="""SELECT
  tr.request_number AS "Ariza",
  tr.status AS "Holat",
  tr.request_type AS "Turi",
  tr.purpose AS "Maqsad",
  tr.planned_departure_at AS "Rejadagi jo'nash",
  rd.name AS "Bo'lim",
  tr.created_at AS "Yaratilgan"
FROM public.transport_request AS tr
LEFT JOIN public.reference_data AS rd
  ON rd.id = tr.department_id
WHERE
  tr.status LIKE 'PENDING%'
ORDER BY
  tr.created_at
LIMIT 50;""",
        tables=('transport_request', 'reference_data'),
    ),
    CatalogEntry(
        question="Yopilmagan yo'l varaqalari",
        sql="""SELECT
  w.waybill_number AS "Yo'l varaqasi",
  w.status AS "Holat",
  v.plate_number AS "Mashina",
  d.full_name AS "Haydovchi",
  w.issue_date AS "Berilgan sana",
  (
    CURRENT_DATE - w.issue_date
  ) AS "Ochiq turgan kun"
FROM public.waybill AS w
LEFT JOIN public.transport_vehicle AS v
  ON v.id = w.vehicle_id
LEFT JOIN public.driver AS d
  ON d.id = w.driver_id
WHERE
  NOT w.status IN ('CLOSED', 'CANCELLED')
ORDER BY
  w.issue_date
LIMIT 50;""",
        tables=('waybill', 'transport_vehicle', 'driver'),
    ),
    CatalogEntry(
        question='Hal qilinmagan hodisalar',
        sql="""SELECT
  i.incident_type AS "Hodisa turi",
  i.severity AS "Daraja",
  i.status AS "Holat",
  i.occurred_at AS "Sodir bo'lgan",
  v.plate_number AS "Mashina",
  d.full_name AS "Haydovchi",
  i.description AS "Tavsif"
FROM public.incident AS i
LEFT JOIN public.transport_vehicle AS v
  ON v.id = i.vehicle_id
LEFT JOIN public.driver AS d
  ON d.id = i.driver_id
WHERE
  i.status IN ('OPEN', 'IN_PROGRESS')
ORDER BY
  i.occurred_at DESC
LIMIT 50;""",
        tables=('incident', 'transport_vehicle', 'driver'),
    ),
    CatalogEntry(
        question="Texnik xizmat muddati o'tgan mashinalar",
        sql="""SELECT
  v.plate_number AS "Mashina",
  mp.maintenance_type AS "Xizmat turi",
  mp.status AS "Holat",
  mp.next_due_at AS "Muddat",
  (
    mp.next_due_at - CURRENT_DATE
  ) AS "Qolgan kun",
  mp.next_due_at_km AS "Muddat (km)",
  mp.current_odometer_km AS "Hozirgi probeg (km)",
  (
    mp.next_due_at_km - mp.current_odometer_km
  ) AS "Qolgan masofa (km)"
FROM public.maintenance_plan AS mp
LEFT JOIN public.transport_vehicle AS v
  ON v.id = mp.vehicle_id
WHERE
  mp.next_due_at < CURRENT_DATE OR mp.next_due_at_km <= mp.current_odometer_km
ORDER BY
  mp.next_due_at
LIMIT 50;""",
        tables=('maintenance_plan', 'transport_vehicle'),
    ),
    CatalogEntry(
        question="Ta'mirda turgan mashinalar",
        sql="""SELECT
  v.plate_number AS "Mashina",
  v.brand || ' ' || v.model AS "Marka",
  vr.repair_number AS "Ta'mir raqami",
  vr.title AS "Nosozlik",
  vr.status AS "Ta'mir holati",
  vr.opened_at AS "Ochilgan",
  ROUND(EXTRACT(EPOCH FROM (
    CURRENT_TIMESTAMP - vr.opened_at
  )) / 86400.0) AS "Turgan kun",
  v.current_status AS "Mashina holati"
FROM public.vehicle_repair AS vr
JOIN public.transport_vehicle AS v
  ON v.id = vr.vehicle_id
WHERE
  vr.completed_at IS NULL
ORDER BY
  vr.opened_at
LIMIT 50;""",
        tables=('vehicle_repair', 'transport_vehicle'),
    ),
    CatalogEntry(
        question='Tezlik oshirish buzilishlari',
        sql="""SELECT
  v.plate_number AS "Mashina",
  d.full_name AS "Haydovchi",
  sv.occurred_at AS "Sana",
  sv.speed_kph AS "Tezlik (km/s)",
  sv.limit_kph AS "Chegara (km/s)",
  sv.excess_kph AS "Oshirilgan (km/s)"
FROM public.speed_violation AS sv
LEFT JOIN public.transport_vehicle AS v
  ON v.id = sv.vehicle_id
LEFT JOIN public.driver AS d
  ON d.id = sv.driver_id
ORDER BY
  sv.excess_kph DESC NULLS LAST
LIMIT 50;""",
        tables=('speed_violation', 'transport_vehicle', 'driver'),
    ),
    CatalogEntry(
        question='Mashinalar hozir qayerda?',
        sql="""SELECT
  v.plate_number AS "Mashina",
  vts.last_latitude AS "Kenglik",
  vts.last_longitude AS "Uzunlik",
  vts.last_speed_kph AS "Tezlik (km/s)",
  vts.last_odometer_km AS "Probeg (km)",
  vts.last_event_at AS "Oxirgi signal",
  t.trip_number AS "Hozirgi reys"
FROM public.vehicle_telemetry_state AS vts
LEFT JOIN public.transport_vehicle AS v
  ON v.id = vts.vehicle_id
LEFT JOIN public.trip AS t
  ON t.id = vts.current_trip_id
ORDER BY
  vts.last_event_at DESC NULLS LAST
LIMIT 50;""",
        tables=('vehicle_telemetry_state', 'transport_vehicle', 'trip'),
    ),
    CatalogEntry(
        question="Bugun tibbiy ko'rikdan o'tmagan haydovchilar",
        sql="""SELECT
  d.full_name AS "Haydovchi",
  d.driver_availability_status AS "Bandlik holati",
  (
    SELECT
      MAX(m.shift_date)
    FROM public.medical_inspection AS m
    WHERE
      m.driver_id = d.id
  ) AS "Oxirgi ko'rik sanasi",
  d.medical_cleared_today AS "Tizimdagi ruxsat bayrog'i",
  MAX(mi.inspected_at) AS "Bugungi oxirgi ko'rik",
  MAX(mi.status) AS "Bugungi natija"
FROM public.driver AS d
LEFT JOIN public.medical_inspection AS mi
  ON mi.driver_id = d.id AND CAST(mi.inspected_at AS DATE) = CURRENT_DATE
WHERE
  d.employment_status = 'ACTIVE'
GROUP BY
  d.id,
  d.full_name,
  d.driver_availability_status,
  d.medical_cleared_today
HAVING
  COUNT(mi.id) FILTER(WHERE
    mi.status = 'FIT') = 0
ORDER BY
  3 ASC NULLS FIRST,
  d.full_name
LIMIT 50;""",
        tables=('driver', 'medical_inspection'),
    ),
    CatalogEntry(
        question="Har bir mashina bo'yicha oxirgi oydagi reys soni va bosib o'tilgan masofa",
        sql="""SELECT
  v.plate_number AS "Mashina",
  COUNT(*) AS "Reys soni",
  ROUND(SUM(t.actual_distance_km), 1) AS "Masofa (km)",
  ROUND(
    AVG(EXTRACT(EPOCH FROM (
      t.actual_arrival_at - t.scheduled_arrival_at
    )) / 60.0)
  ) AS "O'rtacha kechikish (daq)"
FROM public.trip AS t
LEFT JOIN public.transport_vehicle AS v
  ON v.id = t.vehicle_id
WHERE
  t.status = 'COMPLETED'
  AND t.actual_arrival_at >= CURRENT_DATE - INTERVAL '30 DAY'
GROUP BY
  v.plate_number
ORDER BY
  SUM(t.actual_distance_km) DESC NULLS LAST
LIMIT 50;""",
        tables=('trip', 'transport_vehicle'),
    ),
    CatalogEntry(
        question="Haydovchilar bo'yicha oxirgi oydagi ish soati va qo'shimcha soat",
        sql="""SELECT
  ds.driver_name AS "Haydovchi",
  COUNT(*) AS "Smena soni",
  ROUND(SUM(ds.planned_hours), 1) AS "Rejadagi soat",
  ROUND(SUM(ds.actual_hours), 1) AS "Ishlangan soat",
  ROUND(SUM(ds.overtime_hours), 1) AS "Qo'shimcha soat",
  ROUND(SUM(ds.night_hours), 1) AS "Tungi soat"
FROM public.driver_shift AS ds
WHERE
  ds.shift_date >= CURRENT_DATE - INTERVAL '30 DAY'
GROUP BY
  ds.driver_name
ORDER BY
  SUM(ds.overtime_hours) DESC NULLS LAST
LIMIT 50;""",
        tables=('driver_shift',),
    ),
    CatalogEntry(
        question="Bo'limlar kesimida transport so'rovlari soni",
        sql="""SELECT
  rd.name AS "Bo'lim",
  COUNT(*) AS "Arizalar soni",
  COUNT(*) FILTER(WHERE
    tr.status LIKE 'PENDING%') AS "Tasdiq kutmoqda",
  COUNT(*) FILTER(WHERE
    tr.status = 'APPROVED') AS "Tasdiqlangan",
  COUNT(*) FILTER(WHERE
    tr.status LIKE 'REJECTED%') AS "Rad etilgan"
FROM public.transport_request AS tr
LEFT JOIN public.reference_data AS rd
  ON rd.id = tr.department_id
GROUP BY
  rd.name
ORDER BY
  COUNT(*) DESC
LIMIT 50;""",
        tables=('transport_request', 'reference_data'),
    ),
    CatalogEntry(
        question="Marshrut bo'yicha nuqtalar ketma-ketligi",
        sql="""SELECT
  r.route_number AS "Marshrut",
  rp.sequence_number AS "Tartib",
  rp.point_type AS "Nuqta turi",
  rp.location_name AS "Manzil",
  rp.distance_from_previous_km AS "Oldingidan masofa (km)",
  rp.planned_arrival_at AS "Rejadagi kelish"
FROM public.route_point AS rp
LEFT JOIN public.route AS r
  ON r.id = rp.route_id
ORDER BY
  r.route_number,
  rp.sequence_number
LIMIT 100;""",
        tables=('route_point', 'route'),
    ),
]


def find_match(question: str) -> CatalogEntry | None:
    for entry in CATALOG:
        if entry.matches(question):
            return entry
    return None


def similar(question: str, k: int = 3) -> list[CatalogEntry]:
    """Savolga so'zlari eng ko'p mos keladigan k ta yozuv (Jaccard o'xshashligi)."""
    q = tokens(question)
    if not q:
        return []
    scored = []
    for entry in CATALOG:
        e = tokens(entry.question)
        inter = len(q & e)
        if inter:
            scored.append((inter / len(q | e), entry))
    scored.sort(key=lambda x: x[0], reverse=True)
    return [e for _, e in scored[:k]]
