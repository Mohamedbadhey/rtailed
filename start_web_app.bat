@echo off
echo 🚀 Starting Retail Management System with Flutter Web...
echo.

echo 📱 Starting Backend Server...
cd backend
start "Backend Server" cmd /k "npm start"

echo.
echo ⏳ Waiting for backend to start...
timeout /t 3 /nobreak >nul

echo.
echo 🌐 Opening Flutter Web App in browser...
echo 📍 Web App URL: http://localhost:3000
echo 📍 API URL: http://localhost:3000/api
echo.

start http://localhost:3000

echo.
echo ✅ System started successfully!
echo 📱 Backend running on port 3000
echo 🌐 Flutter Web App accessible at http://localhost:3000
echo.
echo Press any key to exit this window...
pause >nul
