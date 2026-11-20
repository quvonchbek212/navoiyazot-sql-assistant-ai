# Navoiyazot Logistics · AI Assistant & Chatbot

Conversational AI assistant and natural language database interface for **Navoiyazot chemical logistics management**.

---

## Key Capabilities

* **Natural Language Text-to-SQL**: Translates questions in Uzbek, Russian, and English into safe, optimized PostgreSQL queries.
* **Logistics Domain Knowledge**: Pre-indexed schema mappings for trips, waybills, fuel dispensary records, repairs, and warehouse inventory.
* **SQL Injection & Security Shield**: Automated question screening rejects adversarial prompt injection and destructive SQL statements.
* **Real-Time Data Streaming**: Streams answers token-by-token alongside structured data table grids.

---

## Tech Stack

* **Language**: Python 3.12+
* **Framework**: FastAPI (Async Streaming SSE & JSON)
* **Agentic Graph**: LangGraph
* **LLM Engine**: OpenAI-compatible client (supporting vLLM / Gemma 4 / local models)
* **SQL Engine**: Sqlglot, Psycopg v3 pool

---

## Core Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/chat` | Send question and receive natural language answer with tables |
| `GET` | `/api/v1/chat/stream` | Server-Sent Events (SSE) streaming chat endpoint |
| `GET` | `/healthz` | Service health status |

---

## Quick Start

### 1. Installation
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Configuration
```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=atil_navoiyazot
DB_USER=postgres
DB_PASSWORD=your_password
VLLM_BASE_URL=http://localhost:8000/v1
VLLM_MODEL=gemma4-31b
```

### 3. Run Service
```bash
python main.py
# Server runs on http://localhost:8006 (Docs: http://localhost:8006/docs)
```
