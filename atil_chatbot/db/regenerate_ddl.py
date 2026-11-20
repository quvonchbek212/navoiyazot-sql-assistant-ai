"""ddl.sql ni HAQIQIY bazadan qayta hosil qiladi.

ISHGA TUSHIRISH (loyiha ildizidan):
    venv/Scripts/python.exe atil_chatbot/db/regenerate_ddl.py

QACHON KERAK: baza sxemasi o'zgarganda (jadval/ustun qo'shilganda yoki
nomi almashganda). Skript FAQAT O'QIYDI — ulanish `read_only` rejimda
ochiladi, bazaga birorta yozuv amali bormaydi.

NIMA UCHUN KERAK (19.08.2026 tekshiruvi): `ddl.sql` qo'lda yuritilardi va
bazadan orqada qolgan edi — 10 ta mavjud bo'lmagan jadval, 8 ta mavjud
bo'lmagan ustun, va bazadagi 97 ta ustun faylda yo'q edi. Natijada model
`transport_vehicle.vehicle_inspection_v2_cleared_today` kabi ustunlarni
ishlatardi, tekshiruvchi (u ham shu faylga qaraydi) ularni o'tkazib
yuborardi, va so'rov faqat bazada yiqilardi.


Maqsad — model to'g'ri SQL yozishi. Shuning uchun faylga uch narsa albatta
kiradi:
  * ustunlar va turlari (aynan bazadagidek);
  * CHECK cheklovlari IXCHAM ko'rinishda — status/enum qiymatlari shu yerda,
    ularsiz model `status = 'faol'` kabi mavjud bo'lmagan qiymat yozadi;
  * FOREIGN KEY lar — model JOIN yo'lini shundan biladi.

Chiqarib tashlanadi: `read-user-atil` o'qiy olmaydigan jadvallar. Ular faylda
tursa model ularni ishlatadi va so'rov "нет доступа" bilan yiqiladi.

O'zbekcha izohlar saqlanadi — ular qo'lda yozilgan domen bilimi.
"""
import pathlib
import re
import sys

import psycopg2
import psycopg2.extras

sys.path.insert(0, str(pathlib.Path("atil_chatbot").resolve()))
from config import DB_HOST, DB_NAME, DB_PASSWORD, DB_PORT, DB_USER, DDL_PATH
from db.ddl_loader import load_tables

#: Sxema ko'chirishda nomi o'zgargan jadvallar — ustunlari 100% mos kelgani
#: bilan tasdiqlangan. Eski izoh yangi nomga ko'chiriladi.
QAYTA_NOMLANGAN = {
    "app_user_department": "user_department",
    "app_user_role": "user_role",
    "app_user_warehouse": "user_warehouse",
    "eimzo": "eimzo_signature",
    "payroll_rates": "payroll_rate",
}

#: IZOHLARDAGI ESKIRGAN NOMLAR.
#: Izohlar qo'lda yozilgani uchun ular ham sxema ko'chirishdan orqada qolgan:
#: `driver` izohi `assigned_vehicle_id` ni, `transport_vehicle` izohi
#: `vehicle_inspection_v2_cleared_today` ni ko'rsatardi — ikkalasi ham bazada
#: YO'Q. Izoh ham promptga tushadi, ya'ni model uni ustun deb qabul qiladi.
#: Nomlar bazadan tekshirib chiqilgan (19.08.2026).
IZOH_NOM = {
    "app_user_department": "user_department",
    "app_user_role": "user_role",
    "app_user_warehouse": "user_warehouse",
    "payroll_rates": "payroll_rate",
    "vehicle_maintenance_plan": "maintenance_plan",
    "vehicle_inspection_v2": "vehicle_technical_inspection",
    "document_audit_entry": "document_audit",
    "vehicle_fuel_sensor_install": "vehicle_fuel_sensor_installation",
}

