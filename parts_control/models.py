"""Javob sxemasi — Swagger shu modellardan chiziladi.

`null` — NOL EMAS: `life_km: null` "resurs cheksiz" emas, "noma'lum".
"""

from __future__ import annotations

from datetime import date, datetime
from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator


class PartFlag(BaseModel):
    code: str
    kind: Literal["MISMATCH", "EARLY", "CONTROL", "MAINTENANCE", "DATA"] = Field(
        ..., description="MISMATCH — qism mashinaga mos emas; EARLY — resursidan oldin; "
                         "CONTROL — hisobsiz; MAINTENANCE — resursi tugagan; DATA — ma'lumot xatosi")
    title: str
    detail: str


class SourceRef(BaseModel):
    title: str
    url: str = ""


class VehicleRef(BaseModel):
    vehicle_id: str | None = None
    plate_number: str | None = None
    vehicle: str | None = None
    transport_type: str | None = None


class RequestItem(VehicleRef):
    request_id: str
    repair_order_id: str | None = None
    item_name: str | None = None
    category: Literal["TIRE", "BATTERY", "OTHER"]
    status: str | None = None
    unit: str | None = None
    requested_quantity: float | None = None
    issued_quantity: float | None = None
    used_quantity: float | None = None
    returned_quantity: float | None = None
    requested_at: datetime | None = None
    issued_at: datetime | None = None
    requested_by: str | None = None
    issued_by: str | None = None
    battery_ah: int | None = Field(None, description="Nomdan o'qilgan sig'im")
    tire_rim: str | None = Field(None, description="Nomdan o'qilgan disk o'lchami (dyuym)")
    voltage: int | None = Field(None, description="Nomdan o'qilgan tizim kuchlanishi")
    flags: list[PartFlag] = Field(default_factory=list)


class InstalledItem(VehicleRef):
    part_id: str
    category: str | None = None
    name: str | None = None
    status: str | None = None
    installed_at: date | None = None
    install_date_is_entry_date: bool = Field(
        False, description="O'rnatilgan sana bazaga kiritilgan kun — oy bo'yicha resurs hisoblanmadi")
    used_km: float | None = None
    used_months: float | None = None
    used_hours: float | None = None
    life_km: float | None = None
    life_months: float | None = None
    life_hours: float | None = None
    warranty_months: float | None = None
    life_source: SourceRef | None = None
    used_pct: float | None = Field(None, description="Resursning necha foizi ishlatilgan "
                                                     "(birinchi tugaydigan o'lchov bo'yicha)")
    remaining_km: float | None = None
    remaining_months: float | None = None
    flags: list[PartFlag] = Field(default_factory=list)


class StockItem(BaseModel):
    item_name: str | None = None
    category: str
    quantity: float | None = None
    unit: str | None = None
    unit_price: float | None = None
    warehouse: str | None = None
    battery_ah: int | None = None
    tire_rim: str | None = None


class Summary(BaseModel):
    requests: int = 0
    flagged_requests: int = 0
    installed_parts: int = 0
    flagged_installed: int = 0
    by_code: dict[str, int] = Field(default_factory=dict)
    by_kind: dict[str, int] = Field(default_factory=dict)
    stock_items: int = 0


class Analysis(BaseModel):
    text: str = ""
    source: Literal["template", "llm"] = "template"
    items_considered: int = 0


class DataQuality(BaseModel):
    row_counts: dict[str, int] = Field(default_factory=dict)
    notes: list[str] = Field(default_factory=list)


class Scope(BaseModel):
    date_from: date
    date_to: date
    filters: dict[str, Any] = Field(default_factory=dict)


class ScanReport(BaseModel):
    generated_at: datetime
    scope: Scope
    summary: Summary
    analysis: Analysis
    requests: list[RequestItem] = Field(default_factory=list)
    installed: list[InstalledItem] = Field(default_factory=list)
    stock: list[StockItem] = Field(default_factory=list)
    data_quality: DataQuality
    elapsed_seconds: float = 0.0


