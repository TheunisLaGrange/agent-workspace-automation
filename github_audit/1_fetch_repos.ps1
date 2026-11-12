$ErrorActionPreference = "Stop"

# Resolve paths relative to repo root (one level up from github_audit\)
$repoRoot   = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot "config\workspace_config.json"

if (-not (Test-Path $configPath)) {
    Write-Error "Missing workspace_config.json at $configPath"
    exit 1
}

$config  = Get-Content $configPath -Raw | ConvertFrom-Json
$tempDir = Join-Path $repoRoot $config.paths.temp_dir
if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }

$reposOutPath = Join-Path $tempDir "repos.json"
$owner        = $config.github.username
$domain       = @("api", "github", "com") -join "."
$uri          = "https://$domain/users/$owner/repos?per_page=100"

$headers = @{
    "User-Agent"           = "PowerShell-Repo-Audit"
    "Accept"               = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

Write-Host "[INFO] Fetching repositories for '$owner'..." -ForegroundColor Cyan
$repos = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

Write-Host "[INFO] Response received. Repository count: $($repos.Count)" -ForegroundColor Green
foreach ($r in $repos) {
    Write-Host " - $($r.name) [$($r.language)] -> $($r.html_url)"
}

$repos | Select-Object name, description, language, html_url, updated_at | ConvertTo-Json -Depth 3 | Out-File -FilePath $reposOutPath -Encoding utf8
Write-Host "[SUCCESS] Exported list to $reposOutPath" -ForegroundColor Green
