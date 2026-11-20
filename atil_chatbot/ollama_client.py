"""Ollama klienti — node'lar shu moduldan `ask_llm` ni chaqiradi.

Interfeys ko'chirib olingan kod kutgan ko'rinishda saqlangan (`ask_llm`,
`_build_payload`, `check_ollama_alive_sync` va h.k.), shuning uchun node'larda
import o'zgartirish kerak bo'lmadi.

MUHIM O'ZGARISH: asl kodda Ollama ishlamasa avtomatik Gemini'ga (Google cloud)
o'tish bor edi. U olib tashlandi — chatbot promptiga ATIL bazasining to'liq
sxemasi va so'rov natijalari kiradi, ularni tashqi API'ga jimgina yuborish
mumkin emas. Ollama ishlamasa aniq xato qaytariladi.
"""

from __future__ import annotations

import json
import logging
import re
import threading
import time
from collections.abc import AsyncIterator
from typing import Any

import httpx

from config import (
    DEFAULT_NUM_CTX,
    DEFAULT_TIMEOUT,
    MODEL_NAME,
    MODEL_WARMER,
    MODEL_WARMER_SECONDS,
    OLLAMA_BASE_URL,
    OLLAMA_KEEP_ALIVE,
    VLLM_API_KEY,
    VLLM_BASE_URL,
)

logger = logging.getLogger(__name__)

#: Ollama "o'lik" deb belgilangandan keyin shu vaqt ichida qayta urinilmaydi
_DOWN_COOLDOWN_SECONDS = 30.0
_down_until: float = 0.0

#: Model nomi -> fon isitgichi shu model uchun issiq ushlaydigan prompt prefiksi.
#:
#: NIMA UCHUN: Ollama promptning o'zgarmas boshlanishini KV-keshda saqlaydi.
#: SQL promptining boshi ~6200 token qoidalardan iborat va hech qachon
#: o'zgarmaydi. 19.08.2026 o'lchovi (gemma4:31b): kesh sovuq bo'lsa promptni
#: o'qish 13.7-24.6 s, issiq bo'lsa 1-2 s. Javob prompti uchun ham xuddi
#: shunday (28.08.2026, qwen2.5:14b-instruct): 2.96 s -> 0.05 s.
#:
#: Ilgari isitgich BO'SH prompt yuborardi. U modelni VRAM da ushlardi, ammo
#: KV-keshni bo'sh ketma-ketlik bilan almashtirib yuborardi — natijada
#: keyingi savol yana to'liq prompt o'qishga to'lardi.
#:
#: Xarita, chunki SQL va javob ALOHIDA modellarda ishlashi mumkin
#: (`CHATBOT_ANSWER_MODEL`) — ikkalasining ham prefiksi issiq turishi kerak.
#: Ikkalasi BIR XIL model bo'lsa keshda faqat bittasi qolaveradi (bu Ollama
#: cheklovi), o'shanda kattarog'i — SQL prefiksi — ustun keladi.
_warm_prefixes: dict[str, str] = {}
_warm_lock = threading.Lock()


def set_warm_prefix(text: str, model: str | None = None) -> None:
    """Fon isitgichi qaysi model uchun qaysi prefiksni issiq ushlashini belgilaydi."""
    if not text:
        return
    with _warm_lock:
        _warm_prefixes[model or MODEL_NAME] = text


def get_warm_prefixes() -> dict[str, str]:
    with _warm_lock:
        return dict(_warm_prefixes)


#: Oxirgi FOYDALANUVCHI so'rovi qachon bo'lgani (fon isitgichi uchun).
#: Ollama bitta model uchun so'rovlarni NAVBAT bilan bajaradi. Isitgich
#: ~6200 tokenlik prefiksni yuboradi va bu bir necha soniya band qiladi —
#: aynan o'sha paytda foydalanuvchi savol bersa, u navbatda kutadi va
#: kutish `load_duration` bo'lib ko'rinadi. Shuning uchun yaqinda haqiqiy
#: so'rov bo'lgan bo'lsa isitgich o'tkazib yuboriladi: model allaqachon
#: issiq, keshda ham o'sha prefiks turibdi.
#: 90 -> 12 s. Kattaroq oyna keshni qayta isitishga imkon bermay qoldi:
#: bo'lishilgan serverda BOSHQA foydalanuvchilarning so'rovlari bizning
#: KV-keshimizni siqib chiqaradi, ya'ni prefiksni MUNTAZAM qayta yuborish
#: kerak. O'lchov: isitgich yaqinda ishlagan bo'lsa prompt o'qish 2.8 s,
#: aks holda 13.8-15.8 s. Oyna faqat AYNI PAYTDA ketayotgan so'rov bilan
#: to'qnashmaslik uchun qoldirilgan.
WARM_SKIP_AFTER_REQUEST_SECONDS = 12.0
_last_request_at: float = 0.0

