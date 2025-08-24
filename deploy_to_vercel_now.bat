@echo off
echo 🚀 Deploying Flutter Web to Vercel...
echo.

echo 📁 Checking web build files...
if not exist "frontend\build\web\index.html" (
    echo ❌ Web build not found! Please run the build commands first.
    pause
    exit /b 1
)

echo ✅ Web build files found!
echo.

echo 📝 Adding web files to Git...
git add frontend/build/web/index.html
git add frontend/build/web/main.dart.js
git add frontend/build/web/flutter.js
git add frontend/build/web/manifest.json
git add frontend/build/web/favicon.png
git add frontend/build/web/icons/

echo 💾 Committing web build...
git commit -m "Add Flutter web build for Vercel deployment"

echo 🚀 Pushing to GitHub...
git push origin master

echo.
echo 🎉 Web build pushed to GitHub!
echo.
echo 🌐 Now deploy to Vercel:
echo 1. Go to vercel.com
echo 2. Import repository: Mohamedbadhey/rtailed
echo 3. Set Root Directory: frontend
echo 4. Set Build Command: chmod +x vercel-build.sh && ./vercel-build.sh
echo 5. Set Output Directory: build/web
echo 6. Click Deploy!
echo.
echo 📱 Your Flutter web app will be live on Vercel!
pause
