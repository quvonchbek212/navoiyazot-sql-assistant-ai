"""OpenAI-compatible streaming must distinguish a complete answer from truncation."""
import asyncio
from types import SimpleNamespace

import pytest

from atil_chatbot.app.llm import LlmClient


class Stream:
    def __init__(self, finish):
        self.finish, self.closed = finish, False

    async def __aiter__(self):
        yield SimpleNamespace(choices=[SimpleNamespace(delta=SimpleNamespace(content="Javob"), finish_reason=None)])
        if self.finish:
            yield SimpleNamespace(choices=[SimpleNamespace(delta=SimpleNamespace(content=None), finish_reason=self.finish)])

    async def close(self):
        self.closed = True


def client(stream):
    llm = object.__new__(LlmClient)
    llm._s = SimpleNamespace(vllm_model="test", llm_temperature=0, llm_max_tokens=100)

    async def create(**kwargs):
        return stream

    llm._chat = SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=create)))
    return llm


def collect(llm):
    async def run():
        return [text async for text in llm.chat_stream("system", "user")]
    return asyncio.run(run())


def test_complete_stream_closes_connection():
    stream = Stream("stop")
    assert collect(client(stream)) == ["Javob"]
    assert stream.closed


@pytest.mark.parametrize("finish", [None, "length", "content_filter"])
def test_incomplete_stream_is_not_success(finish):
    stream = Stream(finish)
    with pytest.raises(RuntimeError):
        collect(client(stream))
    assert stream.closed
