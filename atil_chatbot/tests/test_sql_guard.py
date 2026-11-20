"""SQL xavfsizlik qatlami testlari — bazani himoya qilishning o'zagi."""
import pytest

from atil_chatbot.app.sql_guard import SqlNotAllowed, additive_columns, is_sensitive_column, sanitize_select, split_limit


# ---------------- Ruxsat etilgan so'rovlar ----------------
def test_simple_select_ok():
    out = sanitize_select("SELECT id, name FROM sample", 500)
    assert out.lower().startswith("select * from (")
    assert "limit 500" in out.lower()


def test_with_cte_ok():
    out = sanitize_select("WITH x AS (SELECT id FROM sample) SELECT id FROM x", 100)
    assert "limit 100" in out.lower()


def test_union_ok():
    out = sanitize_select("SELECT id FROM a UNION SELECT id FROM b", 50)
    assert "limit 50" in out.lower()


def test_join_and_aggregate_ok():
    out = sanitize_select(
        "SELECT p.name, count(*) FROM batch b JOIN plant p ON p.id=b.plant_id GROUP BY p.name",
        200,
    )
    assert "limit 200" in out.lower()


def test_trailing_semicolon_stripped():
    assert sanitize_select("SELECT 1;", 10).count(";") == 0


# ---------------- Yozuv/DDL amallari ----------------
@pytest.mark.parametrize("bad", [
    "DELETE FROM sample",
    "UPDATE sample SET x = 0",
    "INSERT INTO sample (id) VALUES (1)",
    "DROP TABLE sample",
    "TRUNCATE sample",
    "ALTER TABLE sample ADD COLUMN x int",
    "CREATE TABLE t (id int)",
    "CREATE TABLE t AS SELECT 1",
    "GRANT ALL ON sample TO public",
    "SET default_transaction_read_only = off",
    "VACUUM FULL",
    "COPY sample TO '/tmp/x.csv'",
])
def test_write_statements_rejected(bad):
    with pytest.raises(SqlNotAllowed):
        sanitize_select(bad, 500)


def test_select_into_rejected():
    """PostgreSQL'da `SELECT ... INTO` JADVAL YARATADI — bloklanishi shart."""
    with pytest.raises(SqlNotAllowed, match="INTO"):
        sanitize_select("SELECT * INTO new_table FROM sample", 500)


def test_for_update_lock_rejected():
    with pytest.raises(SqlNotAllowed):
        sanitize_select("SELECT * FROM sample FOR UPDATE", 500)


# ---------------- Injection ----------------
def test_multiple_statements_rejected():
    with pytest.raises(SqlNotAllowed):
        sanitize_select("SELECT 1; DROP TABLE sample", 500)


def test_stacked_injection_via_comment_rejected():
    with pytest.raises(SqlNotAllowed):
        sanitize_select("SELECT 1; -- x\nDELETE FROM sample", 500)


def test_cte_with_delete_rejected():
    with pytest.raises(SqlNotAllowed):
        sanitize_select("WITH d AS (DELETE FROM sample RETURNING *) SELECT * FROM d", 500)


# ---------------- Xavfli funksiyalar ----------------
@pytest.mark.parametrize("bad", [
    "SELECT pg_sleep(10)",
    "SELECT pg_read_file('/etc/passwd')",
    "SELECT lo_import('/etc/shadow')",
    "SELECT dblink('host=x', 'select 1')",
    "SELECT pg_terminate_backend(1)",
])
def test_dangerous_functions_rejected(bad):
    with pytest.raises(SqlNotAllowed):
        sanitize_select(bad, 500)


# ---------------- Maxfiy ma'lumot ----------------
@pytest.mark.parametrize("bad", [
    "SELECT * FROM pg_authid",
    "SELECT * FROM pg_shadow",
])
def test_credential_tables_rejected(bad):
    with pytest.raises(SqlNotAllowed):
        sanitize_select(bad, 500)


@pytest.mark.parametrize("bad", [
    "SELECT password FROM core_user",
    "SELECT password_hash FROM core_user",
    "SELECT u.api_key FROM users u",
    "SELECT access_token FROM session",
])
def test_sensitive_columns_rejected(bad):
    with pytest.raises(SqlNotAllowed):
        sanitize_select(bad, 500)


def test_is_sensitive_column():
    assert is_sensitive_column("password_hash")
    assert is_sensitive_column("API_KEY")
    assert not is_sensitive_column("username")
    assert not is_sensitive_column("created_at")


# ---------------- Chegaraviy holatlar ----------------
def test_empty_rejected():
    with pytest.raises(SqlNotAllowed):
        sanitize_select("   ", 500)


def test_garbage_rejected():
    with pytest.raises(SqlNotAllowed):
        sanitize_select("bu SQL emas!!", 500)


# ---------------- LIMIT ni ajratish (jami sonni hisoblash uchun) ----------------
def test_split_limit():
    n, unlimited = split_limit("SELECT a FROM t WHERE x = 1 ORDER BY a LIMIT 100")
    assert n == 100 and "LIMIT" not in unlimited.upper() and "ORDER BY a" in unlimited
    assert split_limit("SELECT a FROM t") is None
    assert split_limit("SELECT a FROM t LIMIT 5 OFFSET 10") is None
    assert split_limit("SELECT a FROM t UNION SELECT b FROM u LIMIT 5") is None


def test_additive_columns():
    grouped = ("SELECT g.name AS sex, count(*) AS n, count(*) FILTER (WHERE a.status = 'X') AS c, "
               "count(DISTINCT a.x) AS d, sum(a.q) AS s, round(avg(a.q), 1) AS o FROM t a GROUP BY g.name")
    assert additive_columns(grouped) == ["n", "c", "s"]  # DISTINCT va o'rtacha — qo'shib bo'lmaydi
    assert additive_columns(grouped + " LIMIT 5") == []  # top-N — yig'indi hammaniki emas
    assert additive_columns(grouped + " HAVING count(*) > 10") == []
    assert additive_columns("SELECT count(*) AS n FROM t") == []  # guruhsiz
