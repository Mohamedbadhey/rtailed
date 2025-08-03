@echo off
echo Setting up Business Details functionality...
echo.

echo 1. Updating database schema...
mysql -u root -p retail_management < add_business_id_to_system_logs.sql

echo.
echo 2. Inserting sample data...
mysql -u root -p retail_management < sample_business_details_data.sql

echo.
echo 3. Database setup completed successfully!
echo.
echo 4. Starting backend server...
echo.
cd ..
npm start

pause 