class ModelNorm(BaseModel):
    vehicle: str
    transport_type: str | None = None
    category: str
    parts: int
    vehicles: int
    life_km: float | None = Field(None, description="Necha km yurishi kerak")
    life_km_source: SourceRef | None = None
    life_months: float | None = Field(None, description="Necha oy xizmat qilishi kerak")
    life_months_source: SourceRef | None = None
    warranty_months: float | None = None
    warranty_source: SourceRef | None = None
    worn: int = 0
    worn_avg_km: float | None = Field(None, description="Yeyilganlari amalda o'rtacha necha km yurgan")
    worn_early: int = 0
    over_life: int = 0
    avg_used_pct: float | None = None
    battery_ah: list[int] = Field(default_factory=list)
    tire_rims: list[str] = Field(default_factory=list)


class NormsReport(BaseModel):
    generated_at: datetime
    rows: list[ModelNorm] = Field(default_factory=list)
    sources: list[dict[str, str]] = Field(default_factory=list)
    elapsed_seconds: float = 0.0


# ================================================================ Pasport

ComponentStatus = Literal["OVERDUE", "DUE_SOON", "OK", "UNKNOWN", "NO_INTERVAL"]

#: `date` maydoni sinf ichida `date` turini yashiradi — tur shu nom bilan.
DateValue = date


class PassportEvent(BaseModel):
    date: DateValue | None = None
    action: str
    action_text: str = ""
    odometer_km: float | None = None
    engine_hours: float | None = None
    source: str = Field("", description="vehicle_repair / repair_order_part_request / "
                                        "vehicle_part / maintenance_plan / manual")
    reference: str | None = Field(None, description="Ta'mir raqami, qism nomi yoki yozuv #")
    note: str | None = None
    driver: str | None = None
    recorded_by: str | None = Field(None, description="Qo'lda yozuvni kim kiritgan (login)")
    entry_date: bool = Field(False, description="Sana — bazaga kiritilgan kun, o'rnatilgan emas")


class InstalledPiece(BaseModel):
    """Shina/akkumulyatorning bitta donasi. `null` — noma'lum, nol emas."""

    part_id: str | None = None
    name: str | None = None
    part_number: str | None = None
    size: str | None = None
    record_status: str | None = Field(None, description="ATIL dagi holati (INSTALLED, WORN...)")
    primary: bool | None = Field(None, description="Akkumulyator: asosiysi")
    installed_at: date | None = None
    entry_date: bool = Field(False, description="Sana — bazaga kiritilgan kun, qo'yilgan emas")
    installed_at_km: float | None = None
    installed_at_hours: float | None = None
    life_km: float | None = None
    life_months: float | None = None
    life_hours: float | None = None
    life_source: SourceRef | None = None
    since_km: float | None = Field(None, description="Qo'yilgandan beri yurgan km")
    since_months: float | None = None
    since_hours: float | None = None
    remaining_km: float | None = None
    remaining_months: float | None = None
    remaining_hours: float | None = None
    used_pct: float | None = None
    by: str | None = Field(None, description="Foiz qaysi o'lchovdan: km / months / hours")
    status: ComponentStatus
    status_text: str = ""
    estimated_due_date: date | None = Field(
        None, description="Kunlik o'rtacha yurish va oy resursi bo'yicha — qaysi biri oldin")
    text: str = ""


class ComponentItem(BaseModel):
    component: str = Field(..., description="Qism kodi (ENGINE_OIL, BRAKES, TIRES...)")
    name: str
    status: ComponentStatus = Field(
        ..., description="OVERDUE — vaqti o'tgan; DUE_SOON — korxona chegarasidan (80%) o'tdi; "
                         "OK; UNKNOWN — tarix yo'q; NO_INTERVAL — oraliq ma'lum emas")
    status_text: str
    interval_km: float | None = None
    interval_months: float | None = None
    interval_hours: float | None = None
    interval_source: SourceRef | None = None
    interval_note: str | None = None
    last_replaced: PassportEvent | None = Field(None, description="Oxirgi almashtirish/xizmat")
    last_repaired: PassportEvent | None = Field(None, description="Oxirgi ta'mir")
    events: int = 0
    since_km: float | None = None
    since_months: float | None = None
    since_hours: float | None = None
    used_pct: float | None = None
    next_due_km: float | None = None
    next_due_date: date | None = None
    next_due_hours: float | None = None
    remaining_km: float | None = None
    estimated_due_date: date | None = Field(
        None, description="O'rtacha kunlik yurish bo'yicha — km oralig'i qachon tugaydi")
    installed_count: int | None = None
    worn_count: int | None = None
    worst_part: PassportEvent | None = Field(
        None, description="Shina/akkumulyator: eng ko'p yeyilgan dona — used_pct shundan")
    parts: list[InstalledPiece] = Field(
        default_factory=list, description="Shina/akkumulyator: har bir dona, eng yeyilgani birinchi")
    detail: str = ""


