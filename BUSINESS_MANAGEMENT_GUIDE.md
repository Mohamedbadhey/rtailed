# Business Management System Guide

## Overview

The Business Management System provides comprehensive tools for superadmins to manage all businesses on the platform. This includes messaging, payment tracking, usage monitoring, and business activation/deactivation capabilities.

## Features

### 1. Business Overview Tab
- **Business List**: View all businesses with key statistics
- **Quick Actions**: Access business management functions via popup menu
- **Status Indicators**: Visual indicators for business status and payment status
- **Statistics**: Real-time counts of users, products, sales, and customers

### 2. Business Messages Tab
- **Send Messages**: Communicate with businesses through various message types
- **Message Types**: Info, Warning, Payment Due, Suspension, Activation
- **Priority Levels**: Low, Medium, High, Urgent
- **Message History**: View all sent messages with read status

### 3. Business Payments Tab
- **Payment Tracking**: Monitor all business payments
- **Payment Types**: Subscription, Overage, Penalty, Credit
- **Payment Methods**: Credit Card, Bank Transfer, PayPal, Cash
- **Payment Status**: Pending, Completed, Failed, Refunded

### 4. Business Analytics Tab
- **Overall Statistics**: Platform-wide metrics
- **Business Performance**: Individual business performance metrics
- **Usage Analytics**: User and product usage tracking
- **Revenue Tracking**: Total revenue and payment analytics

## Database Schema

### Business Management Tables

#### 1. business_messages
```sql
CREATE TABLE business_messages (
    id INT PRIMARY KEY AUTO_INCREMENT,
    business_id INT NOT NULL,
    from_superadmin_id INT NOT NULL,
    subject VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    message_type ENUM('info', 'warning', 'payment_due', 'suspension', 'activation'),
    priority ENUM('low', 'medium', 'high', 'urgent'),
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 2. business_payments
```sql
CREATE TABLE business_payments (
    id INT PRIMARY KEY AUTO_INCREMENT,
    business_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_type ENUM('subscription', 'overage', 'penalty', 'credit'),
    payment_method ENUM('credit_card', 'bank_transfer', 'paypal', 'cash'),
    status ENUM('pending', 'completed', 'failed', 'refunded'),
    description TEXT,
    transaction_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 3. business_usage
```sql
CREATE TABLE business_usage (
    id INT PRIMARY KEY AUTO_INCREMENT,
    business_id INT NOT NULL,
    date DATE NOT NULL,
    users_count INT DEFAULT 0,
    products_count INT DEFAULT 0,
    customers_count INT DEFAULT 0,
    sales_count INT DEFAULT 0,
    user_overage INT DEFAULT 0,
    product_overage INT DEFAULT 0,
    total_overage_fee DECIMAL(10,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## API Endpoints

### Business Management Endpoints

#### 1. Get All Businesses
```
GET /api/businesses
Headers: Authorization: Bearer <token>
Query Parameters: limit, offset, search
```

#### 2. Get Business Details
```
GET /api/businesses/:businessId
Headers: Authorization: Bearer <token>
```

#### 3. Send Message to Business
```
POST /api/businesses/:businessId/messages
Headers: Authorization: Bearer <token>
Body: {
    "subject": "string",
    "message": "string",
    "message_type": "info|warning|payment_due|suspension|activation",
    "priority": "low|medium|high|urgent"
}
```

#### 4. Get Business Messages
```
GET /api/businesses/:businessId/messages
Headers: Authorization: Bearer <token>
```

#### 5. Add Payment for Business
```
POST /api/businesses/:businessId/payments
Headers: Authorization: Bearer <token>
Body: {
    "amount": number,
    "payment_type": "subscription|overage|penalty|credit",
    "payment_method": "credit_card|bank_transfer|paypal|cash",
    "status": "pending|completed|failed|refunded",
    "description": "string"
}
```

#### 6. Get Business Payments
```
GET /api/businesses/:businessId/payments
Headers: Authorization: Bearer <token>
```

#### 7. Update Business Settings
```
PUT /api/businesses/:businessId/settings
Headers: Authorization: Bearer <token>
Body: {
    "subscription_plan": "basic|premium|enterprise",
    "max_users": number,
    "max_products": number,
    "monthly_fee": number,
    "overage_fee_per_user": number,
    "overage_fee_per_product": number,
    "grace_period_days": number,
    "notes": "string"
}
```

#### 8. Toggle Business Status
```
PUT /api/businesses/:businessId/status
Headers: Authorization: Bearer <token>
Body: {
    "is_active": boolean,
    "suspension_reason": "string"
}
```

#### 9. Get Business Users
```
GET /api/businesses/:businessId/users
Headers: Authorization: Bearer <token>
```

## Business Management Actions

### 1. Send Message
- **Purpose**: Communicate with business owners
- **Types**: Info, Warning, Payment Due, Suspension, Activation
- **Features**: Priority levels, read status tracking

### 2. Add Payment
- **Purpose**: Record business payments
- **Types**: Subscription, Overage, Penalty, Credit
- **Features**: Multiple payment methods, status tracking

### 3. Business Settings
- **Purpose**: Configure business parameters
- **Features**: Subscription plans, usage limits, pricing

### 4. Manage Users
- **Purpose**: View and manage business users
- **Features**: User roles, contact information

### 5. Analytics
- **Purpose**: View business performance metrics
- **Features**: Usage statistics, payment history, performance indicators

### 6. Toggle Status
- **Purpose**: Activate or suspend businesses
- **Features**: Suspension reasons, status tracking

## Setup Instructions

### 1. Database Setup
Run the complete setup script:
```bash
setup_complete_business_management.bat
```

### 2. Backend Setup
Ensure the backend server is running:
```bash
start_backend.bat
```

### 3. Frontend Setup
Start the Flutter application:
```bash
start_frontend.bat
```

### 4. Access Business Management
1. Login as superadmin
2. Navigate to the Businesses tab
3. Use the tabbed interface to access different management features

## Usage Examples

### Sending a Payment Reminder
1. Go to Messages tab
2. Click "Send Message"
3. Select business
4. Choose "payment_due" type
5. Set priority to "high"
6. Write reminder message
7. Send

### Adding a Payment
1. Go to Payments tab
2. Click "Add Payment"
3. Select business
4. Enter amount and description
5. Choose payment type and method
6. Set status
7. Save

### Viewing Business Analytics
1. Go to Analytics tab
2. View overall platform statistics
3. Click on individual business for detailed analytics
4. Review usage metrics and payment history

## Security Features

- **Role-based Access**: Only superadmins can access business management
- **Audit Logging**: All actions are logged for security
- **Data Validation**: Input validation on all endpoints
- **Token Authentication**: Secure API access

## Troubleshooting

### Common Issues

1. **"Failed to fetch business" error**
   - Ensure database tables are created
   - Check backend server is running
   - Verify authentication token

2. **Missing business data**
   - Run the setup script to create sample data
   - Check database connection

3. **API endpoint errors**
   - Verify backend routes are properly configured
   - Check authentication middleware

### Support

For technical support or questions about the business management system, refer to the main project documentation or contact the development team.

## Future Enhancements

- **Automated Billing**: Automatic payment processing
- **Advanced Analytics**: More detailed reporting
- **Email Notifications**: Automated email alerts
- **API Rate Limiting**: Enhanced security
- **Mobile Notifications**: Push notifications for businesses 