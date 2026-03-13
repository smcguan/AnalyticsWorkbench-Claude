<#
============================================================
FILE: BOOTSTRAP.ps1
PURPOSE: Fresh-machine / developer bootstrap for Analytics Workbench
============================================================

OVERVIEW
--------
This script prepares a Windows laptop or developer machine
to run Analytics Workbench locally.

It is designed to reflect the exact setup lessons learned
during recent laptop bring-up and debugging.

This script does the following:

1. Resolves the project root
2. Verifies Python is available
3. Creates or recreates a virtual environment (.venv)
4. Uses the venv Python directly (more reliable than activation)
5. Upgrades pip
6. Installs project requirements
7. Verifies critical packages are installed
8. Creates or updates .env
9. Prompts for an OpenAI API key if missing/placeholder
10. Optionally starts the backend with uvicorn

WHY THIS EXISTS
---------------
Pulling the repo alone is not enough to run the app on a new
machine. The local environment also matters.

Common fresh-machine issues include:
- missing virtual environment
- missing dependencies
- missing uvicorn
- wrong startup command
- missing or incomplete .env

This script is meant to solve that cleanly.

IMPORTANT
---------
This is a DEV / SETUP script.

It is not the release packaging script.
For packaging a distributable build, use:

    build.ps1

USAGE
-----
PowerShell:

    Set-ExecutionPolicy -Scope Process Bypass
    .\BOOTSTRAP.ps1

============================================================
#>

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Helper: Yes/No prompt
# ------------------------------------------------------------

function Ask-YesNo {
    param(
        [string]$Prompt,
        [bool]$DefaultYes = $true
    )

    while ($true) {
        if ($DefaultYes) { $suffix = " [Y/n]" }
        else { $suffix = " [y/N]" }

        $answer = Read-Host "$Prompt$suffix"

        if ([string]::IsNullOrWhiteSpace($answer)) {
            return $DefaultYes
        }

        switch ($answer.Trim().ToLower()) {
            "y"   { return $true }
            "yes" { return $true }
            "n"   { return $false }
            "no"  { return $false }
            default { Write-Host "Please enter Y or N." }
        }
    }
}

# ------------------------------------------------------------
# Helper: friendly section headers
# ------------------------------------------------------------

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

function Fail {
    param([string]$Message)
    throw $Message
}

# ------------------------------------------------------------
# Helper: set or replace a key=value pair in .env
# ------------------------------------------------------------

function Set-EnvValue {
    param(
        [string]$FilePath,
        [string]$Key,
        [string]$Value
    )

    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) { $content = "" }

    $pattern = "(?m)^$Key=.*$"

    if ($content -match $pattern) {
        $content = [regex]::Replace($content, $pattern, "$Key=$Value")
    }
    else {
        if ($content.Length -gt 0 -and -not $content.EndsWith("`n")) {
            $content += "`r`n"
        }
        $content += "$Key=$Value`r`n"
    }

    Set-Content -Path $FilePath -Value $content -Encoding UTF8
}

# ------------------------------------------------------------
# Helper: read env value from .env if present
# ------------------------------------------------------------

function Get-EnvFileValue {
    param(
        [string]$FilePath,
        [string]$Key
    )

    if (-not (Test-Path $FilePath)) {
        return $null
    }

    $match = Select-String -Path $FilePath -Pattern "^(?i)$Key=(.*)$" | Select-Object -First 1
    if ($match) {
        return $match.Matches[0].Groups[1].Value
    }

    return $null
}

# ------------------------------------------------------------
# Resolve project root
#
# This script assumes it lives in the repo root.
# ------------------------------------------------------------

$ProjectRoot = $PSScriptRoot
Set-Location $ProjectRoot

$VenvDir       = Join-Path $ProjectRoot ".venv"
$VenvPython    = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
$RootReqs      = Join-Path $ProjectRoot "requirements.txt"
$BackendReqs   = Join-Path $ProjectRoot "backend\requirements.txt"
$EnvFile       = Join-Path $ProjectRoot ".env"
$EnvExample    = Join-Path $ProjectRoot ".env.example"
$BackendDir    = Join-Path $ProjectRoot "backend"
$BackendAppDir = Join-Path $BackendDir "app"
$MainPy        = Join-Path $BackendAppDir "main.py"