class PassportAlert(BaseModel):
    component: str
    name: str
    status: ComponentStatus
    message: str


class VehicleCard(BaseModel):
    vehicle_id: str
    plate_number: str | None = None
    vehicle: str
    brand: str | None = None
    model: str | None = None
    transport_type: str | None = None
    usage_mode: str | None = None
    class_: str = Field(..., alias="class")
    class_name: str
    status: str | None = None
    release_year: int | None = None
    commissioning_date: date | None = None
    vin: str | None = None
    same_model_count: int = 0
    same_model_plates: list[str] = Field(default_factory=list)

    model_config = {"populate_by_name": True}


class ReadingsInfo(BaseModel):
    odometer_km: float | None = None
    engine_hours: float | None = None
    daily_km: float | None = None
    daily_hours: float | None = None
    last_reading_date: date | None = None
    dropped: int = Field(0, description="Boshqalariga zid bo'lgani uchun hisobga olinmagan "
                                        "o'lchovlar (orqaga ketgan yoki keskin sakragan)")


class PassportSummary(BaseModel):
    components: int = 0
    overdue: int = 0
    due_soon: int = 0
    ok: int = 0
    unknown: int = 0
    no_interval: int = 0
    warning_at_percent: float | None = Field(
        None, description="\"Vaqti yaqinlashdi\" chegarasi — vehicle_part.warning_at_percent")
    text: str = ""


class AssignedDriver(BaseModel):
    driver_id: str
    driver_name: str | None = None
    phone: str | None = None
    primary: bool = False
    license_valid_until: date | None = None
    medical_valid_until: date | None = None
    employment_status: str | None = None
    availability: str | None = None


class DriverHistory(BaseModel):
    driver_id: str | None = None
    driver_name: str | None = None
    first_trip: date | None = None
    last_trip: date | None = None
    trips: int = 0


class DriverPeriod(BaseModel):
    driver_id: str | None = None
    driver_name: str | None = None
    from_: date | None = Field(None, alias="from")
    to: date | None = None
    trips: int = 0

    model_config = {"populate_by_name": True}


class DriversInfo(BaseModel):
    assigned: list[AssignedDriver] = Field(default_factory=list)
    history: list[DriverHistory] = Field(default_factory=list)
    changes: list[DriverPeriod] = Field(
        default_factory=list, description="Haydovchi almashinuvi — eng yangisi birinchi")


class TimelineItem(PassportEvent):
    component: str | None = None
    name: str = ""


class ModelHistoryItem(BaseModel):
    component: str
    name: str
    replaced: int = 0
    repaired: int = 0
    vehicles: list[str] = Field(default_factory=list)
    last_date: date | None = None


class UsagePeriod(BaseModel):
    """`null` — noma'lum (masalan, davr ichida spidometr uzilgan), NOL EMAS."""

    days: int
    from_: date = Field(..., alias="from")
    to: date
    data_from: date | None = Field(None, description="Reys ma'lumoti boshlangan kun (davr ichida)")
    covered_days: int = 0
    km_odometer: float | None = Field(None, description="Spidometr bo'yicha")
    km_trips: float | None = Field(None, description="Bajarilgan reyslar yig'indisi bo'yicha")
    engine_hours_odometer: float | None = None
    engine_hours_trips: float | None = None
    trips: int = 0
    waybills: int = 0
    active_days: int = 0
    repair_days: int = 0
    idle_days: int = 0
    suspicious_trips: int = Field(0, description="Sutkasiga jismonan imkonsiz — hisobga olinmadi")
    cargo_waybills: int = Field(0, description="Yuk og'irligi yozilgan yo'l varaqalari")
    cargo_tons: float | None = None
    daily_km_trips: float | None = None
    text: str = ""

    model_config = {"populate_by_name": True}


class UsageProfile(BaseModel):
    data_start: date | None = Field(None, description="Bazada reyslar yozila boshlagan kun")
    periods: list[UsagePeriod] = Field(default_factory=list)