#: Ustun butunlay o'chirilgan — iborani qayta yozamiz.
#: TARTIB MUHIM: uzunroq iboralar oldinda tursin, aks holda qisqasi ularning
#: ichini o'zgartirib yuboradi.
IZOH_IBORA = [
    # transport_vehicle: "bugungi texnik ko'rik" BAYROQ ustuni o'chirilgan,
    # o'rniga vehicle_technical_inspection jurnali qolgan.
    ("bugungi texnik ko'rikdan o'tgani\n(vehicle_inspection_v2_cleared_today).",
     "bugungi texnik ko'rik holati esa alohida vehicle_technical_inspection\n"
     "JURNALIDAN olinadi (transport_vehicle da bunday bayroq ustuni YO'Q)."),
    ("(vehicle_inspection_v2_cleared_today)", "(vehicle_technical_inspection jurnalidan)"),
    ("vehicle_inspection_v2_cleared_today", "vehicle_technical_inspection jurnali"),
    # driver: biriktirilgan mashina endi TESKARI yo'nalishda saqlanadi
    ("biriktirilgan mashina (assigned_vehicle_id)",
     "biriktirilgan mashina (transport_vehicle.assigned_driver_id orqali; "
     "ko'p-ko'pga esa vehicle_assigned_drivers jadvali)"),
    ("assigned_vehicle_id", "transport_vehicle.assigned_driver_id"),
    # fine da driver_id yo'q — haydovchi reys orqali topiladi
    ("fine.driver_id", "fine.trip_id -> trip.driver_id"),
    # document_audit ustunlari qayta nomlangan
    ("performed_at", "occurred_at"),
    ("performed_by", "actor"),
    # vehicle_technical_inspection: photos_json ustuni o'chirilgan,
    # rasmlar alohida jadvalda (u bazada bor — tekshirilgan)
    ("izohlar va rasmlar (photos_json).",
     "izohlar. Rasmlar ALOHIDA vehicle_technical_inspection_photo jadvalida."),
    ("photos_json", "vehicle_technical_inspection_photo jadvali"),
    # butunlay o'chirilganlar
    ("analytics_summary", "analytics_summary (BAZADAN O'CHIRILGAN)"),
    ("vehicle_fuel_type", "vehicle_reference_data_fuel_type"),
]


#: Butunlay olib tashlanadigan izoh QATORLARI.
#: "DIQQAT: `trips` jadvali ESKI sxemaga tegishli" kabi ogohlantirishlar
#: o'z vaqtida to'g'ri edi, lekin o'sha jadvallar bazadan BUTUNLAY o'chirilgan.
#: Endi bu qatorlar ikki tomonlama zararli: promptdan joy oladi va modelga
#: mavjud bo'lmagan jadval nomlarini eslatib, ularni "bor" deb o'ylashiga
#: turtki beradi. Markaziy ogohlantirish `_ATIL_RULES` da qoladi.
IZOH_OLIB_TASHLA = [
    re.compile(r"^.*DIQQAT:.*ESKI sxemaga tegishli.*$", re.M),
    re.compile(r"^.*ESKI \(LEGACY\) JADVAL.*$", re.M),
    re.compile(r"^.*YANGI SXEMADA HUJJAT AUDITI.*$", re.M),
    re.compile(r"^\s*document_audit JADVALIDAN OLINADI\.\s*$", re.M),
]


#: QO'LDA YOZILGAN izohlar — eski izoh noto'g'ri yoki umuman yo'q bo'lgan
#: jadvallar uchun. Hammasi bazadan tekshirilgan (19.08.2026).
IZOH_YANGI = {
    "document_audit": (
        "HUJJAT AUDITI — hujjat ustidagi amallar tarixi.\n"
        "action (amal), actor (kim bajargan), occurred_at (qachon),\n"
        "details (tafsilot), document_id (qaysi hujjat).\n"
        "DIQQAT: bu YAGONA hujjat audit jadvali. Ilgari `document_audit_entry`\n"
        "degan ikkinchi jadval bor edi — u bazadan o'chirilgan."
    ),
    "vehicle_assigned_drivers": (
        "MASHINA-HAYDOVCHI BIRIKTIRUVI (ko'p-ko'pga bog'lovchi jadval).\n"
        "Faqat ikki ustun: vehicle_id, driver_id.\n"
        "Bitta mashinaga bir nechta haydovchi biriktirilishi mumkin.\n"
        "ASOSIY (bitta) haydovchi esa transport_vehicle.assigned_driver_id da."
    ),
    "user_role": (
        "FOYDALANUVCHI ROLLARI (bog'lovchi jadval): user_id, role.\n"
        "Ilgari `app_user_role` deb atalardi."
    ),
}


def izohni_tuzat(matn: str) -> str:
    """Izohdagi eskirgan nomlarni bazadagi haqiqiy nomlarga almashtiradi.

    Izoh ham promptga tushadi — model uni ustun/jadval nomi deb qabul qiladi.
    Shuning uchun izoh ham DDL kabi bazaga mos bo'lishi shart.
    """
    for naqsh in IZOH_OLIB_TASHLA:
        matn = naqsh.sub("", matn)
    for eski, yangi in IZOH_IBORA:
        matn = matn.replace(eski, yangi)
    for eski, yangi in IZOH_NOM.items():
        matn = re.sub(rf"\b{re.escape(eski)}\b", yangi, matn)
    # olib tashlangan qatorlardan qolgan bo'sh joylarni yig'ishtiramiz
    matn = re.sub(r"\n{2,}", "\n", matn)
    return matn.strip()


