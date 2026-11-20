# Ehtiyot qismlar nazorati (`/parts-control`)

**Maqsad — qism o'zlashtirilishining oldini olish.** Uch yo'l va izi:

| Yo'l | Iz (bazada 28.10.2026) |
|---|---|
| boshqa mashina uchun olish | Damas ta'miriga "Тормозные колодки передние КАМАЗ" (2 marta), "Генератор 28V 80A"; BYD va XCMG LW300 ga "190Ah" |
| resursidan oldin almashtirish | XCMG LW300 akkumulyatori 13 oyda (resurs 24 oy, kafolat ichida) |
| berib, hisobdan chiqarmaslik | berilgan − ishlatilgan − qaytarilgan > 0 |

```
GET /parts-control/scan    so'ralgan va o'rnatilgan qismlar
GET /parts-control/norms   rusum bo'yicha: necha km / oy yurishi kerak
```

## Qism mashinaga mosmi — nomning o'zidan

| Belgi | Solishtirish |
|---|---|
| `PART_FOR_OTHER_MODEL` | nomdagi marka (КАМАЗ, Damas, Labo...) — mashina rusumi |
| `VOLTAGE_MISMATCH` | 12/24/28 V — mashina elektr tizimi (yengil avtomobil 12 V) |
| `BATTERY_SPEC_MISMATCH` | Ah — shu mashinada, bo'lmasa shu rusumda, bo'lmasa shu turda o'rnatilganlar |
| `TIRE_SIZE_MISMATCH` | disk o'lchami (R12, R17.5) — mashinadagi shinalar |
| `QTY_EXCEEDS_FITMENT` | shina soni — mashinadagi shinalar soni |

Chegara yo'q — to'plamga tegishlilik: so'ralgan 190 Ah o'rnatilgan
{105} ichida emas.

## Resurs — km, oy, kafolat

Baza ustun: `vehicle_part.expected_life_km` / `_months` / `_engine_hours`
(korxona siyosati: Damas/Cobalt shina 40–60 ming km, Isuzu 30–70 ming,
akkumulyator 24 oy). Bazada bo'lmasa:

| Nima | Manba |
|---|---|
| akkumulyator: kamida 24 oy, 90 000 km, 3000 motosoat | GOST R 53165-2020 p.7.3.3 |
| yengil avtomobil shinasi kafolati: 5 yil | GOST 4754-97 p.10.1 |
| shina probegi | tashqi me'yor YO'Q (AE 001-04 kuchini yo'qotgan, Mintrans 2025 xati) — faqat baza |

Qaysi o'lchov BIRINCHI tugasa o'sha hal qiladi. GOST — ENG KAM muddat,
shuning uchun "resursi tugagan" (`OVER_LIFE`) faqat korxona resursidan
chiqadi; "resursidan oldin" esa GOST bilan ham.

## Bazaning cheklovlari (data_quality da aytiladi)

* qism QACHON YECHILGANI yozilmaydi (`removed_at` bo'sh) — almashtirish
  tarixi faqat qism so'rovlaridan;
* ombor harakati (`material_movement`, `inventory_receipt`) bo'sh —
  faqat joriy qoldiq (`stock`);
* 187 qismning o'rnatilgan sanasi = kiritilgan kun — oy bo'yicha resurs
  ular uchun hisoblanmaydi;
* 28 ta shinada resurs "4000 km" — `LIFE_VALUE_SUSPECT` (nol tushib qolgan).

Ma'lumot to'lgani sari tekshiruvlar kod o'zgarmasdan kengayadi.

Agent: `atil_agent/agents/parts_watch.py`. Testlar: `tests/test_parts_control.py`.

## Mashina pasporti (`/parts-control/passport`)

```
GET  /parts-control/passport?plate_number=85471LBA   bitta mashina
GET  /parts-control/passport?model=Damas             park, rusum bo'yicha
POST /parts-control/passport                         almashtirishni yozish
```

**Har mashinaga 15-16 qism** — sinfiga qarab (`vehicle_reference/components.py`):

| Sinf | Mashinalar | Qismlar |
|---|---|---|
| Yengil avtomobil | Damas, Labo, Cobalt, Lacetti, BYD... | moy, moy/havo/yoqilg'i/salon filtri, svecha, GRM, tormoz, tormoz suyuqligi, antifriz, KPP moyi, shina, akkumulyator, yurish qismi, elektr, dvigatel |
| Isuzu N-seriya | NPR/NQR/82L, avtobus, minora | moy, filtrlar, antifriz, KPP va ko'prik moyi, tormoz, shina almashlab qo'yish... |
| Yuk mashinasi | KAMAZ, MAN, HOWO, ZIL, kran... | moy, filtrlar, KPP/ko'prik moyi, tormoz, ilashish, shina... |
| Motosoat texnikasi | yuklagich, ekskavator, traktor, Avtokara | moy, filtrlar, gidravlika moyi/filtri, KPP/ko'prik moyi, antifriz... |

**Oxirgi voqea** — ATIL ta'mirlari (`vehicle_repair` + ish bandlari:
"moy almashtirish" — almashtirildi, "shina yamaldi" — ta'mirlandi), qism
so'rovlari (`USED`), o'rnatilgan shina/akkumulyatorlar, texnik xizmat rejasi
(`maintenance_plan`) va qo'lda yozilgan voqealar (`parts_component_event`,
CHAT_DB bazasida).

**Oraliq** — `maintenance_plan` > `vehicle_tire_norm`/`vehicle_part` >
ishlab chiqaruvchi jadvali (Isuzu N-seriya, Lacetti reglamenti, g'ildirakli
yuklagich, tormoz suyuqligi — havolalar `components.SOURCES` da). Manba
topilmagan qism — `NO_INTERVAL`: faqat tarix, "vaqti keldi" hukmi yo'q.

**Holat**: `OVERDUE` (100%+), `DUE_SOON` (korxona chegarasi 80% —
`vehicle_part.warning_at_percent`), `OK`, `UNKNOWN` (tarix yo'q —
TAXMIN QILINMAYDI). Ta'mir (yamash) oraliqni qayta boshlamaydi, almashtirish
boshlaydi.

**Spidometr** — yo'l varaqalari va texnik ko'riklardan; spidometr orqaga
yurmaydi, shuning uchun eng uzun kamaymaydigan zanjir olinadi va oxirgi 5
o'lchov medianasi (bazada bir kunda 152 229 / 316 606 / 210 594 yozilgan).
Bir kunning takror yozuvi bitta hisoblanadi; zanjirga sig'magan o'lchovlar
soni pasportda (`readings.dropped`) va izohda.

**Ma'lumot ziddiyati — taxmin qilinmaydi, o'lchov noma'lum bo'ladi:**

| Holat (bazada 28.10.2026) | Qoida |
|---|---|
| resurs "4 000 km", parkda 40 000 bor (vehicle_part ham, vehicle_tire_norm ham) | o'sha resurs olinmaydi |
| sutkasiga 1 500 km / 24 motosoatdan ko'p (`PC_MAX_KM_PER_DAY`) | ko'rsatkich xatosi |
| tizim boshida "1 005 motosoat", "50 000 km", keyin haqiqiy raqamga sakrash | kunlik o'rtacha sakrashdan keyin; sakrashdan oldingi almashtirish km bilan solishtirilmaydi |
| ikki xil spidometr: qism yozuvida 344 435 km, yo'l varaqasida 18 623 (185 dona) | shina/akkumulyator — qism yozuvining o'zi (`/scan` bilan bir xil) |
| qo'lda kiritilgan km o'lchovga zid (85019GAA ga 50 000 km, 30.09 da 16 134 km) | yozuv saqlanadi, km hisobga olinmaydi; POST javobida `warnings`, pasportda izoh |
| voqea sanasidan oldin o'lchov yo'q (2025-yilgi almashtirish, spidometr 2026-08 dan) | keyingi o'lchov faqat 7 kun ichida bo'lsa (`PC_READING_FALLBACK_DAYS`), aks holda km noma'lum |

Qo'lda yozuvni kim kiritgani `recorded_by` da — `driver` (haydovchi) emas.

Ziddiyatlar soni pasport izohida — ATIL ma'lumotini tozalash uchun.

**Har bir shina va akkumulyator** (`components[].parts`) — qachon va necha
km da qo'yilgan, qo'yilgandan beri qancha yurgan, resursi (manbasi bilan),
foizi, qancha qolgani va taxminan qachon tugashi (kunlik o'rtacha yurish va
oy resursidan — qaysi biri oldin). Kunlik yurish noma'lum bo'lsa km bo'yicha
sana AYTILMAYDI; resursi tugagan yoki ATIL da yeyilgan deb belgilangan
donaga sana berilmaydi — holati yetarli. Har donada o'qiladigan `text`.

**Ish profili** (`usage`, `parts_control/usage.py`) — so'nggi 30 va 90 kun:
spidometr bo'yicha va reyslar yig'indisi bo'yicha km (IKKALASI — ular mos
kelmasligi mumkin, Damas 85681DBA: 2 123 / 1 715 km), reyslar soni, ishlagan,
turgan va ta'mirda turgan kunlar, yuk (bazada 4 011 yo'l varaqasidan 23
tasida). Reys yozila boshlagan kundan (2026-08-19) oldingisi "turgan" emas —
"ma'lumot yo'q". Rejadagi muddatiga sutkasiga 1 500 km dan ko'p to'g'ri
keladigan reys kirmaydi (R-000905: rejada 11 soat, 6 204 km). Davrda yangi
spidometr o'lchovi bo'lmasa yoki uzilish bo'lsa — km noma'lum, "0 km" emas.
ATIL o'zi karantinga olgan ko'rik o'lchovlari (`vehicle_usage_reading`)
spidometr zanjiriga kirmaydi.