Write-Step "Analytics Workbench Bootstrap"
Write-Host "Project root: $ProjectRoot"

# ------------------------------------------------------------
# Verify Python
# ------------------------------------------------------------

Write-Step "Check Python"

$PythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $PythonCmd) {
    Fail @"
Python was not found on PATH.

Install Python first, then rerun this script.
Recommended:
- Python 3.11+
- Add Python to PATH during install
"@
}

$SystemPython = $PythonCmd.Source
$PythonVersion = & $SystemPython --version
Write-Host "Detected Python: $PythonVersion"
Write-Host "Python path:      $SystemPython"

# ------------------------------------------------------------
# Create or recreate virtual environment
# ------------------------------------------------------------

Write-Step "Virtual Environment"

if (-not (Test-Path $VenvDir)) {
    if (Ask-YesNo "Create Python virtual environment (.venv)?") {
        & $SystemPython -m venv $VenvDir
        if ($LASTEXITCODE -ne 0) {
            Fail "Failed to create virtual environment."
        }
        Write-Host ".venv created."
    }
    else {
        Fail "Cannot continue without a virtual environment."
    }
}
else {
    Write-Host ".venv already exists."

    if (Ask-YesNo "Recreate .venv from scratch?" $false) {
        Remove-Item $VenvDir -Recurse -Force
        & $SystemPython -m venv $VenvDir
        if ($LASTEXITCODE -ne 0) {
            Fail "Failed to recreate virtual environment."
        }
        Write-Host ".venv recreated."
    }
}

if (-not (Test-Path $VenvPython)) {
    Fail "Expected venv Python was not found: $VenvPython"
}

Write-Host "Using venv Python: $VenvPython"

# ------------------------------------------------------------
# Ensure pip exists and upgrade it
# ------------------------------------------------------------

Write-Step "Pip Setup"

& $VenvPython -m ensurepip --upgrade | Out-Null
& $VenvPython -m pip install --upgrade pip

if ($LASTEXITCODE -ne 0) {
    Fail "Failed to prepare pip in the virtual environment."
}

Write-Host "pip upgraded successfully."

# ------------------------------------------------------------
# Resolve requirements file
#
# We prefer backend\requirements.txt if it exists because the
# backend is the runtime engine we need for local development.
# ------------------------------------------------------------

Write-Step "Install Dependencies"

$RequirementsPath = $null

if (Test-Path $BackendReqs) {
    $RequirementsPath = $BackendReqs
}
elseif (Test-Path $RootReqs) {
    $RequirementsPath = $RootReqs
}

