"""SQL tekshiruvchisi testlari — bazaga yubormasdan oldin sxema bo'yicha tekshirish."""
import pytest

from atil_chatbot.app.sql_validator import reference_filters, tables_in, validate


@pytest.mark.parametrize("sql", [
    "SELECT count(*) FROM tnb_analysis WHERE status = 'Chetlanish'",
    "SELECT g.name, count(*) AS n FROM tnb_analysis a "
    "JOIN tnb_sampling_point sp ON sp.code = a.sampling_point_code "
    "JOIN tnb_sampling_point_group g ON g.id = sp.group_id GROUP BY g.name ORDER BY n DESC",
    "WITH x AS (SELECT status, count(*) AS n FROM tnb_analysis GROUP BY status) SELECT status, n FROM x",
    "SELECT sub.k FROM (SELECT status AS k FROM tnb_analysis) sub",
    "SELECT i.name FROM instrument i JOIN status_dictionary sd ON sd.id = i.status_id WHERE sd.code = 'AVAILABLE'",
    'SELECT p."analysisStatus" FROM tnb_party p WHERE p."analysisStatus" = \'PASSED\'',
    "SELECT count(*) FROM tnb_analysis WHERE status ILIKE '%chet%'",
])
def test_valid_queries_pass(catalog, sql):
    assert validate(sql, catalog) == []


def test_unknown_table_with_suggestion(catalog):
    problems = validate("SELECT * FROM tnb_analyses", catalog)
    assert problems and "tnb_analysis" in problems[0]


def test_unknown_qualified_column(catalog):
    problems = validate("SELECT a.sampling_point FROM tnb_analysis a", catalog)
    assert problems and "sampling_point_code" in problems[0]


def test_unknown_unqualified_column(catalog):
    assert validate("SELECT foo FROM tnb_analysis", catalog)


def test_output_alias_not_flagged(catalog):
    assert validate("SELECT count(*) AS n FROM tnb_analysis ORDER BY n", catalog) == []


def test_camelcase_must_be_quoted(catalog):
    problems = validate("SELECT p.analysisStatus FROM tnb_party p", catalog)
    assert problems and '"analysisStatus"' in problems[0]


def test_wrong_value_case_suggests_exact(catalog):
    problems = validate("SELECT count(*) FROM tnb_analysis a WHERE a.status = 'chetlanish'", catalog)
    assert problems and "Ehtimol: 'Chetlanish'" in problems[0]


def test_unknown_value_in_list(catalog):
    problems = validate("SELECT count(*) FROM tnb_party WHERE analysis_status IN ('PASSED', 'DONE')", catalog)
    assert len(problems) == 1 and "'DONE'" in problems[0]


def test_sampled_dictionary_values_are_not_constraints(catalog):
    problems = validate(
        "SELECT count(*) FROM instrument i JOIN status_dictionary sd ON sd.id = i.status_id WHERE sd.code = 'OPEN'",
        catalog,
    )
    assert problems == []  # No CHECK: new codes may be added after the snapshot.


def test_status_id_compared_to_text_not_value_checked(catalog):
    """status_id id saqlaydi — uning qiymatlari (kodlar) bo'yicha tekshirilmaydi."""
    sql = "SELECT count(*) FROM instrument WHERE status_id = 'abc-123'"
    assert validate(sql, catalog) == []


def test_unparseable_sql_left_to_guard(catalog):
    assert validate("SELEC oops", catalog) == []


def test_tables_in_skips_ctes():
    sql = "WITH x AS (SELECT 1 FROM lab) SELECT * FROM x JOIN instrument i ON TRUE"
    assert tables_in(sql) == ["lab", "instrument"] or set(tables_in(sql)) == {"lab", "instrument"}


# ---------------- guruhlash jadvaliga «faol» filtri (hisobdan yozuv tushib qoladi) ----------------
def test_reference_table_state_filter_detected():
    bad = ("SELECT l.name AS lab, count(i.id) AS n FROM lab l JOIN instrument i ON l.id = i.lab_id "
           "WHERE l.is_active AND l.archived_at IS NULL GROUP BY l.id, l.name")
    [problem] = reference_filters(bad)
    assert "'lab'" in problem
    good = bad.replace("WHERE l.is_active AND l.archived_at IS NULL ", "WHERE i.archived_at IS NULL ")
    assert reference_filters(good) == []  # sanalayotgan jadvalning o'z filtri — to'g'ri
    # count(*) — sanalayotgan jadval noaniq, tekshirilmaydi (masalan: faol laboratoriyalar turi bo'yicha)
    assert reference_filters("SELECT l.lab_type, count(*) FROM lab l WHERE l.is_active GROUP BY l.lab_type") == []


def test_catalog_examples_have_no_reference_filters():
    from atil_chatbot.app.sql_catalog import CATALOG
    assert [e.question for e in CATALOG if reference_filters(e.sql)] == []
