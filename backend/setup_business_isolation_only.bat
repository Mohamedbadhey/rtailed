@echo off
echo ========================================
echo Business Data Isolation Setup (Schema Only)
echo ========================================
echo.

echo 1. Updating database schema for business isolation...
mysql -u root -p retail_management < add_business_isolation_schema_only.sql

echo.
echo 2. Schema update completed successfully!
echo.
echo Your existing business data will now be properly isolated.
echo Each business will show only their own unique analytics data.
echo.
echo 3. Starting backend server...
echo.
cd ..
npm start

pause 