# Notification System Setup Guide

## Quick Setup

### Option 1: Using the batch file (Windows)
1. Double-click `setup_notifications.bat`
2. Enter your MySQL password when prompted
3. Restart your backend server

### Option 2: Manual MySQL setup
1. Open MySQL command line or workbench
2. Run the following command:
```sql
mysql -u your_username -p retail_management < backend/setup_notifications.sql
```

### Option 3: Copy and paste the SQL
1. Open your MySQL client
2. Copy and paste the contents of `backend/setup_notifications.sql`
3. Execute the script

## What the setup does:
- Creates `notifications` table
- Creates `user_notifications` table  
- Adds necessary indexes for performance
- Inserts sample notifications
- Links notifications to existing users

## After setup:
1. Restart your backend server
2. The notification system will be available at `/api/notifications`
3. Test by sending a notification from the admin panel

## Troubleshooting:
- If you get "table already exists" errors, the setup script will handle this
- If you get permission errors, make sure your MySQL user has CREATE/DROP privileges
- If the backend still shows errors, restart the server after running the setup 