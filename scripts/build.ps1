<#
============================================================
FILE: build.ps1
PURPOSE: Windows release build script for Analytics Workbench
============================================================

OVERVIEW
--------
This script builds a distributable Windows package for
Analytics Workbench using PyInstaller.

It is intentionally focused on RELEASE PACKAGING, not on
first-time developer machine setup.

This script does the following:

1. Resolves important project paths
2. Validates required folders/files exist
3. Locates Python (prefers .venv if available)
4. Verifies PyInstaller is available
5. Cleans prior build artifacts
6. Builds the desktop app with PyInstaller
7. Stages the release folder
8. Copies frontend/data assets into the release
9. Writes helper launch/readme files
10. Creates a zip package for distribution

IMPORTANT
---------
This script is NOT the fresh-machine bootstrap script.

For a new laptop / developer environment, use:

    BOOTSTRAP.ps1

ASSUMPTIONS
-----------
- Repository structure is intact
- backend\app\main.py is the FastAPI entrypoint
- frontend\ contains the shipped UI
- data\ may contain demo/sample datasets
- A working Python installation exists
- Recommended: a prepared .venv exists

OUTPUTS
-------
- release\AnalyticsWorkbench-v<version>\
- release\AnalyticsWorkbench-v<version>.zip

USAGE
-----
PowerShell:

    Set-ExecutionPolicy -Scope Process Bypass
    .\build.ps1

============================================================
#>

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Helper: formatted status output
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
# Resolve core paths
# ------------------------------------------------------------

$AppName      = "AnalyticsWorkbench"
$Root         = $PSScriptRoot
$BackendDir   = Join-Path $Root "backend"
$BackendApp   = Join-Path $BackendDir "app"
$MainPy       = Join-Path $BackendApp "main.py"
$FrontendDir  = Join-Path $Root "frontend"
$DataDir      = Join-Path $Root "data"
$ReleaseRoot  = Join-Path $Root "release"
$BuildDir     = Join-Path $Root "build"
$DistDir      = Join-Path $Root "dist"

# ------------------------------------------------------------
# Version handling
# ------------------------------------------------------------

$Version = $env:APP_VERSION
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = "0.1.0"
}

$StageDir = Join-Path $ReleaseRoot "$AppName-v$Version"
$ZipPath  = Join-Path $ReleaseRoot "$AppName-v$Version.zip"

# ------------------------------------------------------------
# Prefer project virtual environment Python if present
# This makes builds more deterministic.
# ------------------------------------------------------------

$VenvPython = Join-Path $Root ".venv\Scripts\python.exe"

if (Test-Path $VenvPython) {
    $PythonExe = $VenvPython
    $PythonSource = ".venv"
}
else {
    $PythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if (-not $PythonCmd) {
        Fail "Python was not found. Create/use a virtual environment or install Python and add it to PATH."
    }
    $PythonExe = $PythonCmd.Source
    $PythonSource = "PATH"
}

Write-Step "Analytics Workbench Release Build"
Write-Host "Root:         $Root"
Write-Host "Version:      $Version"
Write-Host "Python:       $PythonExe"
Write-Host "PythonSource: $PythonSource"
Write-Host "StageDir:     $StageDir"
Write-Host "ZipPath:      $ZipPath"

# ------------------------------------------------------------
# Pre-flight validation
# ------------------------------------------------------------

Write-Step "Pre-flight Checks"

