# Business Deactivation System Guide

## Overview

The Business Deactivation System automatically manages business accounts based on their payment status. When a business doesn't pay their monthly subscription fee, the system will automatically deactivate the business and prevent all users from that business from logging in.

## Features

### 🔒 Automatic Business Suspension
- **Daily Payment Status Check**: The system automatically checks business payment status every day
- **Grace Period Management**: Businesses get a configurable grace period (default: 7 days) after payment is due
- **Automatic Suspension**: Businesses are automatically suspended when grace period expires
- **Login Prevention**: Users from suspended businesses cannot log in to the system

### 📊 Payment Status Tracking
- **Payment Status**: `active`, `overdue`, `suspended`, `cancelled`
- **Due Date Tracking**: Next payment due date and grace period end date
- **Suspension History**: Complete log of all status changes with reasons
- **Notification System**: Automatic notifications for suspension and reactivation

### 🛠️ Manual Management (Superadmin Only)
- **Manual Suspension**: Superadmins can manually suspend businesses
- **Manual Reactivation**: Superadmins can reactivate suspended businesses
- **Payment Due Date Management**: Adjust payment due dates and grace periods
- **Status Monitoring**: View all businesses and their payment status

## Database Structure

### New Tables Added

#### `business_payment_status_log`
Tracks all payment status changes:
```sql
- business_id: Business ID
- status_from: Previous status
- status_to: New status
- reason: Reason for change
- triggered_by: 'automatic', 'manual', or 'payment'
- triggered_by_user_id: User who triggered manual change
- created_at: Timestamp
```

#### `business_suspension_notifications`
Stores suspension and reactivation notifications:
```sql
- business_id: Business ID
- notification_type: 'payment_reminder', 'overdue_warning', 'suspension_notice', 'reactivation_notice'
- message: Notification message
- sent_at: Timestamp
- is_read: Read status
```

### Modified Tables

#### `businesses` (New Columns)
```sql
- payment_status: ENUM('active', 'overdue', 'suspended', 'cancelled')
- last_payment_date: DATE
- next_payment_due_date: DATE
- grace_period_end_date: DATE
- suspension_date: TIMESTAMP
- suspension_reason: TEXT
- auto_suspension_enabled: BOOLEAN
```

## Setup Instructions

### 1. Run the Setup Script
```bash
cd backend
setup_business_deactivation.bat
```

### 2. Verify Installation
```bash
node test_business_deactivation.js
```

### 3. Restart Backend Server
```bash
npm start
```

## How It Works

### Payment Status Flow

1. **Active** → Business is current on payments
2. **Overdue** → Payment is past due date, grace period starts
3. **Suspended** → Grace period expired, business is deactivated
4. **Cancelled** → Business subscription is cancelled

### Automatic Process

1. **Daily Check**: `CheckBusinessPaymentStatus()` procedure runs daily
2. **Overdue Detection**: Checks for bills with status 'pending' or 'overdue'
3. **Grace Period**: Sets grace period when payment becomes overdue
4. **Suspension**: Automatically suspends business when grace period expires
5. **Login Block**: Users from suspended businesses cannot log in

### Manual Process

Superadmins can:
- Manually suspend businesses
- Reactivate suspended businesses
- Adjust payment due dates
- View payment status history
- Manage grace periods

## API Endpoints

### Business Payment Management (Superadmin Only)

#### Get Business Payment Status
```
GET /api/business-payments/status/:businessId
```

#### Get All Businesses Payment Status
```
GET /api/business-payments/all-status?status=active&page=1&limit=20
```

#### Suspend Business
```
POST /api/business-payments/suspend/:businessId
Body: { "reason": "Manual suspension reason" }
```

#### Reactivate Business
```
POST /api/business-payments/reactivate/:businessId
Body: { "reason": "Manual reactivation reason" }
```

#### Update Payment Due Date
```
PUT /api/business-payments/update-due-date/:businessId
Body: { "next_payment_due_date": "2024-02-01", "grace_period_days": 10 }
```

#### Get Payment Summary
```
GET /api/business-payments/summary
```

