"""HTTP Basic autorizatsiya — ATIL AI ning barcha endpointlari uchun.

Login va parol loyiha ildizidagi `.env` dan olinadi: `API_USERNAME`,
`API_PASSWORD`.

Bu dependency `main.py` da ilovaning O'ZIGA biriktiriladi
(`FastAPI(dependencies=[...])`), shuning uchun yangi router qo'shilganda uni
alohida ulash SHART EMAS — himoya avtomatik qo'llanadi. Aks holda navbatdagi
OCR moduli e'tibordan chetda qolib, ochiq turib qolishi mumkin edi.

`/docs`, `/redoc` va `/openapi.json` ochiq qoladi: ular FastAPI'ning ichki
Starlette route'lari bo'lgani uchun ilova darajasidagi dependency ularga
tegmaydi. Bu ataylab shunday — Swagger sahifasi ochilmasa, undagi
"Authorize" tugmasi orqali login kiritib bo'lmasdi.
"""

from __future__ import annotations

import os
import secrets
from pathlib import Path

from dotenv import load_dotenv
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPBasic, HTTPBasicCredentials

load_dotenv(Path(__file__).resolve().parent / ".env")

API_USERNAME = (os.getenv("API_USERNAME") or "").strip()
API_PASSWORD = os.getenv("API_PASSWORD") or ""

# auto_error=False emas: login umuman yuborilmaganda ham 401 va
# `WWW-Authenticate: Basic` qaytishi kerak — brauzer shunda login oynasini
# ko'rsatadi.
_basic = HTTPBasic(description="`.env` dagi API_USERNAME va API_PASSWORD")

_UNAUTHORIZED = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Login yoki parol noto'g'ri",
    headers={"WWW-Authenticate": "Basic"},
)


def require_api_credentials(
    request: Request,
    credentials: HTTPBasicCredentials = Depends(_basic),
) -> str:
    """Login/parolni tekshiradi; mos kelmasa 401 ko'taradi.

    Sozlama bo'sh bo'lsa ilova ochiq qolmaydi — barcha so'rov rad etiladi.
    Aks holda `.env` da API_PASSWORD unutilsa, himoya jimgina o'chib qolar
    va buni hech kim sezmasdi.
    """
    settings = getattr(request.app.state, "settings", None)
    accounts = dict(getattr(settings, "api_accounts", {}))
    if API_USERNAME and API_PASSWORD:
        accounts[API_USERNAME] = API_PASSWORD
    if not accounts:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="API_USERNAME/API_PASSWORD .env da sozlanmagan",
        )

    # compare_digest — vaqt bo'yicha hujumdan (timing attack) himoya: oddiy
    # `==` mos kelmagan birinchi belgida to'xtaydi va javob vaqti orqali
    # parolni belgima-belgi topish imkonini beradi.
    expected = accounts.get(credentials.username)
    user_ok = bool(expected)
    password_ok = secrets.compare_digest(
        credentials.password.encode("utf-8"), (expected if user_ok else "invalid-account").encode("utf-8")
    )
    # Ikkalasi ham tekshiriladi (`and` bilan qisqa tutashuv qilinmaydi) —
    # noto'g'ri login va noto'g'ri parol bir xil vaqt olsin.
    if not (user_ok and password_ok):
        raise _UNAUTHORIZED

    request.state.principal = credentials.username
    return credentials.username