#: AYNI PAYTDA ketayotgan LLM chaqiruvlari soni.
#:
#: NIMA UCHUN VAQT O'LCHOVI YETMAYDI: oqimli javob 20-40 soniya davom
#: etadi, `note_request()` esa faqat BOSHIDA chaqiriladi. Faqat vaqtga
#: qarasak, isitgich javob o'rtasida uyg'onib, 10 000 tokenlik prefiksni
#: yuboradi — Ollama so'rovlarni navbat bilan bajargani uchun bu
#: foydalanuvchining oqimini to'xtatib qo'yadi. Hisoblagich bilan
#: isitgich ish ketayotganini ANIQ biladi.
_inflight = 0
_inflight_lock = threading.Lock()


def note_request() -> None:
    """Har bir haqiqiy LLM chaqiruvi shu funksiyani chaqiradi."""
    global _last_request_at
    _last_request_at = time.monotonic()


class _InFlight:
    """LLM chaqiruvi davomida isitgichni to'xtatib turadi."""

    def __enter__(self) -> None:
        global _inflight
        note_request()
        with _inflight_lock:
            _inflight += 1

    def __exit__(self, *exc_info: object) -> None:
        global _inflight
        with _inflight_lock:
            _inflight -= 1
        note_request()


def _warm_needed() -> bool:
    if not get_warm_prefixes():
        return False
    with _inflight_lock:
        if _inflight:
            return False
    return (time.monotonic() - _last_request_at) >= WARM_SKIP_AFTER_REQUEST_SECONDS

_THINKING_RE = re.compile(r"<think(?:ing)?>[\s\S]*?</think(?:ing)?>", re.IGNORECASE)


class OllamaClientError(RuntimeError):
    """Ollama bilan ishlashda yuzaga kelgan xato."""


class OllamaEmptyResponseError(OllamaClientError):
    """Model bo'sh javob qaytardi."""


def _use_vllm() -> bool:
    """vLLM (OpenAI-mos API) ishlatiladimi yoki Ollama.

    Modul konstantasi emas, FUNKSIYA: shunda testlar `VLLM_BASE_URL` ni
    almashtirib ikkala backendni ham sinay oladi.
    """
    return bool(VLLM_BASE_URL)


def _base_url() -> str:
    """So'rov ketadigan manzil.

    DIQQAT: `VLLM_BASE_URL` `/v1` bilan tugashi kerak — endpointlar shunga
    nisbatan qo'shiladi (`/chat/completions`, `/models`).
    """
    return VLLM_BASE_URL if _use_vllm() else OLLAMA_BASE_URL


def _verify_ssl() -> bool:
    """ngrok va boshqa https tunnellar uchun sertifikat tekshiruvi."""
    return _base_url().startswith("https://")


def _build_headers() -> dict[str, str]:
    headers = {
        "Content-Type": "application/json",
        # ngrok bepul tunneli brauzer ogohlantirish sahifasini qaytarmasligi uchun
        "ngrok-skip-browser-warning": "1",
    }
    if _use_vllm() and VLLM_API_KEY:
        headers["Authorization"] = f"Bearer {VLLM_API_KEY}"
    return headers


