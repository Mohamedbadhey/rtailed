@echo off
echo ========================================
echo  Clean Build and Generate Fresh AAB
echo  SmartLedger - Retail Management System
echo ========================================
echo.

cd frontend

echo [1/6] Cleaning old build files...
echo Removing all previous build artifacts...
if exist "build" (
    rmdir /s /q "build"
    echo    ✓ Removed build folder
)
if exist "android\app\build" (
    rmdir /s /q "android\app\build"
    echo    ✓ Removed android/app/build folder
)
if exist "android\build" (
    rmdir /s /q "android\build"
    echo    ✓ Removed android/build folder
)
if exist ".dart_tool" (
    rmdir /s /q ".dart_tool"
    echo    ✓ Removed .dart_tool folder
)
echo.

echo [2/6] Running Flutter clean...
call flutter clean
echo    ✓ Flutter clean completed
echo.

echo [3/6] Getting Flutter dependencies...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo    ✗ Failed to get dependencies!
    pause
    exit /b 1
)
echo    ✓ Dependencies fetched
echo.

echo [4/6] Generating app icons...
call flutter pub run flutter_launcher_icons:main
if %ERRORLEVEL% NEQ 0 (
    echo    ⚠ Warning: Icon generation had issues (continuing anyway)
)
echo    ✓ Icons generated
echo.

echo [5/6] Building release AAB...
echo This may take a few minutes...
call flutter build appbundle --release
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo    ✗✗✗ BUILD FAILED! ✗✗✗
    echo.
    echo Please check the error messages above and fix them.
    echo Common issues:
    echo   - Missing Android SDK
    echo   - Keystore not found
    echo   - Gradle build errors
    echo   - Network connectivity issues
    echo.
    pause
    exit /b 1
)
echo    ✓ AAB built successfully!
echo.

echo [6/6] Checking generated AAB...
if exist "build\app\outputs\bundle\release\app-release.aab" (
    echo    ✓ AAB file found!
    echo.
    echo ========================================
    echo  ✅ SUCCESS! AAB GENERATED
    echo ========================================
    echo.
    echo 📦 Your fresh AAB file is located at:
    echo    frontend\build\app\outputs\bundle\release\app-release.aab
    echo.
    echo 📊 File Information:
    for %%A in ("build\app\outputs\bundle\release\app-release.aab") do (
        echo    Size: %%~zA bytes
        echo    Date: %%~tA
    )
    echo.
    echo 🚀 Next Steps:
    echo    1. Go to Google Play Console
    echo    2. Navigate to your app
    echo    3. Go to Release ^> Production ^> Create new release
    echo    4. Upload: frontend\build\app\outputs\bundle\release\app-release.aab
    echo    5. Fill in release notes
    echo    6. Review and roll out
    echo.
    echo 📝 Current Version: 1.0.0+9
    echo    (Version code: 9)
    echo.
    echo ⚠️  IMPORTANT REMINDERS:
    echo    - Keep your keystore file safe (upload-keystore-new.jks)
    echo    - Never share your key.properties file
    echo    - Test the AAB before uploading to Play Store
    echo    - For next release, increment version to 1.0.0+10
    echo.
) else (
    echo    ✗ AAB file not found at expected location!
    echo.
    echo The build reported success but AAB file is missing.
    echo Please check the build output above for any issues.
    echo.
)

cd ..
echo ========================================
pause
