"""Calendar dates use local midnights, without losing the last microseconds."""
import asyncio

import pytest

from atil_chatbot.app.config import Settings
from atil_chatbot.app.schema_provider import SchemaProvider
from atil_chatbot.app.sql_service import SqlService
from atil_chatbot.app.sql_validator import validate


QUESTION = "2026-yil 1-noyabrdan 6-noyabrgacha, ikkala kunni ham qo'shib, yaratilgan tizim bildirishnomalari jami nechta? O'qilgan va o'qilmaganlarini ham hisobla."
BAD_SQL = "SELECT count(*) AS n FROM public.notification WHERE created_at >= '2026-11-01 00:00:00+00' AND created_at <= '2026-11-06 23:59:59+00'"
GOOD_SQL = "SELECT count(*) AS n FROM public.notification WHERE created_at >= TIMESTAMPTZ '2026-11-01 00:00:00+05' AND created_at < TIMESTAMPTZ '2026-11-07 00:00:00+05'"


@pytest.mark.parametrize("query", [
    BAD_SQL,
    BAD_SQL.replace("+00", "+05"),  # Still drops fractional seconds.
    GOOD_SQL.replace("+05", "+00"),
    GOOD_SQL.replace("+05", "Z"),
    "SELECT count(*) FROM notification WHERE created_at BETWEEN '2026-11-01' AND '2026-11-06'",
    "SELECT count(*) FROM notification WHERE '2026-11-01 00:00+00' <= created_at AND '2026-11-07 00:00+00' > created_at",
    "SELECT count(*) FROM notification n WHERE (n.created_at) >= CAST('2026-11-01 00:00+00' AS timestamptz)",
    "WITH n AS (SELECT created_at AS ts FROM notification) SELECT count(*) FROM n WHERE ts >= '2026-11-01 00:00+00'",
    "SELECT count(*) FROM (SELECT created_at AS ts FROM notification) n WHERE n.ts < '2026-11-07 00:00+00'",
    "SELECT count(*) FROM notification WHERE created_at AT TIME ZONE 'UTC' >= '2026-11-01 00:00:00'",
])
def test_wrong_local_boundaries_are_rejected_before_execution(query, real_catalog):
    assert validate(query, real_catalog) == []  # Schema valid, meaning wrong.
    errors = validate(query, real_catalog, QUESTION)
    assert errors and "Asia/Tashkent" in errors[-1]
    assert "KEYINGI kun" in errors[-1]


@pytest.mark.parametrize("question", [
    QUESTION,
    "Count notifications created from November 1 through November 6, 2026, inclusive.",
    "Сколько уведомлений создано с 1 по 6 ноября 2026 года включительно?",
    "2026-11-01 dan 2026-11-06 gacha bildirishnomalar nechta?",
    "Bugun yaratilgan bildirishnomalar nechta?",
])
def test_calendar_intent_in_supported_languages(question, real_catalog):
    assert validate(BAD_SQL, real_catalog, question)


@pytest.mark.parametrize("query", [
    GOOD_SQL,
    GOOD_SQL.replace("+05", "+05:00"),
    GOOD_SQL.replace("TIMESTAMPTZ ", "").replace("+05", ""),
    GOOD_SQL.replace("TIMESTAMPTZ ", "DATE ").replace(" 00:00:00+05", ""),
    # Correctly converted UTC dates must not be rewritten or rejected.
    "SELECT count(*) FROM notification WHERE created_at >= TIMESTAMPTZ '2026-10-31 19:00:00+00' AND created_at < TIMESTAMPTZ '2026-11-06 19:00:00Z'",
    "SELECT count(*) FROM notification WHERE '2026-10-31 19:00:00Z' <= created_at AND '2026-11-06 19:00:00Z' > created_at",
    "SELECT count(*) FROM notification WHERE created_at >= '2026-11-01 00:00+05' AND created_at <= '2026-11-06 23:59:59.999999+05'",
    "SELECT count(*) FROM notification WHERE created_at > '2026-10-31 23:59:59.999999+05' AND created_at < '2026-11-07 00:00+05'",
    "SELECT count(*) FROM notification WHERE created_at::date BETWEEN DATE '2026-11-01' AND DATE '2026-11-06'",
    "SELECT count(*) FROM notification WHERE created_at >= CURRENT_DATE AND created_at < CURRENT_DATE + INTERVAL '1 day'",
    "SELECT count(*) FROM notification WHERE created_at AT TIME ZONE 'Asia/Tashkent' >= '2026-11-01 00:00:00'",
    "SELECT count(*) FROM notification WHERE created_at AT TIME ZONE 'UTC' >= '2026-10-31 19:00:00'",
    "SELECT count(*) FROM waybill WHERE issue_date BETWEEN DATE '2026-11-01' AND DATE '2026-11-06'",
    # TIMESTAMP WITHOUT TIME ZONE ignores a written offset in PostgreSQL.
    "SELECT count(*) FROM notification WHERE created_at >= TIMESTAMP '2026-11-01 00:00+00'",
])
def test_equivalent_intervals_and_date_columns_remain_valid(query, real_catalog):
    assert validate(query, real_catalog, QUESTION) == []


@pytest.mark.parametrize("question", [
    "Count notifications for November 1–6 in UTC.",
    "2026-yil 1–6-noyabr, GMT vaqtida hisobla.",
    "2026-11-01 kuni 09:30 dan 18:00 gacha hisobla.",
    "Oxirgi 24 soatda bildirishnomalar nechta?",
    "Count notifications over the last 6 hours today.",
    "Сколько уведомлений за последние 30 минут сегодня?",
    "1–6 noyabr, Europe/Moscow vaqtida hisobla.",
    "1–6 noyabr Moskva vaqtida hisobla.",
])
def test_explicit_times_and_alternative_zones_are_not_assumed_local(question, real_catalog):
    assert validate(BAD_SQL, real_catalog, question) == []


class ScriptLlm:
    def __init__(self, *replies):
        self.replies, self.calls = list(replies), []

    async def chat_messages(self, messages, **kwargs):
        self.calls.append([dict(m) for m in messages])
        return self.replies.pop(0)


class RecordingDb:
    def __init__(self):
        self.executed = []

    async def run_select(self, query):
        self.executed.append(query)
        return {"columns": ["n"], "rows": [{"n": 3}]}


def test_wrong_utc_sql_is_corrected_before_it_reaches_the_database():
    settings = Settings(_env_file=None, chat_db_host="", schema_refresh_seconds=0)
    db, llm = RecordingDb(), ScriptLlm(BAD_SQL, GOOD_SQL)
    result = asyncio.run(SqlService(settings, llm, db, SchemaProvider(settings, db)).run(QUESTION))
    assert result["error"] is None and result["attempts"] == 2
    assert result["rows"] == [{"n": 3}] and len(db.executed) == 1
    assert "+05" in db.executed[0] and "+00" not in db.executed[0]
    assert "Asia/Tashkent" in llm.calls[1][-1]["content"]
    assert "kasr soniyalar" in llm.calls[1][-1]["content"]


def test_repeated_wrong_utc_sql_never_reaches_the_database():
    settings = Settings(_env_file=None, chat_db_host="", schema_refresh_seconds=0)
    db, llm = RecordingDb(), ScriptLlm(BAD_SQL, BAD_SQL)
    result = asyncio.run(SqlService(settings, llm, db, SchemaProvider(settings, db)).run(QUESTION))
    assert result["error_kind"] == "not_understood"
    assert len(llm.calls) == 2 and db.executed == []
