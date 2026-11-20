"""Existing /chat clients use the LIMS graph through their original JSON/SSE contract."""
from __future__ import annotations

import contextlib
import json
import logging
import time
import uuid
from typing import Any

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel, Field

from .api import _chat_events, _memory_id, _sse, chat, healthz
from .schemas import ChatRequest

logger = logging.getLogger(__name__)
router = APIRouter()


class LegacyChatRequest(ChatRequest):
    stream: bool = Field(True, description="false: to'liq JSON; true: SSE oqimi")
    model_config = {"json_schema_extra": {"example": {
        "question": "Qaysi reyslar kechikayapti?", "stream": False, "lang": "uz",
    }}}


class LegacyChatResponse(BaseModel):
    answer: str
    session_id: str
    route: str
    sql_query: str | None = None
    sql_source: str | None = None
    table: dict[str, Any] | None = None
    chosen_tables: list[str] = Field(default_factory=list)
    row_count: int | None = None
    error_feedback: str | None = None
    attempts: int = 0
    timings: dict[str, float] = Field(default_factory=dict)
    total_seconds: float = 0
    total_count: int | None = None
    truncated: bool = False
    next_cursor: str | None = None


def _legacy(result: dict[str, Any], started: float) -> dict[str, Any]:
    columns, rows = result.get("columns", []), result.get("rows", [])
    table = None
    if columns:
        table = {
            "title": "", "columns": [{"key": c, "label": c} for c in columns],
            "rows": rows, "row_count": len(rows),
            "total_row_count": result.get("total_count") if result.get("total_count") is not None else len(rows),
            "truncated": result.get("truncated", False), "limited": result.get("truncated", False),
        }
    return LegacyChatResponse(
        answer=result.get("answer", ""), session_id=result["session_id"],
        route="db" if result.get("route") == "database" else "parts" if result.get("route") == "parts" else "chat",
        sql_query=result.get("sql"),
        sql_source=("katalog" if result.get("fast_path") else "llm") if result.get("sql") else None,
        table=table, chosen_tables=result.get("tables", []),
        row_count=None if result.get("error") else result.get("row_count", 0),
        error_feedback=result.get("error"), attempts=result.get("attempts", 0),
        timings=result.get("timings", {}), total_seconds=round(time.monotonic() - started, 2),
        total_count=result.get("total_count"), truncated=result.get("truncated", False),
        next_cursor=result.get("next_cursor"),
    ).model_dump(mode="json")


@router.get("/health", include_in_schema=False)
async def health(request: Request):
    return await healthz(request)


@router.post(
    "/chat", tags=["Chat"], response_class=StreamingResponse,
    responses={200: {"model": LegacyChatResponse, "content": {"text/event-stream": {}},
        "description": "stream=false: JSON; SSE: stage, token, reset, sql, table, done, error. done.answer yakuniy matn."}},
)
async def legacy_chat(body: LegacyChatRequest, request: Request):
    started = time.monotonic()
    if not body.stream:
        result = await chat(body, request)
        return JSONResponse(_legacy(result.model_dump(mode="json"), started))

    async def events():
        text = ""
        session_id = body.session_id or uuid.uuid4().hex
        async with contextlib.aclosing(_chat_events(
            request.app.state.graph, request.app.state.memory, body.question, session_id, body.lang,
            memory_id=_memory_id(request, session_id), request=request,
        )) as source:
            async for frame in source:
                if frame.startswith(":"):
                    yield frame
                    continue
                event, data = frame.rstrip().split("\n", 1)
                kind = event.removeprefix("event: ")
                payload = json.loads(data.removeprefix("data: "))
                if kind == "start":
                    yield _sse("stage", {"stage": "tayyorgarlik", "session_id": session_id})
                elif kind == "delta":
                    text += payload["text"]
                    yield _sse("token", payload)
                elif kind == "result":
                    result = _legacy(payload, started)
                    if text != result["answer"]:
                        if text:
                            yield _sse("reset", {})
                        yield _sse("token", {"text": result["answer"]})
                    if result["sql_query"]:
                        yield _sse("sql", {"sql_query": result["sql_query"], "sql_source": result["sql_source"]})
                    if result["table"]:
                        yield _sse("table", {"table": result["table"], "row_count": result["row_count"]})
                    yield _sse("done", result)
                else:
                    yield _sse(kind, payload)

    return StreamingResponse(events(), media_type="text/event-stream",
        headers={"Cache-Control": "no-cache, no-transform", "X-Accel-Buffering": "no"})


@router.delete("/chat/{session_id}", tags=["Chat"], summary="Suhbat tarixini tozalash")
async def reset_session(session_id: str, request: Request):
    try:
        await request.app.state.memory.clear(_memory_id(request, session_id))
    except Exception:
        logger.exception("Session reset failed")
        raise HTTPException(503, "Suhbat tarixini tozalab bo'lmadi") from None
    return {"session_id": session_id, "status": "reset"}
