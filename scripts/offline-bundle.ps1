<#
.SYNOPSIS
  Stack It Yourself - offline bundle, for when the network can't be trusted.
.EXAMPLE
  # Instructors, on a machine that has passed preflight:
  ./scripts/offline-bundle.ps1 export E:\sit-bundle
  # Attendees, with no network at all:
  ./scripts/offline-bundle.ps1 import E:\sit-bundle
.NOTES
  The bundle holds every container image (images.tar) and the model folder (ollama-data/).
#>
param(
  [Parameter(Mandatory)][ValidateSet("export", "import")][string]$Command,
  [string]$Dir = "offline-bundle"
)
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
$prefix = if ($env:IMAGE_PREFIX) { $env:IMAGE_PREFIX } else { "sit.local" }
$tag = if ($env:WORKSHOP_VERSION) { $env:WORKSHOP_VERSION } else { "dev" }
$images = @("$prefix/ollama-cpu:0.34.4", "$prefix/agent:$tag", "$prefix/mcp-server:$tag", "grafana/otel-lgtm:0.34.0", "redis:8.10-alpine")

if ($Command -eq "export") {
  New-Item -ItemType Directory -Force -Path $Dir | Out-Null
  # Layers are stored compressed already, so no extra gzip (it saved under 1% in testing).
  Write-Host "Saving $($images.Count) images..."
  docker save -o (Join-Path $Dir "images.tar") @images
  if ($LASTEXITCODE -ne 0) { throw "docker save failed" }
  Write-Host "Copying model folder..."
  $dest = Join-Path $Dir "ollama-data"
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  Copy-Item "ollama-data\*" $dest -Recurse -Force   # copy contents, so re-exporting never nests the folder
  $gb = (Get-ChildItem $Dir -Recurse -File | Measure-Object Length -Sum).Sum / 1GB
  Write-Host ("Bundle ready in {0} ({1:N1} GB)" -f $Dir, $gb)
} else {
  $archive = @("images.tar", "images.tar.gz") | ForEach-Object { Join-Path $Dir $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $archive) { throw "No images.tar in $Dir" }
  Write-Host "Loading images (no network needed)..."
  docker load -i $archive
  if ($LASTEXITCODE -ne 0) { throw "docker load failed" }
  Write-Host "Copying model folder..."
  New-Item -ItemType Directory -Force -Path ollama-data | Out-Null
  Copy-Item (Join-Path $Dir "ollama-data\*") ollama-data -Recurse -Force
  if (-not (Test-Path .env)) { Copy-Item env/step1.env .env }
  Write-Host "Done. Start Step 1 with:  docker compose up -d"
}
