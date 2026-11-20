"""Savoldagi identifikatorni BAZADAN topish — taxmin qilmasdan.

MUAMMO
Foydalanuvchi "DOC000030 hujjat haqida ma'lumot ber" desa, model qaysi jadvalda
qidirishni TAXMIN qiladi va ko'pincha yanglishadi: DOC000030 aslida
`transport_document.document_number` da, model esa `vehicle_document` dan
qidirib "topilmadi" deb javob beradi — yolg'on salbiy natija.

Prefiks bo'yicha xarita ham yetarli emas, chunki prefikslar NOYOB EMAS:
    DOC -> transport_document.document_number (35 qator)
        -> vehicle_document.document_number    (2 qator)
    TRP -> trip.trip_number / route.planned_trip_number
    DRV -> driver.employee_id / medical_inspection.employee_id

YECHIM
Qiymatning O'ZINI bazadan qidiramiz. Bu deterministik: qaysi jadvalda
haqiqatan bor bo'lsa, o'sha qaytadi. Tezlik uchun avval prefiks bo'yicha
nomzod ustunlar toraytiriladi (54 tadan 1-2 taga).

XAVFSIZLIK
Qidiruv qiymati parametr sifatida uzatiladi (SQL ichiga qo'shilmaydi), ustun va
jadval nomlari esa faqat pg_catalog dan olingan oq ro'yxatdan keladi.
"""

from __future__ import annotations

import logging
import re
import time
import threading
from dataclasses import dataclass

import psycopg2

from .connect_db_for_server import read_only_cursor
from .ddl_loader import table_names
from .schema import live_columns

logger = logging.getLogger(__name__)

#: Savol matnidagi identifikatorga o'xshash tokenlar: DOC000030, TRQ-30, WB000016
#:
#: 02.09.2026: prefiks {2,6} EDI va bir harfli prefiksni tashlab yuborardi —
#: `R-000004` (reys raqami) shu sababli hech qachon aniqlanmagan.
TOKEN_RE = re.compile(r"\b([A-Za-z]{1,6}[-_]?\d{2,})\b")

#: DAVLAT RAQAMI — TOKEN_RE ga TUSHMAYDI, chunki u teskari tartibda:
#: avval RAQAM, keyin HARF (85116EBA), TOKEN_RE esa harf+raqam qidiradi.
#:
#: NIMA UCHUN QO'SHILDI (02.09.2026): "85116eba raqamli transport haqida
#: ma'lumot ber" savoliga bot "topilmadi" dedi, holbuki mashina bazada bor.
#: Aniqlagich raqamni ko'rmagani uchun modelga ishora bermadi, model esa
#: ustunni O'ZI tanladi va `ref_id` ga urdi — u haqiqiy ustun (shuning uchun
#: tekshiruv o'tkazib yubordi), lekin unda ERP raqami turadi
#: (`8100000000000083`), davlat raqami emas.
#:
#: SHAKL BAZADAN OLINGAN, o'ylab topilmagan (02.09.2026 o'lchovi):
#:     99999AAA -> 109 ta,  99999AA -> 17 ta,  boshqa -> 1 ta ("BN", axlat)
#: Ya'ni 5 raqam + 2-3 harf. Chegara bir oz kengroq olindi (4-6 raqam,
#: 1-4 harf), chunki noto'g'ri topilgan token ZARARSIZ — u baribir bazadan
#: TEKSHIRILADI va topilmasa tashlab yuboriladi.
PLATE_RE = re.compile(r"\b(\d{2}[ \t]*[A-Za-z][ \t]*\d{3}[ \t]*[A-Za-z]{1,2}|\d{2}[ \t]+\d{3}[ \t]*[A-Za-z]{2,3}|\d{4,6}[A-Za-z]{1,4})\b")

