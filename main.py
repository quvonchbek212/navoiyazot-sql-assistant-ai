"""Navoiyazot Logistics: AI Assistant & Natural Language Chatbot Service."""
import logging
import sys
from pathlib import Path
import uvicorn
from fastapi import FastAPI

sys.path.insert(0, str(Path(__file__).resolve().parent / "atil_chatbot"))
from atil_chatbot.app.api import router as chatbot_router
from atil_chatbot.app.compat import router as chat_compat_router
from db.connect_db_for_server import start_keepalive

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")

app = FastAPI(
    title="Navoiyazot Logistics · AI Chatbot API",
    description="Natural language enterprise assistant for logistics queries, SQL translation, and data exploration.",
    version="1.0.0"
)

app.include_router(chatbot_router)
app.include_router(chat_compat_router)

@app.on_event("startup")
def on_startup():
    start_keepalive()

@app.get("/healthz", tags=["Health"])
async def healthz():
    return {"status": "ok", "service": "chatbot"}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8006, reload=False)
