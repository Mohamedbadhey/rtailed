@echo off
echo 🚀 Deploying Flutter Web App to Vercel...
echo.

echo 📱 Building Flutter web app for production...
cd frontend
flutter build web --release --web-renderer canvaskit

echo.
echo 📁 Checking build output...
if not exist "build\web" (
    echo ❌ Web build failed. Please check Flutter installation.
    pause
    exit /b 1
)

echo ✅ Web build completed successfully!
echo.

echo 🔧 Installing Vercel CLI...
npm install -g vercel

echo.
echo 📤 Deploying to Vercel...
vercel --prod

echo.
echo 🎉 Deployment completed!
echo 📍 Your app will be available at the URL shown above
echo.
pause
