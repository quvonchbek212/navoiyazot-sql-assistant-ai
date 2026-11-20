"""Chatda zapchast savollari — javob pasport, prognoz va park holatidan, LLM'siz.

NIMA UCHUN. Umumiy chat savolni SQL ga aylantiradi: "85058GAA mashinasining
qaysi qismini almashtirish kerak?" ga u shunchaki 6 ta shina ro'yxatini berdi
(29.10.2026 sinov) — oraliq, foiz, ma'lumot ziddiyatlari va qo'lda yozilgan
almashtirishlar unda yo'q. Bu savollar pasportga boradi; javobdagi HAR RAQAM
pasportdan, model hech narsa qo'shmaydi va o'ylab topmaydi.

QACHON ISHLAYDI (aks holda None — oddiy chat yo'li o'zgarishsiz):
  * davlat raqami + (qism nomi / zapchast so'zi / haydovchi / yurish /
    "haqida" yoki faqat raqamning o'zi) — mashina pasporti;
  * raqamsiz, prognoz so'zi + shina/akkumulyator/zapchast — talab prognozi;
  * raqamsiz, "vaqti o'tgan / almashtirish kerak" + qism — park holati.
Raqamsiz boshqa savol ("qaysi reyslar kechikyapti?") bu yerga tushmaydi.
"""

from __future__ import annotations

import re
import time
from datetime import date
from typing import Any

from parts_control import check, forecast, passport, queries, texts
from parts_control.passport import DUE_SOON, NO_INTERVAL, OK, OVERDUE, UNKNOWN
from parts_control.texts import t
from vehicle_reference import components as cat

#: "85058GAA", "85 058 GAA", "01 A 777 AA", "85818AA".
PLATE_RE = re.compile(r"(?<![\w])(\d{2}\s?(?:[A-Za-z]\s?)?\d{3}\s?[A-Za-z]{2,3})(?![\w])")
#: Raqamdan keyin kelgan o'lchov birligi davlat raqami emas: "50000 km".
_UNIT_TAILS = {"KM", "TA", "KUN", "OY", "DA", "GA", "DAN", "DONA", "SOAT", "MH"}

INFO_RE = re.compile(r"haqida|ma.?lumot|pasport|holat|информац|сведен|паспорт|состояни|"
                     r"\babout\b|\binfo|\bstatus", re.I)
PARTS_RE = re.compile(r"zapchast|ehtiyot\s+qism|\bqism|detal|запчаст|детал|\bspare|\bparts?\b|"
                      r"almashtir|замен|replace|resurs|ресурс|yeyil|износ|\bwear|"
                      r"texnik\s+xizmat|servis|сервис", re.I)
DRIVER_RE = re.compile(r"haydovchi|kim\s+hayda|водител|\bdriver", re.I)
USAGE_RE = re.compile(r"qancha\s+yur|necha\s+km|yurgan|yurdi|probeg|пробег|mileage|ishlagan|"
                      r"turgan|dam\s+ol|простаива|простой|\bidle|\byuk\b|груз|cargo", re.I)
#: "qancha shina kerak", "nechta akkumulyator kerak bo'ladi" — so'zlar orasida qism nomi.
FORECAST_RE = re.compile(r"prognoz|прогноз|forecast|kerak\s+bo|(?:nechta|qancha)\b[^.?!]{0,40}"
                         r"\bkerak|yetishma|ombor|склад|понадоб|нужн|потребност|\bneed", re.I)
#: "moyi", "moyini" — chatda egalik qo'shimchasi bilan so'raladi ("akkumulyatori va
#: moyi qanday?"). Umumiy qoida (`cat.classify`) o'zgarmaydi: ta'mir matnidagi
#: "reduktor moyi" motor moyi bo'lib qolmasin.
_OIL_FORMS = re.compile(r"\bmoy(?:i|ini|ni)\b", re.I)
DUE_RE = re.compile(r"vaqti\s+o.?tgan|muddati\s+o.?tgan|vaqti\s+kel|almashtirish\s+kerak|"
                    r"vaqti\s+yaqin|просроч|пора\s+замен|overdue|\bdue\b", re.I)
#: Almashtirish/berish so'ralyapti — xulosa kerak ("beraylikmi?", "asoslimi?").
REQUEST_RE = re.compile(r"so.?ral|berayl|berilsin|bersak|bersa\s+bo|almashtirmoqchi|"
                        r"almashtirsak|almashtirsa\s+bo|almashtiraylik|almashtiraymi|"
                        r"almashtirish\s+kerakmi|asoslimi|\bkerakmi|просят|выда[тв]|"
                        r"можно\s+ли|нужно\s+ли|заменить\s+ли|should\s+we|requested", re.I)
