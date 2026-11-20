"""Ehtiyot qismlar — sof hisob (bazasiz, LLM'siz).

O'ZLASHTIRISHNING UCH YO'LI va ularning izi:

  1. BOSHQA MASHINA UCHUN OLINADI. Damas ta'miriga "KAMAZ tormoz
     kolodkasi" va "28V generator" yoziladi, BYD ga "190Ah og'ir
     texnika akkumulyatori" — bazada aynan shunday so'rovlar bor
     (28.10.2026). Qism nomi o'zi aytadi: qaysi marka uchun, necha
     voltli, necha amper-soat, qaysi disk o'lchami. Shular mashinaning
     o'ziga solishtiriladi.
  2. ERTA ALMASHTIRILADI. 60 ming km yurishi kerak shina 20 ming da
     "yeyildi" deb yangisi olinadi. Resurs km, OY va motosoat bilan
     o'lchanadi — qaysi biri birinchi tugasa o'sha hal qiladi.
  3. BERILADI, LEKIN HISOBDAN O'TMAYDI. Ombordan berilgan qism na
     ishlatilgan, na qaytarilgan.

HUKM SOLISHTIRISHDAN CHIQADI, CHEGARADAN EMAS: sig'im shu mashinada
o'rnatilgan akkumulyatorlar to'plamiga kiradimi; disk o'lchami
mashinadagi shinalarniki bilan bir xilmi; ishlatilgan km resursdan
kammi. Ma'lumot yo'q joyda hukm yo'q — "tekshirilmadi".
"""

from __future__ import annotations

import re
from collections import Counter
from datetime import date, datetime
from decimal import Decimal
from typing import Any, Iterable, Sequence

from parts_control import config, texts
from parts_control.texts import t
from vehicle_reference import specs

EPS = 1e-6

#: Belgi turi — daraja emas, tasnif.
#:   MISMATCH     qism mashinaga to'g'ri kelmaydi (eng kuchli o'zlashtirish izi)
#:   EARLY        resursidan oldin almashtirilgan yoki yeyilgan
#:   CONTROL      berilgan, lekin hisobdan o'tmagan
#:   MAINTENANCE  resursi tugagan, hali ishlatilyapti (xavfsizlik)
#:   DATA         ma'lumot xatosi
KIND_OF = {
    "PART_FOR_OTHER_MODEL": "MISMATCH",
    "VOLTAGE_MISMATCH": "MISMATCH",
    "BATTERY_SPEC_MISMATCH": "MISMATCH",
    "TIRE_SIZE_MISMATCH": "MISMATCH",
    "QTY_EXCEEDS_FITMENT": "MISMATCH",
    "EARLY_REPLACEMENT": "EARLY",
    "WORN_EARLY": "EARLY",
    "ISSUED_NOT_USED": "CONTROL",
    "OVER_LIFE": "MAINTENANCE",
    "LIFE_VALUE_SUSPECT": "DATA",
}


def num(value: Any) -> float | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, Decimal):
        return float(value)
    try:
        return float(str(value).replace(",", "."))
    except (TypeError, ValueError):
        return None


def fmt(value: float | None) -> str:
    if value is None:
        return "—"
    rounded = round(value, 1)
    return str(int(rounded)) if rounded == int(rounded) else f"{rounded:.1f}"


def make_flag(code: str, lang: str, *, data: dict[str, Any] | None = None,
              **params: Any) -> dict[str, Any]:
    """`data` — tilga bog'liq bo'lmagan raqamlar (agent xabarni uch tilda shundan
    yozadi; `detail` esa bitta tilda tayyor matn)."""
    text_params = {k: (fmt(v) if v is None or isinstance(v, float) else v)
                   for k, v in params.items()}
    flag = {
        "code": code,
        "kind": KIND_OF[code],
        "title": t(lang, f"flag.{code}"),
        "detail": t(lang, f"detail.{code}", **text_params),
    }
    if data:
        flag["data"] = data
    return flag


# ------------------------------------------------------------ Nomni o'qish

_TIRE_RE = re.compile(r"(шин|shina|balon|баллон|tire|tyre|покрышк|автошин|avtoshina)", re.I)
_BATTERY_RE = re.compile(r"(аккумул|akkumul|\bакб\b|\bakb\b|battery|батаре)", re.I)


