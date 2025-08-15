@echo off
echo ========================================
echo    Firebase Web Deployment
echo ========================================
echo.

REM Check if Firebase CLI is installed
firebase --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Firebase CLI not found!
    echo.
    echo Installing Firebase CLI...
    npm install -g firebase-tools
    
    if %errorlevel% neq 0 (
        echo ❌ Installation failed! Please install manually:
        echo npm install -g firebase-tools
        pause
        exit /b 1
    )
)

echo ✅ Firebase CLI ready
echo.

REM Build the Flutter web app
echo 🔨 Building Flutter web app...
flutter build web --release

if %errorlevel% neq 0 (
    echo ❌ Build failed!
    pause
    exit /b 1
)

echo ✅ Build completed successfully!
echo.

REM Check if firebase.json exists
if not exist "firebase.json" (
    echo 📝 Initializing Firebase project...
    firebase init hosting
    
    echo.
    echo ⚠️  IMPORTANT: During Firebase setup:
    echo    - Select your project
    echo    - Set public directory to: build/web
    echo    - Configure as single-page app: Yes
    echo    - Don't overwrite index.html
    echo.
    pause
)

echo 🚀 Deploying to Firebase...
firebase deploy

if %errorlevel% equ 0 (
    echo.
    echo 🎉 Deployment successful!
    echo Your Flutter app is now live on the web!
    echo.
    echo 🌐 View your app: firebase open hosting:site
    echo 📱 Share the link with anyone - they can access it from any browser!
) else (
    echo.
    echo ❌ Deployment failed!
    echo Check the error messages above.
)

echo.
pause
