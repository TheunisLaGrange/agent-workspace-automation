$ErrorActionPreference = "Stop"

# Resolve paths relative to repo root (one level up from github_audit\)
$repoRoot   = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot "config\workspace_config.json"

if (-not (Test-Path $configPath)) {
    Write-Error "Missing workspace_config.json at $configPath"
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Resolve GitHub Token
$token = $config.github.token
if ([string]::IsNullOrWhiteSpace($token) -or $token -eq "YOUR_GITHUB_PAT_HERE") {
    $token = $env:GITHUB_TOKEN
}
if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Error "No GitHub token found in config/workspace_config.json or `$env:GITHUB_TOKEN."
    exit 1
}

# Verify local template LICENSE exists
$templateLicensePath = Join-Path $config.paths.template_dir "LICENSE"
if (-not (Test-Path $templateLicensePath)) {
    Write-Error "Template LICENSE not found at $templateLicensePath"
    exit 1
}

# Load temp\repos.json
$tempDir   = Join-Path $repoRoot $config.paths.temp_dir
$reposPath = Join-Path $tempDir "repos.json"
if (-not (Test-Path $reposPath)) {
    Write-Error "repos.json not found at $reposPath. Run 1_fetch_repos.ps1 first."
    exit 1
}
$repos = Get-Content $reposPath -Raw | ConvertFrom-Json

# Build API base safely
$domain  = @("api", "github", "com") -join "."
$apiBase = "https://$domain"
$owner   = $config.github.username

$headers = @{
    "User-Agent"           = "PowerShell-License-Sync"
    "Accept"               = "application/vnd.github+json"
    "Authorization"        = "Bearer $token"
    "X-GitHub-Api-Version" = "2022-11-28"
}

# Read and stamp the local template
$currentYear    = (Get-Date).Year.ToString()
$rawLicense     = Get-Content $templateLicensePath -Raw
$stampedLicense = $rawLicense `
    -replace '\[year\]|<YEAR>|\{\{year\}\}', $currentYear `
    -replace '\[fullname\]|<COPYRIGHT_HOLDER>|\{\{author\}\}', $config.github.copyright_holder

$licenseBytes  = [System.Text.Encoding]::UTF8.GetBytes($stampedLicense)
$base64Content = [Convert]::ToBase64String($licenseBytes)

Write-Host "[INFO] Scanning $($repos.Count) repositories for LICENSE..." -ForegroundColor Cyan

foreach ($repo in $repos) {
    $repoName         = $repo.name
    $licenseEndpoint  = "$apiBase/repos/$owner/$repoName/license"
    $contentsEndpoint = "$apiBase/repos/$owner/$repoName/contents/LICENSE"

    Write-Host "`n[CHECK] $repoName" -ForegroundColor Yellow

    try {
        $existingLicense = Invoke-RestMethod -Uri $licenseEndpoint -Headers $headers -Method Get -ErrorAction Stop
        Write-Host "  [OK] License already exists ($($existingLicense.license.spdx_id)). Skipping." -ForegroundColor Green
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404) {
            Write-Host "  [MISSING] No LICENSE found. Stamping and pushing..." -ForegroundColor Magenta

            $payload = @{
                message = "docs: add stamped MIT LICENSE file from project template"
                content = $base64Content
            } | ConvertTo-Json

            try {
                $pushResult = Invoke-RestMethod -Uri $contentsEndpoint -Headers $headers -Method Put -Body $payload -ContentType "application/json" -ErrorAction Stop
                Write-Host "  [PUSHED] Successfully added LICENSE (Commit: $($pushResult.commit.sha.Substring(0,7)))" -ForegroundColor Green
            }
            catch {
                Write-Host "  [ERROR] Failed to push LICENSE to $repoName : $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        else {
            Write-Host "  [ERROR] Unexpected API error ($statusCode) checking $repoName : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`n[DONE] License audit and sync complete." -ForegroundColor Cyan