#: SOF RAQAMLI identifikator: `010-00119`, `001-00033`.
#:
#: NIMA UCHUN ALOHIDA (02.09.2026): "010-00119 so'rov haqida ma'lumot ber?"
#: savolidagi raqam na `TOKEN_RE` ga (u harf bilan boshlanishni talab qiladi),
#: na `PLATE_RE` ga (u harf bilan tugashni talab qiladi) tushardi. Natijada
#: aniqlagich jim qolardi va model qaysi jadvaldan qidirishni O'ZI taxmin
#: qilardi — aynan shu modul bartaraf qilishi kerak bo'lgan holat.
#:
#: SHAKL BAZADAN (02.09.2026, `transport_request.request_number`):
#:     999-99999 -> 79 ta   (010-00119, 001-00033)
#: Qolgan shakllar harf bilan boshlanadi va `TOKEN_RE` ularni oladi.
#:
#: SOF RAQAM (ajratgichsiz, masalan `00016786`) ATAYLAB OLINMAYDI: savoldagi
#: HAR QANDAY son — miqdor, yil, kun soni — identifikator deb qabul qilinib,
#: har biriga bazaga so'rov ketardi. Ajratgich esa uni miqdordan ajratadi.
NUMERIC_ID_RE = re.compile(r"\b(\d{2,6}-\d{3,8})\b")

#: Identifikator saqlashi mumkin bo'lgan ustun nomlari
_COLUMN_HINTS = ("number", "code", "employee_id", "ref_id", "garage_number", "vin")

_candidates: dict[str, list[tuple[str, str]]] | None = None
_all_candidates: list[tuple[str, str]] = []
_lock = threading.Lock()

#: Baza uzilganda xaritani har savolda qayta yuklashga urinmaymiz — har urinish
#: 5 soniya kutadi. Muvaffaqiyatsizlik shu muddatga eslab qolinadi.
_FAILURE_COOLDOWN_SECONDS = 60.0
_retry_after: float = 0.0


@dataclass(frozen=True, slots=True)
class IdentifierHit:
    token: str
    table: str
    column: str
    rows: int
    #: Bazada SAQLANGAN shakl. `token` foydalanuvchi yozgani bo'lib,
    #: harflari boshqacha bo'lishi mumkin ("85116eba" -> "85116EBA").
    #: Promptga AYNAN SHU qiymat qo'yiladi, aks holda model ishoradagi
    #: query'ni ko'chiradi va u nol qator qaytaradi.
    value: str = ""


def _load_candidates() -> tuple[dict[str, list[tuple[str, str]]], list[tuple[str, str]]]:
    """Prefiks -> [(jadval, ustun)] xaritasini bazadan quradi (bir marta)."""
    global _candidates, _all_candidates
    with _lock:
        if _candidates is not None:
            return _candidates, _all_candidates

        allowed = table_names()
        columns: list[tuple[str, str]] = []
        for row in live_columns(text_only=True):
            table, column = row["table_name"], row["column_name"]
            if table not in allowed:
                continue
            if any(hint in column for hint in _COLUMN_HINTS):
                columns.append((table, column))

        prefixes: dict[str, list[tuple[str, str]]] = {}
        with read_only_cursor() as cur:
            for table, column in columns:
                try:
                    cur.execute(
                        f'SELECT DISTINCT upper(substring("{column}" from \'^[A-Za-z]+\')) AS p '
                        f'FROM public."{table}" '
                        f"WHERE \"{column}\" ~ '^[A-Za-z]{{1,6}}[-_]?[0-9]{{2,}}$'"
                    )
                    for row in cur.fetchall():
                        if row["p"]:
                            prefixes.setdefault(row["p"], []).append((table, column))
                except psycopg2.Error:
                    cur.connection.rollback()
                    continue

        _candidates, _all_candidates = prefixes, columns
        logger.info(
            "Identifikator xaritasi tayyor: %d prefiks, %d ustun",
            len(prefixes), len(columns),
        )
        return _candidates, _all_candidates


