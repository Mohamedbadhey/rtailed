@echo off
echo 🏗️ Building Flutter Web App for Production
echo ==========================================
echo.

echo 🧹 Cleaning previous builds...
cd frontend
flutter clean

echo.
echo 📱 Building web app with production optimizations...
flutter build web --release --web-renderer canvaskit --dart-define=FLUTTER_WEB_USE_SKIA=true

if %errorlevel% neq 0 (
    echo ❌ Build failed! Please check Flutter installation.
    pause
    exit /b 1
)

echo.
echo ✅ Production build completed successfully!
echo 📁 Build location: frontend\build\web\
echo 📊 Bundle size optimized for production
echo 🚀 Ready for deployment to Vercel!
echo.

echo 📋 Next steps:
echo 1. Run 'quick_vercel_deploy.bat' to deploy to Vercel
echo 2. Or manually run: vercel --prod
echo.

pause
