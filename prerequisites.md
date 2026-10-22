# Before you arrive: prerequisites

**Stack It Yourself: Open Infrastructure for AI Agents, from Compose to Cluster**

Your workshop organisers will tell you the date, time and room. This page covers everything to do *before* you get there.

---

## Please read this - it decides whether the workshop works for you

You will build and run a complete AI agent stack **on your own laptop**: an agent, a local language model, an observability stack, Redis, and an MCP server. That is **about 2.6 GB of downloads**.

**A full room cannot download that over conference Wi-Fi.** At home, on hotel Wi-Fi, or at the office it takes about 10–20 minutes and needs no attention. **Please do it a few days before the workshop**, so there is time to ask for help if something fails.

### The short version

1. Install a container runtime and Git (links below).
2. Clone this repository.
3. Run preflight - one command that downloads everything, tests it, and prints a checklist.
4. All `OK`? You're done. Nothing is left running.

```bash
git clone <this repository's URL>          # the green "Code" button on GitHub
cd stack-it-yourself-workshop
chmod +x ./scripts/preflight.sh   # macOS, Linux, WSL, Git Bash: make the script executable first
./scripts/preflight.sh            # macOS, Linux, WSL, Git Bash
./scripts/preflight.ps1           # Windows PowerShell
```

> **`Permission denied` when you run `./scripts/preflight.sh`?** The script isn't marked executable yet (this happens with ZIP downloads and some Git setups). Run `chmod +x ./scripts/preflight.sh` and try again. The other `.sh` scripts need the same fix: `chmod +x ./scripts/*.sh`.

A good result ends with:

```text
[6/6] Smoke test: one real chat turn through the agent
  OK   The agent answered - your laptop can run the workshop

All set - see you at the workshop!  (Everything is downloaded; nothing is left running.)
```

---

## 1. Hardware

| | Minimum | Recommended |
|---|---|---|
| **RAM** | 8 GB | 16 GB or more |
| **Memory available to Docker** | 5 GB | 8 GB |
| **Free disk** | 10 GB | 15 GB |
| **CPU** | 64-bit Intel/AMD from about 2018 on, or Apple Silicon (M1 or newer) | 8 or more cores |
| **GPU** | **Not needed, and not used.** Everything runs on the CPU. | - |
| **OS** | macOS 13+, Windows 10/11, or Linux | - |

There is no GPU track. Everyone in the room runs the same exercises on the CPU.

**Docker Desktop users:** check *Settings → Resources → Memory*. If it is below 5 GB, raise it. At the busiest point of the workshop the stack uses about 3.5 GB.

---

## 2. Software

