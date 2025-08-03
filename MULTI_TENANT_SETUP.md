# Multi-Tenant Retail Management System Setup Guide

## Overview

This retail management system now supports multi-tenancy, allowing a superadmin to manage multiple independent businesses, each with their own data, users, and operations.

## Architecture

- **Superadmin**: Creates businesses and business admins, oversees system-wide operations
- **Business Admin**: Manages their specific business users and data
- **Business Users**: Work within their assigned business (manager, cashier roles)
- **Businesses/Tenants**: Independent retail operations with isolated data
- **Data Isolation**: All business data is separated by `business_id`

## Database Changes

### New Tables
- `businesses`: Stores business/tenant information
- `business_statistics`: Business-specific analytics
- `business_settings`: Business-specific configurations
- `business_logs`: Business-specific audit logs

### Modified Tables
All existing tables now include `business_id` for data isolation:
- `users` (except superadmin)
- `products`
- `categories`
- `customers`
- `sales`
- `sale_items`
- `inventory_transactions`
- `vendors`
- `expenses`
- `accounts_payable`
- `cash_flows`

## Setup Instructions

### 1. Database Setup

Run the multi-tenant setup script:
```bash
setup_multi_tenant.bat
```

Or manually execute:
```sql
mysql -u root -p retail_management < backend/add_multi_tenant_support.sql
```

### 2. Backend Setup

The backend automatically includes the new business management routes:
- `GET /api/businesses` - List all businesses
- `POST /api/businesses` - Create new business
- `GET /api/businesses/:id` - Get business details
- `PUT /api/businesses/:id` - Update business
- `DELETE /api/businesses/:id` - Delete business
- `GET /api/businesses/:id/users` - Get business users
- `GET /api/businesses/:id/statistics` - Get business statistics

### 3. Frontend Setup

The Flutter app now includes:
- Business management tab in superadmin dashboard
- Business selection in user registration
- Multi-tenant data isolation

## Usage Guide

### Superadmin Operations

1. **Login as Superadmin**
   - Username: `superadmin`
   - Password: `superadmin123`
   - Or register new superadmin with code: `SUPERADMIN2024`

2. **Create Businesses and Admins**
   - Navigate to "Businesses" tab in superadmin dashboard
   - Create new businesses with subscription plans
   - Automatically create business admin accounts
   - Monitor business statistics and user activity

3. **Business Creation Process**
   - Business Information: Name, code, contact details
   - Subscription Plan: basic, premium, or enterprise
   - Business Admin Account: Username, email, password
   - System automatically creates admin user for the business

### Business Admin Operations

1. **Login as Business Admin**
   - Use credentials provided by superadmin
   - Access limited to their specific business

2. **Manage Business Users**
   - Create manager and cashier accounts
   - Manage user permissions and access
   - Monitor business operations

3. **Business Data Management**
   - Manage products, customers, sales
   - View business reports and analytics
   - Configure business-specific settings

### Business User Management

1. **Business Admin Creates Users**
   - Business admins create users for their business
   - Users are automatically associated with the business
   - Data access limited to their business

2. **User Roles by Business**
   - **Business Admin**: Full access to business data and user management
   - **Manager**: Limited administrative access within business
   - **Cashier**: Sales and basic operations within business

3. **User Registration Process**
   - Business admins create users through their dashboard
   - No public registration for business users
   - All users must be created by business admin or superadmin

### Data Isolation

- Each business has completely isolated data
- Users can only access their assigned business data
- Superadmin can view all business data
- Business-specific settings and configurations

## Subscription Plans

### Basic Plan
- Up to 5 users
- Up to 1,000 products
- Basic reporting
- Email support

### Premium Plan
- Up to 15 users
- Up to 2,000 products
- Advanced analytics
- Priority support

### Enterprise Plan
- Up to 25 users
- Up to 5,000 products
- Custom integrations
- Dedicated support

## API Endpoints

### Business Management (Superadmin Only)
```
GET    /api/businesses              # List businesses
POST   /api/businesses              # Create business
GET    /api/businesses/:id          # Get business details
PUT    /api/businesses/:id          # Update business
DELETE /api/businesses/:id          # Delete business
GET    /api/businesses/:id/users    # Get business users
GET    /api/businesses/:id/statistics # Get business stats
PUT    /api/businesses/:id/settings # Update business settings
```

### Business Creation (Superadmin Only)
```
POST /api/businesses
{
  "name": "Tech Store Pro",
  "business_code": "TECH001",
  "email": "tech@store.com",
  "phone": "+1234567890",
  "subscription_plan": "premium",
  "max_users": 15,
  "max_products": 2000,
  "admin_username": "techadmin",
  "admin_email": "admin@techstore.com",
  "admin_password": "securepassword"
}
```

### User Creation (Business Admin)
```
POST /api/admin/users
{
  "username": "cashier1",
  "email": "cashier@techstore.com",
  "password": "password",
  "role": "cashier"
}
// business_id automatically set from admin's business
```

## Security Features

- **Role-based Access Control**: Different permissions per role
- **Business Isolation**: Data separation between businesses
- **Audit Logging**: Track all business operations
- **Subscription Limits**: Enforce user and product limits
- **Active/Inactive Status**: Suspend businesses as needed

## Monitoring and Analytics

### Superadmin Dashboard
- System-wide overview
- Business performance metrics
- User activity across businesses
- Subscription status monitoring

### Business-specific Analytics
- Sales performance
- User activity
- Product inventory
- Customer data

## Troubleshooting

### Common Issues

1. **Business Not Found**
   - Verify business exists and is active
   - Check business_id in user registration

2. **Data Access Issues**
   - Ensure user is associated with correct business
   - Verify business is active

3. **Subscription Limits**
   - Check current usage vs. plan limits
   - Upgrade subscription if needed

### Database Queries

Check business data:
```sql
SELECT * FROM businesses WHERE is_active = TRUE;
```

Check user-business associations:
```sql
SELECT u.username, b.name as business_name 
FROM users u 
LEFT JOIN businesses b ON u.business_id = b.id;
```

## Migration from Single-Tenant

Existing data is automatically migrated:
- All existing data assigned to "Default Business"
- Existing users remain functional
- No data loss during migration

## Support

For issues or questions:
1. Check the audit logs for business operations
2. Verify business status and subscription limits
3. Review user permissions and business associations
4. Contact system administrator for superadmin access 