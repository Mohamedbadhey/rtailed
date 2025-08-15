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
echo 📁 Your web app is ready in the 'build/web' folder
echo.
echo 🚂 To deploy to Railway:
echo.
echo 1. Copy the contents of 'build/web' folder
echo 2. Paste them into your Railway backend's public folder
echo 3. Or create a new Railway service for static hosting
echo.
echo 🌐 Your app will be accessible at your Railway URL
echo.
pause
