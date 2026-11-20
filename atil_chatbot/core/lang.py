"""Savol tilini aniqlash — javob va ustun sarlavhalari shu tilda bo'lishi uchun.

Nima uchun kodda, modelga tashlab qo'ymasdan: model ba'zan aralash javob
beradi (o'zbekcha savolga inglizcha sarlavhalar yoki aksincha). Til aniq
belgilanib promptga yozilsa, natija barqaror bo'ladi.

Uch til qo'llab-quvvatlanadi: o'zbek (uz), rus (ru), ingliz (en).
"""

from __future__ import annotations

import re

#: Kirill alifbosi — rus tilining eng ishonchli belgisi
_CYRILLIC_RE = re.compile(r"[Ѐ-ӿ]")
_LETTER_RE = re.compile(r"[^\W\d_]", re.UNICODE)

#: O'zbekchaga xos so'zlar (lotin yozuvida ingliz tilidan ajratish uchun)
_UZ_MARKERS = frozenset("""
nechta necha qancha qaysi qanday qayerda qachon kim nima nima uchun
bor yo'q yoq bormi kerak mavjud ro'yxat royxat jami barcha hamma
ber bering ayt aytib ko'rsat korsat chiqar top toping tekshir
va yoki ham bilan uchun bo'yicha boyicha haqida ichida
mashina mashinalar transport haydovchi haydovchilar reys reyslar
marshrut hujjat hujjatlar so'rov sorov ariza arizalar yuk
yoqilg'i yoqilgi sug'urta sugurta jarima hodisa smena ombor
bugun kecha ertaga hozir ayni paytda oxirgi eng
soni sonini holati turi nomi raqami muddati sanasi
""".split())

#: Inglizcha savolga xos so'zlar
_EN_MARKERS = frozenset("""
how many much what which where when who why show list give tell
find check count total all any the of in on for with and or
is are was were do does did can could vehicle vehicles driver drivers
trip trips route document documents request requests fuel insurance
today yesterday now current last latest
""".split())


def detect_language(text: str) -> str:
    """Savol tilini qaytaradi: 'uz', 'ru' yoki 'en'. Aniqlanmasa 'uz'."""
    raw = (text or "").strip()
    if not raw:
        return "uz"

    letters = _LETTER_RE.findall(raw)
    if letters:
        cyrillic = len(_CYRILLIC_RE.findall(raw))
        # Kirill harflar ko'p bo'lsa — ruscha (o'zbekcha kirill ham bo'lishi
        # mumkin, ammo bu bazada va interfeysda lotin yozuvi ishlatiladi)
        if cyrillic / len(letters) >= 0.3:
            return "ru"

    words = set(re.findall(r"[a-zA-Z'`o‘’]+", raw.lower()))
    # Apostrof variantlarini bittaga keltiramiz: o‘ -> o'
    words = {re.sub(r"[`‘’]", "'", w) for w in words}

    uz_hits = len(words & _UZ_MARKERS)
    en_hits = len(words & _EN_MARKERS)

    if uz_hits > en_hits:
        return "uz"
    if en_hits > uz_hits:
        return "en"

    # Teng bo'lsa: o'zbekchaga xos harf birikmalari bormi
    if re.search(r"[o']['`‘’]|g['`‘’]|\bsh|\bch|ning\b|lar\b|dagi\b", raw.lower()):
        return "uz"
    return "uz"


