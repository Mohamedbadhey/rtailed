@echo off
echo Fixing store_business_assignments table...
echo.

REM Run the SQL fix
mysql -u root -p retail_management < fix_store_business_assignments_table.sql

echo.
echo Fix completed! The assignment history should now work.
echo.
pause
