@echo off
echo ========================================
echo Railway Database Setup Helper
echo ========================================
echo.
echo This script will copy your database file content
echo for easy pasting into Railway's SQL editor.
echo.
echo Your database file: retail_management (3).sql
echo.
echo Steps:
echo 1. Run this script
echo 2. Copy the content from the generated file
echo 3. Paste into Railway's SQL editor
echo.
echo Press any key to continue...
pause > nul

echo.
echo Copying database content...
copy "retail_management (3).sql" "railway_database_ready.sql"

if exist "railway_database_ready.sql" (
    echo.
    echo ✅ Success! Database file ready for Railway
    echo.
    echo 📁 File created: railway_database_ready.sql
    echo.
    echo 📋 Next steps:
    echo 1. Open railway_database_ready.sql in a text editor
    echo 2. Copy all content (Ctrl+A, Ctrl+C)
    echo 3. Go to Railway MySQL database
    echo 4. Click "Query" tab
    echo 5. Paste and execute
    echo.
    echo Press any key to open the file...
    pause > nul
    start notepad "railway_database_ready.sql"
) else (
    echo.
    echo ❌ Error: Could not create database file
    echo Make sure 'retail_management (3).sql' exists in this directory
)

echo.
echo Press any key to exit...
pause > nul 