_QTY_RE = re.compile(r"(?<![\w])(\d{1,2})\s*(?:ta\b|dona|шт|pcs)", re.I)
WHICH_RE = re.compile(r"qaysi\s+(?:\w+\s+)?(?:qism|zapchast|detal)|какие\s+(?:\w+\s+)?детал|"
                      r"which\s+parts?", re.I)
_DAYS_RE = re.compile(r"(\d{1,3})\s*(kun|день|дн|day)", re.I)
_MONTHS_RE = re.compile(r"(\d{1,2})\s*(oy|месяц|мес|month)", re.I)

MAX_LINES = 12


def plates_in(question: str) -> list[str]:
    out = []
    for raw in PLATE_RE.findall(question or ""):
        compact = "".join(raw.split()).upper()
        tail = re.search(r"[A-Z]+$", compact)
        if tail and tail.group(0) in _UNIT_TAILS:
            continue
        out.append(compact)
    return out


def detect(question: str) -> dict[str, Any] | None:
    """Savol zapchast haqidami — bo'lsa nima so'ralgan; bo'lmasa None."""
    text = question or ""
    plates = plates_in(text)
    components = cat.classify(_OIL_FORMS.sub("moy", text))
    parts_word = bool(PARTS_RE.search(text))
    if plates and components and REQUEST_RE.search(text):
        qty = _QTY_RE.search(text)
        return {"kind": "check", "plate": plates[0], "components": components,
                "quantity": int(qty.group(1)) if qty else None}
    if plates:
        rest = re.findall(r"\w+", PLATE_RE.sub(" ", text))
        wants = {
            "components": components,
            "drivers": bool(DRIVER_RE.search(text)),
            "usage": bool(USAGE_RE.search(text)),
            # "qaysi qismini almashtirish kerak?" — faqat ogohlantirishlar.
            "due": bool(DUE_RE.search(text) or WHICH_RE.search(text)),
        }
        if components or parts_word or INFO_RE.search(text) or wants["drivers"] \
                or wants["usage"] or len(rest) <= 2:
            return {"kind": "vehicle", "plate": plates[0], **wants}
        return None
    devices = {"TIRES", "BATTERY"} & set(components)
    if FORECAST_RE.search(text) and (devices or parts_word):
        return {"kind": "forecast", "components": components, "days": _days(text)}
    if DUE_RE.search(text) and (components or parts_word):
        return {"kind": "fleet", "components": components}
    return None


def _days(text: str) -> int:
    match = _DAYS_RE.search(text)
    if match:
        return max(7, min(365, int(match.group(1))))
    match = _MONTHS_RE.search(text)
    if match:
        return max(7, min(365, int(match.group(1)) * 30))
    return 90


def _model_in(text: str, vehicles: list[dict[str, Any]]) -> str | None:
    """Savolda tilga olingan rusum ("Damaslar", "Isuzu") — park nomlaridan."""
    words = {w.lower() for w in re.findall(r"[A-Za-z]{3,}", text)}
    for vehicle in vehicles:
        for part in re.findall(r"[A-Za-z]{3,}", passport._vehicle_name(vehicle)):
            key = part.lower()
            if key in ("chevrolet",):
                continue
            if any(w == key or w.startswith(key) for w in words):
                return part
    return None


def _table(title: str, columns: list[tuple[str, str]], rows: list[dict[str, Any]]) -> dict:
    return {"title": title, "columns": [{"key": k, "label": label} for k, label in columns],
            "rows": rows, "row_count": len(rows), "total_row_count": len(rows)}


def _fmt(value: float | None) -> str:
    return f"{value:,.0f}".replace(",", " ") if value is not None else "—"


# ===================================================================== Mashina


def _standard(c: dict[str, Any], lang: str) -> str:
    """"Standart oraliq: 8 000 km yoki 6 oy, qaysi biri oldin kelsa (manba)"."""
    parts = [t(lang, f"unit.{axis}", v=_fmt(c[f"interval_{axis}"]) if axis != "months"
               else f"{c['interval_months']:g}")
             for axis in ("km", "months", "hours") if c.get(f"interval_{axis}")]
    if not parts:
        return ""
    life = t(lang, "chat.or").join(parts) + (t(lang, "chat.either") if len(parts) > 1 else "")
    return t(lang, "chat.standard", life=life, source=short_source(c.get("interval_source")))