def _build_payload(prompt: str, config: dict[str, Any] | None, *, stream: bool = False) -> dict[str, Any]:
    """`config` ni Ollama /api/generate payload'iga aylantiradi.

    Qo'llab-quvvatlanadigan config kalitlari:
        model                 — modelni almashtirish
        timeout               — shu chaqiruv uchun muhlat (soniya)
        options               — temperature, num_ctx, num_predict, top_p, top_k
        response_json_schema  — JSON schema (structured output)
        response_mime_type    — "application/json" bo'lsa erkin JSON majburlanadi
        think                 — thinking modellarida mulohazani o'chirish
    """
    config = dict(config or {})
    options = dict(config.get("options") or {})
    options.setdefault("temperature", 0)
    options.setdefault("num_ctx", DEFAULT_NUM_CTX)

    payload: dict[str, Any] = {
        "model": config.get("model") or MODEL_NAME,
        "prompt": prompt,
        "stream": stream,
        "options": options,
        # Modelni VRAM da ushlab turadi — qayta yuklash 46-67 s turardi
        "keep_alive": config.get("keep_alive", OLLAMA_KEEP_ALIVE),
    }

    schema = config.get("response_json_schema")
    if schema:
        payload["format"] = schema
    elif config.get("response_mime_type") == "application/json":
        payload["format"] = "json"

    # Mulohaza (thinking) SUKUT BO'YICHA O'CHIRILGAN.
    # Sabab (30.07.2026 o'lchovi, gemma4:31b): thinking yoqilganda model butun
    # num_predict budjetini ichki mulohazaga sarflab, `response` ni BO'SH
    # qoldiradi (done_reason="length"). SQL yozish uchun 900 token yetmadi va
    # 3/3 urinish bo'sh qaytdi. `think=false` bilan xuddi shu SQL 219 tokenda
    # to'g'ri chiqdi — ya'ni 5x tez va ishonchli.
    # Mulohaza qilmaydigan modellarda (qwen2.5, llama3.1) bu parametr xato
    # bermaydi — tekshirilgan.
    payload["think"] = config.get("think", False)

    return payload


def _build_chat_payload(
    prompt: str, config: dict[str, Any] | None, *, stream: bool = False
) -> dict[str, Any]:
    """`config` ni vLLM'ning OpenAI-mos `/chat/completions` payload'iga aylantiradi.

    Ollama parametrlarining bir qismi bu yerda ATAYLAB tushiriladi — vLLM
    ularni bilmaydi va 400 qaytaradi:
      * `num_ctx`    — kontekst uzunligi serverda belgilangan (max_model_len);
      * `keep_alive` — vLLM modelni xotiradan tushirmaydi, kerak emas;
      * `think`      — vLLM'da bunday bayroq yo'q.

    JSON majburlash ham boshqacha: Ollama sxemani `format` ga qo'yadi, vLLM
    esa OpenAI ko'rinishidagi `response_format` ni kutadi.
    """
    config = dict(config or {})
    options = dict(config.get("options") or {})

    payload: dict[str, Any] = {
        "model": config.get("model") or MODEL_NAME,
        # /api/generate xom prompt oladi, /chat/completions esa xabarlar
        # ro'yxatini — matn bitta foydalanuvchi xabariga o'raladi.
        "messages": [{"role": "user", "content": prompt}],
        "temperature": options.get("temperature", 0),
        "stream": stream,
    }
    if options.get("num_predict"):
        payload["max_tokens"] = int(options["num_predict"])
    if options.get("top_p") is not None:
        payload["top_p"] = options["top_p"]

    # Opt-in per caller: vLLM chat templates (including Gemma 4) use this
    # flag rather than Ollama's top-level `think`. Other callers retain
    # their existing backend behavior.
    if isinstance(config.get("enable_thinking"), bool):
        payload["chat_template_kwargs"] = {"enable_thinking": config["enable_thinking"]}

    schema = config.get("response_json_schema")
    if schema:
        payload["response_format"] = {
            "type": "json_schema",
            "json_schema": {"name": "javob", "schema": schema},
        }
    elif config.get("response_mime_type") == "application/json":
        payload["response_format"] = {"type": "json_object"}

    return payload


def _extract_chat_text(data: dict[str, Any]) -> str:
    """`/chat/completions` javobidan matnni oladi."""
    choices = data.get("choices") or []
    if not choices:
        return ""
    message = choices[0].get("message") or {}
    text = _strip_thinking_markup(message.get("content") or "")
    if not text and message.get("reasoning"):
        # Ba'zi modellar butun javobni `reasoning` ga yozadi — yo'qotmaymiz.
        text = _strip_thinking_markup(message["reasoning"])
    return text.strip()


