"""Ehtiyot qismlar nazorati — ikkita endpoint.

    GET /parts-control/scan    so'ralgan va o'rnatilgan qismlardagi shubhali holatlar
    GET /parts-control/norms   rusum bo'yicha resurs: necha km / oy yurishi kerak
"""

from __future__ import annotations

from datetime import date
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.concurrency import run_in_threadpool

from parts_control import check, config, forecast, history, passport, service
from parts_control.explain import analyze, fill_template
from parts_control.models import (
    CheckResponse,
    ForecastResponse,
    NormsReport,
    PassportResponse,
    RecordRequest,
    ScanReport,
)
from parts_control.queries import PartsDataError
from security import require_api_credentials
from vehicle_reference import components as cat

router = APIRouter(prefix="/parts-control", tags=["Ehtiyot qismlar nazorati"])


@router.get(
    "/scan",
    response_model=ScanReport,
    summary="Ehtiyot qismlar: mos kelmaydigan, erta almashtirilgan, hisobsiz",
    responses={503: {"description": "Bazaga ulanib bo'lmadi"}},
)
async def scan(
    date_from: date = Query(..., description="So'rovlar davri boshi", examples=["2026-09-01"]),
    date_to: date = Query(..., description="So'rovlar davri oxiri (kiradi)", examples=["2026-10-28"]),
    vehicle_id: str | None = Query(None),
    category: Literal["TIRE", "BATTERY", "OTHER"] | None = Query(None),
    limit: int = Query(config.DEFAULT_LIMIT, ge=1, le=config.MAX_LIMIT),
    analyze_result: bool | None = Query(None, alias="analyze",
                                        description="Xulosani LLM yozsinmi"),
    lang: Literal["uz", "ru", "en"] = Query("uz"),
) -> ScanReport:
    """**Qism so'rovlari (`requests`)** — davrdagi har bir so'rov mashinaning
    o'ziga solishtiriladi:

    | Belgi | Nima bilan solishtiriladi |
    |---|---|
    | `PART_FOR_OTHER_MODEL` | qism nomidagi marka (KAMAZ, Damas...) — mashina rusumi |
    | `VOLTAGE_MISMATCH` | nomdagi 12/24/28 V — mashina elektr tizimi |
    | `BATTERY_SPEC_MISMATCH` | nomdagi Ah — shu mashinada (yoki shu rusumda) o'rnatilgan akkumulyatorlar |
    | `TIRE_SIZE_MISMATCH` | nomdagi disk o'lchami (R12, R17.5) — mashinadagi shinalar |
    | `QTY_EXCEEDS_FITMENT` | berilgan shina soni — mashinadagi shinalar soni |
    | `ISSUED_NOT_USED` | berilgan − ishlatilgan − qaytarilgan |
    | `EARLY_REPLACEMENT` | eski qism resursining necha foizini yurgan (km, oy) va kafolat |

    **O'rnatilgan qismlar (`installed`)** — hozirgi holat: `WORN_EARLY`
    (resursidan oldin yeyilgan), `OVER_LIFE` (resursi tugagan, hali
    ishlatilyapti), `LIFE_VALUE_SUSPECT` (resurs 4 000 km — nol tushib qolgan).

    **Resurs**: bazadagi `expected_life_*` (korxona siyosati); bo'lmasa
    akkumulyator uchun GOST R 53165-2020 (24 oy / 90 000 km / 3000 motosoat).
    Shina kafolati — GOST 4754-97 (yengil avtomobil, 5 yil).

    **Ombor (`stock`)** — shina va akkumulyatorlarning JORIY qoldig'i;
    kirim-chiqim harakati bazada bo'sh — `data_quality` da aytiladi.
    """
    if date_from > date_to:
        raise HTTPException(422, "date_from date_to dan keyin bo'lishi mumkin emas")
    try:
        report = await run_in_threadpool(
            service.scan, date_from=date_from, date_to=date_to, vehicle_id=vehicle_id,
            category=category, limit=limit, lang=lang,
        )
    except PartsDataError as exc:
        raise HTTPException(503, f"Bazadan o'qib bo'lmadi: {exc}")
    fill_template(report, lang)
    if config.LLM_ANALYZE if analyze_result is None else analyze_result:
        await analyze(report, lang=lang)
    return ScanReport(**report)


