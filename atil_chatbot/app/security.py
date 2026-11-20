"""Kirish xavfsizlik qatlami — foydalanuvchi savolini LLM ga yubormasdan oldin tekshiradi.

Bu 1-qatlam (erta to'siq). Asosiy kafolatlar baribir pastda turadi:
  2-qatlam: read-only DB foydalanuvchi
  3-qatlam: read-only sessiya (default_transaction_read_only)
  4-qatlam: sql_guard (AST tekshiruvi + qayta render)
  5-qatlam: majburiy LIMIT

Bu yerda niyat darajasida bloklaymiz: buzg'unchi so'rovlar, prompt-injection va
maxfiy ma'lumot (parol/token) ovlash urinishlari.
"""
from __future__ import annotations

import re
from dataclasses import dataclass

# --- Toifalar ---
DESTRUCTIVE = "destructive"
INJECTION = "injection"
CREDENTIALS = "credentials"
DANGEROUS_FN = "dangerous_function"


@dataclass(frozen=True)
class ScreenResult:
    blocked: bool
    category: str = ""
    detail: str = ""


def _rx(*patterns: str) -> list[re.Pattern[str]]:
    return [re.compile(p, re.IGNORECASE | re.UNICODE) for p in patterns]


# 1) To'g'ridan-to'g'ri SQL yozuv/DDL shakllari
_SQL_WRITE = _rx(
    r"\bdrop\s+(table|database|schema|view|index|column)\b",
    r"\btruncate\b",
    r"\bdelete\s+from\b",
    r"\binsert\s+into\b",
    r"\bupdate\s+\w+\s+set\b",
    r"\balter\s+(table|database|schema|role|user)\b",
    r"\bcreate\s+(table|database|schema|user|role|index)\b",
    r"\b(grant|revoke)\s+",
    r"\bselect\b.+\binto\s+\w+",
    r"\bset\s+.*read_only\b",
)

# 2) Tabiiy tildagi buzg'unchi niyat: fe'l + baza obyekti.
#    MUHIM: o'tgan zamon sifatdoshlari ("o'chirilgan", "o'zgartirilgan",
#    "удалённые") — bu O'QISH so'rovlari, ular bloklanmasligi kerak.
_PART = r"(?!ilgan|ilmagan|ilayotgan|ilgach|ingan)"
_DESTRUCTIVE_VERB = _rx(
    rf"\bo\s*['`’ʻ]?\s*chir{_PART}",           # o'chir, o'chirib — ammo "o'chirilgan" emas
    r"\byo\s*['`’ʻ]?\s*q\s+qil(?!ingan)",      # yo'q qil
    r"\btozala(?!ngan|nmagan)\b",
    r"\bbo\s*['`’ʻ]?\s*shat(?!ilgan)",         # bo'shat
    r"\bdelete\b", r"\bremove\b", r"\bwipe\b", r"\berase\b", r"\bdrop\b",
    r"\bудал(?![её]нн)", r"\bочист(?!ен)", r"\bсотри\b", r"\bснес(?!енн)",
    rf"\bo\s*['`’ʻ]?\s*zgartir{_PART}",
    r"\byangila(?!ngan|nmagan)\b",
    r"\btahrirla(?!ngan|nmagan)\b",
    r"\bqo\s*['`’ʻ]?\s*sh(ing|amiz)\b",
    r"\bизмен(?![её]нн)", r"\bобнов(?!л[её]нн)", r"\bвставь",
)
_DB_OBJECT = _rx(
    r"\breys", r"\bmashina", r"\bhaydovchi", r"\btransport", r"\byo.?l varaq",
    r"\bariza", r"\bbuyurtma", r"\byoqilg", r"\btrip", r"\bvehicle", r"\bdriver",
    r"\bрейс", r"\bмашин", r"\bводител", r"\bтранспорт", r"\bзаявк",
    r"\bjadval", r"\bbaza", r"\btable\b", r"\bdatabase\b", r"\bschema\b",
    r"\bma\s*['`’ʻ]?\s*lumot", r"\bmalumot", r"\byozuv",
    r"\bтаблиц", r"\bбаз[уые]", r"\bданны", r"\bзапис",
    # domen obyektlari: «tahlillarni o'chir», «sertifikatni o'zgartir»
    r"\btahlil", r"\bnamuna", r"\bpartiya", r"\bsertifikat", r"\bmetodika", r"\basbob",
    r"\breagent", r"\bnatija", r"\bfoydalanuvchi", r"\bnuqta",
    r"\bанализ", r"\bпроб", r"\bпарти", r"\bсертификат", r"\bметодик",
    r"\banalys", r"\bsample", r"\bbatch", r"\bcertificat", r"\bmethod", r"\binstrument",
    r"\breagent", r"\brecord", r"\bresult", r"\buser", r"\bdata\b",
)