def category_of(name: str | None) -> str:
    text = name or ""
    if _BATTERY_RE.search(text):
        return "BATTERY"
    if _TIRE_RE.search(text):
        return "TIRE"
    return "OTHER"


_AH_PATTERNS = (
    re.compile(r"(\d{2,3})\s*(?:a\s*h|ah|а\s*ч|ач)(?![a-zа-я])", re.I),
    # "6СТ-190", "6 ст-40", "6-ст 75" — oxirgi son amper-soat.
    re.compile(r"6\s*-?\s*[сc][тt]\s*-?\s*(\d{2,3})(?!\d)", re.I),
)


def battery_ah(name: str | None) -> int | None:
    for pattern in _AH_PATTERNS:
        match = pattern.search(name or "")
        if match:
            return int(match.group(1))
    return None


_VOLT_RE = re.compile(r"(?<!\d)(12|14|24|28)\s*(?:v|в)(?![a-zа-я])", re.I)


def voltage_system(name: str | None) -> int | None:
    """Qism qaysi tizim uchun: 12/14 V -> 12, 24/28 V -> 24 (generator
    zaryadlash kuchlanishi tizimnikidan yuqori yoziladi)."""
    match = _VOLT_RE.search(name or "")
    if not match:
        return None
    return 12 if match.group(1) in ("12", "14") else 24


_RIM_PATTERNS = (
    re.compile(r"(?<![a-z])R\s?(\d{2}(?:[.,]5)?)(?!\d)", re.I),      # 215/75R17.5, 155 R 12
    re.compile(r"\d{3}/\d{2}\s+(\d{2})(?![\d.,])"),                    # 195/65 15
    re.compile(r"\d{2,3}(?:[.,]\d{1,2})?\s*/\s*\d{2}\s*-\s*(\d{2})(?!\d)"),  # 260/95-16
)
_MM_RIM_RE = re.compile(r"\d{3}\s*[xх×]\s*(\d{3})(?!\d)", re.I)       # 260x508 (mm)


def tire_rim(*names: str | None) -> str | None:
    """Disk o'lchami (dyuym) — "R17.5", "R12". Bir nechta matndan birinchisi."""
    for name in names:
        text = name or ""
        for pattern in _RIM_PATTERNS:
            match = pattern.search(text)
            if match:
                return fmt(float(match.group(1).replace(",", ".")))
        match = _MM_RIM_RE.search(text)
        if match:
            return fmt(round(int(match.group(1)) / 25.4 * 2) / 2)
    return None


_SIZE_RE = re.compile(
    r"(?<![\d.])(\d{1,3}(?:\.\d{0,2})?)\s*(?:/\s*(\d{2}(?:\.\d{1,2})?))?"
    r"\s*(-\s*R|R|-|\s)\s*(\d{2}(?:\.5)?)(?![\d.])", re.I)


def _num_text(value: str) -> str:
    """"12.00" → "12", "7.50" → "7.5", "8.25" o'zicha (yaxlitlanmaydi)."""
    value = value.rstrip(".")
    return value.rstrip("0").rstrip(".") if "." in value else value


def tire_size_key(*names: str | None) -> str | None:
    """Shina o'lchami bitta shaklda — ombor qoldig'i bilan solishtirish uchun.

    Bazada bir o'lcham turlicha yozilgan: "12.00R20" (qism), "Шины 12,00 -R20",
    "12,00 R20(с камерой...)" (ombor) — hammasi "12R20"; "7.50 R 16 LT" va
    "7.5R16" — "7.5R16"; diagonal "23.5-25" o'zicha. Topilmasa — None
    ("Avtoshina", faqat "R15" — o'lcham to'liq yozilmagan)."""
    for name in names:
        text = (name or "").upper().replace(",", ".")
        match = _SIZE_RE.search(text)
        if not match:
            continue
        width, aspect, sep, rim = match.groups()
        # "195/65 15" — radial; "260/95-16" (qishloq xo'jaligi) — diagonal.
        radial = "R" in sep or (not sep.strip() and aspect is not None)
        head = _num_text(width) + (f"/{_num_text(aspect)}" if aspect else "")
        return f"{head}{'R' if radial else '-'}{_num_text(rim)}"
    return None


