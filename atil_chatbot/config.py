"""ATIL chatbot sozlamalari — barchasi loyiha ildizidagi .env dan olinadi."""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent


def _find_env_file() -> Path:
    """Eng yaqin `.env` ni yuqoriga qarab qidiradi.

    Oldin yo'l qat'iy `BASE_DIR.parents[1]` edi — u faqat `<ildiz>/atil/atil_chatbot`
    joylashuvida to'g'ri ishlardi. Papka boshqacha joylashsa `.env` topilmay,
    baza sozlamalari bo'sh qolar va xato faqat birinchi so'rovda ko'rinardi.
    """
    for parent in (BASE_DIR, *BASE_DIR.parents):
        candidate = parent / ".env"
        if candidate.is_file():
            return candidate
    return BASE_DIR.parent / ".env"


ENV_PATH = _find_env_file()
PROJECT_ROOT = ENV_PATH.parent

load_dotenv(ENV_PATH)

# ----------------------------------------------------------------------- vLLM
# 01.09.2026: server Ollama'dan vLLM'ga ko'chdi. vLLM OpenAI-mos API beradi
# (`/v1/chat/completions`) va API kalit talab qiladi. Ollama endpointlari
# (`/api/generate`, `/api/tags`) o'sha serverda YO'Q — shuning uchun eski
# manzil 404 HTML qaytarardi.
#
# `VLLM_BASE_URL` to'ldirilgan bo'lsa BUTUN loyiha vLLM'ga boradi; bo'sh
# qoldirilsa hamma narsa avvalgidek Ollama'da ishlaydi. Ya'ni orqaga qaytish
# uchun kod emas, bitta sozlama o'zgartiriladi.
#
# DIQQAT: vLLM'dagi model nomi Ollama'dagidan BOSHQACHA yoziladi —
# `gemma4:31b` emas, `gemma4-31b`. Serverdagi aniq nomni ko'rish:
#     curl -H "Authorization: Bearer $VLLM_API_KEY" <VLLM_BASE_URL>/models
VLLM_BASE_URL = (os.getenv("VLLM_BASE_URL") or "").rstrip("/")
VLLM_API_KEY = os.getenv("VLLM_API_KEY") or ""
VLLM_MODEL = os.getenv("VLLM_MODEL") or ""

#: Rasm o'qiydigan model (OCR). vLLM'da bitta model hamma vazifani bajaradi,
#: shuning uchun sukut bo'yicha matn modeli bilan bir xil — gemma4-31b
#: multimodal (01.09.2026 da tekshirilgan: image_url bilan javob berdi).
VLLM_VISION_MODEL = os.getenv("VLLM_VISION_MODEL") or VLLM_MODEL

USE_VLLM = bool(VLLM_BASE_URL)


# --------------------------------------------------------------------- Ollama
OLLAMA_BASE_URL = (os.getenv("OLLAMA_BASE_URL") or "http://localhost:11434").rstrip("/")

# Chatbot ATIL Agentdan ALOHIDA model ishlatadi: agentga tool calling kerak,
# chatbotga esa SQL yozish. Shuning uchun OLLAMA_MODEL emas, CHATBOT_OLLAMA_MODEL.
MODEL_NAME = os.getenv("CHATBOT_OLLAMA_MODEL") or "gemma4:31b"

# JAVOB MATNINI yozadigan model — SQL yozadiganidan ALOHIDA.
#
# NIMA UCHUN (28.08.2026 o'lchovi, bir xil prompt, bir xil server):
#     gemma4:31b            8.1 tok/s   -> javob 20-40 s
#     qwen2.5:14b-instruct 16.2 tok/s   -> javob 10-18 s
#     qwen3:8b             29.0 tok/s   -> javob  5-10 s
# SQL yozish OG'IR vazifa: sxemani tushunish, JOIN yo'lini tanlash, status
# qiymatini eslab qolish — u yerda katta model o'zini oqlaydi. Javob esa
# TAYYOR qatorlarni o'zbekcha bayon qilish; raqamlar allaqachon hisoblangan
# va promptda turibdi, model ularni faqat gapga soladi. Shu vazifada kichik
# model farq bermaydi, ammo kutish vaqtini bir necha barobar qisqartiradi.
#
# Bo'sh qoldirilsa asosiy model ishlatiladi.
ANSWER_MODEL_NAME = os.getenv("CHATBOT_ANSWER_MODEL") or MODEL_NAME

