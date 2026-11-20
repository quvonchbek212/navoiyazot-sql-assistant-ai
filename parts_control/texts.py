"""Javobdagi hamma matn — uch tilda (uz, ru, en).

KODLAR TARJIMA QILINMAYDI: `flags[].code`, `flags[].kind`, `category`.
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

_CHATBOT_DIR = Path(__file__).resolve().parent.parent / "atil_chatbot"
if str(_CHATBOT_DIR) not in sys.path:
    sys.path.insert(0, str(_CHATBOT_DIR))

from core.lang import answer_instruction  # noqa: E402

LANGS = ("uz", "ru", "en")
DEFAULT_LANG = "uz"


def normalize(lang: str | None) -> str:
    value = (lang or "").strip().lower()
    return value if value in LANGS else DEFAULT_LANG


def llm_instruction(lang: str) -> str:
    return answer_instruction(normalize(lang))


def t(lang: str, key: str, **kwargs: Any) -> str:
    row = MESSAGES.get(key)
    if row is None:
        return key
    text = row.get(normalize(lang)) or row[DEFAULT_LANG]
    return text.format(**kwargs) if kwargs else text


MESSAGES: dict[str, dict[str, str]] = {
    # ------------------------------------------------- So'ralgan qism
    "flag.PART_FOR_OTHER_MODEL": {
        "uz": "Boshqa rusumning qismi so'ralgan",
        "ru": "Запрошена деталь для другой марки",
        "en": "Part for another make requested",
    },
    "detail.PART_FOR_OTHER_MODEL": {
        "uz": "\"{item}\" — {mentioned} uchun, mashina esa {vehicle}",
        "ru": "«{item}» — для {mentioned}, а машина {vehicle}",
        "en": "\"{item}\" is for {mentioned}, the vehicle is {vehicle}",
    },
    "flag.VOLTAGE_MISMATCH": {
        "uz": "Kuchlanish mashinaga mos emas",
        "ru": "Напряжение не подходит машине",
        "en": "Voltage does not match the vehicle",
    },
    "detail.VOLTAGE_MISMATCH": {
        "uz": "\"{item}\" — {part_v} V tizim uchun, {vehicle} elektr tizimi {vehicle_v} V",
        "ru": "«{item}» — для системы {part_v} В, у {vehicle} система {vehicle_v} В",
        "en": "\"{item}\" is for a {part_v} V system, {vehicle} runs {vehicle_v} V",
    },
    "flag.BATTERY_SPEC_MISMATCH": {
        "uz": "Akkumulyator sig'imi o'rnatilganiga mos emas",
        "ru": "Ёмкость АКБ не совпадает с установленной",
        "en": "Battery capacity differs from the installed one",
    },
    "detail.BATTERY_SPEC_MISMATCH": {
        "uz": "so'ralgan {ah} Ah, {basis}: {installed} Ah",
        "ru": "запрошено {ah} Ач, {basis}: {installed} Ач",
        "en": "requested {ah} Ah, {basis}: {installed} Ah",
    },
    "basis.own": {"uz": "shu mashinada o'rnatilgan", "ru": "установлено на этой машине",
                  "en": "installed on this vehicle"},
    "basis.peers": {"uz": "shu rusumdagi mashinalarda o'rnatilgan",
                    "ru": "установлено на машинах этой модели",
                    "en": "installed on vehicles of this model"},
    "basis.type": {"uz": "shu turdagi mashinalarda o'rnatilgan",
                   "ru": "установлено на машинах этого типа",
                   "en": "installed on vehicles of this type"},
    "flag.TIRE_SIZE_MISMATCH": {
        "uz": "Shina o'lchami mashinaga mos emas",
        "ru": "Размер шины не подходит машине",
        "en": "Tire size does not match the vehicle",
    },
    "detail.TIRE_SIZE_MISMATCH": {
        "uz": "\"{item}\" — R{rim}, mashinadagi shinalar: R{installed}",
        "ru": "«{item}» — R{rim}, на машине шины R{installed}",
        "en": "\"{item}\" is R{rim}, the vehicle runs R{installed}",
    },
    "flag.QTY_EXCEEDS_FITMENT": {
        "uz": "G'ildiraklar sonidan ko'p shina",
        "ru": "Шин больше, чем колёс",
        "en": "More tires than wheels",
    },
    "detail.QTY_EXCEEDS_FITMENT": {
        "uz": "{qty} dona shina berilgan, mashinada {fitted} ta shina o'rnatilgan",
        "ru": "выдано {qty} шин, на машине установлено {fitted}",
        "en": "{qty} tires issued, the vehicle has {fitted} fitted",
    },
    "flag.ISSUED_NOT_USED": {
        "uz": "Berilgan, ishlatilmagan va qaytarilmagan",
        "ru": "Выдано, не использовано и не возвращено",
        "en": "Issued but neither used nor returned",
    },
    "detail.ISSUED_NOT_USED": {
        "uz": "berilgan {issued} {unit}, ishlatilgan {used}, qaytarilgan {returned} — "
              "{missing} {unit} hisobsiz (holat {status})",
        "ru": "выдано {issued} {unit}, использовано {used}, возвращено {returned} — "
              "не учтено {missing} {unit} (статус {status})",
        "en": "issued {issued} {unit}, used {used}, returned {returned} — {missing} "
              "{unit} unaccounted (status {status})",
    },
    "flag.EARLY_REPLACEMENT": {
        "uz": "Resursidan oldin almashtirilgan",
        "ru": "Замена раньше ресурса",
        "en": "Replaced before end of life",
    },
    "detail.EARLY_REPLACEMENT": {
        "uz": "o'rnatilganiga {used} bo'lgan, resurs {life} — {pct}% ishlatilgan{warranty}",
        "ru": "с установки прошло {used}, ресурс {life} — использовано {pct}%{warranty}",
        "en": "{used} since installation, life {life} — {pct}% used{warranty}",
    },
    "warranty.inside": {
        "uz": "; kafolat muddati ichida ({months} oy) — yetkazib beruvchiga qaytarilishi kerak edi",
        "ru": "; в пределах гарантии ({months} мес.) — должна была быть рекламация поставщику",
        "en": "; within warranty ({months} months) — should have been claimed from the supplier",
    },

    # ------------------------------------------------- O'rnatilgan qism
    "flag.WORN_EARLY": {
        "uz": "Resursidan oldin yeyilgan",
        "ru": "Изношена раньше ресурса",
        "en": "Worn out before end of life",
    },
    "detail.WORN_EARLY": {
        "uz": "\"yeyilgan\" deb belgilangan: {used} ishlatilgan, resurs {life} — {pct}%{warranty}",
        "ru": "отмечена изношенной: использовано {used}, ресурс {life} — {pct}%{warranty}",
        "en": "marked worn: {used} used, life {life} — {pct}%{warranty}",
    },
    "flag.OVER_LIFE": {
        "uz": "Resursi tugagan, hali ishlatilyapti",
        "ru": "Ресурс исчерпан, ещё в работе",
        "en": "Past its life, still in use",
    },
    "detail.OVER_LIFE": {
        "uz": "{used} ishlatilgan, resurs {life} — {pct}%: almashtirish yoki ko'rik kerak",
        "ru": "использовано {used}, ресурс {life} — {pct}%: нужна замена или осмотр",
        "en": "{used} used, life {life} — {pct}%: replace or inspect",
    },
    "flag.LIFE_VALUE_SUSPECT": {
        "uz": "Resurs qiymati xato bo'lishi mumkin",
        "ru": "Значение ресурса, вероятно, ошибочно",
        "en": "Life value is probably wrong",
    },
    "detail.LIFE_VALUE_SUSPECT": {
        "uz": "resurs {value} km yozilgan, boshqa shu turdagi qismlarda {ten} km — "
              "bitta nol tushib qolgan bo'lishi mumkin",
        "ru": "ресурс записан {value} км, у других таких деталей {ten} км — "
              "возможно, пропущен ноль",
        "en": "life recorded as {value} km, other such parts have {ten} km — a zero "
              "may be missing",
    },
    "unit.km": {"uz": "{v} km", "ru": "{v} км", "en": "{v} km"},
    "unit.months": {"uz": "{v} oy", "ru": "{v} мес.", "en": "{v} months"},
    "unit.hours": {"uz": "{v} motosoat", "ru": "{v} моточасов", "en": "{v} engine hours"},

    # ------------------------------------------------------ data_quality
    "note.no_removal_history": {
        "uz": "Qism QACHON YECHILGANI bazada yozilmaydi (`vehicle_part.removed_at` "
              "hammasida bo'sh) — \"har 20 ming km da almashtiryapti\" degan tarix faqat "
              "qism so'rovlaridan ko'rinadi; qism yechilishi yozila boshlasa hisob o'zi "
              "aniqlashadi.",
        "ru": "Дата СНЯТИЯ детали в базе не записывается (`vehicle_part.removed_at` "
              "пуст) — частота замен видна только по заявкам на детали.",
        "en": "Part REMOVAL dates are not recorded (`vehicle_part.removed_at` is "
              "empty) — replacement frequency is visible only from part requests.",
    },
    "note.no_movement": {
        "uz": "Ombor kirim-chiqim harakati jadvallari bo'sh (`material_movement`, "
              "`inventory_receipt`) — kirim tarixi TEKSHIRILMADI, faqat joriy qoldiq ko'rinadi.",
        "ru": "Таблицы движения склада пусты (`material_movement`, `inventory_receipt`) "
              "— приход НЕ ПРОВЕРЯЛСЯ, виден только текущий остаток.",
        "en": "Warehouse movement tables are empty (`material_movement`, "
              "`inventory_receipt`) — receipts were NOT CHECKED, only the current stock is visible.",
    },
    "note.entry_dates": {
        "uz": "{count} ta qismning o'rnatilgan sanasi bazaga kiritilgan kun bilan bir "
              "xil — bu haqiqiy o'rnatish sanasi bo'lmasligi mumkin, ular uchun oy "
              "bo'yicha resurs TEKSHIRILMADI (km bo'yicha tekshirildi).",
        "ru": "У {count} деталей дата установки совпадает с датой ввода в базу — "
              "ресурс по месяцам для них НЕ ПРОВЕРЯЛСЯ (по км проверен).",
        "en": "{count} part(s) have an install date equal to the entry date — the "
              "monthly life was NOT CHECKED for them (km was checked).",
    },
    "note.no_life": {
        "uz": "{count} ta qismda resurs yo'q (na bazada, na ma'lumotnomada) — ular "
              "TEKSHIRILMADI.",
        "ru": "У {count} деталей нет ресурса (ни в базе, ни в справочнике) — НЕ ПРОВЕРЯЛИСЬ.",
        "en": "{count} part(s) have no life value (neither DB nor reference) — NOT CHECKED.",
    },
    "note.few_requests": {
        "uz": "Davrda {count} ta qism so'rovi bor — so'rovlar ko'paygan sari erta "
              "almashtirish tekshiruvi to'liqroq ishlaydi.",
        "ru": "За период {count} заявок на детали — с ростом данных проверка ранних "
              "замен станет полнее.",
        "en": "{count} part request(s) in the period — the early-replacement check "
              "gets fuller as data grows.",
    },
    "note.categories": {
        "uz": "Bazadagi o'rnatilgan qismlar faqat shina va akkumulyator — boshqa "
              "qismlar so'rovlar orqali tekshiriladi.",
        "ru": "Установленные детали в базе — только шины и АКБ; остальные "
              "проверяются по заявкам.",
        "en": "Installed parts in the DB are only tires and batteries; others are "
              "checked through requests.",
    },

    # ------------------------------------------------------ Mashina pasporti
    "status.OVERDUE": {"uz": "VAQTI O'TGAN", "ru": "ПРОСРОЧЕНО", "en": "OVERDUE"},
    "status.DUE_SOON": {"uz": "Vaqti yaqinlashdi", "ru": "Скоро срок", "en": "Due soon"},
    "status.OK": {"uz": "Joyida", "ru": "В норме", "en": "OK"},
    "status.UNKNOWN": {"uz": "Noma'lum (tarix yo'q)", "ru": "Неизвестно (нет истории)",
                       "en": "Unknown (no history)"},
    "status.NO_INTERVAL": {"uz": "Oraliq ma'lum emas (faqat tarix)",
                           "ru": "Интервал неизвестен (только история)",
                           "en": "No interval (history only)"},
    "action.REPLACED": {"uz": "almashtirildi", "ru": "заменено", "en": "replaced"},
    "action.SERVICED": {"uz": "xizmat ko'rsatildi", "ru": "обслужено", "en": "serviced"},
    "action.REPAIRED": {"uz": "ta'mirlandi", "ru": "отремонтировано", "en": "repaired"},
    "action.INSPECTED": {"uz": "ko'rikdan o'tdi", "ru": "осмотрено", "en": "inspected"},
    "action.BASELINE": {"uz": "bazaga qayd etilgan", "ru": "внесено в базу", "en": "recorded"},
    "action.ISSUED": {"uz": "ombordan berilgan", "ru": "выдано со склада",
                      "en": "issued from stock"},
    "action.IN_REPAIR": {"uz": "ta'mirda", "ru": "в ремонте", "en": "in repair"},
    "component.other": {"uz": "Boshqa qism", "ru": "Прочая деталь", "en": "Other part"},
    "component.status": {"uz": "Mashina holati", "ru": "Статус машины", "en": "Vehicle status"},
    "detail.last": {"uz": "oxirgi: {action} {date} ({at})",
                    "ru": "последнее: {action} {date} ({at})",
                    "en": "last: {action} {date} ({at})"},
    "detail.used": {"uz": "oraliqning {pct}% i o'tdi", "ru": "пройдено {pct}% интервала",
                    "en": "{pct}% of the interval used"},
    "detail.next_km": {"uz": "keyingisi {km} km da", "ru": "следующее на {km} км",
                       "en": "next at {km} km"},
    "detail.next_date": {"uz": "yoki {date} gacha", "ru": "или до {date}", "en": "or by {date}"},
    "detail.worst": {"uz": "eng ko'p yeyilgani ({count} tadan) — {name}: {date} da qo'yilgan ({at})",
                     "ru": "самая изношенная (из {count}) — {name}: установлена {date} ({at})",
                     "en": "most worn (of {count}) — {name}: installed {date} ({at})"},
    "detail.unknown": {
        "uz": "tarix yo'q — birinchi almashtirish yozilgach hisoblanadi",
        "ru": "истории нет — считается после первой записанной замены",
        "en": "no history — tracked after the first recorded replacement",
    },
    "detail.usage_unknown": {
        "uz": "o'shandan beri qancha ishlagani noma'lum — spidometr/motosoat yo'q yoki zid",
        "ru": "наработка с тех пор неизвестна — показаний одометра/моточасов нет или они "
              "противоречивы",
        "en": "usage since then unknown — odometer/engine-hour readings missing or "
              "contradictory",
    },
    "detail.no_interval": {
        "uz": "oraliq ma'lum emas — ATIL maintenance_plan ga kiritilsa hisoblanadi",
        "ru": "интервал неизвестен — будет считаться после ввода в maintenance_plan",
        "en": "interval unknown — tracked once entered in ATIL maintenance_plan",
    },
    "alert.OVERDUE": {"uz": "{name}: VAQTI O'TGAN — {detail}",
                      "ru": "{name}: ПРОСРОЧЕНО — {detail}",
                      "en": "{name}: OVERDUE — {detail}"},
    "alert.DUE_SOON": {"uz": "{name}: vaqti yaqinlashdi — {detail}",
                       "ru": "{name}: скоро срок — {detail}",
                       "en": "{name}: due soon — {detail}"},
    "passport.summary": {
        "uz": "{plate} ({vehicle}): {total} ta qism kuzatiladi — {overdue} tasining vaqti "
              "o'tgan, {soon} tasining vaqti yaqinlashdi, {unknown} tasi bo'yicha ma'lumot "
              "yetarli emas.",
        "ru": "{plate} ({vehicle}): отслеживается {total} деталей — просрочено {overdue}, "
              "скоро срок у {soon}, по {unknown} данных недостаточно.",
        "en": "{plate} ({vehicle}): {total} parts tracked — {overdue} overdue, {soon} due "
              "soon, {unknown} without enough data.",
    },
    "note.passport_unknown": {
        "uz": "{count} ta qism uchun bazada hali tarix yo'q — holati NOMA'LUM. Almashtirish "
              "`POST /parts-control/passport` bilan yoki ATIL ta'miri / texnik xizmat "
              "rejasida yozilsa, shu kundan boshlab kuzatiladi.",
        "ru": "Для {count} деталей в базе нет истории — состояние НЕИЗВЕСТНО. После записи "
              "замены (`POST /parts-control/passport`, ремонт или план ТО в ATIL) деталь "
              "начнёт отслеживаться.",
        "en": "{count} part(s) have no history yet — status UNKNOWN. Once a replacement is "
              "recorded (`POST /parts-control/passport`, an ATIL repair or maintenance plan) "
              "the part is tracked from that day.",
    },
    "note.passport_no_interval": {
        "uz": "{count} ta qism uchun ishlab chiqaruvchi oralig'i topilmadi — faqat tarix "
              "kuzatiladi. Aniq oraliqni ATIL `maintenance_plan` ga kiriting.",
        "ru": "Для {count} деталей интервал производителя не найден — ведётся только "
              "история. Внесите интервал в `maintenance_plan` ATIL.",
        "en": "No manufacturer interval found for {count} part(s) — history only. Enter "
              "the interval in ATIL `maintenance_plan`.",
    },
    "note.passport_no_readings": {
        "uz": "Mashinada spidometr/motosoat ko'rsatkichi yo'q — km va soat bo'yicha hisob "
              "TEKSHIRILMADI.",
        "ru": "У машины нет показаний одометра/моточасов — расчёт по км и часам НЕ "
              "ПРОВЕРЯЛСЯ.",
        "en": "No odometer/engine-hour readings — km and hour checks were NOT CHECKED.",
    },
    "note.passport_readings_dropped": {
        "uz": "Spidometr/motosoat yozuvlaridan {count} tasi boshqalariga zid (orqaga ketgan "
              "yoki keskin sakragan) — hisobga olinmadi. ATIL yo'l varaqalari va texnik "
              "ko'riklarini tekshiring.",
        "ru": "{count} показаний одометра/моточасов противоречат остальным (откат назад или "
              "скачок) — не учтены. Проверьте путевые листы и техосмотры в ATIL.",
        "en": "{count} odometer/engine-hour reading(s) contradict the rest (rollback or "
              "jump) — ignored. Check ATIL waybills and inspections.",
    },
    "note.passport_data_issues": {
        "uz": "Qismlar ma'lumotida {count} ta ziddiyat (resurs \"4 000 km\" — nol tushib "
              "qolgan, yoki o'rnatilgandan beri jismonan imkonsiz km/motosoat) — o'sha "
              "o'lchov hisobga olinmadi, taxmin qilinmadi. ATIL vehicle_part ni tekshiring.",
        "ru": "В данных деталей {count} противоречий (ресурс «4 000 км» — потерян ноль, или "
              "физически невозможный пробег/моточасы с установки) — это измерение не учтено. "
              "Проверьте vehicle_part в ATIL.",
        "en": "{count} contradiction(s) in part data (life \"4,000 km\" — a dropped zero, or "
              "physically impossible km/engine hours since install) — that measure was "
              "ignored, not guessed. Check ATIL vehicle_part.",
    },
    # ------------------------------------------------- Almashtirish tekshiruvi
    "check.verdict.JUSTIFIED": {"uz": "ASOSLI", "ru": "ОБОСНОВАНО", "en": "JUSTIFIED"},
    "check.verdict.CHECK": {"uz": "TEKSHIRING", "ru": "ПРОВЕРЬТЕ", "en": "CHECK FIRST"},
    "check.verdict.NO_DATA": {"uz": "MA'LUMOT YO'Q", "ru": "НЕТ ДАННЫХ", "en": "NO DATA"},
    "check.head": {"uz": "{plate} ({vehicle}) — {name}: {count} dona so'ralgan — {verdict}.",
                   "ru": "{plate} ({vehicle}) — {name}: запрошено {count} шт. — {verdict}.",
                   "en": "{plate} ({vehicle}) — {name}: {count} requested — {verdict}."},
    "check.head_one": {"uz": "{plate} ({vehicle}) — {name}: almashtirish so'ralgan — {verdict}.",
                       "ru": "{plate} ({vehicle}) — {name}: запрошена замена — {verdict}.",
                       "en": "{plate} ({vehicle}) — {name}: replacement requested — {verdict}."},
    "check.group.JUSTIFIED": {"uz": "Almashtirish asosli ({count} ta):",
                              "ru": "Замена обоснована ({count} шт.):",
                              "en": "Replacement justified ({count}):"},
    "check.group.CHECK": {"uz": "Yaqinda almashtirilgan — holati yaxshi bo'lishi kerak ({count} ta):",
                          "ru": "Заменены недавно — состояние должно быть хорошим ({count} шт.):",
                          "en": "Replaced recently — should still be in good condition ({count}):"},
    "check.group.NO_DATA": {"uz": "Oldingi almashtirish ma'lumoti yo'q ({count} ta):",
                            "ru": "Нет данных о прошлой замене ({count} шт.):",
                            "en": "No data on the previous replacement ({count}):"},
    "check.extra": {"uz": "Mashinada {installed} ta qayd etilgan, {count} ta so'ralgan — ortiqcha "
                          "{extra} tasi uchun asos yo'q (zaxira bo'lsa, ko'rsating).",
                    "ru": "На машине учтено {installed}, запрошено {count} — для лишних {extra} "
                          "оснований нет (если запаска — укажите).",
                    "en": "{installed} recorded on the vehicle, {count} requested — no basis for "
                          "the extra {extra} (state if it is a spare)."},
    "check.ago": {"uz": "{v} oldin", "ru": "{v} назад", "en": "{v} ago"},
    "check.days": {"uz": "{v} kun", "ru": "{v} дн.", "en": "{v} days"},
    "check.early": {"uz": "Oxirgi marta {date} da ({ago}) almashtirilgan, o'shandan beri {since}. "
                          "Standart bo'yicha {life} ({source}) — yana {left} xizmat qilishi kerak edi "
                          "({pct}% ishlatilgan). Holati yaxshi bo'lishi kerak — almashtirishdan oldin "
                          "tekshiring.",
                    "ru": "Последняя замена {date} ({ago}), с тех пор {since}. По нормативу {life} "
                          "({source}) — должна была прослужить ещё {left} (использовано {pct}%). "
                          "Состояние должно быть хорошим — проверьте перед заменой.",
                    "en": "Last replaced {date} ({ago}), {since} since then. Standard life is {life} "
                          "({source}) — it should have lasted another {left} ({pct}% used). It should "
                          "be in good condition — inspect before replacing."},
    "check.due": {"uz": "Almashtirish asosli: {detail}.", "ru": "Замена обоснована: {detail}.",
                  "en": "Replacement justified: {detail}."},
    "check.no_history": {"uz": "Bu qismning oldingi almashtirilishi bazada yo'q — solishtirib "
                               "bo'lmaydi.{standard}",
                         "ru": "Прошлой замены этой детали в базе нет — сравнить не с чем.{standard}",
                         "en": "No previous replacement of this part in the database — nothing to "
                               "compare with.{standard}"},
    "check.standard": {"uz": " Standart bo'yicha {life} da almashtiriladi ({source}).",
                       "ru": " По нормативу меняется через {life} ({source}).",
                       "en": " Standard interval: {life} ({source})."},
    "check.no_interval": {"uz": "Oxirgi marta {date} da ({ago}) almashtirilgan, lekin standart "
                                "oralig'i manbasi topilmagan — holatiga qarab hal qiling.",
                          "ru": "Последняя замена {date} ({ago}), но источника нормативного "
                                "интервала нет — решайте по состоянию.",
                          "en": "Last replaced {date} ({ago}), but no source for a standard "
                                "interval — decide by condition."},
    "check.not_tracked": {"uz": "{name} bu mashina turi uchun kuzatilmaydi.",
                          "ru": "{name} для этого типа машины не отслеживается.",
                          "en": "{name} is not tracked for this vehicle type."},
    "check.rec.inspect": {"uz": "Eski qismni mexanik va transport boshlig'i birga ko'zdan kechirsin.",
                          "ru": "Механик и начальник транспорта вместе осматривают старую деталь.",
                          "en": "Have the mechanic and the transport head inspect the old part "
                                "together."},
    "check.rec.act": {"uz": "Shikast bo'lsa (teshilish, yorilish, zavod nuqsoni) — dalolatnoma va "
                            "foto bilan rasmiylashtiring; shikastsiz almashtirmang.",
                      "ru": "При повреждении (прокол, порез, заводской дефект) — акт и фото; без "
                            "повреждения не меняйте.",
                      "en": "If damaged (puncture, cut, factory defect) — file a report with photos; "
                            "do not replace without damage."},
    "check.rec.return_old": {"uz": "Yangisini eskisi omborga topshirilgandan keyin bering.",
                             "ru": "Выдавайте новую после сдачи старой на склад.",
                             "en": "Issue the new one after the old one is returned to the store."},
    "check.rec.warranty": {"uz": "Kafolat muddati ichida ({used} < {warranty}) — nuqson bo'lsa "
                                 "yetkazib beruvchiga da'vo qiling.",
                           "ru": "В пределах гарантии ({used} < {warranty}) — при дефекте "
                                 "предъявите рекламацию поставщику.",
                           "en": "Within warranty ({used} < {warranty}) — claim against the "
                                 "supplier if defective."},
    "check.rec.record": {"uz": "Almashtirilgach yozib qo'ying (POST /parts-control/passport) — "
                               "keyingi safar tizim solishtira oladi.",
                         "ru": "После замены запишите её (POST /parts-control/passport) — в "
                               "следующий раз система сможет сравнить.",
                         "en": "Record the replacement (POST /parts-control/passport) so the "
                               "system can compare next time."},
    "check.warning": {"uz": "Ogohlantirish: {text}", "ru": "Предупреждение: {text}",
                      "en": "Warning: {text}"},
    # ------------------------------------------------------- Chat javobi
    "chat.header": {"uz": "{plate} — {vehicle}, {cls}. {meter}",
                    "ru": "{plate} — {vehicle}, {cls}. {meter}",
                    "en": "{plate} — {vehicle}, {cls}. {meter}"},
    "chat.meter_km": {"uz": "Spidometr: {v} ({day} holatiga).", "ru": "Одометр: {v} (на {day}).",
                      "en": "Odometer: {v} (as of {day})."},
    "chat.meter_hours": {"uz": "Motosoat: {v} ({day} holatiga).",
                         "ru": "Моточасы: {v} (на {day}).", "en": "Engine hours: {v} (as of {day})."},
    "chat.meter_none": {"uz": "Spidometr va motosoat ma'lumoti yo'q.",
                        "ru": "Данных одометра и моточасов нет.",
                        "en": "No odometer or engine-hour data."},
    "chat.attention": {"uz": "Diqqat:", "ru": "Внимание:", "en": "Attention:"},
    "chat.no_alerts": {"uz": "Hozircha vaqti o'tgan yoki yaqinlashgan qism yo'q.",
                       "ru": "Сейчас нет деталей с просроченным или близким сроком.",
                       "en": "No parts are overdue or due soon right now."},
    "chat.known": {"uz": "Holati hisoblangan qismlar:", "ru": "Детали с рассчитанным состоянием:",
                   "en": "Parts with a computed status:"},
    "chat.unknown_list": {"uz": "Tarixi yo'q (noma'lum, taxmin qilinmaydi): {names}.",
                          "ru": "Нет истории (неизвестно, не угадываем): {names}.",
                          "en": "No history (unknown, not guessed): {names}."},
    "chat.no_interval_list": {"uz": "Almashtirish oralig'i manbasi topilmagan: {names}.",
                              "ru": "Не найден источник интервала замены: {names}.",
                              "en": "No source for the replacement interval: {names}."},
    "chat.not_tracked": {"uz": "{name} bu mashina turi uchun kuzatilmaydi.",
                         "ru": "{name} для этого типа машины не отслеживается.",
                         "en": "{name} is not tracked for this vehicle type."},
    "chat.pieces": {"uz": "{name} — {count} dona:", "ru": "{name} — {count} шт.:",
                    "en": "{name} — {count} pcs:"},
    "chat.drivers_assigned": {"uz": "Biriktirilgan haydovchi: {names}.",
                              "ru": "Закреплённый водитель: {names}.",
                              "en": "Assigned driver: {names}."},
    "chat.drivers_none": {"uz": "Biriktirilgan haydovchi yozilmagan.",
                          "ru": "Закреплённый водитель не указан.", "en": "No assigned driver."},
    "chat.driver_changes": {"uz": "Yo'l varaqalari bo'yicha kim haydagan (oxirgilari):",
                            "ru": "Кто ездил по путевым листам (последние):",
                            "en": "Who drove, by waybills (latest):"},
    "chat.driver_period": {"uz": "{name}: {start} — {end} ({trips} ta varaqa)",
                           "ru": "{name}: {start} — {end} ({trips} путевых листов)",
                           "en": "{name}: {start} — {end} ({trips} waybills)"},
    "chat.usage": {"uz": "Ish profili:", "ru": "Профиль работы:", "en": "Usage profile:"},
    "chat.not_found": {"uz": "Mashina topilmadi: {plate}.", "ru": "Машина не найдена: {plate}.",
                       "en": "Vehicle not found: {plate}."},
    "chat.many": {"uz": "Bir nechta mashina mos keldi: {plates}. Raqamni to'liq yozing.",
                  "ru": "Подходит несколько машин: {plates}. Укажите номер полностью.",
                  "en": "Several vehicles match: {plates}. Please give the full plate."},
    "chat.fleet": {"uz": "{name}: vaqti o'tgan — {overdue} ta mashina{over_list}; vaqti "
                         "yaqinlashgan — {soon} ta{soon_list}.",
                   "ru": "{name}: просрочено — {overdue} машин{over_list}; срок близко — "
                         "{soon}{soon_list}.",
                   "en": "{name}: overdue — {overdue} vehicles{over_list}; due soon — "
                         "{soon}{soon_list}."},
    "chat.fleet_unknown": {"uz": "{count} ta mashinada bu qism bo'yicha tarix yoki oraliq yo'q — "
                                 "ular hisobga kirmadi (taxmin qilinmaydi).",
                           "ru": "У {count} машин нет истории или интервала по этой детали — "
                                 "не учтены.",
                           "en": "{count} vehicles have no history or interval for this part — "
                                 "not counted."},
    "chat.pending": {"uz": "Tasdiqlangan, hali berilmagan qism so'rovlari: {items}.",
                     "ru": "Одобренные, но ещё не выданные заявки: {items}.",
                     "en": "Approved but not yet issued requests: {items}."},
    "chat.more": {"uz": "... yana {count} ta (jadvalda).", "ru": "... ещё {count} (в таблице).",
                  "en": "... {count} more (in the table)."},
    "chat.unknown_part": {"uz": "oldingi almashtirish bazada yozilmagan — keyingi muddatni "
                                "hisoblab bo'lmaydi.",
                          "ru": "прошлая замена в базе не записана — следующий срок рассчитать "
                                "нельзя.",
                          "en": "no previous replacement recorded — the next due date cannot be "
                                "computed."},
    "chat.standard": {"uz": "Standart oraliq: {life} ({source}).",
                      "ru": "Нормативный интервал: {life} ({source}).",
                      "en": "Standard interval: {life} ({source})."},
    "chat.or": {"uz": " yoki ", "ru": " или ", "en": " or "},
    "chat.either": {"uz": ", qaysi biri oldin kelsa", "ru": ", что наступит раньше",
                    "en": ", whichever comes first"},
    "chat.now_km": {"uz": "Hozir spidometr: {v}.", "ru": "Сейчас одометр: {v}.",
                    "en": "Odometer now: {v}."},
    "chat.no_meter": {"uz": "Spidometr ma'lumoti ham yo'q.", "ru": "Данных одометра тоже нет.",
                      "en": "No odometer data either."},
    "chat.no_meter_idle": {"uz": "Spidometr ma'lumoti ham, so'nggi 90 kunda reys ham yo'q — "
                                 "mashina ishlatilmayotgan bo'lishi mumkin.",
                           "ru": "Нет ни данных одометра, ни рейсов за 90 дней — машина, "
                                 "возможно, не используется.",
                           "en": "No odometer data and no trips in 90 days — the vehicle may be "
                                 "out of use."},
    "chat.record_hint": {"uz": "Almashtirilganda yozib qo'ying — shundan keyin muddat hisoblanadi.",
                         "ru": "Запишите замену — после этого срок будет рассчитываться.",
                         "en": "Record the replacement — the due date will be tracked from it."},
    "chat.no_activity": {"uz": "So'nggi {days} kunda bu mashinaning reysi ham, yo'l varaqasi ham "
                               "yo'q — ishlatilmayotgan bo'lishi mumkin.",
                         "ru": "За последние {days} дн. у машины нет ни рейсов, ни путевых листов "
                               "— возможно, не используется.",
                         "en": "No trips or waybills in the last {days} days — it may be out of "
                               "use."},
    "chat.recommend": {"uz": "Tavsiya:", "ru": "Рекомендации:", "en": "Recommendations:"},
    "chat.col.part": {"uz": "Qism", "ru": "Деталь", "en": "Part"},
    "chat.col.status": {"uz": "Holat", "ru": "Состояние", "en": "Status"},
    "chat.col.detail": {"uz": "Tafsilot", "ru": "Подробности", "en": "Details"},
    "chat.col.vehicle": {"uz": "Mashina", "ru": "Машина", "en": "Vehicle"},
    "chat.col.need": {"uz": "Kerak", "ru": "Нужно", "en": "Needed"},
    "chat.col.stock": {"uz": "Omborda", "ru": "На складе", "en": "In stock"},
    "chat.col.short": {"uz": "Yetishmaydi", "ru": "Не хватает", "en": "Short"},
    "chat.col.spec": {"uz": "O'lcham", "ru": "Размер", "en": "Size"},
    # ------------------------------------------------------- Talab prognozi
    "forecast.cat.TIRE": {"uz": "Shina", "ru": "Шина", "en": "Tire"},
    "forecast.cat.BATTERY": {"uz": "Akkumulyator", "ru": "Аккумулятор", "en": "Battery"},
    "forecast.spec_unknown": {"uz": "(o'lchami bazada yozilmagan)",
                              "ru": "(размер в базе не указан)", "en": "(size not recorded)"},
    "forecast.need": {"uz": "{total} dona kerak ({detail})", "ru": "нужно {total} шт. ({detail})",
                      "en": "{total} needed ({detail})"},
    "forecast.need_now": {"uz": "{count} tasi hozir — resursi tugagan",
                          "ru": "{count} — сейчас, ресурс исчерпан",
                          "en": "{count} now — life exhausted"},
    "forecast.need_period": {"uz": "{count} tasi {days} kun ichida",
                             "ru": "{count} — в ближайшие {days} дн.",
                             "en": "{count} within {days} days"},
    "forecast.summary_one": {"uz": "Keyingi {days} kunda ({vehicles} ta mashina): {what} — {count} "
                                   "dona kerak; {shortage} ta o'lchamda omborda yetishmaydi.",
                             "ru": "На ближайшие {days} дн. ({vehicles} машин): {what} — нужно "
                                   "{count} шт.; по {shortage} размерам на складе не хватает.",
                             "en": "Next {days} days ({vehicles} vehicles): {what} — {count} "
                                   "needed; {shortage} size(s) short in stock."},
    "forecast.none_due": {"uz": "{days} kun ichida muddati keladigani yo'q",
                          "ru": "в ближайшие {days} дн. срок не наступает",
                          "en": "none due within {days} days"},
    "forecast.undated": {"uz": "yana {count} tasining vaqti yaqin, sanasi noma'lum",
                         "ru": "ещё у {count} срок близко, дата неизвестна",
                         "en": "{count} more are close, date unknown"},
    "forecast.undated_tail": {"uz": "; yana {count} tasida vaqti yaqin, sanasi noma'lum",
                              "ru": "; ещё у {count} срок близко, дата неизвестна",
                              "en": "; {count} more close, date unknown"},
    "forecast.stock": {"uz": "omborda {qty} dona", "ru": "на складе {qty} шт.",
                       "en": "{qty} in stock"},
    "forecast.stock_none": {"uz": "omborda shu o'lcham yo'q", "ru": "на складе такого размера нет",
                            "en": "this size is not in stock"},
    "forecast.stock_unknown": {"uz": "ombor bilan solishtirib bo'lmaydi",
                               "ru": "сравнить со складом нельзя", "en": "cannot compare with stock"},
    "forecast.shortage": {"uz": "{qty} dona yetishmaydi", "ru": "не хватает {qty} шт.",
                          "en": "{qty} short"},
    "forecast.enough": {"uz": "yetadi", "ru": "хватает", "en": "enough"},
    "forecast.history": {"uz": "o'tgan 12 oyda {count} ta qo'yilgan — oyiga ~{avg}, {days} kunga "
                               "~{expected}",
                         "ru": "за 12 мес. установлено {count} — ~{avg} в месяц, ~{expected} "
                               "за {days} дн.",
                         "en": "{count} installed in 12 months — ~{avg}/month, ~{expected} per "
                               "{days} days"},
    "forecast.service": {"uz": "{name}: {now} ta mashinada vaqti o'tgan, {horizon} tasida {days} "
                               "kun ichida keladi{undated}",
                         "ru": "{name}: просрочено у {now} машин, у {horizon} наступит в "
                               "ближайшие {days} дн.{undated}",
                         "en": "{name}: overdue on {now} vehicles, due within {days} days on "
                               "{horizon}{undated}"},
    "forecast.summary": {"uz": "Keyingi {days} kunda ({vehicles} ta mashina): {tires} dona shina, "
                               "{batteries} dona akkumulyator kerak; {shortage} ta o'lchamda "
                               "omborda yetishmaydi; boshqa qismlar bo'yicha {services} ta "
                               "xizmat (almashtirish) vaqti keladi.",
                         "ru": "На ближайшие {days} дн. ({vehicles} машин): нужно {tires} шин, "
                               "{batteries} аккумуляторов; по {shortage} размерам на складе не "
                               "хватает; по остальным деталям — {services} обслуживаний.",
                         "en": "Next {days} days ({vehicles} vehicles): {tires} tires and "
                               "{batteries} batteries needed; {shortage} size(s) short in stock; "
                               "{services} other services due."},
    "note.forecast_method": {
        "uz": "Ikki usul alohida: (1) muddati bo'yicha — har bir shina/akkumulyatorning resursi va "
              "kunlik yurish ({days} kun); (2) o'tgan sarf bo'yicha — so'nggi 12 oyda nechta "
              "qo'yilgan. Ular aralashtirilmaydi. Vaqti yaqin, lekin kunlik yurishi noma'lum "
              "donalar davrga qo'shilmaydi — alohida sanaladi.",
        "ru": "Два метода отдельно: (1) по сроку — ресурс каждой шины/аккумулятора и суточный "
              "пробег ({days} дн.); (2) по прошлому расходу — сколько установлено за 12 мес. Они "
              "не смешиваются. Детали со сроком близко, но без суточного пробега, считаются "
              "отдельно.",
        "en": "Two methods, kept separate: (1) by due date — each tire/battery life and daily "
              "usage ({days} days); (2) by past consumption — installs in 12 months. They are "
              "not blended. Pieces close to due but without daily usage are counted separately.",
    },
    "note.forecast_history_low": {
        "uz": "O'tgan sarf KAM ko'rsatishi mumkin: almashtirilgan eski qism yozuvi bazada "
              "qolmaydi (yechilgan sana yozilmaydi).",
        "ru": "Прошлый расход может быть занижен: запись о снятой детали в базе не остаётся.",
        "en": "Past consumption may be understated: removed parts are not kept in the database.",
    },
    "note.forecast_no_data": {
        "uz": "{count} xil qism (moy, filtr, kolodka...) bo'yicha ko'p mashinada tarix yoki oraliq "
              "yo'q — ular uchun prognoz qilinmaydi (`not_forecast`). Almashtirishlar yozila "
              "boshlagach o'zi hisoblanadi.",
        "ru": "По {count} видам деталей (масло, фильтры, колодки...) у многих машин нет истории "
              "или интервала — прогноз не делается (`not_forecast`).",
        "en": "{count} part types (oil, filters, pads...) lack history or interval on many "
              "vehicles — not forecast (`not_forecast`).",
    },
    "note.forecast_future_dates": {
        "uz": "{count} ta qismning o'rnatilgan sanasi kelajakda — xato, sarfga kirmadi.",
        "ru": "У {count} деталей дата установки в будущем — ошибка, не учтены.",
        "en": "{count} part(s) have a future install date — an error, excluded.",
    },
    "piece.group": {"uz": "{count} ta ({names}): {body}", "ru": "{count} шт. ({names}): {body}",
                    "en": "{count} pcs ({names}): {body}"},
    "piece.no_rate_once": {"uz": "Kunlik yurish noma'lum — qachon tugashini sana bilan aytib "
                                 "bo'lmaydi.",
                           "ru": "Суточный пробег неизвестен — дату окончания ресурса назвать "
                                 "нельзя.",
                           "en": "Daily usage unknown — no end date can be given."},
    "piece.installed": {"uz": "{date} da qo'yilgan{at}", "ru": "установлена {date}{at}",
                        "en": "installed {date}{at}"},
    "piece.entry": {"uz": "bazaga {date} da kiritilgan, qo'yilgan sanasi noma'lum",
                    "ru": "внесена в базу {date}, дата установки неизвестна",
                    "en": "entered {date}, install date unknown"},
    # "O'shandan beri" emas: sanasi noma'lum donada (faqat bazaga kiritilgan
    # kun ma'lum) u "kiritilgandan beri" deb o'qilardi (85681DBA, 29.10.2026).
    "piece.used": {"uz": "qo'yilgandan beri {v}", "ru": "с установки {v}",
                   "en": "{v} since installation"},
    "piece.life": {"uz": "resursi {life} — {pct}% ishlatilgan",
                   "ru": "ресурс {life} — использовано {pct}%", "en": "life {life} — {pct}% used"},
    "piece.left": {"uz": "{v} qoldi", "ru": "осталось {v}", "en": "{v} left"},
    "piece.over": {"uz": "resursi tugagan", "ru": "ресурс исчерпан", "en": "life exhausted"},
    "piece.worn": {"uz": "ATIL'da yeyilgan deb belgilangan", "ru": "в ATIL отмечена изношенной",
                   "en": "marked worn in ATIL"},
    "piece.until": {"uz": "taxminan {date} gacha", "ru": "примерно до {date}",
                    "en": "until about {date}"},
    "piece.no_rate": {"uz": "qachon tugashini aytib bo'lmaydi — kunlik yurish noma'lum",
                      "ru": "срок не определить — неизвестен суточный пробег",
                      "en": "no date — daily usage unknown"},
    "usage.period": {
        "uz": "So'nggi {days} kun{since}: {meter} bo'yicha {km_odometer}, reyslar bo'yicha "
              "{km_trips}; {trips} ta reys; {active} kun ishlagan, {idle} kun turgan, {repair} "
              "kun ta'mirda; yuk: {cargo}.",
        "ru": "Последние {days} дн.{since}: по {meter} {km_odometer}, по рейсам {km_trips}; "
              "рейсов: {trips}; работал {active} дн., простаивал {idle} дн., в ремонте {repair} "
              "дн.; груз: {cargo}.",
        "en": "Last {days} days{since}: {km_odometer} by {meter}, {km_trips} by trips; "
              "{trips} trips; worked {active} days, idle {idle} days, in repair {repair} days; "
              "cargo: {cargo}.",
    },
    "usage.meter_km": {"uz": "spidometr", "ru": "одометру", "en": "odometer"},
    "usage.meter_hours": {"uz": "motosoat hisoblagichi", "ru": "счётчику моточасов",
                          "en": "hour meter"},
    "usage.since": {"uz": " (ma'lumot {day} dan)", "ru": " (данные с {day})",
                    "en": " (data since {day})"},
    "usage.cargo": {"uz": "{tons} t ({count} ta yo'l varaqasida)",
                    "ru": "{tons} т (в {count} путевых листах)",
                    "en": "{tons} t (in {count} waybills)"},
    "usage.cargo_none": {"uz": "bazada yozilmagan", "ru": "в базе не указан",
                         "en": "not recorded"},
    "word.unknown": {"uz": "noma'lum", "ru": "неизвестно", "en": "unknown"},
    "note.usage_suspicious_trips": {
        "uz": "So'nggi {days} kunda {count} ta reysda jismonan imkonsiz masofa yoki motosoat "
              "(rejadagi muddatiga sutkasiga 1 500 km / 24 soatdan ko'p) — yig'indiga "
              "kirmadi. ATIL reyslarini tekshiring.",
        "ru": "За последние {days} дн. в {count} рейсах физически невозможный пробег или "
              "моточасы (больше 1 500 км / 24 ч в сутки на плановую длительность) — не учтены. "
              "Проверьте рейсы в ATIL.",
        "en": "In the last {days} days {count} trip(s) have a physically impossible distance "
              "or engine hours (over 1,500 km / 24 h a day of the planned duration) — "
              "excluded. Check ATIL trips.",
    },
    "note.manual_reading_conflict": {
        "uz": "{ref}: kiritilgan {value} mashinaning {day} dagi o'lchoviga ({reading}) zid — "
              "ko'rsatkich orqaga yurmaydi va sutkasiga {limit} dan ko'p oshmaydi. Yozuv "
              "saqlandi, lekin bu ko'rsatkich hisobga olinmaydi — tekshiring.",
        "ru": "{ref}: введённое значение {value} противоречит показанию от {day} ({reading}) — "
              "счётчик не идёт назад и не растёт больше чем на {limit} в сутки. Запись "
              "сохранена, но это показание не учитывается — проверьте.",
        "en": "{ref}: entered {value} contradicts the reading of {day} ({reading}) — a "
              "counter never goes back or grows more than {limit} a day. The record is "
              "saved, but this value is not used — please check.",
    },
    "word.this_record": {"uz": "Bu yozuv", "ru": "Эта запись", "en": "This record"},
    "note.passport_history_error": {
        "uz": "Qo'lda yozilgan tarix o'qilmadi ({error}) — faqat ATIL ma'lumoti ko'rsatildi.",
        "ru": "Ручная история не прочитана ({error}) — показаны только данные ATIL.",
        "en": "Manual history could not be read ({error}) — ATIL data only.",
    },
    "note.fleet_sources": {
        "uz": "Holat manbalari: ATIL ta'mirlari, qism so'rovlari, o'rnatilgan qismlar, texnik "
              "xizmat rejasi va qo'lda yozilgan voqealar. Tarixi yo'q qism — noma'lum.",
        "ru": "Источники: ремонты ATIL, заявки на детали, установленные детали, план ТО и "
              "ручные записи. Деталь без истории — неизвестно.",
        "en": "Sources: ATIL repairs, part requests, installed parts, maintenance plan and "
              "manual records. A part without history is unknown.",
    },

    # ------------------------------------------------------ Shablon xulosa
    "analysis.nothing": {
        "uz": "{requests} ta qism so'rovi va {parts} ta o'rnatilgan qism tekshirildi — "
              "shubhali holat topilmadi.",
        "ru": "Проверено {requests} заявок и {parts} установленных деталей — "
              "подозрительного не найдено.",
        "en": "{requests} part requests and {parts} installed parts checked — nothing "
              "suspicious found.",
    },
    "analysis.found": {
        "uz": "{requests} ta qism so'rovidan {flagged} tasida shubha bor: mashinaga mos "
              "kelmaydigan — {mismatch}, resursidan oldin — {early}, hisobsiz — {control}.",
        "ru": "Из {requests} заявок подозрительны {flagged}: не подходят машине — "
              "{mismatch}, раньше ресурса — {early}, не учтены — {control}.",
        "en": "{flagged} of {requests} requests are suspicious: wrong part for the "
              "vehicle — {mismatch}, before end of life — {early}, unaccounted — {control}.",
    },
    "analysis.installed": {
        "uz": "O'rnatilgan qismlardan {early} tasi resursidan oldin yeyilgan, {over} "
              "tasining resursi tugagan.",
        "ru": "Из установленных деталей {early} изношены раньше ресурса, у {over} "
              "ресурс исчерпан.",
        "en": "Of installed parts, {early} wore out early and {over} are past their life.",
    },
    "analysis.attention": {
        "uz": "DIQQAT: {note}", "ru": "ВНИМАНИЕ: {note}", "en": "NOTE: {note}",
    },
}

UNCHECKED_MARKERS = ("TEKSHIRILMADI", "НЕ ПРОВЕРЯЛ", "NOT CHECKED")


def is_unchecked(note: str) -> bool:
    upper = (note or "").upper()
    return any(marker in upper for marker in UNCHECKED_MARKERS)