conn = psycopg2.connect(
    host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER, password=DB_PASSWORD,
    connect_timeout=10,
    options="-c default_transaction_read_only=on -c statement_timeout=30000",
)
conn.set_session(readonly=True)
cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

# --- Jadvallar: faqat O'QISH MUMKIN bo'lganlari ---
cur.execute("""
    SELECT c.oid, c.relname AS tbl, c.relkind
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind IN ('r','p','v','f')
      AND has_table_privilege(c.oid, 'SELECT')
    ORDER BY c.relname
""")
relations = list(cur.fetchall())
jadvallar = [r["tbl"] for r in relations]
relation_names = {r['oid']:r['tbl'] for r in relations}
relation_kinds = {r['tbl']:r['relkind'] for r in relations}
relation_ids = list(relation_names)

cur.execute("""
    SELECT a.attrelid AS relation_id, a.attname AS col,
           format_type(a.atttypid, a.atttypmod) AS typ, a.attnotnull AS nn, a.attnum
    FROM pg_attribute a
    WHERE a.attrelid = ANY(%s::oid[])
      AND a.attnum > 0 AND NOT a.attisdropped
    ORDER BY a.attrelid, a.attnum
""", (relation_ids,))
ustunlar = {}
for r in cur.fetchall():
    r['tbl'] = relation_names[r['relation_id']]
    ustunlar.setdefault(r["tbl"], []).append(r)

cur.execute("""
    SELECT con.conrelid AS relation_id, con.contype, pg_get_constraintdef(con.oid) AS def
    FROM pg_constraint con
    WHERE con.conrelid = ANY(%s::oid[]) AND con.contype IN ('p','f','c')
    ORDER BY con.conrelid, con.contype, con.conname
""", (relation_ids,))
cheklovlar = {}
for r in cur.fetchall():
    r['tbl'] = relation_names[r['relation_id']]
    cheklovlar.setdefault(r["tbl"], []).append(r)
# DIQQAT: ulanish shu yerda YOPILMAYDI — quyida enum ustunlarining haqiqiy
# taqsimoti o'qiladi. U `qisqa_check` dan keyin turadi, chunki ustun nomi
# aynan o'sha regexdan olinadi.


def qisqa_tur(t: str) -> str:
    """Turni qisqa, o'qishga qulay ko'rinishga keltiradi (prompt kichrayadi)."""
    t = t.replace("character varying", "varchar").replace("character(", "char(")
    t = re.sub(r"timestamp\(\d+\) with time zone", "timestamptz", t)
    t = re.sub(r"timestamp with time zone", "timestamptz", t)
    t = re.sub(r"timestamp\(\d+\) without time zone", "timestamp", t)
    t = re.sub(r"timestamp without time zone", "timestamp", t)
    t = t.replace("double precision", "float8")
    t = re.sub(r"numeric\((\d+),\s*(\d+)\)", r"numeric(\1,\2)", t)
    return t


_ANY_RE = re.compile(
    r"CHECK\s*\(+\s*\(?(?P<col>\w+)\)?(?:::text)?\s*=\s*ANY\s*\(+\s*ARRAY\s*\[(?P<vals>.*?)\]",
    re.S,
)
_LIT_RE = re.compile(r"'([^']*)'")


def qisqa_check(d: str) -> str:
    """`= ANY (ARRAY[...])` ni `in (...)` ga aylantiradi.

    Nima uchun: asl ko'rinish bitta status ustuni uchun ~40 token yeydi
    (`((status)::text = ANY ((ARRAY['DRAFT'::character varying, ...])::text[]))`),
    ixcham ko'rinish esa ~12. Qiymatlarning O'ZI saqlanadi — model uchun
    eng qimmatli ma'lumot shu.
    """
    m = _ANY_RE.search(d)
    if m:
        vals = _LIT_RE.findall(m.group("vals"))
        if vals:
            return f"check ({m.group('col')} in ({', '.join(repr(v) for v in vals)}))"
    d = re.sub(r"::(text|character varying|numeric|integer|bigint)\b", "", d)
    d = re.sub(r"\s+", " ", d).strip()
    return d.lower() if d.upper().startswith("CHECK") else d


