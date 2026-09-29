"""Conversation history, behind Pydantic AI's serialization boundary.

The agent never knows where its history lives. Swapping the store is configuration
(HISTORY_BACKEND=memory|redis), which is why the agent container can be disposable
and why it scales horizontally in Step 6.
"""

from typing import Protocol

from pydantic_ai.messages import ModelMessage, ModelMessagesTypeAdapter

from .settings import Settings


class History(Protocol):
    async def load(self, conversation_id: str) -> list[ModelMessage]: ...

    async def append(self, conversation_id: str, messages: list[ModelMessage]) -> None: ...


class InMemoryHistory:
    """Lives inside the agent process, so it dies with the container. That is the point."""

    def __init__(self) -> None:
        self._store: dict[str, list[ModelMessage]] = {}

    async def load(self, conversation_id: str) -> list[ModelMessage]:
        return list(self._store.get(conversation_id, []))

    async def append(self, conversation_id: str, messages: list[ModelMessage]) -> None:
        self._store.setdefault(conversation_id, []).extend(messages)


class RedisHistory:
    """History in Redis: one JSON document per turn, appended to a list per conversation."""

    def __init__(self, url: str, max_turns: int = 50, ttl_seconds: int = 7 * 24 * 3600) -> None:
        import redis.asyncio as redis

        self._redis = redis.from_url(url)
        self._max_turns = max_turns
        self._ttl = ttl_seconds

    @staticmethod
    def _key(conversation_id: str) -> str:
        return f"conversation:{conversation_id}"

    async def load(self, conversation_id: str) -> list[ModelMessage]:
        turns = await self._redis.lrange(self._key(conversation_id), 0, -1)
        return [message for turn in turns for message in ModelMessagesTypeAdapter.validate_json(turn)]

    async def append(self, conversation_id: str, messages: list[ModelMessage]) -> None:
        key = self._key(conversation_id)
        async with self._redis.pipeline(transaction=True) as pipe:
            pipe.rpush(key, ModelMessagesTypeAdapter.dump_json(messages))
            pipe.ltrim(key, -self._max_turns, -1)  # keep whole turns, so tool calls stay paired
            pipe.expire(key, self._ttl)
            await pipe.execute()


def build_history(settings: Settings) -> History:
    if settings.history_backend == "redis":
        return RedisHistory(settings.redis_url)
    return InMemoryHistory()