#: Qism nomida tilga olingan marka -> (nomdagi belgi, mashina nomidagi so'z).
_BRANDS: dict[str, tuple[re.Pattern[str], tuple[str, ...]]] = {
    "KAMAZ": (re.compile(r"камаз|kamaz", re.I), ("kamaz",)),
    "MAN": (re.compile(r"(?<![A-Za-zА-Яа-я])MAN(?![A-Za-zА-Яа-я])"), ("man",)),
    "ISUZU": (re.compile(r"isuzu|исуз|исудз", re.I), ("isuzu", "isizu")),
    "DAMAS": (re.compile(r"damas|дамас", re.I), ("damas",)),
    "LABO": (re.compile(r"labo|лабо", re.I), ("labo",)),
    "COBALT": (re.compile(r"cobalt|кобальт", re.I), ("cobalt",)),
    "LACETTI": (re.compile(r"lacetti|лачетти|gentra|джентра", re.I), ("lacetti", "gentra")),
    "NEXIA": (re.compile(r"nexia|нексия|нексиа", re.I), ("nexia",)),
    "ZIL": (re.compile(r"(?<![A-Za-zА-Яа-я])(зил|zil)(?![A-Za-zА-Яа-я])", re.I), ("zil",)),
    # "газ" — yoqilg'i ham; marka faqat "ГАЗ-53" ko'rinishida.
    "GAZ": (re.compile(r"(?<![A-Za-zА-Яа-я])(газ|gaz)-\d", re.I), ("gaz",)),
    "MTZ": (re.compile(r"мтз|mtz|беларус|belarus", re.I), ("mtz", "belarus")),
    "HOWO": (re.compile(r"howo|хово", re.I), ("howo",)),
    "XCMG": (re.compile(r"xcmg", re.I), ("xcmg",)),
    "SANY": (re.compile(r"(?<![A-Za-z])sany(?![A-Za-z])", re.I), ("sany",)),
    "BYD": (re.compile(r"(?<![A-Za-z])byd(?![A-Za-z])", re.I), ("byd",)),
    "UAZ": (re.compile(r"уаз|uaz", re.I), ("uaz",)),
}

#: Bir xil platforma va agregatga ega rusumlar (o'zaro mos qismlar yolg'on PART_FOR_OTHER_MODEL bermaydi).
_COMPATIBLE_PLATFORMS: dict[str, tuple[str, ...]] = {
    "DAMAS": ("damas", "labo"),
    "LABO": ("labo", "damas"),
    "LACETTI": ("lacetti", "gentra"),
}


def mentioned_brands(name: str | None) -> list[str]:
    return [key for key, (pattern, _) in _BRANDS.items() if pattern.search(name or "")]


def vehicle_matches_brand(brand_key: str, brand: str | None, model: str | None) -> bool:
    text = f"{brand or ''} {model or ''}".lower()
    words = set(re.findall(r"[a-z0-9]+", text))
    compact = re.sub(r"[\s\-_]+", "", text)
    allowed = list(_BRANDS[brand_key][1])
    if brand_key in _COMPATIBLE_PLATFORMS:
        allowed.extend(_COMPATIBLE_PLATFORMS[brand_key])
    for token in allowed:
        if token in words or (len(token) > 3 and token in compact):
            return True
    return False


# --------------------------------------------------------------- Resurs


def is_entry_date(part: dict[str, Any]) -> bool:
    """O'rnatilgan sana bazaga kiritilgan kun bilan bir xilmi.

    28.10.2026: 769 qismdan 187 tasida shunday — ko'pchiligi 2026-10-13
    da bir yo'la kiritilgan. Bu sana haqiqiy o'rnatish emas, shuning
    uchun OY bo'yicha resurs ular uchun hisoblanmaydi (km hisoblanadi).
    """
    installed, created = part.get("installed_at"), part.get("created_at")
    if installed is None or created is None:
        return False
    created_day = created.date() if isinstance(created, datetime) else created
    return installed == created_day


def months_between(start: date | None, end: date | None) -> float | None:
    if start is None or end is None or end < start:
        return None
    return (end - start).days / 30.4375


