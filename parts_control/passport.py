"""Mashina pasporti — har mashina uchun 15-16 qism: oxirgi almashtirish, ta'mir va navbatdagisi.

"85471LBA (Damas) — motor moyi: oxirgi marta 26.09.2026 da 45 210 km da
almashtirilgan; 15 000 km dan 15 900 km yurildi — VAQTI O'TGAN". Shu
gapning har bo'lagi bazadan:

    qaysi qism         `vehicle_reference.components` — mashina sinfi bo'yicha
    oxirgi voqea       ATIL ta'mirlari, qism so'rovlari, o'rnatilgan qismlar,
                       texnik xizmat rejasi + qo'lda yozilgan voqealar
    necha km o'tdi     yo'l varaqalari va texnik ko'riklardagi spidometr
    oraliq             `maintenance_plan` > `vehicle_tire_norm`/`vehicle_part`
                       > ishlab chiqaruvchi jadvali (manbali)

TARIX YO'Q — HOLAT NOMA'LUM. Taxmin qilinmaydi: "motor moyi 3 oy oldin
almashtirilgan bo'lsa kerak" degan gap noto'g'ri eslatma beradi. Birinchi
almashtirish yozilgan kundan qism kuzatila boshlaydi.

BU FAYLDA SQL YO'Q (`queries.py`). Hisob sof funksiyalarda, bazasiz sinaladi.
"""

from __future__ import annotations

import re
import time
from collections import Counter, defaultdict
from dataclasses import dataclass, field, replace
from datetime import date, datetime, timedelta
from typing import Any, Sequence

from parts_control import config, history, queries, rules, texts, usage
from parts_control.texts import t
from vehicle_reference import components as cat
from vehicle_reference import specs

# Voqea turlari.
REPLACED = "REPLACED"      # almashtirildi
SERVICED = "SERVICED"      # xizmat ko'rsatildi (tekshirildi, kerak bo'lsa almashtirildi)
REPAIRED = "REPAIRED"      # ta'mirlandi
INSPECTED = "INSPECTED"    # ko'rikdan o'tkazildi
BASELINE = "BASELINE"      # bazaga qayd etilgan holat (o'rnatilgan sana = kiritilgan kun)
ISSUED = "ISSUED"          # ombordan berilgan, hali ishlatilmagan
IN_REPAIR = "IN_REPAIR"    # ta'mir ochiq

#: Oraliqni "qaytadan boshlaydigan" voqealar. Ta'mir (masalan shina
#: yamash) oraliqni boshlamaydi — qism o'sha eski qism.
RESETTING = {REPLACED, SERVICED, BASELINE}

# Holatlar — tartibi og'irlik bo'yicha.
OVERDUE = "OVERDUE"
DUE_SOON = "DUE_SOON"
OK = "OK"
UNKNOWN = "UNKNOWN"          # oraliq bor, lekin tarix yo'q
NO_INTERVAL = "NO_INTERVAL"  # oraliq ma'lum emas — faqat tarix
STATUS_ORDER = {OVERDUE: 0, DUE_SOON: 1, UNKNOWN: 2, NO_INTERVAL: 3, OK: 4}

_REPLACE_RE = re.compile(r"almasht|замен|yangi\s|o.?rnatil|установ|qo.?yildi", re.I)
_CONDITIONAL_RE = re.compile(r"bo.?lsa|если|при необходимост|tekshir|провер", re.I)
_CATEGORY_COMPONENT = {
    "ENGINE": "ENGINE", "BRAKES": "BRAKES", "TIRES": "TIRES", "BATTERY": "BATTERY",
    "ELECTRICAL": "ELECTRICAL", "CHASSIS": "SUSPENSION",
}


@dataclass
class Event:
    component: str | None
    action: str
    day: date | None
    km: float | None = None
    hours: float | None = None
    source: str = ""
    reference: str | None = None
    note: str | None = None
    driver: str | None = None
    #: O'rnatilgan sana bazaga kiritilgan kun — oy bo'yicha hisob qilinmaydi.
    entry_date: bool = False
    #: Qo'lda yozuvni kim kiritgan (login) — haydovchi EMAS.
    recorded_by: str | None = None
    #: Kiritilgan km/motosoat o'lchovlarga zid bo'lsa — (kiritilgan, eng yaqin
    #: o'lchov sanasi, uning qiymati); o'sha ko'rsatkich hisobga olinmaydi.
    km_conflict: tuple[float, date, float] | None = None
    hours_conflict: tuple[float, date, float] | None = None


def _day(value: Any) -> date | None:
    """Mahalliy (Toshkent) sana — server UTC da bo'lsa ertalabki voqea
    aks holda oldingi kunga tushib qolardi."""
    if value is None:
        return None
    if isinstance(value, datetime):
        if value.tzinfo is not None:
            value = value.astimezone(config.LOCAL_TZ)
        return value.date()
    return value if isinstance(value, date) else None


def _median(values: Sequence[float]) -> float | None:
    clean = sorted(values)
    if not clean:
        return None
    mid = len(clean) // 2
    return clean[mid] if len(clean) % 2 else (clean[mid - 1] + clean[mid]) / 2


# =================================================================== Ko'rsatkich


def monotonic(series: Sequence[tuple[date, float]]) -> list[tuple[date, float]]:
    """Spidometr faqat OLDINGA yuradi — eng uzun o'smaydigan-emas zanjir.

    Bazada bir mashinaga bir kunda "152 229", "316 606" va "210 594" yozilgan,
    keyingi oylarda esa 100 000 dan 105 000 gacha tekis o'sgan. Vaqt bo'yicha
    eng uzun kamaymaydigan ketma-ketlik xato raqamlarni (katta ham, kichik ham)
    o'zi chiqarib tashlaydi — chegara kerak emas, faqat "orqaga yurmaydi".
    """
    import bisect

    # OXIRIDAN boshlab quriladi: teng uzunlikdagi zanjirlar ichidan boshida
    # KATTAROQ qiymatlisi tanlanadi. Aks holda "15 025" (bitta raqam tushib
    # qolgan) "100 086" o'rniga zanjir boshiga tushardi.
    backwards = sorted(series, reverse=True)
    tails: list[float] = []
    tail_index: list[int] = []
    previous = [-1] * len(backwards)
    for i, (_, value) in enumerate(backwards):
        pos = bisect.bisect_right(tails, -value)
        if pos == len(tails):
            tails.append(-value)
            tail_index.append(i)
        else:
            tails[pos] = -value
            tail_index[pos] = i
        previous[i] = tail_index[pos - 1] if pos > 0 else -1
    chain: list[tuple[date, float]] = []
    k = tail_index[-1] if tail_index else -1
    while k != -1:
        chain.append(backwards[k])
        k = previous[k]
    return chain


def _jumps(series: Sequence[tuple[date, float]], per_day: float) -> list[int]:
    """Fizik uzilishlar — qo'shni o'lchovlar orasida sutkasiga `per_day` dan
    ko'p (kunlar orasi +1: 1-kun ertalab va 2-kun kechqurun — 48 soat).
    Zanjir monoton bo'lgani uchun "1 005 → 22 818 motosoat" kabi sakrash
    unda qoladi; bu ikki tomon bitta o'lchovda emas."""
    return [i for i in range(1, len(series))
            if series[i][1] - series[i - 1][1]
            > ((series[i][0] - series[i - 1][0]).days + 1) * per_day]


