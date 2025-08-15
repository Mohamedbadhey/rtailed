@echo off
echo 🧪 Testing deployment setup...

echo.
echo 📋 Checking required files...
if exist "package.json" (
    echo ✅ package.json found
) else (
    echo ❌ package.json missing
    pause
    exit /b 1
)

if exist "frontend\pubspec.yaml" (
    echo ✅ Flutter frontend found
) else (
    echo ❌ Flutter frontend missing
    pause
    exit /b 1
)

if exist "backend\package.json" (
    echo ✅ Backend found
) else (
    echo ❌ Backend missing
    pause
    exit /b 1
)

echo.
echo 🔧 Testing Flutter web build...
cd frontend
flutter --version >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ Flutter is installed
    echo 📦 Getting dependencies...
    flutter pub get
    echo 🏗️ Building web app...
    flutter build web --web-renderer canvaskit
    if exist "build\web\index.html" (
        echo ✅ Flutter web build successful!
    ) else (
        echo ❌ Flutter web build failed!
    )
) else (
    echo ❌ Flutter not installed or not in PATH
    echo Please install Flutter first: https://flutter.dev/docs/get-started/install
)

cd ..
echo.
echo 🎯 Deployment setup test completed!
echo.
echo 🚀 To deploy on Railway:
echo 1. Push your code to Railway
echo 2. Railway will automatically build and deploy
echo 3. Your Flutter app will be available at your Railway URL
echo.
pause
