@echo off
echo Setting up billing tables for revenue analytics...
echo.

REM Check if MySQL is available
mysql --version >nul 2>&1
if errorlevel 1 (
    echo Error: MySQL is not installed or not in PATH
    echo Please install MySQL or add it to your PATH
    pause
    exit /b 1
)

REM Run the SQL script
echo Running SQL script to create billing tables...
mysql -u root -p retail_management < create_billing_tables.sql

if errorlevel 1 (
    echo Error: Failed to run SQL script
    echo Please check your MySQL credentials and database name
    pause
    exit /b 1
)

echo.
echo Billing tables setup completed successfully!
echo.
echo Tables created:
echo - subscription_plans
echo - monthly_bills (if not exists)
echo - Added billing columns to businesses table
echo.
echo Default subscription plans added:
echo - Basic: $29.99/month
echo - Premium: $99.99/month  
echo - Enterprise: $299.99/month
echo.
pause 