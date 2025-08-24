@echo off
echo 🚀 Quick Vercel Deployment for Flutter Web App
echo ================================================
echo.

echo 📱 Step 1: Building Flutter Web App...
cd frontend
flutter build web --release --web-renderer canvaskit

if %errorlevel% neq 0 (
    echo ❌ Build failed! Please check Flutter installation.
    pause
    exit /b 1
)

echo ✅ Build successful!
echo.

echo 📤 Step 2: Deploying to Vercel...
echo.
echo 📋 Instructions:
echo 1. If this is your first time, you'll be prompted to login
echo 2. Choose your Vercel account/team
echo 3. Select your project or create a new one
echo 4. Wait for deployment to complete
echo.

vercel --prod

echo.
echo 🎉 Deployment completed!
echo 📍 Your app is now live on Vercel!
echo.
pause
