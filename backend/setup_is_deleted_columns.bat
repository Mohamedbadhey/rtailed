@echo off
echo Running migration to add is_deleted and business_id columns...
echo.

REM Check if MySQL is available
mysql --version >nul 2>&1
if errorlevel 1 (
    echo Error: MySQL command line client not found in PATH
    echo Please make sure MySQL is installed and mysql command is available
    pause
    exit /b 1
)

REM Run the migration script
echo Executing migration script...
mysql -u root -p < add_is_deleted_columns.sql

if errorlevel 1 (
    echo.
    echo Error: Migration failed!
    echo Please check the error messages above and try again.
    pause
    exit /b 1
)

echo.
echo Migration completed successfully!
echo The following columns have been added:
echo - business_id and is_deleted to users table
echo - business_id and is_deleted to products table  
echo - business_id and is_deleted to categories table
echo - business_id and is_deleted to customers table
echo - business_id and is_deleted to sales table
echo - business_id to vendors, expenses, accounts_payable, and cash_flows tables
echo.
echo Data recovery functionality should now work properly.
pause 