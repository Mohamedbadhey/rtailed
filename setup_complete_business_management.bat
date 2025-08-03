@echo off
echo ========================================
echo Complete Business Management Setup
echo ========================================
echo.

echo Step 1: Setting up database tables...
echo.

echo Running initial database setup...
mysql -u root -p retail_management < backend/src/config/schema.sql

echo.
echo Running multi-tenant setup...
mysql -u root -p retail_management < backend/add_multi_tenant_support.sql

echo.
echo Running business management features setup...
mysql -u root -p retail_management < backend/add_business_management_features.sql

echo.
echo Running additional column setup...
mysql -u root -p retail_management < backend/add_is_deleted_columns.sql

echo.
echo Step 2: Verifying setup...
echo.

echo Checking businesses table...
mysql -u root -p retail_management -e "SELECT COUNT(*) as business_count FROM businesses;"

echo.
echo Checking business_messages table...
mysql -u root -p retail_management -e "SELECT COUNT(*) as message_count FROM business_messages;"

echo.
echo Checking business_payments table...
mysql -u root -p retail_management -e "SELECT COUNT(*) as payment_count FROM business_payments;"

echo.
echo Checking business_usage table...
mysql -u root -p retail_management -e "SELECT COUNT(*) as usage_count FROM business_usage;"

echo.
echo Step 3: Creating sample data...
echo.

echo Creating sample businesses...
mysql -u root -p retail_management -e "
INSERT INTO businesses (name, business_code, email, phone, address, subscription_plan, monthly_fee, max_users, max_products, is_active, created_at) VALUES
('Sample Store 1', 'STORE001', 'store1@example.com', '+1234567890', '123 Main St, City', 'basic', 29.99, 5, 1000, 1, NOW()),
('Sample Store 2', 'STORE002', 'store2@example.com', '+1234567891', '456 Oak Ave, Town', 'premium', 49.99, 10, 5000, 1, NOW()),
('Sample Store 3', 'STORE003', 'store3@example.com', '+1234567892', '789 Pine Rd, Village', 'enterprise', 99.99, 25, 10000, 1, NOW())
ON DUPLICATE KEY UPDATE name=name;
"

echo.
echo Creating sample business messages...
mysql -u root -p retail_management -e "
INSERT INTO business_messages (business_id, from_superadmin_id, subject, message, message_type, priority, created_at) VALUES
(1, 1, 'Welcome to our platform', 'Welcome to our retail management platform! We are excited to have you on board.', 'info', 'low', NOW()),
(2, 1, 'Payment reminder', 'Your monthly payment is due in 3 days. Please ensure timely payment to avoid service interruption.', 'payment_due', 'medium', NOW()),
(3, 1, 'Account upgrade available', 'You are eligible for an account upgrade. Contact us for more details.', 'info', 'low', NOW())
ON DUPLICATE KEY UPDATE subject=subject;
"

echo.
echo Creating sample business payments...
mysql -u root -p retail_management -e "
INSERT INTO business_payments (business_id, amount, payment_type, payment_method, status, description, created_at) VALUES
(1, 29.99, 'subscription', 'credit_card', 'completed', 'Monthly subscription payment', NOW()),
(2, 49.99, 'subscription', 'bank_transfer', 'completed', 'Monthly subscription payment', NOW()),
(3, 99.99, 'subscription', 'paypal', 'completed', 'Monthly subscription payment', NOW())
ON DUPLICATE KEY UPDATE amount=amount;
"

echo.
echo Creating sample business usage...
mysql -u root -p retail_management -e "
INSERT INTO business_usage (business_id, date, users_count, products_count, customers_count, sales_count, user_overage, product_overage, total_overage_fee, created_at) VALUES
(1, CURDATE(), 3, 150, 45, 67, 0, 0, 0.00, NOW()),
(2, CURDATE(), 7, 1200, 89, 234, 0, 0, 0.00, NOW()),
(3, CURDATE(), 15, 3500, 156, 567, 0, 0, 0.00, NOW())
ON DUPLICATE KEY UPDATE users_count=users_count;
"

echo.
echo Step 4: Final verification...
echo.

echo Testing businesses endpoint...
curl -X GET "http://localhost:3000/api/businesses" -H "Content-Type: application/json" -H "Authorization: Bearer YOUR_TOKEN_HERE" || echo "Note: Backend needs to be running to test endpoint"

echo.
echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo The business management system is now set up with:
echo - Business management tables
echo - Message system
echo - Payment tracking
echo - Usage monitoring
echo - Sample data for testing
echo.
echo Next steps:
echo 1. Start the backend server: start_backend.bat
echo 2. Start the frontend: start_frontend.bat
echo 3. Login as superadmin to access business management features
echo.
pause 