def life_of(part: dict[str, Any], transport_type: str | None) -> dict[str, Any]:
    """Qismning resursi: km, oy, motosoat va kafolat — har biri manbasi bilan.

    Baza USTUN (`expected_life_*` — korxonaning o'z siyosati). Bazada yo'q
    bo'lsa akkumulyator uchun GOST R 53165-2020. Shina probegi uchun
    tashqi me'yor YO'Q (Mintrans 2025 xati) — bazada bo'lmasa noma'lum.
    """
    category = (part.get("category") or "").upper()
    battery = category == "BATTERY"
    out: dict[str, Any] = {}
    for key, column, ref_key in (("km", "expected_life_km", "life_km"),
                                 ("months", "expected_life_months", "life_months"),
                                 ("hours", "expected_life_engine_hours", "life_engine_hours")):
        value = num(part.get(column))
        if value and value > 0:
            out[key] = (value, "db")
        elif battery:
            out[key] = (float(specs.BATTERY_LIFE[ref_key]), specs.BATTERY_LIFE["source"])
        else:
            out[key] = (None, None)
    if battery:
        out["warranty_months"] = (float(specs.BATTERY_LIFE["life_months"]),
                                  specs.BATTERY_LIFE["source"])
    elif category == "TIRE" and (transport_type or "").upper() == "PASSENGER_CAR":
        months, source = specs.PASSENGER_TIRE_WARRANTY_MONTHS
        out["warranty_months"] = (float(months), source)
    else:
        out["warranty_months"] = (None, None)
    return out


def usage_ratio(
    usage: dict[str, float | None], life: dict[str, Any], lang: str
) -> dict[str, Any] | None:
    """Ishlatilgan ulush — qaysi o'lchov BIRINCHI tugasa (eng katta ulush)."""
    best: dict[str, Any] | None = None
    for key in ("km", "months", "hours"):
        used = usage.get(key)
        limit = life.get(key, (None, None))[0]
        if used is None or not limit:
            continue
        pct = used / limit * 100
        if best is None or pct > best["pct"]:
            best = {
                "pct": round(pct, 1),
                "by": key,
                "used": t(lang, f"unit.{key}", v=fmt(used)),
                "life": t(lang, f"unit.{key}", v=fmt(limit)),
                "life_source": life[key][1],
                "used_value": used, "life_value": limit,
            }
    return best


def warranty_text(months_used: float | None, life: dict[str, Any], lang: str) -> str:
    months = life.get("warranty_months", (None, None))[0]
    if months_used is None or months is None or months_used >= months:
        return ""
    return t(lang, "warranty.inside", months=fmt(months))


def part_usage(part: dict[str, Any], today: date) -> dict[str, float | None]:
    start_km, now_km = num(part.get("installed_at_km")), num(part.get("current_odometer_km"))
    start_h, now_h = num(part.get("installed_at_engine_hours")), num(part.get("current_engine_hours"))
    return {
        "km": now_km - start_km if start_km is not None and now_km is not None
        and now_km >= start_km else None,
        "months": None if is_entry_date(part) else months_between(part.get("installed_at"), today),
        "hours": now_h - start_h if start_h is not None and now_h is not None
        and now_h >= start_h else None,
    }


def evaluate_part(
    part: dict[str, Any], *, today: date, lang: str, life_values: set[float],
) -> dict[str, Any]:
    """O'rnatilgan qismning holati: qancha ishlatilgan, qancha qolgan."""
    life = life_of(part, part.get("transport_type"))
    usage = part_usage(part, today)
    ratio = usage_ratio(usage, life, lang)
    flags: list[dict[str, Any]] = []
    status = (part.get("status") or "").upper()

    if ratio is not None and status == "WORN" and ratio["pct"] < 100:
        flags.append(make_flag("WORN_EARLY", lang, used=ratio["used"], life=ratio["life"],
                               pct=fmt(ratio["pct"]),
                               warranty=warranty_text(usage["months"], life, lang)))
    # "Resursi tugagan" — faqat KORXONA belgilagan resursdan. GOST R 53165
    # akkumulyatorning ENG KAM xizmat muddatini beradi: undan oshib
    # ishlash normal, almashtirish talabi emas.
    policy = {k: (v if v[1] == "db" else (None, None)) for k, v in life.items()}
    policy_ratio = usage_ratio(usage, policy, lang)
    if policy_ratio is not None and status != "WORN" and policy_ratio["pct"] >= 100:
        flags.append(make_flag("OVER_LIFE", lang, used=policy_ratio["used"],
                               life=policy_ratio["life"], pct=fmt(policy_ratio["pct"])))

    value = num(part.get("expected_life_km"))
    if value and value * 10 in life_values:
        flags.append(make_flag("LIFE_VALUE_SUSPECT", lang, value=fmt(value), ten=fmt(value * 10)))

    life_km = life["km"][0]
    life_months = life["months"][0]
    return {
        "usage": usage,
        "life": life,
        "ratio": ratio,
        "remaining_km": round(life_km - usage["km"], 1)
        if life_km is not None and usage["km"] is not None else None,
        "remaining_months": round(life_months - usage["months"], 1)
        if life_months is not None and usage["months"] is not None else None,
        "flags": flags,
    }


