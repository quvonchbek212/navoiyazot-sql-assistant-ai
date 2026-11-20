"""Qism tarixi — qo'lda yozilgan voqealar ("bugun moy almashtirildi, 45 210 km").

NIMA UCHUN KERAK. ATIL bazasida ta'mir va qism so'rovlari bor, lekin har
almashtirish u yerga tushmaydi (moy ko'pincha ta'mir ochmasdan
almashtiriladi). Hozir 15 qismning ko'pchiligi uchun tarix yo'q — holati
"noma'lum". Mexanik shu yerga yozgan kundan boshlab qism kuzatila boshlaydi.

QAYERDA: ATIL bazasiga yozib bo'lmaydi (READ ONLY, faqat SELECT). Jadval
suhbat tarixi bazasida (`CHAT_DB_*`) va uning pool'i qayta ishlatiladi.

Yozuv O'CHIRILMAYDI va o'zgartirilmaydi: xato yozilgan bo'lsa yangi to'g'ri
yozuv qo'shiladi — tarix shunday ishonchli qoladi.
"""

from __future__ import annotations

import logging
import sys
import threading
from pathlib import Path
from typing import Any, Sequence

_CHATBOT_DIR = Path(__file__).resolve().parent.parent / "atil_chatbot"
if str(_CHATBOT_DIR) not in sys.path:
    sys.path.insert(0, str(_CHATBOT_DIR))

from psycopg2 import sql as pg_sql  # noqa: E402

from config import CHAT_DB_SCHEMA  # noqa: E402  (atil_chatbot/config.py)
from db import chat_history_db  # noqa: E402

from parts_control import config  # noqa: E402

logger = logging.getLogger(__name__)

ACTIONS = ("REPLACED", "REPAIRED", "SERVICED", "INSPECTED")

_ready = False
_lock = threading.Lock()


class HistoryError(RuntimeError):
    pass


def _table() -> pg_sql.Composed:
    return pg_sql.SQL("{}.{}").format(
        pg_sql.Identifier(CHAT_DB_SCHEMA), pg_sql.Identifier(config.HISTORY_TABLE)
    )


def _ensure_table() -> None:
    global _ready
    if _ready:
        return
    if not chat_history_db.is_configured():
        raise HistoryError("CHAT_DB_* sozlanmagan")
    with _lock:
        if _ready:
            return
        try:
            with chat_history_db._cursor(commit=True) as cur:  # noqa: SLF001 — umumiy pool
                cur.execute(pg_sql.SQL(
                    "CREATE TABLE IF NOT EXISTS {} ("
                    " id BIGSERIAL PRIMARY KEY,"
                    " created_at TIMESTAMPTZ NOT NULL DEFAULT now(),"
                    " recorded_by TEXT,"
                    " vehicle_id TEXT NOT NULL,"
                    " plate_number TEXT,"
                    " component TEXT NOT NULL,"
                    " action TEXT NOT NULL,"
                    " event_date DATE NOT NULL,"
                    " odometer_km NUMERIC,"
                    " engine_hours NUMERIC,"
                    " note TEXT"
                    ")"
                ).format(_table()))
                cur.execute(pg_sql.SQL(
                    "CREATE INDEX IF NOT EXISTS {} ON {} (vehicle_id, component, event_date DESC)"
                ).format(pg_sql.Identifier(f"{config.HISTORY_TABLE}_vehicle_idx"), _table()))
        except Exception as exc:  # noqa: BLE001
            raise HistoryError(str(exc).strip()[:200]) from exc
        _ready = True


def write(entry: dict[str, Any]) -> int:
    _ensure_table()
    try:
        with chat_history_db._cursor(commit=True) as cur:  # noqa: SLF001
            cur.execute(
                pg_sql.SQL(
                    "INSERT INTO {} (recorded_by, vehicle_id, plate_number, component, action,"
                    " event_date, odometer_km, engine_hours, note)"
                    " VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id"
                ).format(_table()),
                (entry.get("recorded_by"), entry["vehicle_id"], entry.get("plate_number"),
                 entry["component"], entry["action"], entry["event_date"],
                 entry.get("odometer_km"), entry.get("engine_hours"), entry.get("note")),
            )
            return int((cur.fetchone() or {}).get("id"))
    except Exception as exc:  # noqa: BLE001
        raise HistoryError(str(exc).strip()[:200]) from exc


def read(vehicle_ids: Sequence[str] | None = None) -> list[dict[str, Any]]:
    """Qo'lda yozilgan voqealar. Jadval hali yo'q bo'lsa — bo'sh ro'yxat."""
    _ensure_table()
    where = pg_sql.SQL("WHERE vehicle_id = any(%s)") if vehicle_ids else pg_sql.SQL("")
    params: list[Any] = [list(vehicle_ids)] if vehicle_ids else []
    try:
        with chat_history_db._cursor() as cur:  # noqa: SLF001
            cur.execute(pg_sql.SQL(
                "SELECT id, created_at, recorded_by, vehicle_id, plate_number, component, action,"
                " event_date, odometer_km, engine_hours, note FROM {} {} ORDER BY event_date, id"
            ).format(_table(), where), params)
            return [dict(row) for row in cur.fetchall()]
    except Exception as exc:  # noqa: BLE001
        raise HistoryError(str(exc).strip()[:200]) from exc
