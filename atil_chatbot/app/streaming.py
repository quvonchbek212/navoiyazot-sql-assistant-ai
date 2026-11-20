"""Javob matnini oqim bilan yuborish — `/api/chat/stream` uchun.

Javobni yozayotgan LLM tokenlari `delta(text)` bilan chiqariladi; oqim endpointi
`listen(callback)` bilan tinglaydi. Tinglovchi bo'lmasa (oddiy /api/chat)
`active()` False — graf odatdagi (oqimsiz) LLM chaqiruvini ishlatadi.

Tinglovchi ContextVar'da: har bir so'rov faqat o'z javobini oladi — bir vaqtdagi
so'rovlar aralashmaydi. `listen` ichida yaratilgan asyncio task (va LangGraph
uning ichida ochadigan tasklar) kontekst nusxasini oladi.
"""
from __future__ import annotations

import contextlib
from collections.abc import Callable, Iterator
from contextvars import ContextVar

Listener = Callable[[str], None]

_listener: ContextVar[Listener | None] = ContextVar("answer_listener", default=None)


def active() -> bool:
    return _listener.get() is not None


def delta(text: str) -> None:
    """Javobning navbatdagi bo'lagi."""
    listener = _listener.get()
    if listener is not None and text:
        listener(text)


@contextlib.contextmanager
def listen(callback: Listener) -> Iterator[None]:
    token = _listener.set(callback)
    try:
        yield
    finally:
        _listener.reset(token)
