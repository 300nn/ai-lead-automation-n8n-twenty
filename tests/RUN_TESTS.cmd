@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-all-tests.ps1" -N8nContainer "lead-automatisation"
set RC=%ERRORLEVEL%
echo.
if not "%RC%"=="0" (
  echo Regression suite finished with failures. Exit code: %RC%
) else (
  echo Regression suite passed.
)
pause
exit /b %RC%