def resolve(question: str, *, max_tokens: int = 3) -> list[IdentifierHit]:
    """Savoldagi identifikatorlar qaysi jadvalda ekanini aniqlaydi."""
    matn = question or ""
    # Tartib muhim: davlat raqami avval kelsin — u aniqroq shakl.
    tokens = list(dict.fromkeys(
        PLATE_RE.findall(matn) + NUMERIC_ID_RE.findall(matn) + TOKEN_RE.findall(matn)
    ))[:max_tokens]
    if not tokens:
        return []

    global _retry_after
    if time.monotonic() < _retry_after:
        return []

    try:
        prefixes, all_columns = _load_candidates()
    except Exception as exc:  # noqa: BLE001 — bazaga ulanmasa jimgina o'tamiz
        _retry_after = time.monotonic() + _FAILURE_COOLDOWN_SECONDS
        logger.warning(
            "Identifikator xaritasi yuklanmadi (%.0fs qayta urinilmaydi): %s",
            _FAILURE_COOLDOWN_SECONDS, str(exc)[:110],
        )
        return []

    hits: list[IdentifierHit] = []
    for token in tokens:
        if NUMERIC_ID_RE.fullmatch(token):
            # Harf prefiksi yo'q — prefiks xaritasi yordam bermaydi.
            # Nomida "number" bo'lgan ustunlar avval ko'riladi.
            columns = [c for c in all_columns if "number" in c[1]] or all_columns
        elif PLATE_RE.fullmatch(token):
            # Davlat raqamida harf prefiksi yo'q, ya'ni prefiks xaritasi
            # yordam bermaydi va qidiruv 54 ta ustunga tarqalib ketardi.
            # Nomida "plate" bo'lgan ustunlar avval ko'riladi.
            columns = [c for c in all_columns if "plate" in c[1]] or all_columns
        else:
            prefix_match = re.match(r"^([A-Za-z]+)", token)
            prefix = prefix_match.group(1).upper() if prefix_match else ""
            # Avval prefiksga mos ustunlar; topilmasa hammasini ko'ramiz
            columns = prefixes.get(prefix) or all_columns

        try:
            with read_only_cursor() as cur:
                for table, column in columns:
                    try:
                        # HARFGA BEFARQ. Foydalanuvchi "85116eba" deb yozadi,
                        # bazada esa "85116EBA" turadi — `=` bilan nol qator
                        # qaytardi va bot "topilmadi" derdi (02.09.2026).
                        # `min()` bazadagi shaklni qaytaradi: promptga xuddi
                        # shu qiymat qo'yiladi, foydalanuvchi yozgani emas.
                        comparison=(f"regexp_replace(upper(\"{column}\"), '[[:space:]]', '', 'g') = "
                                    "regexp_replace(upper(%s), '[[:space:]]', '', 'g')"
                                    if 'plate' in column and PLATE_RE.fullmatch(token)
                                    else f'upper("{column}") = upper(%s)')
                        cur.execute(
                            f'SELECT min("{column}") AS v, count(*) AS n '
                            f'FROM public."{table}" '
                            f'WHERE {comparison}',
                            (token,),
                        )
                        row = cur.fetchone() or {}
                        count = row.get("n") or 0
                        if count:
                            hits.append(IdentifierHit(
                                token, table, column, count, row.get("v") or token
                            ))
                    except psycopg2.Error:
                        cur.connection.rollback()
                        continue
        except Exception as exc:  # noqa: BLE001
            logger.warning("Identifikator qidiruvi bajarilmadi: %s", str(exc)[:120])
            break

    return hits


#: Ism/atoqli otga o'xshash tokenlar: bosh harf bilan boshlanadigan so'zlar
_NAME_TOKEN_RE = re.compile(r"\b([A-ZА-ЯЎҚҒҲ][\w'`ʼ’-]{2,})\b", re.UNICODE)

#: Bosh harf topilmaganda ishlatiladigan zaxira: har qanday so'z.
#: Foydalanuvchi ismni kichik harfda yozishi juda keng tarqalgan
#: ("islomjon begaliyev qaysi transportdan foydalanadi?") — bunday savolda
#: yuqoridagi regex hech narsa topmaydi va jadval tanlash tasodifiy bo'lib
#: qoladi. Aniqlikni yo'qotmaslik uchun bu faqat ZAXIRA yo'l.
_ANY_TOKEN_RE = re.compile(r"\b([\w'`ʼ’-]{4,})\b", re.UNICODE)

#: Bazada apostrof IKKI XIL yozilgan: `o‘g‘li` (U+2018) va `o'g'li` (ASCII).
#: 01.09.2026 o'lchovi: 206 haydovchidan 25 tasida egri, 47 tasida oddiy
#: apostrof. Solishtirishdan oldin hammasi bitta ko'rinishga keltiriladi —
#: aks holda quyidagi ro'yxatdagi so'z tokenga mos kelmay qoladi.
_APOSTROPHES = str.maketrans({"‘": "'", "’": "'", "ʼ": "'", "`": "'", "´": "'"})


def _normalize(token: str) -> str:
    return token.lower().translate(_APOSTROPHES)