# vLLM yoqilgan bo'lsa model nomini U belgilaydi: Ollama nomlari
# (`gemma4:31b`) u yerda mavjud emas va so'rov 404 bilan yiqiladi.
if USE_VLLM and VLLM_MODEL:
    MODEL_NAME = VLLM_MODEL
    ANSWER_MODEL_NAME = os.getenv("CHATBOT_ANSWER_MODEL") or VLLM_MODEL

# 300 -> 150: o'lchovda (28.08.2026) eng sekin SQL generatsiyasi 67 s olgan.
# 300 da Ollama qotib qolganda foydalanuvchi 5 daqiqa "loading" ko'rardi.
DEFAULT_TIMEOUT = float(os.getenv("CHATBOT_OLLAMA_TIMEOUT_SECONDS") or 150)

# JAVOB YOZISHGA alohida, QISQAROQ muhlat.
#
# NIMA UCHUN: 300 soniya SQL yozish uchun mo'ljallangan — u og'ir vazifa va
# uzoq davom etishi mumkin. Javob yozish esa yengil; u 300 soniya kutsa,
# foydalanuvchi 5 daqiqa "loading" ni ko'rib turadi va nima bo'layotganini
# bilmaydi. 28.08.2026 da aynan shunday bo'ldi: Ollama serverining
# generatsiya runner'i qotib qoldi (/api/tags 0.9 s da javob berardi, lekin
# birorta generatsiya bajarilmasdi) va har savol 5 daqiqaga osilib qolardi.
#
# Muhlat tugagach javob matni o'rniga qisqa xato xabari beriladi
# (`nodes/generate_answer.ERROR_ANSWER`); natija jadvali esa baribir
# yuboriladi — u SQL bajarilishi bilan tayyor bo'ladi.
ANSWER_TIMEOUT_SECONDS = float(os.getenv("CHATBOT_ANSWER_TIMEOUT_SECONDS") or 60)
DEFAULT_NUM_CTX = int(os.getenv("CHATBOT_OLLAMA_NUM_CTX") or 16384)
CHATBOT_PORT = int(os.getenv("CHATBOT_PORT") or 8003)

# Modelni Ollama xotirasida (VRAM) qancha ushlab turish.
# Nima uchun muhim (30.07.2026 o'lchovi): server boshqa model bilan
# bo'lishilgan va GPU ga bir vaqtda bitta ~30 GB model sig'adi. Modelimiz
# xotiradan tushib ketsa, keyingi so'rov 46-67 SONIYA qayta yuklashga
# sarflanadi (hisoblashning o'zi 0.2 s). keep_alive buni kamaytiradi.
OLLAMA_KEEP_ALIVE = os.getenv("CHATBOT_OLLAMA_KEEP_ALIVE") or "30m"


