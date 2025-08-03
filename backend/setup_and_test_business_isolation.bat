@echo off
echo ========================================
echo Business Data Isolation Setup and Test
echo ========================================
echo.

echo 1. Updating database schema...
mysql -u root -p retail_management < add_business_id_to_system_logs.sql

echo.
echo 2. Creating multiple businesses with unique data...
mysql -u root -p retail_management < create_multiple_businesses_with_data.sql

echo.
echo 3. Testing business data isolation...
mysql -u root -p retail_management < test_business_isolation.sql

echo.
echo ========================================
echo Setup and Testing Completed!
echo ========================================
echo.
echo Expected Results:
echo - Each business should have unique users, products, sales, customers
echo - No cross-business data contamination
echo - Each business analytics will show only their own data
echo.
echo 4. Starting backend server...
echo.
cd ..
npm start

pause 