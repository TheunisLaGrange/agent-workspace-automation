# Define Core Paths
$WorkspaceRoot = "C:\PC Programming\Python\src\AI\Agent"
$AppSrc        = "$WorkspaceRoot\ai_cv_genrator\src\core"
$BlueprintSrc  = "$WorkspaceRoot\long-horizon-agent-blueprint\src\core"

Write-Host "🔄 Syncing core updates back to boilerplate safely..." -ForegroundColor Cyan

# 1. Synchronize the central brain script
Copy-Item -Path "$AppSrc\llm_service.py" -Destination "$BlueprintSrc\llm_service.py" -Force

# 2. Synchronize worker files while explicitly EXCLUDING bytecode and cache folders
Get-ChildItem -Path "$AppSrc\workers\" -File | Where-Object { $_.Extension -ne ".pyc" } | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination "$BlueprintSrc\workers\" -Force
}

# 3. Update Master Configuration Blueprint
Copy-Item -Path "$WorkspaceRoot\ai_cv_genrator\config\agent_config.yaml" -Destination "$WorkspaceRoot\long-horizon-agent-blueprint\config\agent_config.yaml" -Force

Write-Host "✅ Master Template Engine Synchronized Safely (Bytecode Skipped)!" -ForegroundColor Green
