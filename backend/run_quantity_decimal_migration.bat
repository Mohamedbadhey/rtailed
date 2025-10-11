@echo off
echo ========================================
echo Migrating quantity fields to DECIMAL
echo ========================================
echo.
echo This will change all quantity-related fields from INT to DECIMAL(10,3)
echo to support decimal stock quantities.
echo.
echo WARNING: This will modify your database schema!
echo Make sure you have a backup before proceeding.
echo.
pause

echo.
echo Running migration...
mysql -u root -p < migrate_quantities_to_decimal.sql

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo Migration completed successfully!
    echo ========================================
    echo.
    echo All quantity fields have been updated to support decimal values.
    echo You can now use decimal stock quantities in your application.
) else (
    echo.
    echo ========================================
    echo Migration failed!
    echo ========================================
    echo.
    echo Please check the error messages above and try again.
)

echo.
pause
