@echo off
echo ========================================
echo  Version Update and AAB Rebuild
echo  SmartLedger - Play Store Submission
echo ========================================
echo.

echo Current version in frontend/pubspec.yaml:
findstr "version:" frontend\pubspec.yaml
echo.

echo ========================================
echo.
echo The version has been updated to 1.0.0+6
echo This will resolve the "version code already used" error.
echo.
echo Now rebuilding AAB with new version...
echo.
pause

cd frontend

echo [1/4] Cleaning previous build...
call flutter clean
echo.

echo [2/4] Getting dependencies...
call flutter pub get
echo.

echo [3/4] Generating icons...
call flutter pub run flutter_launcher_icons:main
echo.

echo [4/4] Building AAB with version 1.0.0+6...
call flutter build appbundle --release

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo  ✅ SUCCESS! NEW AAB GENERATED
    echo ========================================
    echo.
    echo Version: 1.0.0+6 (Build Code: 6)
    echo.
    if exist "android\app\build\outputs\bundle\release\app-release.aab" (
        echo 📦 AAB Location:
        echo    frontend\android\app\build\outputs\bundle\release\app-release.aab
        echo.
        for %%A in ("android\app\build\outputs\bundle\release\app-release.aab") do (
            echo 📊 Size: %%~zA bytes
            echo 📅 Created: %%~tA
        )
        echo.
        echo ✅ This AAB has version code 6 and can be uploaded!
        echo.
    )
) else (
    echo.
    echo ❌ Build failed! Check errors above.
    echo.
)

cd ..
pause
