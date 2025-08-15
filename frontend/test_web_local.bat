@echo off
echo ========================================
echo    Testing Flutter Web App Locally
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

echo 🌐 Starting local web server...
echo Your app will open in your default browser
echo.
echo To stop the server, press Ctrl+C
echo.

REM Start the local web server
python -m http.server 8000 --directory build/web

echo.
echo Server stopped.
pause
