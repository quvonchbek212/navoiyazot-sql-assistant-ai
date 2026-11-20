"""API so'rov/javob modellari."""
from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field

from .prompts import DEFAULT_LANG, Lang


class ChatRequest(BaseModel):
    question: str = Field(
        ..., min_length=1, max_length=3000,
        examples=["Qaysi reyslar kechikayapti?"],
    )
    # Davomli savollar uchun suhbat identifikatori: bir xil qiymat — bitta suhbat.
    session_id: str | None = Field(
        default=None, max_length=100, pattern=r"^[A-Za-z0-9_-]+$", examples=["test1"],
        description="Ixtiyoriy. Bir xil session_id bilan yuborilgan savollar bitta suhbat hisoblanadi.",
    )
    lang: Lang = Field(
        default=DEFAULT_LANG, examples=["uz"],
        description="Javob tili: uz (o'zbek), ru (rus), en (ingliz). Savol istalgan tilda yozilishi mumkin.",
    )


class ChatResponse(BaseModel):
    # So'rovdagi session_id yoki (yuborilmagan bo'lsa) yangi yaratilgani —
    # keyingi savollarda shuni yuborish kerak.
    session_id: str | None = None
    route: str = "database"
    route_reason: str = ""
    blocked_category: str = ""
    answer: str = ""
    sql: str | None = None
    columns: list[str] = Field(default_factory=list)
    rows: list[Any] = Field(default_factory=list)
    row_count: int = 0
    total_count: int | None = None
    truncated: bool = False
    fast_path: bool = False
    tables: list[str] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)
    error: str | None = None
    next_cursor: str | None = None
    attempts: int = 0
    timings: dict[str, float] = Field(default_factory=dict)


class PageRequest(BaseModel):
    cursor: str = Field(min_length=20, max_length=100, pattern=r"^[A-Za-z0-9_-]+$")


class PageResponse(BaseModel):
    columns: list[str]
    rows: list[dict[str, Any]]
    row_count: int
    next_cursor: str | None = None
