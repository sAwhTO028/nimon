@echo off
echo Flutter run (remote drafts - syncs to API / Postgres)...
echo.
cd /d "C:\Users\owner\Desktop\SAW_PROJ\nimon"
if errorlevel 1 (
  echo ERROR: Could not cd to project root.
  pause
  exit /b 1
)
call flutter run --dart-define=NIMON_USE_REMOTE_DRAFTS=true
echo.
echo Flutter process ended.
pause
