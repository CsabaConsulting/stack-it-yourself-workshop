#!/usr/bin/env bash
# Stack It Yourself - Step 6: stand the Step 5 stack up on a local kind cluster.
# About five minutes the first time, so run it before you need it. It loads images from your
# local Docker cache (no registry pulls) and pulls the model into the cluster once.
#
#   ./scripts/cluster-up.sh       then open http://localhost:8081 (agent) and :3001 (Grafana)
#   ./scripts/cluster-down.sh     to delete the cluster
set -euo pipefail
cd "$(dirname "$0")/.."

CLUSTER=stack-it-yourself; NS=stack-it-yourself
PREFIX="${IMAGE_PREFIX:-sit.local}"; TAG="${WORKSHOP_VERSION:-dev}"; MODEL="${CLUSTER_MODEL:-qwen3:1.7b}"
IMAGES=("$PREFIX/ollama-cpu:0.34.4" "$PREFIX/agent:$TAG" "$PREFIX/mcp-server:$TAG" "grafana/otel-lgtm:0.34.0" "redis:8.10-alpine")

kind get clusters 2>/dev/null | grep -qx "$CLUSTER" || kind create cluster --config k8s/kind-cluster.yaml
echo "Loading images into the cluster from the local Docker cache (no registry needed)..."
for image in "${IMAGES[@]}"; do
  if ! kind load docker-image "$image" --name "$CLUSTER" 2>/dev/null; then
    # Docker Desktop's containerd image store keeps only your platform's layers of a
    # multi-platform image, which trips kind's --all-platforms import. Export just this platform.
    platform="$(docker image inspect "$image" --format '{{.Os}}/{{.Architecture}}')"
    archive="$(mktemp)"
    docker save --platform "$platform" -o "$archive" "$image"
    kind load image-archive "$archive" --name "$CLUSTER"
    rm -f "$archive"
  fi
done

kubectl apply -f k8s/namespace.yaml
kubectl -n "$NS" create configmap workshop-dashboards --from-file=grafana/dashboards \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -k k8s

kubectl -n "$NS" rollout status deployment/ollama --timeout=300s
echo "Making sure $MODEL is in the cluster's model volume..."
kubectl -n "$NS" exec deployment/ollama -- ollama pull "$MODEL"
for d in redis lgtm mcp-server agent; do kubectl -n "$NS" rollout status "deployment/$d" --timeout=300s; done

echo
echo "Agent:   http://localhost:8081"
echo "Grafana: http://localhost:3001"
echo "Scale:   kubectl -n $NS scale deployment/agent --replicas=3"
