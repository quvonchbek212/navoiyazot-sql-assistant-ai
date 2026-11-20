"""LangGraph orkestratsiyasi — LIMS AI yordamchisi.

Oqim:

    START
      │
      ▼
   ┌────────┐  bloklandi   ┌─────────┐
   │ screen │─────────────►│ blocked │──► END
   └───┬────┘              └─────────┘
       │ toza
       ▼
   ┌──────────┐  router + jadval tanlash (bitta LLM chaqiruvi)
   │ classify │
   └────┬─────┘
        ├──► database ──┐
        ├──► chitchat ──┼──► END
        └──► refuse  ───┘

`screen` — xavfsizlik filtri: buzg'unchi niyat, prompt-injection va maxfiy
ma'lumot ovlash urinishlari LLM ga yetib bormasdan bloklanadi.
`database` — Text-to-SQL (sql_service) + javob. Javob = LLM xulosasi (savolga
to'g'ridan-to'g'ri javob) + natija ro'yxati (answer_format — kod yozadi, har bir
nom va son bazadagidek). Xulosadagi har bir son natijada borligi tekshiriladi;
aks holda qoidaga asoslangan javob beriladi. Javob — toza oddiy matn, `lang`
tilida (uz/ru/en): LLM ga javob tili aytiladi, tayyor xabarlar prompts.MESSAGES dan.

/api/chat/stream tinglayotgan bo'lsa (streaming.active()), javobni yozuvchi LLM
tokenlari foydalanuvchiga kelishi bilan yuboriladi; xulosadagi sonlar oqimda
ham tekshiriladi (NumberGuard) — natijada yo'q son ekranga chiqmaydi.
"""
from __future__ import annotations

import asyncio
import contextlib
import json
import logging
import re
import time
from typing import Annotated, Any, TypedDict

from langgraph.graph import END, START, StateGraph

from . import streaming
from .answer_format import clean_text, display_rows, fallback_answer, format_rows, strip_symbols
from .config import Settings
from .llm import LlmClient
from .prompts import (
    CHITCHAT_SYSTEM,
    DEFAULT_LANG,
    SUMMARY_SYSTEM,
    blocked_message,
    build_router_prompt,
    message,
    with_language,
)
from .schema_provider import SchemaProvider
from .security import screen_question
from .sql_service import SqlService, history_block
from .sql_catalog import find_match

logger = logging.getLogger("graph")

ANSWER_ROUTES = ("database", "chitchat", "refuse")
GRAPH_ROUTES = (*ANSWER_ROUTES, "parts")
# Javob uzunligi chegaralari (token). Kechikishning asosiy qismi — model yozadigan
# tokenlar soni, shuning uchun har bosqichga kerakligicha beriladi.
ROUTER_MAX_TOKENS = 120
SUMMARY_MAX_TOKENS = 260
CHITCHAT_MAX_TOKENS = 250
_JSON_RE = re.compile(r"\{[^{}]*\}", re.DOTALL)
_NUM_RE = re.compile(r"\d+(?:[.,]\d+)?")
_INT_RE = re.compile(r"\d+")


def _merge(a: dict | None, b: dict | None) -> dict:
    return {**(a or {}), **(b or {})}


class GraphState(TypedDict, total=False):
    question: str
    lang: str  # javob tili: uz / ru / en
    history: list[dict[str, Any]]
    route: str
    route_reason: str
    tables: list[str]
    blocked_category: str
    answer: str
    sql: str | None
    columns: list[str]
    rows: list[Any]
    row_count: int
    total_count: int | None
    truncated: bool
    fast_path: bool
    warnings: list[str]
    error: str | None
    timings: Annotated[dict[str, float], _merge]  # bosqich → soniya (tugunlar qo'shib boradi)
    clarify: str | None
    pagination_sql: str | None
    attempts: int


def _result_payload(res: dict[str, Any], cap: int, lang: str) -> str:
    return json.dumps(
        {
            "columns": res.get("columns"),
            "row_count": res.get("row_count"),
            "total_count": res.get("total_count"),
            "truncated": res.get("truncated", False),
            "totals": display_rows([res["totals"]], lang)[0] if res.get("totals") else None,
            "rows": display_rows((res.get("rows") or [])[:cap], lang),
        },
        ensure_ascii=False,
        default=str,
    )


