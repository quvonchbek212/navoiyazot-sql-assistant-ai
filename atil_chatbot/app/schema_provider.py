"""Sxema provayderi — LLM ga beriladigan baza sxemasini tayyorlaydi.

Manba: `schema/schema.json` (tools/generate_ddl.py yaratadi). Fayl bo'lmasa —
jonli introspeksiya (faqat ustun nomlari va turlari; zaxira variant).

To'liq DDL ~150 KB — promptga sig'maydi. Shuning uchun:
  1. Router LLM savolga mos jadvallarni `listing()` katalogidan tanlaydi.
  2. `bundle()` ularning DDL bloklarini FK qo'shnilari bilan (masalan
     transport_vehicle, driver, reference_data) byudjet ichida yig'adi.
  3. Router jadval tanlay olmasa — `rank()` leksik zaxira tanlovi
     (so'z bo'laklari + domen sinonimlari).
"""
from __future__ import annotations

import logging
import asyncio
import pathlib
import time
from dataclasses import dataclass

from . import domain
from .config import Settings
from .db_client import DbClient
from .schema_catalog import Column, SchemaCatalog, Table
from .sql_catalog import normalize, tokens

logger = logging.getLogger("schema_provider")

LIVE_TTL_SECONDS = 600
DEFAULT_TABLES = ("trip", "transport_vehicle", "driver")
# Promptda eng ko'p uchraydigan jadvallar — sxema matnida doim shu tartibda birinchi turadi.
CORE_ORDER = DEFAULT_TABLES + ("transport_request", "waybill", "route", "reference_data",
                               "fuel_record", "vehicle_repair")


def _block_order(table: str) -> tuple[int, str]:
    return (CORE_ORDER.index(table), "") if table in CORE_ORDER else (len(CORE_ORDER), table)


@dataclass
class SchemaBundle:
    text: str
    source: str          # "schema-file" | "live-introspection"
    tables: list[str]
    total_tables: int

    @property
    def selected_tables(self) -> int:
        return len(self.tables)

    @property
    def partial(self) -> bool:
        return len(self.tables) < self.total_tables


