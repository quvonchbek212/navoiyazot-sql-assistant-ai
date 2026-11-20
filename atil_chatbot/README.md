# ATIL chatbot

Chatbot `lims_chatbot` dagi LangGraph, SQL tekshiruv, qayta urinish, javob formatlash,
suhbat xotirasi va SSE mexanizmlari asosida ishlaydi. Domen ATIL transport bazasiga
moslangan; LIMS sxemasi, laboratoriya ma'lumotlari va Chroma bazasi ko'chirilmagan.

```text
question → screen → classify + jadval tanlash → database / chitchat / refuse
database → aniq katalog yoki LLM SQL → read-only AST → sxema/CHECK tekshiruvi
         → baza → xato bo'lsa aniq sabab bilan qayta urinish → tekshirilgan javob
```

`app/` yangi chatbotning yagona dvigateli. Eski `nodes/` va `core/pipeline.py`
olib tashlangan. `config.py`, `ollama_client.py`, `core/lang.py`, `core/ollama_json.py`
va `db/` yordamchilari dispetcher, yoqilg'i va ta'mir xizmatlari uchun saqlangan.

| Fayl | Vazifa |
|---|---|
| `app/graph.py` | Xavfsizlik, yo'naltirish, sonlar nazorati, javob |
| `app/sql_service.py` | SQL yaratish, tekshirish va xatoni tuzatish |
| `app/sql_guard.py`, `app/sql_validator.py` | Faqat o'qish va mavjud sxema/CHECK qiymatlari |
| `app/domain.py` | ATIL qoidalari, ko'p tilli atamalar, jadval izohlari |
| `app/sql_catalog.py` | 18 ta ATIL savol/SQL misoli; tez yo'l savol to'liq mos kelsa ishlaydi |
| `app/schema_provider.py` | Snapshot va jonli metadata, FK orqali sxema tanlash |
| `app/answer_format.py` | Son va ro'yxatlarni baza natijasidan chiqarish |
| `app/memory.py` | Alohida PostgreSQL yoki jarayon xotirasi |
| `app/api.py`, `app/compat.py` | Yangi API va mavjud `/chat` bilan moslik |
| `schema/schema.json`, `schema/ddl.sql` | Yangi dvigatel sxemasi |

Ildizdan ishga tushirish:

```powershell
pip install -r requirements.txt
uvicorn main:app --host 127.0.0.1 --port 8000
```

Swagger: `/docs`. Barcha API yo'llari mavjud `API_USERNAME`/`API_PASSWORD` bilan
yopiq. `.env` o'zgartirilmagan. Baza ulanishi faqat `ATIL_DB_*` dan olinadi;
LIMS uchun umumiy `DB_*` sozlamalari ATIL ulanishini almashtirmaydi.
`VLLM_BASE_URL`, `VLLM_API_KEY`, `VLLM_MODEL` ishlatiladi. URL bo'sh bo'lsa
`OLLAMA_BASE_URL/v1` va `CHATBOT_OLLAMA_MODEL` ishlaydi.

| Endpoint | Shartnoma |
|---|---|
| `POST /chat` | Mavjud format: sukut SSE (`stage/token/reset/sql/table/done/error`); `stream:false` bilan JSON |
| `DELETE /chat/{session_id}` | Shu foydalanuvchining yangi xotirasini tozalash |
| `POST /api/chat` | LIMS uslubidagi JSON: `answer`, `sql`, `columns`, `rows`, `next_cursor` |
| `POST /api/chat/stream` | `start/delta/result/error` SSE |
| `POST /api/chat/page` | `{"cursor":"..."}` bilan keyingi 20 qator |
| `GET /api/schema` | Sxema manbasi, jadval/ustunlar soni |
| `GET /healthz`, `GET /health` | Haqiqiy DB/LLM/xotira/sxema tayyorligi; nosozlikda 503 |

Har ikkala chat yo'li `question`, `session_id`, `lang` (`uz/ru/en`) qabul qiladi va
bir xil graf hamda xotirani ishlatadi. SSE mijozida yakuniy `done.answer` yoki
`result.answer` bilan oldingi bo'laklarni almashtiring. `/chat` dagi `reset`
kelganda yig'ilgan matnni tozalang. `/api/chat/page` ikkala javobdagi cursor bilan ishlaydi.

Scalar qiymat, sanoq va ro'yxatlarni kod chiqaradi. Ko'p qatorli natijada model
faqat miqdorsiz qisqa izoh yozadi; yangi son chiqsa oqim to'xtatilib, baza natijasidan
qoidaviy javob beriladi. `rows` ko'pi bilan 20 qator; `total_count` bo'lmasa jami
son ma'lum deb hisoblamang. Cursor jarayon ichida saqlanadi; bir nechta worker
uchun sticky routing kerak.

`CHAT_DB_*` sozlangan bo'lsa yangi `atil_chatbot_sessions` va
`atil_chatbot_messages` jadvallari alohida tarix bazasida yaratiladi.
`CHAT_DB_TABLE_PREFIX` nomni o'zgartiradi. Eski `chat_history` jadvali saqlanadi;
eski suhbatlar yangi formatga avtomatik ko'chirilmaydi. `CHAT_DB_HOST` bo'sh bo'lsa
jarayon xotirasi ishlaydi. Sessiyalar login va `session_id` juftligi bilan ajratiladi.

Sxemani yangilash (faqat o'qish):

```powershell
python -m atil_chatbot.tools.generate_ddl --metadata-only
python -m atil_chatbot.tools.generate_ddl                # tarixiy qiymatlar va statistika ham
python -m atil_chatbot.tools.generate_ddl --render-only  # bazaga ulanmasdan DDL chizish
```

Dastlabki snapshot mavjud ATIL `ddl.sql` metadata nusxasidan olingan. Ishlashda
jonli metadata har 600 soniyada yangilanadi; CHECK qiymatlari cheklov, tarixiy
namuna qiymatlari faqat maslahat. `SCHEMA_REFRESH_SECONDS=0` offline sinov uchun.
Ildizdagi `ddl.sql` boshqa xizmatlar uchun saqlangan va eski generator orqali yangilanadi.

Tekshirish:

```powershell
pytest tests atil_chatbot/tests -q
python -m atil_chatbot.tools.evaluate --catalog-only
python -m atil_chatbot.tools.evaluate --output .codex_run/atil-chatbot-evaluation.json
```

Oddiy testlar jonli LLMni chaqirmaydi. Katalog baholashi haqiqiy ATIL bazasida faqat
SELECT bajaradi. To'liq baholash sozlangan LLMga ATIL sxemasi va natijalarini yuboradi;
hisobot beshta scalar savolni nazorat SQLlari bilan solishtiradi. U barcha savollar
uchun aniqlik kafolati emas. Baholash suhbat bazasiga yozmaydi.

2026-11-07 tekshiruvi: 18/18 katalog SQLi haqiqiy ATIL bazasida bajarildi;
model yaratgan beshta scalar javobning barchasi nazorat SQLlari bilan mos chiqdi.
Tabiiy tildagi avtopark savoli va undan keyingi davomli savol ham mos chiqdi.
Haqiqiy LLM bilan `/chat`, `/api/chat`, `/api/chat/stream` va `/healthz` tekshirildi.
Bu sinovlarda tarix faqat jarayon xotirasida saqlandi. PostgreSQL tarix backendining
jonli yozuvi sinovdan o'tkazilmadi; uning alohida integratsion testlari ixtiyoriy.