#: Ism deb qabul qilinmaydigan bosh harfli so'zlar (savol boshidagi so'zlar,
#: domen atamalari, oylar va h.k.).
_NOT_A_NAME = frozenset(_normalize(w) for w in """
Nechta Necha Qancha Qaysi Qanday Qayerda Qachon Kim Nima Bugun Kecha Ertaga
Menga Bering Ber Ayt Aytib Korsat Ko'rsat Chiqar Top Toping Tekshir Salom
Mashina Mashinalar Transport Haydovchi Haydovchilar Reys Reyslar Marshrut
Hujjat Hujjatlar Sorov So'rov Ariza Arizalar Yuk Yoqilgi Yoqilg'i Sugurta
Sug'urta Jarima Hodisa Smena Ombor Tarif Mijoz Bolim Bo'lim Filial
Tizim Tizimda Baza Jami Barcha Hamma Royxat Ro'yxat Malumot Ma'lumot
Kerak Bor Yoq Yo'q Bormi Mavjud Holati Soni Sonini Turi Nomi Raqami
Yanvar Fevral Mart Aprel May Iyun Iyul Avgust Sentabr Oktabr Noyabr Dekabr
Who What Where When Which Show List Give Tell Find Check Count Total All
Hello Vehicle Driver Trip Route Document Request Fuel Insurance Info
Кто Что Где Когда Какие Сколько Покажи Список Информация Данные
""".split())

#: Otasining ismi qo'shimchasi — ismning o'zi emas. 01.09.2026: bosh harf
#: bilan yozilganda ("... Olim O'g'li") ular ism deb qabul qilinardi va OR
#: sharti butun jadvalni tortardi — bitta savolga 34 ta haydovchi chiqardi.
#: Quyidagi STEMS ga QO'SHILMAYDI, faqat to'liq tenglik bo'yicha rad etiladi:
#: stem bo'lganda "Qizilov" kabi HAQIQIY familiya ham tushib qolardi.
_PATRONYMIC = frozenset(
    _normalize(w) for w in "O'g'li Ogli O'gli Oglu Ugli Qizi Kizi".split()
)
_NOT_A_NAME = _NOT_A_NAME | _PATRONYMIC


#: O'zbekchada so'zga qo'shimcha yopishadi ("transportdan", "mashinalarni",
#: "haydovchining"). Shuning uchun to'liq tenglik yetarli emas — domen so'zi
#: tokenning BOSHIDA turgan bo'lsa ham uni ism deb qabul qilmaymiz.
_NOT_A_NAME_STEMS = tuple(
    sorted((w for w in _NOT_A_NAME - _PATRONYMIC if len(w) >= 4), key=len)
)


def _looks_like_name(token: str) -> bool:
    low = _normalize(token)
    if low in _NOT_A_NAME:
        return False
    return not any(low.startswith(stem) for stem in _NOT_A_NAME_STEMS)


def _name_tokens(question: str, max_tokens: int) -> list[str]:
    """Savoldan ism nomzodlarini ajratadi.

    Avval bosh harfli so'zlar (aniqroq). Ular topilmasa — barcha so'zlar
    zaxira sifatida, domen atamalari va qo'shimchali shakllari chiqarilgan
    holda. Zaxira yo'lda ortiqcha token tushib qolishi mumkin, ammo u
    bazadan 0 qator qaytaradi va natijaga ta'sir qilmaydi.
    """
    text = question or ""
    tokens = [
        t for t in dict.fromkeys(_NAME_TOKEN_RE.findall(text))
        if _looks_like_name(t)
    ]
    if tokens:
        return tokens[:max_tokens]
    return [
        t for t in dict.fromkeys(_ANY_TOKEN_RE.findall(text))
        if _looks_like_name(t) and not t.isdigit()
    ][:max_tokens]


@dataclass(frozen=True, slots=True)
class NameHit:
    token: str
    table: str
    column: str
    rows: int
    #: Bazadagi haqiqiy qiymatlar (namuna)
    samples: tuple[str, ...] = ()
    #: Bo'laklarning HAMMASI bitta qatorda uchragan qatorlar soni va namunasi
    all_rows: int = 0
    all_sample: str = ""
    #: `all_rows` qaysi bo'laklar bo'yicha hisoblangani (shu ustunda uchraganlari)
    and_tokens: tuple[str, ...] = ()


