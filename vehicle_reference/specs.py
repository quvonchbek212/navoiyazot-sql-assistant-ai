"""Rusum ma'lumotnomasi — bazada bo'lmagan qiymatlar, MANBASI bilan.

BAZA USTUN. Bu fayldagi qiymat faqat bazada bo'sh bo'lgan joyni
to'ldiradi: `vehicle_part` da `expected_life_km` bor bo'lsa qism resursi
undan olinadi. Javobda har qiymat yonida `source` turadi — "baza" yoki
shu yerdagi manba kaliti.

NIMA BOR (28.10.2026 da internetdan yig'ilgan):
  * elektr tizimi kuchlanishi (12/24 V) — "boshqa mashinaning qismi"
    tekshiruvi (Damas uchun 28V generator);
  * akkumulyator xizmat muddati va shina kafolati — GOST.

NIMA YO'Q — ATAYLAB: SHINA PROBEGI. AE 001-04 me'yori 2007 yilda kuchini
yo'qotgan; Mintrans 13.05.2025 xati: probeg ishlab chiqaruvchi
tavsiyasidan olinadi. Korxonaning o'z siyosati `vehicle_part.expected_life_km`
da bor (Damas/Cobalt 40-60 ming, Isuzu 30-60 ming) — o'sha ishlatiladi.

YANGI RUSUM QO'SHISH: `MODELS` ga bitta yozuv va `_MATCHERS` ga bitta
qator. Boshqa hech qayerga tegilmaydi.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

#: Manba kalitlari — javobda `source` maydoniga shu kalit yoziladi.
SOURCES: dict[str, dict[str, str]] = {
    "gost_53165": {
        "title": "GOST R 53165-2020 p.7.3.3: kislotali akkumulyator kamida 24 oy, "
                 "90 000 km yoki 3000 motosoatgacha",
        "url": "https://www.zr.ru/content/articles/985683-skolko-zhivet-akkumulyator/",
    },
    "gost_4754": {
        "title": "GOST 4754-97 p.10.1: yengil avtomobil shinasi kafolati — "
                 "ishlab chiqarilgandan 5 yil",
        "url": "https://auto.ru/mag/article/kak-uznat-datu-vypuska-avtomobilnoy-shiny-vazhno-otvechaet-ekspert/",
    },
    "mintrans_tires": {
        "title": "Mintrans RF 13.05.2025 N DZ/1112-IS: shina probegi me'yori "
                 "ishlab chiqaruvchi tavsiyasidan olinadi",
        "url": "https://pravo.ppt.ru/pismo/mintrans/n-dz-1112-is-313310",
    },
    "voltage_rule": {
        "title": "Umumiy texnik qoida: yengil avtomobil elektr tizimi 12 V, "
                 "og'ir dizel yuk mashinasi 24 V (28V generator — 24 V tizim)",
        "url": "",
    },
}


@dataclass(frozen=True)
class ModelSpec:
    key: str
    title: str
    voltage: int | None = None
    sources: tuple[str, ...] = ()


MODELS: dict[str, ModelSpec] = {
    "damas": ModelSpec("damas", "Chevrolet Damas", voltage=12, sources=("voltage_rule",)),
    "labo": ModelSpec("labo", "Chevrolet Labo", voltage=12, sources=("voltage_rule",)),
    "cobalt": ModelSpec("cobalt", "Chevrolet Cobalt", voltage=12, sources=("voltage_rule",)),
    "lacetti": ModelSpec("lacetti", "Chevrolet Lacetti / Gentra", voltage=12,
                         sources=("voltage_rule",)),
    "isuzu_fvr34": ModelSpec("isuzu_fvr34", "Isuzu FVR34", voltage=24, sources=("voltage_rule",)),
    "kamaz": ModelSpec("kamaz", "KAMAZ", voltage=24, sources=("voltage_rule",)),
    "man": ModelSpec("man", "MAN", voltage=24, sources=("voltage_rule",)),
    "howo": ModelSpec("howo", "HOWO", voltage=24, sources=("voltage_rule",)),
    "volvo": ModelSpec("volvo", "Volvo FH", voltage=24, sources=("voltage_rule",)),
}

#: Bazadagi marka/model yozuvlari tartibsiz ("Isuzu 82l", "HOWO Sam" +
#: "Isuzu", "Malibu 2" + "Chevrolet"). Shuning uchun moslash noaniq
#: (fuzzy) EMAS, aniq bo'lak bo'yicha.
_MATCHERS: tuple[tuple[str, str], ...] = (
    ("damas", "damas"),
    ("labo", "labo"),
    ("cobalt", "cobalt"),
    ("lacetti", "lacetti"),
    ("gentra", "lacetti"),
    ("fvr34", "isuzu_fvr34"),
    ("kamaz", "kamaz"),
    ("howo", "howo"),
    ("volvo", "volvo"),
)

#: Butun so'z bo'lib kelishi kerak bo'lgan markalar ("MAN" — "Manipulator"
#: ichida ham bor).
_WORD_MATCHERS: tuple[tuple[str, str], ...] = (("man", "man"),)


def _compact(text: str) -> str:
    return re.sub(r"[\s\-_]+", "", (text or "").lower())


def lookup(brand: str | None, model: str | None) -> ModelSpec | None:
    """Bazadagi marka va modelni ma'lumotnoma yozuviga moslaydi."""
    joined = _compact(f"{brand or ''} {model or ''}")
    for token, key in _MATCHERS:
        if token in joined:
            return MODELS[key]
    words = set(re.findall(r"[a-z0-9]+", f"{brand or ''} {model or ''}".lower()))
    for token, key in _WORD_MATCHERS:
        if token in words:
            return MODELS[key]
    return None