if (-not (Test-Path $BackendDir))  { Fail "Missing required folder: backend\" }
if (-not (Test-Path $BackendApp))  { Fail "Missing required folder: backend\app\" }
if (-not (Test-Path $MainPy))      { Fail "Missing FastAPI entrypoint: backend\app\main.py" }
if (-not (Test-Path $FrontendDir)) { Fail "Missing required folder: frontend\" }

if (-not (Test-Path $DataDir)) {
    Write-Warning "data\ folder not found. Build will continue, but demo/sample datasets will not be included."
}

# Make sure release root exists
New-Item -ItemType Directory -Force -Path $ReleaseRoot | Out-Null

# ------------------------------------------------------------
# Verify PyInstaller is installed in the selected Python
# ------------------------------------------------------------

Write-Step "Verify Build Dependencies"

& $PythonExe -m PyInstaller --version | Out-Null
if ($LASTEXITCODE -ne 0) {
    Fail @"
PyInstaller is not available in the selected Python environment.

Install it with:
    $PythonExe -m pip install pyinstaller

Recommended first:
    .\BOOTSTRAP.ps1
"@
}

Write-Host "PyInstaller detected."

# ------------------------------------------------------------
# Clean prior build artifacts
# ------------------------------------------------------------

Write-Step "Clean Prior Artifacts"

if (Test-Path $BuildDir)  { Remove-Item -Recurse -Force $BuildDir }
if (Test-Path $DistDir)   { Remove-Item -Recurse -Force $DistDir }
if (Test-Path $StageDir)  { Remove-Item -Recurse -Force $StageDir }
if (Test-Path $ZipPath)   { Remove-Item -Force $ZipPath }

Write-Host "Previous build artifacts removed."

# ------------------------------------------------------------
# Build executable with PyInstaller
#
# IMPORTANT:
# We point PyInstaller at backend\app\main.py and add backend\
# to the import path so imports like "from app.ai.routes ..."
# resolve correctly in development and build contexts.
# ------------------------------------------------------------

Write-Step "Build EXE with PyInstaller"

& $PythonExe -m PyInstaller `
    --noconfirm `
    --clean `
    --onedir `
    --name $AppName `
    --paths $BackendDir `
    $MainPy

if ($LASTEXITCODE -ne 0) {
    Fail "PyInstaller build failed."
}

$BuiltAppDir = Join-Path $DistDir $AppName
if (-not (Test-Path $BuiltAppDir)) {
    Fail "PyInstaller did not produce expected folder: $BuiltAppDir"
}

Write-Host "PyInstaller build completed."

# ------------------------------------------------------------
# Stage release folder
# ------------------------------------------------------------

Write-Step "Stage Release Folder"

New-Item -ItemType Directory -Force -Path $StageDir | Out-Null

# Copy built app contents to stage root
Copy-Item -Path (Join-Path $BuiltAppDir "*") -Destination $StageDir -Recurse -Force

# Copy frontend into release
Copy-Item -Path $FrontendDir -Destination (Join-Path $StageDir "frontend") -Recurse -Force

# Copy data if present
if (Test-Path $DataDir) {
    Copy-Item -Path $DataDir -Destination (Join-Path $StageDir "data") -Recurse -Force
}

# Ensure exports folder exists for runtime output
New-Item -ItemType Directory -Force -Path (Join-Path $StageDir "exports") | Out-Null

Write-Host "Release folder staged."

# ------------------------------------------------------------
# Create helper launch script
# ------------------------------------------------------------

Write-Step "Write Runtime Helpers"

$RunBat = Join-Path $StageDir "run.bat"
@"
@echo off
setlocal
cd /d "%~dp0"
start "" http://127.0.0.1:8000/ui/
"%~dp0$AppName.exe"
endlocal
"@ | Out-File -Encoding ascii $RunBat

# ------------------------------------------------------------
# Create release README
# ------------------------------------------------------------

$Readme = Join-Path $StageDir "README.md"
@"
# Analytics Workbench v$Version

## Start
1. Double-click **run.bat** (recommended), or run **$AppName.exe**
2. Your browser should open to: http://127.0.0.1:8000/ui/

## Add your data (Parquet)
Drop Parquet files into:

  data\\datasets\\<dataset_name>\\*.parquet

Example:

  data\\datasets\\doge\\BIG.parquet

Refresh the UI and the dataset will appear in the **Dataset** dropdown.

## Demo dataset
A small sample dataset may be included at:

  data\\datasets\\demo\\sample.parquet

## Exports
Exports appear in:

  exports\\

## Notes
- This is a local, single-machine desktop build.
- If port 8000 is already in use, close the other app using it and try again.
- This package is built from a local PyInstaller release process.
"@ | Out-File -Encoding utf8 $Readme

Write-Host "Runtime helper files created."

# ------------------------------------------------------------
# Create zip package
# ------------------------------------------------------------

Write-Step "Create Zip Package"

Compress-Archive -Path $StageDir -DestinationPath $ZipPath -Force

# ------------------------------------------------------------
# Final summary
# ------------------------------------------------------------

Write-Step "Build Complete"
Write-Host "Stage folder: $StageDir" -ForegroundColor Green
Write-Host "Zip package:  $ZipPath"  -ForegroundColor Green