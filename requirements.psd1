@{
    # Minimum PowerShell Engine Version
    PowerShellVersion = '5.1'

    # Required External CLI Tools (must be available in system PATH)
    ExternalDependencies = @{
        Git    = '2.40.0 or higher (with Git Credential Manager)'
        Python = '3.10.0 or higher (for py_compile validation & smoke tests)'
    }

    # Optional Linting & Static Analysis Modules
    RecommendedModules = @(
        @{ ModuleName = 'PSScriptAnalyzer'; ModuleVersion = '1.21.0' }
    )
}