def voltage_for(
    brand: str | None, model: str | None, transport_type: str | None
) -> tuple[int | None, str | None]:
    """Elektr tizimi kuchlanishi va manbasi.

    Rusum ma'lumotnomada bo'lmasa ham YENGIL AVTOMOBIL 12 V — bu
    umumiy qoida, taxmin emas. Yuk mashinasi uchun bunday umumiy qoida
    YO'Q (Isuzu N-seriyasi 12 V ham, 24 V ham bo'ladi), shuning uchun
    ular faqat ma'lumotnomadan.
    """
    spec = lookup(brand, model)
    if spec and spec.voltage:
        return spec.voltage, "voltage_rule"
    if (transport_type or "").upper() == "PASSENGER_CAR":
        return 12, "voltage_rule"
    return None, None


# ------------------------------------------------------------ Qism resursi

#: Akkumulyator: GOST R 53165-2020 — eng KAM xizmat muddati. Bundan oldin
#: almashtirilgan akkumulyator "resursidan oldin" hisoblanadi: yo
#: kafolat bo'yicha yetkazib beruvchiga qaytarilishi kerak edi, yo
#: almashtirishning o'zi shubhali.
BATTERY_LIFE = {
    "life_months": 24,
    "life_km": 90000,
    "life_engine_hours": 3000,
    "source": "gost_53165",
}

#: Yengil avtomobil shinasi: kafolat ishlab chiqarilgan sanadan 5 yil.
#: Ishlab chiqarilgan sana bazada yo'q, shuning uchun o'rnatilgan sana
#: bilan solishtiriladi — bu kafolatni KATTA ko'rsatadi, javobda ochiq
#: yoziladi.
PASSENGER_TIRE_WARRANTY_MONTHS = (60, "gost_4754")


def source_info(key: str | None) -> dict[str, str] | None:
    """Manba kaliti bo'yicha sarlavha va havola."""
    if not key:
        return None
    if key == "db":
        return {"title": "ATIL bazasi", "url": ""}
    return SOURCES.get(key)
