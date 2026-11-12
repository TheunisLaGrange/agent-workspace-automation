<#
.SYNOPSIS
    Master Blueprint Synchronization Engine (JSON WIP Context Driven)
.DESCRIPTION
    Reads active_project.json and safely synchronizes core engine updates
    back into long-horizon-agent-blueprint while excluding bytecode.
#>
$ErrorActionPreference = "Stop"

# 1. Load Active Workspace Context from JSON WIP Manifest
$WipStateFile = Join-Path -Path $PSScriptRoot -ChildPath "active_project.json"
if (-not (Test-Path -Path $WipStateFile)) {
    Write-Error "CRITICAL: active_project.json not found at $WipStateFile. Run generate_project.ps1 first."
    Exit 1
}

$Context       = Get-Content -Path $WipStateFile -Raw | ConvertFrom-Json
$ProjectName   = $Context.project_name
$AppRoot       = $Context.project_root
$BlueprintRoot = Join-Path -Path $Context.base_dir -ChildPath "long-horizon-agent-blueprint"

if (-not (Test-Path -Path $BlueprintRoot)) {
    Write-Error "CRITICAL: Master blueprint directory not found at $BlueprintRoot"
    Exit 1
}

Write-Output "🔄 Syncing core updates from [$ProjectName] back to master blueprint..."

# 2. Synchronize central orchestrator script
Copy-Item -Path (Join-Path -Path $AppRoot -ChildPath "src\core\llm_service.py") `
          -Destination (Join-Path -Path $BlueprintRoot -ChildPath "src\core\llm_service.py") -Force

# 3. Synchronize worker modules while excluding bytecode
$WorkersSrc  = Join-Path -Path $AppRoot -ChildPath "src\core\workers"
$WorkersDest = Join-Path -Path $BlueprintRoot -ChildPath "src\core\workers"

Get-ChildItem -Path $WorkersSrc -File | Where-Object { $_.Extension -ne ".pyc" } | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $WorkersDest -Force
}

# 4. Update Master Configuration Blueprint
Copy-Item -Path (Join-Path -Path $AppRoot -ChildPath "config\agent_config.yaml") `
          -Destination (Join-Path -Path $BlueprintRoot -ChildPath "config\agent_config.yaml") -Force

Write-Output "✅ Master Blueprint synchronized safely from [$ProjectName]!"
