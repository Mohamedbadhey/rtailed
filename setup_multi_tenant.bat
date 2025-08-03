@echo off
echo Setting up Multi-Tenant Retail Management System...
echo.

echo Step 1: Running multi-tenant database setup...
mysql -u root -p retail_management < backend/add_multi_tenant_support.sql

echo.
echo Step 2: Verifying setup...
mysql -u root -p retail_management -e "SELECT COUNT(*) as business_count FROM businesses;"
mysql -u root -p retail_management -e "SELECT COUNT(*) as user_count FROM users;"

echo.
echo Multi-tenant setup completed!
echo.
echo Next steps:
echo 1. Start the backend server: npm start
echo 2. Start the frontend: flutter run -d web-server --web-port 8080
echo 3. Login as superadmin to manage businesses
echo.
pause 