| What | Link | Notes |
|---|---|---|
| **A container runtime** with Compose **2.24 or newer** | [Docker Desktop](https://docs.docker.com/desktop/) · [Rancher Desktop](https://rancherdesktop.io/) · [Podman Desktop](https://podman-desktop.io/) · [OrbStack](https://orbstack.dev/) (macOS) | Any of these works. Check with `docker compose version`. |
| **Git** | [git-scm.com/downloads](https://git-scm.com/downloads) | To clone the repo. |
| **A browser** | - | The agent UI and Grafana run in your browser. |
| *Windows only:* **WSL 2** | [Install WSL](https://learn.microsoft.com/windows/wsl/install) | Docker Desktop uses it. PowerShell works fine for the workshop commands. |

**You do not need** Python, Ollama installed natively, Kubernetes, or any cloud account or API key. It all runs in containers, and there are no proprietary API keys - that's rather the point.

---

## 3. What preflight downloads

| Item | Download | Why |
|---|---|---|
| Grafana LGTM (`grafana/otel-lgtm:0.34.0`) | ~0.9 GB | Traces, metrics and logs in one container |
| Workshop images: agent, MCP server, CPU-only Ollama | ~0.2 GB | Built for this workshop - see note below |
| Redis (`redis:8.10-alpine`) | ~40 MB | Durable conversation history |
| **Model: `qwen3:1.7b`** | **1.4 GB** | The language model everyone uses |
| **Total** | **~2.6 GB** | |

> **Why a "CPU-only Ollama" image?** The official `ollama/ollama` image is a 3.75 GB download, and about 4.7 GB of its 9 GB on disk is GPU runtime (CUDA, MLX-CUDA, Vulkan) that a CPU-only workshop never touches. Ours copies the official Ollama binary and its CPU backends into a small image - about 54 MB. The Dockerfile is in [`images/ollama-cpu`](images/ollama-cpu/Dockerfile) if you want to check.

---

## 4. The model - and which one to pick

We use **Qwen3**, because it is **Apache-2.0 at every size**. This workshop is about open infrastructure, so we wanted a model that is genuinely open source rather than just free to download. Llama's and NVIDIA Nemotron's licences are not OSI-approved.

| Tier | Model | Download | Needs | Use it if... |
|---|---|---|---|---|
| **Baseline (everyone)** | [`qwen3:1.7b`](https://ollama.com/library/qwen3:1.7b) | 1.4 GB | 8 GB RAM | **Default.** Preflight gets this one. |
| **Recommended** | [`qwen3:4b-instruct`](https://ollama.com/library/qwen3:4b-instruct) | 2.5 GB | 16 GB RAM | You have the RAM and want steadier tool calling. Run preflight with `--with-4b` (bash) or `-With4b` (PowerShell). |
| Lightweight | [`qwen3:0.6b`](https://ollama.com/library/qwen3:0.6b) | 0.5 GB | older, slower laptops | Only if 1.7b is too slow. It works for Steps 1–4 but often fumbles the tool calls in Step 5. |

**What we measured** on a 16-thread laptop CPU, with no GPU:

| | Tool calls made correctly | Time per question |
|---|---|---|
| `qwen3:1.7b` | 4 of 4 | ~4 s |
| `qwen3:4b-instruct` | 4 of 4 | ~8 s |
| `qwen3:0.6b` | 2–3 of 4 | ~2 s |

Expect slower times on an older laptop. The **first** reply after starting the stack takes 15–30 s while the model loads into memory. After that it's quick.

> ⚠️ **Don't pick plain `qwen3:4b`.** In Ollama that tag is the *Thinking-2507* variant, which always "thinks" before answering and cannot be switched off. On a CPU that took nearly two minutes per question in our tests. Use `qwen3:4b-instruct`.

---

## 5. When to do what

| When | Do this |
|---|---|
| **A week or more before** | Install the software, clone the repo, run preflight, and fix anything that fails. |
| **The night before** | `git pull`, then run preflight again - it takes a minute when everything is already downloaded. |
| **Morning of** | Start Docker **before** you walk into the room. |
| **In the room** | Arrive a few minutes early and open the repo. Bring your charger: running a model is hard on the battery. |

---

## 6. If you can't prepare - come anyway

What's available depends on your workshop, so check with the organisers. The repo supports both of these:

| Situation | What helps |
|---|---|
| **Couldn't download** | An **offline bundle** - every image and the model on a USB drive, if your instructors bring one. One command installs it with no network: `./scripts/offline-bundle.sh import <drive>` (or `offline-bundle.ps1 import <drive>`). |
| **Laptop can't run the model** | The **hosted fallback on Azure AI Foundry**, serving Qwen3-4B-Instruct-2507 (the same model as the recommended tier). Copy `env/hosted.env.example` to `env/hosted.env`, fill in the endpoint and key your instructors give you, and do every exercise the same way as everyone else. |
| **Laptop can't run containers at all** | Pair with a neighbour - this material pairs well - or follow along on the big screen. Every step is shown. |

Every step is one command against a known-good configuration, so if you fall behind, one command puts you back with the room.

---

## 7. Ready when...

- [ ] `docker compose version` shows 2.24 or newer
- [ ] Preflight ends with **All set**
- [ ] 10 GB or more of disk is still free
- [ ] Your charger is in your bag

## 8. Common problems

**A download fails partway.** Run preflight again. Downloads resume where they stopped.

**"Docker is not running."** Start Docker Desktop (or your runtime) and wait for it to report that it's running.

**Windows: Docker Desktop won't start.** Make sure WSL 2 is installed and virtualization is enabled in BIOS/UEFI.

**Corporate VPN or proxy blocks image pulls.** Try from a personal network. Registry filtering is common on corporate networks, and we can't work around it in the room.

**Low on disk.** `docker system prune` reclaims space from old containers and images. Check what it will delete first.

**Replies are very slow.** Close other heavy apps, give Docker more memory, or drop to `qwen3:0.6b` - but expect Step 5's tool calls to wobble.

**Questions before your workshop?** Open an issue on the repo. The answer then helps everyone.
