@echo off
echo Setting up Business Deactivation System...
echo.

REM Check if MySQL is running
echo Checking MySQL connection...
mysql -u root -p -e "SELECT 1;" >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: MySQL is not running or credentials are incorrect.
    echo Please make sure MySQL is running and you have the correct credentials.
    pause
    exit /b 1
)

echo MySQL connection successful.
echo.

REM Run the business deactivation SQL script
echo Running business deactivation system setup...
mysql -u root -p retail_management < add_business_deactivation_system.sql

if %errorlevel% equ 0 (
    echo.
    echo Business deactivation system setup completed successfully!
    echo.
    echo Features added:
    echo - Business payment status tracking
    echo - Automatic business suspension for overdue payments
    echo - Grace period management
    echo - Payment status logging
    echo - Suspension notifications
    echo - Daily automatic payment status checks
    echo.
    echo The system will now:
    echo - Check business payment status daily
    echo - Automatically suspend businesses with overdue payments
    echo - Prevent users from logging in to suspended businesses
    echo - Allow superadmins to manually manage business status
    echo.
) else (
    echo.
    echo Error: Failed to set up business deactivation system.
    echo Please check the SQL script and try again.
    echo.
)

pause 