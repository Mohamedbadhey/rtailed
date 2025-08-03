@echo off
echo Creating business_usage table...
echo.

REM Check if MySQL is available
mysql --version >nul 2>&1
if errorlevel 1 (
    echo Error: MySQL is not installed or not in PATH
    echo Please install MySQL or add it to your PATH
    pause
    exit /b 1
)

REM Run the SQL script to create the table
echo Running SQL script to create business_usage table...
mysql -u root -p retail_management < create_business_usage_table.sql

if errorlevel 1 (
    echo Error: Failed to run SQL script
    echo Please check your MySQL credentials and database name
    pause
    exit /b 1
)

echo.
echo Business usage table created successfully!
echo.
echo The table now has all required columns:
echo - business_id (links to businesses)
echo - date (for daily tracking)
echo - users_count (current user count)
echo - products_count (current product count)
echo - user_overage (users exceeding limit)
echo - product_overage (products exceeding limit)
echo - total_overage_fee (calculated overage fees)
echo.
pause 