def short_source(source: dict[str, str] | None) -> str:
    """Manba nomi — ikki nuqtagacha: "Sinotruk HOWO 371HP xizmat jadvali". To'liq
    tavsif (butun jadval) chatda javobni uch barobar uzaytirardi; u API da qoladi."""
    title = (source or {}).get("title") or "—"
    return title.split(":")[0].strip()


def _component_line(c: dict[str, Any], lang: str, context: str = "") -> str:
    """Bitta qism — savolga javob. "Noma'lum (tarix yo'q) — tarix yo'q — ..."
    takrorlanmasin va tarix yo'q bo'lsa ham standart oraliq aytilsin (85428RAA
    HOWO: "moyini qachon almashtirish kerak?" ga 8 000 km / 6 oy aytilmagandi)."""
    if c["status"] == UNKNOWN:
        return " ".join(filter(None, [f"{c['name']}: {t(lang, 'chat.unknown_part')}",
                                      _standard(c, lang), context,
                                      t(lang, "chat.record_hint")]))
    if c["status"] == NO_INTERVAL:
        return " ".join(filter(None, [f"{c['name']}: {c['detail']}.", context]))
    return " ".join(filter(None, [f"{c['name']}: {c['status_text']} — {c['detail']}.",
                                  _standard(c, lang), context]))


def vehicle_answer(intent: dict[str, Any], lang: str) -> dict[str, Any]:
    try:
        vid = passport.resolve_vehicle(intent["plate"], None)
    except passport.NotFound as exc:
        message = (t(lang, "chat.many", plates=", ".join(exc.suggestions))
                   if exc.suggestions else t(lang, "chat.not_found", plate=intent["plate"]))
        return {"answer": message, "table": None}
    d = passport.build_passport(vid, lang=lang)
    v, r = d["vehicle"], d["readings"]
    asked = list(intent.get("components") or [])
    focused = bool(asked or intent.get("drivers") or intent.get("usage"))
    due_only = bool(intent.get("due")) and not focused
    # To'liq pasport faqat umumiy savolda ("85019GAA", "... haqida ma'lumot").
    # Qisqa savolga — faqat shu savolga javob va kerakli tavsiya (30.10.2026:
    # "moyini qachon almashtirish kerak?" ga mashina turi, spidometr, uzun
    # manba matni chiqardi).
    full = not (focused or due_only)
    periods = (d.get("usage") or {}).get("periods") or []
    idle = bool(periods) and not any(p["trips"] or p["waybills"] for p in periods)
    if full:
        if r["odometer_km"] is not None:
            meter = t(lang, "chat.meter_km", v=t(lang, "unit.km", v=_fmt(r["odometer_km"])),
                      day=r["last_reading_date"])
        elif r["engine_hours"] is not None:
            meter = t(lang, "chat.meter_hours",
                      v=t(lang, "unit.hours", v=_fmt(r["engine_hours"])),
                      day=r["last_reading_date"])
        else:
            meter = t(lang, "chat.meter_none")
            if idle:
                meter += " " + t(lang, "chat.no_activity", days=max(p["days"] for p in periods))
        lines = [t(lang, "chat.header", plate=v["plate_number"] or "—", vehicle=v["vehicle"],
                   cls=v["class_name"], meter=meter)]
    elif due_only:
        lines = []  # xulosa gapining o'zi "85058GAA (Isuzu): 15 ta qism ..." deb boshlanadi
    else:
        lines = [f"{v['plate_number'] or '—'} ({v['vehicle']})"]
    by_key = {c["component"]: c for c in d["components"]}
    axes = passport.usage_axes(v.get("usage_mode"))

    for key in asked:
        c = by_key.get(key)
        if c is None:
            name = cat.COMPONENTS[key].name(lang) if key in cat.COMPONENTS else key
            lines.append(t(lang, "chat.not_tracked", name=name))
        elif c["parts"]:
            lines.append(t(lang, "chat.pieces", name=c["name"], count=len(c["parts"])))
            lines += [f"- {line}" for line in
                      passport.group_pieces(c["parts"], lang, axes, rate_note=False)]
            if any(passport.needs_rate_note(p) for p in c["parts"]):
                lines.append(t(lang, "piece.no_rate_once"))
        else:
            context = ""
            if c.get("next_due_km") and r["odometer_km"] is not None:
                context = t(lang, "chat.now_km", v=t(lang, "unit.km", v=_fmt(r["odometer_km"])))
            elif c["status"] == UNKNOWN and r["odometer_km"] is None and r["engine_hours"] is None:
                context = t(lang, "chat.no_meter_idle" if idle else "chat.no_meter")
            lines.append(_component_line(c, lang, context))

    if not focused:
        lines.append(d["summary"]["text"])
        if d["alerts"]:
            lines.append(t(lang, "chat.attention"))
            lines += [f"- {a['message']}" for a in d["alerts"]]
        else:
            lines.append(t(lang, "chat.no_alerts"))
    if full:
        known = [c for c in d["components"] if c["status"] == OK]
        if known:
            lines.append(t(lang, "chat.known"))
            lines += [f"- {c['name']}: {c['detail']}" for c in known]
        for status, key in ((UNKNOWN, "chat.unknown_list"), (NO_INTERVAL, "chat.no_interval_list")):
            names = [c["name"] for c in d["components"] if c["status"] == status]
            if names:
                lines.append(t(lang, key, names=", ".join(names)))

    if intent.get("usage") or full:
        lines.append(t(lang, "chat.usage"))
        lines += [f"- {p['text']}" for p in periods]

    if intent.get("drivers") or full:
        assigned = [a["driver_name"] + (f" ({a['phone']})" if a.get("phone") else "")
                    for a in d["drivers"]["assigned"] if a.get("driver_name")]
        lines.append(t(lang, "chat.drivers_assigned", names=", ".join(assigned)) if assigned
                     else t(lang, "chat.drivers_none"))
        changes = d["drivers"]["changes"][: 5 if intent.get("drivers") else 3]
        if changes:
            lines.append(t(lang, "chat.driver_changes"))
            lines += [f"- " + t(lang, "chat.driver_period", name=p.get("driver_name") or "—",
                                start=p.get("from"), end=p.get("to"), trips=p.get("trips"))
                      for p in changes]

    if full:
        lines += [n for n in d["notes"] if n.startswith("#")]

    rows = [{"part": c["name"], "status": c["status_text"], "detail": c["detail"]}
            for c in d["components"] if not asked or c["component"] in asked]
    table = _table(f"{v['plate_number']} — {v['vehicle']}",
                   [("part", t(lang, "chat.col.part")), ("status", t(lang, "chat.col.status")),
                    ("detail", t(lang, "chat.col.detail"))], rows)
    return {"answer": "\n".join(lines), "table": table}


