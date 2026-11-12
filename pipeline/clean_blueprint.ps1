# clean_blueprint.ps1
# Strips project-specific artifacts from long-horizon-agent-blueprint to maintain a clean master template.

$ErrorActionPreference = "Stop"

$BlueprintRoot = "C:\PC Programming\Python\src\AI\Agent\02_Python_Source\long-horizon-agent-blueprint"

if (-not (Test-Path $BlueprintRoot)) {
    Write-Error "[HANDSHAKE FAILED] Blueprint directory not found: $BlueprintRoot"
    exit 1
}

Write-Host "=== STARTING BLUEPRINT CLEANUP ===" -ForegroundColor Cyan
Write-Host "Target: $BlueprintRoot`n"

# 1. Specific files to strip (CV-generator leftovers, caches, and ad-hoc test files)
$FilesToRemove = @(
    "input_profile.json",
    "target.json",
    "target_criteria.txt",
    "test_connection.py",
    ".data_cache\my_cache.json",
    "src\core\workers\compiler.py",
    "src\core\workers\extractor.py",
    "src\core\workers\optimizer.py"
)

# 2. Specific directories to strip completely (if empty or obsolete)
$DirsToRemove = @(
    "src\core\workers"
)

$RemovedCount = 0
$MissingCount = 0

# Remove targeted files
foreach ($RelPath in $FilesToRemove) {
    $FullPath = Join-Path $BlueprintRoot $RelPath
    if (Test-Path $FullPath) {
        Remove-Item -Path $FullPath -Force
        Write-Host "[REMOVED FILE] $RelPath" -ForegroundColor Green
        $RemovedCount++
    } else {
        Write-Host "[ALREADY CLEAN] $RelPath" -ForegroundColor DarkGray
        $MissingCount++
    }
}

# Remove targeted directories
foreach ($RelDir in $DirsToRemove) {
    $FullDir = Join-Path $BlueprintRoot $RelDir
    if (Test-Path $FullDir) {
        Remove-Item -Path $FullDir -Recurse -Force
        Write-Host "[REMOVED DIR]  $RelDir\" -ForegroundColor Green
        $RemovedCount++
    }
}

# 3. Purge all __pycache__ folders and .pyc files across the blueprint
$PyCaches = Get-ChildItem -Path $BlueprintRoot -Include "__pycache__", "*.pyc" -Recurse -Force -ErrorAction SilentlyContinue
foreach ($CacheItem in $PyCaches) {
    Remove-Item -Path $CacheItem.FullName -Recurse -Force
    Write-Host "[PURGED CACHE] $($CacheItem.FullName.Replace($BlueprintRoot, ''))" -ForegroundColor Yellow
    $RemovedCount++
}

# 4. Ensure required structural directories exist (even when empty)
$RequiredDirs = @(
    ".data_cache",
    "Output",
    "User_Data",
    "Sample_User_Data",
    "sandbox",
    "config",
    "src\core",
    "src\diagnostics"
)

foreach ($ReqDir in $RequiredDirs) {
    $FullReqDir = Join-Path $BlueprintRoot $ReqDir
    if (-not (Test-Path $FullReqDir)) {
        New-Item -ItemType Directory -Path $FullReqDir -Force | Out-Null
        Write-Host "[CREATED DIR]  $ReqDir\" -ForegroundColor Cyan
    }
}

Write-Host "`n=== HANDSHAKE OK: Blueprint Cleaned ($RemovedCount items removed) ===" -ForegroundColor Cyan
