@echo off
echo ========================================
echo    Deploying Flutter App to Web
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
echo 🌐 To deploy to a hosting service:
echo.
echo 1. FIREBASE (Recommended - Free):
echo    npm install -g firebase-tools
echo    firebase login
echo    firebase init hosting
echo    firebase deploy
echo.
echo 2. NETLIFY (Free):
echo    npm install -g netlify-cli
echo    netlify login
echo    netlify deploy --prod --dir=build/web
echo.
echo 3. VERCEL (Free):
echo    npm install -g vercel
echo    vercel build/web
echo.
echo 4. GITHUB PAGES (Free):
echo    Upload build/web contents to gh-pages branch
echo.
pause
