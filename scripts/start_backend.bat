@echo off
echo Starting Nimon backend (NestJS watch)...
echo.
cd /d "C:\Users\owner\Desktop\SAW_PROJ\nimon\nimon-backend"
if errorlevel 1 (
  echo ERROR: Could not cd to nimon-backend.
  pause
  exit /b 1
)
call npm run start:dev
echo.
echo Backend process ended.
pause
