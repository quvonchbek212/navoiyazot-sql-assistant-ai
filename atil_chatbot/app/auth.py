"""HTTP Basic autorizatsiya — ilovaning barcha endpointlari uchun.

Login va parol `.env` dan olinadi: `API_USERNAME`, `API_PASSWORD`.

Dependency `main.py` da ilovaning O'ZIGA biriktiriladi
(`FastAPI(dependencies=[...])`) — yangi router qo'shilganda uni alohida ulash
shart emas, himoya avtomatik qo'llanadi.

`/docs`, `/redoc` va `/openapi.json` ochiq qoladi (ular FastAPI'ning ichki
route'lari, ilova darajasidagi dependency ularga tegmaydi) — Swagger sahifasi
ochilmasa, undagi "Authorize" tugmasi orqali login kiritib bo'lmasdi.
"""
from __future__ import annotations

import logging
import secrets

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPBasic, HTTPBasicCredentials

from .config import Settings, get_settings

logger = logging.getLogger("auth")

# Login yuborilmaganda ham 401 + `WWW-Authenticate: Basic` qaytadi.
_basic = HTTPBasic(description="Login va parol (`.env` dagi API_USERNAME / API_PASSWORD)")

_UNAUTHORIZED = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Login yoki parol noto'g'ri",
    headers={"WWW-Authenticate": "Basic"},
)


def require_api_credentials(
    request: Request,
    credentials: HTTPBasicCredentials = Depends(_basic),
) -> str:
    """Login/parolni tekshiradi; mos kelmasa 401.

    Sozlama bo'sh bo'lsa ilova OCHIQ QOLMAYDI — barcha so'rov rad etiladi.
    Aks holda `.env` da parol unutilsa, himoya jimgina o'chib qolardi.
    """
    s: Settings = getattr(request.app.state, "settings", None) or get_settings()
    accounts = dict(s.api_accounts)
    if s.api_username and s.api_password:
        accounts[s.api_username] = s.api_password
    if not accounts:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="API_USERNAME/API_PASSWORD .env da sozlanmagan",
        )

    # compare_digest — javob vaqti orqali parolni topishdan (timing attack) himoya.
    # Ikkalasi ham tekshiriladi: noto'g'ri login va noto'g'ri parol bir xil vaqt olsin.
    selected = accounts.get(credentials.username)
    user_ok = bool(selected)
    password_ok = secrets.compare_digest(credentials.password.encode("utf-8"), (selected if user_ok else "invalid-account").encode("utf-8"))
    if not (user_ok and password_ok):
        logger.warning("Noto'g'ri login urinishi: %r (%s)", credentials.username[:40],
                       request.client.host if request.client else "?")
        raise _UNAUTHORIZED
    request.state.principal = credentials.username
    return credentials.username
