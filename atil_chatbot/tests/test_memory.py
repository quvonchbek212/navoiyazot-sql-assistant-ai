"""Suhbat xotirasi: jarayon xotirasi, PostgreSQL (TEST_CHAT_DB_URL bo'lsa) va baza o'chiqligi."""
import asyncio
import os
import time
import uuid

import psycopg
import pytest
from psycopg.conninfo import conninfo_to_dict

from atil_chatbot.app import memory as memory_mod
from atil_chatbot.app.config import Settings
from atil_chatbot.app.memory import ChatMemory, PgChatMemory, Turn, create_memory


def db_turn(q, sql="SELECT 1"):
    return Turn(question=q, answer="ok", route="database", sql=sql, row_count=1)


# ---------------- jarayon xotirasi ----------------
def test_process_memory_keeps_only_sql_turns():
    async def go():
        m = ChatMemory()
        await m.add("s", Turn(question="salom", answer="salom!", route="chitchat"))
        await m.add("s", Turn(question="xato", answer="⚠️", route="database", error="x"))
        await m.add("s", db_turn("birinchi"))
        return await m.history("s"), await m.history("boshqa")

    hist, other = asyncio.run(go())
    assert hist == [{"question": "birinchi", "sql": "SELECT 1"}]
    assert other == []


def test_process_memory_limits_turns():
    async def go():
        m = ChatMemory()
        for i in range(memory_mod.MAX_TURNS + 3):
            await m.add("s", db_turn(f"q{i}"))
        return await m.history("s")

    hist = asyncio.run(go())
    assert len(hist) == memory_mod.MAX_TURNS
    assert hist[-1]["question"] == f"q{memory_mod.MAX_TURNS + 2}"


def test_create_memory_picks_backend():
    assert isinstance(create_memory(Settings(chat_db_host="", chat_db_name="")), ChatMemory)
    assert isinstance(create_memory(Settings(chat_db_host="h", chat_db_name="d")), PgChatMemory)


# ---------------- baza o'chiq bo'lsa chat to'xtamaydi ----------------
def test_unreachable_db_degrades_gracefully(monkeypatch):
    monkeypatch.setattr(memory_mod, "POOL_TIMEOUT", 0.5)

    async def go():
        m = PgChatMemory(Settings(chat_db_host="127.0.0.1", chat_db_port=1, chat_db_name="x"))
        m.open()
        try:
            await m.add("s", db_turn("q"))  # xato ko'tarmaydi
            return await m.history("s"), await m.ping()
        finally:
            await m.close()

    hist, ok = asyncio.run(go())
    assert hist == [] and ok is False


def test_unreachable_db_is_skipped_after_failure(monkeypatch):
    """Bir marta javob bermasa — keyingi so'rovlar POOL_TIMEOUT kutmaydi."""
    monkeypatch.setattr(memory_mod, "POOL_TIMEOUT", 0.5)

    async def go():
        m = PgChatMemory(Settings(chat_db_host="127.0.0.1", chat_db_port=1, chat_db_name="x"))
        m.open()
        try:
            await m.history("s")  # birinchisi kutadi va xatoni eslab qoladi
            t0 = time.monotonic()
            await m.add("s", db_turn("q"))
            hist = await m.history("s")
            return hist, time.monotonic() - t0
        finally:
            await m.close()

    hist, elapsed = asyncio.run(go())
    assert hist == [] and elapsed < 0.1


# ---------------- haqiqiy PostgreSQL ----------------
@pytest.fixture
def pg_settings():
    url = os.environ.get("TEST_CHAT_DB_URL")
    if not url:
        pytest.skip("TEST_CHAT_DB_URL yo'q (masalan postgresql://user:pass@localhost:5432/db)")
    c = conninfo_to_dict(url)
    prefix = f"test_{uuid.uuid4().hex[:8]}"
    settings = Settings(
        chat_db_host=c.get("host", "localhost"), chat_db_port=int(c.get("port", 5432)),
        chat_db_name=c["dbname"], chat_db_user=c.get("user", ""), chat_db_password=c.get("password", ""),
        chat_db_table_prefix=prefix,
    )
    yield settings
    with psycopg.connect(url) as conn:
        conn.execute(f'DROP TABLE IF EXISTS "{prefix}_messages", "{prefix}_sessions"')


def run_pg(settings, fn):
    async def go():
        m = PgChatMemory(settings)
        m.open()
        try:
            return await fn(m)
        finally:
            await m.close()
    return asyncio.run(go())


def test_pg_saves_every_turn_and_reads_context(pg_settings):
    async def fn(m):
        assert await m.ping() is True  # jadvallarni ham yaratadi
        await m.add("s1", Turn(question="salom", answer="salom!", route="chitchat",
                               meta={"route_reason": "salomlashuv"}))
        await m.add("s1", Turn(question="yomon", answer="⚠️", route="database", error="SQL xato"))
        for i in range(memory_mod.MAX_TURNS + 1):
            await m.add("s1", db_turn(f"savol {i}", f"SELECT {i}"))
        await m.add("s2", db_turn("boshqa suhbat"))
        return await m.history("s1"), await m.history("s2"), await m.history("yo'q")

    hist, other, missing = run_pg(pg_settings, fn)
    # Kontekst: faqat muvaffaqiyatli SQL, eng oxirgi MAX_TURNS tasi, eski → yangi tartibda.
    assert [t["question"] for t in hist] == [f"savol {i}" for i in range(1, memory_mod.MAX_TURNS + 1)]
    assert hist[-1]["sql"] == f"SELECT {memory_mod.MAX_TURNS}"
    assert [t["question"] for t in other] == ["boshqa suhbat"]
    assert missing == []

    p = pg_settings.chat_db_table_prefix
    with psycopg.connect(os.environ["TEST_CHAT_DB_URL"]) as conn:
        sessions = conn.execute(f'SELECT id, title, message_count FROM "{p}_sessions" ORDER BY id').fetchall()
        routes = conn.execute(
            f'SELECT route, error, meta FROM "{p}_messages" WHERE session_id = %s ORDER BY id LIMIT 2', ("s1",)
        ).fetchall()
    # Har bir savol saqlanadi (chitchat va xato ham), sessiya hisoblagichi yangilanadi.
    assert sessions == [("s1", "salom", memory_mod.MAX_TURNS + 3), ("s2", "boshqa suhbat", 1)]
    assert routes[0] == ("chitchat", None, {"route_reason": "salomlashuv"})
    assert routes[1][:2] == ("database", "SQL xato")


def test_pg_schema_creation_is_idempotent(pg_settings):
    async def fn(m):
        return await m.ping()

    assert run_pg(pg_settings, fn) is True
    assert run_pg(pg_settings, fn) is True  # jadvallar bor — qayta yaratilmaydi, xato yo'q
