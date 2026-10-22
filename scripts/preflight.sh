#!/usr/bin/env bash
# Stack It Yourself - preflight. Run at home, on good Wi-Fi, a few days before the workshop.
#
#   ./scripts/preflight.sh              baseline model qwen3:1.7b (required)
#   ./scripts/preflight.sh --with-4b    also qwen3:4b-instruct, the recommended tier (16 GB RAM)
#
# It checks your machine, downloads every container image and the model, runs a real chat
# turn through the agent, then shuts everything down. Safe to re-run: downloads resume.
set -uo pipefail
cd "$(dirname "$0")/.."

MODELS=("qwen3:1.7b")
for arg in "$@"; do
  case "$arg" in
    --with-4b) MODELS+=("qwen3:4b-instruct") ;;
    --with-0.6b) MODELS+=("qwen3:0.6b") ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg"; exit 2 ;;
  esac
done

PROFILES=(--profile observability --profile state --profile tools)
FAILED=0
ok()   { printf '  \033[32mOK\033[0m   %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }
note() { printf '  \033[33mNOTE\033[0m %s\n' "$1"; }
ver_ge() { awk -v have="$1" -v need="$2" 'BEGIN { split(have,a,"."); split(need,b,".");
  for (i=1;i<=3;i++) { if ((a[i]+0)>(b[i]+0)) exit 0; if ((a[i]+0)<(b[i]+0)) exit 1 } exit 0 }'; }

echo "Stack It Yourself - preflight"
echo

echo "[1/6] Container runtime"
if ! docker info >/dev/null 2>&1; then
  bad "Docker is not running. Start Docker Desktop (or your runtime) and run this again."
  exit 1
fi
ok "Docker engine is running"
compose_v="$(docker compose version --short 2>/dev/null | sed 's/^v//')"
if [ -n "$compose_v" ] && ver_ge "$compose_v" "2.24.0"; then ok "Docker Compose $compose_v"
else bad "Docker Compose ${compose_v:-not found} - version 2.24 or newer is required. Update Docker Desktop."; fi

echo "[2/6] Resources"
mem_gb=$(( $(docker info --format '{{.MemTotal}}') / 1024 / 1024 / 1024 ))
if [ "$mem_gb" -ge 6 ]; then ok "Docker can use ${mem_gb} GB of memory"
else note "Docker can use only ${mem_gb} GB of memory. Give it at least 6 GB (Docker Desktop > Settings > Resources)."; fi
free_gb=$(( $(df -Pk . | awk 'NR==2 {print $4}') / 1024 / 1024 ))
if [ "$free_gb" -ge 10 ]; then ok "${free_gb} GB free disk"
else bad "Only ${free_gb} GB free disk - at least 10 GB is needed."; fi

echo "[3/6] Workshop configuration"
if [ ! -f .env ]; then cp env/step1.env .env; ok "Created .env from env/step1.env"
else ok ".env already exists (left untouched)"; fi
mkdir -p ollama-data

echo "[4/6] Container images (the big download)"
PREFIX="${IMAGE_PREFIX:-sit.local}"
if docker compose "${PROFILES[@]}" pull --ignore-buildable --quiet; then ok "Pulled Grafana LGTM and Redis"
else bad "Could not pull Grafana LGTM / Redis - check your network and re-run."; fi
if [ "$PREFIX" != "sit.local" ] && docker compose "${PROFILES[@]}" pull --quiet agent mcp-server ollama 2>/dev/null; then
  ok "Pulled prebuilt workshop images from $PREFIX"
elif docker compose "${PROFILES[@]}" build --quiet; then
  ok "Built workshop images locally (agent, MCP server, CPU-only Ollama)"
else bad "Image build failed - see the output above."; fi

echo "[5/6] Model weights"
docker compose up -d --wait ollama >/dev/null 2>&1 || bad "Ollama did not start"
for m in "${MODELS[@]}"; do
  echo "  ...  downloading $m (progress below - safe to re-run if it stops)"
  if docker compose exec -T ollama ollama pull "$m"; then ok "Model $m"
  else bad "Could not download $m - re-run to resume."; fi
done

echo "[6/6] Smoke test: one real chat turn through the agent"
if docker compose up -d --wait agent >/dev/null 2>&1; then
  reply="$(curl -fsS -m 180 -X POST http://localhost:8000/chat -H 'content-type: application/json' \
    -d '{"message":"Reply with the single word: ready"}' 2>/dev/null || true)"
  if printf '%s' "$reply" | grep -q '"reply"'; then ok "The agent answered - your laptop can run the workshop"
  else bad "The agent did not answer. Run: docker compose logs agent"; fi
else bad "The agent did not start. Run: docker compose logs agent"; fi
docker compose "${PROFILES[@]}" down >/dev/null 2>&1

echo
if [ "$FAILED" -eq 0 ]; then
  printf '\033[32mAll set - see you at the workshop!\033[0m  (Everything is downloaded; nothing is left running.)\n'
else
  printf '\033[31mSomething needs attention - fix the FAIL lines above and run this again.\033[0m\n'
  echo "Stuck? Open an issue on the workshop repo, or ask your workshop instructors."
  exit 1
fi
