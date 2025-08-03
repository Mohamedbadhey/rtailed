# 🗂️ Data Recovery System Guide

## Overview

The Superadmin Dashboard now includes a comprehensive **Data Recovery System** that allows superadmins to recover deleted data from each business. This system provides granular control over data recovery with business-specific isolation and audit logging.

---

## 🎯 **Key Features**

### **1. Business-Specific Recovery**
- **Per-Business Isolation**: Each business's deleted data is completely isolated
- **Recovery Statistics**: Visual overview of deleted items by type for each business
- **Bulk Operations**: Recover all deleted data for a business at once

### **2. Multi-Data Type Support**
- **Users**: Deleted user accounts and profiles
- **Products**: Deleted product catalog items
- **Sales**: Deleted sales transactions
- **Customers**: Deleted customer records
- **Categories**: Deleted product categories
- **Notifications**: Deleted system notifications

### **3. Advanced Recovery Options**
- **Individual Recovery**: Recover specific items one by one
- **Bulk Recovery**: Recover multiple items simultaneously
- **Permanent Deletion**: Permanently delete items that cannot be recovered
- **Audit Logging**: All recovery actions are logged for security

---

## 🏗️ **System Architecture**

### **Backend Endpoints**

#### **1. Get Business Recovery Statistics**
```http
GET /api/admin/businesses/:businessId/recovery-stats
```
**Response:**
```json
{
  "business_id": 1,
  "deleted_counts": {
    "users": 5,
    "products": 12,
    "sales": 3,
    "customers": 8,
    "categories": 2,
    "notifications": 15
  },
  "total_deleted": 45
}
```

#### **2. Get Business Deleted Data**
```http
GET /api/admin/businesses/:businessId/deleted-data?dataType=all
```
**Query Parameters:**
- `dataType`: `users`, `products`, `sales`, `customers`, `categories`, `notifications`, `all`

**Response:**
```json
{
  "business": {
    "id": 1,
    "name": "Business Name",
    "subscription_plan": "premium"
  },
  "users": [...],
  "products": [...],
  "sales": [...],
  "customers": [...],
  "categories": [...],
  "notifications": [...]
}
```

#### **3. Recover Single Item**
```http
POST /api/admin/recover/:dataType/:id
```
**Body:**
```json
{
  "businessId": 1
}
```

#### **4. Recover Multiple Items**
```http
POST /api/admin/recover-multiple
```
**Body:**
```json
{
  "businessId": 1,
  "items": [
    {"type": "user", "id": 1},
    {"type": "product", "id": 5},
    {"type": "sale", "id": 10}
  ]
}
```

#### **5. Permanently Delete Item**
```http
DELETE /api/admin/permanently-delete/:dataType/:id
```
**Body:**
```json
{
  "businessId": 1
}
```

---

## 🖥️ **Frontend Interface**

### **Tab Structure**
The "Deleted Data" tab now has two sub-tabs:

#### **1. Business Recovery Tab**
- **Business Cards**: Expandable cards showing each business
- **Recovery Statistics**: Visual grid showing deleted counts by type
- **Action Buttons**: "View Deleted Data" and "Recover All"
- **Color Coding**: Red for items with deleted data, green for clean businesses

#### **2. Global Deleted Data Tab**
- **Legacy Interface**: Shows all deleted data across all businesses
- **Simple Recovery**: Basic restore functionality

### **Business Recovery Card Features**

#### **Statistics Grid**
```
┌─────────┬─────────┬─────────┐
│ 👥 Users│ 📦 Prod │ 🛒 Sales│
│    5    │   12    │    3    │
├─────────┼─────────┼─────────┤
│ 👤 Cust │ 📂 Cat  │ 🔔 Notif│
│    8    │    2    │   15    │
└─────────┴─────────┴─────────┘
```

#### **Action Buttons**
- **View Deleted Data**: Opens detailed dialog with all deleted items
- **Recover All**: Bulk recovery with confirmation dialog

### **Detailed Recovery Dialog**

#### **Tabbed Interface**
- **Users Tab**: Deleted user accounts with recovery options
- **Products Tab**: Deleted products with recovery options
- **Sales Tab**: Deleted sales transactions with recovery options
- **Customers Tab**: Deleted customer records with recovery options
- **Categories Tab**: Deleted categories with recovery options
- **Notifications Tab**: Deleted notifications with recovery options

#### **Item Actions**
Each deleted item shows:
- **Item Details**: Name, ID, deletion date, business ID
- **Recover Button**: Restore the item
- **Delete Permanently Button**: Remove item forever

---

## 🔒 **Security & Data Isolation**

### **Business Isolation**
```sql
-- All queries filter by business_id
WHERE business_id = ? AND is_deleted = 1
```

