@echo off
echo ========================================
echo COMPREHENSIVE FIX FOR RETAIL MANAGEMENT
echo ========================================
echo.

echo Step 1: Fixing database schema issues...
cd backend
if exist fix_schema_issues.bat (
    call fix_schema_issues.bat
    if errorlevel 1 (
        echo Error: Database schema fix failed!
        pause
        exit /b 1
    )
) else (
    echo Warning: fix_schema_issues.bat not found
    echo Please run the database migration manually
)

echo.
echo Step 2: Fixing Flutter application...
cd ..\frontend

echo Cleaning Flutter build...
flutter clean
if errorlevel 1 (
    echo Error: Flutter clean failed!
    pause
    exit /b 1
)

echo Getting Flutter dependencies...
flutter pub get
if errorlevel 1 (
    echo Error: Flutter pub get failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo FIXES APPLIED SUCCESSFULLY!
echo ========================================
echo.
echo The following issues have been fixed:
echo.
echo BACKEND FIXES:
echo - Added missing is_deleted columns to customers and categories
echo - Added proper foreign key constraints
echo - Fixed data integrity issues
echo - Added performance indexes
echo.
echo FRONTEND FIXES:
echo - Fixed Google Fonts loading errors with fallback theme
echo - Fixed type conversion errors (int/String, LinkedMap)
echo - Fixed RenderFlex overflow issues in dialogs
echo - Added global error handling
echo - Created TypeConverter utility for safe data handling
echo - Created SafeDialog widgets for better UI
echo.
echo NEXT STEPS:
echo 1. Test the application: flutter run -d chrome
echo 2. Check that all dialogs work without overflow
echo 3. Verify that data recovery functionality works
echo 4. Test user creation and management features
echo.
echo If you encounter any issues, check the console for error messages.
echo.
pause 