# ============================================================ Almashtirish tekshiruvi


def check_answer(intent: dict[str, Any], lang: str) -> dict[str, Any]:
    """"85058GAA ga 4 ta shina so'ralyapti, beraylikmi?" — xulosa va tavsiya."""
    try:
        vid = passport.resolve_vehicle(intent["plate"], None)
    except passport.NotFound as exc:
        message = (t(lang, "chat.many", plates=", ".join(exc.suggestions))
                   if exc.suggestions else t(lang, "chat.not_found", plate=intent["plate"]))
        return {"answer": message, "table": None}
    lines, rows = [], []
    for key in intent["components"][:3]:
        result = check.evaluate(vid, key, quantity=intent.get("quantity"), lang=lang)
        lines.append(result["conclusion"])
        lines.append(t(lang, "chat.recommend"))
        lines += [f"- {r}" for r in result["recommendations"]]
        rows += [{"part": i["name"], "status": t(lang, f"check.verdict.{i['verdict']}"),
                  "detail": i["text"]} for i in result["items"]]
    table = _table(intent["plate"], [("part", t(lang, "chat.col.part")),
                                     ("status", t(lang, "chat.col.status")),
                                     ("detail", t(lang, "chat.col.detail"))], rows)
    return {"answer": "\n".join(lines), "table": table}


# ===================================================================== Prognoz


