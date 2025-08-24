@echo off
echo 🔨 Rebuilding Flutter Web App...
echo.

echo 📱 Building Flutter web app...
cd frontend
flutter build web --release

echo.
echo 📁 Copying web build to backend...
if exist "build\web" (
    xcopy "build\web\*" "..\backend\web-app\" /E /Y /Q
    echo ✅ Web app copied to backend successfully!
) else (
    echo ❌ Web build not found. Please ensure Flutter is installed and build completed.
    pause
    exit /b 1
)

echo.
echo 🌐 Web app rebuilt and ready to serve!
echo 📍 Access at: http://localhost:3000
echo.
pause
