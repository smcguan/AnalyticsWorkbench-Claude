<#
File: BOOTSTRAP.ps1

Purpose
-------
Create or refresh the local Analytics Workbench development environment.

Responsibilities
----------------
- create the Python virtual environment if it does not exist
- activate the virtual environment
- install backend requirements when available
- fall back to a safe package list if requirements.txt is missing
- verify that critical runtime modules are importable
- make the environment consistent across machines

Important Notes
---------------
- This script now validates the Milestone 3 dataset import dependencies:
    * pandas
    * pyarrow
    * openpyxl
    * multipart  (provided by python-multipart)
- The goal is to catch environment drift early before build or runtime.
#>

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Fail {
    param([string]$Message)
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Root) {
    $Root = (Get-Location).Path
}

Set-Location $Root

$VenvDir = Join-Path $Root ".venv"
$Requirements = Join-Path $Root "backend\requirements.txt"

Write-Host ""
Write-Host "=== Analytics Workbench Bootstrap ===" -ForegroundColor Cyan
Write-Host "Root: $Root"

if (-not (Test-Path $VenvDir)) {
    Write-Host "Creating virtual environment..." -ForegroundColor Yellow
    py -3 -m venv $VenvDir
    if ($LASTEXITCODE -ne 0) {
        Fail "Failed to create virtual environment."
    }
}
else {
    Write-Host "Virtual environment already exists." -ForegroundColor Green
}

$Activate = Join-Path $VenvDir "Scripts\Activate.ps1"
if (-not (Test-Path $Activate)) {
    Fail "Missing activation script: $Activate"
}

Write-Host "Activating virtual environment..." -ForegroundColor Yellow
. $Activate

Write-Host "Upgrading pip/setuptools/wheel..." -ForegroundColor Yellow
python -m pip install --upgrade pip setuptools wheel
if ($LASTEXITCODE -ne 0) {
    Fail "Failed upgrading pip tooling."
}

if (Test-Path $Requirements) {
    Write-Host "Installing backend requirements..." -ForegroundColor Yellow
    python -m pip install -r $Requirements
    if ($LASTEXITCODE -ne 0) {
        Fail "Failed installing backend requirements."
    }
}
else {
    Write-Host "backend\requirements.txt not found. Installing fallback packages..." -ForegroundColor Yellow
    python -m pip install `
        fastapi `
        uvicorn `
        duckdb `
        pandas `
        pyarrow `
        openpyxl `
        python-multipart `
        python-dotenv `
        openai
    if ($LASTEXITCODE -ne 0) {
        Fail "Failed installing fallback packages."
    }
}

Write-Host "Installing packaging-sensitive runtime dependencies explicitly..." -ForegroundColor Yellow
python -m pip install pyarrow openpyxl python-multipart
if ($LASTEXITCODE -ne 0) {
    Fail "Failed installing explicit runtime dependencies."
}

$CriticalModules = @(
    "uvicorn",
    "fastapi",
    "duckdb",
    "dotenv",
    "pandas",
    "pyarrow",
    "openpyxl",
    "multipart"
)

Write-Host "Verifying critical imports..." -ForegroundColor Yellow
foreach ($Module in $CriticalModules) {
    python -c "import $Module"
    if ($LASTEXITCODE -ne 0) {
        Fail "Critical module import failed: $Module"
    }
    Write-Host "  OK  $Module" -ForegroundColor Green
}

Write-Host ""
Write-Host "Bootstrap complete." -ForegroundColor Green
Write-Host "Activate later with:" -ForegroundColor Cyan
Write-Host "  .\.venv\Scripts\Activate.ps1"
