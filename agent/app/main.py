"""HTTP front door for the workshop agent. This file does not change between steps."""

import json
import logging
import socket
import time
import uuid
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse, JSONResponse
from opentelemetry import trace
from pydantic import BaseModel, Field
from pydantic_ai.exceptions import ModelHTTPError
from pydantic_ai.messages import ModelRequest, ModelResponse, TextPart, ToolCallPart, UserPromptPart

from .assistant import agent, describe
from .history import build_history
from .settings import settings

logger = logging.getLogger("agent")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")

history = build_history(settings)
SERVED_BY = socket.gethostname()
STATIC = Path(__file__).parent / "static"

app = FastAPI(title="Stack It Yourself - workshop agent")


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    conversation_id: str | None = Field(default=None, max_length=64)


def _trace_id() -> str | None:
    ctx = trace.get_current_span().get_span_context()
    return format(ctx.trace_id, "032x") if ctx.is_valid else None


@app.get("/")
async def index() -> FileResponse:
    return FileResponse(STATIC / "index.html")


@app.get("/healthz")
async def healthz() -> dict:
    return {"status": "ok"}


@app.get("/info")
async def info() -> dict:
    return {
        **describe(),
        "history_backend": settings.history_backend,
        "telemetry": settings.telemetry_enabled,
        "served_by": SERVED_BY,
        "grafana_url": settings.grafana_url,
    }


@app.post("/chat")
async def chat(req: ChatRequest):
    conversation_id = req.conversation_id or uuid.uuid4().hex[:12]
    started = time.perf_counter()
    past = await history.load(conversation_id)
    try:
        # conversation_id becomes gen_ai.conversation.id on every span, so one trace search
        # finds every turn of a conversation - even across container restarts in Step 4.
        result = await agent.run(req.message, message_history=past, conversation_id=conversation_id)
    except ModelHTTPError as exc:
        # Surfaced on purpose: in Step 2 a backend that doesn't speak the Responses API
        # answers 400, and that failure is the lesson.
        detail = exc.body if isinstance(exc.body, str) else json.dumps(exc.body, default=str)
        logger.warning("model backend rejected request: status=%s body=%s", exc.status_code, detail)
        return JSONResponse(
            status_code=502,
            content={
                "error": f"The model backend returned HTTP {exc.status_code}",
                "status_code": exc.status_code,
                "detail": detail[:500],
                "model": settings.model,
                "trace_id": _trace_id(),
            },
        )
    except Exception as exc:  # noqa: BLE001 - e.g. the model server is down (the cold open)
        logger.exception("agent run failed")
        return JSONResponse(
            status_code=502,
            content={
                "error": "The agent could not get an answer from the model backend",
                "detail": f"{type(exc).__name__}: {exc}"[:500],
                "model": settings.model,
                "trace_id": _trace_id(),
            },
        )
    await history.append(conversation_id, result.new_messages())

    usage = result.usage
    tools_called = [
        p.tool_name for m in result.new_messages() if isinstance(m, ModelResponse) for p in m.parts if isinstance(p, ToolCallPart)
    ]
    logger.info(
        "turn complete conversation=%s history_messages=%d tools=%s input_tokens=%s output_tokens=%s",
        conversation_id, len(past), tools_called or "none", usage.input_tokens, usage.output_tokens,
    )
    return {
        "conversation_id": conversation_id,
        "reply": result.output,
        "tools_called": tools_called,
        "served_by": SERVED_BY,
        "model": settings.model,
        "api": describe()["api"],
        "history_backend": settings.history_backend,
        "trace_id": _trace_id(),
        "seconds": round(time.perf_counter() - started, 2),
        "usage": {"input_tokens": usage.input_tokens, "output_tokens": usage.output_tokens, "requests": usage.requests},
    }


@app.get("/conversations/{conversation_id}")
async def conversation(conversation_id: str) -> list[dict]:
    """A readable view of what the history store holds for one conversation."""
    turns: list[dict] = []
    for message in await history.load(conversation_id):
        for part in message.parts:
            if isinstance(message, ModelRequest) and isinstance(part, UserPromptPart) and isinstance(part.content, str):
                turns.append({"role": "user", "text": part.content})
            elif isinstance(message, ModelResponse) and isinstance(part, TextPart) and part.content.strip():
                turns.append({"role": "assistant", "text": part.content})
            elif isinstance(message, ModelResponse) and isinstance(part, ToolCallPart):
                turns.append({"role": "tool", "text": f"{part.tool_name}({part.args_as_json_str()})"})
    return turns
