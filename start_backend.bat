@echo off
echo Starting Retail Management Backend Server...
echo.

cd backend

echo Installing dependencies...
npm install

echo.
echo Starting server...

REM Configure HOST/PORT defaults for local run
if "%PORT%"=="" set PORT=3000
if "%HOST%"=="" set HOST=0.0.0.0

set "BOUND_URL=http://%HOST%:%PORT%"
set "LOCAL_URL=http://localhost:%PORT%"

echo.
echo Bound Address: %BOUND_URL%
echo Open in browser (Local): %LOCAL_URL%
echo API Health Check: %LOCAL_URL%/api/health
echo.

npm start

pause 