def _name_columns() -> list[tuple[str, str]]:
    """Ism saqlashi mumkin bo'lgan ustunlar (bir marta yuklanadi)."""
    allowed = table_names()
    columns: list[tuple[str, str]] = []
    for row in live_columns(text_only=True):
        table, column = row["table_name"], row["column_name"]
        if table in allowed and (
            "name" in column or "actor" in column or column.endswith("_by")
        ):
            columns.append((table, column))
    return columns


_name_cols: list[tuple[str, str]] | None = None


def _matching_tokens(cur, table: str, column: str, tokens: list[str]) -> set[str]:
    """Ustunda qaysi tokenlar HAQIQATAN uchraganini bitta so'rov bilan aniqlaydi."""
    selects = ", ".join(
        f'count(*) FILTER (WHERE "{column}" ILIKE %s) AS t{i}'
        for i in range(len(tokens))
    )
    cur.execute(
        f'SELECT {selects} FROM public."{table}"',
        tuple(f"%{t}%" for t in tokens),
    )
    row = cur.fetchone() or {}
    return {t for i, t in enumerate(tokens) if row.get(f"t{i}")}


#: PostgreSQL so'z chegarasi (`\y`) — f-string ichida qochirilmasin.
_WB = r"\y"


def _all_tokens_together(
    cur, table: str, column: str, tokens: tuple[str, ...]
) -> tuple[int, str]:
    r"""Bo'laklarning HAMMASI bitta qatorda uchraydimi — soni va namunasi.

    Shart modelga beriladigan SQL bilan AYNAN bir xil bo'lishi kerak
    (`~* '\y...\y'`), ILIKE bilan emas: ILIKE '%ali%' 'Begaliyev' ni ham
    topadi, `\yali\y` esa yo'q. Aks holda bu yerda "bor" deb sanalgan qator
    model yozgan SQL'da chiqmay qoladi va bot "topilmadi" deb javob beradi.
    """
    if not tokens:
        return 0, ""
    condition = " AND ".join(
        [f"\"{column}\" ~* ('{_WB}' || %s || '{_WB}')"] * len(tokens)
    )
    cur.execute(
        f'SELECT count(*) AS n, min("{column}") AS sample '
        f'FROM public."{table}" WHERE {condition}',
        tuple(t.lower() for t in tokens),
    )
    row = cur.fetchone() or {}
    return int(row.get("n") or 0), str(row.get("sample") or "")


#: Bitta savol ichida resolve_names ikki marta chaqiriladi (jadval tanlashda
#: va SQL tuzishda). Natija o'zgarmaydi — 51 ta ustun bo'yicha qidiruvni
#: takrorlash ~0.7 s ni behuda sarflaydi.
_name_cache: dict[str, list[NameHit]] = {}
_name_cache_lock = threading.Lock()


def resolve_names(question: str, *, max_tokens: int = 4) -> list[NameHit]:
    key = (question or "").strip().lower()
    with _name_cache_lock:
        if key in _name_cache:
            return _name_cache[key]

    hits = _resolve_names_uncached(question, max_tokens=max_tokens)

    # XATONI KESHLAMAYMIZ. Baza vaqtincha uzilsa (tashqi serverdagi ma'lum
    # muammo) qidiruv bo'sh qaytadi — o'shani keshlab qo'ysak, baza tiklangandan
    # keyin ham AYNAN SHU savol boshqa hech qachon ism topa olmaydi.
    if hits is None:
        return []

    with _name_cache_lock:
        if len(_name_cache) > 256:
            _name_cache.clear()
        _name_cache[key] = hits
    return hits