@router.get(
    "/norms",
    response_model=NormsReport,
    summary="Rusum bo'yicha qism resursi — necha km va necha oy yurishi kerak",
    responses={503: {"description": "Bazaga ulanib bo'lmadi"}},
)
async def norms(
    category: Literal["TIRE", "BATTERY"] | None = Query(None),
    lang: Literal["uz", "ru", "en"] = Query("uz"),
) -> NormsReport:
    """Har rusum va qism turi uchun: **korxona belgilagan resurs** (km, oy),
    kafolat, va o'sha rusumdagi **yeyilgan qismlar amalda qancha yurgani**
    (`worn_avg_km`). Masalan: Damas shinasi 40 000 km, Isuzu — 60 000 km.

    Bazada resurs bo'lmasa manbasi bilan ma'lumotnomadan (`life_*_source`).
    """
    try:
        report = await run_in_threadpool(service.norms, category=category, lang=lang)
    except PartsDataError as exc:
        raise HTTPException(503, f"Bazadan o'qib bo'lmadi: {exc}")
    return NormsReport(**report)


# ======================================================== Mashina pasporti


@router.get(
    "/passport",
    response_model=PassportResponse,
    summary="Mashina pasporti: 15 qism — oxirgi almashtirish, ta'mir va vaqti kelganlari",
    responses={404: {"description": "Mashina topilmadi"},
               503: {"description": "Bazaga ulanib bo'lmadi"}},
)
async def passport_get(
    plate_number: str | None = Query(
        None, description="Davlat raqami (bo'shliq/chiziqcha farqi yo'q). Berilsa — shu "
                          "mashina pasporti; berilmasa — butun park", examples=["85471LBA"]),
    vehicle_id: str | None = Query(None),
    model: str | None = Query(None, description="Park ko'rinishida — rusum nomi bo'yicha filtr",
                              examples=["Damas"]),
    status: Literal["OVERDUE", "DUE_SOON", "OK", "UNKNOWN", "NO_INTERVAL"] | None = Query(
        None, description="Park ko'rinishida — eng og'ir holati shu bo'lgan mashinalar"),
    lang: Literal["uz", "ru", "en"] = Query("uz"),
) -> PassportResponse:
    """**Har mashina uchun 15-16 qism** (sinfiga qarab: yengil avtomobil, Isuzu
    N-seriya, yuk mashinasi, motosoat texnikasi): motor moyi, filtrlar, tormoz,
    shina, akkumulyator, dvigatel va boshqalar.

    Har qism uchun: **oxirgi marta qachon almashtirilgan/ta'mirlangan**
    (sana, km, kim, qaysi hujjat), **o'shandan beri qancha yurilgan**,
    **keyingisi qachon** va holat:

    | `status` | Ma'nosi |
    |---|---|
    | `OVERDUE` | vaqti o'tgan |
    | `DUE_SOON` | korxona chegarasidan (`warning_at_percent` = 80%) o'tdi |
    | `OK` | joyida |
    | `UNKNOWN` | oraliq bor, lekin tarix yo'q — **taxmin qilinmaydi** |
    | `NO_INTERVAL` | oraliq ma'lum emas — faqat tarix ko'rsatiladi |

    **Oraliq qayerdan**: ATIL `maintenance_plan` (korxona kiritgan) >
    `vehicle_tire_norm` / `vehicle_part` > ishlab chiqaruvchi jadvali
    (`interval_source` da havola).

    **Tarix manbalari**: ATIL ta'mirlari (`vehicle_repair` + ish bandlari),
    qism so'rovlari, o'rnatilgan qismlar, texnik xizmat rejasi va
    `POST /parts-control/passport` bilan qo'lda yozilgan voqealar.

    Pasportda yana: **haydovchilar** (biriktirilgan, kim qachon haydagan,
    almashinuv tarixi), **mashina tarixi** va **rusum tarixi** — shu
    rusumdagi barcha mashinalarda qaysi qism qancha almashtirilgan.
    """
    try:
        if plate_number or vehicle_id:
            vid = await run_in_threadpool(passport.resolve_vehicle, plate_number, vehicle_id)
            data = await run_in_threadpool(passport.build_passport, vid, lang=lang)
            return PassportResponse(mode="vehicle", vehicle=data)
        data = await run_in_threadpool(passport.fleet_overview, model=model, status=status,
                                       lang=lang)
        return PassportResponse(mode="fleet", fleet=data)
    except passport.NotFound as exc:
        raise HTTPException(404, {"message": str(exc), "suggestions": exc.suggestions})
    except PartsDataError as exc:
        raise HTTPException(503, f"Bazadan o'qib bo'lmadi: {exc}")