# =====================================================================
# STATUS QIYMATLARI — javob tiliga TARJIMA QILINADI
# =====================================================================
# Bazada status/tur qiymatlari INGLIZCHA saqlanadi (CLOSED, IN_USE, ...).
# Ilgari qoida ularni "asl ko'rinishida qoldir" derdi va o'zbekcha javob
# ichida inglizcha so'zlar qolib ketardi:
#     "WB-20260817-003: CLOSED, 85462KBA, 4.6 t"
# Endi ular javob tiliga o'giriladi.
#
# NIMA UCHUN LUG'AT KERAK: bazada 317 ta noyob status qiymati bor. Modelga
# "o'zing tarjima qil" deb qo'yilsa, bir xil qiymat har safar boshqacha
# chiqadi (CLOSED -> "yopilgan" / "yopiq" / "tugagan") va foydalanuvchi
# javoblarni solishtira olmaydi. Quyidagi ro'yxat eng ko'p uchraydiganlarni
# QAT'IY belgilaydi; qolganlari ma'no bo'yicha o'giriladi.
#
# Ro'yxat `ddl.sql` dagi CHECK cheklovlaridan olingan (19.08.2026).
_STATUS_UZ = (
    "ACTIVE=faol, INACTIVE=nofaol, DRAFT=qoralama, ISSUED=berilgan, "
    "IN_USE=ishlatilmoqda, RETURNED=qaytarilgan, CLOSED=yopilgan, "
    "CANCELLED=bekor qilingan, COMPLETED=yakunlangan, IN_PROGRESS=jarayonda, "
    "PENDING=kutilmoqda, UNDER_REVIEW=ko'rib chiqilmoqda, "
    "APPROVED=tasdiqlangan, REJECTED=rad etilgan, CONFIRMED=tasdiqlangan, "
    "OPEN=ochiq, ARCHIVED=arxivlangan, PAID=to'langan, PLANNED=rejalashtirilgan, "
    "STARTED=boshlangan, LOADING=yuklanmoqda, DELIVERED=yetkazilgan, "
    "AVAILABLE=bo'sh, RESERVED=band qilingan, RESERVED_FOR_TRIP=reysga band, "
    "ON_TRIP=reysda, IN_OPERATION=ishda, IN_MAINTENANCE=texnik xizmatda, "
    "BLOCKED=bloklangan, DECOMMISSIONED=hisobdan chiqarilgan, "
    "UNAVAILABLE=mavjud emas, REST_REQUIRED=dam olishi kerak, "
    "SICK_LEAVE=kasallik varaqasida, ON_LEAVE=ta'tilda, "
    "SUSPENDED=to'xtatilgan, TERMINATED=ishdan bo'shatilgan, "
    "FIT=yaroqli, RESTRICTED=cheklangan, UNFIT=yaroqsiz, "
    "PASSED=o'tgan, FAILED=o'tmagan, NOT_PERFORMED=o'tkazilmagan, "
    "WORK_ALLOWED=ishga ruxsat, WORK_SUSPENDED=ishdan chetlatilgan, "
    "ASSIGNED=tayinlangan, ARRIVED_AT_POINT=nuqtaga yetib borgan, "
    "LOADED=yuklangan, UNLOADED=tushirilgan, INTERRUPTED=to'xtatilgan, "
    "READY_FOR_PLANNING=rejalashtirishga tayyor, "
    "PENDING_DEPARTMENT_APPROVAL=bo'lim tasdig'i kutilmoqda, "
    "PENDING_TRANSPORT_APPROVAL=transport tasdig'i kutilmoqda, "
    "REJECTED_BY_DEPARTMENT=bo'lim rad etgan, "
    "REJECTED_BY_TRANSPORT=transport rad etgan, "
    "LOW=past, MEDIUM=o'rta, HIGH=yuqori, CRITICAL=jiddiy, OTHER=boshqa"
)
_STATUS_RULE_UZ = (
    "STATUS QIYMATLARINI TARJIMA QIL. Bazada ular inglizcha (CLOSED, IN_USE) "
    "saqlanadi — javobda O'ZBEKCHA yoz, inglizcha shaklini qavsda ham berma.\n"
    f"Lug'at: {_STATUS_UZ}.\n"
    "Ro'yxatda yo'q qiymatni ma'nosi bo'yicha o'zbekchalashtir "
    "(LONG_HAUL -> uzoq masofali). Ma'nosi noaniq bo'lsagina asl shaklda qoldir.\n"
    "DIQQAT: davlat raqami (85462KBA), hujjat raqami (WB-20260817-003), "
    "F.I.Sh. va o'lchov birliklari TARJIMA QILINMAYDI."
)