#### Manually Trigger Status Check
```
POST /api/business-payments/check-status
```

## Login Prevention

### Authentication Flow

When a user attempts to log in:

1. **User Validation**: Check if user exists and is active
2. **Business Check**: For non-superadmin users, check business status
3. **Payment Status**: Verify business payment status is 'active'
4. **Login Block**: If business is suspended/overdue, block login with error message

### Error Messages

- **Business Deactivated**: "Business account is deactivated. Please contact your administrator."
- **Payment Overdue**: "Business account is overdue on payments. Please contact support to resolve payment issues."
- **Business Suspended**: "Business account is suspended due to payment issues."

## Configuration

### Grace Period
Default grace period is 7 days. Can be configured per business:
```sql
UPDATE businesses SET grace_period_days = 10 WHERE id = 1;
```

### Auto-Suspension
Can be disabled for specific businesses:
```sql
UPDATE businesses SET auto_suspension_enabled = 0 WHERE id = 1;
```

### Daily Check Schedule
The automatic check runs daily at midnight. To change the schedule:
```sql
DROP EVENT daily_business_payment_check;
CREATE EVENT daily_business_payment_check
ON SCHEDULE EVERY 1 DAY
STARTS '2024-01-01 02:00:00'
DO CALL CheckBusinessPaymentStatus();
```

## Monitoring and Alerts

### Status Monitoring
Superadmins can monitor:
- Number of active businesses
- Number of overdue businesses
- Number of suspended businesses
- Total monthly revenue
- Payment status distribution

### Notifications
The system automatically creates notifications for:
- Payment reminders
- Overdue warnings
- Suspension notices
- Reactivation notices

## Testing

### Test Scenarios

1. **Create Overdue Bill**: Insert a bill with past due date
2. **Run Status Check**: Execute the payment status check procedure
3. **Verify Suspension**: Check if business is suspended
4. **Test Login Block**: Attempt login with user from suspended business
5. **Manual Reactivation**: Reactivate business manually
6. **Verify Login**: Confirm user can login after reactivation

### Test Commands

```bash
# Run comprehensive test
node test_business_deactivation.js

# Check specific business status
mysql -u root -p -e "SELECT id, name, payment_status, is_active FROM businesses WHERE id = 1;"

# Run manual status check
mysql -u root -p -e "CALL CheckBusinessPaymentStatus();"
```

## Troubleshooting

### Common Issues

1. **Business Not Suspending**
   - Check if `auto_suspension_enabled = 1`
   - Verify overdue bills exist
   - Check grace period settings

2. **Users Still Can Login**
   - Verify business `is_active = 0`
   - Check business `payment_status = 'suspended'`
   - Ensure authentication middleware is updated

3. **Daily Check Not Running**
   - Verify MySQL event scheduler is enabled
   - Check event exists: `SHOW EVENTS;`
   - Manually trigger: `CALL CheckBusinessPaymentStatus();`

### Debug Commands

```sql
-- Check business status
SELECT id, name, payment_status, is_active, next_payment_due_date, grace_period_end_date 
FROM businesses;

-- Check overdue bills
SELECT business_id, billing_month, total_amount, due_date, status 
FROM monthly_bills 
WHERE status IN ('pending', 'overdue') AND due_date < CURDATE();

-- Check status log
SELECT business_id, status_from, status_to, reason, triggered_by, created_at 
FROM business_payment_status_log 
ORDER BY created_at DESC 
LIMIT 10;
```

## Security Considerations

1. **Superadmin Only**: All management endpoints require superadmin role
2. **Authentication Required**: All endpoints require valid JWT token
3. **Business Isolation**: Users can only access their own business data
4. **Audit Trail**: All status changes are logged with user and timestamp
5. **Graceful Degradation**: System continues to work even if payment checks fail

## Future Enhancements

1. **Email Notifications**: Send email alerts for payment reminders
2. **Payment Gateway Integration**: Automatic payment processing
3. **Advanced Billing**: Support for different billing cycles
4. **Payment Plans**: Installment payment options
5. **Analytics Dashboard**: Payment status analytics and reporting 