def _resolve_names_uncached(question: str, *, max_tokens: int = 4) -> list[NameHit] | None:
    """Savoldagi ism bazaning qaysi jadvalida ekanini topadi.

    Nima uchun kerak (31.07.2026): "Bekzod Aliyev bo'yicha malumot kerak"
    savolida qoidalarga tushadigan birorta kalit so'z yo'q — faqat ism.
    Natijada jadval tanlash tasodifiy bo'lib qolgan (`position_log`,
    `document_version`) va bot "qamrovimda driver jadvali yo'q" degan
    NOTO'G'RI sabab bilan rad javob bergan.
    """
    global _name_cols

    tokens = _name_tokens(question, max_tokens)
    if not tokens:
        return []

    if time.monotonic() < _retry_after:
        return None  # baza uzilgan — xato, "ism yo'q" emas

    try:
        if _name_cols is None:
            _name_cols = _name_columns()
        columns = _name_cols
    except Exception as exc:  # noqa: BLE001
        logger.warning("Ism ustunlari yuklanmadi: %s", str(exc)[:110])
        return None

    hits: list[NameHit] = []
    matched: set[str] = set()
    try:
        with read_only_cursor() as cur:
            for table, column in columns:
                try:
                    conditions = " OR ".join([f'"{column}" ILIKE %s'] * len(tokens))
                    params = tuple(f"%{t}%" for t in tokens)
                    cur.execute(
                        f'SELECT count(*) AS n, min("{column}") AS sample '
                        f'FROM public."{table}" WHERE {conditions}',
                        params,
                    )
                    row = cur.fetchone() or {}
                    if row.get("n"):
                        col_tokens = _matching_tokens(cur, table, column, tokens)
                        matched.update(col_tokens)
                        # AND FAQAT shu ustunda uchragan bo'laklar bo'yicha:
                        # umuman uchramagan bo'lak (zaxira yo'ldagi ortiqcha
                        # so'z) qo'shilsa natija har doim 0 chiqadi.
                        ordered = tuple(t for t in tokens if t in col_tokens)
                        all_rows, all_sample = _all_tokens_together(
                            cur, table, column, ordered
                        )
                        hits.append(
                            NameHit(
                                token="",  # quyida haqiqiy moslar bilan to'ldiriladi
                                table=table,
                                column=column,
                                rows=row["n"],
                                samples=(str(row.get("sample") or ""),),
                                all_rows=all_rows,
                                all_sample=all_sample,
                                and_tokens=ordered,
                            )
                        )
                except psycopg2.Error:
                    cur.connection.rollback()
                    continue
    except Exception as exc:  # noqa: BLE001
        logger.warning("Ism qidiruvi bajarilmadi: %s", str(exc)[:110])
        return None

    # Promptga FAQAT bazada haqiqatan uchragan bo'laklar tushsin. Zaxira
    # yo'lda ("qaysi transportdan foydalanadi") ortiqcha so'zlar ham
    # nomzod bo'ladi — ular SQL shartiga tushib qolmasligi kerak.
    final = ", ".join(t for t in tokens if t in matched)
    if not final:
        return []
    hits = [
        NameHit(
            final, h.table, h.column, h.rows, h.samples,
            h.all_rows, h.all_sample, h.and_tokens,
        )
        for h in hits
    ]
    hits.sort(key=lambda h: h.rows, reverse=True)
    return hits[:5]


