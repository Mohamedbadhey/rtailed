@echo off
echo ========================================
echo Subscription-Based Billing Setup
echo ========================================
echo.
echo Step 1: Setting up database tables...
mysql -u root -p retail_management < backend/src/config/schema.sql
mysql -u root -p retail_management < backend/add_multi_tenant_support.sql
mysql -u root -p retail_management < backend/add_business_management_features.sql
mysql -u root -p retail_management < backend/add_monthly_billing_and_backup.sql
mysql -u root -p retail_management < backend/add_subscription_based_billing.sql
mysql -u root -p retail_management < backend/add_is_deleted_columns.sql
echo.
echo Step 2: Creating sample data...
mysql -u root -p retail_management -e "INSERT INTO businesses (name, email, phone, address, subscription_plan, monthly_fee, max_users, max_products, overage_fee_per_user, overage_fee_per_product, is_active, created_at) VALUES ('Tech Solutions Inc', 'tech@example.com', '+1234567890', '123 Tech St, City', 'basic', 29.99, 5, 1000, 5.00, 0.10, 1, NOW()) ON DUPLICATE KEY UPDATE subscription_plan='basic';"
mysql -u root -p retail_management -e "INSERT INTO businesses (name, email, phone, address, subscription_plan, monthly_fee, max_users, max_products, overage_fee_per_user, overage_fee_per_product, is_active, created_at) VALUES ('Premium Retail Store', 'premium@example.com', '+1234567891', '456 Premium Ave, City', 'premium', 49.99, 10, 5000, 4.00, 0.08, 1, NOW()) ON DUPLICATE KEY UPDATE subscription_plan='premium';"
mysql -u root -p retail_management -e "INSERT INTO businesses (name, email, phone, address, subscription_plan, monthly_fee, max_users, max_products, overage_fee_per_user, overage_fee_per_product, is_active, created_at) VALUES ('Enterprise Corp', 'enterprise@example.com', '+1234567892', '789 Enterprise Blvd, City', 'enterprise', 99.99, 25, 10000, 3.00, 0.05, 1, NOW()) ON DUPLICATE KEY UPDATE subscription_plan='enterprise';"
echo.
echo Step 3: Creating sample monthly bills...
mysql -u root -p retail_management -e "INSERT INTO monthly_bills (business_id, billing_month, base_amount, user_overage_fee, product_overage_fee, total_amount, status, due_date, created_at) VALUES (1, '2024-01-01', 29.99, 0.00, 0.00, 29.99, 'paid', '2024-02-01', NOW()) ON DUPLICATE KEY UPDATE total_amount=29.99;"
mysql -u root -p retail_management -e "INSERT INTO monthly_bills (business_id, billing_month, base_amount, user_overage_fee, product_overage_fee, total_amount, status, due_date, created_at) VALUES (2, '2024-01-01', 49.99, 20.00, 0.00, 69.99, 'pending', '2024-02-01', NOW()) ON DUPLICATE KEY UPDATE total_amount=69.99;"
mysql -u root -p retail_management -e "INSERT INTO monthly_bills (business_id, billing_month, base_amount, user_overage_fee, product_overage_fee, total_amount, status, due_date, created_at) VALUES (3, '2024-01-01', 99.99, 0.00, 50.00, 149.99, 'overdue', '2024-02-01', NOW()) ON DUPLICATE KEY UPDATE total_amount=149.99;"
echo.
echo Step 4: Creating sample payment submissions...
mysql -u root -p retail_management -e "INSERT INTO payment_acceptance (business_id, monthly_bill_id, amount, payment_method, transaction_id, status, submitted_at, reviewed_at, reviewed_by, notes) VALUES (1, 1, 29.99, 'bank_transfer', 'TXN001', 'accepted', NOW(), NOW(), 1, 'Payment received on time') ON DUPLICATE KEY UPDATE status='accepted';"
mysql -u root -p retail_management -e "INSERT INTO payment_acceptance (business_id, monthly_bill_id, amount, payment_method, transaction_id, status, submitted_at, reviewed_at, reviewed_by, notes) VALUES (2, 2, 69.99, 'credit_card', 'TXN002', 'pending', NOW(), NULL, NULL, 'Payment submitted for review') ON DUPLICATE KEY UPDATE status='pending';"
echo.
echo Step 5: Creating sample business usage data...
mysql -u root -p retail_management -e "INSERT INTO business_usage (business_id, date, users_count, products_count, user_overage, product_overage, total_overage_fee, created_at) VALUES (1, CURDATE(), 3, 500, 0, 0, 0.00, NOW()) ON DUPLICATE KEY UPDATE users_count=3;"
mysql -u root -p retail_management -e "INSERT INTO business_usage (business_id, date, users_count, products_count, user_overage, product_overage, total_overage_fee, created_at) VALUES (2, CURDATE(), 12, 3000, 2, 0, 8.00, NOW()) ON DUPLICATE KEY UPDATE users_count=12;"
mysql -u root -p retail_management -e "INSERT INTO business_usage (business_id, date, users_count, products_count, user_overage, product_overage, total_overage_fee, created_at) VALUES (3, CURDATE(), 20, 12000, 0, 2000, 100.00, NOW()) ON DUPLICATE KEY UPDATE users_count=20;"
echo.
echo Step 6: Creating sample business messages...
mysql -u root -p retail_management -e "INSERT INTO business_messages (business_id, from_superadmin_id, subject, message, message_type, priority, created_at) VALUES (1, 1, 'Welcome to Our Platform', 'Welcome to our retail management platform! We are here to help you succeed.', 'info', 'low', NOW()) ON DUPLICATE KEY UPDATE message_type='info';"
mysql -u root -p retail_management -e "INSERT INTO business_messages (business_id, from_superadmin_id, subject, message, message_type, priority, created_at) VALUES (2, 1, 'Payment Due Reminder', 'Your monthly payment of $69.99 is due. Please submit payment for review.', 'payment_due', 'high', NOW()) ON DUPLICATE KEY UPDATE message_type='payment_due';"
mysql -u root -p retail_management -e "INSERT INTO business_messages (business_id, from_superadmin_id, subject, message, message_type, priority, created_at) VALUES (3, 1, 'Overdue Payment Notice', 'Your payment of $149.99 is overdue. Please contact us immediately.', 'suspension', 'urgent', NOW()) ON DUPLICATE KEY UPDATE message_type='suspension';"
echo.
echo Step 7: Creating sample business backups...
mysql -u root -p retail_management -e "INSERT INTO business_backups (business_id, backup_type, filename, file_size, status, created_at) VALUES (1, 'full', 'backup_tech_solutions_20240101.sql', 1024000, 'completed', NOW()) ON DUPLICATE KEY UPDATE status='completed';"
mysql -u root -p retail_management -e "INSERT INTO business_backups (business_id, backup_type, filename, file_size, status, created_at) VALUES (2, 'full', 'backup_premium_retail_20240101.sql', 2048000, 'completed', NOW()) ON DUPLICATE KEY UPDATE status='completed';"
mysql -u root -p retail_management -e "INSERT INTO business_backups (business_id, backup_type, filename, file_size, status, created_at) VALUES (3, 'full', 'backup_enterprise_corp_20240101.sql', 5120000, 'completed', NOW()) ON DUPLICATE KEY UPDATE status='completed';"
echo.
echo Step 8: Final verification...
echo.
echo Checking subscription plans...
mysql -u root -p retail_management -e "SELECT plan_name, monthly_fee, max_users, max_products FROM subscription_plans;"
echo.
echo Checking businesses with subscription plans...
mysql -u root -p retail_management -e "SELECT name, subscription_plan, monthly_fee, max_users, max_products FROM businesses WHERE is_deleted = 0;"
echo.
echo Checking monthly bills...
mysql -u root -p retail_management -e "SELECT b.name, mb.total_amount, mb.status, mb.due_date FROM monthly_bills mb JOIN businesses b ON mb.business_id = b.id ORDER BY mb.created_at DESC LIMIT 5;"
echo.
echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo The subscription-based billing system is now ready!
echo.
echo Features available:
echo - Automatic bill calculation based on subscription plans
echo - Overage fees for users and products beyond limits
echo - Monthly billing automation
echo - Payment acceptance workflow
echo - Business backup and recovery
echo - Comprehensive business management
echo.
echo Next steps:
echo 1. Start the backend: start_backend.bat
echo 2. Start the frontend: start_frontend.bat
echo 3. Test the superadmin dashboard billing features
echo.
pause 