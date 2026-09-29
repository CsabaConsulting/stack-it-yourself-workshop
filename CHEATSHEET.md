# Cheatsheet - Stack It Yourself

**Every step:** `cp env/stepN.env .env` then `docker compose up -d`
**Fallen behind?** Do exactly that for the step the room is on. You're caught up.
**What did a step change?** `git diff --no-index env/step2.env env/step3.env`

| Step | Command | Open | Look for |
|---|---|---|---|
| **1** Baseline | `cp env/step1.env .env` · `docker compose up -d` | http://localhost:8000 | `class OllamaModel` · `API Chat Completions`. The first reply takes 15–30 s while the model loads. |
| **2** Responses API | `cp env/step2.env .env` · `docker compose up -d` | http://localhost:8000 | `class OpenAIResponsesModel` · `API Responses`. Same server, one line changed. |
| **3** Observability | `cp env/step3.env .env` · `docker compose up -d` | http://localhost:3000 → Dashboards → *Stack It Yourself - Agent* | Click **trace ↗** under a reply: `POST /chat → invoke_agent → chat → POST` |
| **4** Redis history | `cp env/step4.env .env` · `docker compose up -d` | http://localhost:8000 | Chat, then `docker compose rm -sf agent` and `docker compose up -d`. Reload the page: the conversation is still there. |
| **5** Tools + MCP | `cp env/step5.env .env` · `docker compose up -d` | http://localhost:8000 · Grafana | Ask *"What workshops are on Friday?"*, then open its trace. It spans **agent** and **mcp-server**. |
| **6** Cluster *(about 5 min to set up)* | `./scripts/cluster-up.sh` | http://localhost:8081 · http://localhost:3001 | `kubectl -n stack-it-yourself scale deployment/agent --replicas=3` |

Windows: `cp` works in PowerShell. In cmd, use `copy`.

## Good questions to ask the agent

- What workshops are on Friday?
- Which workshop is about security?
- What time is it in San Jose right now?
- What's on in this room after this workshop?

## Rescue commands

| Problem | Fix |
|---|---|
| Something is odd | `docker compose ps` - everything should say *healthy* |
| See what the agent is doing | `docker compose logs -f agent` |
| Ports already in use | `docker compose down`, then find what else is on 8000, 3000 or 11434 |
| Start clean | `docker compose --profile observability --profile state --profile tools down` then redo the current step |
| Peek into Redis | `docker compose exec redis redis-cli KEYS 'conversation:*'` |
| Hit the model directly | `curl http://localhost:11434/v1/models` |
| Local model won't run | Use a hosted OpenAI-compatible endpoint: `cp env/hosted.env.example env/hosted.env` and fill it in |
