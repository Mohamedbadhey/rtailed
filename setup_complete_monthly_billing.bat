@echo off
echo ========================================
echo Complete Monthly Billing & Backup Setup
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
echo Running monthly billing and backup setup...
mysql -u root -p retail_management < backend/add_monthly_billing_and_backup.sql

echo.
echo Running additional column setup...
mysql -u root -p retail_management < backend/add_is_deleted_columns.sql

echo.
echo Step 2: Verifying setup...
echo.

echo Checking businesses table...
mysql -u root -p retail_management -e "SELECT COUNT(*) as business_count FROM businesses;"

echo.
echo Checking monthly_bills table...
mysql -u root -p retail_management -e "SELECT COUNT(*) as bill_count FROM monthly_bills;"

echo.
echo Checking payment_acceptance table...
mysql -u root -p retail_management -e "SELECT COUNT(*) as payment_count FROM payment_acceptance;"

echo.
echo Checking business_backups table...
mysql -u root -p retail_management -e "SELECT COUNT(*) as backup_count FROM business_backups;"

echo.
echo Checking business_deletion_log table...
mysql -u root -p retail_management -e "SELECT COUNT(*) as deletion_count FROM business_deletion_log;"

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
echo Creating sample monthly bills...
mysql -u root -p retail_management -e "
INSERT INTO monthly_bills (business_id, billing_month, base_amount, user_overage_fee, product_overage_fee, total_amount, status, due_date) VALUES
(1, '2024-01-01', 29.99, 0.00, 0.00, 29.99, 'paid', '2024-01-31'),
(2, '2024-01-01', 49.99, 0.00, 0.00, 49.99, 'paid', '2024-01-31'),
(3, '2024-01-01', 99.99, 0.00, 0.00, 99.99, 'paid', '2024-01-31'),
(1, '2024-02-01', 29.99, 5.00, 2.50, 37.49, 'pending', '2024-02-29'),
(2, '2024-02-01', 49.99, 0.00, 0.00, 49.99, 'overdue', '2024-02-15'),
(3, '2024-02-01', 99.99, 10.00, 5.00, 114.99, 'pending', '2024-02-29')
ON DUPLICATE KEY UPDATE base_amount=base_amount;
"

echo.
echo Creating sample payment acceptance records...
mysql -u root -p retail_management -e "
INSERT INTO payment_acceptance (business_id, monthly_bill_id, payment_amount, payment_method, status) VALUES
(1, 1, 29.99, 'bank_transfer', 'accepted'),
(2, 2, 49.99, 'credit_card', 'accepted'),
(3, 3, 99.99, 'paypal', 'accepted'),
(1, 4, 37.49, 'bank_transfer', 'pending'),
(3, 6, 114.99, 'credit_card', 'pending')
ON DUPLICATE KEY UPDATE payment_amount=payment_amount;
"

echo.
echo Creating sample backup records...
mysql -u root -p retail_management -e "
INSERT INTO business_backups (business_id, backup_type, backup_date, backup_time, file_path, file_size, status, created_by) VALUES
(1, 'full', CURDATE(), CURTIME(), '/backups/business_1_full_20240101.sql', 1024000, 'completed', 1),
(2, 'full', CURDATE(), CURTIME(), '/backups/business_2_full_20240101.sql', 2048000, 'completed', 1),
(3, 'full', CURDATE(), CURTIME(), '/backups/business_3_full_20240101.sql', 3072000, 'completed', 1),
(1, 'incremental', CURDATE(), CURTIME(), '/backups/business_1_incremental_20240201.sql', 512000, 'completed', 1),
(2, 'manual', CURDATE(), CURTIME(), '/backups/business_2_manual_20240201.sql', 1536000, 'completed', 1)
ON DUPLICATE KEY UPDATE file_path=file_path;
"

echo.
echo Creating sample business messages...
mysql -u root -p retail_management -e "
INSERT INTO business_messages (business_id, from_superadmin_id, subject, message, message_type, priority, created_at) VALUES
(1, 1, 'Welcome to our platform', 'Welcome to our retail management platform! We are excited to have you on board.', 'info', 'low', NOW()),
(2, 1, 'Payment reminder', 'Your monthly payment is due in 3 days. Please ensure timely payment to avoid service interruption.', 'payment_due', 'medium', NOW()),
(3, 1, 'Account upgrade available', 'You are eligible for an account upgrade. Contact us for more details.', 'info', 'low', NOW()),
(2, 1, 'Payment overdue', 'Your payment is overdue. Please submit payment immediately to avoid account suspension.', 'payment_due', 'high', NOW()),
(1, 1, 'Payment submitted for review', 'Payment of $37.49 has been submitted for review. Transaction ID: TXN001', 'info', 'medium', NOW())
ON DUPLICATE KEY UPDATE subject=subject;
"

echo.
echo Step 4: Final verification...
echo.

echo Testing businesses endpoint...
curl -X GET "http://localhost:3000/api/businesses" -H "Content-Type: application/json" -H "Authorization: Bearer YOUR_TOKEN_HERE" || echo "Note: Backend needs to be running to test endpoint"

echo.
echo Testing pending payments endpoint...
curl -X GET "http://localhost:3000/api/businesses/pending-payments/all" -H "Content-Type: application/json" -H "Authorization: Bearer YOUR_TOKEN_HERE" || echo "Note: Backend needs to be running to test endpoint"

echo.
echo Testing overdue bills endpoint...
curl -X GET "http://localhost:3000/api/businesses/overdue-bills/all" -H "Content-Type: application/json" -H "Authorization: Bearer YOUR_TOKEN_HERE" || echo "Note: Backend needs to be running to test endpoint"

echo.
echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo The monthly billing and backup system is now set up with:
echo - Monthly billing system with overage fees
echo - Payment acceptance workflow
echo - Business backup and restore functionality
echo - Deleted data recovery system
echo - Sample data for testing
echo.
echo Features available:
echo 1. Generate monthly bills for businesses
echo 2. Send payment reminders and overdue notifications
echo 3. Review and accept/reject business payments
echo 4. Create and manage business backups
echo 5. Restore businesses from backups
echo 6. Track deleted businesses and restore them
echo 7. Suspend/activate businesses based on payment status
echo.
echo Next steps:
echo 1. Start the backend server: start_backend.bat
echo 2. Start the frontend: start_frontend.bat
echo 3. Login as superadmin to access billing and backup features
echo 4. Navigate to the Billing and Backups tabs in the superadmin dashboard
echo.
pause 