@dataclass
class Readings:
    """Spidometr va motosoat — kun bo'yicha, xato raqamga chidamli."""

    km: list[tuple[date, float]] = field(default_factory=list)
    hours: list[tuple[date, float]] = field(default_factory=list)
    #: Zanjirga sig'magan (boshqalariga zid) o'lchovlar — pasportda izoh bo'ladi.
    dropped: int = 0

    @classmethod
    def from_rows(
        cls, rows: Sequence[dict[str, Any]], *, use_km: bool = True, use_hours: bool = True
    ) -> "Readings":
        """`use_km`/`use_hours` — mashina rejimi bo'yicha: motosoat texnikasida
        km ustuniga ham soat yoziladi (bazada LW300 da ikkalasi 5832).

        Bir kunning bir xil o'lchovi (yo'l varaqasi, ko'rik) BITTA hisoblanadi:
        aks holda takror yozuv zanjirni "ko'pchilik ovozi" bilan yutadi —
        85058GAA da 16.10 dagi "1 138" uch marta, 08.10 dagi 120 000 bir marta
        yozilgan (28.10.2026).
        """
        km = sorted({(r["day"], float(r["km"])) for r in rows
                     if use_km and r.get("day") is not None and rules.num(r.get("km"))})
        hours = sorted({(r["day"], float(r["hours"])) for r in rows
                        if use_hours and r.get("day") is not None and rules.num(r.get("hours"))})
        km_chain, hours_chain = monotonic(km), monotonic(hours)
        return cls(km=km_chain, hours=hours_chain,
                   dropped=len(km) - len(km_chain) + len(hours) - len(hours_chain))

    @staticmethod
    def _at(series: list[tuple[date, float]], day: date | None) -> float | None:
        """Sanagacha bo'lgan oxirgi `READING_WINDOW` o'lchovning MEDIANASI.

        Bitta xato raqam ("2 499 956 km") medianani buzmaydi. Sanadan oldin
        o'lchov bo'lmasa — keyingi o'lchovlar, faqat `READING_FALLBACK_DAYS`
        ichida (mashina bazaga keyinroq qo'shilgan bo'lishi mumkin). Undan
        uzoq bo'lsa — noma'lum: bir yildan keyingi spidometr o'sha kunniki emas.
        """
        if not series:
            return None
        window = max(1, config.READING_WINDOW)
        if day is None:
            values = [v for _, v in series[-window:]]
        else:
            limit = day + timedelta(days=config.READING_FALLBACK_DAYS)
            values = [v for d, v in series if d <= day][-window:] \
                or [v for d, v in series if day < d <= limit][:window]
        return _median(values)

    def km_at(self, day: date | None) -> float | None:
        return self._at(self.km, day)

    def hours_at(self, day: date | None) -> float | None:
        return self._at(self.hours, day)

    @property
    def current_km(self) -> float | None:
        return self._at(self.km, None)

    @property
    def current_hours(self) -> float | None:
        return self._at(self.hours, None)

    def jump_spans(self, axis: str) -> list[tuple[date, date]]:
        """Fizik uzilishlar — (oldingi o'lchov kuni, keyingisi). Shu oraliqni
        o'z ichiga olgan davrda spidometr farqi ishonchsiz (85019GAA: 11.09 →
        13.09 da 6 200 km)."""
        series, per_day = ((self.km, config.MAX_KM_PER_DAY) if axis == "km"
                           else (self.hours, config.HOURS_PER_DAY))
        return [(series[i - 1][0], series[i][0]) for i in _jumps(series, per_day)]

    def latest(self, axis: str) -> float | None:
        series = self.km if axis == "km" else self.hours
        return series[-1][1] if series else None

    def since(self, axis: str, start: float | None) -> float | None:
        """Joriy ko'rsatkich − `start`. Mediana oxirgi o'lchovdan biroz orqada
        qoladi: bugun qo'lda yozilgan "18 000 km" (mediana 17 950) zid emas —
        0. Eng oxirgi o'lchovdan ham katta bo'lsagina manfiy (zid)."""
        series = self.km if axis == "km" else self.hours
        current = self._at(series, None)
        if current is None or start is None:
            return None
        if current >= start:
            return current - start
        return 0.0 if series[-1][1] >= start else current - start

    def last_day(self) -> date | None:
        days = [d for d, _ in self.km[-1:]] + [d for d, _ in self.hours[-1:]]
        return max(days) if days else None

    def jump_after(self, axis: str, day: date | None) -> bool:
        """`day` dan (shu kun ham) keyin ko'rsatkichda fizik uzilish bormi —
        bo'lsa o'sha kungi qiymat bilan bugungisi bitta o'lchovda emas."""
        series, per_day = ((self.km, config.MAX_KM_PER_DAY) if axis == "km"
                           else (self.hours, config.HOURS_PER_DAY))
        return day is not None and any(series[i][0] >= day for i in _jumps(series, per_day))

    @staticmethod
    def _daily(series: list[tuple[date, float]], days: int, per_day: float) -> float | None:
        # Faqat oxirgi FIZIK UZILISHDAN keyingisi: tizim boshida yozilgan
        # "1 005 motosoat", "50 000 km" dan haqiqiy raqamga sakrash kunlik
        # o'rtachani buzmasin.
        cut = _jumps(series, per_day)
        series = series[cut[-1]:] if cut else series
        if len(series) < 2:
            return None
        # Zanjirdagi qiymatlar, mediana emas: ikki uchida mediana har xil
        # kechikadi — ikki o'lchovda (117 000 → 120 000, 30 kun) "kuniga 50 km"
        # chiqardi, 100 emas (29.10.2026). Xato sakrash yuqorida kesilgan.
        end_day, end_value = series[-1]
        start = end_day - timedelta(days=days)
        start_day, start_value = ([(d, v) for d, v in series if d <= start] or [series[0]])[-1]
        span = (end_day - start_day).days
        if span <= 0 or end_value <= start_value:
            return None
        return (end_value - start_value) / span

    @property
    def daily_km(self) -> float | None:
        return self._daily(self.km, config.DAILY_RATE_DAYS, config.MAX_KM_PER_DAY)

    @property
    def daily_hours(self) -> float | None:
        return self._daily(self.hours, config.DAILY_RATE_DAYS, config.HOURS_PER_DAY)


# ===================================================================== Voqealar


def repair_events(rows: Sequence[dict[str, Any]], readings: Readings) -> list[Event]:
    """ATIL ta'mirlari -> qism voqealari.

    Ta'mir matni bo'laklarga ajratiladi (nosozlik joyi, bajarilgan ish, ish
    bandlari): "moy almashtirish" — motor moyi ALMASHTIRILDI, "old tormoz" —
    tormoz TA'MIRLANDI. Matnda hech bir qism tanilmasa — ATIL kategoriyasi
    (BRAKES, TIRES...) bo'yicha.
    """
    events: list[Event] = []
    for row in rows:
        status = (row.get("status") or "").upper()
        if status in ("CANCELLED", "REJECTED"):
            continue
        closed = status == "CLOSED"
        day = _day(row.get("repaired_at") or row.get("completed_at")) if closed else None
        day = day or _day(row.get("detected_at") or row.get("opened_at"))
        fragments = [row.get("defect_area"), row.get("title"), row.get("work_performed"),
                     *((row.get("work_items") or "").split(" | "))]
        actions: dict[str, set[str]] = defaultdict(set)
        for fragment in filter(None, fragments):
            found = cat.classify(fragment)
            if not found:
                continue
            action = REPAIRED
            if _REPLACE_RE.search(fragment):
                action = SERVICED if _CONDITIONAL_RE.search(fragment) else REPLACED
            for key in found:
                actions[key].add(action)
        if not actions:
            mapped = _CATEGORY_COMPONENT.get((row.get("component_category") or "").upper())
            if mapped:
                actions[mapped].add(REPAIRED)
        note = row.get("work_performed") or row.get("work_items") or row.get("description")
        for key, acts in actions.items():
            action = (REPLACED if REPLACED in acts else SERVICED if SERVICED in acts
                      else REPAIRED)
            events.append(Event(
                component=key, action=action if closed else IN_REPAIR, day=day,
                km=readings.km_at(day), hours=readings.hours_at(day), source="vehicle_repair",
                reference=row.get("repair_number") or row.get("title"),
                note=(note or "")[:160] or None, driver=row.get("driver_name"),
            ))
    return events


def request_events(rows: Sequence[dict[str, Any]], readings: Readings) -> list[Event]:
    """Qism so'rovlari: ISHLATILGAN — almashtirildi; BERILGAN — hali ishlatilmagan."""
    events: list[Event] = []
    for row in rows:
        status = (row.get("status") or "").upper()
        if status == "USED":
            action, day = REPLACED, _day(row.get("used_at") or row.get("issued_at")
                                         or row.get("requested_at"))
        elif status == "ISSUED":
            action, day = ISSUED, _day(row.get("issued_at") or row.get("requested_at"))
        else:
            continue
        keys = cat.classify(row.get("item_name")) or [None]
        for key in keys:
            events.append(Event(
                component=key, action=action, day=day, km=readings.km_at(day),
                hours=readings.hours_at(day), source="repair_order_part_request",
                reference=row.get("item_name"),
            ))
    return events


def part_events(parts: Sequence[dict[str, Any]]) -> list[Event]:
    """O'rnatilgan shina va akkumulyatorlar — o'rnatilgan kun va km."""
    events: list[Event] = []
    for part in parts:
        category = (part.get("category") or "").upper()
        key = {"TIRE": "TIRES", "BATTERY": "BATTERY"}.get(category)
        if not key:
            continue
        entry = rules.is_entry_date(part)
        events.append(Event(
            component=key, action=BASELINE if entry else REPLACED, day=part.get("installed_at"),
            km=rules.num(part.get("installed_at_km")),
            hours=rules.num(part.get("installed_at_engine_hours")), source="vehicle_part",
            reference=part.get("name"), entry_date=entry,
        ))
    return events