class VehiclePassport(BaseModel):
    generated_at: datetime
    vehicle: VehicleCard
    readings: ReadingsInfo
    usage: UsageProfile | None = Field(None, description="Ish profili: yurgan km, reys, "
                                                         "ishlagan/turgan kun, yuk")
    summary: PassportSummary
    alerts: list[PassportAlert] = Field(default_factory=list)
    components: list[ComponentItem] = Field(default_factory=list)
    drivers: DriversInfo
    history: list[TimelineItem] = Field(default_factory=list)
    model_history: list[ModelHistoryItem] = Field(
        default_factory=list, description="Shu rusumdagi BARCHA mashinalar bo'yicha qism tarixi")
    notes: list[str] = Field(default_factory=list)
    elapsed_seconds: float = 0.0

    # `model_history` — "model_" bilan boshlanadi, bu pydantic'ning o'z nomlari emas.
    model_config = {"protected_namespaces": ()}


class FleetVehicle(BaseModel):
    vehicle_id: str
    plate_number: str | None = None
    transport_type: str | None = None
    class_: str | None = Field(None, alias="class")
    worst_status: ComponentStatus
    overdue: int = 0
    due_soon: int = 0
    unknown: int = 0
    alerts: list[str] = Field(default_factory=list)
    odometer_km: float | None = None
    engine_hours: float | None = None


class FleetModel(BaseModel):
    vehicle: str
    class_: str = Field(..., alias="class")
    class_name: str
    count: int
    vehicles: list[FleetVehicle] = Field(default_factory=list)

    model_config = {"populate_by_name": True}


class FleetOverview(BaseModel):
    generated_at: datetime
    summary: dict[str, Any] = Field(default_factory=dict)
    models: list[FleetModel] = Field(default_factory=list)
    notes: list[str] = Field(default_factory=list)
    elapsed_seconds: float = 0.0


class ForecastVehicle(BaseModel):
    plate_number: str | None = None
    vehicle: str = ""
    count: int = 0
    overdue: int = Field(0, description="Shundan resursi tugagani")
    earliest_date: date | None = Field(None, description="Eng birinchi taxminiy muddat")


class StockItem(BaseModel):
    name: str | None = None
    quantity: float | None = None
    unit: str | None = None
    warehouse: str | None = None


class ForecastItem(BaseModel):
    """Bitta o'lcham (shina) yoki sig'im (akkumulyator) bo'yicha talab."""

    category: Literal["TIRE", "BATTERY"]
    spec: str | None = Field(None, description="Shina o'lchami (12R20) yoki sig'im (190 Ah); "
                                               "null — bazada yozilmagan")
    needed_now: int = Field(0, description="Resursi tugagan yoki yeyilgan — hozir kerak")
    needed_in_period: int = Field(0, description="Davr ichida taxminan tugaydi")
    needed_total: int = 0
    due_soon_undated: int = Field(0, description="Vaqti yaqin (80%+), sanasi noma'lum — "
                                                 "jamiga kirmaydi")
    vehicles: list[ForecastVehicle] = Field(default_factory=list)
    stock_quantity: float | None = Field(None, description="Omborda shu o'lcham; null — "
                                                           "solishtirib bo'lmaydi")
    stock_items: list[StockItem] = Field(default_factory=list)
    shortage: float | None = Field(None, description="needed_total − ombor (manfiy emas)")
    installed_last_12m: int = Field(0, description="O'tgan sarf: 12 oyda qo'yilgan")
    avg_per_month: float = 0.0
    expected_by_history: float = Field(0.0, description="O'tgan sarf bo'yicha shu davrga")
    text: str = ""


class ForecastService(BaseModel):
    """Miqdori bazada yo'q qism (moy, filtr...) — necha mashinada xizmat vaqti keladi."""

    component: str
    name: str
    needed_now: int = 0
    needed_in_period: int = 0
    due_soon_undated: int = 0
    vehicles: list[ForecastVehicle] = Field(default_factory=list)
    text: str = ""


class PendingRequest(BaseModel):
    item_name: str | None = None
    status: str | None = None
    requested_at: date | None = None
    plate_number: str | None = None
    vehicle: str = ""


class NotForecast(BaseModel):
    component: str
    name: str
    vehicles: int = Field(0, description="Shuncha mashinada tarix yoki oraliq yo'q")


