@echo off
echo Testing Credit Payment Fix...
echo.

echo 1. Checking if Node.js is installed...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)

echo 2. Checking if required packages are installed...
if not exist "node_modules" (
    echo Installing required packages...
    npm install
    if %errorlevel% neq 0 (
        echo ERROR: Failed to install packages
        pause
        exit /b 1
    )
)

echo 3. Running credit payment fix test...
echo.
node test_credit_payment_fix.js

echo.
echo Test completed. Check the output above for results.
echo.
pause