def names_as_prompt_hint(hits: list[NameHit]) -> str:
    """Topilgan ism uchun modelga beriladigan yo'riqnoma.

    ENG MUHIM QISM — WHERE shartining AND yoki OR bilan berilishi.
    01.09.2026 gacha bu yerda HAR DOIM OR turardi va "familiya ism otasining
    ismi" ko'rinishidagi savolda bitta bo'lagi mos kelgan begona odamlar ham
    javobga tushardi ("Nematov Shaxboz Zoyir" -> 3 ta haydovchi). Bazada
    o'lchandi: 205 ta to'liq ismning 144 tasida (70 %) OR ortiqcha odam
    qaytaradi, AND esa birortasida ham qatorni yo'qotmadi.

    Shuning uchun AND qachon xavfsiz ekani TAXMIN QILINMAYDI — bazadan
    sanaladi (`_all_tokens_together`). Bo'laklar bitta qatorda uchrasa AND
    beriladi; uchramasa (foydalanuvchi ismni boshqacha yozgan) OR qoladi.
    """
    if not hits:
        return ""
    lines = ["SAVOLDAGI ISM BAZADAN QIDIRILDI:"]
    for hit in hits:
        sample = hit.samples[0] if hit.samples else ""
        line = (
            f"  public.{hit.table}.{hit.column} — {hit.rows} qatorda bo'laklardan "
            f"BIRI bor (masalan: {sample!r})"
        )
        if hit.all_rows:
            line += (
                f"; HAMMA bo'lak BITTA qatorda: {hit.all_rows} qator "
                f"(masalan: {hit.all_sample!r})"
            )
        lines.append(line)

    # Bo'laklarning hammasi bitta qatorda uchragan ustunlar. Eng ko'p bo'lak
    # mos kelgani, teng bo'lsa eng KAM qator qaytargani tanlanadi — u eng aniq.
    exact = [h for h in hits if h.all_rows and h.and_tokens]
    if exact:
        best = min(exact, key=lambda h: (-len(h.and_tokens), h.all_rows))
        conditions = " AND ".join(
            f"{best.column} ~* '{_WB}{t.lower()}{_WB}'" for t in best.and_tokens
        )
        lines.append(
            "  ISMNING HAMMA BO'LAGI BITTA QATORDA bo'lishi shart — bo'laklarni "
            "AND bilan bog'la, OR bilan EMAS. OR bo'lsa bitta bo'lagi mos kelgan "
            "BOSHQA odamlar ham qo'shilib ketadi (familiyadoshlar, ismdoshlar). "
            "ILIKE '%...%' ham ISHLATMA — u so'z ICHIGA tushadi "
            "('%ali%' -> 'Begaliyev'). So'z chegarasi bilan:\n"
            f"      WHERE {conditions}\n"
            "  Ustun nomi jadvalga qarab boshqacha (yuqoridagi ro'yxatga qara) — "
            "hamma jadvalda `full_name` emas."
        )
        if best.all_rows == 1:
            lines.append(
                f"  {best.all_sample!r} — bazadagi HAQIQIY yozuv, shartga mos "
                "YAGONA odam. Savoldagi yozilishi biroz farq qilsa ham (apostrof "
                "turi, qo'shimcha) AYNAN shuni chiqar, boshqasini qo'shma."
            )
        else:
            # Bu yerda "faqat bittasini ol" deyish XATO bo'lardi: shartga
            # haqiqatan bir necha odam mos keladi (masalan bitta familiya
            # ikki haydovchida). Ularning hammasi ko'rsatilishi kerak.
            lines.append(
                f"  Shu shartga {best.all_rows} ta yozuv mos keladi (masalan: "
                f"{best.all_sample!r}) — HAMMASINI alohida qator qilib ko'rsat, "
                "ism ustunini ham SELECT ga qo'sh."
            )
        return "\n".join(lines)

    parts = [p for p in (hits[0].token or "").split(", ") if p]
    if parts:
        conditions = " OR ".join(
            f"{hits[0].column} ~* '{_WB}{p.lower()}{_WB}'" for p in parts
        )
        lines.append(
            "  BO'LAKLARNING HAMMASI BITTA QATORDA UCHRAMADI — ism bazada "
            "boshqacha yozilgan bo'lishi mumkin (familiya va ism tartibi teskari, "
            "yoki qo'shimcha farq qiladi). Shuning uchun bo'laklarni OR bilan "
            "qidir, LEKIN ILIKE '%...%' ISHLATMA — u so'z ICHIGA ham tushadi va "
            "BOSHQA ODAMNI qo'shib yuboradi ('%ali%' -> 'Begaliyev').\n"
            "  So'z chegarasi bilan qidir:\n"
            f"      WHERE {conditions}"
        )
    lines.append(
        "  Yuqorida bazadagi HAQIQIY qiymat namunasi ko'rsatilgan. Agar "
        "so'ralgan ism aynan o'sha bo'lmasa ham, o'xshash yozuvni chiqar — "
        "foydalanuvchi ismni biroz boshqacha yozgan bo'lishi mumkin. Natijada "
        "bir nechta odam chiqsa, ularni ALOHIDA ko'rsat (ism ustunini ham "
        "SELECT ga qo'sh), yig'ib bitta qilib yuborma."
    )
    return "\n".join(lines)


def as_prompt_hint(hits: list[IdentifierHit]) -> str:
    """Topilgan identifikatorlarni model uchun ko'rsatmaga aylantiradi."""
    if not hits:
        return ""
    lines = ["SAVOLDAGI IDENTIFIKATOR BAZADAN TOPILDI — TAXMIN QILMA:"]
    for hit in hits:
        lines.append(
            f"  '{hit.token}' -> public.{hit.table}.{hit.column} "
            f"({hit.rows} qator). Aynan SHU jadval va ustundan qidir: "
            f"WHERE {hit.column} = '{hit.value or hit.token}'"
        )
    lines.append("  Boshqa jadvaldan qidirma — identifikator u yerda YO'Q.")
    return "\n".join(lines)

