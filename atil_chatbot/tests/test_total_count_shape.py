"""Reproduce the grouped COUNT(DISTINCT key) bug with executable read-only SQL."""
import asyncio
import sqlite3

import pytest
import sqlglot

from atil_chatbot.app import streaming
from atil_chatbot.app.config import Settings
from atil_chatbot.app.graph import AssistantGraph
from atil_chatbot.app.schema_provider import SchemaProvider
from atil_chatbot.app.sql_service import SqlService, _scalar_total_sql
from atil_chatbot.app.sql_guard import check_select


QUESTION = (
    "Mashinalarga haydovchilar biriktirish ro'yxati (vehicle_assigned_drivers) bo'yicha "
    "kamida ikkita turli haydovchi biriktirilgan mashinalar jami nechta? "
    "Har bir mashinani bir marta sana."
)
BAD_SQL = """SELECT COUNT(DISTINCT vehicle_id) AS jami_mashinalar_soni
FROM public.vehicle_assigned_drivers
GROUP BY vehicle_id HAVING COUNT(DISTINCT driver_id) >= 2"""


class ScriptLlm:
    def __init__(self, sql):
        self.sql, self.calls = sql, 0

    async def chat_messages(self, *args, **kwargs):
        self.calls += 1
        return self.sql

    async def chat(self, *args, **kwargs):
        raise AssertionError("A single total must not need a summary model")


class QueryDb:
    def __init__(self, groups, null_group=False):
        self.connection = sqlite3.connect(":memory:")
        self.connection.row_factory = sqlite3.Row
        self.connection.execute("ATTACH DATABASE ':memory:' AS public")
        self.connection.execute("CREATE TABLE public.vehicle_assigned_drivers (vehicle_id TEXT, driver_id TEXT)")
        rows = [(f"v{i}", f"d{j}") for i in range(groups) for j in range(2)]
        # Repeated copies of one driver must not qualify as two distinct drivers.
        rows += [("single", "d0"), ("duplicate", "d0"), ("duplicate", "d0")]
        if null_group:
            rows += [(None, "d0"), (None, "d1")]
        self.connection.executemany("INSERT INTO public.vehicle_assigned_drivers VALUES (?, ?)", rows)
        self.connection.commit()
        self.connection.execute("PRAGMA query_only = ON")
        self.executed = []

    async def run_select(self, query):
        self.executed.append(query)
        query = sqlglot.transpile(query, read="postgres", write="sqlite")[0]
        cursor = self.connection.execute(query)
        return {"columns": [c[0] for c in cursor.description], "rows": [dict(row) for row in cursor.fetchall()]}

    def close(self):
        self.connection.close()


@pytest.mark.parametrize("groups,null_group", [(43, False), (0, False), (1, False), (43, True)])
def test_grouped_distinct_count_returns_one_total(groups, null_group):
    settings = Settings(_env_file=None, chat_db_host="", schema_refresh_seconds=0)
    db = QueryDb(groups, null_group)
    llm = ScriptLlm(BAD_SQL)
    sql = SqlService(settings, llm, db, SchemaProvider(settings, db))
    graph = AssistantGraph(settings, llm, sql, None)
    chunks = []
    try:
        with streaming.listen(chunks.append):
            result = asyncio.run(graph.database_node({"question": QUESTION, "lang": "uz"}))
        assert result["rows"] == [{"jami_mashinalar_soni": groups}]
        assert result["row_count"] == 1 and not result["truncated"]
        assert result["answer"] == f"Jami mashinalar soni: {groups}"
        assert "".join(chunks) == result["answer"]
        assert llm.calls == 1
    finally:
        db.close()


@pytest.mark.parametrize("question", [
    QUESTION,
    "Umumiy sonini ayting: kamida ikkita haydovchi biriktirilgan mashinalar.",
    "How many vehicles have at least two drivers in total? Count each vehicle once.",
    "Сколько всего машин имеют не менее двух водителей?",
])
def test_total_count_preserves_filters_and_quoted_alias(question):
    query = BAD_SQL.replace("AS jami_mashinalar_soni", 'AS "Mashinalar soni"').replace(
        "GROUP BY", "WHERE vehicle_id <> 'v42' GROUP BY",
    ) + ' ORDER BY "Mashinalar soni" DESC'
    db = QueryDb(43, null_group=True)
    try:
        corrected = check_select(_scalar_total_sql(check_select(query), question))
        result = asyncio.run(db.run_select(corrected))
        assert result["rows"] == [{"Mashinalar soni": 42}]
    finally:
        db.close()


@pytest.mark.parametrize("query,question", [
    (BAD_SQL, "Har bir mashina uchun jami nechta haydovchi bor?"),
    (BAD_SQL, "Har bir bo'limda jami nechta mashina bor?"),
    (BAD_SQL, "Mashinalar kesimida jami sonini ko'rsat"),
    (BAD_SQL, "Show the total number for each vehicle"),
    (BAD_SQL, "Mashinalar ro'yxatini ko'rsat"),
    (BAD_SQL + " LIMIT 20", QUESTION),
    (BAD_SQL + " OFFSET 5", QUESTION),
    (BAD_SQL.replace("GROUP BY vehicle_id", "GROUP BY vehicle_id, driver_id"), QUESTION),
    (BAD_SQL.replace("GROUP BY vehicle_id", "GROUP BY ROLLUP(vehicle_id)"), QUESTION),
    (BAD_SQL.replace("COUNT(DISTINCT vehicle_id)", "COUNT(DISTINCT driver_id)"), QUESTION),
    (BAD_SQL.replace("COUNT(DISTINCT vehicle_id)", "COUNT(*)"), QUESTION),
    (BAD_SQL.replace("SELECT COUNT", "SELECT vehicle_id, COUNT", 1), QUESTION),
    ("SELECT count(DISTINCT vehicle_id) AS jami FROM public.vehicle_assigned_drivers", QUESTION),
])
def test_other_result_shapes_are_not_collapsed(query, question):
    clean = check_select(query)
    assert _scalar_total_sql(clean, question) == clean
