@echo off
setlocal

echo.
echo === PUSH MAIN ===
echo.

cd /d "%~dp0"

for /f "delims=" %%i in ('git branch --show-current') do set CURRENT_BRANCH=%%i

if /I not "%CURRENT_BRANCH%"=="main" (
    echo ERROR: Current branch is "%CURRENT_BRANCH%".
    echo Switch to main before pushing.
    pause
    exit /b 1
)

echo Current branch: %CURRENT_BRANCH%
echo.

echo Syncing with origin/main first...
git pull origin main

if errorlevel 1 (
    echo.
    echo Pull failed. Resolve that first before pushing.
    pause
    exit /b 1
)

echo.
git status
echo.

set /p MSG=Enter commit message: 

if "%MSG%"=="" (
    echo ERROR: Commit message cannot be blank.
    pause
    exit /b 1
)

git add .
git commit -m "%MSG%"

if errorlevel 1 (
    echo.
    echo Commit failed or nothing to commit.
    pause
    exit /b 1
)

git push origin main

if errorlevel 1 (
    echo.
    echo Push failed.
    pause
    exit /b 1
)

echo.
echo Push to main complete.
pause
endlocal