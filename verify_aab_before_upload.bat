@echo off
echo ========================================
echo  Verify AAB Before Upload
echo  SmartLedger - Play Store Check
echo ========================================
echo.

cd frontend

set AAB_PATH=build\app\outputs\bundle\release\app-release.aab

echo Checking for AAB file...
if not exist "%AAB_PATH%" (
    echo ✗ AAB file not found!
    echo.
    echo Expected location: %AAB_PATH%
    echo.
    echo Please run 'clean_and_build_fresh_aab.bat' first to generate the AAB.
    echo.
    cd ..
    pause
    exit /b 1
)

echo ✓ AAB file found!
echo.

echo ========================================
echo  AAB File Information
echo ========================================
echo.
for %%A in ("%AAB_PATH%") do (
    echo File Path: %%~fA
    echo File Size: %%~zA bytes (%%~zA / 1048576 MB)
    echo Created:   %%~tA
)
echo.

echo ========================================
echo  App Configuration Details
echo ========================================
echo.

echo Reading version from pubspec.yaml...
findstr /C:"version:" ..\pubspec.yaml
echo.

echo ========================================
echo  Keystore Configuration
echo ========================================
echo.
if exist "android\key.properties" (
    echo ✓ Keystore configuration found
    type android\key.properties | findstr /V "Password"
) else (
    echo ✗ Keystore configuration missing!
)
echo.

echo ========================================
echo  Pre-Upload Checklist
echo ========================================
echo.
echo [ ] AAB file exists and is not empty
echo [ ] File size is reasonable (usually 20-50 MB)
echo [ ] Version code is incremented from previous release
echo [ ] App was tested on physical device
echo [ ] All features work correctly
echo [ ] No debug code or test data included
echo [ ] Privacy policy link is ready (if required)
echo [ ] Store listing is complete
echo [ ] Screenshots are ready
echo.

echo ========================================
echo  Ready to Upload?
echo ========================================
echo.
echo If all checks pass, you can upload the AAB to:
echo https://play.google.com/console
echo.
echo Your AAB file location:
echo %CD%\%AAB_PATH%
echo.
echo You can also test the AAB using bundletool:
echo https://github.com/google/bundletool
echo.

cd ..
pause
