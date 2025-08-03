@echo off
echo ========================================
echo Business Deactivation System Setup
echo ========================================
echo.

REM Check if MySQL is running
echo [1/5] Checking MySQL connection...
mysql -u root -p -e "SELECT 1;" >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Error: MySQL is not running or credentials are incorrect.
    echo Please make sure MySQL is running and you have the correct credentials.
    pause
    exit /b 1
)
echo ✅ MySQL connection successful.
echo.

REM Run the business deactivation SQL script
echo [2/5] Setting up business deactivation database...
mysql -u root -p retail_management < backend/add_business_deactivation_system.sql

if %errorlevel% neq 0 (
    echo ❌ Error: Failed to set up business deactivation database.
    echo Please check the SQL script and try again.
    pause
    exit /b 1
)
echo ✅ Business deactivation database setup completed.
echo.

REM Run the monthly billing setup if not already done
echo [3/5] Setting up monthly billing system...
if exist "backend/add_monthly_billing_and_backup.sql" (
    mysql -u root -p retail_management < backend/add_monthly_billing_and_backup.sql
    echo ✅ Monthly billing system setup completed.
) else (
    echo ⚠️  Monthly billing script not found, skipping...
)
echo.

REM Run the subscription billing setup if not already done
echo [4/5] Setting up subscription billing system...
if exist "backend/add_subscription_based_billing.sql" (
    mysql -u root -p retail_management < backend/add_subscription_based_billing.sql
    echo ✅ Subscription billing system setup completed.
) else (
    echo ⚠️  Subscription billing script not found, skipping...
)
echo.

REM Test the system
echo [5/5] Testing business deactivation system...
cd backend
node test_business_deactivation.js
cd ..

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo 🎉 Setup Completed Successfully!
    echo ========================================
    echo.
    echo ✅ Business Deactivation System Features:
    echo    - Automatic business suspension for overdue payments
    echo    - Grace period management (default: 7 days)
    echo    - Daily payment status checks
    echo    - Login prevention for suspended businesses
    echo    - Manual business management (superadmin only)
    echo    - Payment status tracking and logging
    echo    - Suspension notifications
    echo.
    echo ✅ API Endpoints Available:
    echo    - GET /api/business-payments/status/:businessId
    echo    - GET /api/business-payments/all-status
    echo    - POST /api/business-payments/suspend/:businessId
    echo    - POST /api/business-payments/reactivate/:businessId
    echo    - GET /api/business-payments/summary
    echo    - POST /api/business-payments/check-status
    echo.
    echo ✅ Frontend Widget Available:
    echo    - BusinessPaymentStatusWidget for superadmin dashboard
    echo.
    echo 📋 Next Steps:
    echo    1. Restart your backend server: npm start
    echo    2. Add BusinessPaymentStatusWidget to superadmin dashboard
    echo    3. Test the system with overdue payments
    echo    4. Monitor business payment status regularly
    echo.
    echo 📚 Documentation: BUSINESS_DEACTIVATION_GUIDE.md
    echo.
) else (
    echo.
    echo ❌ Setup completed with errors.
    echo Please check the error messages above and try again.
    echo.
)

pause 