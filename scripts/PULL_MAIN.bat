@echo off
setlocal

echo.
echo =====================================
echo        PULL ANALYTICS WORKBENCH
echo =====================================
echo.

REM Repo is the parent of this scripts folder
cd /d "%~dp0.."

if errorlevel 1 (
    echo ERROR: Could not access repo directory.
    pause
    exit /b 1
)

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo ERROR: Parent directory is not a git repository.
    pause
    exit /b 1
)

for /f "delims=" %%i in ('git branch --show-current') do set CURRENT_BRANCH=%%i

if /I not "%CURRENT_BRANCH%"=="main" (
    echo ERROR: You are on branch "%CURRENT_BRANCH%".
    echo Switch to main before pulling.
    pause
    exit /b 1
)

echo Repo:
git rev-parse --show-toplevel
echo Branch: %CURRENT_BRANCH%
echo.

echo Fetching origin...
git fetch origin
if errorlevel 1 (
    echo ERROR: Fetch failed.
    pause
    exit /b 1
)

echo.
echo Pulling origin/main...
git pull origin main
if errorlevel 1 (
    echo ERROR: Pull failed.
    pause
    exit /b 1
)

echo.
echo Pull successful.
git log --oneline -3
echo.
pause
endlocal