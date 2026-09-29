<#
.SYNOPSIS
  Stack It Yourself - preflight. Run at home, on good Wi-Fi, a few days before the workshop.
.DESCRIPTION
  Checks your machine, downloads every container image and the model, runs a real chat turn
  through the agent, then shuts everything down. Safe to re-run: downloads resume.
.EXAMPLE
  ./scripts/preflight.ps1            # baseline model qwen3:1.7b (required)
  ./scripts/preflight.ps1 -With4b    # also qwen3:4b-instruct, the recommended tier (16 GB RAM)
#>
param([switch]$With4b, [switch]$With06b)

Set-Location (Join-Path $PSScriptRoot "..")
$Models = @("qwen3:1.7b")
if ($With4b) { $Models += "qwen3:4b-instruct" }
if ($With06b) { $Models += "qwen3:0.6b" }
$Profiles = @("--profile", "observability", "--profile", "state", "--profile", "tools")
$script:Failed = $false
function Ok($m)   { Write-Host "  OK   " -ForegroundColor Green -NoNewline; Write-Host $m }
function Bad($m)  { Write-Host "  FAIL " -ForegroundColor Red -NoNewline; Write-Host $m; $script:Failed = $true }
function Note($m) { Write-Host "  NOTE " -ForegroundColor Yellow -NoNewline; Write-Host $m }

Write-Host "Stack It Yourself - preflight`n"

Write-Host "[1/6] Container runtime"
docker info *> $null
if ($LASTEXITCODE -ne 0) { Bad "Docker is not running. Start Docker Desktop and run this again."; exit 1 }
Ok "Docker engine is running"
$composeV = (docker compose version --short 2>$null) -replace '^v', ''
if ($composeV -and ([version]($composeV -replace '[^0-9.].*$', '') -ge [version]"2.24.0")) { Ok "Docker Compose $composeV" }
else { Bad "Docker Compose $composeV - version 2.24 or newer is required. Update Docker Desktop." }

Write-Host "[2/6] Resources"
$memGb = [math]::Floor([double](docker info --format '{{.MemTotal}}') / 1GB)
if ($memGb -ge 6) { Ok "Docker can use $memGb GB of memory" }
else { Note "Docker can use only $memGb GB of memory. Give it at least 6 GB (Docker Desktop > Settings > Resources)." }
$drive = (Get-Item .).PSDrive
$freeGb = [math]::Floor($drive.Free / 1GB)
if ($freeGb -ge 10) { Ok "$freeGb GB free disk" } else { Bad "Only $freeGb GB free disk - at least 10 GB is needed." }

Write-Host "[3/6] Workshop configuration"
if (-not (Test-Path .env)) { Copy-Item env/step1.env .env; Ok "Created .env from env/step1.env" }
else { Ok ".env already exists (left untouched)" }
New-Item -ItemType Directory -Force -Path ollama-data | Out-Null

Write-Host "[4/6] Container images (the big download)"
$prefix = if ($env:IMAGE_PREFIX) { $env:IMAGE_PREFIX } else { "sit.local" }
docker compose @Profiles pull --ignore-buildable --quiet
if ($LASTEXITCODE -eq 0) { Ok "Pulled Grafana LGTM and Redis" } else { Bad "Could not pull Grafana LGTM / Redis - check your network and re-run." }
$pulled = $false
if ($prefix -ne "sit.local") { docker compose @Profiles pull --quiet agent mcp-server ollama 2>$null; $pulled = ($LASTEXITCODE -eq 0) }
if ($pulled) { Ok "Pulled prebuilt workshop images from $prefix" }
else {
  docker compose @Profiles build --quiet
  if ($LASTEXITCODE -eq 0) { Ok "Built workshop images locally (agent, MCP server, CPU-only Ollama)" } else { Bad "Image build failed - see the output above." }
}

Write-Host "[5/6] Model weights"
docker compose up -d --wait ollama *> $null
if ($LASTEXITCODE -ne 0) { Bad "Ollama did not start" }
foreach ($m in $Models) {
  Write-Host "  ...  downloading $m (progress below - safe to re-run if it stops)"
  docker compose exec -T ollama ollama pull $m
  if ($LASTEXITCODE -eq 0) { Ok "Model $m" } else { Bad "Could not download $m - re-run to resume." }
}

Write-Host "[6/6] Smoke test: one real chat turn through the agent"
docker compose up -d --wait agent *> $null
if ($LASTEXITCODE -eq 0) {
  try {
    $r = Invoke-RestMethod -Method Post -Uri http://localhost:8000/chat -ContentType "application/json" `
      -Body '{"message":"Reply with the single word: ready"}' -TimeoutSec 180
    if ($r.reply) { Ok "The agent answered - your laptop can run the workshop" } else { Bad "The agent returned no reply. Run: docker compose logs agent" }
  } catch { Bad "The agent did not answer. Run: docker compose logs agent" }
} else { Bad "The agent did not start. Run: docker compose logs agent" }
docker compose @Profiles down *> $null

Write-Host ""
if (-not $script:Failed) {
  Write-Host "All set - see you at the workshop!" -ForegroundColor Green -NoNewline
  Write-Host "  (Everything is downloaded; nothing is left running.)"
} else {
  Write-Host "Something needs attention - fix the FAIL lines above and run this again." -ForegroundColor Red
  Write-Host "Stuck? Open an issue on the workshop repo, or ask your workshop instructors."
  exit 1
}