def plan_data(rows: Sequence[dict[str, Any]]) -> tuple[list[Event], dict[str, cat.Interval]]:
    """ATIL texnik xizmat rejasi — oxirgi xizmat VA korxona oralig'i."""
    kind_to_component = {k: c.key for c in cat.COMPONENTS.values() for k in c.plan_kinds}
    events: list[Event] = []
    intervals: dict[str, cat.Interval] = {}
    for row in rows:
        key = kind_to_component.get((row.get("kind") or "").upper())
        if not key:
            continue
        days = rules.num(row.get("interval_days"))
        intervals[key] = cat.Interval(
            km=rules.num(row.get("interval_km")), months=days / 30.4375 if days else None,
            hours=rules.num(row.get("interval_engine_hours")), source="db")
        if row.get("last_serviced_at"):
            events.append(Event(
                component=key, action=SERVICED, day=row["last_serviced_at"],
                km=rules.num(row.get("last_serviced_at_km")),
                hours=rules.num(row.get("last_serviced_engine_hours")),
                source="maintenance_plan", reference=row.get("maintenance_type"),
            ))
    return events, intervals


def reading_conflict(
    series: Sequence[tuple[date, float]], day: date | None, value: float | None, per_day: float
) -> tuple[date, float] | None:
    """Qo'lda kiritilgan ko'rsatkich o'lchovlarga ZIDmi — zid bo'lsa eng yaqin
    o'lchov (sana, qiymat).

    Spidometr orqaga yurmaydi va sutkasiga `per_day` dan ko'p oshmaydi.
    Orqaga bir sutkalik farqqa yo'l qo'yiladi: o'lchov kunning boshqa
    soatida olingan bo'lishi mumkin. Sinovda 85019GAA ga 50 000 km yozildi,
    30.09 dagi spidometr 16 128 km — tizim indamay qabul qilgandi (29.10.2026).
    """
    if value is None or day is None or not series:
        return None
    for d, v in [(d, v) for d, v in series if d <= day][-1:]:
        if not v - per_day <= value <= v + ((day - d).days + 1) * per_day:
            return d, v
    for d, v in [(d, v) for d, v in series if d > day][:1]:
        if not v - ((d - day).days + 1) * per_day <= value <= v + per_day:
            return d, v
    return None


def manual_events(rows: Sequence[dict[str, Any]], readings: Readings) -> list[Event]:
    events = []
    for row in rows:
        day = row.get("event_date")
        km = rules.num(row.get("odometer_km"))
        hours = rules.num(row.get("engine_hours"))
        km_hit = reading_conflict(readings.km, day, km, config.MAX_KM_PER_DAY)
        hours_hit = reading_conflict(readings.hours, day, hours, config.HOURS_PER_DAY)
        events.append(Event(
            component=row.get("component"), action=(row.get("action") or REPLACED).upper(),
            day=day,
            km=None if km_hit else km if km is not None else readings.km_at(day),
            hours=None if hours_hit else hours if hours is not None else readings.hours_at(day),
            source="manual", reference=f"#{row.get('id')}", note=row.get("note"),
            recorded_by=row.get("recorded_by"),
            km_conflict=(km, *km_hit) if km_hit else None,
            hours_conflict=(hours, *hours_hit) if hours_hit else None,
        ))
    return events


def record_warnings(
    vehicle_id: str, *, event_date: date | None, odometer_km: float | None,
    engine_hours: float | None, lang: str = texts.DEFAULT_LANG,
) -> list[str]:
    """POST javobi uchun: kiritilgan km/motosoat mashinaning o'lchovlariga zidmi.
    Yozuv RAD ETILMAYDI — bazada spidometr ba'zan ikki xil o'lchovda, qaysi
    biri to'g'riligini mexanik biladi."""
    vehicles = queries.fetch_vehicles([vehicle_id])
    if not vehicles:
        return []
    use_km, use_hours = usage_axes(vehicles[0].get("usage_mode"))
    readings = Readings.from_rows(queries.fetch_readings([vehicle_id]),
                                  use_km=use_km, use_hours=use_hours)
    day = event_date or date.today()
    out = []
    for value, series, per_day, unit in (
        (odometer_km, readings.km, config.MAX_KM_PER_DAY, "km"),
        (engine_hours, readings.hours, config.HOURS_PER_DAY, "hours"),
    ):
        hit = reading_conflict(series, day, value, per_day)
        if hit:
            out.append(_conflict_text(lang, None, value, hit, unit))
    return out


def _conflict_text(lang: str, reference: str | None, value: float,
                   hit: tuple[date, float], unit: str) -> str:
    limit = config.MAX_KM_PER_DAY if unit == "km" else config.HOURS_PER_DAY
    return t(lang, "note.manual_reading_conflict",
             ref=reference or t(lang, "word.this_record"),
             value=t(lang, f"unit.{unit}", v=_fmt(value)), day=hit[0],
             reading=t(lang, f"unit.{unit}", v=_fmt(hit[1])),
             limit=t(lang, f"unit.{unit}", v=_fmt(limit)))


def _fmt(value: float) -> str:
    return f"{value:,.0f}".replace(",", " ")


# ======================================================================= Holat


def _ratio(used: float | None, limit: float | None) -> float | None:
    if used is None or not limit or used < 0:
        return None
    return used / limit * 100


def _possible(used: float | None, since: date | None, today: date, per_day: float) -> bool:
    """Fizik chegara: `since` kunidan beri sutkasiga `per_day` dan ko'p yurib
    (ishlab) bo'lmaydi, spidometr orqaga ham yurmaydi. Buzilsa boshlang'ich
    yoki joriy ko'rsatkich xato — o'sha o'lchov NOMA'LUM, taxmin qilinmaydi."""
    if used is None:
        return True
    if used < 0:
        return False
    return since is None or used <= ((today - since).days + 1) * per_day


def component_state(
    key: str,
    interval: cat.Interval | None,
    events: Sequence[Event],
    readings: Readings,
    *,
    today: date,
    warn_pct: float | None,
) -> dict[str, Any]:
    """Bitta qismning holati — oxirgi voqeadan beri o'tgan km/oy/soat va oraliq."""
    own = sorted((e for e in events if e.component == key),
                 key=lambda e: (e.day or date.min))
    last = own[-1] if own else None
    reset = next((e for e in reversed(own) if e.action in RESETTING), None)
    repaired = next((e for e in reversed(own) if e.action in (REPAIRED, IN_REPAIR)), None)

    has_interval = interval is not None and any((interval.km, interval.months, interval.hours))
    state: dict[str, Any] = {
        "key": key, "status": NO_INTERVAL if not has_interval else UNKNOWN,
        "interval": interval, "last_event": last, "last_replaced": reset,
        "last_repaired": repaired, "events": len(own), "used_pct": None, "by": None,
        "since_km": None, "since_months": None, "since_hours": None,
        "next_due_km": None, "next_due_date": None, "next_due_hours": None,
        "remaining_km": None, "estimated_due_date": None, "data_issues": 0,
    }
    if not has_interval or reset is None:
        return state

    cur_km = readings.current_km
    since_km = readings.since("km", reset.km)
    since_hours = readings.since("hours", reset.hours)
    real_day = None if reset.entry_date else reset.day
    # Fizik chegara VA voqeadan keyin uzilish yo'qligi: 85019GAA da 11.09 → 13.09
    # 6 200 km sakrash — 01.09 dagi almashtirishdan beri "6 969 km" bo'lib
    # chiqardi (29 kunga bo'linsa imkonli ko'rinadi, lekin ikki xil o'lchov).
    km_ok = _possible(since_km, real_day, today, config.MAX_KM_PER_DAY) and (
        since_km is None or not readings.jump_after("km", real_day))
    hours_ok = _possible(since_hours, real_day, today, config.HOURS_PER_DAY) and (
        since_hours is None or not readings.jump_after("hours", real_day))
    if not km_ok:
        since_km = None
    if not hours_ok:
        since_hours = None
    state["data_issues"] = (not km_ok) + (not hours_ok)
    since_months = (None if reset.entry_date or reset.day is None
                    else max(0.0, (today - reset.day).days / 30.4375))
    ratios = {
        "km": _ratio(since_km, interval.km),
        "months": _ratio(since_months, interval.months),
        "hours": _ratio(since_hours, interval.hours),
    }
    known = {k: v for k, v in ratios.items() if v is not None}
    state.update(since_km=since_km, since_months=since_months, since_hours=since_hours)
    # Ko'rsatkich zid bo'lsa "keyingisi X km da" ham ishonchsiz — qaysi biri
    # xatoligini bilmaymiz.
    if reset.km is not None and interval.km and km_ok:
        state["next_due_km"] = reset.km + interval.km
        if cur_km is not None:
            state["remaining_km"] = state["next_due_km"] - cur_km
            rate = readings.daily_km
            if rate and state["remaining_km"] > 0:
                state["estimated_due_date"] = today + timedelta(days=state["remaining_km"] / rate)
    if reset.day is not None and interval.months and not reset.entry_date:
        state["next_due_date"] = reset.day + timedelta(days=interval.months * 30.4375)
    if reset.hours is not None and interval.hours and hours_ok:
        state["next_due_hours"] = reset.hours + interval.hours
    if not known:
        return state
    by, pct = max(known.items(), key=lambda kv: kv[1])
    state.update(used_pct=round(pct, 1), by=by)
    if pct >= 100:
        state["status"] = OVERDUE
    elif warn_pct is not None and pct >= warn_pct:
        state["status"] = DUE_SOON
    else:
        state["status"] = OK
    return state