# --- Enum ustunlarining HAQIQIY taqsimoti ---
#
# NIMA UCHUN (29.08.2026 o'lchovi): `check (...)` faqat RUXSAT ETILGAN
# qiymatlarni beradi, bazada qaysi biri HAQIQATDA uchrashini emas. Savol
# "rejadagi operatsiyalar nechta?" bo'lganda model `trip.status = 'PLANNED'`
# ni tanladi (u ro'yxatda BIRINCHI turadi) va "0" javobini oldi. Son
# to'g'ri edi, xulosa esa noto'g'ri: bazada `PLANNED` HECH QACHON
# ishlatilmaydi, tugallanmagan reyslar ASSIGNED (16) va STARTED (8)
# holatida turibdi. Foydalanuvchi "0" ni ko'rib "rejada ish yo'q" deb
# tushunadi va izlashni to'xtatadi.
#
# Endi har enum ustuni yoniga haqiqiy taqsimot yoziladi.
_ISHLATILMAGAN_LIMIT = 8


def _enum_taqsimoti(jadval: str, ustun: str, ruxsat: list) -> str:
    """Bitta enum ustuni bo'yicha izoh qatori (bo'lmasa bo'sh satr)."""
    try:
        cur.execute(
            'SELECT "' + ustun + '" AS q, count(*) AS n FROM public."'
            + jadval + '" GROUP BY 1 ORDER BY 2 DESC'
        )
        qatorlar = cur.fetchall()
    except psycopg2.Error:
        conn.rollback()
        return ""

    bor = [(str(r["q"]), r["n"]) for r in qatorlar if r["q"] is not None and r["n"]]
    bosh = sum(1 for r in qatorlar if r["q"] is None)
    nol = [v for v in ruxsat if v not in {q for q, _ in bor}]

    if not bor and not bosh:
        return "    -- " + ustun + " BAZADA: jadval bo'sh"

    qismlar = [", ".join(q + " " + str(n) for q, n in bor)] if bor else ["yo'q"]
    if bosh:
        qismlar.append("NULL " + str(bosh))
    satr = "    -- " + ustun + " BAZADA: " + "; ".join(qismlar)
    if nol:
        korsatiladi = nol[:_ISHLATILMAGAN_LIMIT]
        qolgan = "" if len(nol) <= _ISHLATILMAGAN_LIMIT else (
            " va yana " + str(len(nol) - _ISHLATILMAGAN_LIMIT) + " ta")
        satr += " | ISHLATILMAGAN: " + ", ".join(korsatiladi) + qolgan
    return satr


def enum_ustuni(check_def: str):
    """`check (col in (...))` dan (ustun, qiymatlar) ni ajratadi."""
    m = _ANY_RE.search(check_def)
    if not m:
        return None
    vals = _LIT_RE.findall(m.group("vals"))
    return (m.group("col"), vals) if vals else None


# --- Eski izohlar (fayl qayta yozilishidan OLDIN o'qiladi) ---
eski = load_tables()
izohlar = {n: str(i.get("description") or "") for n, i in eski.items()}
for eski_nom, yangi_nom in QAYTA_NOMLANGAN.items():
    if izohlar.get(eski_nom) and not izohlar.get(yangi_nom):
        izohlar[yangi_nom] = (
            izohlar[eski_nom]
            + f"\n(Ilgari `{eski_nom}` deb atalardi — sxema ko'chirishda nomi o'zgargan.)"
        )

CHIZIQ = "-- " + "-" * 69
BOSH = """\
-- =====================================================================
-- ATIL BAZASI — DDL   (AVTOMATIK HOSIL QILINGAN)
-- =====================================================================
-- Bu fayl haqiqiy bazadan (pg_catalog) hosil qilingan. QO'LDA USTUN
-- QO'SHMANG — baza o'zgarganda fayl qaytadan hosil qilinadi va qo'lda
-- kiritilgan o'zgarish yo'qoladi.
--
-- Chatbot bazani AYNAN shu fayl orqali "ko'radi": model shundan SQL yozadi
-- va `execute_sql` dagi jadval/ustun tekshiruvchisi ham shunga qaraydi.
-- Fayl bazadan orqada qolsa, xato SQL tekshiruvdan o'tib ketadi va faqat
-- bazada yiqiladi — foydalanuvchi esa buni "ma'lumot yo'q" deb tushunadi.
--
-- Faylga FAQAT `read-user-atil` o'qiy oladigan jadvallar kiradi.
--
-- Har jadvalda saqlanadi:
--   * ustunlar va turlari — bazadagidek;
--   * check (...) — status/tur ustunlarining RUXSAT ETILGAN QIYMATLARI;
--   * `-- <ustun> BAZADA:` — o'sha qiymatlardan qaysi biri HAQIQATDA
--     uchrashi va nechtadan. `ISHLATILMAGAN:` dagi qiymatlar bazada YO'Q —
--     ularni WHERE shartida ishlatmang, natija doim bo'sh chiqadi;
--   * foreign key — JOIN yo'llari.
--
-- Jadval USTIDAGI `-- ` izohlari qo'lda yozilgan domen bilimi bo'lib, qayta
-- hosil qilishda saqlanadi. Yangi izohni jadval ustiga yozing.
-- =====================================================================

"""