# ------------------------------------------------------- So'ralgan qism


def odometer_at(days: Sequence[tuple[date, float]], on: date | None) -> float | None:
    """Sanagacha bo'lgan oxirgi spidometr (kunlar saralangan)."""
    if on is None:
        return None
    value = None
    for day, km in days:
        if day > on:
            break
        value = km
    return value


def check_request(
    request: dict[str, Any],
    *,
    vehicle_parts: Sequence[dict[str, Any]],
    peer_parts: Sequence[dict[str, Any]],
    previous: Sequence[dict[str, Any]],
    odometer_days: Sequence[tuple[date, float]],
    lang: str,
    type_parts: Sequence[dict[str, Any]] = (),
) -> list[dict[str, Any]]:
    """Bitta qism so'rovining belgilari.

    `peer_parts` — shu rusumdagi mashinalarning qismlari, `type_parts` —
    shu turdagi (yengil avtomobil, samosval...) mashinalarniki.
    `previous` — shu mashinaga shu turdagi qismning OLDINGI so'rovlari.
    """
    flags: list[dict[str, Any]] = []
    name = request.get("item_name") or ""
    category = category_of(name)
    brand, model = request.get("brand"), request.get("model")
    vehicle_label = " ".join(x for x in (brand, model) if x) or "—"

    # 1. Boshqa marka uchun --------------------------------------------
    mentioned = mentioned_brands(name)
    if mentioned and (brand or model) and not any(
            vehicle_matches_brand(k, brand, model) for k in mentioned):
        flags.append(make_flag("PART_FOR_OTHER_MODEL", lang, item=name[:80],
                               mentioned=", ".join(mentioned), vehicle=vehicle_label))

    # 2. Kuchlanish ----------------------------------------------------
    part_v = voltage_system(name)
    vehicle_v, _ = specs.voltage_for(brand, model, request.get("transport_type"))
    if part_v and vehicle_v and part_v != vehicle_v:
        flags.append(make_flag("VOLTAGE_MISMATCH", lang, item=name[:80], part_v=str(part_v),
                               vehicle=vehicle_label, vehicle_v=str(vehicle_v)))

    issued = num(request.get("issued_quantity")) or 0.0
    requested = num(request.get("requested_quantity")) or 0.0

    # 3. Akkumulyator sig'imi -------------------------------------------
    if category == "BATTERY":
        ah = battery_ah(name)
        # Solishtirish to'plami: avval shu mashina, keyin shu rusum, keyin
        # shu tur. BYD da akkumulyator yozuvi yo'q, lekin yengil
        # avtomobillarda 40-75 Ah — 190 Ah ular orasida yo'q.
        basis, pool = "basis.own", set()
        for basis, parts in (("basis.own", vehicle_parts), ("basis.peers", peer_parts),
                             ("basis.type", type_parts)):
            pool = {battery_ah(p.get("name")) for p in parts if p.get("category") == "BATTERY"}
            pool.discard(None)
            if pool:
                break
        if ah and pool and not (min(pool) <= ah <= max(pool)):
            flags.append(make_flag("BATTERY_SPEC_MISMATCH", lang, ah=str(ah),
                                   basis=t(lang, basis),
                                   installed=", ".join(str(x) for x in sorted(pool))))

    # 4. Shina o'lchami va soni -----------------------------------------
    if category == "TIRE":
        tires = [p for p in vehicle_parts if p.get("category") == "TIRE"]
        rim = tire_rim(name)
        rims = {tire_rim(p.get("tire_size"), p.get("name")) for p in tires}
        rims.discard(None)
        if rim and rims and rim not in rims:
            flags.append(make_flag("TIRE_SIZE_MISMATCH", lang, item=name[:80], rim=rim,
                                   installed=", R".join(sorted(rims))))
        quantity = issued or requested
        if tires and quantity > len(tires):
            flags.append(make_flag("QTY_EXCEEDS_FITMENT", lang, qty=fmt(quantity),
                                   fitted=str(len(tires))))

    # 5. Hisobsiz qism -------------------------------------------------
    status = (request.get("status") or "").upper()
    used = num(request.get("used_quantity")) or 0.0
    returned = num(request.get("returned_quantity")) or 0.0
    if status in config.CLOSED_REQUEST_STATUSES and issued - used - returned > EPS:
        flags.append(make_flag("ISSUED_NOT_USED", lang, issued=fmt(issued), used=fmt(used),
                               returned=fmt(returned), missing=fmt(issued - used - returned),
                               unit=request.get("unit_of_measure") or "", status=status))

    # 6. Erta almashtirish ----------------------------------------------
    if category in ("BATTERY", "TIRE"):
        early = _early_replacement(request, category, vehicle_parts, previous,
                                   odometer_days, lang)
        if early:
            flags.append(early)
    return flags


