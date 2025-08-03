@echo off
echo Testing Branding System...
echo.

REM Check if Node.js is available
node --version >nul 2>&1
if errorlevel 1 (
    echo Error: Node.js not found in PATH
    echo Please make sure Node.js is installed and node command is available
    pause
    exit /b 1
)

REM Check if axios is installed
node -e "require('axios')" >nul 2>&1
if errorlevel 1 (
    echo Installing axios...
    npm install axios
)

REM Run the test
echo Running branding system test...
node test_branding_system.js

if errorlevel 1 (
    echo.
    echo Test failed! Please check the error messages above.
    pause
    exit /b 1
)

echo.
echo Branding system test completed successfully!
pause 