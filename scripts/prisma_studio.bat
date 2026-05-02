@echo off
echo Starting Prisma Studio (nimon-backend)...
echo.
cd /d "C:\Users\owner\Desktop\SAW_PROJ\nimon\nimon-backend"
if errorlevel 1 (
  echo ERROR: Could not cd to nimon-backend.
  pause
  exit /b 1
)
call npm run prisma:studio
echo.
echo Prisma Studio process ended.
pause
