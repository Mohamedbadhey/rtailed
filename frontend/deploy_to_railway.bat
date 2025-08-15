@echo off
echo ========================================
echo    Railway Flutter Web Deployment
echo ========================================
echo.

echo 🔨 Building Flutter web app...
flutter build web --release

if %errorlevel% neq 0 (
    echo ❌ Build failed!
    pause
    exit /b 1
)

echo ✅ Build completed successfully!
echo.

echo 🚂 Preparing for Railway deployment...
echo.

REM Create web-app directory in backend
if not exist "..\backend\web-app" (
    echo 📁 Creating web-app directory in backend...
    mkdir "..\backend\web-app"
)

echo 📋 Copying Flutter web app to backend...
xcopy "build\web\*" "..\backend\web-app\" /E /Y /Q

if %errorlevel% equ 0 (
    echo ✅ Flutter web app copied to backend successfully!
    echo.
    echo 🎯 Next steps:
    echo 1. Commit and push your backend changes to Railway
    echo 2. Your Flutter app will be accessible at your Railway URL
    echo 3. No separate hosting needed - everything runs on Railway!
    echo.
    echo 🌐 Your app will be available at:
    echo    https://your-railway-app.up.railway.app
    echo.
    echo 📱 Users can access it from any browser with just that link!
) else (
    echo ❌ Failed to copy web app to backend
    echo Please check the paths and try again
)

echo.
pause
