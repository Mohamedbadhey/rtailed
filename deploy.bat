@echo off
echo 🚀 Starting deployment process...

REM Check if we're in the right directory
if not exist "package.json" (
    echo ❌ Error: package.json not found. Please run this script from the project root.
    pause
    exit /b 1
)

echo 📦 Installing backend dependencies...
call npm install

echo 🎉 Deployment setup completed!
echo 🚀 Starting the application...

REM Start the application
call npm start

pause
