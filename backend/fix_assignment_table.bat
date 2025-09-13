@echo off
echo Fixing store_business_assignments table...
echo.

REM Run the SQL script to add the missing removed_at column
mysql -u root -p retail_management < add_removed_at_column.sql

echo.
echo Done! The removed_at column has been added to the store_business_assignments table.
echo The assignment history should now work without 500 errors.
pause
