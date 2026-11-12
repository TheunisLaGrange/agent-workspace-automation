<#
.SYNOPSIS
    DevOps Lifecycle Script: Step 2 Initial Test Code Integration.
    Injects custom processing logic from sandbox.py into the app_sandbox.py master template.
#>
# Enforce explicit handshaking variables and stop instantly on errors
$ErrorActionPreference = "Stop"

# 1. Establish absolute file path references from the active project status context
$ActiveProjectCfg = Join-Path $PSScriptRoot "active_project.json"
if (-not (Test-Path $ActiveProjectCfg)) {
    Write-Error "CRITICAL: Active workspace context configuration file is missing at: $ActiveProjectCfg"
}

$WorkspaceState = Get-Content $ActiveProjectCfg | ConvertFrom-Json
$ProjectName = $WorkspaceState.project_name
$ProjectRoot = "C:\PC Programming\Python\src\AI\Agent\02_Python_Source\$ProjectName"

$SandboxLogicFile = Join-Path $ProjectRoot "sandbox\sandbox.py"
$AppSandboxTemplate = Join-Path $ProjectRoot "sandbox\app_sandbox.py"

Write-Host "==============================================================" -ForegroundColor DarkCyan
Write-Host "🔬 INITIALIZING LOCAL SANDBOX LAYER DYNAMIC SPLICE ENGINE     " -ForegroundColor Yellow
Write-Host "==============================================================" -ForegroundColor DarkCyan
Write-Host "Target Active Project: $ProjectName" -ForegroundColor Cyan

# 2. Guard validation check: Verify both code tokens exist
if (-not (Test-Path $SandboxLogicFile)) {
    Write-Error "Missing business component input tracking file: $SandboxLogicFile"
}
if (-not (Test-Path $AppSandboxTemplate)) {
    Write-Error "Missing master framework staging template: $AppSandboxTemplate"
}

# ... Previous script setup logic remains unchanged ...
# 3. Safely extract and slice code block allocations cleanly
Write-Host "🔹 Reading project logic from sandbox.py..." -ForegroundColor Yellow
$RawLogic = Get-Content $SandboxLogicFile -Raw

if ($RawLogic -match "(?s)# >>> START SANDBOX LOGIC >>>.*?# <<< END SANDBOX LOGIC <<<") {
    # 🌟 FIX: Target index 0 to capture the complete text payload including markers
    $ExtractedCode = $Matches[0]
    
    Write-Host "🔹 Injecting component logic matrices into app_sandbox.py harness..." -ForegroundColor Yellow
    $TemplateContent = Get-Content $AppSandboxTemplate -Raw
    
    # Target precise template anchor markers safely using regex matches
    $Pattern = "(?s)# >>> INJECTED LOGIC BOILERPLATE START >>>.*?# >>> INJECTED LOGIC BOILERPLATE END >>>"
    $Replacement = "# >>> INJECTED LOGIC BOILERPLATE START >>>`n$ExtractedCode`n# >>> INJECTED LOGIC BOILERPLATE END >>>"
    
    $UpdatedTemplate = [regex]::Replace($TemplateContent, $Pattern, $Replacement)
    Set-Content $AppSandboxTemplate $UpdatedTemplate -Encoding UTF8
    
# ... Remaining compiler compilation loops remain unchanged ... 
    # 4. Functional verification handshake step via a quick python syntax compile check
    Write-Host "🔹 Executing compiler validation smoke check..." -ForegroundColor Yellow
    $CompileCheck = python -m py_compile $AppSandboxTemplate 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Success: Sandbox logic injected and successfully compiled with zero syntax errors." -ForegroundColor Green
    } else {
        Write-Error "CRITICAL: Compiled syntax check failed. Code has structural anomalies: $CompileCheck"
    }
} else {
    Write-Error "Failed to locate expected demarcation tags: (# >>> START SANDBOX LOGIC >>>) inside sandbox.py"
}

Write-Host "==============================================================" -ForegroundColor DarkCyan