def _stream_line(line: str) -> tuple[str, bool]:
    """Oqimning bitta qatoridan (matn bo'lagi, tugadimi) ni ajratadi.

    Ikki format:
      Ollama — NDJSON: har qator to'liq JSON, oxirgisida `done: true`;
      vLLM   — SSE:    `data: {...}` qatorlari, oxirida `data: [DONE]`.
    """
    line = line.strip()
    if not line:
        return "", False

    if _use_vllm():
        if not line.startswith("data:"):
            return "", False
        line = line[len("data:"):].strip()
        if line == "[DONE]":
            return "", True

    try:
        chunk = json.loads(line)
    except json.JSONDecodeError:
        return "", False

    if chunk.get("error"):
        raise OllamaClientError(f"LLM xatosi: {chunk['error']}")

    if _use_vllm():
        choices = chunk.get("choices") or []
        if not choices:
            return "", False
        delta = choices[0].get("delta") or {}
        return delta.get("content") or "", bool(choices[0].get("finish_reason"))

    return chunk.get("response") or "", bool(chunk.get("done"))


def _timeout_for(config: dict[str, Any] | None) -> float:
    """Chaqiruv muhlati: config'da berilgan bo'lsa o'sha, aks holda umumiysi."""
    value = (config or {}).get("timeout")
    return float(value) if value else DEFAULT_TIMEOUT


def _strip_thinking_markup(text: str) -> str:
    """Thinking modellari qo'shadigan <think>...</think> bloklarini olib tashlaydi."""
    return _THINKING_RE.sub("", text or "").strip()


def _mark_ollama_down() -> None:
    global _down_until
    _down_until = time.monotonic() + _DOWN_COOLDOWN_SECONDS


def _is_marked_down() -> bool:
    return time.monotonic() < _down_until


def _clear_down() -> None:
    global _down_until
    _down_until = 0.0


def _generate_endpoint() -> str:
    """Matn generatsiya qilinadigan manzil."""
    if _use_vllm():
        return f"{_base_url()}/chat/completions"
    return f"{OLLAMA_BASE_URL}/api/generate"


def _payload_for(
    prompt: str, config: dict[str, Any] | None, *, stream: bool
) -> dict[str, Any]:
    """Amaldagi backend uchun payload."""
    builder = _build_chat_payload if _use_vllm() else _build_payload
    return builder(prompt, config, stream=stream)


def _models_endpoint() -> tuple[str, str]:
    """Modellar ro'yxati manzili va javobdagi ro'yxat kaliti.

    vLLM: `/v1/models` -> {"object": "list", "data": [...]}
    Ollama: `/api/tags` -> {"models": [...]}
    """
    if _use_vllm():
        return f"{_base_url()}/models", "data"
    return f"{OLLAMA_BASE_URL}/api/tags", "models"


def check_ollama_alive_sync() -> bool:
    """Tezkor health-check — uzoq timeout kutmaslik uchun.

    Faqat status kodini tekshirish YETARLI EMAS: ngrok tunneli o'lganda o'z
    404 HTML sahifasini qaytaradi, ya'ni "5xx emas" degani Ollama tirik degani
    emas. Shuning uchun javob JSON bo'lishi va `models` kaliti borligi ham
    tekshiriladi.
    """
    if _is_marked_down():
        return False
    path, key = _models_endpoint()
    try:
        with httpx.Client(timeout=10.0, verify=_verify_ssl()) as client:
            response = client.get(path, headers=_build_headers())
        if response.status_code != 200:
            logger.warning(
                "LLM %s status %s qaytardi", path, response.status_code,
            )
            _mark_ollama_down()
            return False
        payload = response.json()
        if not isinstance(payload, dict) or key not in payload:
            logger.warning(
                "LLM serveri emas: %s JSON'da '%s' yo'q. URL boshqa servisga "
                "(masalan o'lgan ngrok tunneliga) ishlayapti.", path, key,
            )
            _mark_ollama_down()
            return False
        _clear_down()
        return True
    except Exception as exc:  # noqa: BLE001 — health-check hech qachon otmasin
        logger.warning("LLM health-check muvaffaqiyatsiz: %s", exc)
        _mark_ollama_down()
        return False