## Talab prognozi (`/parts-control/forecast`)

```
GET /parts-control/forecast?days=90&category=TIRE&model=Damas
```

Shina va akkumulyator — **o'lcham bo'yicha nechta kerak** (`parts_control/forecast.py`).
Ikki usul ALOHIDA, aralashtirilmaydi (vazn o'ylab topilmaydi):

| Usul | Manba |
|---|---|
| muddati bo'yicha | har bir donaning taxminiy tugash sanasi: resursi tugagan — "hozir", davrda tugaydi — "davrda"; sanasi noma'lum (kunlik yurish yo'q) — alohida, jamiga kirmaydi |
| o'tgan sarf bo'yicha | so'nggi 12 oyda shu o'lchamdan nechta qo'yilgan (bazaga kiritilgan kun emas). Eski yozuv qolmagani uchun KAM ko'rsatishi mumkin |

Ombor (`inventory_stock`) bilan o'lcham kaliti orqali (`rules.tire_size_key`:
"Шины 12,00 -R20" = "12.00R20" = "12R20"; akkumulyator — Ah). Mos kelmasa
"omborda shu o'lcham yo'q" — o'xshashi taklif qilinmaydi (40 Ah kerak, omborda
35 Ah). Boshqa qismlar — miqdor bazada yo'q, necha mashinada xizmat vaqti
keladi; tarix yo'qlari — `not_forecast`. Tasdiqlangan, hali berilmagan qism
so'rovlari — `pending_requests`.

## Almashtirish tekshiruvi (`/parts-control/check`)

```
GET /parts-control/check?plate_number=85058GAA&component=TIRES&quantity=4
```

Qism BERISHDAN OLDIN (`parts_control/check.py`): oxirgi marta qachon
almashtirilgan, o'shandan beri qancha yurgan, standart bo'yicha yana qancha
yurishi kerak edi — xulosa va tavsiya:

| Xulosa | Qachon |
|---|---|
| `JUSTIFIED` (asosli) | resursi tugagan, "yeyilgan" deb belgilangan yoki 80% dan oshgan |
| `CHECK` (tekshiring) | yaqinda almashtirilgan: eski qismni ko'rish, shikast bo'lsa dalolatnoma+foto, eskisini omborga topshirish, kafolat ichida — yetkazib beruvchiga da'vo |
| `NO_DATA` | oldingi almashtirish yoki oraliq yo'q — standart oraliq (bo'lsa) aytiladi |

