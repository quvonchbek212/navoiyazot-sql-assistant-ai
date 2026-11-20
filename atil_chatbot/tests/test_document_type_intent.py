"""Document type counts must use document_type, preserving access to template codes."""
import asyncio
import sqlite3

import pytest
import sqlglot

from atil_chatbot.app.config import Settings
from atil_chatbot.app.schema_provider import SchemaProvider
from atil_chatbot.app.sql_service import SqlService
from atil_chatbot.app.sql_validator import validate


QUESTION = "Faol hujjat shablonlari hujjat turi kodlari bo'yicha nechtadan? Faqat active qiymati true bo'lgan shablonlarni sana."
BAD_SQL = 'SELECT code AS "Hujjat turi kodi", count(*) AS n FROM public.document_template WHERE active = true GROUP BY code'
GOOD_SQL = "SELECT document_type, count(*) AS n FROM public.document_template WHERE active = true GROUP BY document_type ORDER BY document_type"


class ScriptLlm:
    def __init__(self, *replies):
        self.replies, self.calls = list(replies), []

    async def chat_messages(self, messages, **kwargs):
        self.calls.append([dict(message) for message in messages])
        return self.replies.pop(0)


class QueryDb:
    def __init__(self):
        self.connection = sqlite3.connect(":memory:")
        self.connection.row_factory = sqlite3.Row
        self.connection.execute("ATTACH DATABASE ':memory:' AS public")
        self.connection.execute("CREATE TABLE public.document_template (id TEXT, code TEXT, document_type TEXT, active BOOLEAN)")
        self.connection.executemany("INSERT INTO public.document_template VALUES (?, ?, ?, ?)", [
            ("1", "template-a", "WAYBILL", True), ("2", "template-b", "WAYBILL", True),
            ("3", "template-c", "TTN", True), ("4", "inactive", "WAYBILL", False),
        ])
        self.connection.commit()
        self.connection.execute("PRAGMA query_only = ON")
        self.executed = []

    async def run_select(self, query):
        self.executed.append(query)
        cursor = self.connection.execute(sqlglot.transpile(query, read="postgres", write="sqlite")[0])
        return {"columns": [c[0] for c in cursor.description], "rows": [dict(row) for row in cursor.fetchall()]}

    def close(self):
        self.connection.close()


def test_wrong_template_code_is_corrected_before_database_execution():
    settings = Settings(_env_file=None, chat_db_host="", schema_refresh_seconds=0)
    db, llm = QueryDb(), ScriptLlm(BAD_SQL, GOOD_SQL)
    service = SqlService(settings, llm, db, SchemaProvider(settings, db))
    try:
        result = asyncio.run(service.run(QUESTION))
        assert result["rows"] == [{"document_type": "TTN", "n": 1}, {"document_type": "WAYBILL", "n": 2}]
        assert result["error"] is None and result["attempts"] == 2
        assert len(db.executed) == 1
        assert "document_type" in llm.calls[1][-1]["content"]
        assert "document_template.code" in llm.calls[1][-1]["content"]
        assert [m["role"] for m in llm.calls[1]] == ["system", "user", "assistant", "user"]
    finally:
        db.close()


def test_repeated_wrong_dimension_never_reaches_database():
    settings = Settings(_env_file=None, chat_db_host="", schema_refresh_seconds=0)
    db, llm = QueryDb(), ScriptLlm(BAD_SQL, BAD_SQL)
    service = SqlService(settings, llm, db, SchemaProvider(settings, db))
    try:
        result = asyncio.run(service.run(QUESTION))
        assert result["error"] and result["error_kind"] == "not_understood"
        assert not db.executed
        assert len(llm.calls) == 2
    finally:
        db.close()


@pytest.mark.parametrize("query", [
    BAD_SQL,
    "SELECT t.code AS kind, count(*) FROM public.document_template t GROUP BY t.code",
    "SELECT code AS kind, count(*) FROM public.document_template GROUP BY kind",
    "SELECT code AS kind, count(*) FROM public.document_template GROUP BY 1",
    "SELECT count(*) FROM public.document_template GROUP BY code",
    "SELECT document_type, code, count(*) FROM public.document_template GROUP BY document_type, code",
    "WITH t AS (SELECT code AS kind, active FROM public.document_template) SELECT kind, count(*) FROM t WHERE active GROUP BY kind",
    "SELECT t.kind, count(*) FROM (SELECT code AS kind, active FROM public.document_template) t WHERE active GROUP BY t.kind",
    'SELECT code AS "Hujjat turi" FROM public.document_template',
])
def test_wrong_dimension_is_detected_through_aliases_and_ctes(query, real_catalog):
    assert validate(query, real_catalog) == []  # valid schema, wrong meaning for this question
    errors = validate(query, real_catalog, QUESTION)
    assert errors and "document_template.document_type" in errors[-1]


@pytest.mark.parametrize("question", [
    QUESTION,
    "Count active document templates by document type code.",
    "Сколько активных шаблонов по типам документов?",
])
def test_document_type_intent_is_supported_in_all_answer_languages(question, real_catalog):
    assert validate(BAD_SQL, real_catalog, question)


@pytest.mark.parametrize("query,question", [
    (GOOD_SQL, QUESTION),
    ("SELECT document_type, count(code) FROM public.document_template GROUP BY document_type", QUESTION),
    ("SELECT document_type FROM public.document_template WHERE code = 'template-a'", QUESTION),
    ("WITH t AS (SELECT code, document_type, active FROM public.document_template) SELECT document_type, count(code) FROM t WHERE active GROUP BY document_type", QUESTION),
    ("SELECT code FROM public.document_template", "Faol shablonlarning kodlarini ko'rsat"),
    ("SELECT code FROM public.document_template WHERE document_type = 'WAYBILL'", "WAYBILL hujjat turi uchun shablon kodlarini ko'rsat"),
    ("SELECT code, document_type FROM public.document_template", "Shablonning o'z kodi va hujjat turini ko'rsat"),
    ("SELECT code, document_type FROM public.document_template", "Show template codes for each document type"),
    ("SELECT code, document_type FROM public.document_template", "Покажи коды шаблонов по типам документов"),
])
def test_real_document_types_and_explicit_template_code_requests_remain_valid(query, question, real_catalog):
    assert validate(query, real_catalog, question) == []


def test_schema_describes_both_codes_and_routes_templates(real_catalog):
    ddl = real_catalog.render_table("document_template")
    assert "hujjat turi emas" in ddl
    assert "Hujjat turi kodi (WAYBILL, TTN" in ddl
    assert "document_type" in real_catalog.catalog_line("document_template")
    settings = Settings(_env_file=None, chat_db_host="", schema_refresh_seconds=0)
    assert "document_template" in asyncio.run(SchemaProvider(settings, None).rank(QUESTION))