def keep_model_warm() -> bool:
    """Modelni Ollama xotirasida (VRAM) issiq ushlaydi.

    NIMA UCHUN KERAK (31.07.2026 o'lchovi):
        model issiq bo'lsa   -> chaqiruv 1.9 s (yuklash 0.1 s)
        model siqib chiqarilgan bo'lsa -> yuklash 14-34 s
    `keep_alive` ishlaydi, lekin server boshqa ish bilan bo'lishilgan: birov
    boshqa modelni yuklasa, bizniki VRAM dan chiqib ketadi. Buni to'sib
    bo'lmaydi, ammo QAYTA YUKLASHNI FOYDALANUVCHI KUTAYOTGAN PAYTGA emas,
    fonga surish mumkin — shu funksiya buni qiladi.

    Eng arzon usul: bo'sh prompt bilan chaqiruv (num_predict=0). Ollama
    modelni yuklaydi va hech narsa generatsiya qilmaydi.
    """
    if not _warm_needed():
        # Yaqinda haqiqiy so'rov bo'ldi — model ham, kesh ham issiq.
        return True

    # HAR BIR ishlatiladigan model uchun o'z prefiksi yuboriladi. SQL va javob
    # alohida modellarda bo'lishi mumkin; javob modeli sovuq qolsa,
    # foydalanuvchi SQL ni tez oladi-yu, javobni 15-35 s kutadi.
    ok = True
    try:
        with httpx.Client(timeout=180.0, verify=_verify_ssl()) as client:
            for model, prefix in get_warm_prefixes().items():
                if _use_vllm():
                    # vLLM modelni xotiradan tushirmaydi, ammo PREFIKS KESHI
                    # (automatic prefix caching) baribir foyda beradi: prompt
                    # boshini qayta o'qish kerak bo'lmaydi. `max_tokens: 0`
                    # vLLM'da xato, shuning uchun 1 ta token so'raymiz.
                    body = _build_chat_payload(
                        prefix,
                        {"model": model, "options": {"num_predict": 1}},
                        stream=False,
                    )
                else:
                    body = {
                        "model": model,
                        # Bo'sh emas, HAQIQIY prefiks: model VRAM da qolishi
                        # bilan birga promptning o'zgarmas boshi ham KV-keshda
                        # issiq turadi. `num_predict: 0` — matn generatsiya
                        # qilinmaydi, faqat prompt o'qiladi.
                        "prompt": prefix,
                        "stream": False,
                        "keep_alive": OLLAMA_KEEP_ALIVE,
                        "options": {"num_predict": 0, "num_ctx": DEFAULT_NUM_CTX},
                        "think": False,
                    }
                response = client.post(
                    _generate_endpoint(), headers=_build_headers(), json=body,
                )
                ok = ok and response.status_code == 200
        return ok
    except Exception as exc:  # noqa: BLE001 — fon vazifasi hech qachon otmasin
        logger.debug("Modelni issiq ushlash muvaffaqiyatsiz: %s", str(exc)[:120])
        return False


def start_model_warmer(interval_seconds: int | None = None) -> threading.Thread | None:
    """Fonda modelni issiq ushlab turadigan oqim.

    `.env` da `CHATBOT_MODEL_WARMER=off` bo'lsa oqim UMUMAN ishga tushmaydi
    va `None` qaytadi — chaqiruvchi log'da nima bo'lganini aniq ayta olsin.
    Tekshiruv aynan SHU YERDA, halqa ichida emas: o'chirilgan isitgich
    hech qanday oqim ham, uyg'onib turadigan `sleep` ham qoldirmasligi kerak.
    """
    if not MODEL_WARMER:
        logger.info("Model isitgichi o'chirilgan (CHATBOT_MODEL_WARMER=off)")
        return None

    delay = MODEL_WARMER_SECONDS if interval_seconds is None else interval_seconds

    def loop() -> None:
        while True:
            keep_model_warm()
            time.sleep(delay)

    thread = threading.Thread(target=loop, name="llm-warmer", daemon=True)
    thread.start()
    return thread


