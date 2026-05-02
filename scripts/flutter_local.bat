@echo off
echo Flutter run (local-first drafts, default)...
echo.
cd /d "C:\Users\owner\Desktop\SAW_PROJ\nimon"
if errorlevel 1 (
  echo ERROR: Could not cd to project root.
  pause
  exit /b 1
)
call flutter run
echo.
echo Flutter process ended.
pause
