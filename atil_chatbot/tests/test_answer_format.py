"""Javob matni: qiymatlar ko'rinishi, ro'yxat, qoidaviy javob, belgilarni tozalash."""
from atil_chatbot.app.answer_format import (
    LIST_MAX,
    clean_text,
    display_value,
    fallback_answer,
    format_rows,
    strip_symbols,
)


def test_display_values():
    assert display_value("2026-09-18") == "18.09.2026"
    assert display_value("2026-09-18T10:23:45.123+05:00") == "18.09.2026 10:23"
    assert display_value("2026-07-11T00:00:00+05:00") == "11.07.2026"
    assert display_value("10:23:00") == "10:23"
    assert display_value(1472.0) == "1472"
    assert display_value(77.50) == "77.5"
    assert display_value(33.3333) == "33.33"
    assert display_value(0.00352) == "0.0035"
    assert display_value(True) == "ha" and display_value(False) == "yo'q"
    assert display_value(None) == ""
    assert display_value("x" * 500).endswith("...")


def test_list_rows_with_name_as_head():
    res = {"rows": [{"sex": "Ammiak", "tahlillar_soni": 1472, "chetlanishlar_soni": 398},
                    {"sex": None, "tahlillar_soni": 5, "chetlanishlar_soni": None}], "row_count": 2}
    assert format_rows(res) == ("1. Ammiak: tahlillar soni 1472, chetlanishlar soni 398\n"
                                "2. ko'rsatilmagan: tahlillar soni 5")


def test_list_rows_without_text_head():
    res = {"rows": [{"partiya_raqami": 720, "sana": "2026-09-18"}, {"partiya_raqami": 5, "sana": None}]}
    assert format_rows(res) == "1. partiya raqami 720, sana 18.09.2026\n2. partiya raqami 5"


def test_filtered_constant_column_not_repeated():
    res = {"sql": "SELECT ... WHERE a.status = 'Chetlanish'",
           "rows": [{"nuqta": "A", "tahlilchi": "Norova F.", "holat": "Chetlanish"},
                    {"nuqta": "B", "tahlilchi": "Norova F.", "holat": "Chetlanish"}]}
    # holat — filtr qiymati, olib tashlanadi; tahlilchi bir xil, lekin filtr emas — qoladi
    assert format_rows(res) == "1. A: tahlilchi Norova F.\n2. B: tahlilchi Norova F."


def test_whitespace_in_values_collapsed():
    res = {"rows": [{"nuqta": "Metanol  rezervuar\nV-55"}, {"nuqta": "B"}]}
    assert format_rows(res) == "1. Metanol rezervuar V-55\n2. B"


def test_long_list_is_cut_with_total():
    rows = [{"nomi": f"N{i}"} for i in range(LIST_MAX + 5)]
    text = format_rows({"rows": rows, "row_count": len(rows)})
    assert text.count("\n") == LIST_MAX and text.endswith(f"jami {LIST_MAX + 5} ta.")
    truncated = format_rows({"rows": rows[:3], "row_count": 3, "truncated": True, "total_count": 900})
    assert truncated.endswith("Birinchi 3 tasi ko'rsatildi, jami 900 ta.")


def test_fallback_answer_variants():
    assert fallback_answer({"rows": []}) == "So'rov bo'yicha ma'lumot topilmadi."
    assert fallback_answer({"rows": [{"tahlillar_soni": 5, "oxirgi_sana": "2026-09-21"}]}) == (
        "Tahlillar soni: 5\nOxirgi sana: 21.09.2026")
    many = fallback_answer({"rows": [{"a": "x"}, {"a": "y"}], "row_count": 2})
    assert many == "Jami 2 ta yozuv topildi.\n\n1. x\n2. y"


def test_clean_text_removes_markdown_and_symbols():
    raw = "### Natija\n**Jami** 1472 ta ✅ «Ammiak» sexida.\n* birinchi\n\n\n\noxiri ⚠️"
    assert clean_text(raw) == "Natija\nJami 1472 ta Ammiak sexida.\n- birinchi\n\noxiri"


def test_uzbek_apostrophes_kept_and_normalized():
    # o`, o‘, oʻ, maʼ — o'chirilmaydi (aks holda «otkazilgan», «malumot»), oddiy ' ga keltiriladi
    raw = "O‘zbek ko`mir: o’tkazilgan maʼlumot, oʻn"
    assert clean_text(raw) == "O'zbek ko'mir: o'tkazilgan ma'lumot, o'n"
    assert strip_symbols("ko`") + strip_symbols("p") == "ko'p"


def test_strip_symbols_is_chunk_safe():
    chunks = ["**Ja", "mi*", "* 14", "72 ✅"]
    assert "".join(strip_symbols(c) for c in chunks) == "Jami 1472 "


def test_code_written_text_in_requested_language():
    rows = [{"nomi": f"N{i}", "faol": True} for i in range(3)]
    res = {"rows": rows, "row_count": 3, "truncated": True, "total_count": 900}
    assert format_rows(res, "ru").endswith("Показаны первые 3, всего 900.")
    assert format_rows(res, "en").startswith("1. N0: faol yes")
    assert fallback_answer({"rows": []}, "en") == "No data found for this request."
    assert fallback_answer({"rows": rows[:2], "row_count": 2}, "ru").startswith("Всего найдено записей: 2.")


def test_totals_line_after_list():
    res = {"rows": [{"sex": "A", "tahlillar_soni": 33, "chetlanishlar_soni": 11},
                    {"sex": "B", "tahlillar_soni": 27, "chetlanishlar_soni": 2}],
           "totals": {"tahlillar_soni": 60, "chetlanishlar_soni": 13}}
    assert format_rows(res).endswith("\nJami: tahlillar soni 60, chetlanishlar soni 13")
    assert format_rows(res, "ru").endswith("\nИтого: tahlillar soni 60, chetlanishlar soni 13")


def test_backtick_apostrophe_in_data_not_rendered_as_code():
    res = {"rows": [{"kod": "007-ATSETAL`DEGID", "metodika": "Atsetal`degid"}, {"kod": "B", "metodika": "C"}]}
    assert format_rows(res).startswith("1. 007-ATSETAL'DEGID: metodika Atsetal'degid")
