@echo off
echo Updating database schema for business details support...

REM Add business_id column to system_logs table
mysql -u root -p retail_management < add_business_id_to_system_logs.sql

echo Database schema updated successfully!
echo.
echo Now you can start the backend server to test the business details functionality.
pause 