### **Permission Checks**
- **Superadmin Only**: All recovery endpoints require superadmin role
- **Business Verification**: Items can only be recovered if they belong to the specified business
- **Audit Logging**: All actions are logged in `system_logs` table

### **Audit Trail**
```sql
INSERT INTO system_logs (
  user_id, action, table_name, record_id, 
  old_values, new_values
) VALUES (
  ?, 'recover_deleted_item', ?, ?, 
  '{"is_deleted": 1}', '{"is_deleted": 0}'
)
```

---

## 🚀 **Usage Workflow**

### **1. Access Recovery System**
1. Navigate to Superadmin Dashboard
2. Click on "Deleted Data" tab
3. Select "Business Recovery" sub-tab

### **2. View Business Statistics**
1. Browse through business cards
2. Check the statistics grid for each business
3. Identify businesses with deleted data (red indicators)

### **3. Recover Individual Items**
1. Click "View Deleted Data" on a business card
2. Navigate through tabs to find specific item types
3. Click "Recover" button next to desired items
4. Confirm recovery action

### **4. Bulk Recovery**
1. Click "Recover All" on a business card
2. Confirm the bulk recovery action
3. Wait for the recovery process to complete
4. Review the results summary

### **5. Permanent Deletion**
1. Click "Delete Permanently" on an item
2. Confirm the permanent deletion
3. Item is removed from database forever

---

## 📊 **Recovery Statistics**

### **Visual Indicators**
- **Red Background**: Items with deleted data
- **Green Background**: Clean businesses (no deleted data)
- **Count Display**: Number of deleted items per type
- **Total Count**: Sum of all deleted items

### **Business Overview**
- **Business Name**: Clear identification
- **Subscription Plan**: Current plan level
- **Total Deleted**: Overall count of deleted items
- **Status Color**: Red for issues, green for clean

---

## 🔧 **Technical Implementation**

### **Database Schema**
All tables with soft delete support include:
```sql
is_deleted TINYINT(1) NOT NULL DEFAULT 0
```

### **Recovery Process**
1. **Verification**: Check item exists and belongs to business
2. **Recovery**: Set `is_deleted = 0`
3. **Logging**: Record action in audit log
4. **Response**: Return success/failure status

### **Error Handling**
- **Item Not Found**: 404 error with descriptive message
- **Business Mismatch**: Security error for cross-business access
- **Database Errors**: 500 error with logging
- **Validation Errors**: 400 error with field-specific messages

---

## 📋 **Best Practices**

### **For Superadmins**
1. **Regular Monitoring**: Check recovery statistics regularly
2. **Selective Recovery**: Only recover necessary items
3. **Audit Review**: Monitor recovery logs for unusual activity
4. **Backup Verification**: Ensure backups are working before permanent deletion

### **For System Administrators**
1. **Database Maintenance**: Regular cleanup of permanently deleted items
2. **Log Rotation**: Archive old audit logs
3. **Performance Monitoring**: Watch for large recovery operations
4. **Security Audits**: Regular review of recovery permissions

---

## 🚨 **Important Notes**

### **Data Integrity**
- **Soft Delete Only**: Items are marked as deleted, not physically removed
- **Recovery Safety**: Recovered items maintain their original data
- **Business Isolation**: No cross-business data access
- **Audit Compliance**: All actions are logged for compliance

### **Performance Considerations**
- **Large Datasets**: Recovery operations may take time for large datasets
- **Indexing**: Ensure proper indexes on `business_id` and `is_deleted` columns
- **Batch Operations**: Use bulk recovery for multiple items
- **Memory Usage**: Monitor memory usage during large recovery operations

### **Limitations**
- **Soft Delete Required**: Only works with tables that have `is_deleted` column
- **Business Context**: All operations require business ID
- **Superadmin Only**: Limited to superadmin role
- **No Cross-Business**: Cannot recover items across different businesses

---

## 🎉 **Benefits**

### **For Superadmins**
- **Complete Control**: Full oversight of all business data
- **Granular Recovery**: Recover specific items or entire datasets
- **Audit Trail**: Complete logging of all recovery actions
- **Business Isolation**: Safe, isolated recovery per business

### **For Businesses**
- **Data Safety**: Accidental deletions can be recovered
- **Business Continuity**: Maintain operations even after data loss
- **Compliance**: Meet data retention requirements
- **Peace of Mind**: Know that data can be recovered if needed

### **For System**
- **Data Integrity**: Maintain referential integrity during recovery
- **Performance**: Efficient queries with proper indexing
- **Security**: Secure, audited recovery operations
- **Scalability**: Handle multiple businesses and large datasets

---

This comprehensive data recovery system provides superadmins with powerful tools to manage and recover deleted data while maintaining strict security and business isolation requirements. 