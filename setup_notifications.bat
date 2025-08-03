@echo off
echo Setting up notification tables...
echo.

REM Check if MySQL is available
mysql --version >nul 2>&1
if errorlevel 1 (
    echo Error: MySQL is not installed or not in PATH
    echo Please install MySQL or add it to your PATH
    pause
    exit /b 1
)

echo Running notification setup script...
mysql -u root -p retail_management < backend/setup_notifications.sql

if errorlevel 1 (
    echo Error: Failed to run the setup script
    echo Please check your MySQL credentials and database name
    pause
    exit /b 1
)

echo.
echo Notification tables setup completed successfully!
echo You can now restart your backend server.
pause 