def _early_replacement(
    request: dict[str, Any],
    category: str,
    vehicle_parts: Sequence[dict[str, Any]],
    previous: Sequence[dict[str, Any]],
    odometer_days: Sequence[tuple[date, float]],
    lang: str,
) -> dict[str, Any] | None:
    """Yangi qism so'ralgan paytda eskisi resursining qanchasini yurgan edi.

    Eski qism ikki manbadan: shu mashinada o'rnatilgan qism (so'rovdan
    OLDIN o'rnatilgan) yoki shu turdagi oldingi so'rov. Bir nechta shina
    bo'lsa ENG KO'P yurgani olinadi: bittasi ham resursiga yetgan bo'lsa
    almashtirish asosli.
    """
    day = request.get("requested_day")
    if day is None:
        return None
    odo_now = odometer_at(odometer_days, day)
    candidates: list[tuple[dict[str, Any], dict[str, Any]]] = []

    for part in vehicle_parts:
        if part.get("category") != category or part.get("installed_at") is None:
            continue
        if part["installed_at"] >= day or (part.get("status") or "").upper() == "WORN":
            continue
        start_km = num(part.get("installed_at_km"))
        usage = {
            "km": odo_now - start_km if odo_now is not None and start_km is not None
            and odo_now >= start_km else None,
            "months": None if is_entry_date(part) else months_between(part["installed_at"], day),
            "hours": None,
        }
        candidates.append((usage, life_of(part, request.get("transport_type"))))

    for prior in previous:
        prior_day = prior.get("requested_day")
        if prior_day is None or prior_day >= day:
            continue
        odo_then = odometer_at(odometer_days, prior_day)
        usage = {
            "km": odo_now - odo_then if odo_now is not None and odo_then is not None
            and odo_now >= odo_then else None,
            "months": months_between(prior_day, day),
            "hours": None,
        }
        reference = next((p for p in vehicle_parts if p.get("category") == category), None)
        candidates.append((usage, life_of(reference or {"category": category},
                                          request.get("transport_type"))))

    best = None
    for usage, life in candidates:
        ratio = usage_ratio(usage, life, lang)
        if ratio is None:
            continue
        if best is None or ratio["pct"] > best[0]["pct"]:
            best = (ratio, usage, life)
    if best is None or best[0]["pct"] >= 100:
        return None
    ratio, usage, life = best
    return make_flag("EARLY_REPLACEMENT", lang, used=ratio["used"], life=ratio["life"],
                     pct=fmt(ratio["pct"]), warranty=warranty_text(usage["months"], life, lang),
                     data={"pct": ratio["pct"], "by": ratio["by"], "used": ratio["used_value"],
                           "life": ratio["life_value"],
                           "left": ratio["life_value"] - ratio["used_value"]})


# ---------------------------------------------------- Rusum bo'yicha resurs


