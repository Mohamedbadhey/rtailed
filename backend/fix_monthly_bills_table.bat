@echo off
echo Fixing monthly_bills table structure...
echo.

REM Check if MySQL is available
mysql --version >nul 2>&1
if errorlevel 1 (
    echo Error: MySQL is not installed or not in PATH
    echo Please install MySQL or add it to your PATH
    pause
    exit /b 1
)

REM Run the SQL script to fix the table
echo Running SQL script to fix monthly_bills table...
mysql -u root -p retail_management < check_monthly_bills_table.sql

if errorlevel 1 (
    echo Error: Failed to run SQL script
    echo Please check your MySQL credentials and database name
    pause
    exit /b 1
)

echo.
echo Monthly bills table fixed successfully!
echo.
echo The table now has all required columns including:
echo - updated_at (with automatic timestamp updates)
echo - All billing columns (base_amount, overage_fees, etc.)
echo - Proper indexes for performance
echo.
pause 