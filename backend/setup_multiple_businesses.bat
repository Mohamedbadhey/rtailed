@echo off
echo Setting up Multiple Businesses with Unique Data...
echo.

echo 1. Updating database schema...
mysql -u root -p retail_management < add_business_id_to_system_logs.sql

echo.
echo 2. Creating multiple businesses with unique data...
mysql -u root -p retail_management < create_multiple_businesses_with_data.sql

echo.
echo 3. Multiple businesses setup completed successfully!
echo.
echo Business Summary:
echo - TechMart Electronics (ID: 1): Premium plan, 4 users, 5 products, 5 sales
echo - FreshGrocer Market (ID: 2): Basic plan, 3 users, 5 products, 4 sales  
echo - FashionHub Boutique (ID: 3): Enterprise plan, 5 users, 5 products, 5 sales
echo - HomeDecor Plus (ID: 4): Basic plan, 2 users, 0 products, 0 sales (inactive)
echo - SportsZone Equipment (ID: 5): Premium plan, 3 users, 5 products, 4 sales
echo.
echo 4. Starting backend server...
echo.
cd ..
npm start

pause 