@router.post(
    "/passport",
    response_model=PassportResponse,
    summary="Qism almashtirilgani / ta'mirlanganini yozish",
    responses={404: {"description": "Mashina topilmadi"},
               422: {"description": "Noma'lum qism yoki noto'g'ri sana"},
               503: {"description": "Tarix bazasiga yozib bo'lmadi"}},
)
async def passport_record(
    body: RecordRequest,
    username: str = Depends(require_api_credentials),
) -> PassportResponse:
    """"Bugun 85471LBA ning motor moyi almashtirildi, 18 000 km" — shu kundan
    boshlab qism kuzatiladi va keyingi almashtirish vaqti hisoblanadi.

    Yozuv ATIL bazasiga emas (u faqat o'qish uchun), suhbat tarixi bazasidagi
    `parts_component_event` jadvaliga tushadi. Yozuv o'chirilmaydi: xato
    bo'lsa yangi to'g'ri yozuv qo'shiladi. Kim yozgani — logindan.

    Javob — yangilangan pasport.
    """
    try:
        vid = await run_in_threadpool(passport.resolve_vehicle, body.plate_number,
                                      body.vehicle_id)
        early: list[str] = []
        if body.action in ("REPLACED", "SERVICED") and body.component.upper() in cat.COMPONENTS:
            # Yozishdan OLDIN: yozilgach yangi yozuvning o'zi "0% — yaqinda" bo'lib qoladi.
            early = await run_in_threadpool(check.early_warning, vid, body.component,
                                            lang=body.lang)
        record_id = await run_in_threadpool(
            passport.record_event, vehicle_id=vid, component=body.component,
            action=body.action, event_date=body.event_date, odometer_km=body.odometer_km,
            engine_hours=body.engine_hours, note=body.note, recorded_by=username,
        )
        warnings = early + await run_in_threadpool(
            passport.record_warnings, vid, event_date=body.event_date,
            odometer_km=body.odometer_km, engine_hours=body.engine_hours, lang=body.lang,
        )
        data = await run_in_threadpool(passport.build_passport, vid, lang=body.lang)
    except passport.NotFound as exc:
        raise HTTPException(404, {"message": str(exc), "suggestions": exc.suggestions})
    except ValueError as exc:
        raise HTTPException(422, str(exc))
    except history.HistoryError as exc:
        raise HTTPException(503, f"Tarix bazasiga yozib bo'lmadi: {exc}")
    except PartsDataError as exc:
        raise HTTPException(503, f"Bazadan o'qib bo'lmadi: {exc}")
    return PassportResponse(mode="vehicle", vehicle=data, record_id=record_id,
                            warnings=warnings)


