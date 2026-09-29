<#
.SYNOPSIS
  Stack It Yourself - the hosted fallback on Azure AI Foundry (managed compute).
.DESCRIPTION
  Deploys Qwen3-4B-Instruct-2507 - the same model as the workshop's recommended local tier - on one
  NVIDIA A100 80GB in your Foundry resource. Attendees whose laptops can't run the local model point
  env/hosted.env at it and do every exercise unchanged. It serves both Chat Completions and the
  Responses API on https://<resource>.openai.azure.com/openai/v1/.

  Managed compute bills per GPU-hour for as long as the deployment exists (about USD 3.95/hour
  for one A100 80GB when this was written), whether or not anyone calls it. Run "up" shortly before
  the session - provisioning takes 15-20 minutes - and "down" straight after.

  Needs: Azure CLI logged in to the subscription that holds the Foundry resource, and
  Cognitive Services Contributor (or Owner) on that resource.
.EXAMPLE
  ./scripts/hosted-fallback.ps1 up     -Account my-foundry -ResourceGroup my-rg   # 15-20 minutes
  ./scripts/hosted-fallback.ps1 status -Account my-foundry -ResourceGroup my-rg
  ./scripts/hosted-fallback.ps1 env    -Account my-foundry -ResourceGroup my-rg   # writes env/hosted.env (git-ignored)
  ./scripts/hosted-fallback.ps1 down   -Account my-foundry -ResourceGroup my-rg   # deletes it - billing stops
#>
param(
  [Parameter(Mandatory, Position = 0)][ValidateSet("up", "status", "env", "down")][string]$Command,
  [Parameter(Mandatory)][string]$Account,
  [Parameter(Mandatory)][string]$ResourceGroup,
  [string]$Subscription,
  [string]$Deployment = "qwen3-4b-instruct"
)
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$Model = "azureml://registries/azure-huggingface/models/qwen--qwen3-4b-instruct-2507/versions/3"
$Template = "azureml://registries/azure-huggingface/deploymenttemplates/qwen--qwen3-4b-instruct-2507--256k-nvidia-a100/labels/latest"
$Accelerator = "A100_80GB"
$Api = "2026-09-01"

if (-not $Subscription) { $Subscription = az account show --query id -o tsv; if (-not $Subscription) { throw "Run 'az login' first." } }
$acctPath = "/subscriptions/$Subscription/resourceGroups/$ResourceGroup/providers/Microsoft.CognitiveServices/accounts/$Account"
$depUrl = "https://management.azure.com$acctPath/managedComputeDeployments/${Deployment}?api-version=$Api"

function Get-Deployment {
  $r = az rest --method get --url $depUrl -o json 2>$null
  if ($LASTEXITCODE -ne 0) { return $null }
  return $r | ConvertFrom-Json
}
function Get-BaseUrl {
  $sub = az cognitiveservices account show -n $Account -g $ResourceGroup --subscription $Subscription --query properties.customSubDomainName -o tsv
  return "https://$sub.openai.azure.com/openai/v1/"
}

switch ($Command) {
  "up" {
    $existing = Get-Deployment
    if ($existing) { Write-Host "Deployment '$Deployment' already exists ($($existing.properties.provisioningState))." }
    else {
      Write-Host "Creating '$Deployment' on 1x $Accelerator in $Account - billing starts now (about USD 3.95/hour)."
      $body = @{
        sku = @{ name = "GlobalManagedCompute"; capacity = 1 }
        properties = @{ model = $Model; deploymentTemplate = $Template; acceleratorType = $Accelerator; versionUpgradeOption = "NoAutoUpgrade" }
      } | ConvertTo-Json -Depth 5
      $bodyFile = Join-Path ([IO.Path]::GetTempPath()) "sit-hosted-fallback.json"
      [IO.File]::WriteAllText($bodyFile, $body)
      az rest --method put --url $depUrl --body "@$bodyFile" --headers "Content-Type=application/json" -o none
      if ($LASTEXITCODE -ne 0) { throw "Create failed - see the error above." }
      Remove-Item $bodyFile -ErrorAction SilentlyContinue
    }
    $start = Get-Date
    do {
      Start-Sleep -Seconds 30
      $d = Get-Deployment; $state = $d.properties.provisioningState
      Write-Host ("  {0,5:N1} min  {1}" -f ((Get-Date) - $start).TotalMinutes, $state)
    } while ($state -notin "Succeeded", "Failed", "Canceled")
    if ($state -ne "Succeeded") { throw "Provisioning ended in state '$state'." }
    Write-Host ""
    Write-Host "Ready. Base URL: $(Get-BaseUrl)   model: $Deployment"
    Write-Host "Next: ./scripts/hosted-fallback.ps1 env ... to test it, and remember 'down' afterwards."
  }
  "status" {
    $d = Get-Deployment
    if (-not $d) { Write-Host "No deployment '$Deployment' - nothing is billing."; break }
    $p = $d.properties
    Write-Host "$Deployment : $($p.provisioningState) - $($p.totalAccelerators)x $($p.acceleratorType), created $($d.systemData.createdAt) (billing while it exists)"
    Write-Host "Base URL: $(Get-BaseUrl)   model: $Deployment"
  }
  "env" {
    $d = Get-Deployment
    if (-not $d -or $d.properties.provisioningState -ne "Succeeded") { throw "Deployment '$Deployment' isn't ready - run 'up' first." }
    $key = az cognitiveservices account keys list -n $Account -g $ResourceGroup --subscription $Subscription --query key1 -o tsv
    $lines = @(
      "# Written by scripts/hosted-fallback.ps1 - git-ignored, never commit it.",
      "MODEL=openai-chat:$Deployment",
      "OPENAI_BASE_URL=$(Get-BaseUrl)",
      "OPENAI_API_KEY=$key",
      "REASONING=default"
    )
    [IO.File]::WriteAllText((Join-Path (Get-Location) "env/hosted.env"), ($lines -join "`n") + "`n")
    Write-Host "Wrote env/hosted.env. Run 'docker compose up -d' and the agent uses the hosted model."
    Write-Host "Delete env/hosted.env to go back to local inference."
  }
  "down" {
    if (-not (Get-Deployment)) { Write-Host "No deployment '$Deployment' - nothing to delete."; break }
    Write-Host "Deleting '$Deployment'..."
    az rest --method delete --url $depUrl -o none
    do { Start-Sleep -Seconds 20 } while (Get-Deployment)
    Write-Host "Deleted - billing has stopped."
    Write-Host "If keys were handed out, rotate them: az cognitiveservices account keys regenerate -n $Account -g $ResourceGroup --key-name key1"
  }
}
