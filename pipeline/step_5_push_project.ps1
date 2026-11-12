<#
.SYNOPSIS
    DevOps Deployment Engine: Step 5 Final Git Repository Synchronization.
    Dynamically binds remotes using parameters verified in active_project.json.
#>
$ErrorActionPreference = "Stop"

# 1. Ingest workspace context configuration parameters safely
$ManifestFile = Join-Path $PSScriptRoot "active_project.json"
if (-not (Test-Path $ManifestFile)) {
    Write-Error "CRITICAL: active_project.json configuration manifest is missing at: $ManifestFile"
    Exit 1
}

$Context = Get-Content $ManifestFile -Raw | ConvertFrom-Json
$ProjectRoot = $Context.project_root

# Extract the fully qualified URL variable directly from your metadata manifest
$RepoUrl = $Context.github_url

Write-Host "==============================================================" -ForegroundColor DarkCyan
Write-Host "🚀 DEPLOYING TARGET SOURCE MATRICES TO GITHUB LIVE REPOSITORY " -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor DarkCyan
Write-Host "Workspace Root  : $ProjectRoot" -ForegroundColor Cyan

# 🌟 TARGET VERIFICATION PRINTER (Prints the exact repository target address)
Write-Host "Target Git URL  : $RepoUrl" -ForegroundColor Yellow

Write-Host "==============================================================" -ForegroundColor DarkCyan

Set-Location -Path $ProjectRoot

# 2. Local Repository Initialization Gateway
if (-not (Test-Path (Join-Path $ProjectRoot ".git"))) {
    Write-Host "🔹 Initializing fresh git index tracking matrix..." -ForegroundColor Yellow
    git init -b main
}

# 3. Securely apply remote target definitions dynamically and overwrite stale markers
$ExistingRemotes = git remote -v
if ($ExistingRemotes -match "origin") {
    # Force set-url explicitly to wipe out any previously corrupted tracking strings
    git remote set-url origin $RepoUrl
} else {
    git remote add origin $RepoUrl
}

# 4. Phase Commit & Push Sequence
Write-Host "🔹 Compiling staging assets..." -ForegroundColor Yellow
git add .

# Clear residual test scripts and build folders out of staging safely
git rm --cached --ignore-unmatch sandbox/sandbox.py 2>$null
git rm -r --cached --ignore-unmatch Release_Build build_nuitka_temp 03_CSharp_GUI/bin 03_CSharp_GUI/obj 2>$null

$CommitMsg = Read-Host -Prompt "Enter Git commit message (Press Enter for default)"
if ([string]::IsNullOrWhiteSpace($CommitMsg)) {
    $CommitMsg = "feat(StrataRisk): deploy decoupled Python backend and C# GUI"
}

git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    git commit -m $CommitMsg
    Write-Host "✅ Commit recorded: $CommitMsg" -ForegroundColor Green
} else {
    Write-Host "ℹ️ No new staged changes to commit." -ForegroundColor Cyan
}


# 5. Execute Upstream Branch Synchronization Transport Loop
Write-Host "⚡ Transporting package layers to main production vector..." -ForegroundColor Green
git push -u origin main --force

Write-Host "`n==============================================================" -ForegroundColor DarkCyan
Write-Host "🎉 GIT DEPLOYMENT RUNTIME LIFECYCLE COMPLETED SUCCESSFULLY   " -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor DarkCyan