# 3) Prompt-injection
_INJECTION = _rx(
    r"\b(ignore|disregard|forget)\b.{0,30}\b(previous|prior|above|all|earlier)\b.{0,20}"
    r"\b(instruction|prompt|rule|direction)",
    r"\b(system|tizim)\s+(prompt|message|ko\s*['`’ʻ]?\s*rsatma)",
    r"ko\s*['`’ʻ]?\s*rsatmalaring(ni|izni)?\s+(ko\s*['`’ʻ]?\s*rsat|ayt|yoz)",
    r"\b(oldingi|avvalgi)\s+(ko\s*['`’ʻ]?\s*rsatma|qoida|buyruq)\w*\s*(ni)?\s*(unut|e['`’ʻ]?tiborsiz)",
    r"\b(sen endi|siz endi)\b", r"\byou are now\b", r"\bact as\b", r"\bpretend to be\b",
    r"\b(забудь|игнорируй)\b",
    r"\b(reveal|show|print)\b.{0,20}\b(your|the)\b.{0,20}\b(prompt|instruction|system)",
    r"\bdeveloper mode\b", r"\bjailbreak\b",
)

# 4) Maxfiy ma'lumot ovlash
_CREDENTIALS = _rx(
    r"\bparol", r"\bpassword", r"\bpasswd\b", r"\bpwd\b",
    r"\bmaxfiy\s+(kalit|so\s*['`’ʻ]?\s*z)", r"\bsecret\b",
    r"\bapi[_\s-]?key\b", r"\btoken\b", r"\bcredential",
    r"\bpg_shadow\b", r"\bpg_authid\b", r"\brolpassword\b",
    r"\bпароль", r"\bсекрет",
)

# 5) Xavfli funksiyalar / fayl tizimi
_DANGEROUS_FN = _rx(
    r"\bpg_sleep\b", r"\bpg_read_file\b", r"\bpg_read_binary_file\b", r"\bpg_ls_dir\b",
    r"\blo_import\b", r"\blo_export\b", r"\bdblink\b",
    r"\bpg_terminate_backend\b", r"\bpg_cancel_backend\b",
    r"\bcopy\b.{0,40}\b(to|from)\s+(program|'|\")",
)


def _any(patterns: list[re.Pattern[str]], text: str) -> str | None:
    for p in patterns:
        m = p.search(text)
        if m:
            return m.group(0)
    return None


def screen_question(question: str) -> ScreenResult:
    """Savolni tekshiradi. Bloklansa — toifa va sababni qaytaradi."""
    text = (question or "").strip()
    if not text:
        return ScreenResult(False)

    if hit := _any(_DANGEROUS_FN, text):
        return ScreenResult(True, DANGEROUS_FN, hit)
    if hit := _any(_SQL_WRITE, text):
        return ScreenResult(True, DESTRUCTIVE, hit)
    if hit := _any(_INJECTION, text):
        return ScreenResult(True, INJECTION, hit)
    if hit := _any(_CREDENTIALS, text):
        return ScreenResult(True, CREDENTIALS, hit)

    # Tabiiy tildagi buzg'unchi niyat: fe'l VA baza obyekti birga kelsa.
    verb = _any(_DESTRUCTIVE_VERB, text)
    obj = _any(_DB_OBJECT, text)
    if verb and obj:
        return ScreenResult(True, DESTRUCTIVE, f"{verb} … {obj}")

    return ScreenResult(False)
