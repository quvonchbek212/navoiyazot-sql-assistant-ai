"""ATIL chatbot endpointlari — ildizdagi `main.py` ga router sifatida ulanadi.

Endpointlar (hammasi HTTP Basic bilan yopiq — ildizdagi security.py):
    POST /api/chat          { "question": "...", "session_id": "..." }  → xavfsizlik → router → javob
                            (har bir savol-javob suhbat xotirasiga yoziladi — memory.py)
    POST /api/chat/stream   xuddi shu, lekin javob matni bo'laklab keladi (SSE, streaming.py)
    GET  /api/schema        sxema manbasi haqida ma'lumot
    GET  /healthz           holat
"""
from __future__ import annotations

import asyncio
import contextlib
import json
import hashlib
import logging
import pathlib
import time
import uuid
from collections.abc import AsyncIterator
from typing import Any

import anyio
from fastapi import APIRouter, FastAPI, HTTPException, Request
from fastapi.responses import StreamingResponse, JSONResponse

from . import streaming
from .config import Settings, get_settings
from .db_client import DbClient
from .graph import AssistantGraph
from .llm import LlmClient
from .memory import ChatMemory, PgChatMemory, Turn, create_memory
from .pagination import PAGE_SIZE, QueryPages
from .prompts import DEFAULT_LANG
from .schema_provider import SchemaProvider
from .schemas import ChatRequest, ChatResponse, PageRequest, PageResponse
from .sql_service import SqlService
from .sql_validator import validate

logger = logging.getLogger("api")

HEARTBEAT_SECONDS = 10  # oqim jim qolsa shuncha soniyada `: ping` — proksi ulanishni uzmasin


@contextlib.asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    llm = LlmClient(settings)
    db = DbClient(settings)
    schema_provider = SchemaProvider(settings, db)
    sql = SqlService(settings, llm, db, schema_provider)

    app.state.settings = settings
    app.state.llm = llm
    app.state.db = db
    app.state.schema_provider = schema_provider
    app.state.graph = AssistantGraph(settings, llm, sql, schema_provider)
    memory = create_memory(settings)
    memory.open()
    app.state.memory = memory
    app.state.pages = QueryPages()

    schema_file = pathlib.Path(settings.schema_file)
    logger.info(
        "Tayyor. LLM=%s | schema.json=%s | login=%s | xotira=%s",
        settings.vllm_model,
        "bor" if schema_file.is_file() else "YO'Q (jonli introspeksiya — aniqlik past)",
        "sozlangan" if (settings.api_username and settings.api_password) or settings.api_accounts else "SOZLANMAGAN (barcha so'rov rad etiladi)",
        f"postgres ({settings.chat_db_host}/{settings.chat_db_name})" if settings.chat_db_enabled
        else "jarayon ichida (CHAT_DB_HOST yo'q — qayta ishga tushsa yo'qoladi)",
    )
    try:
        yield
    finally:
        try:
            await memory.close()
        finally:
            await llm.close()


router = APIRouter(lifespan=lifespan)


@router.get("/healthz", tags=["Holat"], summary="Xizmat holati")
async def healthz(request: Request):
    s: Settings = request.app.state.settings
    db: DbClient = request.app.state.db
    async def probe(fn):
        try:
            return bool(await fn())
        except Exception:
            return False
    memory: ChatMemory | PgChatMemory = request.app.state.memory
    db_ok, llm_ok, memory_ok = await asyncio.gather(
        probe(db.ping), probe(request.app.state.llm.ping), probe(memory.ping),
    )
    provider = request.app.state.schema_provider
    schema_ok = bool(await probe(provider.catalog))
    schema_ok = schema_ok and (s.schema_refresh_seconds <= 0 or provider.live_verified)
    ready = db_ok and llm_ok and memory_ok and schema_ok
    return JSONResponse(status_code=200 if ready else 503, content={
        "status": "ok" if ready else "degraded",
        "llm_model": s.vllm_model,
        "llm_connected": llm_ok,
        "db_connected": db_ok,
        "schema_file_present": pathlib.Path(s.schema_file).is_file(),
        "memory_backend": memory.backend,
        "memory_ok": memory_ok,
        "schema_available": schema_ok,
        "schema_live_verified": provider.live_verified,
    })