def installed_state(
    key: str,
    parts: Sequence[dict[str, Any]],
    tire_norm: cat.Interval | None,
    events: Sequence[Event],
    readings: Readings,
    *,
    today: date,
    warn_pct: float | None,
    life_values: dict[str, set[float]] | None = None,
) -> dict[str, Any]:
    """Shina va akkumulyator — har bir O'RNATILGAN dona alohida, eng ko'p yeyilgani hal qiladi.

    Oraliq: qismning o'zida (`vehicle_part.expected_life_*`), bo'lmasa shina
    me'yori (`vehicle_tire_norm`), akkumulyator uchun GOST R 53165.
    `life_values` — park bo'yicha resurslar: "4 000 km" yonida 40 000 bo'lsa
    nol tushib qolgan, u resurs olinmaydi.
    """
    category = "TIRE" if key == "TIRES" else "BATTERY"
    own = [p for p in parts if (p.get("category") or "").upper() == category]
    base = component_state(key, None, events, readings, today=today, warn_pct=warn_pct)
    suspect_values = (life_values or {}).get(category, ())
    issues = 0
    if tire_norm is not None and tire_norm.km and tire_norm.km * 10 in suspect_values:
        # Shina me'yori jadvalida ham nol tushib qolgan: 7.50R16 — "4 000"
        # (shu o'lcham Isuzu'da 60 000). Me'yorning km qismi olinmaydi.
        tire_norm = replace(tire_norm, km=None)
        issues += 1
    # Akkumulyator BITTA dona: o'rnatilganidan keyin yangisi almashtirilgani
    # yozilgan bo'lsa (qism so'rovi, ta'mir, qo'lda), `vehicle_part` dagi eski
    # yozuv eskirgan — hisob yangi almashtirishdan. Shinada bunday emas: bitta
    # balon almashtirilsa qolgan uchtasi o'sha eski shinalar.
    newer = next((e for e in reversed(sorted(
        (e for e in events if e.component == key and e.action in (REPLACED, SERVICED)
         and e.source != "vehicle_part" and e.day), key=lambda e: e.day))), None)
    if key == "BATTERY" and newer is not None:
        recorded = own
        own = [p for p in own if (p.get("installed_at") or date.min) >= newer.day]
        if recorded and not own:
            # Korxona resursi (24 oy) eski yozuvda turibdi — o'sha olinadi.
            months = next((rules.num(p.get("expected_life_months")) for p in recorded
                           if rules.num(p.get("expected_life_months"))), None)
            interval = cat.Interval(
                km=specs.BATTERY_LIFE["life_km"],
                months=months or specs.BATTERY_LIFE["life_months"],
                hours=specs.BATTERY_LIFE["life_engine_hours"],
                source="db" if months else specs.BATTERY_LIFE["source"])
            return component_state(key, interval, events, readings, today=today,
                                   warn_pct=warn_pct)
    if not own:
        interval = tire_norm if key == "TIRES" else cat.Interval(
            km=specs.BATTERY_LIFE["life_km"], months=specs.BATTERY_LIFE["life_months"],
            hours=specs.BATTERY_LIFE["life_engine_hours"], source=specs.BATTERY_LIFE["source"])
        state = component_state(key, interval, events, readings, today=today, warn_pct=warn_pct)
        state["data_issues"] += issues
        return state

    worst: dict[str, Any] | None = None
    worn = 0
    pieces: list[dict[str, Any]] = []
    for part in own:
        life = rules.life_of(part, part.get("transport_type"))
        life_km = life["km"][0]
        if life["km"][1] == "db" and life_km and life_km * 10 in suspect_values:
            # "4 000 km" — parkda 40 000 bor: nol tushib qolgan (/scan da
            # LIFE_VALUE_SUSPECT). 40 000 deb taxmin qilinmaydi — shina me'yori
            # yoki noma'lum. Aks holda 85427LBA shinasi "162% — vaqti o'tgan".
            life["km"] = (None, None)
            issues += 1
        if key == "TIRES" and tire_norm is not None and life["km"][0] is None \
                and life["hours"][0] is None:
            life.update(km=(tire_norm.km, "db"), hours=(tire_norm.hours, "db"))
        # Asos — qism yozuvining o'zi (joriy − o'rnatilgan, /scan ham shunday).
        # Yo'l varaqasi faqat SHU yozuvga mos kelsa yangilaydi: bazada ikki xil
        # spidometr bor (28.10.2026: 185 dona; 85116EBA qismda 344 435 km,
        # varaqada 18 623; 85818AA qismda 361 motosoat, varaqada 22 847).
        usage = rules.part_usage(part, today)
        created = _day(part.get("created_at"))
        for axis, start_col, now_col, per_day in (
                ("km", "installed_at_km", "current_odometer_km", config.MAX_KM_PER_DAY),
                ("hours", "installed_at_engine_hours", "current_engine_hours",
                 config.HOURS_PER_DAY)):
            start = rules.num(part.get(start_col))
            since = readings.since(axis, start)
            if since is None or since < 0:
                continue
            row_now = rules.num(part.get(now_col))
            # Yozuvning o'zi zid bo'lsa (joriy < o'rnatilgan, masalan 0) — u o'lchov emas.
            if row_now is not None and row_now >= (start or 0) and not _possible(
                    readings.latest(axis) - row_now, created, today, per_day):
                issues += 1
                continue
            usage[axis] = since
        real_day = None if rules.is_entry_date(part) else _day(part.get("installed_at"))
        for axis, per_day in (("km", config.MAX_KM_PER_DAY), ("hours", config.HOURS_PER_DAY)):
            if not _possible(usage.get(axis), real_day, today, per_day):
                usage[axis] = None
                issues += 1
        ratios = {axis: _ratio(usage.get(axis), life[axis][0]) for axis in ("km", "months", "hours")}
        known = {k: v for k, v in ratios.items() if v is not None}
        by, pct = max(known.items(), key=lambda kv: kv[1]) if known else (None, None)
        if (part.get("status") or "").upper() == "WORN":
            worn += 1
            pct = max(pct or 0.0, 100.0)
        pieces.append(_piece(part, life, usage, pct, by, warn_pct, readings, today))
        candidate = {"part": part, "life": life, "usage": usage, "pct": pct, "by": by}
        if worst is None or (pct or -1) > (worst["pct"] or -1):
            worst = candidate

    life = worst["life"]
    interval = cat.Interval(km=life["km"][0], months=life["months"][0], hours=life["hours"][0],
                            source=life["km"][1] or life["months"][1] or life["hours"][1])
    pct = worst["pct"]
    status = UNKNOWN if pct is None else OVERDUE if pct >= 100 else \
        DUE_SOON if warn_pct is not None and pct >= warn_pct else OK
    latest = max(own, key=lambda p: p.get("installed_at") or date.min)
    # Foiz ENG ESKI donadan, "oxirgi almashtirish" esa eng yangisidan — qaysi
    # dona ekanini aytmasa chalg'itadi (85058GAA: 2 shina 2024-12-12 da, 4 tasi
    # 2026-04-10 da qo'yilgan; 81.9% eskilariniki).
    worst_part = worst["part"]
    worst_entry = rules.is_entry_date(worst_part)
    base.update(
        status=status, interval=interval, used_pct=round(pct, 1) if pct is not None else None,
        by=worst["by"], data_issues=issues,
        since_km=worst["usage"].get("km"), since_months=worst["usage"].get("months"),
        since_hours=worst["usage"].get("hours"), installed_count=len(own), worn_count=worn,
        pieces=sorted(pieces, key=lambda p: -(p["used_pct"] if p["used_pct"] is not None else -1)),
        worst_part=Event(
            component=key, action=BASELINE if worst_entry else REPLACED,
            day=worst_part.get("installed_at"), km=rules.num(worst_part.get("installed_at_km")),
            hours=rules.num(worst_part.get("installed_at_engine_hours")),
            source="vehicle_part", reference=worst_part.get("name"), entry_date=worst_entry),
    )
    if base["last_replaced"] is None:
        base["last_replaced"] = Event(
            component=key, action=BASELINE if rules.is_entry_date(latest) else REPLACED,
            day=latest.get("installed_at"), km=rules.num(latest.get("installed_at_km")),
            source="vehicle_part", reference=latest.get("name"),
            entry_date=rules.is_entry_date(latest))
    return base


