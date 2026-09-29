<#
.SYNOPSIS
  Stack It Yourself - Step 6: stand the Step 5 stack up on a local kind cluster.
.DESCRIPTION
  About five minutes the first time, so run it before you need it. It loads images from your
  local Docker cache (no registry pulls) and pulls the model into the cluster once.
  Then open http://localhost:8081 and :3001.
#>
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
$cluster = "stack-it-yourself"; $ns = "stack-it-yourself"
$prefix = if ($env:IMAGE_PREFIX) { $env:IMAGE_PREFIX } else { "sit.local" }
$tag = if ($env:WORKSHOP_VERSION) { $env:WORKSHOP_VERSION } else { "dev" }
$model = if ($env:CLUSTER_MODEL) { $env:CLUSTER_MODEL } else { "qwen3:1.7b" }
$images = @("$prefix/ollama-cpu:0.34.4", "$prefix/agent:$tag", "$prefix/mcp-server:$tag", "grafana/otel-lgtm:0.34.0", "redis:8.10-alpine")

function Run { & $args[0] $args[1..($args.Count - 1)]; if ($LASTEXITCODE -ne 0) { throw "failed: $args" } }

if (-not ((kind get clusters 2>$null) -contains $cluster)) { Run kind create cluster --config k8s/kind-cluster.yaml }
Write-Host "Loading images into the cluster from the local Docker cache (no registry needed)..."
foreach ($image in $images) {
  kind load docker-image $image --name $cluster 2>$null
  if ($LASTEXITCODE -ne 0) {
    # Docker Desktop's containerd image store keeps only your platform's layers of a
    # multi-platform image, which trips kind's --all-platforms import. Export just this platform.
    $platform = docker image inspect $image --format '{{.Os}}/{{.Architecture}}'
    $archive = Join-Path ([IO.Path]::GetTempPath()) "sit-kind-image.tar"
    Run docker save --platform $platform -o $archive $image
    Run kind load image-archive $archive --name $cluster
    Remove-Item $archive -ErrorAction SilentlyContinue
  }
}

Run kubectl apply -f k8s/namespace.yaml
kubectl -n $ns create configmap workshop-dashboards --from-file=grafana/dashboards --dry-run=client -o yaml | kubectl apply -f -
Run kubectl apply -k k8s

Run kubectl -n $ns rollout status deployment/ollama --timeout=300s
Write-Host "Making sure $model is in the cluster's model volume..."
# '--' must be quoted: unquoted, PowerShell consumes it as its own end-of-parameters marker.
Run kubectl -n $ns exec deployment/ollama '--' ollama pull $model
foreach ($d in "redis", "lgtm", "mcp-server", "agent") { Run kubectl -n $ns rollout status "deployment/$d" --timeout=300s }

Write-Host ""
Write-Host "Agent:   http://localhost:8081"
Write-Host "Grafana: http://localhost:3001"
Write-Host "Scale:   kubectl -n $ns scale deployment/agent --replicas=3"
