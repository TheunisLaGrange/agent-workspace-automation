<#
.SYNOPSIS
    System Integration Pipeline & Deployment Manager (Robust Regex Splicer)
.DESCRIPTION
    Reads active_project.json from 01_Automation_Scripts and integrates verified 
    app_sandbox.py core logic into the active project's main.py cleanly.
#>
$ErrorActionPreference = "Stop"

# 1. Load Active Workspace Context from JSON WIP Manifest
$WipStateFile = Join-Path -Path $PSScriptRoot -ChildPath "active_project.json"
if (-not (Test-Path -Path $WipStateFile)) {
    Write-Error "CRITICAL: active_project.json not found at $WipStateFile. Run generate_project.ps1 first."
    Exit 1
}

$Context        = Get-Content -Path $WipStateFile -Raw | ConvertFrom-Json
$TargetProject  = $Context.project_name
$SandboxFile    = $Context.sandbox_file      # Points to ...\sandbox\app_sandbox.py
$ProductionMain = $Context.production_main  # Points to ...\main.py

Write-Output "=============================================================="
Write-Output "🚀 Launching Production Integration Pipeline for: [$TargetProject]"
Write-Output "=============================================================="

# 2. Safety Guards: Verify asset integrity
if (-not (Test-Path -Path $SandboxFile)) { 
    Write-Error "CRITICAL: Verified sandbox core logic template not found at $SandboxFile."
    Exit 1
}
if (-not (Test-Path -Path $ProductionMain)) { 
    Write-Error "CRITICAL: Target main deployment file not found at $ProductionMain."
    Exit 1
}

# 3. Read raw text code strings natively
$AppSandboxContent = Get-Content -Path $SandboxFile -Raw
$MainContent       = Get-Content -Path $ProductionMain -Raw

# 4. Extract verified algorithm logic from sandbox template anchors
Write-Output "⚙️ Extracting data capturing matrix from app_sandbox.py..."
$SandboxRegex = "(?s)# >>> START SANDBOX LOGIC >>>.*?# <<< END SANDBOX LOGIC <<<"

if (-not ($AppSandboxContent -match $SandboxRegex)) {
    Write-Error "CRITICAL FAILURE: Could not locate verified block tags (# >>> START SANDBOX LOGIC >>>) within app_sandbox.py"
    Exit 1
}
$VerifiedCoreLogic = $Matches[0]

# 5. Execute production splice using robust string regex operations
Write-Output "⚙️ Splicing sandbox core directly into integration zone..."
$MainPattern = "(?s)# >>> START CORE LOGIC >>>.*?# <<< END CORE LOGIC <<<"

if (-not ($MainContent -match $MainPattern)) {
    Write-Error "CRITICAL FAILURE: Integration tags (# >>> START CORE LOGIC >>>) missing from target $ProductionMain."
    Exit 1
}

# Wrap core extraction logic into production anchor blocks safely
$ReplacementBlock = "# >>> START CORE LOGIC >>>`n$VerifiedCoreLogic`n# <<< END CORE LOGIC <<<"
$IntegratedContent = [regex]::Replace($MainContent, $MainPattern, $ReplacementBlock)

# 6. Safety Backup Layer
Copy-Item -Path $ProductionMain -Destination "$ProductionMain.bak" -Force
Write-Output "💾 Checkpoint saved: Pre-existing main.py backed up to main.py.bak"

# 7. Flush structural update back to project production core
Set-Content -Path $ProductionMain -Value $IntegratedContent -Force

# 8. Automated Compilation Check
Write-Output "🔍 Running syntax validation on integrated environment..."
$CompileResult = python -m py_compile $ProductionMain 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Output "✅ SUCCESS: Workspace [$TargetProject\main.py] updated and compiled cleanly!"
} else {
    Write-Warning "⚠️ Splicing finished, but Python compiler caught syntax trace errors: $CompileResult"
}
Write-Output "=============================================================="
