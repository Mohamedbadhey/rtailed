@echo off
echo Building release AAB for SmartLedger...

REM Clean previous builds
echo Cleaning previous builds...
flutter clean

REM Get dependencies
echo Getting Flutter dependencies...
flutter pub get

REM Generate app icons
echo Generating app icons...
flutter pub run flutter_launcher_icons:main

REM Build release AAB
echo Building release AAB...
flutter build appbundle --release

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ AAB built successfully!
    echo.
    echo Your release AAB is located at:
    echo build\app\outputs\bundle\release\app-release.aab
    echo.
    echo Next steps:
    echo 1. Go to Google Play Console
    echo 2. Create a new app or select existing app
    echo 3. Upload the AAB file
    echo 4. Complete store listing
    echo 5. Submit for review
    echo.
) else (
    echo.
    echo ❌ Build failed! Please check the error messages above.
    echo.
)

pause