qismlar = [BOSH]
statistika = {"jadval": 0, "ustun": 0, "check": 0, "fk": 0, "izoh": 0, "taqsimot": 0}

for jadval in jadvallar:
    izoh = IZOH_YANGI.get(jadval) or izohni_tuzat(izohlar.get(jadval, "").strip())
    if relation_kinds[jadval] in ('v','f'):
        # This file is a read-model description for the SQL assistant, never a migration.
        kind = 'READ-ONLY VIEW' if relation_kinds[jadval]=='v' else 'FOREIGN TABLE'
        prefix=f'{kind}: ustunlar SELECT uchun jadval shaklida tasvirlangan.'
        while izoh.startswith(prefix):izoh=izoh[len(prefix):].lstrip()
        izoh=prefix+('\n'+izoh if izoh else '')
    if izoh:
        statistika["izoh"] += 1
        qismlar.append(CHIZIQ)
        qismlar += [f"-- {q}".rstrip() for q in izoh.splitlines()]
        qismlar.append(CHIZIQ)

    kols = ustunlar[jadval]
    kenglik = max(len(c["col"]) for c in kols) + 1
    qatorlar = [
        f"    {c['col']:<{kenglik}} {qisqa_tur(c['typ'])}{' not null' if c['nn'] else ''}"
        for c in kols
    ]
    statistika["ustun"] += len(kols)

    pk = [c for c in cheklovlar.get(jadval, []) if c["contype"] == "p"]
    ck = [c for c in cheklovlar.get(jadval, []) if c["contype"] == "c"]
    fk = [c for c in cheklovlar.get(jadval, []) if c["contype"] == "f"]
    for c in pk:
        qatorlar.append("    " + c["def"].lower())
    distributed=set()
    for c in ck:
        qatorlar.append("    " + qisqa_check(c["def"]))
        statistika["check"] += 1
        # Ruxsat etilgan qiymatlar yonida HAQIQIY taqsimot ham tursin
        enum = enum_ustuni(c["def"])
        if enum:
            distributed.add(enum[0])
            satr = _enum_taqsimoti(jadval, enum[0], enum[1])
            if satr:
                qatorlar.append(satr)
                statistika["taqsimot"] += 1
    # Some current status columns have no enum CHECK. Keep their observed
    # values without inventing a database constraint or claiming exhaustiveness.
    for column in ('status','current_status'):
        if column not in distributed and any(c['col']==column for c in kols):
            satr=_enum_taqsimoti(jadval,column,[])
            if satr:
                qatorlar.append(satr)
                statistika['taqsimot']+=1
    for c in fk:
        d = re.sub(r"\s+", " ", c["def"]).lower()
        qatorlar.append("    " + d)
        statistika["fk"] += 1

    # Vergul FAQAT haqiqiy ta'riflar orasiga qo'yiladi. Izoh qatoriga
    # vergul tushsa u izoh ICHIDA qolib ketadi va DDL sintaksisi buziladi
    # (`check (...)` dan keyingi vergul yo'qoladi).
    oxirgi = max(
        (i for i, q in enumerate(qatorlar) if not q.lstrip().startswith("--")),
        default=-1,
    )
    tana = [
        q if (q.lstrip().startswith("--") or i >= oxirgi) else q + ","
        for i, q in enumerate(qatorlar)
    ]
    qismlar += [f"create table {jadval}", "(", "\n".join(tana), ");", ""]
    statistika["jadval"] += 1

conn.close()

matn = "\n".join(qismlar)
pathlib.Path(DDL_PATH).write_text(matn, encoding="utf-8")
print(f"yozildi: {DDL_PATH}")
print(f"  jadval {statistika['jadval']} | ustun {statistika['ustun']} | "
      f"check {statistika['check']} | foreign key {statistika['fk']} | "
      f"izohi saqlangan {statistika['izoh']} | taqsimot {statistika['taqsimot']}")
print(f"  hajm: {len(matn):,} belgi ({len(matn.splitlines()):,} qator)")
