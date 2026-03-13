<#
File: build.ps1

Purpose
-------
Build a packaged Windows distribution for Analytics Workbench.

Responsibilities
----------------
- verify the local virtual environment exists
- ensure the build uses the project virtual environment Python
- clean old build artifacts so stale code is not reused
- build through AnalyticsWorkbench.spec
- preserve packaging rules needed for PyArrow, multipart uploads, and Excel import
- write a small packaged README for users

Important Notes
---------------
- This script intentionally builds from the PyInstaller spec file rather than
  directly from backend\app\main.py.
- That is required because the spec includes hidden imports and native library
  collection needed by:
    * pyarrow
    * python-multipart
    * openpyxl
    * duckdb
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

$AppName = "AnalyticsWorkbench"
$VenvPython = Join-Path $Root ".venv\Scripts\python.exe"
$SpecFile = Join-Path $Root "AnalyticsWorkbench.spec"
$BuildDir = Join-Path $Root "build"
$DistDir = Join-Path $Root "dist"
$DistAppDir = Join-Path $DistDir $AppName

Write-Host ""
Write-Host "=== Analytics Workbench Build ===" -ForegroundColor Cyan
Write-Host "Root: $Root"

if (-not (Test-Path $VenvPython)) {
    Fail "Missing virtual environment Python: $VenvPython`nRun BOOTSTRAP.ps1 first."
}

if (-not (Test-Path $SpecFile)) {
    Fail "Missing PyInstaller spec file: $SpecFile"
}

Write-Host "Using Python: $VenvPython" -ForegroundColor Green

Write-Host "Refreshing runtime/build dependencies..." -ForegroundColor Yellow
& $VenvPython -m pip install -r (Join-Path $Root "backend\requirements.txt")
if ($LASTEXITCODE -ne 0) {
    Fail "Failed installing backend requirements."
}

& $VenvPython -m pip install pyinstaller pyarrow openpyxl python-multipart
if ($LASTEXITCODE -ne 0) {
    Fail "Failed installing build/runtime dependencies."
}

if (Test-Path $BuildDir) {
    Write-Host "Removing build directory..." -ForegroundColor Yellow
    Remove-Item $BuildDir -Recurse -Force
}

if (Test-Path $DistDir) {
    Write-Host "Removing dist directory..." -ForegroundColor Yellow
    Remove-Item $DistDir -Recurse -Force
}

Write-Host "Building with PyInstaller spec..." -ForegroundColor Yellow
& $VenvPython -m PyInstaller --noconfirm --clean $SpecFile
if ($LASTEXITCODE -ne 0) {
    Fail "PyInstaller build failed."
}

if (-not (Test-Path $DistAppDir)) {
    Fail "Expected packaged app folder was not created: $DistAppDir"
}

$ReadmePath = Join-Path $DistAppDir "README.txt"
$Readme = @"
Analytics Workbench
===================

Run
---
Launch:
  AnalyticsWorkbench.exe

Data location
-------------
The packaged app uses local folders inside this distribution:
  data\datasets
  exports

Dataset import
--------------
The app can import:
  - .parquet
  - .csv
  - .xlsx

Imported datasets are normalized internally to Parquet and stored in:
  data\datasets\<dataset_name>\

Environment
-----------
If you need to rebuild this package on another machine:
  1. run BOOTSTRAP.ps1
  2. run build.ps1
"@

Set-Content -Path $ReadmePath -Value $Readme -Encoding UTF8

Write-Host ""
Write-Host "Build complete." -ForegroundColor Green
Write-Host "Output folder: $DistAppDir" -ForegroundColor Cyan
