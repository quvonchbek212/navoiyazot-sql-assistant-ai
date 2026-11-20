"""Short-lived, user-bound query cursors. Query text and rows stay server-side."""
from __future__ import annotations

import secrets
import threading
import time
import sqlglot
from sqlglot import exp
from collections import OrderedDict
from dataclasses import dataclass

from .sql_guard import check_select

TTL_SECONDS = 900
MAX_CURSORS = 2000
PAGE_SIZE = 20


@dataclass(frozen=True)
class Page:
    sql: str
    columns: tuple[str, ...]
    offset: int
    principal: str
    expires_at: float


class QueryPages:
    def __init__(self):
        self._pages: OrderedDict[str, Page] = OrderedDict()
        self._lock = threading.Lock()

    def add(self, sql: str, columns: list[str], offset: int, principal: str,
            expires_at: float | None = None) -> str:
        clean = check_select(sql)
        if not columns or len(columns) != len(set(columns)):
            raise ValueError("Natija ustunlari aniq va takrorlanmas bo'lishi kerak")
        page = Page(clean, tuple(columns), offset, principal, expires_at or time.monotonic() + TTL_SECONDS)
        with self._lock:
            for token in list(self._pages):
                if self._pages[token].expires_at <= time.monotonic():
                    del self._pages[token]
            token = secrets.token_urlsafe(32)
            self._pages[token] = page
            while len(self._pages) > MAX_CURSORS:
                self._pages.popitem(last=False)
        return token

    def get(self, token: str, principal: str) -> Page:
        with self._lock:
            page = self._pages.get(token)
            if page is None or page.expires_at <= time.monotonic() or not secrets.compare_digest(
                page.principal.encode(), principal.encode(),
            ):
                raise ValueError("Sahifa muddati tugagan yoki mavjud emas")
            return page

    @staticmethod
    def query(page: Page) -> str:
        statement = sqlglot.parse_one(page.sql, dialect="postgres")
        limit = statement.args.get("limit")
        offset = statement.args.get("offset")
        size = PAGE_SIZE + 1
        start = page.offset
        for node in (limit, offset):
            if node is not None and not (isinstance(node.expression, exp.Literal) and node.expression.is_int):
                raise ValueError("Sahifalash uchun LIMIT/OFFSET butun son bo'lishi kerak")
        if limit is not None:
            size = max(0, min(size, int(limit.expression.to_py()) - page.offset))
        if offset is not None:
            start += int(offset.expression.to_py())
        statement.set("limit", exp.Limit(expression=exp.Literal.number(size)))
        statement.set("offset", exp.Offset(expression=exp.Literal.number(start)))
        return check_select(statement.sql(dialect="postgres"))