class ForecastResponse(BaseModel):
    generated_at: datetime
    days: int
    from_: date = Field(..., alias="from")
    until: date
    category: str | None = None
    model: str | None = None
    summary: dict[str, Any] = Field(default_factory=dict)
    items: list[ForecastItem] = Field(default_factory=list)
    services: list[ForecastService] = Field(default_factory=list)
    pending_requests: list[PendingRequest] = Field(
        default_factory=list, description="Tasdiqlangan, lekin hali berilmagan qism so'rovlari")
    not_forecast: list[NotForecast] = Field(default_factory=list)
    notes: list[str] = Field(default_factory=list)
    elapsed_seconds: float = 0.0

    model_config = {"populate_by_name": True, "protected_namespaces": ()}


CheckVerdict = Literal["JUSTIFIED", "CHECK", "NO_DATA"]


class CheckItem(BaseModel):
    """Bitta dona (shina/akkumulyator) yoki qism — oxirgi almashtirishdan beri."""

    name: str | None = None
    installed_at: date | None = Field(None, description="Qo'yilgan / oxirgi almashtirilgan kun")
    entry_date: bool = Field(False, description="Sana — bazaga kiritilgan kun, qo'yilgan emas")
    ago: str | None = None
    status: ComponentStatus
    verdict: CheckVerdict
    used_pct: float | None = None
    since_km: float | None = None
    since_months: float | None = None
    since_hours: float | None = None
    remaining_km: float | None = Field(None, description="Standart bo'yicha yana shuncha")
    remaining_months: float | None = None
    remaining_hours: float | None = None
    life_source: SourceRef | None = None
    text: str = ""


class CheckResponse(BaseModel):
    generated_at: datetime
    vehicle: dict[str, Any]
    component: str
    name: str
    requested_quantity: int
    verdict: CheckVerdict = Field(..., description="JUSTIFIED — asosli; CHECK — yaqinda "
                                                   "almashtirilgan, avval tekshiring; NO_DATA — "
                                                   "oldingi almashtirish yoki oraliq yo'q")
    verdict_text: str
    counts: dict[str, int] = Field(default_factory=dict)
    items: list[CheckItem] = Field(default_factory=list)
    conclusion: str = Field("", description="Xulosa: qachon almashtirilgan, qancha yurgan, "
                                            "standart bo'yicha yana qancha yurishi kerak edi")
    recommendations: list[str] = Field(default_factory=list)
    sources: list[SourceRef] = Field(default_factory=list)
    elapsed_seconds: float = 0.0


class PassportResponse(BaseModel):
    """Raqam berilsa — `vehicle` (bitta mashina pasporti), berilmasa — `fleet` (butun park)."""

    mode: Literal["vehicle", "fleet"]
    vehicle: VehiclePassport | None = None
    fleet: FleetOverview | None = None
    record_id: int | None = Field(None, description="POST da — yozilgan voqea raqami")
    warnings: list[str] = Field(default_factory=list,
                                description="POST da — kiritilgan km/motosoat o'lchovlarga zid "
                                            "bo'lsa (yozuv saqlanadi, ko'rsatkich hisobga "
                                            "olinmaydi)")


class RecordRequest(BaseModel):
    plate_number: str | None = Field(None, examples=["85471LBA"])
    vehicle_id: str | None = None
    component: str = Field(..., description="Qism kodi: ENGINE_OIL, OIL_FILTER, BRAKES, TIRES, "
                                            "BATTERY... (GET javobidagi `component`)")
    action: Literal["REPLACED", "REPAIRED", "SERVICED", "INSPECTED"] = "REPLACED"
    event_date: date | None = Field(None, description="Berilmasa — bugun")
    odometer_km: float | None = Field(None, ge=0, description="Berilmasa — o'sha kungi spidometr")
    engine_hours: float | None = Field(None, ge=0)
    note: str | None = Field(None, max_length=500)
    lang: Literal["uz", "ru", "en"] = "uz"

    # `component` kabi `action` ham harf kattaligiga qaramaydi: sinovda
    # "replaced" 422 qaytardi, "engine_oil" esa o'tdi (28.10.2026).
    @field_validator("action", mode="before")
    @classmethod
    def _action_upper(cls, value: Any) -> Any:
        return value.upper() if isinstance(value, str) else value

    model_config = {
        "json_schema_extra": {
            "example": {"plate_number": "85471LBA", "component": "ENGINE_OIL",
                        "action": "REPLACED", "odometer_km": 18000,
                        "note": "Motor moyi va filtri almashtirildi"}
        }
    }
