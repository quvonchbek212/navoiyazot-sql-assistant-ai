"""Umumiy test yordamchilari — kichik sun'iy sxema katalogi (bazasiz)."""
from __future__ import annotations

import json
import pathlib

import pytest

from atil_chatbot.app.config import Settings
from atil_chatbot.app.schema_catalog import SchemaCatalog

REAL_SCHEMA = pathlib.Path(__file__).resolve().parents[1] / "schema" / "schema.json"


@pytest.fixture(autouse=True)
def isolated_runtime(monkeypatch):
    """Unit tests never call the real LLM or initialize production chat tables."""
    from atil_chatbot.app.config import get_settings
    monkeypatch.setenv("SCHEMA_REFRESH_SECONDS", "0")
    monkeypatch.setenv("CHAT_DB_HOST", "")
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def col(name, type_="varchar", **kw):
    return {"name": name, "type": type_, **kw}


def catalog_dict(n_noise: int = 0) -> dict:
    tables = {
        "tnb_analysis": {
            "rows": 4468,
            "columns": [
                col("id", notnull=True),
                col("analysis_date", "date", notnull=True, date_min="2026-06-29", date_max="2026-09-18"),
                col("status", notnull=True, allowed=["Norma", "Chetlanish"],
                    values=[["Norma", 2996], ["Chetlanish", 1472]], values_complete=True),
                col("sampling_point_code"),
                col("analyst_full_name", notnull=True),
                col("archived_at", "timestamp with time zone"),
                col("inputs_json", "oid"),
                col("lab_sample_id", always_null=True),
            ],
            "pk": ["id"],
            "fks": [{"column": "sampling_point_code", "ref_table": "tnb_sampling_point",
                     "ref_column": "code", "logical": True}],
        },
        "tnb_sampling_point": {
            "rows": 1131,
            "columns": [col("id", notnull=True), col("code", notnull=True), col("name"), col("group_id")],
            "pk": ["id"],
            "fks": [{"column": "group_id", "ref_table": "tnb_sampling_point_group", "ref_column": "id"}],
        },
        "tnb_sampling_point_group": {
            "rows": 119,
            "columns": [col("id", notnull=True), col("name", notnull=True), col("lab_id")],
            "pk": ["id"],
            "fks": [],
        },
        "tnb_party": {
            "rows": 17,
            "columns": [
                col("id", notnull=True), col("party_no", "integer"),
                col("analysisStatus", allowed=["PENDING", "PASSED", "REJECTED"],
                    values=[["PENDING", 11], ["PASSED", 4]], values_complete=True),
                col("analysis_status", allowed=["PENDING", "PASSED", "REJECTED"],
                    values=[["PENDING", 11], ["PASSED", 4]], values_complete=True),
            ],
            "pk": ["id"],
            "fks": [],
        },
        "instrument": {
            "rows": 15,
            "columns": [
                col("id", notnull=True), col("name", notnull=True), col("code"), col("lab_id", notnull=True),
                col("calibration_due_at", "timestamp with time zone"),
                col("status_id", notnull=True, status_ref=True,
                    values=[["INSTRUMENT_ACTIVE", 10], ["AVAILABLE", 3]], values_complete=True),
                col("archived_at", "timestamp with time zone"),
            ],
            "pk": ["id"],
            "fks": [{"column": "lab_id", "ref_table": "lab", "ref_column": "id"},
                    {"column": "status_id", "ref_table": "status_dictionary", "ref_column": "id"}],
        },
        "lab": {
            "rows": 71,
            "columns": [col("id", notnull=True), col("name", notnull=True), col("lab_type"),
                        col("is_active", "boolean"), col("archived_at", "timestamp with time zone")],
            "pk": ["id"],
            "fks": [],
        },
        "status_dictionary": {
            "rows": 158,
            "columns": [
                col("id", notnull=True), col("label", notnull=True),
                col("code", notnull=True, values=[["AVAILABLE", 42], ["NC_OPEN", 2], ["INSTRUMENT_ACTIVE", 1]],
                    values_complete=True),
            ],
            "pk": ["id"],
            "fks": [],
        },
        "core_user": {
            "rows": 84,
            "columns": [col("id", notnull=True), col("full_name"), col("password_hash", sensitive=True)],
            "pk": ["id"],
            "fks": [],
        },
        "lab_sample": {"rows": 0, "columns": [col("id", notnull=True), col("sample_no")], "pk": ["id"], "fks": []},
    }
    for i in range(n_noise):
        tables[f"noise_table_{i:03d}"] = {
            "rows": 5,
            "columns": [col("id"), col(f"filler_column_{i}"), col("another_filler", "text")],
            "pk": ["id"], "fks": [],
        }
    return {"generated_at": "2026-09-19T10:00:00", "source": "test", "tables": tables}


@pytest.fixture
def catalog() -> SchemaCatalog:
    return SchemaCatalog.from_dict(catalog_dict())


@pytest.fixture
def schema_file(tmp_path) -> pathlib.Path:
    path = tmp_path / "schema.json"
    path.write_text(json.dumps(catalog_dict(n_noise=60)), encoding="utf-8")
    return path


@pytest.fixture
def settings(schema_file) -> Settings:
    return Settings(schema_file=str(schema_file), db_password="x", schema_char_budget=6000,
                    sql_row_limit=5, max_sql_attempts=3)


@pytest.fixture
def real_catalog() -> SchemaCatalog:
    if not REAL_SCHEMA.is_file():
        pytest.skip("schema.json yo'q — python -m atil_chatbot.tools.generate_ddl")
    return SchemaCatalog.load(REAL_SCHEMA)
