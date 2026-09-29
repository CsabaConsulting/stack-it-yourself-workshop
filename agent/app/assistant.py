"""The agent itself. Model, tools and behaviour all come from configuration."""

from pydantic_ai import Agent
from pydantic_ai.mcp import MCPToolset
from pydantic_ai.models import infer_model
from pydantic_ai.models.instrumented import InstrumentationSettings

from . import tools
from .settings import settings

# The one line of instrumentation. It has been here since Step 1: until Step 3 no
# OpenTelemetry SDK is configured, so it talks to a no-op tracer. In Step 3 we give it
# somewhere to send spans and metrics that follow the OpenTelemetry GenAI conventions.
# include_content puts prompts and completions in traces - useful in dev, a data-exposure
# risk in production (set CAPTURE_CONTENT=false).
Agent.instrument_all(InstrumentationSettings(include_content=settings.capture_content))

API_SURFACE = {
    "OllamaModel": "Chat Completions",
    "OpenAIChatModel": "Chat Completions",
    "OpenAIResponsesModel": "Responses",
}

BASE_INSTRUCTIONS = (  # the first sentence of each string is event-specific - change it for another event
    "You are the assistant for AGNTCon + MCPCon North America 2026 in San Jose. "
    "Answer in one to three sentences."
)
TOOL_INSTRUCTIONS = (
    "You are the assistant for AGNTCon + MCPCon North America 2026 in San Jose. "
    "You have tools for the workshop schedule and the current time. "
    "If a question is about workshops, sessions, rooms, days or the time, use a tool to get the facts first, "
    "then answer in one to three sentences using only what the tool returned. "
    "Never describe a tool call in your reply - just make it."
)
# Measured with qwen3:1.7b and thinking off: an earlier, vaguer wording ("call a tool
# instead of guessing") produced a real tool call on only 2 of 4 schedule questions - the model
# wrote "Call the search_workshops function..." as text instead. TOOL_INSTRUCTIONS scored 8 of 8.
# Without tools we must not mention them, or the model invents tool-call text like GET_WORKSHOPS_FRI.
INSTRUCTIONS = TOOL_INSTRUCTIONS if settings.tools else BASE_INSTRUCTIONS

model = infer_model(settings.model)


def _model_settings() -> dict:
    # Qwen3 "thinks" before answering by default, which roughly quadruples CPU latency.
    # This one key switches it off on both the Chat Completions and Responses surfaces.
    return {"openai_reasoning_effort": "none"} if settings.reasoning == "off" else {}


agent = Agent(
    model,
    name="conference-assistant",
    instructions=INSTRUCTIONS,
    tools=tools.LOCAL_TOOLS if "local" in settings.tools else [],
    toolsets=[MCPToolset(settings.mcp_server_url)] if "mcp" in settings.tools else [],
    model_settings=_model_settings(),
)


def describe() -> dict:
    name = type(model).__name__
    return {
        "model": settings.model,
        "model_class": name,
        "api": API_SURFACE.get(name, "unknown"),
        "base_url": str(getattr(model, "base_url", "")),
        "tools": sorted(settings.tools),
        "reasoning": settings.reasoning,
    }