if ($RequirementsPath) {
    Write-Host "Requirements file: $RequirementsPath"

    if (Ask-YesNo "Install dependencies from requirements file?") {
        & $VenvPython -m pip install -r $RequirementsPath

        if ($LASTEXITCODE -ne 0) {
            Fail "Dependency installation failed."
        }

        Write-Host "Dependencies installed."
    }
}
else {
    Write-Warning "No requirements file found at root or backend level."

    if (Ask-YesNo "Install a minimal fallback package set?" $false) {
        & $VenvPython -m pip install `
            fastapi `
            uvicorn `
            duckdb `
            pandas `
            pyarrow `
            python-dotenv `
            openai

        if ($LASTEXITCODE -ne 0) {
            Fail "Fallback dependency installation failed."
        }

        Write-Host "Fallback dependency set installed."
    }
}

# ------------------------------------------------------------
# Verify critical runtime packages
#
# This reflects what actually failed on the laptop:
# uvicorn was missing, which prevented backend startup.
# ------------------------------------------------------------

Write-Step "Verify Critical Packages"

$CriticalModules = @(
    "uvicorn",
    "fastapi",
    "duckdb",
    "dotenv"
)

foreach ($ModuleName in $CriticalModules) {
    & $VenvPython -c "import $ModuleName" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Fail "Critical Python module missing from venv: $ModuleName"
    }
    Write-Host "Verified: $ModuleName"
}

# ------------------------------------------------------------
# Verify core project files
# ------------------------------------------------------------

Write-Step "Verify Project Structure"

if (-not (Test-Path $BackendDir))    { Fail "Missing folder: backend\" }
if (-not (Test-Path $BackendAppDir)) { Fail "Missing folder: backend\app\" }
if (-not (Test-Path $MainPy))        { Fail "Missing file: backend\app\main.py" }

Write-Host "Backend entrypoint found: $MainPy"

# ------------------------------------------------------------
# .env setup
# ------------------------------------------------------------

Write-Step ".env Setup"

if (-not (Test-Path $EnvFile)) {
    Write-Host ".env not found."

    if (Test-Path $EnvExample) {
        Copy-Item $EnvExample $EnvFile
        Write-Host ".env created from .env.example"
    }
    else {
        New-Item $EnvFile -ItemType File | Out-Null
        Write-Host ".env created."
    }
}
else {
    Write-Host ".env already exists."
}

# ------------------------------------------------------------
# Prompt for OpenAI API key if missing / blank / placeholder
# ------------------------------------------------------------

Write-Step "OpenAI Key Check"

$CurrentKey = Get-EnvFileValue -FilePath $EnvFile -Key "OPENAI_API_KEY"
$NeedsKey = $false

if ($null -eq $CurrentKey) {
    $NeedsKey = $true
}
elseif ([string]::IsNullOrWhiteSpace($CurrentKey)) {
    $NeedsKey = $true
}
elseif ($CurrentKey -eq "your_openai_key_here") {
    $NeedsKey = $true
}

if ($NeedsKey) {
    Write-Host "OPENAI_API_KEY is missing, blank, or still using a placeholder."

    if (Ask-YesNo "Enter your OpenAI API key now?") {
        $Key = Read-Host "Paste your OpenAI API key"

        if (-not [string]::IsNullOrWhiteSpace($Key)) {
            Set-EnvValue -FilePath $EnvFile -Key "OPENAI_API_KEY" -Value $Key
            Write-Host "OpenAI key saved to local .env"
        }
        else {
            Write-Warning "No key entered. AI features may not work until .env is updated."
        }
    }
    else {
        Write-Warning "Skipping API key entry. AI features may not work until .env is updated."
    }
}
else {
    Write-Host "OPENAI_API_KEY already appears to be configured."
}

# ------------------------------------------------------------
# Optional release build
# ------------------------------------------------------------

Write-Step "Optional Release Build"

$BuildScript = Join-Path $ProjectRoot "build.ps1"

if (Test-Path $BuildScript) {
    if (Ask-YesNo "Run release build now? (PyInstaller)" $false) {
        & $BuildScript
    }
}
else {
    Write-Host "build.ps1 not found. Skipping release build option."
}

# ------------------------------------------------------------
# Optional backend startup
#
# IMPORTANT:
# We start the backend with uvicorn using the same pattern
# that worked during laptop debugging.
#
# We also set PYTHONPATH to backend\ so imports like
# app.main:app resolve correctly.
# ------------------------------------------------------------

Write-Step "Optional Backend Startup"

if (Ask-YesNo "Start backend server now?") {
    $env:PYTHONPATH = $BackendDir

    Write-Host ""
    Write-Host "Starting backend with uvicorn..."
    Write-Host "PYTHONPATH: $env:PYTHONPATH"
    Write-Host "URL:        http://127.0.0.1:8010/docs"
    Write-Host ""

    & $VenvPython -m uvicorn app.main:app --reload --port 8010 --log-level debug
}

# ------------------------------------------------------------
# Final instructions
# ------------------------------------------------------------

Write-Step "Bootstrap Complete"

Write-Host "Recommended next steps:"
Write-Host ""
Write-Host "1. Start the backend manually if needed:"
Write-Host "   `$env:PYTHONPATH = `"$BackendDir`""
Write-Host "   `"$VenvPython`" -m uvicorn app.main:app --reload --port 8010 --log-level debug"
Write-Host ""
Write-Host "2. Open Swagger docs:"
Write-Host "   http://127.0.0.1:8010/docs"
Write-Host ""
Write-Host "3. Open the app UI (if your frontend is wired to this backend):"
Write-Host "   http://127.0.0.1:8010/ui/"
Write-Host ""
Write-Host "4. For release packaging, run:"
Write-Host "   .\build.ps1"
Write-Host ""