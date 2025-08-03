@echo off
echo ========================================
echo Update App Icon with Branding Logo
echo ========================================
echo.
echo This script will help you update your app icon
echo with your branding logo.
echo.
echo Steps:
echo 1. Copy your branding logo to this directory
echo 2. Rename it to 'app_icon.png'
echo 3. Run this script to generate app icons
echo.
echo Your branding logos are in: ../backend/uploads/branding/
echo.
echo Press any key to continue...
pause > nul

echo.
echo Copying branding logo...
copy "..\backend\uploads\branding\logo.png" "app_icon.png"

if exist "app_icon.png" (
    echo.
    echo ✅ Logo copied successfully!
    echo.
    echo 📋 Next steps:
    echo 1. Use an online icon generator like:
    echo    - https://appicon.co/
    echo    - https://www.appicon.co/
    echo    - https://makeappicon.com/
    echo.
    echo 2. Upload app_icon.png to generate all sizes
    echo.
    echo 3. Replace the icons in:
    echo    android/app/src/main/res/mipmap-*
    echo.
    echo Press any key to open the icon file...
    pause > nul
    start notepad "app_icon.png"
) else (
    echo.
    echo ❌ Error: Could not copy logo
    echo Make sure logo.png exists in branding folder
)

echo.
echo Press any key to exit...
pause > nul 