def _piece(
    part: dict[str, Any], life: dict[str, tuple[float | None, str | None]],
    usage: dict[str, float | None], pct: float | None, by: str | None,
    warn_pct: float | None, readings: Readings, today: date,
) -> dict[str, Any]:
    """Bitta o'rnatilgan dona — "balonlari qachon qo'yilgan, qachongacha chidaydi?".

    Qolgani — resurs − o'shandan beri ishlatilgani (km, oy, motosoat — qaysi
    biri ma'lum bo'lsa). Taxminiy sana — kunlik o'rtacha yurish bo'yicha va oy
    resursidan; qaysi biri BIRINCHI kelsa. Kunlik yurish noma'lum bo'lsa km
    bo'yicha sana aytilmaydi — taxmin qilinmaydi.
    """
    status = UNKNOWN if pct is None else OVERDUE if pct >= 100 else \
        DUE_SOON if warn_pct is not None and pct >= warn_pct else OK
    remaining = {axis: life[axis][0] - usage[axis]
                 if life[axis][0] and usage.get(axis) is not None else None
                 for axis in ("km", "months", "hours")}
    dates = []
    for axis, rate in (("km", readings.daily_km), ("hours", readings.daily_hours)):
        if remaining[axis] is not None and rate:
            dates.append(today + timedelta(days=max(0.0, remaining[axis]) / rate))
    if remaining["months"] is not None:
        dates.append(today + timedelta(days=max(0.0, remaining["months"]) * 30.4375))
    if pct is not None and pct >= 100:
        dates = []  # Resursi tugagan (yoki yeyilgan deb belgilangan) — sana emas, holat.
    entry = rules.is_entry_date(part)
    return {
        "part_id": part.get("part_id"), "name": part.get("name"),
        "part_number": part.get("part_number"), "size": part.get("tire_size"),
        "record_status": part.get("status"), "primary": part.get("primary_battery"),
        "installed_at": _day(part.get("installed_at")), "entry_date": entry,
        "installed_at_km": rules.num(part.get("installed_at_km")),
        "installed_at_hours": rules.num(part.get("installed_at_engine_hours")),
        "life_km": life["km"][0], "life_months": life["months"][0],
        "life_hours": life["hours"][0],
        "life_source": life["km"][1] or life["months"][1] or life["hours"][1],
        "since_km": usage.get("km"), "since_months": usage.get("months"),
        "since_hours": usage.get("hours"),
        "remaining_km": remaining["km"], "remaining_months": remaining["months"],
        "remaining_hours": remaining["hours"],
        "used_pct": round(pct, 1) if pct is not None else None, "by": by, "status": status,
        "estimated_due_date": min(dates) if dates else None,
    }


# ================================================================ Haydovchilar


def driver_periods(trips: Sequence[dict[str, Any]]) -> list[dict[str, Any]]:
    """Yo'l varaqalari bo'yicha haydovchi davrlari — almashinuv tarixi.

    Ketma-ket bir haydovchining varaqalari bitta davrga birlashadi:
    "A — 01.09 dan 15.09 gacha (12 reys), B — 16.09 dan ...".
    """
    periods: list[dict[str, Any]] = []
    for trip in trips:
        driver = trip.get("driver_id")
        if periods and periods[-1]["driver_id"] == driver:
            periods[-1]["to"] = trip.get("day") or periods[-1]["to"]
            periods[-1]["trips"] += 1
        else:
            periods.append({"driver_id": driver, "driver_name": trip.get("driver_name"),
                            "from": trip.get("day"), "to": trip.get("day"), "trips": 1})
    return periods


def warn_percent(parts: Sequence[dict[str, Any]]) -> float | None:
    """"Vaqti yaqinlashdi" chegarasi — korxona siyosati (`vehicle_part.warning_at_percent`)."""
    values = Counter(rules.num(p.get("warning_at_percent")) for p in parts
                     if rules.num(p.get("warning_at_percent")))
    return values.most_common(1)[0][0] if values else None


def tire_norm_interval(rows: Sequence[dict[str, Any]]) -> cat.Interval | None:
    """Mashinaning shina me'yori. "PROBE" o'lchamli yozuvlar — sinov, oxiriga qo'yiladi."""
    usable = [r for r in rows if rules.num(r.get("expected_life_km"))
              or rules.num(r.get("expected_life_engine_hours"))]
    if not usable:
        return None
    usable.sort(key=lambda r: (r.get("tire_size") or "").upper() == "PROBE")
    row = usable[0]
    months = rules.num(row.get("expected_life_months"))
    return cat.Interval(km=rules.num(row.get("expected_life_km")),
                        hours=rules.num(row.get("expected_life_engine_hours")),
                        months=months, source="db")


# ===================================================================== Yig'ish


class NotFound(LookupError):
    def __init__(self, message: str, suggestions: list[str] | None = None):
        super().__init__(message)
        self.suggestions = suggestions or []


def resolve_vehicle(plate_number: str | None, vehicle_id: str | None) -> str:
    if vehicle_id:
        return vehicle_id
    if not plate_number:
        raise NotFound("plate_number yoki vehicle_id bering")
    rows = queries.find_vehicles_by_plate(plate_number)
    if len(rows) == 1:
        return rows[0]["vehicle_id"]
    plates = [r.get("plate_number") or r["vehicle_id"][:8] for r in rows]
    if not rows:
        raise NotFound(f"Mashina topilmadi: {plate_number}")
    raise NotFound(f"Bir nechta mashina mos keldi: {plate_number}", plates)


@dataclass
class Fleet:
    """Park bo'yicha bir martada o'qilgan ma'lumot — mashinalarga bo'lingan."""

    vehicles: list[dict[str, Any]]
    repairs: dict[str, list[dict[str, Any]]]
    requests: dict[str, list[dict[str, Any]]]
    parts: dict[str, list[dict[str, Any]]]
    plans: dict[str, list[dict[str, Any]]]
    norms: dict[str, list[dict[str, Any]]]
    readings: dict[str, list[dict[str, Any]]]
    manual: dict[str, list[dict[str, Any]]]
    warn_pct: float | None
    manual_error: str | None = None
    #: Park bo'yicha qism turi → resurslar (km) — shubhali "4 000" uchun.
    life_values: dict[str, set[float]] = field(default_factory=dict)