def _norm_num(n: str) -> str:
    n = n.replace(",", ".")
    if "." in n:
        n = n.rstrip("0").rstrip(".")
    return n.lstrip("0") or "0"


def unsupported_numbers(answer: str, *sources: str) -> list[str]:
    """Detect unsupported numbers, including every single digit."""
    allowed = _allowed_numbers(*sources)
    return [n for n in _NUM_RE.findall(answer or "") if _is_unsupported(n, allowed)]


def _allowed_numbers(*sources: str) -> set[str]:
    # Butun qismlar ham: «18.09.2026» dan «18» («18 sentabr»), «10:23» dan «10».
    return {_norm_num(n) for src in sources for rx in (_NUM_RE, _INT_RE) for n in rx.findall(src or "")}


def _is_unsupported(n: str, allowed: set[str]) -> bool:
    return _norm_num(n) not in allowed


class NumberGuard:
    """Oqimdagi xulosani son-son tekshiradi — natijada yo'q son ekranga chiqmaydi.

    Oxiridagi tugallanmagan son («12» → «12,5» bo'lishi mumkin) keyingi bo'lak
    kelguncha ushlab turiladi. Natijada yo'q son chiqsa `bad` o'rnatiladi va
    matn boshqa chiqarilmaydi.
    """

    _TAIL = re.compile(r"\d+(?:[.,]\d*)?$")

    def __init__(self, *sources: str):
        self._allowed = _allowed_numbers(*sources)
        self._text = ""
        self._sent = 0
        self.bad: str | None = None

    def feed(self, chunk: str, *, final: bool = False) -> str:
        """Yuborish xavfsiz bo'lgan yangi matn ('' — hozircha yo'q yoki son rad etildi)."""
        if self.bad is not None:
            return ""
        self._text += chunk
        tail = None if final else self._TAIL.search(self._text, self._sent)
        ready = max(tail.start() if tail else len(self._text), self._sent)
        for m in _NUM_RE.finditer(self._text, self._sent, ready):
            if _is_unsupported(m.group(0), self._allowed):
                self.bad = m.group(0)
                return ""
        out, self._sent = self._text[self._sent:ready], ready
        return out


def _lang(state: GraphState) -> str:
    return state.get("lang") or DEFAULT_LANG


def _base_out(res: dict[str, Any]) -> dict[str, Any]:
    return {
        "sql": res.get("sql"),
        "columns": res.get("columns", []),
        "rows": res.get("rows", []),
        "row_count": res.get("row_count", 0),
        "total_count": res.get("total_count"),
        "truncated": res.get("truncated", False),
        "fast_path": res.get("fast_path", False),
        "warnings": res.get("warnings", []),
        "error": res.get("error"),
        "pagination_sql": res.get("pagination_sql"),
        "tables": res.get("tables", []),
        "attempts": res.get("attempts", 0),
    }