def _flag(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


# Fon isitgichi: modelni LLM serverida issiq ushlab turadigan oqim
# (`ollama_client.start_model_warmer`, `main.lifespan` dan ishga tushadi).
#
# NIMA UCHUN O'CHIRGICH KERAK: isitgich hech kim so'ramasa ham har
# `CHATBOT_MODEL_WARMER_SECONDS` da bitta chaqiruv yuboradi. Prod'da bu
# to'g'ri savdo (kesh sovusa prompt o'qish 2.8 s o'rniga 13-15 s), lekin
# lokal ishlab chiqishda bo'lishilgan serverni bekorga band qiladi va
# log'ni to'ldirib, "kimdir mening nomimdan so'rov yuboryapti" degan
# taassurot beradi.
#
# SUKUT BO'YICHA YOQIQ — server xatti-harakati o'zgarmasin.
# Lokalda o'chirish: .env da CHATBOT_MODEL_WARMER=off
MODEL_WARMER = _flag("CHATBOT_MODEL_WARMER", True)
MODEL_WARMER_SECONDS = int(os.getenv("CHATBOT_MODEL_WARMER_SECONDS") or 25)

# Jadval sarlavhalarini LLM bilan qayta nomlash.
# SUKUT BO'YICHA O'CHIQ: SQL allaqachon o'zbekcha AS sarlavha yozadi
# ("Qolgan masofa (km)"), shuning uchun qayta nomlash foyda bermaydi, ammo
# o'lchov bo'yicha bitta so'rovda 54 soniyagacha vaqt oladi.
TABLE_META_LLM = _flag("CHATBOT_TABLE_META_LLM", False)

# Jadval tanlashda LLM bilan qayta saralash.
# SUKUT BO'YICHA O'CHIQ (31.07.2026 o'lchovi asosida):
#   * qoidalar reytingi 49/49 savolda to'g'ri jadvalni topdi — LLM qo'shimcha
#     aniqlik bermadi, aksincha ba'zan noto'g'ri jadvalni birinchi qo'ydi;
#   * bu bosqich o'rtacha 33 soniya olardi (jami vaqtning 26%), chunki har
#     LLM chaqiruvi model qayta yuklanishini keltirib chiqarishi mumkin.
# Yoqish: .env da CHATBOT_TABLE_CHOICE_LLM=true
TABLE_CHOICE_LLM = _flag("CHATBOT_TABLE_CHOICE_LLM", False)

# ----------------------------------------------------------------- PostgreSQL
DB_HOST = os.getenv("ATIL_DB_HOST") or ""
DB_PORT = int(os.getenv("ATIL_DB_PORT") or 5432)
DB_NAME = os.getenv("ATIL_DB_NAME") or ""
DB_USER = os.getenv("ATIL_DB_USER") or ""
DB_PASSWORD = os.getenv("ATIL_DB_PASSWORD") or ""
DB_SCHEMA = os.getenv("ATIL_DB_SCHEMA") or "public"

DB_READ_ONLY = (os.getenv("DB_READ_ONLY") or "true").strip().lower() in {"1", "true", "yes", "on"}
DB_STATEMENT_TIMEOUT_MS = int(os.getenv("DB_STATEMENT_TIMEOUT_MS") or 15000)
DB_CONNECT_TIMEOUT = int(os.getenv("DB_CONNECT_TIMEOUT") or 10)

# --------------------------------------------- PostgreSQL — suhbat tarixi bazasi
# ATIL bazasi READ ONLY (`default_transaction_read_only=on`) — unga tarix
# yozib bo'lmaydi. Shu sababli tarix ALOHIDA bazada saqlanadi.
CHAT_DB_HOST = os.getenv("CHAT_DB_HOST") or ""
CHAT_DB_PORT = int(os.getenv("CHAT_DB_PORT") or 5432)
CHAT_DB_NAME = os.getenv("CHAT_DB_NAME") or ""
CHAT_DB_USER = os.getenv("CHAT_DB_USER") or ""
CHAT_DB_PASSWORD = os.getenv("CHAT_DB_PASSWORD") or ""
CHAT_DB_SCHEMA = os.getenv("CHAT_DB_SCHEMA") or "public"
CHAT_DB_TABLE = os.getenv("CHAT_DB_TABLE") or "chat_history"

# DIQQAT: bu server SSL muzokarasida ulanishni uzadi (10053 "connection
# abort"), shuning uchun sukut bo'yicha `disable`. ATIL bazasi esa standart
# rejimda ishlaydi — shu bois sozlama alohida.
CHAT_DB_SSLMODE = os.getenv("CHAT_DB_SSLMODE") or "disable"

CHAT_DB_CONNECT_TIMEOUT = int(os.getenv("CHAT_DB_CONNECT_TIMEOUT") or 4)
CHAT_DB_STATEMENT_TIMEOUT_MS = int(os.getenv("CHAT_DB_STATEMENT_TIMEOUT_MS") or 5000)

# Promptga qo'shiladigan va bazadan o'qiladigan oxirgi savol-javoblar soni
CHAT_HISTORY_MAX_TURNS = int(os.getenv("CHAT_HISTORY_MAX_TURNS") or 10)

# Jadvalni startda avtomatik yaratish. Bazaga CREATE huquqi bo'lmasa false qiling.
CHAT_DB_AUTO_CREATE = _flag("CHAT_DB_AUTO_CREATE", True)


# ------------------------------------------------------------------ Yo'llar
DDL_PATH = BASE_DIR / "ddl.sql"


def db_config_missing() -> list[str]:
    """To'ldirilmagan majburiy baza sozlamalarini qaytaradi."""
    required = {
        "ATIL_DB_HOST": DB_HOST,
        "ATIL_DB_NAME": DB_NAME,
        "ATIL_DB_USER": DB_USER,
        "ATIL_DB_PASSWORD": DB_PASSWORD,
    }
    return [name for name, value in required.items() if not value]


def chat_db_config_missing() -> list[str]:
    """Suhbat tarixi bazasi uchun to'ldirilmagan sozlamalar."""
    required = {
        "CHAT_DB_HOST": CHAT_DB_HOST,
        "CHAT_DB_NAME": CHAT_DB_NAME,
        "CHAT_DB_USER": CHAT_DB_USER,
        "CHAT_DB_PASSWORD": CHAT_DB_PASSWORD,
    }
    return [name for name, value in required.items() if not value]
