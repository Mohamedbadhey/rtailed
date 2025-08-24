@echo off
echo 🚀 Building Fresh Flutter Web App with Updated Flutter...
echo.

echo 📱 Checking Flutter version...
flutter --version

echo.
echo 🧹 Cleaning previous builds...
cd frontend
flutter clean

echo.
echo 📦 Getting latest dependencies...
flutter pub get

echo.
echo 🏗️ Building fresh web app...
flutter build web --release --web-renderer canvaskit

echo.
echo ✅ Fresh web build completed!
echo 📁 Build location: frontend\build\web\
echo 📊 Checking build output...
dir build\web

echo.
echo 🎯 Essential files for Vercel:
echo - index.html
echo - main.dart.js  
echo - flutter.js
echo - manifest.json
echo - favicon.png
echo - icons\Icon-*.png

echo.
echo 🌐 Ready for Vercel deployment!
pause
