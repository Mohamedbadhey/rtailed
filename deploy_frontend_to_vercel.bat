@echo off
echo 🚀 Deploying Flutter Frontend to Vercel
echo =======================================
echo.
echo 📍 Backend: Railway (https://rtailed-production.up.railway.app)
echo 🌐 Frontend: Vercel
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
echo 📋 Deployment Instructions:
echo 1. If first time, you'll be prompted to login to Vercel
echo 2. Choose your Vercel account/team
echo 3. Select your project or create a new one
echo 4. Wait for deployment to complete
echo.

vercel --prod

echo.
echo 🎉 Frontend deployment completed!
echo 📍 Your Flutter web app is now live on Vercel!
echo 🔗 Backend API: https://rtailed-production.up.railway.app
echo.
pause
