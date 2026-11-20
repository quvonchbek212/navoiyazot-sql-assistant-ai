"""Read accessible schema metadata without scanning information_schema views."""

from __future__ import annotations

from config import DB_SCHEMA

from .connect_db_for_server import read_only_cursor


def live_columns(*, text_only: bool = False) -> list[dict[str, str]]:
    """Columns of relations readable by this user, matching regenerate_ddl.py."""
    with read_only_cursor() as cur:
        cur.execute(
            "SELECT c.oid, c.relname AS table_name "
            "FROM pg_catalog.pg_class c "
            "JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace "
            "WHERE n.nspname = %s AND c.relkind IN ('r','p','v','f') "
            "AND has_table_privilege(c.oid, 'SELECT')",
            (DB_SCHEMA,),
        )
        names = {row["oid"]: row["table_name"] for row in cur.fetchall()}
        if not names:
            return []
        type_filter = (
            " AND a.atttypid IN ('text'::regtype, 'varchar'::regtype)"
            if text_only else ""
        )
        # Large OID arrays can make PostgreSQL choose a full catalog scan.
        # Keep each lookup small even as the accessible schema grows.
        relation_ids = list(names)
        columns = []
        for offset in range(0, len(relation_ids), 64):
            cur.execute(
                "SELECT a.attrelid, a.attname AS column_name "
                "FROM pg_catalog.pg_attribute a "
                "WHERE a.attrelid = ANY(%s::oid[]) "
                "AND a.attnum > 0 AND NOT a.attisdropped" + type_filter,
                (relation_ids[offset:offset + 64],),
            )
            columns.extend(cur.fetchall())
        return sorted(
            ({"table_name": names[row["attrelid"]], "column_name": row["column_name"]}
             for row in columns),
            key=lambda row: (row["table_name"], row["column_name"]),
        )
