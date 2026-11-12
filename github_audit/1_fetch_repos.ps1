$protocol = "https://"
$hostParts = @("api", "github", "com")
$domain = $hostParts -join "."
$owner = "TheunisLaGrange"

$uri = "$protocol$domain/users/$owner/repos?per_page=100"

Write-Host "[DEBUG] Protocol : $protocol" -ForegroundColor Cyan
Write-Host "[DEBUG] Domain   : $domain" -ForegroundColor Cyan
Write-Host "[DEBUG] Full URI : $uri" -ForegroundColor Yellow

$headers = @{
    "User-Agent" = "PowerShell-Repo-Audit"
    "Accept"     = "application/vnd.github+json"
}

Write-Host "[INFO] Sending request to GitHub API..." -ForegroundColor Cyan
$repos = Invoke-RestMethod -Uri $uri -Headers $headers

Write-Host "[INFO] Response received. Repository count: $($repos.Count)" -ForegroundColor Green

foreach ($r in $repos) {
    Write-Host " - $($r.name) [$($r.language)] -> $($r.html_url)"
}

$repos | Select-Object name, description, language, html_url, updated_at | ConvertTo-Json -Depth 3 | Out-File -FilePath "repos.json" -Encoding utf8
Write-Host "[SUCCESS] Exported list to repos.json" -ForegroundColor Green
