"""Konfiguratsiya — barcha sozlamalar muhit o'zgaruvchilaridan (.env) o'qiladi."""
from __future__ import annotations

import pathlib
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import AliasChoices, Field, model_validator


SCHEMA_DIR = pathlib.Path(__file__).resolve().parent.parent / "schema"
PROJECT_ROOT = pathlib.Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=PROJECT_ROOT / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
        populate_by_name=True,
    )

    # --- Chat LLM (vLLM, OpenAI-mos API) ---
    vllm_base_url: str = ""
    vllm_api_key: str = Field("dummy", repr=False)
    vllm_model: str = ""
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = Field("gemma4:31b", validation_alias=AliasChoices("CHATBOT_OLLAMA_MODEL", "ollama_model"))
    llm_temperature: float = 0.0
    llm_max_tokens: int = 1500
    llm_timeout: float = Field(150.0, validation_alias=AliasChoices("ATIL_CHATBOT_LLM_TIMEOUT", "CHATBOT_OLLAMA_TIMEOUT_SECONDS", "llm_timeout"))

    # --- PostgreSQL (READ-ONLY foydalanuvchi) ---
    db_host: str = Field("", validation_alias=AliasChoices("ATIL_DB_HOST", "db_host"))
    db_port: int = Field(5432, validation_alias=AliasChoices("ATIL_DB_PORT", "db_port"))
    db_name: str = Field("", validation_alias=AliasChoices("ATIL_DB_NAME", "db_name"))
    db_user: str = Field("", validation_alias=AliasChoices("ATIL_DB_USER", "db_user"))
    db_password: str = Field("", validation_alias=AliasChoices("ATIL_DB_PASSWORD", "db_password"), repr=False)
    db_include_schemas: str = Field("public", validation_alias=AliasChoices("ATIL_DB_SCHEMA", "db_include_schemas"))
    db_connect_timeout: int = Field(10, ge=1, validation_alias=AliasChoices("DB_CONNECT_TIMEOUT", "db_connect_timeout"))
    # Sxema manbasi. Yaratish: python -m atil_chatbot.tools.generate_ddl
    schema_file: str = Field(str(SCHEMA_DIR / "schema.json"), validation_alias=AliasChoices("ATIL_CHATBOT_SCHEMA_FILE", "schema_file"))
    ddl_file: str = Field(str(SCHEMA_DIR / "ddl.sql"), validation_alias=AliasChoices("ATIL_CHATBOT_DDL_FILE", "ddl_file"))

    # --- Suhbat xotirasi (alohida PostgreSQL, YOZISH huquqi bilan) ---
    # ATIL bazasi read-only — tarix boshqa bazaga yoziladi. CHAT_DB_HOST bo'sh
    # bo'lsa xotira jarayon ichida qoladi (qayta ishga tushsa yo'qoladi).
    chat_db_host: str = ""
    chat_db_port: int = 5432
    chat_db_name: str = ""
    chat_db_user: str = ""
    chat_db_password: str = Field("", repr=False)
    chat_db_schema: str = "public"
    chat_db_sslmode: str = "disable"
    # Jadvallar: <prefix>_sessions, <prefix>_messages — bazadagi boshqa
    # chatbot jadvallari (masalan chat_history) bilan to'qnashmaydi.
    chat_db_table_prefix: str = "atil_chatbot"

    # --- Xavfsizlik / cheklovlar ---
    sql_row_limit: int = 500
    max_rows_to_model: int = 20  # xulosa LLM iga beriladigan satrlar (ro'yxatni kod qo'shadi)
    statement_timeout_ms: int = Field(15000, validation_alias=AliasChoices("DB_STATEMENT_TIMEOUT_MS", "statement_timeout_ms"))
    schema_char_budget: int = 24000
    schema_refresh_seconds: int = 600
    llm_health_timeout: float = 10.0
    llm_max_retries: int = 1
    max_sql_attempts: int = 3

    @model_validator(mode="after")
    def llm_backend(self):
        if not self.vllm_base_url:
            self.vllm_base_url = self.ollama_base_url.rstrip("/") + "/v1"
            self.vllm_model = self.ollama_model
        if not self.vllm_api_key:
            self.vllm_api_key = "unused"
        if not self.vllm_model:
            self.vllm_model = "gemma4-31b"
        return self

    # --- Xizmat ---
    cors_allow_origins: str = "*"
    # HTTP Basic login/parol (barcha endpointlar uchun). Bo'sh bo'lsa — barcha
    # so'rov rad etiladi (himoya jimgina o'chib qolmasin).
    api_username: str = ""
    api_password: str = Field("", repr=False)
    # Optional separate accounts; session history is isolated by authenticated account.
    api_accounts: dict[str, str] = Field(default_factory=dict, repr=False)

    @property
    def include_schemas_list(self) -> list[str]:
        return [s.strip() for s in self.db_include_schemas.split(",") if s.strip()]

    @property
    def chat_db_enabled(self) -> bool:
        return bool(self.chat_db_host and self.chat_db_name)


@lru_cache
def get_settings() -> Settings:
    return Settings()
