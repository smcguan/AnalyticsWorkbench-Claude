@echo off
setlocal

echo.
echo =====================================
echo        PUSH ANALYTICS WORKBENCH
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
    echo Switch to main before pushing.
    pause
    exit /b 1
)

echo Repo:
git rev-parse --show-toplevel
echo Branch: %CURRENT_BRANCH%
echo.

echo Pulling latest origin/main first...
git pull origin main
if errorlevel 1 (
    echo.
    echo ERROR: Pull failed. Resolve that first.
    pause
    exit /b 1
)

echo.
git status
echo.

set /p MSG=Enter commit message: 

if "%MSG%"=="" (
    echo ERROR: Commit message cannot be empty.
    pause
    exit /b 1
)

echo.
echo Staging changes...
git add .

echo.
echo Creating commit...
git commit -m "%MSG%"
if errorlevel 1 (
    echo.
    echo No changes to commit, or commit failed.
    pause
    exit /b 1
)

echo.
echo Pushing to origin/main...
git push origin main
if errorlevel 1 (
    echo.
    echo ERROR: Push failed.
    pause
    exit /b 1
)

echo.
echo Push successful.
git log --oneline -1
echo.
pause
endlocal