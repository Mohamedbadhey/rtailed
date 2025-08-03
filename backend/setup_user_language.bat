@echo off
echo Adding language column to users table...
mysql -u root -p retail_management < add_language_column_to_users.sql
echo Language column added successfully!
pause 