_STATUS_RU = (
    "ACTIVE=активный, INACTIVE=неактивный, DRAFT=черновик, ISSUED=выдан, "
    "IN_USE=используется, RETURNED=возвращён, CLOSED=закрыт, "
    "CANCELLED=отменён, COMPLETED=завершён, IN_PROGRESS=в процессе, "
    "PENDING=ожидает, UNDER_REVIEW=на рассмотрении, APPROVED=утверждён, "
    "REJECTED=отклонён, CONFIRMED=подтверждён, OPEN=открыт, "
    "ARCHIVED=в архиве, PAID=оплачен, PLANNED=запланирован, STARTED=начат, "
    "LOADING=загрузка, DELIVERED=доставлен, AVAILABLE=свободен, "
    "RESERVED=забронирован, RESERVED_FOR_TRIP=забронирован под рейс, "
    "ON_TRIP=в рейсе, IN_OPERATION=в работе, IN_MAINTENANCE=на техобслуживании, "
    "BLOCKED=заблокирован, DECOMMISSIONED=списан, UNAVAILABLE=недоступен, "
    "REST_REQUIRED=требуется отдых, SICK_LEAVE=на больничном, "
    "ON_LEAVE=в отпуске, SUSPENDED=отстранён, TERMINATED=уволен, "
    "FIT=годен, RESTRICTED=ограниченно годен, UNFIT=не годен, "
    "PASSED=пройден, FAILED=не пройден, NOT_PERFORMED=не проводился, "
    "WORK_ALLOWED=допущен к работе, WORK_SUSPENDED=отстранён от работы, "
    "LOW=низкий, MEDIUM=средний, HIGH=высокий, CRITICAL=критический, "
    "ASSIGNED=назначен, ARRIVED_AT_POINT=прибыл на точку, "
    "LOADED=загружен, UNLOADED=разгружен, INTERRUPTED=прерван, "
    "READY_FOR_PLANNING=готов к планированию, "
    "PENDING_DEPARTMENT_APPROVAL=ожидает согласования отдела, "
    "PENDING_TRANSPORT_APPROVAL=ожидает согласования транспорта, "
    "REJECTED_BY_DEPARTMENT=отклонён отделом, "
    "REJECTED_BY_TRANSPORT=отклонён транспортом, "
    "WAITING_PARTS=ожидает запчасти, WAITING_PARTS_APPROVAL=ожидает согласования запчастей, "
    "PARTS_ISSUED=запчасти выданы, REPAIR_IN_PROGRESS=ремонт идёт, "
    "REPAIRING=в ремонте, REPAIRED=отремонтирован, NOT_REPAIRED=не отремонтирован, "
    "DIAGNOSING=диагностика, CREATED=создан, NEW=новый, "
    "PENDING_FINAL_MECHANIC_INSPECTION=ожидает финальной проверки механика, "
    "FINAL_INSPECTION_PASSED=финальная проверка пройдена, "
    "FINAL_INSPECTION_FAILED=финальная проверка не пройдена, "
    "OTHER=прочее"
)
_STATUS_RULE_RU = (
    "ПЕРЕВОДИ ЗНАЧЕНИЯ СТАТУСОВ. В базе они на английском (CLOSED, IN_USE) — "
    "в ответе пиши ПО-РУССКИ, английский вариант в скобках не давай.\n"
    f"Словарь: {_STATUS_RU}.\n"
    "Значение, которого нет в списке, переведи по смыслу "
    "(LONG_HAUL -> междугородний). Оставляй как есть только если смысл неясен.\n"
    "ВНИМАНИЕ: гос. номера (85462KBA), номера документов (WB-20260817-003), "
    "ФИО и единицы измерения НЕ переводятся."
)

_STATUS_RULE_EN = (
    "Database status values are already in English (CLOSED, IN_USE). Keep them, "
    "but write them in readable form: IN_USE -> in use, NOT_PERFORMED -> "
    "not performed, ON_TRIP -> on a trip. Do not print raw UPPER_SNAKE_CASE.\n"
    "Plate numbers (85462KBA), document numbers (WB-20260817-003), names and "
    "units stay unchanged."
)



