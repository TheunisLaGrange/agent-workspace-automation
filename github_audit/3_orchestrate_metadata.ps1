$ErrorActionPreference = "Stop"

# Resolve paths relative to script location
$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot "config\workspace_config.json"
$llmWorker = Join-Path $repoRoot "utils\llm_service.py"

if (-not (Test-Path $configPath)) {
    Write-Error "Missing config file at $configPath. Copy workspace_config.sample.json to workspace_config.json."
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$tempDir = Join-Path $repoRoot $config.paths.temp_dir
if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }

$reposJsonPath = Join-Path $tempDir "repos.json"
if (-not (Test-Path $reposJsonPath)) {
    Write-Error "Missing $reposJsonPath. Run 1_fetch_repos.ps1 first."
    exit 1
}

# Resolve Token & Python Executable
$token = if ($config.github.token -and $config.github.token -ne "YOUR_GITHUB_PAT_HERE") { $config.github.token } else { $env:GITHUB_TOKEN }
$pythonExe = if (Test-Path $config.paths.python_exe) { $config.paths.python_exe } else { "python" }

# Safe API Base Construction
$domain = @("api", "github", "com") -join "."
$apiBase = "https://$domain"
$owner = $config.github.username

$headers = @{
    "User-Agent"           = "PowerShell-Metadata-Orchestrator"
    "Accept"               = "application/vnd.github+json"
    "Authorization"        = "Bearer $token"
    "X-GitHub-Api-Version" = "2022-11-28"
}

$repos = Get-Content $reposJsonPath -Raw | ConvertFrom-Json
$inputBridge = Join-Path $tempDir "llm_input.json"
$outputBridge = Join-Path $tempDir "llm_output.json"

Write-Host "[INFO] Starting metadata orchestration for $($repos.Count) repositories..." -ForegroundColor Cyan

foreach ($repo in $repos) {
    $repoName = $repo.name
    Write-Host "`n[REPO] Processing $repoName..." -ForegroundColor Yellow

    # 1. Fetch README.md via GitHub API
    $readmeUri = "$apiBase/repos/$owner/$repoName/readme"
    try {
        $readmeObj = Invoke-RestMethod -Uri $readmeUri -Headers $headers -Method Get
        $readmeBytes = [Convert]::FromBase64String(($readmeObj.content -replace "`n", ""))
        $readmeText = [System.Text.Encoding]::UTF8.GetString($readmeBytes)
    }
    catch {
        Write-Host "  [SKIP] No README.md found or API error for $repoName." -ForegroundColor DarkYellow
        continue
    }

    # 2. Write Standardized Input JSON Contract
    $inputPayload = @{
        task        = "generate_repo_description"
        constraints = @{
            max_characters = $config.llm_settings.max_description_chars
            tone           = "technical, concise, recruiter-ready"
        }
        context     = @{
            repo_name        = $repoName
            primary_language = if ($repo.language) { $repo.language } else { "Multiple" }
            readme_content   = $readmeText
        }
    }
    $inputPayload | ConvertTo-Json -Depth 4 | Out-File -FilePath $inputBridge -Encoding utf8

    # 3. Execute Python LLM Service
    Write-Host "  [LLM] Generating <=$($config.llm_settings.max_description_chars)-char description..." -ForegroundColor Cyan
    & $pythonExe $llmWorker $inputBridge $outputBridge
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $outputBridge)) {
        Write-Host "  [ERROR] llm_service.py failed for $repoName." -ForegroundColor Red
        continue
    }

    $llmResult = Get-Content $outputBridge -Raw | ConvertFrom-Json
    if ($llmResult.status -ne "success") {
        Write-Host "  [SKIP] LLM skipped $repoName : $($llmResult.reason)" -ForegroundColor DarkYellow
        continue
    }

    # 4. Push Description & Topics to GitHub
    $repoUri = "$apiBase/repos/$owner/$repoName"
    $patchBody = @{ description = $llmResult.description } | ConvertTo-Json
    Invoke-RestMethod -Uri $repoUri -Headers $headers -Method Patch -Body $patchBody -ContentType "application/json" | Out-Null
    Write-Host "  [PUSHED] Description ($($llmResult.character_count) chars): $($llmResult.description)" -ForegroundColor Green

    if ($llmResult.suggested_topics -and $llmResult.suggested_topics.Count -gt 0) {
        $topicsUri = "$apiBase/repos/$owner/$repoName/topics"
        $topicsBody = @{ names = @($llmResult.suggested_topics) } | ConvertTo-Json
        Invoke-RestMethod -Uri $topicsUri -Headers $headers -Method Put -Body $topicsBody -ContentType "application/json" | Out-Null
        Write-Host "  [PUSHED] Topics: $($llmResult.suggested_topics -join ', ')" -ForegroundColor Green
    }
}

Write-Host "`n[DONE] Metadata orchestration complete." -ForegroundColor Cyan
