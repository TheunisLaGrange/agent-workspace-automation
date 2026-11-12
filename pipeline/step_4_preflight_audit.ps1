<#
.SYNOPSIS
    DevOps Lifecycle Script: Step 4 Pre-Flight Architectural Audit.
    Runs the workspace auditor to clean up and refactor documentation 
    prior to executing an upstream GitHub deployment push.
#>
$ErrorActionPreference = "Stop"

# 1. Establish absolute file path references from the active project status context
$ActiveProjectCfg = Join-Path $PSScriptRoot "active_project.json"
if (-not (Test-Path $ActiveProjectCfg)) {
    Write-Error "CRITICAL: Active workspace context configuration file is missing at: $ActiveProjectCfg"
}

$WorkspaceState = Get-Content $ActiveProjectCfg | ConvertFrom-Json
$ProjectName = $WorkspaceState.project_name
$ProjectRoot = "C:\PC Programming\Python\src\AI\Agent\02_Python_Source\$ProjectName"
$AuditorScript = Join-Path $ProjectRoot "src\diagnostics\project_auditor.py"

Write-Host "==============================================================" -ForegroundColor DarkCyan
Write-Host "🔍 RUNNING PRE-FLIGHT REPOSITORY ARCHITECTURE AUDITOR        " -ForegroundColor Yellow
Write-Host "==============================================================" -ForegroundColor DarkCyan
Write-Host "Target Active Workspace: $ProjectName" -ForegroundColor Cyan

# 2. Guard validation check: Confirm the Python auditor module exists
if (-not (Test-Path $AuditorScript)) {
    Write-Error "CRITICAL: Python auditor module missing at target directory: $AuditorScript"
}

# 3. Step into the active workspace and execute the Python analysis runtime natively
Write-Host "🔹 Scanning file trees and extracting dependencies..." -ForegroundColor Yellow
Push-Location -Path $ProjectRoot
try {
    & python "src/diagnostics/project_auditor.py"
    Write-Host "`n✅ Success: README.md has been refactored with the verified directory map." -ForegroundColor Green
} catch {
    Write-Error "Auditor execution runtime failure: $_"
} finally {
    Pop-Location
}

Write-Host "==============================================================" -ForegroundColor DarkCyan