"Berma" demaydi — shikast haqiqiy sabab bo'lishi mumkin. Bir nechta dona
(4 ta shina): avval asoslilari, qolgani uchun "tekshiring" (85058GAA: 2 tasi
81.9%, 4 tasi 2026-04-10 da qo'yilgan, 7.9%).

Qayerda ishlaydi: endpoint; chatda ("85058GAA ga 4 ta shina so'ralyapti,
beraylikmi?"); `POST /parts-control/passport` da almashtirish yozilayotganda
`warnings` (yozuvdan OLDIN hisoblanadi); `parts` agenti ATIL qism so'rovida
("XCMG LW300 akkumulyatori 24 oydan 13.3 oyida — yana 10.7 oy xizmat qilishi
kerak edi").

**Oraliq manbalari (internetdan, havola bilan `components.SOURCES`):**
HOWO — Sinotruk HOWO 371HP xizmat jadvali; Lacetti/Gentra — svecha 30 000 km,
GRM tasmasi 60 000 km (zr.ru). Topilmagani — taxmin qilinmaydi: KAMAZ (zavod
jadvali TO-1/TO-2 ni model va ekologik sinfga bog'laydi, bazada model
yozilmagan), MAN (oraliqni bort kompyuteri belgilaydi), Cobalt GRM (zanjir).
Bular uchun ATIL `maintenance_plan` ga kiriting.

## Chatda (`POST /chat`, `route: parts`)

`parts_control/chat.py` — zapchast savoli pasport/prognoz/park holatidan,
LLM'siz javob oladi (har raqam pasportdan). Qachon:

| Savol | Javob |
|---|---|
| "85058GAA", "85058GAA haqida ma'lumot" | to'liq pasport: ogohlantirishlar, holati ma'lum qismlar, noma'lumlar, ish profili, haydovchilar |
| "85058GAA balonlari qachon qo'yilgan, qachongacha chidaydi?" | faqat shu qism, har bir dona |
| "85058GAA qaysi qismini almashtirish kerak?" | faqat ogohlantirishlar va noma'lumlar |
| "85058GAA ga 4 ta shina so'ralyapti, beraylikmi?" | almashtirish tekshiruvi: xulosa va tavsiya |
| "85019GAA ni kim haydagan?", "85681DBA qancha yurgan?" | haydovchilar / ish profili |
| "Keyingi 3 oyda qancha shina kerak bo'ladi?" | talab prognozi |
| "Qaysi mashinalarning akkumulyatori vaqti o'tgan?" | park holati shu qism bo'yicha |

Boshqa savol (masalan "85058GAA qaysi reyslarda bo'lgan?") — oddiy SQL yo'li.
"50000 km" davlat raqami deb olinmaydi.

**Qisqa savolga — qisqa javob.** To'liq pasport faqat umumiy savolda (faqat
raqam yoki "haqida ma'lumot"). Qism, haydovchi, yurish yoki "nimani almashtirish
kerak" so'ralsa — faqat shu va kerakli tavsiya: sarlavha qisqa, bir xil donalar
bitta qatorda ("4 ta (L334CA04051, ...)"), "kunlik yurish noma'lum" bir marta,
manba nomi qisqa (to'liq tavsif va havola API da). Tarixi yo'q qismga ham
standart oraliq aytiladi (HOWO moyi: 8 000 km yoki 6 oy).

**Haydovchilar** — biriktirilganlar (`transport_vehicle`,
`vehicle_assigned_drivers`) va yo'l varaqalari bo'yicha kim qachon
haydagani, almashinuv tarixi bilan.

**Bildirishnoma** — `atil_agent/agents/service_watch.py` (`service`):
vaqti o'tgan yoki yaqinlashgan qism website notification'ga boradi.

Testlar: `tests/test_parts_passport.py`, `test_parts_usage.py`, `test_parts_forecast.py`, `test_parts_chat.py`, `test_parts_check.py`.