def installed_models() -> list[str]:
    """Serverda o'rnatilgan modellar ro'yxati (health endpoint uchun)."""
    path, key = _models_endpoint()
    # vLLM model nomini `id` da, Ollama esa `name` da beradi.
    field = "id" if _use_vllm() else "name"
    try:
        with httpx.Client(timeout=10.0, verify=_verify_ssl()) as client:
            response = client.get(path, headers=_build_headers())
            response.raise_for_status()
        return [m[field] for m in response.json().get(key, []) if m.get(field)]
    except Exception:  # noqa: BLE001
        return []


def _extract_text(data: dict[str, Any]) -> str:
    """/api/generate javobidan matnni oladi (thinking modellarini ham hisobga olib)."""
    text = _strip_thinking_markup(data.get("response") or "")
    if not text and data.get("thinking"):
        # Ba'zi modellar butun javobni `thinking` ga yozib, `response` ni bo'sh
        # qoldiradi — javobni yo'qotmaymiz.
        text = _strip_thinking_markup(data["thinking"])
    return text.strip()


def _is_json_response(response: httpx.Response) -> bool:
    """Javob LLM serveridan kelganmi yoki boshqa servisdanmi.

    Ngrok tunneli o'lganda o'zining 404 HTML sahifasini qaytaradi. Uni
    "model topilmadi" deb talqin qilish noto'g'ri maslahatga olib keladi
    (`ollama pull ...`), holbuki model joyida, URL ishlamayapti.
    """
    content_type = (response.headers.get("content-type") or "").lower()
    return "json" in content_type


def _raise_for_response(response: httpx.Response, payload: dict[str, Any]) -> None:
    if response.status_code < 400:
        return

    base = _base_url()
    setting = "VLLM_BASE_URL" if _use_vllm() else "OLLAMA_BASE_URL"

    if response.status_code >= 500:
        raise OllamaClientError(
            f"LLM serveri yoki proksi vaqtincha javob bera olmayapti "
            f"(status {response.status_code}). Keyinroq qayta urinib ko'ring."
        )

    if not _is_json_response(response):
        raise OllamaClientError(
            f"'{base}' manzili LLM serveri emas — javob HTML qaytdi "
            f"(status {response.status_code}). Ngrok tunneli o'lgan yoki URL "
            f"o'zgargan bo'lishi mumkin. .env dagi {setting} ni yangilang."
        )

    if response.status_code in (401, 403):
        raise OllamaClientError(
            f"LLM serveri kalitni qabul qilmadi (status {response.status_code}). "
            ".env dagi VLLM_API_KEY ni tekshiring."
        )

    if response.status_code == 404:
        if _use_vllm():
            # vLLM'da model nomi Ollama'nikidan boshqacha yoziladi
            # (`gemma4-31b`, `gemma4:31b` emas) — eng ko'p uchraydigan xato shu.
            raise OllamaClientError(
                f"vLLM'da bunday model yo'q: '{payload.get('model')}'. "
                f"Serverdagi aniq nomni ko'ring: GET {base}/models — "
                "vLLM nomlarida ikki nuqta emas, defis ishlatiladi. "
                ".env dagi VLLM_MODEL ni to'g'rilang."
            )
        raise OllamaClientError(
            f"Model topilmadi: '{payload.get('model')}'. "
            f"Serverda `ollama pull {payload.get('model')}` ni bajaring."
        )
    raise OllamaClientError(
        f"LLM xatosi {response.status_code}: {response.text[:400]}"
    )


