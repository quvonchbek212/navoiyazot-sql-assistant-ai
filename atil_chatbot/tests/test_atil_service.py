"""ATIL integration: real transport schema, scripted model, no network."""
import asyncio
import json
from pathlib import Path

import psycopg
import pytest

from atil_chatbot.app import streaming
from atil_chatbot.app.config import Settings
from atil_chatbot.app.graph import AssistantGraph
from atil_chatbot.app.schema_provider import SchemaProvider
from atil_chatbot.app.sql_service import SqlService


class Llm:
    def __init__(self, *replies):
        self.replies = list(replies)
        self.calls = []

    async def chat_messages(self, messages, **kwargs):
        self.calls.append([dict(m) for m in messages])
        return self.replies.pop(0)

    async def chat(self, system, user, **kwargs):
        return await self.chat_messages([{"role": "system", "content": system}, {"role": "user", "content": user}])

    async def chat_stream(self, *args, **kwargs):
        for part in self.replies.pop(0):
            yield part


class Db:
    def __init__(self, rows=None, failure=None):
        self.rows = rows if rows is not None else [{"soni": 5}]
        self.failure = failure
        self.executed = []

    async def run_select(self, sql):
        self.executed.append(sql)
        if self.failure:
            failure, self.failure = self.failure, None
            raise failure
        return {"columns": list(self.rows[0]) if self.rows else [], "rows": self.rows}

    async def count(self, sql):
        return 700


@pytest.fixture
def runtime():
    s = Settings(_env_file=None, chat_db_host="", schema_refresh_seconds=0, sql_row_limit=500,
                 schema_file=str(Path(__file__).resolve().parents[1] / "schema/schema.json"))
    return s


def service(s, llm, db):
    return SqlService(s, llm, db, SchemaProvider(s, db))


def test_sql_retry_preserves_question_sql_and_precise_error(runtime):
    llm = Llm("SELECT missing_column FROM trip", "SELECT count(*) AS soni FROM trip")
    db = Db()
    result = asyncio.run(service(runtime, llm, db).run("Reyslarning umumiy sonini ayting"))
    assert not result["error"] and result["attempts"] == 2
    assert len(db.executed) == 1
    second = llm.calls[1]
    assert [m["role"] for m in second] == ["system", "user", "assistant", "user"]
    assert "missing_column" in second[3]["content"]
    assert "umumiy sonini" in second[1]["content"]


def test_check_value_rejected_before_db(runtime):
    llm = Llm("SELECT count(*) AS soni FROM trip WHERE status = 'started'",
              "SELECT count(*) AS soni FROM trip WHERE status = 'STARTED'")
    db = Db()
    result = asyncio.run(service(runtime, llm, db).run("Boshlangan reyslarning soni"))
    assert not result["error"] and len(db.executed) == 1
    assert "STARTED" in db.executed[0]


def test_database_outage_does_not_regenerate_sql(runtime):
    llm = Llm("SELECT count(*) AS soni FROM trip")
    result = asyncio.run(service(runtime, llm, Db(failure=psycopg.OperationalError("offline"))).run("Jami reys sonini ayting"))
    assert result["error_kind"] == "db_unavailable" and result["sql"] is None
    assert len(llm.calls) == 1


def test_exact_catalog_bypasses_sql_model(runtime):
    llm = Llm()
    result = asyncio.run(service(runtime, llm, Db()).run("Qaysi reyslar kechikayapti?"))
    assert result["fast_path"] and not llm.calls


def test_repeat_error_stops_retry(runtime):
    llm = Llm("SELECT missing FROM trip", "SELECT missing FROM trip", "SELECT missing FROM trip")
    result = asyncio.run(service(runtime, llm, Db()).run("noaniq reys savoli"))
    assert result["error"] and len(llm.calls) == 2


def test_truncation_keeps_real_total(runtime):
    rows = [{"reys": str(i)} for i in range(501)]
    llm = Llm("SELECT trip_number AS reys FROM trip ORDER BY trip_number")
    result = asyncio.run(service(runtime, llm, Db(rows)).run("Barcha reys raqamlarini ko'rsat"))
    assert result["row_count"] == 20 and result["total_count"] == 700 and result["truncated"]


def test_scalar_answer_comes_from_db_without_summary_model(runtime):
    class Sql:
        async def run(self, *args):
            return {"sql": "SELECT count(*) AS soni FROM trip", "columns": ["soni"], "rows": [{"soni": 0}], "row_count": 1}
    graph = AssistantGraph(runtime, Llm(), Sql(), None)
    result = asyncio.run(graph.database_node({"question": "Reyslar soni"}))
    assert "0" in result["answer"]


def test_stream_drops_unsupported_number_and_returns_deterministic_rows(runtime):
    class Sql:
        async def run(self, *args):
            return {"columns": ["mashina", "soni"], "rows": [{"mashina": "A", "soni": 2}, {"mashina": "B", "soni": 3}], "row_count": 2}
    graph = AssistantGraph(runtime, Llm(["Jami ", "999", " ta"]), Sql(), None)
    chunks = []
    with streaming.listen(chunks.append):
        result = asyncio.run(graph.database_node({"question": "Reyslar"}))
    assert "999" not in "".join(chunks) and "999" not in result["answer"]
    assert "A" in result["answer"] and "B" in result["answer"]


def test_config_never_uses_generic_lims_db_env(monkeypatch):
    monkeypatch.setenv("DB_HOST", "lims-server")
    monkeypatch.setenv("DB_NAME", "lims-database")
    monkeypatch.setenv("ATIL_DB_HOST", "atil-server")
    monkeypatch.setenv("ATIL_DB_NAME", "atil-database")
    settings = Settings(_env_file=None)
    assert settings.db_host == "atil-server" and settings.db_name == "atil-database"
    assert "atil_chatbot" in settings.schema_file and settings.chat_db_table_prefix == "atil_chatbot"


def test_config_preserves_ollama_fallback():
    s = Settings(_env_file=None, vllm_base_url="", vllm_model="", ollama_base_url="http://local:11434", ollama_model="gemma4:31b")
    assert s.vllm_base_url == "http://local:11434/v1" and s.vllm_model == "gemma4:31b"
