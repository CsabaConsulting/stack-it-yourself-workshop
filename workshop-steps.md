# Workshop steps: Stack It Yourself

## Open Infrastructure for AI Agents, from Compose to Cluster

**AGNTCon + MCPCon North America 2026**  
**Planned session:** Friday, October 23, 2026, 10:25 AM-12:00 PM  
**Location:** San Jose McEnery Convention Center, LL21 DEF

This is a beginner-friendly walkthrough of the workshop in this repository. You will run an AI assistant, change the way it talks to a language model, see what happens inside a request, give it persistent conversation history, connect it to tools, and see the same application run on Kubernetes.

You do not need to know Python, Docker, Kubernetes, OpenTelemetry, or MCP beforehand. The application code is already written. The exercises let you examine and operate it rather than write an application from scratch.

**The main idea:** good boundaries let you change infrastructure without rewriting the agent. In Steps 1-5, you copy a prepared configuration file and let Docker Compose apply it. In Step 6, you deploy the existing container images to a different runtime.

> The normal laptop path needs no GPU, cloud account, or paid API key. A hosted model is an optional recovery path, not a prerequisite. This is a development workshop, not a production-ready deployment or a security-hardening exercise.

## Contents

- [How to use these instructions](#how-to-use-these-instructions)
- [The workshop at a glance](#the-workshop-at-a-glance)
- [The pieces you are about to run](#the-pieces-you-are-about-to-run)
- [Before the workshop: prepare your laptop](#before-the-workshop-prepare-your-laptop)
- [Step 0: understand the problem](#step-0-understand-the-problem)
- [Step 1: run an agent on local inference](#step-1-run-an-agent-on-local-inference)
- [Step 2: change the model API without changing the application](#step-2-change-the-model-api-without-changing-the-application)
- [Step 3: see inside the agent with OpenTelemetry and Grafana](#step-3-see-inside-the-agent-with-opentelemetry-and-grafana)
- [Step 4: keep a conversation when the agent container is destroyed](#step-4-keep-a-conversation-when-the-agent-container-is-destroyed)
- [Step 5: give the agent tools and follow a request across MCP](#step-5-give-the-agent-tools-and-follow-a-request-across-mcp)
- [Step 6: move the same application to Kubernetes](#step-6-move-the-same-application-to-kubernetes)
- [Step 7: review the lessons and clean up](#step-7-review-the-lessons-and-clean-up)
- [Recovery paths and troubleshooting](#recovery-paths-and-troubleshooting)
- [Optional instructor preparation](#optional-instructor-preparation)
- [Where to look next](#where-to-look-next)

## How to use these instructions

1. Complete the preparation section **before** arriving. Downloads are much easier on a reliable connection than on conference Wi-Fi.
2. Work through the numbered steps in order. Each step has a goal, commands, an explanation, and a checkpoint.
3. During the live workshop, follow the presenters' pace. Step 6 is planned as a presenter demonstration; you can do it yourself later.
4. If you fall behind, use the prepared configuration for the step the room is on. You do not need to reconstruct every earlier edit.

### Command conventions

- Run commands in a terminal opened at the repository root: the directory containing [compose.yaml](compose.yaml).
- Use **PowerShell** blocks on Windows. Use **Bash** blocks on macOS, Linux, WSL, or Git Bash. Where two alternatives are shown, run only the one for your shell.
- Docker commands without operating-system-specific paths work in either shell.
- Bash scripts are invoked with `bash` so that a missing executable permission does not prevent a ZIP-download user from running them.
- Copy the commands, not example output. If a command reports an error, fix that before continuing.
- `Ctrl+C` stops a command such as a live log viewer. It does not stop containers that you started with `docker compose up -d`.

### What you should and should not edit

The step files in [env](env) are prepared examples. **Do not edit the tracked examples or application code for the main exercises.** Copy the appropriate example to the untracked `.env` file instead.

Copying a step file replaces your current `.env` settings. Save any personal configuration first if you are reusing an existing checkout.

The optional hosted-model path uses a second untracked file, `env/hosted.env`. Its model settings override those in `.env`. This matters especially in Step 2.

> Use made-up names and non-sensitive questions. The lab captures conversation content in telemetry by default and has no application login. Do not put credentials, personal information, or confidential work into it, and do not expose its ports to the public internet.

## The workshop at a glance

The live plan is 95 minutes. Preparation and optional experiments are outside that time.

| Planned time | Step | Duration | What you accomplish |
|---|---|---|---|
| 10:25 | 0. Understand the problem | 8 minutes | See why an answering model is not the same as a complete agent system |
| 10:33 | 1. Local baseline | 12 minutes | Run the assistant with a local model, memory-only history, and no tools |
| 10:45 | 2. Model API | 12 minutes | Change from Chat Completions to the Responses API through configuration |
| 10:57 | 3. Observability | 18 minutes | Read a trace, token metrics, and correlated logs |
| 11:15 | 4. Durable history | 10 minutes | Preserve a conversation outside a destroyed agent container |
| 11:25 | 5. Tools and MCP | 12 minutes | Retrieve schedule facts and follow a trace into another process |
| 11:37 | 6. Compose to cluster | 14 minutes | Watch the existing images run on Kubernetes and scale the agent |
| 11:51 | 7. Review and cleanup | 9 minutes | Understand the limitations, stop the lab, and identify next steps |

Here is the configuration journey:

| Step | Model API, local path | History | Tools | Telemetry | Compose profiles |
|---|---|---|---|---|---|
| 1 | Chat Completions | Agent process memory | None | Off | None |
| 2 | Responses | Agent process memory | None | Off | None |
| 3 | Responses | Agent process memory | None | On | `observability` |
| 4 | Responses | Redis | None | On | `observability,state` |
| 5 | Responses | Redis | Local functions and MCP | On | `observability,state,tools` |
| 6 | Responses | A separate Redis in Kubernetes | Local functions and MCP | On | Kubernetes manifests, not Compose profiles |

There is no sixth step environment file. Step 6 uses the manifests in [k8s](k8s).

## The pieces you are about to run

### A few terms in plain language

| Term | Meaning in this workshop |
|---|---|
| **Language model / LLM** | Software that generates text from input. It does not automatically have current facts, a clock, or access to your systems. |
| **Inference** | Running the model to produce an answer. |
| **Agent** | The application around the model: instructions, conversation history, optional tools, and the loop that can call a tool and ask the model again. |
| **API** | A defined way for programs to communicate. Chat Completions and Responses are two model API surfaces. |
| **OpenAI-compatible** | An endpoint implements some of the same request and response conventions as OpenAI's APIs. It need not be operated by OpenAI, and compatibility is not necessarily complete. |
| **Container image** | A packaged application and its dependencies. Think of it as the template for a running application. |
| **Container** | A running instance of an image. Removing a container removes its private writable filesystem and process memory, not its image. |
| **Docker Compose** | A tool that starts a group of related containers from a configuration file. |
| **Environment variable** | A named setting passed to a program, such as `HISTORY_BACKEND=redis`. |
| **Compose profile** | A named switch that includes optional services. Starting a Redis container and telling the agent to use Redis are separate decisions. |
| **Volume / bind mount** | Storage outside a container's disposable filesystem. A named volume is managed by Docker; a bind mount points at a normal host directory. |
| **Telemetry** | Data describing what software did: traces, metrics, and logs. |
| **Trace / span** | A trace follows one operation end to end. A span describes one operation within that trace, with a start, duration, and attributes. |
| **MCP** | Model Context Protocol: a standard way for an application to discover and call tools provided by another program. |
| **Kubernetes** | A system that schedules and manages containers. A **pod** is its basic running unit; a **Deployment** manages replicas; a **Service** provides a stable network address for them. |

### The request path

The browser is not running the model. It sends your message to the agent, which calls other services as needed.

```text
Your browser
    |
    | HTTP: a chat message
    v
agent: FastAPI + Pydantic AI
    |-- model request ----------> ollama: local Qwen3 model
    |-- load/save conversation -> redis                 [Step 4 onward]
    |-- MCP tool request -------> mcp-server             [Step 5 onward]
    |-- local tool call --------> current_time function  [Step 5 onward]
    |
    `-- OpenTelemetry ----------> lgtm                   [Step 3 onward]
                                  |-- Tempo: traces
                                  |-- Prometheus: metrics
                                  |-- Loki: logs
                                  `-- Grafana: the interface
```

- **FastAPI** exposes the web page and HTTP endpoints.
- **Pydantic AI** coordinates the model, messages, and tool calls.
- **Ollama** serves the local model through an HTTP API.
- **Qwen3** is the model; it is not the agent framework or the model server.
- **FastMCP** implements the separate schedule tool server.
- **OpenTelemetry**, often shortened to OTel, provides standard instrumentation and export.
- **OTLP** is the protocol used to send that telemetry to the collector inside the LGTM container.

### Which addresses belong in a browser?

| Component | Docker Compose | Local Kubernetes demo |
|---|---|---|
| Agent UI | http://localhost:8000 | http://localhost:8081 |
| Grafana | http://localhost:3000 | http://localhost:3001 |
| Ollama API | http://localhost:11434/v1 | Internal cluster service; no browser port is published by these manifests |
| Redis | Internal service, port 6379 | Internal service, port 6379 |
| MCP server | Internal service, port 8001, path `/mcp` | Internal service, port 8001, path `/mcp` |
| OTLP HTTP receiver | Internal `lgtm` service, port 4318 | Internal `lgtm` service, port 4318 |

**Why two kinds of address?** `localhost` means "this machine" from the caller's point of view. Inside the agent container, `localhost` would refer to that container, not the Ollama container. Compose provides service names such as `ollama` and `redis`; Kubernetes provides similar service DNS names. Keep the supplied internal URLs as they are.

## Before the workshop: prepare your laptop

**Goal:** finish the downloads and prove that one real model request works before the live session.

Read [prerequisites.md](prerequisites.md) for installation links and the full hardware guidance.

### 1. Check the machine and software

You need:

- A container runtime exposing the Docker CLI and Docker Compose **2.24 or newer**.
- Git and a browser.
- An 8 GB RAM machine at minimum; 16 GB or more is recommended.
- At least 10 GB free disk, with more headroom strongly recommended for source builds and the cluster extension.
- Sufficient memory assigned to Docker. The prerequisites list 5 GB as a minimum; preflight warns below 6 GB. Aim for 8 GB if your machine allows it.
- On Windows with Docker Desktop, a working WSL 2 setup and Linux containers.

You do **not** need a native Python environment, a native Ollama installation, a GPU, or Kubernetes for Steps 1-5.

Start your container runtime and wait until it reports that it is ready:

```bash
docker info
docker compose version
git --version
```

**Why this is needed:** an installed Docker CLI is only a client. The background engine must also be running for it to create containers. Compose also needs features used by this repository's configuration.

### 2. Get the repository

Skip cloning if you already have this repository. Open a terminal at its root instead.

**PowerShell:**

```powershell
git clone https://github.com/bbenz/stack-it-yourself-workshop.git
Set-Location .\stack-it-yourself-workshop
```

**Bash:**

```bash
git clone https://github.com/bbenz/stack-it-yourself-workshop.git
cd stack-it-yourself-workshop
```

**Why this is needed:** the repository supplies the application, service definitions, prepared settings, dashboards, and helper scripts. All subsequent relative paths assume this working directory.

### 3. Run preflight on a reliable connection

**PowerShell:**

```powershell
.\scripts\preflight.ps1
```

**Bash:**

```bash
bash ./scripts/preflight.sh
```

Preflight:

1. Checks that Docker is running and Compose is new enough.
2. Checks available memory and disk space.
3. Creates `.env` from the Step 1 example if `.env` does not already exist.
4. Downloads supporting images and pulls or builds the workshop images.
5. Downloads the baseline `qwen3:1.7b` model.
6. Starts the agent, sends a real chat request, and then shuts down the Compose stack.

It leaves an existing `.env` untouched. An existing hosted override also affects the smoke test, so do not interpret a hosted-model success as proof that local inference works.

Look for:

```text
[6/6] Smoke test: one real chat turn through the agent
  OK   The agent answered - your laptop can run the workshop

All set - see you at the workshop!
```

**Why a real chat request matters:** a healthy HTTP endpoint or a running Ollama process does not prove that the requested model weights are available or that a model call will succeed.

If preflight reports `FAIL`, address the reported problem and rerun it. Completed model downloads are reused. Do not rerun it casually in the middle of a conversation: its final cleanup stops the Compose services and discards memory-only history.

> **Download-size caveat:** the plan's approximately 2.6 GB total assumes prepared workshop images plus the baseline model. This checkout defaults to the deliberately local-only `sit.local` image prefix. Without organizer-provided images, preflight builds locally, including downloading the much larger upstream Ollama build image. Allow extra bandwidth, disk space, and time. Do not try to log in to or pull from `sit.local` as though it were a public registry.

### 4. Choose a model tier, if necessary

Use the baseline unless you have a reason to change it:

| Model | Role | Important detail |
|---|---|---|
| `qwen3:1.7b` | Everyone's baseline | About 1.4 GB of model downloads; the prepared steps use this |
| `qwen3:4b-instruct` | Optional, steadier tool use on a 16 GB-or-larger machine | About 2.5 GB; download it before the session |
| `qwen3:0.6b` | Lightweight recovery option | Faster on constrained machines, but less dependable for Step 5 tool calls |

To download the optional 4B instruct model as well as the baseline:

**PowerShell:**

```powershell
.\scripts\preflight.ps1 -With4b
```

**Bash:**

```bash
bash ./scripts/preflight.sh --with-4b
```

This **downloads** another model; it does not change the prepared steps to use it.

**Do not substitute plain `qwen3:4b`.** The workshop planning tests identified that tag as a thinking variant with very long CPU response times. Use the explicitly named `qwen3:4b-instruct` tier.

### Preparation checkpoint

- [ ] Docker is running, and Compose reports version 2.24 or newer.
- [ ] Preflight completes with a successful real chat turn and no `FAIL` lines.
- [ ] You know where the repository is and can open a terminal there.
- [ ] You have a charger and enough memory and disk headroom.
- [ ] You understand that preflight shuts the stack down; you will start it again in Step 1.

If downloads are impossible, use the [offline recovery path](#a-import-an-offline-bundle). If your laptop cannot run the model, use the [hosted recovery path](#b-use-an-instructor-provided-hosted-model).

## Step 0: understand the problem

**Live plan:** 10:25, 8 minutes. Primarily watch the presenters.

**Goal:** understand why "the model answered" is only the beginning of an agent system.

### Observe an assistant without tools

The presenter starts the Step 1 stack and asks:

> What workshops are on Friday?

At this point the application has no schedule tool. The model might invent a plausible schedule, answer vaguely, or say it does not know. It might give a different answer in a new conversation.

**The lesson is not that a particular wrong answer is guaranteed.** The lesson is that fluent text is not evidence that the model retrieved current event data. In Step 5, you will repeat the question and inspect an actual tool call.

### Observe three infrastructure problems

| Demonstration | What it illustrates |
|---|---|
| Stop the local model server and ask again | The agent depends on a reachable inference backend |
| Ask why a response was slow while telemetry is off | Without instrumentation, there is little evidence to inspect |
| Restart the memory-only agent and reload the page | A conversation stored in process memory disappears with that process |

For a presenter or a self-paced experiment, **only when using local inference at Step 1**, the failure-and-recovery commands are:

```bash
docker compose stop ollama
```

Send a question in the browser. Expect a model connection error, not an answer. Then restore the model server:

```bash
docker compose start ollama
docker compose ps ollama
```

Wait for it to be healthy. Restart the memory-only agent and reload the browser:

```bash
docker compose restart agent
```

If you use the hosted fallback, stopping Ollama does not take away your actual model backend, so skip this experiment.

**Why this step is needed:** it gives the remaining steps a purpose. You will establish an inference boundary, add evidence about execution, move state out of disposable compute, and finally reuse the resulting application in a cluster.

**Checkpoint:** you can name the four questions the workshop answers:

1. Where does inference come from?
2. How can I see what the agent did?
3. Where does conversation history live?
4. How can the same application run somewhere else?

## Step 1: run an agent on local inference

**Live plan:** 10:33, 12 minutes.

**Goal:** get one complete browser-to-agent-to-local-model round trip working.

### 1. Apply the baseline configuration

**PowerShell:**

```powershell
Copy-Item .\env\step1.env .env
docker compose up -d
```

**Bash:**

```bash
cp env/step1.env .env
docker compose up -d
```

What those commands do:

- The copy makes [env/step1.env](env/step1.env) your active runtime configuration.
- Compose reads [compose.yaml](compose.yaml), starts Ollama, and starts the agent after Ollama is healthy.
- `-d` means "detached": leave the services running and return control to your terminal.
- No optional profile is active yet, so Redis, LGTM, and the MCP server are not required for this baseline.

The important settings are:

```dotenv
MODEL=ollama:qwen3:1.7b
OPENAI_BASE_URL=http://ollama:11434/v1
OPENAI_API_KEY=ollama
REASONING=off
OTEL_SDK_DISABLED=true
HISTORY_BACKEND=memory
TOOLS=
```

The value `ollama` in `OPENAI_API_KEY` is a local placeholder for client compatibility, **not a purchased key or a security mechanism**. The supplied Compose settings also provide the Ollama-specific base URL used by `OllamaModel`.

### 2. Check the services and open the UI

```bash
docker compose ps
```

Wait for `ollama` and `agent` to be healthy, then open **http://localhost:8000**.

The status chips should show:

| Chip | Expected value on the local path |
|---|---|
| model | `ollama:qwen3:1.7b` |
| class | `OllamaModel` |
| API | `Chat Completions` |
| history | `memory` |
| tools | `none` |
| telemetry | `off` |
| served by | A container hostname; your value will differ from anyone else's |

If you deliberately use the hosted fallback, the model and class chips will show its settings instead.

### 3. Send a simple message

Try:

> In one sentence, explain what a container is.

The first answer may take 15-30 seconds while model weights load into memory; slower machines can take longer. Avoid repeatedly pressing Send.

Send a follow-up:

> Make that explanation even simpler.

The application loads the earlier messages and includes them in the next model request. That is how the model can interpret "that explanation"; the running model is not independently maintaining your browser conversation.

### 4. Identify the configuration boundary

Open [agent/app/assistant.py](agent/app/assistant.py) for reading. The application resolves the `MODEL` string and constructs a Pydantic AI agent.

For this configuration:

- `ollama:` selects `OllamaModel`.
- `qwen3:1.7b` identifies the model served by Ollama.
- The local model is reached over the Chat Completions API.
- Tools are disabled.
- Conversation history is in the agent's process memory.

`REASONING=off` makes this application send `openai_reasoning_effort=none`. In the workshop's tests, this reduced Qwen3 CPU latency substantially. It does not mean the application has removed its instructions or stopped using context.

To look for the actual HTTP route in the logs:

**PowerShell:**

```powershell
docker compose logs --tail 100 agent | Select-String "HTTP Request"
```

**Bash:**

```bash
docker compose logs --tail 100 agent | grep "HTTP Request"
```

Look for a request to `/v1/chat/completions`.

### Why this step is needed

This is the smallest working system you will build on. If it cannot answer a real message, adding dashboards or Kubernetes will not solve the underlying model connection problem.

**Checkpoint:**

- [ ] The browser receives an answer.
- [ ] The local-path UI identifies `OllamaModel` and Chat Completions.
- [ ] You can explain the difference between the agent application, Ollama, and Qwen3.

> Until Step 4, the conversation is disposable. Changing configuration often recreates the agent container, so losing a memory-only conversation during Steps 2-3 is expected.

## Step 2: change the model API without changing the application

**Live plan:** 10:45, 12 minutes.

**Goal:** understand the difference between a model server and the API used to call it, and see a configuration-only change in action.

### 1. Compare the two configurations

**PowerShell:**

```powershell
git --no-pager diff --no-index -- .\env\step1.env .\env\step2.env
```

**Bash:**

```bash
git --no-pager diff --no-index -- env/step1.env env/step2.env
```

Comments differ too, but the only changed setting is:

```diff
-MODEL=ollama:qwen3:1.7b
+MODEL=openai-responses:qwen3:1.7b
```

`git diff --no-index` compares two files even though neither is a pending Git change. Exit code 1 means the files differ; that is expected here.

### 2. Apply Step 2

**PowerShell:**

```powershell
Copy-Item .\env\step2.env .env
docker compose up -d
```

**Bash:**

```bash
cp env/step2.env .env
docker compose up -d
```

Refresh **http://localhost:8000**. The UI loads its configuration chips when the page loads, so a refresh is important after every step.

Expect:

```text
class: OpenAIResponsesModel
API: Responses
history: memory
tools: none
telemetry: off
```

Ask another simple question. Use the log command from Step 1 and look for `/v1/responses` instead of `/v1/chat/completions`.

### 3. Explain what changed, and what did not

**Changed:** the client class and the API request format.

**Unchanged:** the model weights, local Ollama service, agent source code, browser UI, and overall purpose of the request.

Chat Completions and Responses are not different language models. They are different API surfaces. Pydantic AI selects a client implementation from the provider prefix in `MODEL`.

| Model string prefix | Client class | API surface |
|---|---|---|
| `ollama:` | `OllamaModel` | Chat Completions |
| `openai-chat:` | `OpenAIChatModel` | Chat Completions |
| `openai-responses:` | `OpenAIResponsesModel` | Responses |

### 4. Optional presenter demonstration: a hosted backend

The presenter may apply an instructor-prepared hosted override and make the same application call a model outside the laptop. See the [hosted recovery instructions](#b-use-an-instructor-provided-hosted-model).

With the repository's hosted example, the model becomes `openai-chat:qwen3-4b-instruct`. This changes both the backend and model size, so it is a portability demonstration, not a controlled speed comparison with the local 1.7B model.

The planned Foundry deployment supports **both** Chat Completions and Responses. There is no intentional Responses failure in this exercise. Other endpoints can differ in API coverage, authentication, tool support, reasoning options, and performance.

**Hosted attendees:** copying Step 2 does not override the `MODEL` in `env/hosted.env`. Staying on Chat Completions is expected. If the instructor asks you to test hosted Responses, change the `MODEL` line in that untracked hosted file to `openai-responses:qwen3-4b-instruct`, then rerun Compose.

### Why this step is needed

It demonstrates a portability boundary rather than a promise of universal compatibility. A configurable model name and base URL avoid hard-wiring a particular service into the application, but each backend still needs a real compatibility test.

**Checkpoint:**

- [ ] The local-path chips say `OpenAIResponsesModel` and Responses.
- [ ] A new question receives an answer.
- [ ] You understand that "OpenAI-compatible" describes an interface, not where the request is necessarily sent.

## Step 3: see inside the agent with OpenTelemetry and Grafana

**Live plan:** 10:57, 18 minutes. This is the main guided exploration.

**Goal:** replace guesswork about the agent's behavior with traces, metrics, and logs.

### 1. Enable both telemetry collection and telemetry export

The meaningful changes from Step 2 are:

```diff
-COMPOSE_PROFILES=
+COMPOSE_PROFILES=observability
-OTEL_SDK_DISABLED=true
+OTEL_SDK_DISABLED=false
```

**PowerShell:**

```powershell
Copy-Item .\env\step3.env .env
docker compose up -d
```

**Bash:**

```bash
cp env/step3.env .env
docker compose up -d
```

Two switches are necessary:

- The `observability` profile starts the `lgtm` backend.
- `OTEL_SDK_DISABLED=false` lets the instrumented application export telemetry.

Starting only a dashboard would not create application telemetry. Enabling export without a reachable receiver would leave it nowhere useful to go.

Wait for Grafana to start at **http://localhost:3000**. It can take tens of seconds. The supplied development image normally opens without a login.

`docker compose ps` shows `lgtm` as running; this service has no Compose healthcheck, so a missing `healthy` label for it is not by itself a failure.

### 2. Generate a new trace

1. Refresh **http://localhost:8000**.
2. Confirm the telemetry chip says `on`.
3. Send a new question and wait for its answer.
4. Click **trace** under that new answer.

The link opens Grafana Explore for that exact trace ID. It is the easiest starting point; you do not need to learn Grafana's menus first.

Only requests made after telemetry was enabled are recorded. Reloaded historical messages do not regain their original reply metadata or trace links, so send a fresh message if you cannot see a link.

### 3. Read the trace from outside to inside

A simple request has a shape like this. Names can include the model name or additional attributes:

```text
POST /chat                       agent receives the browser request
`-- invoke_agent                 Pydantic AI runs the agent
    `-- chat                     the model operation
        `-- POST                 the HTTP request to the model server
```

Click the spans and answer:

1. **Which service performed this operation?** Look for the service name.
2. **Which span took the most time?** Compare the horizontal bars and durations.
3. **Which model was requested?** Look at the `gen_ai.*` attributes.
4. **How many tokens were used?** Find input and output token usage.
5. **Did the model call succeed?** Look for status or error information.

Important details:

- A parent span includes time spent in its children. Do not add every nested duration together as though they were independent.
- A **token** is a small unit of model input or output, not necessarily a word.
- The GenAI attributes follow OpenTelemetry conventions, which make telemetry easier to compare across implementations.
- You may see `gen_ai.provider.name=openai` while using Ollama. Here the client instrumentation identifies the OpenAI-style API; it is not proof that the request went to OpenAI's cloud. Check the HTTP destination.
- One user turn has one trace containing multiple spans. A conversation has many turns and therefore usually many trace IDs.

On the planning test machine, inference dominated simple-request latency. Treat that as a hypothesis to inspect on your own machine, not a fixed percentage or performance guarantee.

### 4. Understand where the telemetry came from

Read, without editing:

- [agent/app/assistant.py](agent/app/assistant.py): `Agent.instrument_all(...)` adds the agent and model spans.
- [agent/Dockerfile](agent/Dockerfile): `opentelemetry-instrument` starts the application with standard instrumentation.
- [compose.yaml](compose.yaml): the shared `OTEL_*` settings select exporters and the collector address.

The instrumentation was already present in Step 1. Configuration turned it from a no-op into an exporting SDK. No observability vendor account is needed for this path.

### 5. Explore the supplied dashboard

In Grafana, open **Dashboards**, then **Stack It Yourself - Agent**.

The dashboard is provisioned from [grafana/dashboards/agent.json](grafana/dashboards/agent.json). You do not need to build it manually.

| Panel | What it tells you |
|---|---|
| Agent turns (range) | How many chat requests were observed in the selected period |
| Tokens used (range) | Input and output tokens consumed |
| Avg input tokens per model call | How much context an average model call receives |
| p95 /chat latency (range) | A latency estimate at the 95th percentile, not the average |
| Tokens per minute, by type | How token use changes over time |
| /chat latency p50 / p95 | Typical and slower-end latency over time |
| Recent agent runs (click a Trace ID) | Entry points into individual traces |
| Logs - agent and MCP server (each line links to its trace) | Application events with trace correlation |

Send two or three follow-up messages in the **same** conversation. Input tokens often grow because the retained conversation is sent back to the model on subsequent requests.

That growth is useful evidence: longer context can mean more work, greater latency, and higher cost on a metered backend. This application does not automatically summarize an ever-growing conversation.

**If panels initially say "No data":** metric export is configured every 5 seconds, the dashboard refreshes every 10 seconds, and rate calculations need multiple samples. Send a few messages, wait, and check the selected time range.

### 6. Connect a log to a trace

Expand an agent log line in the logs panel. A completed turn logs its conversation ID, tool names, and token usage. Trace-correlated lines also carry a trace ID.

Follow the trace link to relate a textual event to its execution timeline.

You can also use these Explore queries:

**Tempo / TraceQL, agent runs:**

```traceql
{ resource.service.name = "agent" && span.gen_ai.operation.name = "invoke_agent" }
```

**Loki / LogQL, both application services:**

```logql
{service_name=~"agent|mcp-server"}
```

Tempo search indexing can lag new requests. If a search is empty, use the direct trace link, allow a few seconds for export, and retry. Search and direct lookup are different paths.

### Content-capture warning

The examples use `CAPTURE_CONTENT=true` to make model inputs and outputs inspectable. Treat tool arguments and results as potentially captured too.

For a privacy-focused extension, change that setting to `false` in your untracked `.env`, rerun Compose, and compare **new** spans. Restore the current step file afterward if you want to return to the baseline.

This setting reduces GenAI content capture. It does not erase telemetry already stored, remove Redis history, or act as a universal redactor for every log and attribute.

### Why this step is needed

An agent can make several model and tool calls for one visible answer. An end-to-end trace shows where time went and what actually happened; metrics show trends; logs explain individual events.

**Checkpoint:**

- [ ] You have opened a trace from your own new answer.
- [ ] You can identify the browser request, agent operation, and model request.
- [ ] You can distinguish a trace, a metric, and a log.
- [ ] You understand why sending conversation content to telemetry is a data-handling decision.

## Step 4: keep a conversation when the agent container is destroyed

**Live plan:** 11:15, 10 minutes.

**Goal:** separate disposable application compute from conversation state.

### 1. Start Redis and select it as the history backend

The meaningful changes are:

```diff
-COMPOSE_PROFILES=observability
+COMPOSE_PROFILES=observability,state
-HISTORY_BACKEND=memory
+HISTORY_BACKEND=redis
```

**PowerShell:**

```powershell
Copy-Item .\env\step4.env .env
docker compose up -d
```

**Bash:**

```bash
cp env/step4.env .env
docker compose up -d
```

The profile starts Redis. The history setting makes the agent use it. Neither setting alone accomplishes the whole change.

Refresh the browser and confirm the history chip says `redis`.

**Existing memory-only messages are not migrated.** Start the demonstration with a new conversation after Redis is selected.

### 2. Create a recognizable conversation

1. Click **New**.
2. Note the conversation ID in the footer.
3. Send:

   > My name is Pat, and my favorite fruit is mango. Please remember that.

4. Wait for the answer to finish before continuing.

Use this made-up detail rather than private information. The application saves a completed turn after the agent finishes.

The browser stores the **conversation ID** in local storage, not the canonical conversation transcript. That ID is the lookup key the server uses.

### 3. Destroy only the agent container

```bash
docker compose rm -sf agent
docker compose up -d
```

What happens:

- `rm -sf agent` stops and removes the agent container. Its process memory is gone.
- Redis is not removed and continues to hold the conversation.
- `up -d` creates a new agent container from the existing image.

This is a stronger test than merely leaving the page open. You are replacing the process that originally handled the conversation.

### 4. Retrieve the same conversation

1. Wait for the new agent container to be healthy.
2. Reload the **same browser tab at the same address**.
3. Do **not** click New.
4. Confirm that the footer has the same conversation ID.
5. Confirm that the earlier messages redraw.
6. Note the new `served by` hostname.
7. Ask:

   > What is my name, and which fruit did I mention?

The earlier messages should come back from Redis, and the model should have those details in its context.

**The storage proof is the reloaded transcript under the same ID.** The model's wording is an additional demonstration, not the only evidence of persistence.

Do not switch browser profiles, clear browser storage, or change between `localhost` and another hostname during this test. Those changes can select a different browser-side ID.

### 5. Inspect the storage boundary

Read [agent/app/history.py](agent/app/history.py):

- Both history backends expose `load` and `append`.
- The memory backend keeps Python objects in the agent process.
- The Redis backend serializes Pydantic AI messages with `ModelMessagesTypeAdapter`.
- Each Redis list item contains one completed turn, including its related tool messages.
- The Redis store retains the most recent **50 turns**, with a **7-day expiry refreshed on append**.

The model does not need to know which store implements this interface.

To list conversation keys in this small lab:

```bash
docker compose exec redis redis-cli --scan --pattern 'conversation:*'
```

Keys look like `conversation:` followed by an ID from the UI.

In a new trace, look for a Redis history load before the agent run and a save after it. They can appear as `LRANGE` and a pipeline involving `RPUSH`, `LTRIM`, and `EXPIRE`.

To find turns of one conversation in Tempo, replace `PASTE_CONVERSATION_ID` with the footer value:

```traceql
{ span.gen_ai.conversation.id = "PASTE_CONVERSATION_ID" }
```

### What "durable" means here

In **Compose**, Redis uses append-only persistence and a named `redis-data` volume. That separates history from the agent container and also from Redis's disposable container filesystem.

It does not replace backups, high availability, or a migration strategy. Deleting the Redis volume deletes the history. The Kubernetes Redis example has a different limitation, explained in Step 6.

The UI's **New** button selects a new conversation ID. It does not erase old Redis conversations.

### Why this step is needed

If conversation state lives only inside one agent process, replacing or scaling that process changes what the user experiences. External history lets a replacement process load the same context.

**Checkpoint:**

- [ ] The history chip says `redis`.
- [ ] You removed and recreated the agent container.
- [ ] The same conversation ID still loads its earlier messages.
- [ ] You can explain the difference between the browser's ID, agent process memory, and Redis storage.

## Step 5: give the agent tools and follow a request across MCP

**Live plan:** 11:25, 12 minutes.

**Goal:** connect answers to actual data and see a single trace cross an application boundary.

### 1. Enable the two kinds of tool

The meaningful changes are:

```diff
-COMPOSE_PROFILES=observability,state
+COMPOSE_PROFILES=observability,state,tools
-TOOLS=
+TOOLS=local,mcp
```

**PowerShell:**

```powershell
Copy-Item .\env\step5.env .env
docker compose up -d
```

**Bash:**

```bash
cp env/step5.env .env
docker compose up -d
```

Refresh the browser. The chips should show `tools local, mcp`, history `redis`, and telemetry `on`.

The new service, `mcp-server`, runs separately from the agent. The existing agent can now discover and call its tools through MCP over Streamable HTTP.

### 2. Understand the available tools

| Tool | Where it runs | What it does |
|---|---|---|
| `current_time(city)` | In the agent process | Reads the current clock and formats it for a supported city's time zone |
| `list_workshops(day)` | In the MCP server | Returns the stored workshops for a conference day |
| `search_workshops(keyword)` | In the MCP server | Searches stored titles and summaries for a word or phrase |

Read the implementations in [agent/app/tools.py](agent/app/tools.py) and [mcp-server/server.py](mcp-server/server.py).

**The schedule is bundled demo data**, copied and paraphrased from the event listing in September 2026. It is not scraped live, and it is not a general calendar service. On another date, "Friday" still refers to the conference data; the current-time tool, by contrast, uses the actual current clock.

### 3. Repeat the opening question

Click **New** if you want to avoid carrying an earlier invented schedule into this demonstration. Then ask:

> What workshops are on Friday, October 23, 2026?

Look for a `list_workshops` tool indication as well as the answer.

The stored Friday data is:

| Time | Workshop | Room |
|---|---|---|
| 10:25-12:00 | Stack It Yourself: Open Infrastructure for AI Agents, from Compose to Cluster | LL21 DEF |
| 12:10-13:45 | Governing AI Agent Actions: MCP and Beyond | LL21 DEF |
| 16:00-17:35 | Secure Agentic Framework (SAF) for Agentic AI | LL21 DEF |

The answer can paraphrase or format those records differently. Compare the facts, not exact prose.

**Important:** a convincing answer alone is not proof of a tool call. Look at the UI's tool indication, the trace, or the API response's `tools_called` array.

### 4. Open the cross-process trace

Click the new reply's trace link. A representative structure is:

```text
invoke_agent                                  agent
|-- tools/list                                MCP discovery, when needed
|   `-- tools/list                            mcp-server
|-- chat                                      model chooses a tool
|-- execute_tool list_workshops                agent
|   `-- tools/call list_workshops              MCP client
|       `-- tools/call list_workshops          mcp-server
`-- chat                                      model writes the answer
```

Exact nesting can vary. The important evidence is that **the same trace ID contains spans from both `agent` and `mcp-server`**.

What happened:

1. The application exposed tool descriptions to the model.
2. The model requested a tool call with arguments.
3. The framework sent the request to the MCP server.
4. The server executed a Python function over the bundled schedule.
5. The tool result returned to the agent.
6. The model used that result to write a response.

This is why a single user message can produce more than one model request.

The libraries propagate W3C trace context through MCP request metadata, following **SEP-414**. The context includes identifiers that let the server continue the existing trace. This repository does not add custom trace-propagation code for the call.

Compare time spent in the MCP call with time spent generating the answer. The workshop planning tests found the tool round trip much shorter than inference, but use your trace to establish the result on your machine.

### 5. Compare a local tool

Ask:

> What time is it in San Jose right now?

Find the `current_time` execution span.

That function runs **inside the agent process**. Its execution does not require a `tools/call` into the MCP server.

You may still see MCP discovery elsewhere in that trace because the MCP toolset remains enabled. Compare the actual tool-execution branch rather than assuming that the entire trace must contain no MCP activity.

Try another grounded question:

> Search the workshop schedule for security.

Look for `search_workshops` and compare the answer with the returned data.

### 6. Understand why instructions matter

The application automatically selects different instructions when tools are enabled. Read `TOOL_INSTRUCTIONS` in [agent/app/assistant.py](agent/app/assistant.py).

The instructions tell the model to retrieve facts first and actually call tools instead of merely describing a proposed call.

This helps but does not force every small-model decision to be correct. If the answer says "Call the list_workshops function" without a real tool indication, the model has generated text, not executed the tool.

Retry with an explicit request such as "Use the schedule tool to list Friday's workshops." If needed, use the pre-downloaded 4B instruct model or watch the presenter's trace. Do not treat a small planning-test success count as a universal reliability guarantee.

### Why this step is needed

Tools give the application a route to information and actions that are outside the model's generated text. MCP makes the remote-tool boundary interoperable; distributed tracing makes that boundary visible.

MCP does not make a data source automatically current, an action automatically authorized, or a model automatically trustworthy. Those remain application-design responsibilities.

**Checkpoint:**

- [ ] A schedule question produces a real tool call.
- [ ] Its trace contains both application service names.
- [ ] You can distinguish a local function from a remote MCP tool.
- [ ] You can explain why the schedule answer is grounded in a supplied data source, not in the model's memory.

## Step 6: move the same application to Kubernetes

**Live plan:** 11:37, 14 minutes. Presenter-led in the live workshop.

**Goal:** see which deployment concepts change when the existing application images move from Compose to a cluster.

### 1. Decide whether to watch or run it yourself

For the live session, watching is the normal attendee path. A presenter should have the cluster prepared in advance.

For a self-paced run, you additionally need:

- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/), which runs a local Kubernetes cluster using containers.
- [kubectl](https://kubernetes.io/docs/tasks/tools/), the Kubernetes command-line client.
- Enough memory for the cluster, particularly if Compose remains running. Planning tests used roughly 10 GB for both stacks together.
- A reliable connection for the kind node image on first creation and for the cluster's separate model download.

The offline Compose bundle does **not** include the kind node image or automatically populate the cluster's model volume. Allow several minutes or more on the first run.

Check the extra tools:

```bash
kind version
kubectl version --client
kind get clusters
```

**Context safety:** `kubectl` has a current context, which identifies its target cluster. If `stack-it-yourself` already exists, select its context **before** rerunning the setup script:

```bash
kubectl config use-context kind-stack-it-yourself
```

On a first run, the setup script creates the cluster and kind selects its context. On a repeat run, the script does not explicitly switch contexts. Do not let it apply workshop resources to an unrelated cluster. Stop if context selection fails.

Keep the default local image names and model for this first run. [k8s/kustomization.yaml](k8s/kustomization.yaml) names `sit.local` images with the `dev` application tag, and [k8s/config.yaml](k8s/config.yaml) selects `qwen3:1.7b`. Script environment overrides alone do not rewrite those manifests.

### 2. Start the local cluster stack

**PowerShell:**

```powershell
.\scripts\cluster-up.ps1
```

**Bash:**

```bash
bash ./scripts/cluster-up.sh
```

The script:

1. Creates a single-node cluster named `stack-it-yourself` if it does not exist.
2. Loads the workshop, Redis, and LGTM images from your local Docker cache into kind.
3. Creates the namespace and dashboard configuration.
4. Applies the Kubernetes manifests.
5. Downloads the model into a Kubernetes volume.
6. Waits for the deployments to become ready.

It does not rebuild the agent. Loading the same cached image is the concrete "no application rewrite" demonstration.

The Compose model directory and the Kubernetes model volume are separate. The Kubernetes step therefore calls `ollama pull` inside the cluster even if Compose already has the model.

### 3. Check the result and open the cluster UI

```bash
kubectl config current-context
kubectl -n stack-it-yourself get pods
kubectl -n stack-it-yourself get services
```

The current context must be `kind-stack-it-yourself`. Wait for the application pods to be ready, then open:

- **Agent:** http://localhost:8081
- **Grafana:** http://localhost:3001

Send a real question. Readiness alone does not prove model inference works.

Expect the same API, tools, and history-backend choices as Step 5. The `served by` value is now a pod hostname.

**Two important separations:**

- Compose's `.env` and `env/hosted.env` are **not imported** into Kubernetes. The supplied cluster uses its own ConfigMap, Secret, and local Ollama model. A laptop using hosted inference can still lack the resources for this cluster.
- Compose history is **not migrated** into the cluster's Redis. The new browser port is also a different browser origin. Start a new conversation here; this exercise demonstrates reuse of the application, not automatic data migration.

### 4. Map the deployment concepts

Read the manifests in [k8s](k8s):

| Compose concept | Kubernetes example | Why it is needed |
|---|---|---|
| Agent service | Deployment plus Service | A Deployment manages running copies; a Service provides a stable way to reach them |
| `.env` and service environment | ConfigMap plus Secret | Separates runtime settings from the image |
| Healthchecks | Readiness and, for the agent, liveness probes | Determines whether a pod can receive traffic and whether a process should be restarted |
| Host-published ports | NodePort plus kind port mappings | Makes selected cluster services reachable from your browser |
| Model bind mount | PersistentVolumeClaim | Stores model weights outside the Ollama container |
| Service-name networking | Kubernetes Service DNS | Lets the application use stable names even when pods are replaced |
| Dashboard file mounts | ConfigMap mounted into LGTM | Reuses the existing dashboard definitions |

Kubernetes does not reproduce Compose's `depends_on` startup ordering. Applications still need to tolerate unavailable dependencies; a probe is not a substitute for that behavior.

The Secret in this example contains only the dummy local Ollama key. A Kubernetes Secret is not automatically a complete secret-management or encryption solution.

### 5. Find the same telemetry in the new environment

Ask a question in the cluster UI and open its trace link. It should go to Grafana on port **3001**, not the Compose Grafana on port 3000.

The instrumentation and trace shape are unchanged. The cluster configuration adds the resource attribute `deployment.environment.name=kind`.

In the cluster Tempo Explore view, you can search:

```traceql
{ resource.deployment.environment.name = "kind" }
```

**Implementation detail:** this repository still runs the all-in-one `otel-lgtm` image in Kubernetes. It does **not** split the collector, Tempo, Loki, Prometheus, and Grafana into separately operated production services. That split is a future deployment decision, not something this script already performs.

### 6. Scale the agent

```bash
kubectl -n stack-it-yourself scale deployment/agent --replicas=3
kubectl -n stack-it-yourself rollout status deployment/agent --timeout=120s
kubectl -n stack-it-yourself get pods -l app=agent
```

You should see three ready agent pods.

Create a new conversation, give it a made-up detail, and ask several follow-ups. Responses include `served_by`, so you can see which pod handled a turn. All pods use the same Redis service.

Browser connections can be reused and stay with one pod. For a clearer demonstration, the following optional terminal exercise makes fresh connections and sends **sequential** turns under one conversation ID.

**PowerShell:**

```powershell
$uri = "http://localhost:8081/chat"
$seed = Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json" -DisableKeepAlive -TimeoutSec 180 -Body (@{
    message = "Remember that my favorite fruit is mango."
} | ConvertTo-Json)
$seed | Select-Object conversation_id, served_by, reply

1..6 | ForEach-Object {
    $turn = Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json" -DisableKeepAlive -TimeoutSec 180 -Body (@{
        message = "What fruit did I ask you to remember?"
        conversation_id = $seed.conversation_id
    } | ConvertTo-Json)
    $turn | Select-Object conversation_id, served_by, reply
}
```

**Bash:**

```bash
conversation_id="kind-demo-$(date +%s)"
curl -fsS --max-time 180 http://localhost:8081/chat \
  -H 'Content-Type: application/json' \
  -d "{\"message\":\"Remember that my favorite fruit is mango.\",\"conversation_id\":\"$conversation_id\"}"
printf '\n'

for turn in 1 2 3 4 5 6; do
  curl -fsS --max-time 180 http://localhost:8081/chat \
    -H 'Content-Type: application/json' \
    -d "{\"message\":\"What fruit did I ask you to remember?\",\"conversation_id\":\"$conversation_id\"}"
  printf '\n'
done
```

Look for:

- The **same** conversation ID on each response.
- More than one `served_by` pod name over repeated requests.
- Answers that still have the original fruit in context.

Load balancing does not guarantee that exactly six requests will visit all three pods. If necessary, confirm all replicas are ready and send a few more sequential requests.

This is a shared-history demonstration, not a concurrency test. The example does not implement per-conversation distributed locking; simultaneous requests for one conversation can race.

### What remains a demo

- **Cluster Redis has no persistent volume in these manifests.** It can outlive replacement agent pods, but replacing the Redis pod can lose its history even though append-only mode is enabled.
- LGTM storage is also disposable here.
- Three agent pods on one laptop are not a high-availability cluster.
- There are no production ingress, TLS, authentication, backup, or capacity-management arrangements.
- The CPU-only Ollama image does not become GPU-capable merely by adding a GPU resource request.

A future serving tier such as vLLM can offer GPU inference and batching. That involves suitable serving images, drivers, nodes, and configuration. It is a conceptual extension, not an installation required by this workshop.

### Why this step is needed

It tests whether the application is coupled to its laptop runtime. Externalized configuration, HTTP interfaces, portable telemetry, and shared history let the application image stay the same while deployment mechanics change.

**Checkpoint, watching or running:**

- [ ] You can map a Compose service to a Deployment and Service.
- [ ] You understand why agent replicas can share a conversation.
- [ ] You know that the cluster has separate data and configuration from Compose.
- [ ] You can distinguish "runs on Kubernetes" from "ready for production."

## Step 7: review the lessons and clean up

**Live plan:** 11:51, 9 minutes. The planned room handover requires finishing at noon.

### 1. Review the four boundaries

| Boundary | What you saw | Why it matters |
|---|---|---|
| Inference | A configurable model client and HTTP endpoint | Changing a serving backend need not require rewriting the agent |
| Observability | Standard spans, metrics, and logs exported over OTLP | You can inspect behavior without adopting a proprietary telemetry schema |
| State | Typed messages serialized into a separate history store | Replacing agent compute need not erase the conversation |
| Deployment | Existing images run in Compose and kind | Packaging and configuration make portability concrete |

MCP adds a tool boundary across processes. It fits into those same observability and deployment decisions.

### 2. Understand what is deliberately not covered

Before using these ideas in a real service, you would also need to design:

- Authentication, authorization, tool permissions, and prompt-injection boundaries.
- Network exposure, TLS, and secret management.
- History retention, backups, Redis availability, and data migration.
- Resource requests and limits, availability, scaling, and inference capacity.
- Telemetry redaction, retention, sampling, and access control.
- Evaluation and regression tests for answer quality and actual tool use.
- Ordering and conflict handling for concurrent turns in a conversation.

The planning materials place governance, access boundaries, and runtime hardening in adjacent conference workshops. The schedule tool demonstrates those listings; it does not implement those controls.

### 3. Stop the Compose stack

From the repository root:

```bash
docker compose --profile observability --profile state --profile tools down
```

Explicitly listing all three profiles makes cleanup work even if your current `.env` selects an earlier step.

This removes the project's containers and network. It leaves:

- Cached container images.
- Model weights in the host's ignored `ollama-data` directory.
- The named Redis data volume and its saved conversations.
- Your untracked runtime configuration.

**Telemetry is different:** the supplied LGTM service has no persistent data volume. Do not expect the current traces, metrics, and logs to survive container removal.

If you intentionally want to erase the Compose Redis history too, the following is **optional and destructive**:

```bash
docker compose --profile observability --profile state --profile tools down --volumes
```

Do not add `--volumes` merely to stop the workshop. It removes the project's Redis volume; it does not remove the host's model bind-mount directory.

### 4. Delete the optional local cluster

Only if you created the workshop cluster and no longer need its data:

**PowerShell:**

```powershell
.\scripts\cluster-down.ps1
```

**Bash:**

```bash
bash ./scripts/cluster-down.sh
```

These scripts delete the kind cluster named `stack-it-yourself`, including its cluster-local model storage and conversations. They do not delete the Compose model directory or Compose Redis volume.

Check your Kubernetes context before using `kubectl` for unrelated work afterward.

### 5. Clean up hosted access, if used

Attendees should remove the local `env/hosted.env` file when finished with the supplied credentials. Removing that file does not revoke its key or stop a cloud deployment.

The instructor must separately delete any paid hosted deployment and rotate any key shared for the session. See [optional instructor preparation](#optional-instructor-preparation).

### Final learning checkpoint

- [ ] I can explain where the model runs and which API the agent uses.
- [ ] I can follow a trace to a model or tool operation.
- [ ] I can explain why conversation history survives an agent replacement.
- [ ] I can distinguish a real tool call from text that describes one.
- [ ] I understand what changes, and what does not, between Compose and Kubernetes.
- [ ] I have stopped the resources I no longer need.

## Recovery paths and troubleshooting

### A. Import an offline bundle

**Use this when:** you can run containers but could not finish the image and model downloads.

Get a workshop bundle from an instructor. It contains `images.tar` and a model directory. The images must match your laptop's CPU architecture and the workshop's expected image names.

Use the actual directory on your USB drive, not the example path if it differs.

**PowerShell example:**

```powershell
.\scripts\offline-bundle.ps1 import "E:\sit-bundle"
```

**Bash example on macOS:**

```bash
bash ./scripts/offline-bundle.sh import "/Volumes/WORKSHOP/sit-bundle"
```

The script loads container images, copies model weights into the repository's local model directory, and creates a baseline `.env` if none exists.

It does not start the stack. Continue with the configuration copy for your current step and:

```bash
docker compose up -d --pull never
```

`--pull never` is useful evidence that the Compose exercise is using cached images rather than depending on the network. An image-missing error means the bundle or image names still need attention.

### B. Use an instructor-provided hosted model

**Use this when:** containers work, but your machine cannot comfortably run local inference. This requires internet access and an endpoint supplied by the instructor.

The shipped example targets Qwen3-4B-Instruct-2507 on Azure AI Foundry. You do not need to provision a deployment or bring a personal cloud account to use instructor-provided credentials.

**PowerShell:**

```powershell
Copy-Item .\env\hosted.env.example .\env\hosted.env
```

**Bash:**

```bash
cp env/hosted.env.example env/hosted.env
```

Open `env/hosted.env` in your editor. Replace both angle-bracket placeholders using the instructor's actual endpoint and key. Keep the deployment name they give you; the example uses:

```dotenv
MODEL=openai-chat:qwen3-4b-instruct
OPENAI_BASE_URL=https://<your-foundry-resource>.services.ai.azure.com/openai/v1/
OPENAI_API_KEY=<your-api-key>
REASONING=default
```

The angle-bracket values are examples, not valid credentials. Do not leave them in place.

Then apply the change:

```bash
docker compose up -d
```

Refresh the browser. Confirm `OpenAIChatModel`, Chat Completions, and the hosted model name, then send a real question.

**Why it works across the workshop:** [compose.yaml](compose.yaml) reads `env/hosted.env` after `.env`, so its model settings override each prepared step while profiles, history, and tools continue to follow the step.

**Important limitations and precautions:**

- Prompts and context now leave your laptop for that hosted service.
- Keep the key off projected screens, screenshots, commits, and shared logs.
- The file is Git-ignored, but that is not encryption.
- Avoid sharing full resolved `docker compose config` output: it can contain the key.
- Compose still starts its Ollama dependency; the override does not remove that container. It avoids loading the local model for the agent's requests.
- This override does not configure the optional Kubernetes demo.

To return to local inference, remove **only** the hosted override, then reapply Compose:

**PowerShell:**

```powershell
Remove-Item -LiteralPath .\env\hosted.env
docker compose up -d
```

**Bash:**

```bash
rm env/hosted.env
docker compose up -d
```

### C. Rejoin the current step

Every prepared configuration includes the earlier features needed for that step.

For example, to rejoin Step 5:

**PowerShell:**

```powershell
Copy-Item .\env\step5.env .env
docker compose up -d
```

**Bash:**

```bash
cp env/step5.env .env
docker compose up -d
```

Then refresh the browser and send a real test message.

Rejoining restores configuration, not lost in-memory history or missing downloads. A hosted override remains in effect until you remove it.

### D. Diagnose before resetting

| Symptom | What to check or do |
|---|---|
| Docker connection or daemon error | Start the container runtime and wait for readiness; rerun `docker info` |
| `.env` is missing | Copy the prepared environment file for the step you want |
| `sit.local` image cannot be pulled | Run preflight on a reliable connection or import a matching offline bundle; it is deliberately not a public registry |
| Windows will not run a PowerShell script | Follow your organization's script-execution policy or use the Bash equivalent in an approved shell; do not change machine-wide security policy for the lab |
| A port is already allocated | Identify the application using 8000, 11434, 3000, 8081, or 3001 and close only an application you own; do not stop unknown processes |
| Container is running but chat fails | Inspect the agent log and test a real model request; a process healthcheck does not prove model readiness |
| Model is not found | Run `docker compose exec ollama ollama list`; if needed, download the baseline with `docker compose exec ollama ollama pull qwen3:1.7b` on a reliable connection |
| All replies are very slow | Close heavy applications, check Docker memory, confirm the intended model, or use the hosted fallback; avoid plain `qwen3:4b` |
| Model or API chip did not change | Refresh the page, check that Compose applied the new configuration, and check for a hosted override |
| No trace link | Confirm telemetry is on, then send a new message; restored historical messages do not contain their old reply links |
| Grafana is unavailable | Check `docker compose ps lgtm` and its logs; give the service time to start |
| Dashboard has no metrics yet | Generate several messages, wait for multiple exports, and check the time range |
| Recent trace is not in search | Use its direct link and allow export/indexing time |
| Conversation appears empty after restart | Check history is `redis`, keep the same origin and footer ID, and do not click New during the test |
| Model describes a tool instead of using it | Inspect `tools_called` or the execution span, retry explicitly, or use the prepared 4B instruct tier |
| No MCP execution spans | Confirm `TOOLS=local,mcp`, the `tools` profile, and a healthy `mcp-server`; ask a schedule question that needs a remote tool |
| Hosted backend returns 401 | Verify the supplied key and base URL with the instructor; different routes can use different authentication conventions |
| Hosted backend rejects Responses | Use a supported API prefix, commonly `openai-chat:`, and verify compatibility; not every endpoint supports both APIs |
| Agent shows HTTP 502 | Read the surfaced backend error and agent log; this can wrap a model HTTP error or a connection failure rather than indicate a browser problem |
| kind has `ImagePullBackOff` | Verify the expected `sit.local`/`dev` images are cached and loaded; custom script image overrides do not rewrite the Kustomize image names |
| kind is ready but model calls fail | Check the separate in-cluster model download, the selected context, and the agent/Ollama logs |
| Every scaled request reaches one pod | Confirm three ready replicas and try fresh sequential connections; service load balancing is not a guaranteed round-robin sequence |

Useful read-only diagnostics:

```bash
docker compose ps
docker compose logs --tail 100 agent
docker compose logs --tail 100 ollama
docker compose logs --tail 100 lgtm
docker compose logs --tail 100 mcp-server
```

Use only the services active for your step. Logs can contain conversation content or backend details; redact them before sharing.

The application also exposes `/healthz` and `/info`:

**PowerShell:**

```powershell
Invoke-RestMethod -Uri http://localhost:8000/healthz
Invoke-RestMethod -Uri http://localhost:8000/info
```

**Bash:**

```bash
curl -fsS http://localhost:8000/healthz
curl -fsS http://localhost:8000/info
```

`/healthz` checks the web application, not all its dependencies. `/info` describes the active client, history, tools, telemetry, and serving hostname; it does not return the API key.

For the optional cluster:

```bash
kubectl config current-context
kubectl -n stack-it-yourself get pods
kubectl -n stack-it-yourself logs deployment/agent --tail=100
kubectl -n stack-it-yourself logs deployment/ollama --tail=100
```

If a clean container restart is necessary, use the all-profile `down` command from Step 7 and then reapply the current step. Leave out `--volumes` unless erasing Redis data is intentional. There is no need for broad Docker pruning or deletion of unrelated resources.

## Optional instructor preparation

This section is for someone delivering the workshop, not additional attendee prerequisites.

### Before the event

1. Run preflight and rehearse Steps 1-5 on every presenter laptop. Use the current repository rather than treating old planning output as a fresh test result.
2. Decide whether attendees receive published workshop images, use local builds, or import USB bundles. The default prefix is local-only. See [README.md](README.md#running-this-workshop-yourself) and the [image publication workflow](.github/workflows/publish-images.yml).
3. Prepare offline bundles after successful preflight. Build separate image bundles for different CPU architectures as needed; cross-shell import does not imply cross-architecture image compatibility.
4. Verify the bundled schedule against the event plan. It is a fixed demo snapshot, not a live agenda feed.
5. Prewarm the presenter cluster and run one real cluster question before the room opens. Verify the Kubernetes context, ports 8081/3001, trace links, and three-replica demonstration.
6. Bring a recovery plan: helpers, charger/power access, offline media, a pairing option, and a recorded demonstration if available.
7. Allow time for room turnover. If behind, preserve the first working chat, the guided trace, the cross-process MCP trace, and the same-image deployment explanation. Optional experiments and repeated scaling requests can be shortened.

Example bundle export:

**PowerShell:**

```powershell
.\scripts\offline-bundle.ps1 export "E:\sit-bundle"
```

**Bash:**

```bash
bash ./scripts/offline-bundle.sh export "/Volumes/WORKSHOP/sit-bundle"
```

### Hosted fallback lifecycle

Only prepare this if you have an appropriate existing Foundry resource, permissions, capacity/quota, and approval for the cost. The scripts do not create a whole Azure account or an arbitrary new workshop environment.

The lifecycle is implemented in [scripts/hosted-fallback.ps1](scripts/hosted-fallback.ps1) and [scripts/hosted-fallback.sh](scripts/hosted-fallback.sh):

| Action | Purpose |
|---|---|
| `up` | Creates the named managed-compute model deployment and waits for it |
| `status` | Reports the deployment state and endpoint |
| `env` | Writes the private local hosted override for a smoke test |
| `down` | Deletes that model deployment after the event |

The supplied configuration uses one A100 80 GB accelerator. Provisioning took around 15-20 minutes in the planning tests. The script's approximately USD 3.95/hour figure is a historical estimate, **not a current pricing guarantee**. Verify current availability and pricing. Billing can continue while an idle deployment exists.

For an approved resource, a PowerShell preparation example is:

```powershell
$account = "YOUR_FOUNDRY_RESOURCE"
$resourceGroup = "YOUR_RESOURCE_GROUP"

.\scripts\hosted-fallback.ps1 up -Account $account -ResourceGroup $resourceGroup
.\scripts\hosted-fallback.ps1 status -Account $account -ResourceGroup $resourceGroup
.\scripts\hosted-fallback.ps1 env -Account $account -ResourceGroup $resourceGroup
```

Replace the example names, authenticate the Azure CLI to the intended subscription first, and keep the written key private. Send a real agent question to verify the deployment; merely creating it is not enough.

After the session, using the same approved resource names:

```powershell
.\scripts\hosted-fallback.ps1 down -Account $account -ResourceGroup $resourceGroup
```

Verify deletion in Azure, rotate any shared key, and remove private override files. Compose shutdown and removal of a local credential file do not stop managed-compute billing.

## Where to look next

### Small, optional experiments

- After downloading `qwen3:4b-instruct`, change `MODEL` in your untracked `.env` to `openai-responses:qwen3:4b-instruct`, rerun Compose, and compare actual tool traces and token usage. A hosted override would take precedence.
- Change `CAPTURE_CONTENT` in `.env` to `false` and inspect new spans. Compare observability with and without conversation content.
- Read how `REASONING=off` changes model settings, then compare latency and output tokens in a controlled, non-sensitive question. CPU reasoning can be slow; this is not needed for the live workshop.
- Consider another OTLP-compatible observability backend. Compose explicitly sets the export endpoint, so changing only an arbitrary new `.env` variable will not override that service setting; deployment wiring would also need attention.
- Study an alternative Redis-protocol store such as Valkey. Protocol compatibility is not on-disk compatibility: do not point it at an existing Redis 8 data volume without a supported migration plan.
- Design an evaluation that checks whether an actual tool was called, not merely whether the generated answer sounded plausible.

### Repository reading map

| File or directory | Read it to understand |
|---|---|
| [README.md](README.md) | The concise architecture, configuration reference, and reuse notes |
| [prerequisites.md](prerequisites.md) | Installation, machine requirements, and model tiers |
| [CHEATSHEET.md](CHEATSHEET.md) | The quick in-room command reference |
| [compose.yaml](compose.yaml) | Services, profiles, ports, dependencies, and storage |
| [env](env) | The five complete step configurations and hosted example |
| [agent/app/assistant.py](agent/app/assistant.py) | Model selection, instructions, instrumentation, and tool wiring |
| [agent/app/settings.py](agent/app/settings.py) | How runtime settings enter the application |
| [agent/app/main.py](agent/app/main.py) | The chat HTTP endpoint, conversation lookup, response metadata, and error reporting |
| [agent/app/history.py](agent/app/history.py) | The memory/Redis boundary and typed message serialization |
| [agent/app/tools.py](agent/app/tools.py) | The in-process time tool |
| [agent/app/static/index.html](agent/app/static/index.html) | Browser conversation IDs, status chips, and direct trace links |
| [mcp-server/server.py](mcp-server/server.py) | The schedule snapshot and remote tools |
| [grafana/dashboards/agent.json](grafana/dashboards/agent.json) | The actual queries behind the eight dashboard panels |
| [images/ollama-cpu/Dockerfile](images/ollama-cpu/Dockerfile) | Why the workshop's runtime image omits GPU backends |
| [k8s](k8s) | The cluster mappings and their development-only limitations |
| [scripts](scripts) | Preflight, offline import/export, cluster lifecycle, and hosted fallback helpers |

### Planning basis

The event timing and learning progression in this guide follow the accepted workshop proposal, the v4 workshop outline, the event prerequisites, and the existing planning run of show supplied for AGNTCon + MCPCon 2026. The current repository determines the commands, framework, configuration, storage behavior, and limitations described here.

Planning measurements are context, not fresh results from your machine. Earlier proposals and intermediate outlines describe alternatives that are not required by this implementation: the current framework is Pydantic AI, vLLM is a future serving-tier discussion, and the Kubernetes lab retains the all-in-one LGTM image.

You have now followed the workshop's central progression: **a working local agent, an explicit inference boundary, visible execution, external history, interoperable tools, and portable deployment packaging**.