async def ask_llm(
    prompt: str,
    config: dict[str, Any] | None = None,
    *,
    allow_fallback: bool = True,  # interfeys mosligi uchun saqlangan, ishlatilmaydi
) -> str:
    """Asosiy chaqiruv — node'lar shuni ishlatadi (asyncio.run bilan)."""
    timeout = _timeout_for(config)
    payload = _payload_for(prompt, config, stream=False)
    try:
        with _InFlight():
            async with httpx.AsyncClient(
                timeout=timeout, verify=_verify_ssl()
            ) as client:
                response = await client.post(
                    _generate_endpoint(),
                    headers=_build_headers(),
                    json=payload,
                )
            _raise_for_response(response, payload)
            data = response.json()
    except OllamaClientError:
        _mark_ollama_down()
        raise
    except httpx.ReadTimeout as exc:
        raise OllamaClientError(
            f"Model {timeout:.0f}s ichida javob bermadi "
            f"(model={payload.get('model')}). Kichikroq model tanlang yoki "
            "CHATBOT_OLLAMA_TIMEOUT_SECONDS ni oshiring."
        ) from exc
    except Exception as exc:  # noqa: BLE001
        _mark_ollama_down()
        raise OllamaClientError(
            f"LLM serveriga ulanib bo'lmadi ({_base_url()}): {exc}"
        ) from exc

    _clear_down()
    text = _extract_chat_text(data) if _use_vllm() else _extract_text(data)
    if not text:
        raise OllamaEmptyResponseError(
            f"Model bo'sh javob qaytardi (model={payload.get('model')})."
        )
    return text


async def stream_llm(
    prompt: str,
    config: dict[str, Any] | None = None,
) -> AsyncIterator[str]:
    """Javobni BO'LAKMA-BO'LAK qaytaradi (harflar ketma-ket chiqishi uchun).

    NIMA UCHUN KERAK: bu serverda model sekundiga 4-16 token yozadi. 120
    so'zlik batafsil javob to'liq tayyor bo'lishini kutish 20-40 soniya, ya'ni
    foydalanuvchi ekranga tikilib turadi. Oqim bilan BIRINCHI HARF ~1 soniyada
    chiqadi va matn o'sib boradi — kutish HIS QILINMAYDI va javobni qisqartirish
    kerak bo'lmaydi.

    Ollama `stream: true` da har bo'lakni ALOHIDA QATORDA, JSON obyekt qilib
    yuboradi (NDJSON). Oxirgi qatorda `done: true` keladi.

    Thinking bloklari bu yerda KESILMAYDI: `<think>` teglari bo'laklarga
    bo'linib ketishi mumkin, ya'ni regexni oqimga qo'llash ishonchsiz.
    `_build_payload` da `think=False` — shuning uchun ular umuman kelmaydi.
    """
    timeout = _timeout_for(config)
    payload = _payload_for(prompt, config, stream=True)
    completed = False
    has_text = False
    try:
        # Butun OQIM davomida isitgich to'xtaydi: javob 20-40 soniya
        # yozilishi mumkin va o'sha paytda 10 000 tokenlik isitish
        # so'rovi yuborilsa, Ollama navbati oqimni to'xtatib qo'yadi.
        with _InFlight():
            async with httpx.AsyncClient(
                timeout=timeout, verify=_verify_ssl()
            ) as client:
                async with client.stream(
                    "POST",
                    _generate_endpoint(),
                    headers=_build_headers(),
                    json=payload,
                ) as response:
                    if response.status_code >= 400:
                        # Xato tanasi oqimda kelgani uchun avval o'qib olamiz —
                        # `_raise_for_response` matnga murojaat qiladi.
                        await response.aread()
                        _raise_for_response(response, payload)

                    async for line in response.aiter_lines():
                        piece, done = _stream_line(line)
                        if piece:
                            has_text = has_text or bool(piece.strip())
                            yield piece
                        if done:
                            completed = True
                            break
                    if not completed:
                        raise OllamaClientError("Model javob oqimi tugamasdan uzildi.")
                    if not has_text:
                        raise OllamaEmptyResponseError(
                            f"Model bo'sh javob qaytardi (model={payload.get('model')})."
                        )
    except OllamaClientError:
        _mark_ollama_down()
        raise
    except httpx.ReadTimeout as exc:
        raise OllamaClientError(
            f"Model {timeout:.0f}s ichida javob bermadi "
            f"(model={payload.get('model')})."
        ) from exc
    except Exception as exc:  # noqa: BLE001
        _mark_ollama_down()
        raise OllamaClientError(
            f"LLM serveriga ulanib bo'lmadi ({_base_url()}): {exc}"
        ) from exc

    _clear_down()