# ---------------------------------------------------------------------
# TUR / KATEGORIYA / MULKCHILIK — status EMAS, lekin ular ham bazada
# INGLIZCHA saqlanadi va javobga xom holda chiqib qolardi (02.09.2026:
# "Turi: FLATBED", "Kategoriya: HEAVY", "Mulkchilik: OWNED").
#
# Ilgari bu lug'at `generate_answer._PROMPT` ichida FAQAT O'ZBEKCHA yozilgan
# edi va u "o'zbekcha yoz" deb buyurardi — natijada RUSCHA savolga ham
# o'zbekcha javob kelardi. Shuning uchun u shu yerga, til bo'yicha
# bo'lingan joyga ko'chirildi.
#
# Ro'yxat `ddl.sql` dagi CHECK cheklovlaridan olingan.
_TUR_UZ = (
    "MOBILE_CRANE=avtokran, AERIAL_PLATFORM=havo platformasi, TRACTOR=traktor, "
    "WATER_TRUCK=suv tashuvchi, EXCAVATOR=ekskavator, "
    "FRONT_LOADER=g'ildirakli yuklagich, DUMP_TRUCK=samosval, "
    "LONG_LOAD_TRUCK=uzun yuk tashuvchi, FLATBED=platforma, "
    "MANIPULATOR=manipulyator, PASSENGER_CAR=yengil avtomobil, BUS=avtobus, "
    "VAN=furgon, BULLDOZER=buldozer, CONCRETE_PUMP=beton nasosi, "
    "CONCRETE_MIXER=beton aralashtirgich, FIRE_TRUCK=o't o'chirish mashinasi, "
    "AMBULANCE=tez yordam, TRUCK=yuk mashinasi, TANKER=sisterna, "
    "REFRIGERATED=refrijerator, SPECIALIZED=maxsus texnika, "
    "MINIBUS=mikroavtobus, PICKUP=pikap, TRAILER=tirkama, "
    "LIGHT=yengil, HEAVY=og'ir, EXTRA_HEAVY=o'ta og'ir, SPECIAL=maxsus, "
    "OWNED=o'z mulki, LEASED=lizingda, RENTED=ijarada, "
    "KM=kilometr bo'yicha, MOTOSOAT=motosoat bo'yicha"
)
_TUR_RU = (
    "MOBILE_CRANE=автокран, AERIAL_PLATFORM=автовышка, TRACTOR=трактор, "
    "WATER_TRUCK=водовоз, EXCAVATOR=экскаватор, FRONT_LOADER=фронтальный погрузчик, "
    "DUMP_TRUCK=самосвал, LONG_LOAD_TRUCK=длинномер, FLATBED=бортовой, "
    "MANIPULATOR=манипулятор, PASSENGER_CAR=легковой автомобиль, BUS=автобус, "
    "VAN=фургон, BULLDOZER=бульдозер, CONCRETE_PUMP=бетононасос, "
    "CONCRETE_MIXER=бетоносмеситель, FIRE_TRUCK=пожарная машина, "
    "AMBULANCE=скорая помощь, TRUCK=грузовик, TANKER=цистерна, "
    "REFRIGERATED=рефрижератор, SPECIALIZED=спецтехника, MINIBUS=микроавтобус, "
    "PICKUP=пикап, TRAILER=прицеп, "
    "LIGHT=лёгкий, HEAVY=тяжёлый, EXTRA_HEAVY=особо тяжёлый, SPECIAL=специальный, "
    "OWNED=собственный, LEASED=в лизинге, RENTED=в аренде, "
    "KM=по километражу, MOTOSOAT=по моточасам"
)
_TUR_EN = (
    "MOBILE_CRANE=mobile crane, AERIAL_PLATFORM=aerial platform, "
    "FRONT_LOADER=front loader, DUMP_TRUCK=dump truck, "
    "LONG_LOAD_TRUCK=long-load truck, FLATBED=flatbed, "
    "PASSENGER_CAR=passenger car, CONCRETE_PUMP=concrete pump, "
    "CONCRETE_MIXER=concrete mixer, FIRE_TRUCK=fire truck, "
    "REFRIGERATED=refrigerated, SPECIALIZED=specialized, "
    "EXTRA_HEAVY=extra heavy, OWNED=owned, LEASED=leased, RENTED=rented, "
    "KM=by kilometres, MOTOSOAT=by engine hours"
)
_TUR_RULE = {
    "uz": f"TUR/KATEGORIYA/MULKCHILIK kodlarini ham o'zbekcha yoz: {_TUR_UZ}.",
    "ru": f"КОДЫ ТИПА/КАТЕГОРИИ/СОБСТВЕННОСТИ тоже переводи: {_TUR_RU}.",
    "en": f"Write type/category/ownership codes in readable English: {_TUR_EN}.",
}