@router.get("/api/schema", tags=["Holat"], summary="Baza sxemasi haqida ma'lumot")
async def schema_info(request: Request) -> dict[str, Any]:
    provider: SchemaProvider = request.app.state.schema_provider
    try:
        catalog = await provider.catalog()
    except Exception as exc:  # noqa: BLE001
        logger.warning("Sxema mavjud emas: %s", type(exc).__name__)
        raise HTTPException(503, "Sxema vaqtincha mavjud emas") from exc
    return {
        "source": provider.source,
        "generated_at": catalog.generated_at,
        "total_tables": len(catalog.tables),
        "total_columns": sum(len(t.columns) for t in catalog.tables.values()),
    }


@router.post(
    "/api/chat",
    response_model=ChatResponse,
    tags=["Chat"],
    summary="Savolga bazadan javob",
    description=(
        "Savol o'zbek, rus yoki ingliz tilida yoziladi. Bot xavfsiz SELECT tuzadi, read-only "
        "bazada bajaradi va javobni (`answer`), natija jadvalini (`columns`, `rows`) va SQL ni qaytaradi.\n\n"
        "Bir xil `session_id` bilan yuborilgan savollar bitta suhbat hisoblanadi — "
        "davomli savollar («ulardan nechtasi…?») shunday ishlaydi. `session_id` "
        "yuborilmasa yangisi yaratiladi va javobda qaytadi.\n\n"
        "`lang` — javob tili: `uz` (standart), `ru`, `en`."
    ),
)
async def chat(body: ChatRequest, request: Request) -> ChatResponse:
    graph: AssistantGraph = request.app.state.graph
    memory: ChatMemory | PgChatMemory = request.app.state.memory
    session_id = body.session_id or uuid.uuid4().hex

    t0 = time.monotonic()
    memory_id = _memory_id(request, session_id)
    try:
        state = await graph.run(body.question, await memory.history(memory_id), body.lang)
    except Exception:
        logger.exception("Chat failed")
        raise HTTPException(503, "Javob tayyorlab bo'lmadi") from None
    await memory.add(memory_id, _turn(body.question, state, _ms(t0)))
    return _response(session_id, _with_cursor(request, state))


@router.post(
    "/api/chat/stream",
    tags=["Chat"],
    summary="Savolga javob — matn oqimi (SSE)",
    response_class=StreamingResponse,
    responses={200: {"content": {"text/event-stream": {}}, "description": "Server-Sent Events oqimi"}},
    description=(
        "`/api/chat` bilan bir xil, lekin javob matni yozilishi bilan bo'laklab keladi "
        "(`text/event-stream`) — foydalanuvchi to'liq javobni kutib qolmaydi.\n\n"
        "Hodisalar:\n"
        "- `start` — `{session_id}` (darhol)\n"
        "- `delta` — `{text}`: javobning navbatdagi bo'lagi (0 yoki ko'p marta; LLM yozadigan "
        "javoblarda). Bo'laklarni ketma-ket qo'shib boring.\n"
        "- `result` — `/api/chat` javobi bilan bir xil obyekt (oxirgi hodisa). `answer` — yakuniy "
        "matn: oldin kelgan bo'laklar o'rniga shuni ko'rsating (tekshiruvdan o'tmagan xulosa "
        "shu yerda almashtiriladi).\n"
        "- `error` — `{detail}` (kutilmagan xato; oxirgi hodisa)\n\n"
        f"Jim paytlarda har {HEARTBEAT_SECONDS} soniyada `: ping` izohi keladi (proksi ulanishni "
        "uzmasin). Mijoz uzilsa so'rov to'xtatiladi (LLM bekor ishlamaydi).\n\n"
        "Swagger oqimni oxirida birdaniga ko'rsatadi — jonli ko'rish uchun frontend yoki `curl -N`."
    ),
)
async def chat_stream(body: ChatRequest, request: Request) -> StreamingResponse:
    graph: AssistantGraph = request.app.state.graph
    memory: ChatMemory | PgChatMemory = request.app.state.memory
    session_id = body.session_id or uuid.uuid4().hex
    return StreamingResponse(
        _chat_events(graph, memory, body.question, session_id, body.lang,
                     memory_id=_memory_id(request, session_id), request=request),
        media_type="text/event-stream",
        # no-transform/X-Accel-Buffering — proksi (nginx) oqimni to'plab ushlab qolmasin.
        headers={"Cache-Control": "no-cache, no-transform", "X-Accel-Buffering": "no"},
    )


