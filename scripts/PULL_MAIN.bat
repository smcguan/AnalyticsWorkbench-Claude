@echo off
setlocal

echo.
echo === PULL MAIN ===
echo.

cd /d "%~dp0"

for /f "delims=" %%i in ('git branch --show-current') do set CURRENT_BRANCH=%%i

if /I not "%CURRENT_BRANCH%"=="main" (
    echo ERROR: Current branch is "%CURRENT_BRANCH%".
    echo Switch to main before pulling.
    pause
    exit /b 1
)

echo Current branch: %CURRENT_BRANCH%
echo.

git status
echo.

choice /M "Continue with pull from origin/main"
if errorlevel 2 (
    echo Pull cancelled.
    pause
    exit /b 0
)

git pull origin main

if errorlevel 1 (
    echo.
    echo Pull failed.
    pause
    exit /b 1
)

echo.
echo Pull from main complete.
pause
endlocal