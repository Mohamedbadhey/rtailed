@echo off
echo ========================================
echo Fixing Businesses Endpoint Issue
echo ========================================
echo.

echo Step 1: Checking database connection...
node backend/test_businesses_endpoint.js

echo.
echo Step 2: Setting up database if needed...
echo.

echo Running initial database setup...
mysql -u root -p retail_management < backend/src/config/schema.sql

echo.
echo Running multi-tenant setup...
mysql -u root -p retail_management < backend/add_multi_tenant_support.sql

echo.
echo Running additional column setup...
mysql -u root -p retail_management < backend/add_is_deleted_columns.sql

echo.
echo Step 3: Verifying setup...
mysql -u root -p retail_management -e "SELECT COUNT(*) as business_count FROM businesses;"
mysql -u root -p retail_management -e "SELECT COUNT(*) as user_count FROM users;"

echo.
echo Step 4: Testing the endpoint...
echo Starting backend server for testing...
start /B npm start --prefix backend

echo Waiting for server to start...
timeout /t 5 /nobreak > nul

echo Testing businesses endpoint...
curl -X GET https://rtailed-production.up.railway.app/api/businesses -H "Content-Type: application/json"

echo.
echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo Next steps:
echo 1. Start the backend server: cd backend && npm start
echo 2. Start the frontend: flutter run -d web-server --web-port 8080
echo 3. Login as superadmin to access the businesses tab
echo.
echo If you still see "failed to fetch business" error:
echo 1. Check that the backend server is running on port 3000
echo 2. Check that you're logged in as a superadmin user
echo 3. Check the browser console for any CORS or network errors
echo.
pause 