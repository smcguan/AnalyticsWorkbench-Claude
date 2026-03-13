@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM FILE: PUSH_MAIN.bat
REM PURPOSE: Safely commit and push the current repo to origin/main
REM ============================================================
REM
REM OVERVIEW
REM --------
REM This script is a safer wrapper around the normal Git workflow:
REM
REM     git add .
REM     git commit -m "message"
REM     git push origin main
REM
REM It adds several useful safeguards:
REM
REM 1. Resolves and prints the repo root clearly
REM 2. Confirms the current branch
REM 3. Shows the remote URL being used
REM 4. Pulls latest origin/main before committing
REM 5. Prompts for a commit message
REM 6. Stages changes AFTER the prompt
REM 7. Shows exactly what is staged
REM 8. Refuses to continue if nothing is staged
REM 9. Commits and pushes to origin/main
REM 10. Prints the final local and remote HEAD hashes
REM
REM IMPORTANT
REM ---------
REM This script assumes it lives in:
REM
REM     <repo>\scripts\PUSH_MAIN.bat
REM
REM and therefore treats the parent folder of "scripts" as the
REM repository root.
REM
REM If you move this file somewhere else, update the REPO logic.
REM
REM USAGE
REM -----
REM Double-click it, or run from Command Prompt / PowerShell.
REM
REM ============================================================

REM ------------------------------------------------------------
REM Resolve repository root based on script location
REM ------------------------------------------------------------
for %%I in ("%~dp0..") do set "REPO=%%~fI"

echo.
echo ============================================================
echo Analytics Workbench - Safe Push Script
echo ============================================================
echo Script location: %~dp0
echo Repo target:     %REPO%
echo Initial folder:  %CD%
echo.

REM ------------------------------------------------------------
REM Move into the repo root
REM ------------------------------------------------------------
cd /d "%REPO%" || (
    echo ERROR: Failed to change directory to repo root.
    pause
    exit /b 1
)

echo Current folder after cd: %CD%
echo.

REM ------------------------------------------------------------
REM Verify this is actually a Git repository
REM ------------------------------------------------------------
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo ERROR: This folder is not a Git repository:
    echo        %CD%
    pause
    exit /b 1
)

REM ------------------------------------------------------------
REM Show repo / branch / remote information
REM ------------------------------------------------------------
for /f "delims=" %%A in ('git rev-parse --show-toplevel') do set "TOPLEVEL=%%A"
for /f "delims=" %%A in ('git branch --show-current') do set "BRANCH=%%A"

echo Repo root:
echo %TOPLEVEL%
echo Branch: %BRANCH%
echo.
echo Remotes:
git remote -v
echo.

if /I not "%BRANCH%"=="main" (
    echo WARNING: You are not on branch "main".
    echo Current branch: %BRANCH%
    echo.
    choice /M "Continue anyway"
    if errorlevel 2 (
        echo Aborted by user.
        pause
        exit /b 1
    )
)

REM ------------------------------------------------------------
REM Show current status before doing anything
REM ------------------------------------------------------------
echo Current status before pull:
git status --short
echo.

echo Current HEAD before pull:
git log --oneline -1
echo.

REM ------------------------------------------------------------
REM Pull latest origin/main first
REM ------------------------------------------------------------
echo Pulling latest origin/main first...
git pull origin main
if errorlevel 1 (
    echo.
    echo ERROR: git pull failed.
    echo Resolve the issue above, then try again.
    pause
    exit /b 1
)
echo.

REM ------------------------------------------------------------
REM Show status after pull
REM ------------------------------------------------------------
echo Current status after pull:
git status --short
echo.

REM ------------------------------------------------------------
REM Prompt for commit message
REM ------------------------------------------------------------
set "MSG="
set /p MSG=Enter commit message, then press Enter to stage, commit, and push: 

if "%MSG%"=="" (
    echo.
    echo ERROR: Commit message cannot be empty.
    pause
    exit /b 1
)

echo.
echo Commit message:
echo %MSG%
echo.

REM ------------------------------------------------------------
REM Stage all changes
REM ------------------------------------------------------------
echo Staging changes...
git add .
if errorlevel 1 (
    echo.
    echo ERROR: git add failed.
    pause
    exit /b 1
)
echo.

REM ------------------------------------------------------------
REM Show exactly what is staged
REM ------------------------------------------------------------
echo Staged changes:
git diff --cached --name-status
echo.

REM ------------------------------------------------------------
REM Refuse to continue if nothing is staged
REM ------------------------------------------------------------
git diff --cached --quiet
if not errorlevel 1 (
    echo No staged changes to commit.
    echo.
    echo This usually means one of the following:
    echo   - nothing actually changed
    echo   - changes were already committed
    echo   - files changed in a way Git is not tracking
    echo.
    pause
    exit /b 0
)

REM ------------------------------------------------------------
REM Final confirmation before commit/push
REM ------------------------------------------------------------
choice /M "Proceed with commit and push"
if errorlevel 2 (
    echo Aborted by user.
    pause
    exit /b 1
)

echo.
echo Creating commit...
git commit -m "%MSG%"
if errorlevel 1 (
    echo.
    echo ERROR: git commit failed.
    pause
    exit /b 1
)
echo.

echo Pushing to origin main...
git push origin main
if errorlevel 1 (
    echo.
    echo ERROR: git push failed.
    pause
    exit /b 1
)
echo.

REM ------------------------------------------------------------
REM Show final verification
REM ------------------------------------------------------------
echo ============================================================
echo Push complete
echo ============================================================
echo.
echo Local HEAD:
git rev-parse HEAD
echo.
echo Remote HEAD (origin/main):
git rev-parse origin/main
echo.
echo Latest commit:
git log --oneline -1
echo.
echo Final status:
git status --short
echo.
pause
exit /b 0