def forecast_answer(intent: dict[str, Any], question: str, lang: str) -> dict[str, Any]:
    devices = [d for d in intent.get("components") or [] if d in forecast.DEVICES]
    category = forecast.DEVICES[devices[0]] if len(devices) == 1 else None
    model = _model_in(question, queries.fetch_vehicles())
    data = forecast.build(days=intent["days"], category=category, model=model, lang=lang)
    lines = [data["summary"]["text"]]
    needed = [i for i in data["items"] if i["needed_total"] or i["due_soon_undated"]]
    lines += [f"- {i['text']}" for i in needed[:MAX_LINES]]
    if len(needed) > MAX_LINES:
        lines.append(t(lang, "chat.more", count=len(needed) - MAX_LINES))
    lines += [f"- {s['text']}" for s in data["services"][:5]]
    if data["pending_requests"]:
        items = ", ".join(f"{p['item_name']} ({p['plate_number']})"
                          for p in data["pending_requests"][:5])
        lines.append(t(lang, "chat.pending", items=items))
    rows = [{"spec": f"{t(lang, 'forecast.cat.' + i['category'])} "
                     f"{i['spec'] or t(lang, 'forecast.spec_unknown')}",
             "need": i["needed_total"], "stock": i["stock_quantity"], "short": i["shortage"]}
            for i in needed]
    table = _table(data["summary"]["text"][:80],
                   [("spec", t(lang, "chat.col.spec")), ("need", t(lang, "chat.col.need")),
                    ("stock", t(lang, "chat.col.stock")), ("short", t(lang, "chat.col.short"))],
                   rows)
    return {"answer": "\n".join(lines), "table": table}


# ===================================================================== Park


def _listed(items: list[str], limit: int = 8) -> str:
    if not items:
        return ""
    more = f", +{len(items) - limit}" if len(items) > limit else ""
    return ": " + ", ".join(items[:limit]) + more


def fleet_answer(intent: dict[str, Any], question: str, lang: str) -> dict[str, Any]:
    """"Qaysi mashinalarning akkumulyatori vaqti o'tgan?" — qism bo'yicha park holati."""
    fleet = passport.load_fleet()
    model = _model_in(question, fleet.vehicles)
    keys = [k for k in intent.get("components") or []] or None
    today = date.today()
    found: dict[str, dict[str, list[str]]] = {}
    unknown: dict[str, int] = {}
    rows = []
    for vehicle in fleet.vehicles:
        name = passport._vehicle_name(vehicle)
        if model and model.lower() not in name.lower():
            continue
        plate = vehicle.get("plate_number") or vehicle["vehicle_id"][:8]
        for state in passport.vehicle_states(vehicle, fleet, today=today)["states"]:
            key = state["key"]
            if keys and key not in keys:
                continue
            group = found.setdefault(key, {OVERDUE: [], DUE_SOON: []})
            if state["status"] in group:
                group[state["status"]].append(f"{plate} ({name})")
                comp = cat.COMPONENTS.get(key)
                rows.append({"vehicle": f"{plate} ({name})",
                             "part": comp.name(lang) if comp else key,
                             "status": t(lang, f"status.{state['status']}")})
            elif state["status"] in (UNKNOWN, NO_INTERVAL):
                unknown[key] = unknown.get(key, 0) + 1
    lines = []
    for key, group in sorted(found.items(), key=lambda kv: -len(kv[1][OVERDUE])):
        if not keys and not (group[OVERDUE] or group[DUE_SOON]):
            continue
        comp = cat.COMPONENTS.get(key)
        lines.append(t(lang, "chat.fleet", name=comp.name(lang) if comp else key,
                       overdue=len(group[OVERDUE]), over_list=_listed(group[OVERDUE]),
                       soon=len(group[DUE_SOON]), soon_list=_listed(group[DUE_SOON])))
        if keys and unknown.get(key):
            lines.append(t(lang, "chat.fleet_unknown", count=unknown[key]))
    if not lines:
        lines.append(t(lang, "chat.no_alerts"))
    table = _table(lines[0][:80], [("vehicle", t(lang, "chat.col.vehicle")),
                                   ("part", t(lang, "chat.col.part")),
                                   ("status", t(lang, "chat.col.status"))], rows)
    return {"answer": "\n".join(lines), "table": table}


# ===================================================================== Kirish


def answer(question: str, lang: str = texts.DEFAULT_LANG) -> dict[str, Any] | None:
    """Zapchast savoli bo'lsa — {answer, table, kind, seconds}; aks holda None."""
    intent = detect(question)
    if intent is None:
        return None
    started = time.perf_counter()
    lang = texts.normalize(lang)
    if intent["kind"] == "check":
        out = check_answer(intent, lang)
    elif intent["kind"] == "vehicle":
        out = vehicle_answer(intent, lang)
    elif intent["kind"] == "forecast":
        out = forecast_answer(intent, question, lang)
    else:
        out = fleet_answer(intent, question, lang)
    return {**out, "kind": intent["kind"], "seconds": round(time.perf_counter() - started, 3)}