@router.get(
    "/forecast",
    response_model=ForecastResponse,
    response_model_by_alias=True,
    summary="Talab prognozi: yaqin davrda qaysi qism qancha kerak",
    responses={503: {"description": "Bazadan o'qib bo'lmadi"}},
)
async def forecast_get(
    days: int = Query(90, ge=7, le=365, description="Necha kunga oldindan"),
    category: Literal["TIRE", "BATTERY"] | None = Query(None),
    model: str | None = Query(None, description="Rusum nomi bo'yicha filtr", examples=["Damas"]),
    lang: Literal["uz", "ru", "en"] = Query("uz"),
    _: str = Depends(require_api_credentials),
) -> ForecastResponse:
    """Shina va akkumulyator — **o'lcham bo'yicha nechta kerak**: resursi
    tugagani (hozir) va davr ichida taxminan tugaydigani, omborda qancha bor,
    qancha yetishmaydi; o'tgan 12 oydagi sarf bilan solishtirish. Ikki usul
    ALOHIDA, aralashtirilmaydi.

    Boshqa qismlar (moy, filtr, kolodka) — miqdor bazada yo'q, shuning uchun
    **necha mashinada xizmat vaqti keladi**. Tarix yoki oraliq yo'q qismlar —
    `not_forecast` (taxmin qilinmaydi). Tasdiqlangan, lekin hali berilmagan
    qism so'rovlari — `pending_requests`.
    """
    try:
        data = await run_in_threadpool(forecast.build, days=days, category=category,
                                       model=model, lang=lang)
    except PartsDataError as exc:
        raise HTTPException(503, f"Bazadan o'qib bo'lmadi: {exc}")
    return ForecastResponse(**data)


@router.get(
    "/check",
    response_model=CheckResponse,
    summary="Almashtirish tekshiruvi: so'ralgan qismni berish asoslimi",
    responses={404: {"description": "Mashina topilmadi"},
               503: {"description": "Bazadan o'qib bo'lmadi"}},
)
async def check_get(
    plate_number: str | None = Query(None, examples=["85058GAA"]),
    vehicle_id: str | None = Query(None),
    component: str = Query(..., description="Qism kodi: TIRES, BATTERY, ENGINE_OIL, BRAKES...",
                           examples=["TIRES"]),
    quantity: int | None = Query(None, ge=1, le=50,
                                 description="Nechta dona so'ralgan (shina/akkumulyator)"),
    lang: Literal["uz", "ru", "en"] = Query("uz"),
    _: str = Depends(require_api_credentials),
) -> CheckResponse:
    """Qism **berishdan oldin**: oxirgi marta qachon almashtirilgan, o'shandan
    beri qancha yurgan, standart bo'yicha yana qancha yurishi kerak edi —
    va xulosa: `JUSTIFIED` (asosli), `CHECK` (yaqinda almashtirilgan —
    avval tekshiring) yoki `NO_DATA`. "Berma" demaydi: shikast haqiqiy sabab
    bo'lishi mumkin — `recommendations` da nima talab qilish kerakligi.

    Bir nechta dona (4 ta shina) — har biri alohida: eng yeyilganlari
    birinchi, qolgani uchun "tekshiring".
    """
    if component.upper() not in cat.COMPONENTS:
        raise HTTPException(422, f"Noma'lum qism: {component}. Mavjud: "
                                 f"{', '.join(cat.COMPONENTS)}")
    try:
        vid = await run_in_threadpool(passport.resolve_vehicle, plate_number, vehicle_id)
        data = await run_in_threadpool(check.evaluate, vid, component, quantity=quantity,
                                       lang=lang)
    except passport.NotFound as exc:
        raise HTTPException(404, {"message": str(exc), "suggestions": exc.suggestions})
    except PartsDataError as exc:
        raise HTTPException(503, f"Bazadan o'qib bo'lmadi: {exc}")
    return CheckResponse(**data)