#: Promptga qo'shiladigan ko'rsatma
_INSTRUCTIONS = {
    "uz": (
        "JAVOB TILI: O'ZBEK TILI (lotin yozuvi).\n"
        "Butun javob faqat o'zbekcha bo'lsin. Inglizcha yoki ruscha so'z, ibora "
        "va sarlavha ISHLATMA.\n"
        + _STATUS_RULE_UZ
        + "\n" + _TUR_RULE["uz"]
    ),
    "ru": (
        "ЯЗЫК ОТВЕТА: РУССКИЙ.\n"
        "Весь ответ должен быть на русском языке. Не используй узбекские или "
        "английские слова и заголовки.\n"
        + _STATUS_RULE_RU
        + "\n" + _TUR_RULE["ru"]
    ),
    "en": (
        "ANSWER LANGUAGE: ENGLISH.\n"
        "Write the entire answer in English. Do not use Uzbek or Russian words "
        "or headings.\n"
        + _STATUS_RULE_EN
        + "\n" + _TUR_RULE["en"]
    ),
}

#: SQL ustun sarlavhalari uchun ko'rsatma
_LABEL_INSTRUCTIONS = {
    "uz": 'Ustun sarlavhalari (AS) O\'ZBEK TILIDA bo\'lsin: AS "Davlat raqami".',
    "ru": 'Заголовки столбцов (AS) должны быть НА РУССКОМ: AS "Гос. номер".',
    "en": 'Column labels (AS) must be in ENGLISH: AS "Plate number".',
}


def answer_instruction(language: str) -> str:
    return _INSTRUCTIONS.get(language, _INSTRUCTIONS["uz"])


def label_instruction(language: str) -> str:
    return _LABEL_INSTRUCTIONS.get(language, _LABEL_INSTRUCTIONS["uz"])


# ---------------------------------------------------------------------
# Lug'atni KOD uchun ham ochib beramiz.
#
# Yuqoridagi `_STATUS_*` va `_TUR_*` satrlari PROMPT uchun yozilgan. Ammo
# javobning bir qismi LLM'siz, kodda tuziladi (`status_note` — bitta qiymatli
# javobga qo'shiladigan "qaysi holat sanaldi" izohi). U ham javob tilida
# bo'lishi kerak, aks holda ruscha javobga o'zbekcha izoh yopishadi
# (02.09.2026 da aynan shunday bo'lgan).
#
# Tarjimalarni ikkinchi marta yozmaymiz — SHU satrlarning o'zi ajratiladi.
# Shunda prompt va kod bir xil so'zni ishlatadi va ular bir-biridan
# uzoqlashib ketmaydi.
def _dict_from(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for bolak in text.split(","):
        if "=" in bolak:
            kod, _, nom = bolak.partition("=")
            out[kod.strip()] = nom.strip()
    return out


_DICTS: dict[str, dict[str, str]] = {
    "uz": {**_dict_from(_STATUS_UZ), **_dict_from(_TUR_UZ)},
    "ru": {**_dict_from(_STATUS_RU), **_dict_from(_TUR_RU)},
    "en": {**_dict_from(_TUR_EN)},
}


def status_dictionary(language: str) -> dict[str, str]:
    """Bazadagi kod -> shu tildagi nom. Ingliz tilida ro'yxat qisqa:
    kodning o'zi inglizcha so'z, uni faqat o'qishga qulay yozish kerak."""
    return _DICTS.get(language, _DICTS["uz"])