class AssistantGraph:
    def __init__(self, settings: Settings, llm: LlmClient, sql: SqlService, schema: SchemaProvider):
        self._s = settings
        self._llm = llm
        self._sql = sql
        self._schema = schema
        self._graph = self._build()

    # ---------------- 1. Xavfsizlik filtri ----------------
    async def screen(self, state: GraphState) -> dict[str, Any]:
        verdict = screen_question(state["question"])
        if verdict.blocked:
            logger.warning("So'rov bloklandi [%s]: %r", verdict.category, verdict.detail[:60])
            return {"route": "blocked", "blocked_category": verdict.category,
                    "route_reason": f"xavfsizlik: {verdict.category}"}
        return {}

    def _screen_selector(self, state: GraphState) -> str:
        return "blocked" if state.get("route") == "blocked" else "classify"

    async def blocked_node(self, state: GraphState) -> dict[str, Any]:
        return {"answer": blocked_message(state.get("blocked_category", ""), _lang(state))}

    # ---------------- 2. Router + jadval tanlash ----------------
    async def classify(self, state: GraphState) -> dict[str, Any]:
        # GitLab's parts passport/forecast fast path runs inside the current
        # graph, after security screening; the retired pipeline stays removed.
        try:
            from parts_control import chat as parts_chat
            if parts_chat.detect(state["question"]) is not None:
                t0 = time.monotonic()
                parts = await asyncio.to_thread(parts_chat.answer, state["question"], _lang(state))
                if parts is not None:
                    table = parts.get("table") or {}
                    columns = table.get("columns") or []
                    labels = {c["key"]: c.get("label") or c["key"] for c in columns}
                    rows = [{labels.get(k, k): v for k, v in row.items()} for row in table.get("rows") or []]
                    return {"route": "parts", "route_reason": "ehtiyot qismlar hisobi",
                            "answer": parts["answer"], "columns": list(labels.values()), "rows": rows,
                            "row_count": len(rows), "total_count": table.get("total_row_count", len(rows)),
                            "timings": self._timing("parts_" + parts["kind"], t0)}
        except Exception as exc:  # noqa: BLE001 — preserve the normal SQL fallback
            logger.warning("Ehtiyot qismlar javobi olinmadi: %s", type(exc).__name__)
        entry = find_match(state["question"]) if not state.get("history") and _lang(state) == "uz" else None
        if entry:
            return {"route": "database", "route_reason": "tekshirilgan savol", "tables": list(entry.tables)}
        try:
            system = build_router_prompt(await self._schema.listing(state["question"]))
            user = history_block(state.get("history")) + f"Savol: {state['question']}"
            t0 = time.monotonic()
            raw = await self._llm.chat(system, user, temperature=0, max_tokens=ROUTER_MAX_TOKENS)
            timings = self._timing("router", t0)
        except Exception as exc:  # noqa: BLE001
            logger.warning("Router xatosi, 'database' ga o'tildi: %s", exc)
            return {"route": "database", "route_reason": "router xatosi", "tables": []}

        route, reason, tables = "database", "standart", []
        for m in _JSON_RE.finditer(raw or ""):
            try:
                data = json.loads(m.group(0))
            except json.JSONDecodeError:
                continue
            candidate = str(data.get("route", "")).lower().strip()
            if candidate in ANSWER_ROUTES:
                selected = data.get("tables") or []
                if not isinstance(selected, list) or any(not isinstance(t, str) for t in selected):
                    continue
                tables = [t.strip() for t in selected if t.strip()][:6]
                route = candidate
                reason = str(data.get("reason") or ", ".join(tables))[:120]
                break
        else:
            low = (raw or "").lower()
            for r in ANSWER_ROUTES:
                if r in low:
                    route, reason = r, "matndan aniqlandi"
                    break
        logger.info("Router → %s (%s) jadvallar=%s", route, reason, tables)
        return {"route": route, "route_reason": reason, "tables": tables, "timings": timings}

    def _route_selector(self, state: GraphState) -> str:
        route = state.get("route", "database")
        return route if route in GRAPH_ROUTES else "database"

    async def parts_node(self, state: GraphState) -> dict[str, Any]:
        streaming.delta(state["answer"])
        return {"answer": state["answer"]}

    # ---------------- 3. Database ----------------
    async def database_node(self, state: GraphState) -> dict[str, Any]:
        t0 = time.monotonic()
        lang = _lang(state)
        res = await self._sql.run(state["question"], state.get("tables"), state.get("history"), lang)
        out = _base_out(res)
        out["timings"] = self._timing("sql", t0)
        if res.get("error"):
            out["answer"] = message(res.get("error_kind") or "service_error", lang)
            return out
        if res.get("clarify"):
            out["answer"] = clean_text(res["clarify"])
            out["clarify"] = out["answer"]
            return out

        # Counts and scalar values are rendered from the DB, never rewritten by a model.
        if len(res.get("rows") or []) <= 1:
            out["answer"] = fallback_answer(res, lang)
            streaming.delta(out["answer"])
            return out

        # Javob = LLM xulosasi (savolga to'g'ridan-to'g'ri javob) + ro'yxat (kod yozadi — aniq va to'liq).
        payload = _result_payload(res, self._s.max_rows_to_model, lang)
        user = f"Savol: {state['question']}\nSQL: {res.get('sql')}\nNatija: {payload}"
        t0 = time.monotonic()
        lead = await self._answer(with_language(SUMMARY_SYSTEM, lang), user, fallback="",
                                  max_tokens=SUMMARY_MAX_TOKENS,
                                  guard=NumberGuard())
        out["timings"].update(self._timing("summary", t0))
        # Numeric claims belong to the deterministic listing. A number occurring
        # elsewhere in the question or metadata is not proof of its meaning.
        bad = unsupported_numbers(lead)
        if not lead or bad:
            if bad:
                logger.warning("Xulosada natijada yo'q sonlar: %s — qoidaviy javob", bad)
            out["answer"] = fallback_answer(res, lang)
            streaming.delta(out["answer"])
            return out
        listing = format_rows(res, lang) if len(res.get("rows") or []) > 1 else ""
        if listing:
            streaming.delta("\n\n" + listing)
        out["answer"] = f"{lead}\n\n{listing}" if listing else lead
        return out

    # ---------------- 4. Chitchat / Refuse ----------------
    async def chitchat_node(self, state: GraphState) -> dict[str, Any]:
        return {"answer": await self._answer(
            with_language(CHITCHAT_SYSTEM, _lang(state)), state["question"], max_tokens=CHITCHAT_MAX_TOKENS,
            fallback=message("chitchat_fallback", _lang(state)),
        )}

    async def refuse_node(self, state: GraphState) -> dict[str, Any]:
        return {"answer": message("refuse", _lang(state))}

    # ---------------- yordamchi ----------------
    @staticmethod
    def _timing(stage: str, t0: float) -> dict[str, float]:
        """Bosqich vaqti — logga va holatga (sekin joyni topish uchun)."""
        sec = round(time.monotonic() - t0, 2)
        logger.info("⏱ %s: %.2fs", stage, sec)
        return {stage: sec}

    async def _answer(self, system: str, user: str, *, fallback: str, max_tokens: int,
                      guard: NumberGuard | None = None) -> str:
        """Foydalanuvchiga ko'rinadigan javob. Oqim tinglanayotgan bo'lsa — tokenlab yuboriladi.

        Yakuniy matn `result` hodisasida baribir keladi: oqim o'rtada uzilsa yoki son
        rad etilsa, mijoz ko'rgan qism yakuniy javob bilan almashtiriladi.
        """
        if not streaming.active():
            return await self._safe_chat(system, user, fallback=fallback, max_tokens=max_tokens)
        parts: list[str] = []
        sent = False
        try:
            async with contextlib.aclosing(self._llm.chat_stream(system, user, max_tokens=max_tokens)) as tokens:
                async for token in tokens:
                    parts.append(token)
                    text = guard.feed(token) if guard else token
                    if guard and guard.bad:
                        # aclosing LLM oqimini yopadi — generatsiya shu yerda to'xtaydi.
                        logger.warning("Xulosada natijada yo'q son %r — oqim to'xtatildi", guard.bad)
                        return ""
                    text = strip_symbols(text)
                    if not sent:
                        text = text.lstrip()
                    if text:
                        streaming.delta(text)
                        sent = True
            if guard:
                text = strip_symbols(guard.feed("", final=True))  # ushlab turilgan oxirgi son
                if guard.bad:
                    return ""
                streaming.delta(text if sent else text.lstrip())
        except Exception as exc:  # noqa: BLE001
            logger.warning("LLM javob bermadi: %s", exc)
            return fallback
        return clean_text("".join(parts)) or fallback

    async def _safe_chat(self, system: str, user: str, *, fallback: str,
                         max_tokens: int | None = None) -> str:
        try:
            text = await self._llm.chat(system, user, max_tokens=max_tokens)
            return clean_text(text) or fallback
        except Exception as exc:  # noqa: BLE001
            logger.warning("LLM javob bermadi: %s", exc)
            return fallback

    # ---------------- qurish ----------------
    def _build(self):
        g = StateGraph(GraphState)
        g.add_node("screen", self.screen)
        g.add_node("blocked", self.blocked_node)
        g.add_node("classify", self.classify)
        g.add_node("database", self.database_node)
        g.add_node("chitchat", self.chitchat_node)
        g.add_node("refuse", self.refuse_node)
        g.add_node("parts", self.parts_node)

        g.add_edge(START, "screen")
        g.add_conditional_edges(
            "screen", self._screen_selector,
            {"blocked": "blocked", "classify": "classify"},
        )
        g.add_conditional_edges(
            "classify", self._route_selector, {r: r for r in GRAPH_ROUTES}
        )
        g.add_edge("blocked", END)
        for node in GRAPH_ROUTES:
            g.add_edge(node, END)
        return g.compile()

    async def run(self, question: str, history: list[dict[str, Any]] | None = None,
                  lang: str = DEFAULT_LANG) -> GraphState:
        state: GraphState = {
            "question": question, "lang": lang, "history": history or [], "warnings": [],
            "columns": [], "rows": [], "row_count": 0, "tables": [], "timings": {},
        }
        return await self._graph.ainvoke(state)
