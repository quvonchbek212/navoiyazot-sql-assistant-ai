"""LLM (chat) klienti — vLLM (`gemma4-31b`), OpenAI-mos API, async.

ngrok orqali ishlaydi — `ngrok-skip-browser-warning` sarlavhasi qo'shiladi.
"""
from __future__ import annotations

import logging
import asyncio
from collections.abc import AsyncIterator
from typing import Any

from openai import AsyncOpenAI

from .config import Settings

logger = logging.getLogger("llm")

_NGROK_HEADER = {"ngrok-skip-browser-warning": "true"}


class LlmClient:
    def __init__(self, settings: Settings):
        self._s = settings
        self._chat = AsyncOpenAI(
            base_url=settings.vllm_base_url,
            api_key=settings.vllm_api_key,
            timeout=settings.llm_timeout,
            max_retries=settings.llm_max_retries,
            default_headers=_NGROK_HEADER,
        )

    async def ping(self) -> bool:
        try:
            client = self._chat.with_options(timeout=self._s.llm_health_timeout, max_retries=0)
            async with asyncio.timeout(self._s.llm_health_timeout):
                response = await client.chat.completions.create(
                    model=self._s.vllm_model,
                    messages=[{"role": "user", "content": "Reply with OK."}],
                    max_tokens=8, temperature=0,
                )
            return bool(response.choices and response.choices[0].message.content)
        except Exception as exc:
            logger.warning("LLM readiness failed: %s", type(exc).__name__)
            return False

    async def close(self) -> None:
        await self._chat.close()

    async def chat(
        self,
        system: str,
        user: str,
        *,
        temperature: float | None = None,
        max_tokens: int | None = None,
    ) -> str:
        return await self.chat_messages(
            [{"role": "system", "content": system}, {"role": "user", "content": user}],
            temperature=temperature,
            max_tokens=max_tokens,
        )

    async def chat_messages(
        self,
        messages: list[dict[str, Any]],
        *,
        temperature: float | None = None,
        max_tokens: int | None = None,
    ) -> str:
        resp = await self._chat.chat.completions.create(
            model=self._s.vllm_model,
            temperature=self._s.llm_temperature if temperature is None else temperature,
            max_tokens=max_tokens or self._s.llm_max_tokens,
            messages=messages,
        )
        return (resp.choices[0].message.content or "").strip()

    async def chat_stream(
        self,
        system: str,
        user: str,
        *,
        temperature: float | None = None,
        max_tokens: int | None = None,
    ) -> AsyncIterator[str]:
        """Javob tokenlari (bo'laklari) kelishi bilan.

        `contextlib.aclosing` bilan ishlating: iteratsiya to'xtatilsa ulanish yopiladi
        va vLLM generatsiyani to'xtatadi (GPU bekor ishlamaydi).
        """
        stream = await self._chat.chat.completions.create(
            model=self._s.vllm_model,
            temperature=self._s.llm_temperature if temperature is None else temperature,
            max_tokens=max_tokens or self._s.llm_max_tokens,
            messages=[{"role": "system", "content": system}, {"role": "user", "content": user}],
            stream=True,
        )
        try:
            completed = False
            async for chunk in stream:
                if not chunk.choices:
                    continue
                choice = chunk.choices[0]
                if text := choice.delta.content:
                    yield text
                if choice.finish_reason is not None:
                    if choice.finish_reason != "stop":
                        raise RuntimeError("Model javobi to'liq tugamadi")
                    completed = True
            if not completed:
                raise RuntimeError("Model javob oqimi tugamasdan uzildi")
        finally:
            await stream.close()
