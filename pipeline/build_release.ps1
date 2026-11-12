# build_release.ps1
# Builds completely standalone Python Backend EXE and C# GUI EXE decoupled via Shared_Data CSV bridge

$ErrorActionPreference = "Stop"

$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$WipStateFile = Join-Path $ScriptDir "active_project.json"
$PythonExe    = "C:\Users\User\AppData\Local\Programs\Python\Python312\python.exe"

# Resolve active project root dynamically from active_project.json
if (Test-Path $WipStateFile) {
    $WipState      = Get-Content $WipStateFile -Raw | ConvertFrom-Json
    $WorkspaceRoot = $WipState.project_root
    $ProjectName   = $WipState.project_name
} else {
    $WorkspaceRoot = "C:\PC Programming\Python\src\AI\Agent\02_Python_Source\StrataRisk"
    $ProjectName   = "StrataRisk"
}

$PythonDir       = Join-Path $WorkspaceRoot "02_Python_Backend"
$CSharpDir       = Join-Path $WorkspaceRoot "03_CSharp_GUI"
$ReleaseRoot     = Join-Path $WorkspaceRoot "Release_Build"
$NuitkaBuildTemp = Join-Path $WorkspaceRoot "build_nuitka_temp"

# Validate required source directories before building
if (-not (Test-Path $PythonDir)) {
    Write-Error "[HANDSHAKE FAILED] Python backend directory not found: $PythonDir"
    exit 1
}
if (-not (Test-Path $CSharpDir)) {
    Write-Error "[HANDSHAKE FAILED] C# GUI directory not found: $CSharpDir"
    exit 1
}

Write-Host "=== BUILDING DECOUPLED STANDALONE RELEASE ($ProjectName) ===" -ForegroundColor Cyan
Write-Host "Workspace: $WorkspaceRoot"

# 0. Clean previous Release_Build & crashed Nuitka artifacts
if (Test-Path $ReleaseRoot) { Remove-Item $ReleaseRoot -Recurse -Force }
$CrashReport = Join-Path $PythonDir "nuitka-crash-report.xml"
if (Test-Path $CrashReport) { Remove-Item $CrashReport -Force }

$BackendOut = Join-Path $ReleaseRoot "Backend_Engine"
$GuiOut     = Join-Path $ReleaseRoot "GUI_App"
$SharedData = Join-Path $ReleaseRoot "Shared_Data"

New-Item -ItemType Directory -Path $BackendOut, $GuiOut, "$SharedData\config", "$SharedData\input", "$SharedData\output" -Force | Out-Null

# 1. Build Standalone Python Backend (Nuitka)
Write-Host "`n[1/3] Compiling Standalone Python Backend ($ProjectName.Engine.exe)..." -ForegroundColor Yellow
Push-Location $PythonDir
try {
    $NuitkaArgs = @(
        "-m", "nuitka",
        "--standalone",
        "--assume-yes-for-downloads",
        "--show-progress",
        "--low-memory",
        "--jobs=2",
        "--output-dir=$NuitkaBuildTemp",
        "--output-filename=$ProjectName.Engine.exe",
        "--include-package=data_import",
        "--include-package=processing",
        "--include-package=exporting",
        "--include-package=diagnostics",
        "--noinclude-pytest-mode=nofollow",
        "--noinclude-setuptools-mode=nofollow",
        "main.py"
    )

    & $PythonExe @NuitkaArgs
    if ($LASTEXITCODE -ne 0) { throw "Nuitka compilation failed (Exit Code: $LASTEXITCODE)." }

    $DistFolder = Join-Path $NuitkaBuildTemp "main.dist"
    Copy-Item -Path "$DistFolder\*" -Destination $BackendOut -Recurse -Force
    Write-Host "[HANDSHAKE OK] Python Backend deployed to $BackendOut" -ForegroundColor Green
}
finally {
    Pop-Location
}

# 2. Build Standalone C# WPF GUI (.NET 10)
Write-Host "`n[2/3] Publishing Standalone C# GUI ($ProjectName.GUI.exe)..." -ForegroundColor Yellow
Push-Location $CSharpDir
try {
    dotnet publish "$ProjectName.GUI.csproj" `
        -c Release `
        -r win-x64 `
        --self-contained true `
        -p:PublishSingleFile=true `
        -p:DebugType=None `
        -p:DebugSymbols=false `
        -o $GuiOut

    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed (Exit Code: $LASTEXITCODE)." }
    Write-Host "[HANDSHAKE OK] C# GUI deployed to $GuiOut" -ForegroundColor Green
}
finally {
    Pop-Location
}

# 3. Initialize Clean Shared_Data Bridge Contract
Write-Host "`n[3/3] Initializing Clean CSV Bridge Directory..." -ForegroundColor Yellow
$TargetConfig = Join-Path $PythonDir "config\target.json"
if (Test-Path $TargetConfig) {
    Copy-Item -Path $TargetConfig -Destination "$SharedData\config\target.json" -Force
}

Write-Host "`n=== RELEASE BUILD COMPLETE ===" -ForegroundColor Cyan
Write-Host "Backend EXE: $BackendOut\$ProjectName.Engine.exe"
Write-Host "GUI EXE:     $GuiOut\$ProjectName.GUI.exe"
Write-Host "CSV Bridge:  $SharedData\output\latest_screening_results.csv"
