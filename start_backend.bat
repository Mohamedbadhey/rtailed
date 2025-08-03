@echo off
echo Starting Retail Management Backend Server...
echo.

cd backend

echo Installing dependencies...
npm install

echo.
echo Starting server...
echo Backend will be available at: https://rtailed-production.up.railway.app
echo API Health Check: https://rtailed-production.up.railway.app/api/health
echo.

npm start

pause 