class SchemaProvider:
    def __init__(self, settings: Settings, db: DbClient):
        self._s = settings
        self._db = db
        self._catalog: SchemaCatalog | None = None
        self._source = ""
        self._mtime = 0.0
        self._loaded_at = 0.0
        self._refresh_at = 0.0
        self._refresh_lock = asyncio.Lock()
        self.live_verified = False

    # ---------------- yuklash ----------------
    def _path(self) -> pathlib.Path:
        return pathlib.Path(self._s.schema_file).expanduser()

    async def catalog(self) -> SchemaCatalog:
        path = self._path()
        if path.is_file():
            mtime = path.stat().st_mtime
            if self._catalog is None or mtime != self._mtime:
                self._catalog = SchemaCatalog.load(path)
                self._source, self._mtime = "schema-file", mtime
                logger.info("Sxema yuklandi: %s (%d jadval)", path.name, len(self._catalog.tables))
            await self._refresh_live()
            return self._catalog
        if self._catalog is None or time.monotonic() - self._loaded_at > LIVE_TTL_SECONDS:
            logger.warning("schema.json yo'q — jonli introspeksiya (aniqlik past). "
                           "Yarating: python -m atil_chatbot.tools.generate_ddl")
            self._catalog = await self._db.introspect_catalog()
            self.live_verified = True
            self._source, self._loaded_at = "live-introspection", time.monotonic()
        return self._catalog

    async def _refresh_live(self) -> None:
        ttl = self._s.schema_refresh_seconds
        if ttl <= 0 or time.monotonic() < self._refresh_at:
            return
        async with self._refresh_lock:
            if time.monotonic() < self._refresh_at:
                return
            try:
                live = await self._db.introspect_catalog()
                if not live.tables:
                    raise ValueError("O'qish huquqli sxema bo'sh")
                # The live schema controls accessibility/columns/constraints.
                # Snapshot examples are hints only, never an exhaustive enum.
                for name, table in live.tables.items():
                    old = self._catalog.table(name) if self._catalog else None
                    if old:
                        for column in table.columns:
                            previous = old.column(column.name)
                            if previous and previous.type == column.type and not column.sensitive:
                                column.values = previous.values
                self._catalog = live
                self._source = "live-metadata"
                self.live_verified = True
                self._refresh_at = time.monotonic() + ttl
            except Exception as exc:
                self.live_verified = False
                self._refresh_at = time.monotonic() + min(ttl, 30)
                logger.warning("Jonli sxema tekshiruvi ishlamadi: %s", type(exc).__name__)

    @property
    def source(self) -> str:
        return self._source

    # ---------------- katalog (jadval tanlash uchun) ----------------
    async def listing(self, question: str | None = None) -> str:
        cat = await self.catalog()
        if question is None:
            return "\n".join(cat.catalog_line(n) for n in sorted(cat.tables))
        detailed = set(await self.rank(question, k=24)) | {n for n in CORE_ORDER if n in cat.tables}
        lines = [cat.catalog_line(n) for n in sorted(detailed)]
        # Every accessible relation remains selectable without repeating hundreds
        # of long descriptions for each classification request.
        others = sorted(set(cat.tables) - detailed)
        if others:
            lines.append("BOSHQA RUXSATLI JADVALLAR (kerak bo'lsa shulardan ham tanla): " + ", ".join(others))
        return "\n".join(lines)

    # ---------------- leksik zaxira tanlov ----------------
    async def rank(self, question: str, k: int = 5) -> list[str]:
        cat = await self.catalog()
        q = normalize(question)
        toks = tokens(question)
        scores: dict[str, float] = {}
        for term, tables in domain.SYNONYMS.items():
            if term in q:
                for t in tables:
                    scores[t] = scores.get(t, 0) + 10
        for name, table in cat.tables.items():
            parts = {p[:6] for p in name.split("_") if len(p) > 2}
            score = 5 * len(toks & parts)
            if name.lower() in q:
                score += 1000
            note = domain.TABLE_NOTES.get(name, "").split("\n", 1)[0]
            if note:
                score += 2 * len(toks & tokens(note))
            if score:
                scores[name] = scores.get(name, 0) + score
        ranked = [
            (s * (0.5 if cat.tables[n].rows == 0 else 1.0), n)
            for n, s in scores.items() if n in cat.tables
        ]
        ranked.sort(reverse=True)
        return [n for s, n in ranked[:k] if s > 0]

    # ---------------- DDL to'plami ----------------
    async def bundle(self, question: str, tables: list[str] | None = None,
                     extra: list[str] | None = None) -> SchemaBundle:
        """Savol uchun DDL matni.

        tables — router tanlagan jadvallar (asosiy); extra — misollar jadvallari.
        Ikkalasi bo'sh bo'lsa leksik tanlov, u ham bo'sh bo'lsa — asosiy TNB jadvallari.
        """
        cat = await self.catalog()
        primary = [t for t in (tables or []) if t in cat.tables]
        if not primary:
            primary = await self.rank(question)
        if not primary:
            primary = [t for t in DEFAULT_TABLES if t in cat.tables]
        for general, main in domain.MAIN_TABLES.items():
            if general in primary and main in cat.tables and main not in primary:
                primary.insert(primary.index(general), main)

        chosen: list[str] = []
        for t in primary + [t for t in (extra or []) if t in cat.tables]:
            if t not in chosen:
                chosen.append(t)

        budget = self._s.schema_char_budget
        blocks: dict[str, str] = {}
        used = 0
        for t in chosen:
            block = cat.render_table(t)
            if blocks and used + len(block) > budget:
                continue
            blocks[t] = block
            used += len(block) + 2

        # Asosiy jadvallarning 1 qadam FK qo'shnilari (transport, haydovchi, bo'lim) —
        # joy bo'lsa. Doim NULL ustun va bo'sh jadvalga bog'lanish foydasiz — faqat prompt o'sadi.
        neighbours: list[str] = []
        for t in primary:
            table = cat.tables[t]
            for fk in table.fks:
                ref = fk["ref_table"]
                column = table.column(fk["column"])
                if (ref not in cat.tables or ref in blocks or ref in neighbours
                        or cat.tables[ref].rows == 0 or (column is not None and column.always_null)):
                    continue
                neighbours.append(ref)
        for ref in neighbours[:8]:
            block = cat.render_table(ref)
            if used + len(block) <= budget:
                blocks[ref] = block
                used += len(block) + 2

        # Barqaror tartib: o'xshash savollar promptining sxema qismi bir xil boshlanadi va
        # vLLM prefiks keshidan olinadi (keshsiz ~8k token prefill — o'nlab soniya).
        ordered = sorted(blocks, key=_block_order)
        return SchemaBundle(
            text="\n\n".join(blocks[t] for t in ordered),
            source=self._source,
            tables=ordered,
            total_tables=len(cat.tables),
        )

    async def render(self, table: str) -> str | None:
        cat = await self.catalog()
        return cat.render_table(table) if table in cat.tables else None