def _mode(values: Iterable[float | None]) -> float | None:
    counter = Counter(v for v in values if v)
    return counter.most_common(1)[0][0] if counter else None


def model_norms(
    parts: Sequence[dict[str, Any]], *, today: date, lang: str
) -> list[dict[str, Any]]:
    """Har rusum va qism turi bo'yicha: necha km yurishi kerak, amalda qancha yurdi.

    "Cobalt shinasi 40 000 km, Isuzu 60 000 km" — korxona siyosati
    (`expected_life_km`) va o'sha rusumdagi YEYILGAN qismlarning haqiqatda
    yurgan masofasi yonma-yon.
    """
    groups: dict[tuple[str, str], list[dict[str, Any]]] = {}
    for part in parts:
        key = model_key(part.get("brand"), part.get("model"))
        groups.setdefault((key, (part.get("category") or "").upper()), []).append(part)

    life_values = life_values_by_category(parts)
    rows = []
    for (_, category), items in sorted(groups.items()):
        # Guruhda bir nechta yozuv bo'lsa ("KAMAZ"/"Kamaz") — ko'pchiligi.
        name = Counter(vehicle_name(p.get("brand"), p.get("model")) for p in items).most_common(1)[0][0]
        evaluated = [evaluate_part(p, today=today, lang=lang,
                                   life_values=life_values.get(category, set())) for p in items]
        worn = [(p, e) for p, e in zip(items, evaluated) if (p.get("status") or "").upper() == "WORN"]
        worn_km = [e["usage"]["km"] for _, e in worn if e["usage"]["km"] is not None]
        life = life_of(items[0], items[0].get("transport_type"))
        db_km = _mode(num(p.get("expected_life_km")) for p in items)
        db_months = _mode(num(p.get("expected_life_months")) for p in items)
        pcts = [e["ratio"]["pct"] for e in evaluated if e["ratio"]]
        rows.append({
            "vehicle": name,
            "transport_type": items[0].get("transport_type"),
            "category": category,
            "parts": len(items),
            "vehicles": len({p.get("vehicle_id") for p in items}),
            "life_km": db_km if db_km else life["km"][0],
            "life_km_source": "db" if db_km else life["km"][1],
            "life_months": db_months if db_months else life["months"][0],
            "life_months_source": "db" if db_months else life["months"][1],
            "warranty_months": life["warranty_months"][0],
            "warranty_source": life["warranty_months"][1],
            "worn": len(worn),
            "worn_avg_km": round(sum(worn_km) / len(worn_km)) if worn_km else None,
            "worn_early": sum(1 for e in evaluated if any(f["code"] == "WORN_EARLY" for f in e["flags"])),
            "over_life": sum(1 for e in evaluated if any(f["code"] == "OVER_LIFE" for f in e["flags"])),
            "avg_used_pct": round(sum(pcts) / len(pcts), 1) if pcts else None,
            "battery_ah": sorted({x for x in (battery_ah(p.get("name")) for p in items) if x}),
            "tire_rims": sorted({x for x in (tire_rim(p.get("tire_size"), p.get("name"))
                                             for p in items) if x}),
        })
    return rows


def life_values_by_category(parts: Iterable[dict[str, Any]]) -> dict[str, set[float]]:
    out: dict[str, set[float]] = {}
    for part in parts:
        value = num(part.get("expected_life_km"))
        if value:
            out.setdefault((part.get("category") or "").upper(), set()).add(value)
    return out


def vehicle_name(brand: str | None, model: str | None) -> str:
    brand, model = (brand or "").strip(), (model or "").strip()
    if brand and model.lower().startswith(brand.lower()):
        return model
    if model and brand.lower().startswith(model.lower()):
        return brand
    return f"{brand} {model}".strip() or "—"


def model_key(brand: str | None, model: str | None) -> str:
    """Rusum bo'yicha guruhlash kaliti. Bazada bitta rusum turlicha yozilgan
    ("KAMAZ" 4 ta, "Kamaz" 1 ta — 28.10.2026): harf katta-kichikligi, bo'shliq
    va chiziqcha farq qilmaydi. Ko'rsatishda bazadagi yozuv qoladi."""
    return " ".join(p for p in re.split(r"[\s\-_]+", vehicle_name(brand, model).casefold()) if p)