async def _chat_events(
    graph: AssistantGraph, memory: ChatMemory | PgChatMemory, question: str, session_id: str,
    lang: str = DEFAULT_LANG,
    *, memory_id: str | None = None, request: Request | None = None,
) -> AsyncIterator[str]:
    """Graf alohida taskda ishlaydi; javob bo'laklari (streaming.delta) navbat orqali oqimga o'tadi."""
    yield _sse("start", {"session_id": session_id})

    t0 = time.monotonic()
    loop = asyncio.get_running_loop()
    queue: asyncio.Queue[str | None] = asyncio.Queue()  # None — graf tugadi
    memory_id = memory_id or session_id
    history = await memory.history(memory_id)
    with streaming.listen(lambda text: loop.call_soon_threadsafe(queue.put_nowait, text)):
        task = asyncio.create_task(graph.run(question, history, lang))  # kontekst (tinglovchi) nusxalanadi
    task.add_done_callback(lambda _: loop.call_soon_threadsafe(queue.put_nowait, None))

    partial = ""  # mijozga yuborilgan qism (uzilsa xotiraga yoziladi)
    try:
        finished = False
        while not finished:
            try:
                item = await asyncio.wait_for(queue.get(), HEARTBEAT_SECONDS)
            except TimeoutError:
                yield ": ping\n\n"
                continue
            # Navbatda to'planib qolgan bo'laklar bitta hodisaga birlashtiriladi (kamroq yozuv).
            chunk = []
            while item is not None:
                chunk.append(item)
                if queue.empty():
                    break
                item = queue.get_nowait()
            finished = item is None
            if chunk:
                text = "".join(chunk)
                partial += text
                yield _sse("delta", {"text": text})

        try:
            state = task.result()
        except Exception as exc:  # noqa: BLE001 — tafsilot faqat logga
            logger.exception("Oqimli chat xatosi (%s)", session_id)
            await memory.add(memory_id, Turn(question=question, answer=partial, route="error",
                                              error=str(exc)[:500], duration_ms=_ms(t0)))
            yield _sse("error", {"detail": "Ichki xato yuz berdi — savolni qayta yuboring."})
            return
        # Avval yoziladi (bir necha ms): mijoz natijani olib darhol uzilsa ham savol yo'qolmaydi.
        await memory.add(memory_id, _turn(question, state, _ms(t0)))
        if request is not None:
            state = _with_cursor(request, state)
        yield _sse("result", _response(session_id, state).model_dump(mode="json"))
    finally:
        if not task.done():
            # Mijoz uzildi — graf (LLM, baza) bekor ishlamasin. Savol baribir yoziladi.
            task.cancel()
            logger.info("Mijoz uzildi, so'rov to'xtatildi (%s)", session_id)
            with anyio.CancelScope(shield=True):
                with contextlib.suppress(asyncio.CancelledError, Exception):
                    await task
                await memory.add(memory_id, Turn(
                    question=question, answer=partial, route="cancelled",
                    error="Mijoz javobni kutmasdan uzildi", duration_ms=_ms(t0),
                ))


