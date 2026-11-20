"""Qismlar katalogi — har mashina SINFI uchun kuzatiladigan 15-16 qism va xizmat oralig'i.

NIMA UCHUN SINF, RUSUM EMAS. Bazada 161 mashina 73 xil rusum/tur bo'lib
yozilgan ("Isuzu" + "Isuzu 82l" + "MSITTS ISIZU"...). Xizmat jadvali esa
dvigatel va ish turiga bog'liq: benzinli yengil avtomobil, Isuzu N-seriyali
dizel, og'ir yuk mashinasi, motosoat bilan ishlaydigan texnika.

ORALIQ QAYERDAN — USTUNLIK TARTIBIDA:
  1. ATIL `maintenance_plan` (shu mashina uchun korxona kiritgan oraliq);
  2. ATIL `vehicle_tire_norm` / `vehicle_part` (shina va akkumulyator);
  3. shu fayl — ishlab chiqaruvchi jadvali, MANBA HAVOLASI bilan.
Manba topilmagan qismning oralig'i `None`: u faqat TARIX bilan kuzatiladi
("oxirgi marta qachon almashtirilgan"), "vaqti keldi" hukmi chiqmaydi.
Taxminiy raqam yozilmaydi — noto'g'ri eslatma ishonchni yo'qotadi.

YANGI QISM YOKI SINF: `COMPONENTS` ga bitta yozuv, `CLASS_COMPONENTS` ga
kalit, kerak bo'lsa `INTERVALS` ga oraliq.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

#: Manbalar — javobda `source` maydoniga kalit yoziladi.
SOURCES: dict[str, dict[str, str]] = {
    "isuzu_n_pm": {
        "title": "Isuzu N-Series (NPR/NQR/NRR, dizel) texnik xizmat jadvali: moy 10 000 mil "
                 "(16 000 km) yoki 250 motosoat; og'ir sharoitda 7 500 mil / 200 soat",
        "url": "https://heavyvehicleinspection.com/blog/post/isuzu-n-series-pm-schedule-light-duty",
    },
    "lacetti_oil": {
        "title": "Chevrolet Lacetti reglamenti: motor moyi va filtri har 15 000 km",
        "url": "https://www.zr.ru/content/articles/805452-zamena-masla-v-dvigatele-maslyanogo-filtra-chevrolet-lacetti/",
    },
    "lacetti_service": {
        "title": "Daewoo Gentra / Chevrolet Lacetti: havo filtri 45 000 km; zavod antifrizi "
                 "240 000 km yoki 5 yil",
        "url": "https://www.zr.ru/content/articles/934420-daewoo-gentra-chevrolet-lacetti/",
    },
    "brake_fluid": {
        "title": "Tormoz suyuqligi: odatda 1-3 yil (DOT turiga qarab), mo'ljal — 2 yil",
        "url": "https://www.amic.ru/news/transport/kak-chasto-i-zachem-nado-menyat-tormoznuyu-zhidkost-364146",
    },
    "lacetti_plugs": {
        "title": "Chevrolet Lacetti reglamenti: svechalar 15 000 km da tekshiriladi, 30 000 km "
                 "da almashtiriladi",
        "url": "https://www.zr.ru/content/articles/805528-proverka-sostoyaniya-zamena-svechej-zazhiganiya-chevrolet-lacetti/",
    },
    "lacetti_timing": {
        "title": "Chevrolet Lacetti reglamenti: GRM tasmasi 30 000 km da tekshiriladi, 60 000 km "
                 "da almashtiriladi",
        "url": "https://www.zr.ru/content/articles/805080-proverka-sostoyaniya-zamena-remnya-privoda-gazoraspredelitelnogo-mexanizma-chevrolet-lacetti/",
    },
    "howo_371_pm": {
        "title": "Sinotruk HOWO 371HP xizmat jadvali: moy va moy filtri har 8 000 km / 6 oy "
                 "(birinchisi 2 000 km), yoqilg'i filtri 16 000 km, havo filtri 24 000 km, "
                 "antifriz 32 000 km, KPP va ko'prik moyi 60 000 km / 10 oy, tormoz qoplamasi "
                 "40 000 km",
        "url": "https://cnhtcgroup.com/wp-content/uploads/2024/11/HOWO-SERVICE-AND-MAINTENANCE-SCHEDULE.pdf",
    },
    "wheel_loader_pm": {
        "title": "G'ildirakli yuklagich texnik xizmati (OEM jadvali): moy 250 s, yoqilg'i va "
                 "havo filtri 500 s, gidravlika/uzatma/ko'prik moyi 1000 s, antifriz 2000 s",
        "url": "https://heavyvehicleinspection.com/blog/post/wheel-loader-preventive-maintenance-schedule",
    },
}


@dataclass(frozen=True)
class Component:
    key: str
    names: dict[str, str]
    #: ATIL `vehicle_repair.component_category` — matnda aniqroq belgi
    #: topilmasa ta'mir shu kategoriya orqali qismga bog'lanadi.
    repair_categories: tuple[str, ...] = ()
    #: ATIL `maintenance_plan.kind`.
    plan_kinds: tuple[str, ...] = ()
    #: Ta'mir, qism so'rovi va qo'lda yozilgan matndan qismni tanish.
    pattern: str = ""

    def name(self, lang: str) -> str:
        return self.names.get(lang) or self.names["uz"]


def _c(key: str, uz: str, ru: str, en: str, pattern: str, *,
       categories: tuple[str, ...] = (), plans: tuple[str, ...] = ()) -> Component:
    return Component(key, {"uz": uz, "ru": ru, "en": en}, categories, plans, pattern)


#: TARTIB MUHIM: matn bir nechta qismga mos kelsa ham hammasi olinadi,
#: lekin aniqroq (gidravlika moyi) umumiy (motor moyi) dan oldin turadi —
#: umumiy belgi faqat aniqrog'i topilmaganda ishlatiladi (`classify`).
COMPONENTS: dict[str, Component] = {c.key: c for c in (
    _c("HYDRAULIC_OIL", "Gidravlika moyi", "Гидравлическое масло", "Hydraulic oil",
       r"gidravli\w*\s+moy|гидравл\w*\s+масл|масл\w*\s+гидр"),
    _c("HYDRAULIC_FILTER", "Gidravlika filtri", "Гидравлический фильтр", "Hydraulic filter",
       r"gidravli\w*\s+filtr|гидравл\w*\s+фильтр"),
    _c("TRANSMISSION_OIL", "Uzatmalar qutisi moyi", "Масло КПП", "Transmission oil",
       r"uzatma\w*(\s+qutisi)?\s+moy|\bkpp\b|\bкпп\b|коробк\w*\s+передач|трансмисс"),
    _c("DIFFERENTIAL_OIL", "Ko'prik (reduktor) moyi", "Масло моста (редуктора)", "Axle oil",
       r"reduktor|редуктор|ko.?prik\w*\s+moy|мост\w*\s+масл|дифференц"),
    _c("OIL_FILTER", "Moy filtri", "Масляный фильтр", "Oil filter",
       r"moy\s+filtr|масл\w*\s+фильтр|фильтр\w*\s+масл"),
    _c("ENGINE_OIL", "Motor moyi", "Моторное масло", "Engine oil",
       r"\bmoy\b|moy\s+almasht|motor\s+moy|моторн\w*\s+масл|масл\w*\s+двигат|замен\w*\s+масл",
       categories=(), plans=("OIL_CHANGE",)),
    _c("AIR_FILTER", "Havo filtri", "Воздушный фильтр", "Air filter",
       r"havo\s+filtr|воздуш\w*\s+фильтр|фильтр\w*\s+воздуш"),
    _c("FUEL_FILTER", "Yoqilg'i filtri", "Топливный фильтр", "Fuel filter",
       r"yoqilg.{0,2}i\s+filtr|топлив\w*\s+фильтр|фильтр\w*\s+топлив|сепаратор"),
    _c("CABIN_FILTER", "Salon filtri", "Салонный фильтр", "Cabin filter",
       r"salon\s+filtr|салон\w*\s+фильтр"),
    _c("SPARK_PLUGS", "Svechalar", "Свечи зажигания", "Spark plugs", r"svecha|свеч"),
    _c("TIMING_BELT", "GRM tasmasi", "Ремень ГРМ", "Timing belt",
       r"\bgrm\b|\bгрм\b|timing|газораспредел", plans=("TIMING_BELT",)),
    _c("BRAKE_FLUID", "Tormoz suyuqligi", "Тормозная жидкость", "Brake fluid",
       r"tormoz\w*\s+suyuq|тормозн\w*\s+жидк"),
    _c("BRAKES", "Tormoz tizimi (kolodka, disk)", "Тормоза (колодки, диски)", "Brakes (pads, discs)",
       r"tormoz|тормоз|kolodka|колодк|baraban|барабан",
       categories=("BRAKES",), plans=("BRAKE_INSPECTION",)),
    _c("COOLANT", "Antifriz (sovutish suyuqligi)", "Антифриз", "Coolant",
       r"antifriz|антифриз|тосол|охлажда\w*\s+жидк|sovutish\s+suyuq"),
    _c("CLUTCH", "Ilashish (sseplenie)", "Сцепление", "Clutch",
       r"ilashish|sseplen|сцеплен|корзин"),
    _c("TIRE_ROTATION", "Shinalarni almashlab qo'yish", "Перестановка шин", "Tire rotation",
       r"rotation|перестанов\w*\s+шин", plans=("TIRE_ROTATION",)),
    _c("TIRES", "Shinalar (balon)", "Шины", "Tires",
       # "\bshina": "ma-shina-lar", "Moshina" ichida ham "shina" bor (29.10.2026).
       r"\bshina|balon|баллон|\bшин|шины|g.?ildirak|покрышк|avtoshina|автошин",
       categories=("TIRES",)),
    _c("BATTERY", "Akkumulyator", "Аккумулятор", "Battery",
       r"akkumul|аккумул|\bakb\b|\bакб\b|batare|батаре", categories=("BATTERY",)),
    _c("ELECTRICAL", "Generator / starter / elektr", "Генератор / стартер / электрика",
       "Alternator / starter / electrics",
       r"generator|генератор|starter|стартер|elektr|электр|проводк|фар\w*|габарит|плафон|lampa",
       categories=("ELECTRICAL",)),
    _c("SUSPENSION", "Yurish qismi (amortizator, rul)", "Ходовая (амортизаторы, рулевое)",
       "Suspension & steering",
       r"amortiz|амортиз|\brul\b|рулев|подвеск|ressor|рессор|шаров|stupitsa|ступиц|xodov|ходов",
       categories=("CHASSIS",)),
    _c("ENGINE", "Dvigatel (motor)", "Двигатель", "Engine",
       r"mator|\bmotor\b|dvigatel|двигател|мотор", categories=("ENGINE",)),
)}

_COMPILED = {k: re.compile(c.pattern, re.I) for k, c in COMPONENTS.items() if c.pattern}


def classify(text: str | None) -> list[str]:
    """Matndan qism kalitlari.

    Aniqrog'i topilganda FAQAT UNING SO'ZLARI matndan olib tashlanadi va
    qolgan matn umumiy belgilarga tekshiriladi. Shunda "gidravlika moyi"
    motor moyi bo'lib qolmaydi, lekin "kolodka, disk va tormoz suyuqligi"
    da ham suyuqlik, ham kolodka topiladi.
    """
    remaining = text or ""
    found: list[str] = []
    for key, rx in _COMPILED.items():
        if rx.search(remaining):
            found.append(key)
            remaining = rx.sub(" ", remaining)
    return found


# --------------------------------------------------------------- Sinflar

PASSENGER = "PASSENGER"
LIGHT_DIESEL = "LIGHT_DIESEL"
TRUCK = "TRUCK"
EQUIPMENT = "EQUIPMENT"

CLASS_NAMES = {
    PASSENGER: {"uz": "Yengil avtomobil (benzin)", "ru": "Легковой автомобиль",
                "en": "Passenger car"},
    LIGHT_DIESEL: {"uz": "Isuzu N-seriya (dizel yuk/avtobus)", "ru": "Isuzu N-серия (дизель)",
                   "en": "Isuzu N-series (diesel)"},
    TRUCK: {"uz": "Yuk mashinasi / maxsus texnika (km)", "ru": "Грузовик / спецтехника (км)",
            "en": "Truck / special vehicle (km)"},
    EQUIPMENT: {"uz": "Motosoat bilan ishlaydigan texnika", "ru": "Техника на моточасах",
                "en": "Engine-hour equipment"},
}

CLASS_COMPONENTS: dict[str, tuple[str, ...]] = {
    PASSENGER: ("ENGINE_OIL", "OIL_FILTER", "AIR_FILTER", "FUEL_FILTER", "CABIN_FILTER",
                "SPARK_PLUGS", "TIMING_BELT", "BRAKES", "BRAKE_FLUID", "COOLANT",
                "TRANSMISSION_OIL", "TIRES", "BATTERY", "SUSPENSION", "ELECTRICAL", "ENGINE"),
    LIGHT_DIESEL: ("ENGINE_OIL", "OIL_FILTER", "FUEL_FILTER", "AIR_FILTER", "COOLANT",
                   "TRANSMISSION_OIL", "DIFFERENTIAL_OIL", "BRAKES", "BRAKE_FLUID",
                   "TIRE_ROTATION", "TIRES", "BATTERY", "SUSPENSION", "ELECTRICAL", "ENGINE"),
    TRUCK: ("ENGINE_OIL", "OIL_FILTER", "FUEL_FILTER", "AIR_FILTER", "COOLANT",
            "TRANSMISSION_OIL", "DIFFERENTIAL_OIL", "BRAKES", "BRAKE_FLUID", "CLUTCH",
            "TIRES", "BATTERY", "SUSPENSION", "ELECTRICAL", "ENGINE"),
    EQUIPMENT: ("ENGINE_OIL", "OIL_FILTER", "FUEL_FILTER", "AIR_FILTER", "HYDRAULIC_OIL",
                "HYDRAULIC_FILTER", "TRANSMISSION_OIL", "DIFFERENTIAL_OIL", "COOLANT",
                "BRAKES", "TIRES", "BATTERY", "SUSPENSION", "ELECTRICAL", "ENGINE"),
}


@dataclass(frozen=True)
class Interval:
    km: float | None = None
    months: float | None = None
    hours: float | None = None
    source: str | None = None
    note: str = ""
    extra: dict = field(default_factory=dict)


#: Ishlab chiqaruvchi oraliqlari. Bu yerda YO'Q qism — oralig'i noma'lum
#: (faqat tarix). Shina va akkumulyator bazadan olinadi.
INTERVALS: dict[str, dict[str, Interval]] = {
    PASSENGER: {
        "ENGINE_OIL": Interval(km=15000, source="lacetti_oil",
                               note="Lacetti reglamenti; Damas/Matiz/Cobalt uchun korxona o'z "
                                    "oralig'ini maintenance_plan ga kiritishi mumkin"),
        "OIL_FILTER": Interval(km=15000, source="lacetti_oil"),
        "AIR_FILTER": Interval(km=45000, source="lacetti_service"),
        "BRAKE_FLUID": Interval(months=24, source="brake_fluid"),
        "COOLANT": Interval(km=240000, months=60, source="lacetti_service"),
        "SPARK_PLUGS": Interval(km=30000, source="lacetti_plugs",
                                note="Lacetti reglamenti; boshqa rusum uchun maintenance_plan"),
    },
    LIGHT_DIESEL: {
        "ENGINE_OIL": Interval(km=16000, hours=250, source="isuzu_n_pm",
                               note="og'ir sharoitda (chang, issiq) 12 000 km / 200 soat"),
        "OIL_FILTER": Interval(km=16000, hours=250, source="isuzu_n_pm"),
        "FUEL_FILTER": Interval(km=24000, source="isuzu_n_pm"),
        "AIR_FILTER": Interval(km=48000, source="isuzu_n_pm"),
        "COOLANT": Interval(km=80000, source="isuzu_n_pm"),
        "TRANSMISSION_OIL": Interval(km=80000, source="isuzu_n_pm"),
        "DIFFERENTIAL_OIL": Interval(km=80000, source="isuzu_n_pm"),
        "BRAKES": Interval(km=16000, source="isuzu_n_pm", note="ko'rik oralig'i"),
        "TIRE_ROTATION": Interval(km=24000, source="isuzu_n_pm"),
        "BRAKE_FLUID": Interval(months=24, source="brake_fluid"),
    },
    TRUCK: {
        "BRAKE_FLUID": Interval(months=24, source="brake_fluid"),
    },
    EQUIPMENT: {
        "ENGINE_OIL": Interval(hours=250, source="wheel_loader_pm",
                               note="og'ir sharoitda 125 soat; ekskavator/traktor uchun "
                                    "servis kitobchasi bilan solishtiring"),
        "OIL_FILTER": Interval(hours=250, source="wheel_loader_pm"),
        "FUEL_FILTER": Interval(hours=500, source="wheel_loader_pm"),
        "AIR_FILTER": Interval(hours=500, source="wheel_loader_pm"),
        "HYDRAULIC_OIL": Interval(hours=1000, source="wheel_loader_pm"),
        "HYDRAULIC_FILTER": Interval(hours=1000, source="wheel_loader_pm"),
        "TRANSMISSION_OIL": Interval(hours=1000, source="wheel_loader_pm"),
        "DIFFERENTIAL_OIL": Interval(hours=1000, source="wheel_loader_pm"),
        "COOLANT": Interval(hours=2000, source="wheel_loader_pm"),
    },
}

#: Rusum bo'yicha oraliq — sinf jadvalidan USTUN (bir sinfda turli ishlab
#: chiqaruvchi). Kalit — mashina nomidagi so'z. Faqat rasmiy jadvali topilgani:
#:   * KAMAZ — zavod jadvali TO-1/TO-2 ni model raqami va ekologik sinfga
#:     qarab beradi (65115 Euro-2/3: 10 000 / 30 000 km), bazada esa model
#:     yozilmagan ("KAMAZ") va qaysi qism qaysi TO da almashtirilishi yo'q —
#:     taxmin qilinmaydi (https://www.autoopt.ru/upload/to_kamaz_2018.pdf);
#:   * MAN — oraliqni bort xizmat kompyuteri yoqilg'i sarfiga qarab belgilaydi,
#:     yagona raqam yo'q.
#: GRM faqat Lacetti/Gentra da: sinf bo'yicha qo'yilsa zanjirli dvigatelga
#: (Cobalt) ham "tasma 60 000 km" deyilardi.
BRAND_INTERVALS: dict[str, dict[str, Interval]] = {
    "lacetti": {"TIMING_BELT": Interval(km=60000, source="lacetti_timing")},
    "gentra": {"TIMING_BELT": Interval(km=60000, source="lacetti_timing")},
    "howo": {
        "ENGINE_OIL": Interval(km=8000, months=6, source="howo_371_pm",
                               note="birinchisi 2 000 km; og'ir sharoitda qisqartiriladi"),
        "OIL_FILTER": Interval(km=8000, months=6, source="howo_371_pm"),
        "FUEL_FILTER": Interval(km=16000, months=12, source="howo_371_pm"),
        "AIR_FILTER": Interval(km=24000, months=18, source="howo_371_pm",
                               note="har 4 000 km da tozalanadi"),
        "COOLANT": Interval(km=32000, months=24, source="howo_371_pm"),
        "TRANSMISSION_OIL": Interval(km=60000, months=10, source="howo_371_pm"),
        "DIFFERENTIAL_OIL": Interval(km=60000, months=10, source="howo_371_pm"),
        "BRAKES": Interval(km=40000, source="howo_371_pm", note="tormoz qoplamasi (kolodka)"),
    },
}


#: Nomida ikkinchi marka ham bo'lsa jadval qo'llanmaydi: bazada "HOWO Sam" +
#: "Isuzu" yozuvi bor (85 657 OBA) — qaysi biri ekani noma'lum.
_OTHER_MAKES = re.compile(r"\b(isuzu|kamaz|man|zil|gaz|volvo|xcmg|sany)\b")


def brand_interval(brand: str | None, model: str | None, key: str) -> Interval | None:
    name = f"{brand or ''} {model or ''}".lower()
    for word, table in BRAND_INTERVALS.items():
        if re.search(rf"\b{word}\b", name) and key in table \
                and not _OTHER_MAKES.search(re.sub(rf"\b{word}\b", " ", name)):
            return table[key]
    return None


_EQUIPMENT_TYPES = {"FRONT_LOADER", "EXCAVATOR", "TRACTOR", "BULLDOZER"}
_PASSENGER_TYPES = {"PASSENGER_CAR"}


def vehicle_class(
    brand: str | None, model: str | None, transport_type: str | None, usage_mode: str | None
) -> str:
    """Mashina sinfi — marka/model va bazadagi tur/rejimdan."""
    text = f"{brand or ''} {model or ''}".lower()
    ttype = (transport_type or "").upper()
    mode = (usage_mode or "").upper()
    if ttype in _PASSENGER_TYPES or (ttype == "VAN" and ("damas" in text or "labo" in text)) \
            or ("labo" in text and ttype == "FLATBED"):
        return PASSENGER
    if ttype in _EQUIPMENT_TYPES or mode == "MOTOSOAT":
        return EQUIPMENT
    # Isuzu N-seriya: NPR/NQR/82L/75LK va shu shassidagi avtobus/minora.
    # F-seriya (FVR) va CYZ — og'ir, ular uchun bu jadval qo'llanmaydi.
    isuzu = any(x in text for x in ("isuzu", "isizu", "saznqr"))
    heavy_isuzu = any(x in text for x in ("fvr", "cyz", "howo"))
    if isuzu and not heavy_isuzu:
        return LIGHT_DIESEL
    return TRUCK
