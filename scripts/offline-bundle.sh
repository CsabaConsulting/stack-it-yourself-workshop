#!/usr/bin/env bash
# Stack It Yourself - offline bundle, for when the network can't be trusted.
#
#   Instructors, on a machine that has passed preflight:
#     ./scripts/offline-bundle.sh export /Volumes/USB/sit-bundle
#   Attendees, with no network at all:
#     ./scripts/offline-bundle.sh import /Volumes/USB/sit-bundle
#
# The bundle holds every container image (images.tar) and the model folder (ollama-data/).
set -euo pipefail
cd "$(dirname "$0")/.."

cmd="${1:-}"; dir="${2:-offline-bundle}"
PREFIX="${IMAGE_PREFIX:-sit.local}"; TAG="${WORKSHOP_VERSION:-dev}"
IMAGES=("$PREFIX/ollama-cpu:0.34.4" "$PREFIX/agent:$TAG" "$PREFIX/mcp-server:$TAG" "grafana/otel-lgtm:0.34.0" "redis:8.10-alpine")

case "$cmd" in
  export)
    mkdir -p "$dir"
    # Layers are stored compressed already, so no extra gzip (it saved under 1% in testing).
    echo "Saving ${#IMAGES[@]} images..."
    docker save -o "$dir/images.tar" "${IMAGES[@]}"
    echo "Copying model folder..."
    mkdir -p "$dir/ollama-data" && cp -R ollama-data/. "$dir/ollama-data/"
    du -sh "$dir"
    echo "Bundle ready in $dir"
    ;;
  import)
    archive="$dir/images.tar"; [ -f "$archive" ] || archive="$dir/images.tar.gz"
    [ -f "$archive" ] || { echo "No images.tar in $dir"; exit 1; }
    echo "Loading images (no network needed)..."
    docker load -i "$archive"
    echo "Copying model folder..."
    mkdir -p ollama-data && cp -R "$dir/ollama-data/." ollama-data/
    [ -f .env ] || cp env/step1.env .env
    echo "Done. Start Step 1 with:  docker compose up -d"
    ;;
  *) sed -n '2,9p' "$0"; exit 2 ;;
esac
