@echo off
echo Starting Retail Management Backend Server...
echo.

cd backend

echo Installing dependencies...
npm install

echo.
echo Starting server...
echo Backend will be available at: http://localhost:3000
echo API Health Check: http://localhost:3000/api/health
echo.

npm start

pause 