def _sse(event: str, data: dict[str, Any]) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False, default=str)}\n\n"


def _ms(t0: float) -> int:
    return int((time.monotonic() - t0) * 1000)


def _memory_id(request: Request, session_id: str) -> str:
    principal = request.state.principal
    return hashlib.sha256(f"{principal}\0{session_id}".encode()).hexdigest()


def _with_cursor(request: Request, state: dict[str, Any]) -> dict[str, Any]:
    if state.get("truncated") and state.get("pagination_sql") and not state.get("error"):
        state["next_cursor"] = request.app.state.pages.add(
            state["pagination_sql"], state["columns"], state["row_count"], request.state.principal,
        )
    return state


@router.post("/api/chat/page", response_model=PageResponse, tags=["Chat"])
async def chat_page(body: PageRequest, request: Request) -> PageResponse:
    pages: QueryPages = request.app.state.pages
    try:
        page = pages.get(body.cursor, request.state.principal)
    except ValueError:
        raise HTTPException(404, "Sahifa muddati tugagan yoki mavjud emas") from None
    try:
        catalog = await request.app.state.schema_provider.catalog()
    except Exception:
        logger.exception("Page schema unavailable")
        raise HTTPException(503, "Sxema vaqtincha mavjud emas") from None
    try:
        query = pages.query(page)
    except ValueError:
        raise HTTPException(409, "Bu so'rovni sahifalab bo'lmaydi. Savolni qayta yuboring.") from None
    if validate(query, catalog):
        raise HTTPException(409, "Sxema o'zgargan. Asl savolni qayta yuboring.")
    try:
        result = await request.app.state.db.run_select(query)
    except Exception:
        logger.exception("Page query failed")
        raise HTTPException(503, "Sahifani olib bo'lmadi") from None
    rows = result["rows"][:PAGE_SIZE]
    cursor = None
    if len(result["rows"]) > PAGE_SIZE:
        cursor = pages.add(page.sql, list(page.columns), page.offset + len(rows), page.principal, page.expires_at)
    return PageResponse(columns=result["columns"], rows=rows, row_count=len(rows), next_cursor=cursor)


def _response(session_id: str, state: dict[str, Any]) -> ChatResponse:
    return ChatResponse(
        session_id=session_id,
        route=state.get("route", "database"),
        route_reason=state.get("route_reason", ""),
        blocked_category=state.get("blocked_category", ""),
        answer=state.get("answer", ""),
        sql=state.get("sql"),
        columns=state.get("columns", []),
        rows=state.get("rows", []),
        row_count=state.get("row_count", 0),
        total_count=state.get("total_count"),
        truncated=state.get("truncated", False),
        fast_path=state.get("fast_path", False),
        tables=state.get("tables", []),
        warnings=state.get("warnings", []),
        error="request_failed" if state.get("error") else None,
        next_cursor=state.get("next_cursor"),
        attempts=state.get("attempts", 0),
        timings=state.get("timings", {}),
    )


def _turn(question: str, state: dict[str, Any], duration_ms: int) -> Turn:
    """Graf natijasidan xotiraga yoziladigan yozuv (natija satrlarisiz)."""
    meta = {
        "lang": state.get("lang"),
        "route_reason": state.get("route_reason"),
        "blocked_category": state.get("blocked_category"),
        "tables": state.get("tables"),
        "total_count": state.get("total_count"),
        "truncated": state.get("truncated"),
        "fast_path": state.get("fast_path"),
        "warnings": state.get("warnings"),
        "timings": state.get("timings"),
        "clarification": state.get("clarify"),
    }
    return Turn(
        question=question,
        answer=state.get("answer", ""),
        route=state.get("route", "database"),
        sql=state.get("sql"),
        row_count=state.get("row_count"),
        error=state.get("error"),
        duration_ms=duration_ms,
        meta={k: v for k, v in meta.items() if v not in (None, "", [], {})},
    )
