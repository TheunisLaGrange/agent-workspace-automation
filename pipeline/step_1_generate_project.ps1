# =====================================================================
# AUTOMATED PROJECT GENERATOR SYSTEM (v3.5 - LEAN TEMPLATE ENGINE)
# =====================================================================
$ErrorActionPreference = "Stop"

$AgentRoot       = "C:\PC Programming\Python\src\AI\Agent"
$ScriptsDir      = Join-Path $AgentRoot "01_Automation_Scripts"
$BaseDir         = Join-Path $AgentRoot "02_Python_Source"
$LibraryRoot     = Join-Path $AgentRoot "03_Shared_Libraries"
$BoilerplateRoot = Join-Path $BaseDir "project_template"
$WipStateFile    = Join-Path $ScriptsDir "active_project.json"
$GitHubUser      = "TheunisLaGrange"
$CopyrightHolder = "Theunis La Grange"
$CurrentYear     = (Get-Date).Year

if (-not (Test-Path $BoilerplateRoot)) {
    Write-Error "[HANDSHAKE FAILED] Template folder missing: $BoilerplateRoot"
    Exit 1
}

$ProjectName = (Read-Host "Enter the Project Name").Trim()
if ([string]::IsNullOrEmpty($ProjectName)) {
    Write-Error "[HANDSHAKE FAILED] Project Name cannot be blank."
    Exit 1
}

Write-Output "`nSelect Architecture: [1] Blank  [2] Core  [3] Data Pipeline"
switch ((Read-Host "Enter choice (1, 2, or 3)").Trim()) {
    "1" { $SelectedModule = "blank" }
    "2" { $SelectedModule = "core" }
    "3" { $SelectedModule = "data_pipeline" }
    Default { Write-Error "[HANDSHAKE FAILED] Invalid selection."; Exit 1 }
}

$TargetWorkspace = Join-Path $BaseDir $ProjectName
$RepoUrl         = "https://github.com" + "/$GitHubUser/$ProjectName"

function Copy-CleanDirectory {
    param ([string]$SourcePath, [string]$DestinationPath)
    if (-not (Test-Path $SourcePath)) {
        Write-Error "[HANDSHAKE FAILED] Missing source: $SourcePath"
        Exit 1
    }
    Copy-Item -Path $SourcePath -Destination $DestinationPath -Recurse -Force
    Get-ChildItem -Path $DestinationPath -Include "__pycache__", "*.pyc" -Recurse -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force
}

# PHASE 1: Clone project_template & inject shared library modules
if (-not (Test-Path $TargetWorkspace)) {
    Copy-CleanDirectory -SourcePath $BoilerplateRoot -DestinationPath $TargetWorkspace

    foreach ($Dir in @("data\cache", "data\input", "data\output", "diagnostics", "src")) {
        New-Item -ItemType Directory -Path (Join-Path $TargetWorkspace $Dir) -Force | Out-Null
    }

    # Sync shared diagnostics if present in 03_Shared_Libraries
    $LibDiag = @( (Join-Path $LibraryRoot "diagnostics"), (Join-Path $LibraryRoot "src\diagnostics") ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($LibDiag) {
        Get-ChildItem -Path $LibDiag -Filter "*.py" -File | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination (Join-Path $TargetWorkspace "diagnostics\$($_.Name)") -Force
        }
    }

    # Inject optional module (core or data_pipeline)
    if ($SelectedModule -ne "blank") {
        $LibMod = @( (Join-Path $LibraryRoot "src\$SelectedModule"), (Join-Path $LibraryRoot $SelectedModule) ) | Where-Object { Test-Path $_ } | Select-Object -First 1
        Copy-CleanDirectory -SourcePath $LibMod -DestinationPath (Join-Path $TargetWorkspace "src\$SelectedModule")
        Write-Output "[OK] Injected '$SelectedModule' from 03_Shared_Libraries."
    }
}

# PHASE 2: Stamp LICENSE & README.md in-place (zero text bloat)
$LicensePath = Join-Path $TargetWorkspace "LICENSE"
if (Test-Path $LicensePath) {
    $Lic = (Get-Content $LicensePath -Raw) -replace '\[YEAR\]|\b20\d{2}\b', $CurrentYear -replace '\[COPYRIGHT_HOLDER\]|<copyright holders>', $CopyrightHolder
    Set-Content -Path $LicensePath -Value $Lic.Trim() -Encoding UTF8
    Write-Output "[OK] Stamped LICENSE ($CurrentYear $CopyrightHolder)."
}

$ReadmePath = Join-Path $TargetWorkspace "README.md"
if (Test-Path $ReadmePath) {
    $Readme = (Get-Content $ReadmePath -Raw) -replace '\[PROJECT_NAME\]|project_template', $ProjectName -replace '\[REPO_URL\]', $RepoUrl
    Set-Content -Path $ReadmePath -Value $Readme.Trim() -Encoding UTF8
    Write-Output "[OK] Updated README.md."
}

# PHASE 3: Save active_project.json manifest & run smoke test
$WipState = [ordered]@{
    project_name    = $ProjectName
    architecture    = $SelectedModule
    base_dir        = $BaseDir
    project_root    = $TargetWorkspace
    input_dir       = Join-Path $TargetWorkspace "data\input"
    output_dir      = Join-Path $TargetWorkspace "data\output"
    cache_dir       = Join-Path $TargetWorkspace "data\cache"
    production_main = Join-Path $TargetWorkspace "main.py"
    github_url      = $RepoUrl
    last_updated    = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}
$WipState | ConvertTo-Json -Depth 3 | Set-Content -Path $WipStateFile -Encoding UTF8

Push-Location $TargetWorkspace
try {
    $TestRun = Start-Process -FilePath "python" -ArgumentList "main.py" -NoNewWindow -Wait -PassThru
    Write-Output "[HANDSHAKE] Smoke test exit code: $($TestRun.ExitCode)"
} finally {
    Pop-Location
}
