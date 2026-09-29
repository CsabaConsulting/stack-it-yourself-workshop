"""Configuration for the workshop agent.

Every difference between workshop steps is an environment variable (see ../env/stepN.env).
The code does not change between steps.
"""

import os
from dataclasses import dataclass


def _flag(name: str, default: str) -> bool:
    return os.getenv(name, default).strip().lower() in {"1", "true", "yes", "on"}


def _csv(name: str) -> frozenset[str]:
    return frozenset(p.strip().lower() for p in os.getenv(name, "").split(",") if p.strip())


@dataclass(frozen=True)
class Settings:
    model: str
    reasoning: str
    history_backend: str
    redis_url: str
    tools: frozenset[str]
    mcp_server_url: str
    capture_content: bool
    grafana_url: str
    telemetry_enabled: bool


def load() -> Settings:
    return Settings(
        # "<provider>:<model>". The provider prefix picks the API surface:
        #   ollama:            -> OllamaModel          -> Chat Completions
        #   openai-chat:       -> OpenAIChatModel      -> Chat Completions
        #   openai-responses:  -> OpenAIResponsesModel -> Responses
        model=os.getenv("MODEL", "ollama:qwen3:1.7b"),
        reasoning=os.getenv("REASONING", "off").strip().lower(),
        history_backend=os.getenv("HISTORY_BACKEND", "memory").strip().lower(),
        redis_url=os.getenv("REDIS_URL", "redis://redis:6379/0"),
        tools=_csv("TOOLS"),
        mcp_server_url=os.getenv("MCP_SERVER_URL", "http://mcp-server:8001/mcp"),
        capture_content=_flag("CAPTURE_CONTENT", "true"),
        grafana_url=os.getenv("GRAFANA_URL", "http://localhost:3000").rstrip("/"),
        telemetry_enabled=not _flag("OTEL_SDK_DISABLED", "false"),
    )


settings = load()
