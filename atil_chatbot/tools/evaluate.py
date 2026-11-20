"""Read-only ATIL evaluation. Never opens or writes the chat-history database."""
from __future__ import annotations

import argparse
import asyncio
import json
from pathlib import Path
import time

from atil_chatbot.app.config import get_settings
from atil_chatbot.app.db_client import DbClient
from atil_chatbot.app.graph import AssistantGraph
from atil_chatbot.app.llm import LlmClient
from atil_chatbot.app.schema_provider import SchemaProvider
from atil_chatbot.app.sql_catalog import CATALOG
from atil_chatbot.app.sql_service import SqlService


# Separate questions with known scalar SQL answers exercise model-generated queries.
EVAL_SET = [
    ("trip_count", "trip jadvalidagi jami yozuvlar sonini ayting", "SELECT count(*) AS soni FROM public.trip"),
    ("driver_count", "driver jadvalida jami nechta yozuv bor?", "SELECT count(*) AS soni FROM public.driver"),
    ("vehicle_count", "transport_vehicle jadvalidagi barcha yozuvlar nechta?", "SELECT count(*) AS soni FROM public.transport_vehicle"),
    ("completed_trips", "trip jadvalida status COMPLETED bo'lgan jami reyslar sonini ayting", "SELECT count(*) AS soni FROM public.trip WHERE status = 'COMPLETED'"),
    ("waybill_count", "waybill jadvalidagi jami yozuvlar sonini ayting", "SELECT count(*) AS soni FROM public.waybill"),
]


async def evaluate(catalog_only: bool) -> dict:
    settings = get_settings()
    db = DbClient(settings)
    if not await db.ping():
        raise RuntimeError("ATIL database unavailable")
    report = {"catalog": [], "questions": [], "model_ready": None}
    for entry in CATALOG:
        start = time.monotonic()
        try:
            result = await db.run_select(entry.sql)
            item = {"question": entry.question, "ok": True, "rows": len(result["rows"])}
        except Exception as exc:
            item = {"question": entry.question, "ok": False, "error_type": type(exc).__name__}
        item["seconds"] = round(time.monotonic() - start, 2)
        report["catalog"].append(item)
        print(json.dumps(item, ensure_ascii=False), flush=True)
    if catalog_only:
        return report
    llm = LlmClient(settings)
    try:
        report["model_ready"] = await llm.ping()
        if not report["model_ready"]:
            return report
        schema = SchemaProvider(settings, db)
        graph = AssistantGraph(settings, llm, SqlService(settings, llm, db, schema), schema)
        for name, question, reference in EVAL_SET:
            start = time.monotonic()
            expected = await db.run_select(reference)
            state = await graph.run(question)
            actual = state.get("rows", [])
            expected_value = next(iter(expected["rows"][0].values()))
            actual_value = next(iter(actual[0].values())) if len(actual) == 1 and len(actual[0]) == 1 else None
            item = {"name": name, "ok": not state.get("error") and actual_value == expected_value,
                    "route": state.get("route"), "fast_path": state.get("fast_path", False),
                    "seconds": round(time.monotonic() - start, 2)}
            report["questions"].append(item)
            print(json.dumps(item, ensure_ascii=False), flush=True)
    finally:
        await llm.close()
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog-only", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = asyncio.run(evaluate(args.catalog_only))
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    passed = all(item["ok"] for item in report["catalog"] + report["questions"])
    return 0 if passed and (args.catalog_only or report["model_ready"]) else 1


if __name__ == "__main__":
    raise SystemExit(main())
