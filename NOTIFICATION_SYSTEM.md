# Notification System

This document describes the notification system implemented for the retail management application, allowing admins to send messages to their cashiers.

## Features

### For Admins
- Send notifications to all cashiers or specific cashiers
- Choose notification type (info, warning, error, success)
- Set priority levels (low, medium, high, urgent)
- View notification statistics
- Track read/unread status

### For Cashiers
- View received notifications
- Mark notifications as read
- See unread notification count
- Filter notifications by read status

## Database Schema

### Notifications Table
```sql
CREATE TABLE notifications (
    id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type ENUM('info', 'warning', 'error', 'success') DEFAULT 'info',
    priority ENUM('low', 'medium', 'high', 'urgent') DEFAULT 'medium',
    created_by INT NOT NULL,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id)
);
```

### User Notifications Table
```sql
CREATE TABLE user_notifications (
    id INT PRIMARY KEY AUTO_INCREMENT,
    notification_id INT NOT NULL,
    user_id INT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (notification_id) REFERENCES notifications(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_notification (notification_id, user_id)
);
```

## API Endpoints

### Send Notification (Admin Only)
```
POST /api/notifications/send
Content-Type: application/json
Authorization: Bearer <token>

{
  "title": "Notification Title",
  "message": "Notification message content",
  "type": "info|warning|error|success",
  "priority": "low|medium|high|urgent",
  "target_cashiers": [1, 2, 3] // Optional: specific cashier IDs
}
```

### Get My Notifications
```
GET /api/notifications/my?unread_only=false&page=1&limit=10
Authorization: Bearer <token>
```

### Mark Notification as Read
```
PUT /api/notifications/{id}/read
Authorization: Bearer <token>
```

### Mark All Notifications as Read
```
PUT /api/notifications/read-all
Authorization: Bearer <token>
```

### Get Cashiers List (Admin Only)
```
GET /api/notifications/cashiers
Authorization: Bearer <token>
```

### Get Notification Statistics (Admin Only)
```
GET /api/notifications/stats
Authorization: Bearer <token>
```

## Frontend Components

### NotificationProvider
Manages notification state and API calls:
- `fetchMyNotifications()` - Load user's notifications
- `sendNotification()` - Send notification to cashiers
- `markAsRead()` - Mark notification as read
- `markAllAsRead()` - Mark all notifications as read
- `getCashiers()` - Get list of cashiers
- `getNotificationStats()` - Get notification statistics

### NotificationsScreen
Main notification interface with two tabs:
1. **My Notifications** - View received notifications
2. **Send Message** - Send notifications to cashiers (admin only)

### NotificationBadge
Widget that displays unread notification count with a red badge.

## Setup Instructions

### 1. Database Setup
Run the notification tables migration:
```bash
mysql -u your_username -p retail_management < backend/add_notification_tables.sql
```

### 2. Backend Setup
The notification routes are already registered in `backend/src/index.js`:
```javascript
app.use('/api/notifications', require('./routes/notifications'));
```

### 3. Frontend Setup
The NotificationProvider is registered in `frontend/lib/main.dart`:
```dart
ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
  create: (_) => NotificationProvider(AuthProvider(ApiService(), prefs)),
  update: (_, auth, previous) => previous ?? NotificationProvider(auth),
),
```

### 4. Generate Model Files
Run the build runner to generate the notification model files:
```bash
cd frontend
flutter packages pub run build_runner build --delete-conflicting-outputs
```

## Usage

### For Admins
1. Navigate to the Notifications tab in the app
2. Switch to the "Send Message" tab
3. Fill in the notification details:
   - Title and message
   - Type (info, warning, error, success)
   - Priority (low, medium, high, urgent)
   - Select target cashiers (or leave empty for all)
4. Click "Send Notification"

### For Cashiers
1. Navigate to the Notifications tab
2. View received notifications in the "My Notifications" tab
3. Tap on unread notifications to mark them as read
4. Use "Mark all as read" to mark all notifications as read

## Security Features

- **Role-based access**: Only admins can send notifications
- **Business isolation**: Admins can only send to cashiers in their business
- **Authentication required**: All endpoints require valid JWT token
- **Input validation**: All notification data is validated
- **Audit logging**: All notification actions are logged

## Multi-language Support

The notification system supports both English and Somali languages through the translation system.

## Future Enhancements

- Push notifications for real-time alerts
- Email notifications
- Notification templates
- Scheduled notifications
- Rich media support (images, links)
- Notification preferences per user 