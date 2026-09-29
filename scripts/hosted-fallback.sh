#!/usr/bin/env bash
# Stack It Yourself - the hosted fallback on Azure AI Foundry (managed compute).
#
# Deploys Qwen3-4B-Instruct-2507 - the same model as the workshop's recommended local tier - on one
# NVIDIA A100 80GB in your Foundry resource. Attendees whose laptops can't run the local model point
# env/hosted.env at it and do every exercise unchanged. It serves both Chat Completions and the
# Responses API on https://<resource>.openai.azure.com/openai/v1/.
#
# Managed compute bills per GPU-hour for as long as the deployment exists (about USD 3.95/hour for
# one A100 80GB when this was written), whether or not anyone calls it. Run "up" shortly before the
# session - provisioning takes 15-20 minutes - and "down" straight after.
#
#   ./scripts/hosted-fallback.sh up     <account> <resource-group>   # 15-20 minutes
#   ./scripts/hosted-fallback.sh status <account> <resource-group>
#   ./scripts/hosted-fallback.sh env    <account> <resource-group>   # writes env/hosted.env (git-ignored)
#   ./scripts/hosted-fallback.sh down   <account> <resource-group>   # deletes it - billing stops
#
# Needs: Azure CLI logged in to the subscription that holds the Foundry resource, and
# Cognitive Services Contributor (or Owner) on that resource. Optional: DEPLOYMENT=<name>.
set -euo pipefail
cd "$(dirname "$0")/.."

cmd="${1:-}"; account="${2:-}"; rg="${3:-}"
[ -n "$cmd" ] && [ -n "$account" ] && [ -n "$rg" ] || { sed -n '2,19p' "$0"; exit 2; }
deployment="${DEPLOYMENT:-qwen3-4b-instruct}"
model="azureml://registries/azure-huggingface/models/qwen--qwen3-4b-instruct-2507/versions/3"
template="azureml://registries/azure-huggingface/deploymenttemplates/qwen--qwen3-4b-instruct-2507--256k-nvidia-a100/labels/latest"
accelerator="A100_80GB"
api="2026-09-01"

sub="$(az account show --query id -o tsv)" || { echo "Run 'az login' first."; exit 1; }
dep_url="https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.CognitiveServices/accounts/$account/managedComputeDeployments/$deployment?api-version=$api"

state() { az rest --method get --url "$dep_url" --query properties.provisioningState -o tsv 2>/dev/null || true; }
base_url() { echo "https://$(az cognitiveservices account show -n "$account" -g "$rg" --query properties.customSubDomainName -o tsv).openai.azure.com/openai/v1/"; }

case "$cmd" in
  up)
    if [ -n "$(state)" ]; then echo "Deployment '$deployment' already exists ($(state))."
    else
      echo "Creating '$deployment' on 1x $accelerator in $account - billing starts now (about USD 3.95/hour)."
      body="$(mktemp)"
      cat > "$body" <<EOF
{"sku":{"name":"GlobalManagedCompute","capacity":1},
 "properties":{"model":"$model","deploymentTemplate":"$template","acceleratorType":"$accelerator","versionUpgradeOption":"NoAutoUpgrade"}}
EOF
      az rest --method put --url "$dep_url" --body "@$body" --headers "Content-Type=application/json" -o none
      rm -f "$body"
    fi
    start=$(date +%s)
    while :; do
      sleep 30; s="$(state)"
      printf '  %5.1f min  %s\n' "$(awk -v a="$start" -v b="$(date +%s)" 'BEGIN{print (b-a)/60}')" "$s"
      case "$s" in Succeeded) break ;; Failed|Canceled) echo "Provisioning ended in state '$s'."; exit 1 ;; esac
    done
    echo; echo "Ready. Base URL: $(base_url)   model: $deployment"
    echo "Next: ./scripts/hosted-fallback.sh env ... to test it, and remember 'down' afterwards."
    ;;
  status)
    s="$(state)"
    if [ -z "$s" ]; then echo "No deployment '$deployment' - nothing is billing."
    else echo "$deployment : $s (billing while it exists)"; echo "Base URL: $(base_url)   model: $deployment"; fi
    ;;
  env)
    [ "$(state)" = "Succeeded" ] || { echo "Deployment '$deployment' isn't ready - run 'up' first."; exit 1; }
    key="$(az cognitiveservices account keys list -n "$account" -g "$rg" --query key1 -o tsv)"
    printf '%s\n' "# Written by scripts/hosted-fallback.sh - git-ignored, never commit it." \
      "MODEL=openai-chat:$deployment" "OPENAI_BASE_URL=$(base_url)" "OPENAI_API_KEY=$key" "REASONING=default" > env/hosted.env
    echo "Wrote env/hosted.env. Run 'docker compose up -d' and the agent uses the hosted model."
    echo "Delete env/hosted.env to go back to local inference."
    ;;
  down)
    [ -n "$(state)" ] || { echo "No deployment '$deployment' - nothing to delete."; exit 0; }
    echo "Deleting '$deployment'..."
    az rest --method delete --url "$dep_url" -o none
    while [ -n "$(state)" ]; do sleep 20; done
    echo "Deleted - billing has stopped."
    echo "If keys were handed out, rotate them: az cognitiveservices account keys regenerate -n $account -g $rg --key-name key1"
    ;;
  *) sed -n '2,19p' "$0"; exit 2 ;;
esac
