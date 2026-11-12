# ⚙️ Agent Workspace Lifecycle & DevOps Automation Suite

A modular PowerShell & Python automation toolkit that manages the end-to-end development lifecycle of AI agent projects—from workspace scaffolding and sandbox integration to automated GitHub repository auditing and LLM-powered metadata generation.

## 🏗️ Architecture & State Management

All scripts coordinate dynamically via a unified local JSON configuration (`config/workspace_config.json`, modeled in `config/workspace_config.sample.json`) and strict JSON Input/Output contracts (`templates/`), eliminating hardcoded paths across scripts.

```text
01_Automation_Scripts/
├── config/
│   ├── workspace_config.json           # 🔒 Git-ignored active config (tokens, paths, project state)
│   └── workspace_config.sample.json    # 📋 Committed reference schema for workspace setup
├── github_audit/
│   ├── 1_fetch_repos.ps1               # 📡 Pulls public repository metadata into temp/repos.json
│   ├── 2_sync_licenses.ps1             # 📜 Audits repos and pushes stamped MIT LICENSE files
│   └── 3_orchestrate_metadata.ps1      # 🤖 Bridges READMEs through llm_service.py to update descriptions/topics
├── pipeline/
│   ├── step_1_generate_project.ps1     # 🏗️ Scaffolds modular project folders and initializes state
│   ├── step_2_inject_sandbox.ps1       # 🧪 Injects isolated test harnesses into sandbox environments
│   ├── step_3_integrate_workspace.ps1  # 🔗 Splices verified sandbox logic into production main.py
│   ├── step_4_preflight_audit.ps1      # 🛡️ Runs syntax checks, secret scans, and pre-push validation
│   ├── step_5_push_project.ps1         # 🚀 Stages clean changes and pushes commits to GitHub
│   ├── step_6_publish_github_release.py# 📦 Packages release artifacts and publishes GitHub releases
│   ├── blueprint_sync_script.ps1       # 🔄 Promotes battle-tested core modules back to master blueprint
│   ├── build_release.ps1               # 🏭 Compiles standalone executables and release bundles
│   ├── clean_blueprint.ps1             # 🧹 Purges cache, bytecode, and temporary build artifacts
│   └── update_boilerplate.ps1          # 📐 Syncs updated boilerplate hooks across active workspaces
├── templates/
│   ├── llm_input.schema.json           # 📥 Standardized JSON input envelope for LLM workers
│   └── llm_output.schema.json          # 📤 Standardized JSON output envelope for LLM workers
├── utils/
│   └── llm_service.py                  # 🧠 Modular Google Gemini worker with Pydantic validation & retries
├── .gitignore                          # 🙈 Excludes config/workspace_config.json, temp/, and logs
├── LICENSE                             # ⚖️ MIT License
├── README.md                           # 📖 Suite architecture and usage guide
├── requirements.psd1                   # 💻 PowerShell & system prerequisite manifest
└── requirements.txt                    # 🐍 Python package dependencies (google-genai, pydantic)
```

## 🛠️ Included Modules

### 📡 GitHub Portfolio Audit (`github_audit/`)
* **`1_fetch_repos.ps1`**: Queries the GitHub REST API and exports structured repository metadata to `temp/repos.json`.
* **`2_sync_licenses.ps1`**: Scans all repositories in `temp/repos.json` for a `LICENSE` file, stamps the local template with the current year and copyright holder, and commits it via the GitHub Contents API.
* **`3_orchestrate_metadata.ps1`**: Pulls each repository's `README.md`, passes it to `utils/llm_service.py` via a JSON bridge, and updates the repository's 350-character description and topic tags on GitHub.

### 🔄 Development Lifecycle Pipeline (`pipeline/`)
* **`step_1_generate_project.ps1`**: Initializes a new project workspace from a master template, enforcing strict separation between program logic (`src/`) and user data (`User_Data/`, `Output/`).
* **`step_2_inject_sandbox.ps1` & `step_3_integrate_workspace.ps1`**: Isolates experimental code in `sandbox/`, creates safety backups (`main.py.bak`), splices verified logic between integration markers, and validates Python syntax (`py_compile`).
* **`step_4_preflight_audit.ps1` & `step_5_push_project.ps1`**: Strips temporary backup artifacts, verifies remote origin configuration, and pushes clean commits to GitHub.
* **`step_6_publish_github_release.py` & `build_release.ps1`**: Automates standalone compilation and publishes versioned GitHub releases.
* **`blueprint_sync_script.ps1`**: Promotes verified core engine upgrades (`llm_service.py`, `workers/*.py`) back to the master blueprint template.

### 🧠 Shared Utilities & Contracts (`utils/` & `templates/`)
* **`utils/llm_service.py`**: Decoupled Python CLI worker powered by Google Gemini (`gemini-3.6-flash`) with exponential backoff retries and strict Pydantic JSON schema enforcement.

## ⚡ Prerequisites & Quick Start

1. **System Requirements**: Ensure **PowerShell 5.1+**, **Git for Windows**, and **Python 3.10+** are installed and available on your `PATH` (see `requirements.psd1`).
2. **Install Python Dependencies**:
   ```powershell
   pip install -r requirements.txt
   ```
3. **Configure Workspace**: Copy `config/workspace_config.sample.json` to `config/workspace_config.json` and add your GitHub Personal Access Token (`repo` scope) and local paths.
4. **Run Automation**:
   * **Audit & Sync GitHub Repos**: Run `.\github_audit\1_fetch_repos.ps1`, `.\github_audit\2_sync_licenses.ps1`, or `.\github_audit\3_orchestrate_metadata.ps1`.
   * **Manage Project Lifecycle**: Run `.\pipeline\step_1_generate_project.ps1` through `.\pipeline\step_6_publish_github_release.py` sequentially without manual path arguments.