def _group(rows: Sequence[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        grouped[str(row.get("vehicle_id"))].append(row)
    return grouped


def _manual_rows() -> tuple[list[dict[str, Any]], str | None]:
    try:
        return history.read(), None
    except history.HistoryError as exc:
        return [], str(exc)[:160]


def load_fleet(
    vehicle_ids: Sequence[str] | None = None, vehicles: list[dict[str, Any]] | None = None
) -> Fleet:
    """Park ma'lumoti — `vehicle_ids=None` bo'lsa butun park (161 mashina).

    Bitta pasport uchun faqat shu mashina va shu rusumdagilar o'qiladi —
    `readings` butun park uchun 11 mingdan ortiq qator.

    So'rovlar ATAYLAB KETMA-KET: parallel qilinganda 2 s o'rniga 9-13 s
    o'lchandi (28.10.2026). Sabab `docs/db-connection-issue.md` da — bu
    bazaga YANGI ulanish ochish beqaror, ochilgan ulanish esa tez; parallel
    oqimlar pool'dan yangi ulanish talab qiladi.
    """
    ids = list(vehicle_ids) if vehicle_ids is not None else None
    done = {
        "vehicles": vehicles if vehicles is not None else queries.fetch_vehicles(ids),
        "repairs": queries.fetch_repairs(ids),
        "requests": queries.fetch_all_requests(ids),
        "parts": queries.fetch_installed(ids) if ids is not None else queries.fetch_installed(),
        "plans": queries.fetch_plans(ids),
        "norms": queries.fetch_tire_norms(ids),
        "readings": queries.fetch_readings(ids),
        "life_values": queries.fetch_life_values(),
    }
    manual_rows, manual_error = _manual_rows()
    if ids is not None:
        wanted = set(ids)
        manual_rows = [r for r in manual_rows if r.get("vehicle_id") in wanted]
    return Fleet(
        vehicles=done["vehicles"],
        repairs=_group(done["repairs"]),
        requests=_group(done["requests"]),
        parts=_group(done["parts"]),
        plans=_group(done["plans"]),
        norms=_group(done["norms"]),
        readings=_group(done["readings"]),
        manual=_group(manual_rows),
        warn_pct=warn_percent(done["parts"]),
        manual_error=manual_error,
        life_values=done["life_values"],
    )


def usage_axes(usage_mode: str | None) -> tuple[bool, bool]:
    """Qaysi ko'rsatkich ishonchli: KM — spidometr, MOTOSOAT — soat, ikkalasi — ikkalasi.
    Rejim yozilmagan bo'lsa ikkalasi ham olinadi."""
    mode = (usage_mode or "").upper()
    if not mode:
        return True, True
    return "KM" in mode, "MOTOSOAT" in mode


def vehicle_events(vehicle: dict[str, Any], fleet: Fleet) -> tuple[list[Event], Readings,
                                                                    dict[str, cat.Interval]]:
    vid = vehicle["vehicle_id"]
    use_km, use_hours = usage_axes(vehicle.get("usage_mode"))
    readings = Readings.from_rows(fleet.readings.get(vid, []), use_km=use_km,
                                  use_hours=use_hours)
    plan_events, plan_intervals = plan_data(fleet.plans.get(vid, []))
    events = (repair_events(fleet.repairs.get(vid, []), readings)
              + request_events(fleet.requests.get(vid, []), readings)
              + part_events(fleet.parts.get(vid, []))
              + plan_events
              + manual_events(fleet.manual.get(vid, []), readings))
    return events, readings, plan_intervals


def vehicle_states(vehicle: dict[str, Any], fleet: Fleet, *, today: date) -> dict[str, Any]:
    """Bitta mashinaning barcha kuzatiladigan qismlari holati."""
    vid = vehicle["vehicle_id"]
    cls = cat.vehicle_class(vehicle.get("brand"), vehicle.get("model"),
                            vehicle.get("transport_type"), vehicle.get("usage_mode"))
    events, readings, plan_intervals = vehicle_events(vehicle, fleet)
    parts = [{**p, "transport_type": vehicle.get("transport_type")}
             for p in fleet.parts.get(vid, [])]
    tire_norm = tire_norm_interval(fleet.norms.get(vid, []))

    keys = list(cat.CLASS_COMPONENTS[cls])
    # Ro'yxatda yo'q qismga voqea bo'lsa ham (yengil mashinaga "ilashish")
    # u ko'rsatiladi — tarix yashirilmaydi.
    for event in events:
        if event.component and event.component not in keys:
            keys.append(event.component)

    states = []
    for key in keys:
        if key in ("TIRES", "BATTERY"):
            state = installed_state(key, parts, tire_norm, events, readings,
                                    today=today, warn_pct=fleet.warn_pct,
                                    life_values=fleet.life_values)
        else:
            interval = (plan_intervals.get(key)
                        or cat.brand_interval(vehicle.get("brand"), vehicle.get("model"), key)
                        or cat.INTERVALS.get(cls, {}).get(key))
            state = component_state(key, interval, events, readings,
                                    today=today, warn_pct=fleet.warn_pct)
        states.append(state)
    return {"class": cls, "states": states, "events": events, "readings": readings}


# ==================================================================== Javob


def _src(key: str | None) -> dict[str, str] | None:
    if not key:
        return None
    return cat.SOURCES.get(key) or specs.source_info(key)


def _event_out(event: Event | None, lang: str) -> dict[str, Any] | None:
    if event is None:
        return None
    return {
        "date": event.day, "action": event.action, "action_text": t(lang, f"action.{event.action}"),
        "odometer_km": rules.num(event.km), "engine_hours": rules.num(event.hours),
        "source": event.source, "reference": event.reference, "note": event.note,
        "driver": event.driver, "recorded_by": event.recorded_by,
        "entry_date": event.entry_date,
    }


def render_state(
    state: dict[str, Any], lang: str, axes: tuple[bool, bool] = (True, True)
) -> dict[str, Any]:
    """`axes` — `usage_axes()`: motosoat texnikasida matnda km ko'rsatilmaydi
    (bazada traktor shinasi "2 km da qo'yilgan")."""
    key = state["key"]
    component = cat.COMPONENTS.get(key)
    interval: cat.Interval | None = state.get("interval")
    out = {
        "component": key,
        "name": component.name(lang) if component else key,
        "status": state["status"],
        "status_text": t(lang, f"status.{state['status']}"),
        "interval_km": interval.km if interval else None,
        "interval_months": round(interval.months, 1) if interval and interval.months else None,
        "interval_hours": interval.hours if interval else None,
        "interval_source": _src(interval.source) if interval else None,
        "interval_note": interval.note if interval and interval.note else None,
        "last_replaced": _event_out(state.get("last_replaced"), lang),
        "last_repaired": _event_out(state.get("last_repaired"), lang),
        "events": state.get("events", 0),
        "since_km": _round(state.get("since_km")),
        "since_months": _round(state.get("since_months")),
        "since_hours": _round(state.get("since_hours")),
        "used_pct": state.get("used_pct"),
        "next_due_km": _round(state.get("next_due_km")),
        "next_due_date": state.get("next_due_date"),
        "next_due_hours": _round(state.get("next_due_hours")),
        "remaining_km": _round(state.get("remaining_km")),
        "estimated_due_date": state.get("estimated_due_date"),
        "installed_count": state.get("installed_count"),
        "worn_count": state.get("worn_count"),
        "worst_part": _event_out(state.get("worst_part"), lang),
        "parts": [_piece_out(p, lang, axes) for p in state.get("pieces") or []],
    }
    out["detail"] = _detail(out, lang, axes)
    return out


def _piece_out(p: dict[str, Any], lang: str, axes: tuple[bool, bool]) -> dict[str, Any]:
    out = {**p, "status_text": t(lang, f"status.{p['status']}"),
           "life_source": _src(p["life_source"]) if p["life_source"] else None}
    for key in ("installed_at_km", "installed_at_hours", "since_km", "since_hours",
                "remaining_km", "remaining_hours"):
        out[key] = _round(p[key])
    for key in ("since_months", "remaining_months"):
        out[key] = round(p[key], 1) if p[key] is not None else None
    out["text"] = _piece_text(out, lang, axes)
    return out


def _piece_text(p: dict[str, Any], lang: str, axes: tuple[bool, bool]) -> str:
    """"Shina 7.5R16 (11GB502600): 2024-12-12 da qo'yilgan (70 882 km); o'shandan
    beri 49 118 km; resursi 60 000 km — 81.9% ishlatilgan; 10 882 km qoldi; ..."."""
    return f"{p['name'] or '—'}: " + piece_body(p, lang, axes)


def piece_body(p: dict[str, Any], lang: str, axes: tuple[bool, bool], *,
               no_rate: bool = True) -> str:
    """Donaning holati nomsiz. `no_rate=False` — "kunlik yurish noma'lum" yozilmaydi
    (bir xil donalar guruhlanganda u javob oxirida BIR MARTA aytiladi)."""
    def unit(axis: str, value: float) -> str:
        v = f"{value:,.1f}".rstrip("0").rstrip(".") if axis == "months" else f"{value:,.0f}"
        return t(lang, f"unit.{axis}", v=v.replace(",", " "))

    use_km, use_hours = axes
    at_axis = "km" if use_km and p["installed_at_km"] is not None else \
        "hours" if use_hours and p["installed_at_hours"] is not None else None
    at = f" ({unit(at_axis, p[f'installed_at_{at_axis}'])})" if at_axis else ""
    parts = [t(lang, "piece.entry", date=p["installed_at"]) if p["entry_date"]
             else t(lang, "piece.installed", date=p["installed_at"], at=at)]
    by = p["by"]
    if by:
        used = p[f"since_{by}"]
        parts.append(t(lang, "piece.used", v=unit(by, used)))
        parts.append(t(lang, "piece.life", life=unit(by, p[f"life_{by}"]), pct=p["used_pct"]))
        left = p[f"remaining_{by}"]
        parts.append(t(lang, "piece.left", v=unit(by, left)) if left is not None and left > 0
                     else t(lang, "piece.over"))
    if (p["record_status"] or "").upper() == "WORN":
        parts.append(t(lang, "piece.worn"))
    if p["estimated_due_date"]:
        parts.append(t(lang, "piece.until", date=p["estimated_due_date"]))
    elif no_rate and p["status"] in (OK, DUE_SOON):
        parts.append(t(lang, "piece.no_rate"))
    return "; ".join(parts)


def needs_rate_note(p: dict[str, Any]) -> bool:
    """Sana aytilmadi, chunki kunlik yurish noma'lum (resursi hali bor)."""
    return not p.get("estimated_due_date") and p["status"] in (OK, DUE_SOON)


def group_pieces(pieces: Sequence[dict[str, Any]], lang: str, axes: tuple[bool, bool], *,
                 rate_note: bool = True, suffix=None) -> list[str]:
    """Bir xil donalar bitta qatorda: 85058GAA da 4 ta shina bir kunda, bir km da
    qo'yilgan — 4 marta bir xil uzun qator yozilardi (chatda javob 3 barobar
    uzun, 30.10.2026). "Kunlik yurish noma'lum" ham oxirida bir marta."""
    groups: dict[tuple, list[dict[str, Any]]] = {}
    for p in pieces:
        key = (p["installed_at"], p["entry_date"], p["installed_at_km"], p["used_pct"],
               p["status"], p["record_status"], p["estimated_due_date"])
        groups.setdefault(key, []).append(p)
    lines = []
    for same in groups.values():
        names = _group_names([p["name"] for p in same])
        shown = ", ".join(names[:4]) + (f", +{len(names) - 4}" if len(names) > 4 else "")
        lines.append(t(lang, "piece.group", count=len(same), names=shown,
                       body=piece_body(same[0], lang, axes, no_rate=False))
                     + (suffix(same[0]) if suffix else ""))
    if rate_note and any(needs_rate_note(p) for p in pieces):
        lines.append(t(lang, "piece.no_rate_once"))
    return lines


def _group_names(names: Sequence[str | None]) -> list[str]:
    """Guruhdagi donalar nomi qisqa: "Shina 7.5R16 (11GB502600)" → "11GB502600".
    Qavs ichida seriya emas, tartib raqami bo'lsa ("Akkumulyator 6 ст-190 (1)",
    "(2)" — 85019GAA) — nomning o'zi, hammasi bir xil bo'lsa bir marta."""
    serials = [re.search(r"\(([^)]+)\)\s*$", n or "") for n in names]
    if all(m and len(m.group(1)) >= 5 for m in serials):
        return [m.group(1) for m in serials]
    bases = list(dict.fromkeys(re.sub(r"\s*\(\d{1,2}\)\s*$", "", n or "—") for n in names))
    return bases


def _round(value: float | None) -> float | None:
    return None if value is None else round(value, 1)


def _where(event: dict[str, Any], lang: str, axes: tuple[bool, bool]) -> str:
    use_km, use_hours = axes
    if use_km and event["odometer_km"] is not None:
        return t(lang, "unit.km", v=rules.fmt(event["odometer_km"]))
    if use_hours and event["engine_hours"] is not None:
        return t(lang, "unit.hours", v=rules.fmt(event["engine_hours"]))
    return "—"


def _detail(item: dict[str, Any], lang: str, axes: tuple[bool, bool] = (True, True)) -> str:
    status = item["status"]
    last = item.get("last_replaced") or item.get("last_repaired")
    parts: list[str] = []
    if last:
        parts.append(t(lang, "detail.last", action=last["action_text"],
                       date=str(last["date"] or "—"), at=_where(last, lang, axes)))
    worst = item.get("worst_part")
    if worst and (item.get("installed_count") or 0) > 1 and (
            not last or (worst["date"], worst["odometer_km"]) != (last["date"], last["odometer_km"])):
        parts.append(t(lang, "detail.worst", count=item["installed_count"],
                       name=worst["reference"] or "—", date=str(worst["date"] or "—"),
                       at=_where(worst, lang, axes)))
    if status in (OVERDUE, DUE_SOON, OK) and item.get("used_pct") is not None:
        parts.append(t(lang, "detail.used", pct=rules.fmt(item["used_pct"])))
        if item.get("next_due_km"):
            parts.append(t(lang, "detail.next_km", km=rules.fmt(item["next_due_km"])))
        if item.get("next_due_date"):
            parts.append(t(lang, "detail.next_date", date=str(item["next_due_date"])))
    elif status == UNKNOWN:
        # Tarix BOR, lekin ko'rsatkich yo'q yoki zid — "tarix yo'q" deyish yolg'on.
        parts.append(t(lang, "detail.usage_unknown" if last else "detail.unknown"))
    elif status == NO_INTERVAL:
        parts.append(t(lang, "detail.no_interval"))
    return "; ".join(parts)


def _vehicle_name(vehicle: dict[str, Any]) -> str:
    return rules.vehicle_name(vehicle.get("brand"), vehicle.get("model"))


def _model_key(vehicle: dict[str, Any]) -> str:
    return rules.model_key(vehicle.get("brand"), vehicle.get("model"))


def build_passport(vehicle_id: str, *, lang: str = texts.DEFAULT_LANG) -> dict[str, Any]:
    """Bitta mashina pasporti: qismlar, ogohlantirishlar, tarix, haydovchilar, rusum tarixi."""
    started = time.perf_counter()
    lang = texts.normalize(lang)
    today = date.today()
    all_vehicles = queries.fetch_vehicles()
    vehicle = next((v for v in all_vehicles if v["vehicle_id"] == vehicle_id), None)
    if vehicle is None:
        raise NotFound(f"Mashina topilmadi: {vehicle_id}")
    # Shu mashina va shu rusumdagilar — rusum tarixi uchun ular ham kerak.
    same_model = [v for v in all_vehicles if _model_key(v) == _model_key(vehicle)]
    fleet = load_fleet([v["vehicle_id"] for v in same_model], vehicles=same_model)

    result = vehicle_states(vehicle, fleet, today=today)
    readings: Readings = result["readings"]
    axes = usage_axes(vehicle.get("usage_mode"))
    components = [render_state(s, lang, axes) for s in result["states"]]
    components.sort(key=lambda c: STATUS_ORDER.get(c["status"], 9))
    alerts = [
        {"component": c["component"], "name": c["name"], "status": c["status"],
         "message": t(lang, f"alert.{c['status']}", name=c["name"], detail=c["detail"])}
        for c in components if c["status"] in (OVERDUE, DUE_SOON)
    ]

    # ------------------------------------------------- Ish profili
    work = usage.profile(
        today=today, data_start=queries.fetch_usage_start(),
        trips=queries.fetch_usage_trips([vehicle_id]),
        waybills=queries.fetch_usage_waybills([vehicle_id]),
        repairs=fleet.repairs.get(vehicle_id, []),
        km=readings.km, hours=readings.hours,
        km_jumps=readings.jump_spans("km"), hours_jumps=readings.jump_spans("hours"),
    )
    for p in work["periods"]:
        p["text"] = usage.period_text(p, lang, axes)

    # --------------------------------------------------- Haydovchilar
    trips = queries.fetch_driver_trips([vehicle_id])
    periods = driver_periods(trips)
    summary: dict[str, dict[str, Any]] = {}
    for trip in trips:
        did = trip.get("driver_id") or "—"
        row = summary.setdefault(did, {"driver_id": trip.get("driver_id"),
                                       "driver_name": trip.get("driver_name"),
                                       "first_trip": trip.get("day"), "last_trip": trip.get("day"),
                                       "trips": 0})
        row["trips"] += 1
        row["last_trip"] = trip.get("day") or row["last_trip"]
    assigned = [
        {"driver_id": d["driver_id"], "driver_name": d.get("full_name"), "phone": d.get("phone"),
         "primary": bool(d.get("primary_driver")),
         "license_valid_until": d.get("license_valid_until"),
         "medical_valid_until": d.get("medical_certificate_valid_until"),
         "employment_status": d.get("employment_status"),
         "availability": d.get("driver_availability_status")}
        for d in queries.fetch_assigned_drivers([vehicle_id])
    ]
    assigned.sort(key=lambda d: not d["primary"])

    # --------------------------------------------------------- Tarix
    timeline = [
        {"date": e.day, "component": e.component,
         "name": cat.COMPONENTS[e.component].name(lang) if e.component in cat.COMPONENTS
         else t(lang, "component.other"),
         **{k: v for k, v in (_event_out(e, lang) or {}).items() if k != "date"}}
        for e in result["events"]
    ]
    for row in queries.fetch_status_history([vehicle_id]):
        timeline.append({
            "date": _day(row.get("changed_at")), "component": None,
            "name": t(lang, "component.status"), "action": "STATUS",
            "action_text": f"{row.get('previous_status') or '—'} → {row.get('new_status')}",
            "source": "vehicle_status_history", "reference": row.get("reason"),
            "note": None, "driver": None, "odometer_km": None, "engine_hours": None,
            "entry_date": False,
        })
    timeline.sort(key=lambda r: r.get("date") or date.min, reverse=True)

    # -------------------------------------------------- Rusum tarixi
    name = _vehicle_name(vehicle)
    peers = [v for v in fleet.vehicles if _model_key(v) == _model_key(vehicle)]
    model_rows: dict[str, dict[str, Any]] = {}
    for peer in peers:
        events, _, _ = vehicle_events(peer, fleet)
        for e in events:
            if not e.component or e.action in (BASELINE, ISSUED):
                continue
            row = model_rows.setdefault(e.component, {
                "component": e.component, "name": cat.COMPONENTS[e.component].name(lang)
                if e.component in cat.COMPONENTS else e.component,
                "replaced": 0, "repaired": 0, "vehicles": set(), "last_date": None})
            row["replaced" if e.action in (REPLACED, SERVICED) else "repaired"] += 1
            row["vehicles"].add(peer.get("plate_number") or peer["vehicle_id"][:8])
            if e.day and (row["last_date"] is None or e.day > row["last_date"]):
                row["last_date"] = e.day
    model_history = sorted(
        ({**r, "vehicles": sorted(r["vehicles"])} for r in model_rows.values()),
        key=lambda r: -(r["replaced"] + r["repaired"]))

    # ------------------------------------------------------- Izohlar
    counts = Counter(c["status"] for c in components)
    notes: list[str] = []
    if counts.get(UNKNOWN):
        notes.append(t(lang, "note.passport_unknown", count=counts[UNKNOWN]))
    if counts.get(NO_INTERVAL):
        notes.append(t(lang, "note.passport_no_interval", count=counts[NO_INTERVAL]))
    if readings.current_km is None and readings.current_hours is None:
        notes.append(t(lang, "note.passport_no_readings"))
    if readings.dropped:
        notes.append(t(lang, "note.passport_readings_dropped", count=readings.dropped))
    issues = sum(s.get("data_issues") or 0 for s in result["states"])
    if issues:
        notes.append(t(lang, "note.passport_data_issues", count=issues))
    longest = max(work["periods"], key=lambda p: p["days"], default=None)
    if longest and longest["suspicious_trips"]:
        notes.append(t(lang, "note.usage_suspicious_trips", days=longest["days"],
                       count=longest["suspicious_trips"]))
    for e in result["events"]:
        for conflict, unit in ((e.km_conflict, "km"), (e.hours_conflict, "hours")):
            if conflict:
                entered, day, reading = conflict
                notes.append(_conflict_text(lang, e.reference, entered, (day, reading), unit))
    if fleet.manual_error:
        notes.append(t(lang, "note.passport_history_error", error=fleet.manual_error))

    cls = result["class"]
    return {
        "generated_at": datetime.now(),
        "vehicle": {
            "vehicle_id": vehicle_id,
            "plate_number": vehicle.get("plate_number"),
            "vehicle": name,
            "brand": vehicle.get("brand"),
            "model": vehicle.get("model"),
            "transport_type": vehicle.get("transport_type"),
            "usage_mode": vehicle.get("usage_mode"),
            "class": cls,
            "class_name": cat.CLASS_NAMES[cls].get(lang) or cat.CLASS_NAMES[cls]["uz"],
            "status": vehicle.get("current_status"),
            "release_year": vehicle["release_date"].year if vehicle.get("release_date") else None,
            "commissioning_date": vehicle.get("commissioning_date"),
            "vin": vehicle.get("vin"),
            "same_model_count": len(peers),
            "same_model_plates": sorted(p.get("plate_number") or "—" for p in peers),
        },
        "readings": {
            "odometer_km": _round(readings.current_km),
            "engine_hours": _round(readings.current_hours),
            "daily_km": _round(readings.daily_km),
            "daily_hours": _round(readings.daily_hours),
            "last_reading_date": readings.last_day(),
            "dropped": readings.dropped,
        },
        "usage": work,
        "summary": {
            "components": len(components),
            "overdue": counts.get(OVERDUE, 0),
            "due_soon": counts.get(DUE_SOON, 0),
            "ok": counts.get(OK, 0),
            "unknown": counts.get(UNKNOWN, 0),
            "no_interval": counts.get(NO_INTERVAL, 0),
            "warning_at_percent": fleet.warn_pct,
            "text": t(lang, "passport.summary", plate=vehicle.get("plate_number") or "—",
                      vehicle=name, total=len(components), overdue=counts.get(OVERDUE, 0),
                      soon=counts.get(DUE_SOON, 0),
                      unknown=counts.get(UNKNOWN, 0) + counts.get(NO_INTERVAL, 0)),
        },
        "alerts": alerts,
        "components": components,
        "drivers": {
            "assigned": assigned,
            "history": sorted(summary.values(), key=lambda d: d["last_trip"] or date.min,
                              reverse=True),
            "changes": list(reversed(periods))[: config.HISTORY_LIMIT],
        },
        "history": timeline[: config.HISTORY_LIMIT],
        "model_history": model_history,
        "notes": notes,
        "elapsed_seconds": round(time.perf_counter() - started, 3),
    }


def fleet_overview(
    *, model: str | None = None, status: str | None = None, lang: str = texts.DEFAULT_LANG
) -> dict[str, Any]:
    """Butun park: rusum bo'yicha nechta mashina va har birida nechta qismning vaqti keldi."""
    started = time.perf_counter()
    lang = texts.normalize(lang)
    today = date.today()
    fleet = load_fleet()
    models: dict[str, dict[str, Any]] = {}
    totals: Counter[str] = Counter()
    for vehicle in fleet.vehicles:
        name = _vehicle_name(vehicle)
        if model and model.lower() not in name.lower():
            continue
        result = vehicle_states(vehicle, fleet, today=today)
        counts = Counter(s["status"] for s in result["states"])
        alerts = [cat.COMPONENTS[s["key"]].name(lang) if s["key"] in cat.COMPONENTS else s["key"]
                  for s in result["states"] if s["status"] in (OVERDUE, DUE_SOON)]
        worst = min((s["status"] for s in result["states"]), key=lambda s: STATUS_ORDER[s],
                    default=UNKNOWN)
        if status and worst != status.upper():
            continue
        totals.update(counts)
        cls = result["class"]
        group = models.setdefault(_model_key(vehicle), {
            "names": Counter(), "classes": Counter(), "vehicles": []})
        group["names"][name] += 1
        group["classes"][cls] += 1
        group["vehicles"].append({
            "vehicle_id": vehicle["vehicle_id"], "plate_number": vehicle.get("plate_number"),
            "transport_type": vehicle.get("transport_type"), "class": cls, "worst_status": worst,
            "overdue": counts.get(OVERDUE, 0), "due_soon": counts.get(DUE_SOON, 0),
            "unknown": counts.get(UNKNOWN, 0) + counts.get(NO_INTERVAL, 0),
            "alerts": alerts,
            "odometer_km": _round(result["readings"].current_km),
            "engine_hours": _round(result["readings"].current_hours),
        })
    rows = []
    for group in models.values():
        # Bitta rusum bazada turlicha yozilgan ("KAMAZ"/"Kamaz") yoki bir xil
        # rusum turli rejimda (ZIL-138: km va motosoat) — ko'pchiligi ko'rsatiladi,
        # har mashinaning o'z sinfi `vehicles[].class` da.
        cls = group["classes"].most_common(1)[0][0]
        rows.append({
            "vehicle": group["names"].most_common(1)[0][0], "class": cls,
            "class_name": cat.CLASS_NAMES[cls].get(lang) or cat.CLASS_NAMES[cls]["uz"],
            "count": len(group["vehicles"]),
            "vehicles": sorted(group["vehicles"],
                               key=lambda v: (STATUS_ORDER[v["worst_status"]], -v["overdue"])),
        })
    rows.sort(key=lambda m: (-m["count"], m["vehicle"]))
    notes = [t(lang, "note.fleet_sources")]
    if fleet.manual_error:
        notes.append(t(lang, "note.passport_history_error", error=fleet.manual_error))
    return {
        "generated_at": datetime.now(),
        "summary": {
            "vehicles": sum(m["count"] for m in rows), "models": len(rows),
            "overdue": totals.get(OVERDUE, 0), "due_soon": totals.get(DUE_SOON, 0),
            "warning_at_percent": fleet.warn_pct,
        },
        "models": rows,
        "notes": notes,
        "elapsed_seconds": round(time.perf_counter() - started, 3),
    }


def record_event(
    *,
    vehicle_id: str,
    component: str,
    action: str,
    event_date: date | None,
    odometer_km: float | None,
    engine_hours: float | None,
    note: str | None,
    recorded_by: str | None,
) -> int:
    """Qo'lda voqea yozish — tekshiruvdan keyin jadvalga."""
    component = component.upper()
    action = action.upper()
    if component not in cat.COMPONENTS:
        raise ValueError(f"Noma'lum qism: {component}. Mavjud: {', '.join(cat.COMPONENTS)}")
    if action not in history.ACTIONS:
        raise ValueError(f"Noma'lum voqea: {action}. Mavjud: {', '.join(history.ACTIONS)}")
    vehicles = queries.fetch_vehicles([vehicle_id])
    if not vehicles:
        raise NotFound(f"Mashina topilmadi: {vehicle_id}")
    day = event_date or date.today()
    if day > date.today():
        raise ValueError("Voqea sanasi kelajakda bo'lishi mumkin emas")
    return history.write({
        "recorded_by": recorded_by, "vehicle_id": vehicle_id,
        "plate_number": vehicles[0].get("plate_number"), "component": component,
        "action": action, "event_date": day, "odometer_km": odometer_km,
        "engine_hours": engine_hours, "note": (note or "")[:500] or None,
    })
