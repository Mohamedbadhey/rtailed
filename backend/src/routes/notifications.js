const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { auth, checkRole } = require('../middleware/auth');

// Middleware to ensure admin access
const adminOnly = checkRole(['admin', 'superadmin']);

// Send notification (admin to cashiers, or cashier to admin/superadmin, or reply to existing notification)
router.post('/send', auth, async (req, res) => {
  try {
    const { title, message, type = 'info', priority = 'medium', target_cashiers, target_admins, parent_id } = req.body;

    console.log('=== SEND NOTIFICATION DEBUG ===');
    console.log('Raw request body:', req.body);
    console.log('Parsed parent_id:', parent_id, 'Type:', typeof parent_id);
    console.log('Send notification request:', {
      title,
      message: message ? message.substring(0, 50) + '...' : null,
      type,
      priority,
      parent_id,
      parent_id_type: typeof parent_id,
      user_id: req.user.id,
      user_role: req.user.role,
      business_id: req.user.business_id
    });

    if (!message) {
      return res.status(400).json({ message: 'Message is required' });
    }

    // If this is a reply, validate parent notification exists and user has access
    if (parent_id) {
      console.log('Processing reply to parent_id:', parent_id);
      const [parentNotification] = await pool.query(
        'SELECT n.*, un.user_id FROM notifications n INNER JOIN user_notifications un ON n.id = un.notification_id WHERE n.id = ? AND un.user_id = ? AND n.business_id = ?',
        [parent_id, req.user.id, req.user.business_id]
      );
      
      console.log('Parent notification found:', parentNotification.length > 0);
      
      if (parentNotification.length === 0) {
        return res.status(404).json({ message: 'Parent notification not found or access denied' });
      }
    }

    const validTypes = ['info', 'warning', 'error', 'success'];
    if (!validTypes.includes(type)) {
      return res.status(400).json({ message: 'Invalid notification type' });
    }

    const validPriorities = ['low', 'medium', 'high', 'urgent'];
    const notificationPriority = validPriorities.includes(priority) ? priority : 'medium';

    let businessId = req.user.business_id;
    if (!businessId) {
      return res.status(400).json({ message: 'Business ID is required' });
    }

    // Use title from parent if this is a reply, otherwise require title
    let notificationTitle = title;
    if (parent_id && !title) {
      const [parent] = await pool.query('SELECT title FROM notifications WHERE id = ?', [parent_id]);
      if (parent.length > 0) {
        notificationTitle = `Re: ${parent[0].title}`;
      }
    } else if (!title) {
      return res.status(400).json({ message: 'Title is required' });
    }

    console.log('Creating notification with title:', notificationTitle, 'parent_id:', parent_id, 'parent_id_type:', typeof parent_id);

    // Create notification
    const insertQuery = 'INSERT INTO notifications (business_id, parent_id, title, message, type, priority, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)';
    const insertParams = [businessId, parent_id || null, notificationTitle, message, type, notificationPriority, req.user.id];
    
    console.log('Insert query:', insertQuery);
    console.log('Insert params:', insertParams);
    
    const [result] = await pool.query(insertQuery, insertParams);
    const notificationId = result.insertId;

    console.log('Notification created with ID:', notificationId);

    let recipients = [];
    if (parent_id) {
      // For replies, send to the original sender and all other recipients of the parent
      const [parentRecipients] = await pool.query(
        'SELECT DISTINCT un.user_id FROM user_notifications un INNER JOIN notifications n ON un.notification_id = n.id WHERE n.id = ? AND un.user_id != ?',
        [parent_id, req.user.id]
      );
      recipients = parentRecipients.map(r => [notificationId, r.user_id]);
      console.log('Reply recipients:', recipients.length);
    } else if (req.user.role === 'cashier') {
      // Cashier sends to all admins and superadmins in their business
      const [admins] = await pool.query(
        'SELECT id FROM users WHERE role IN ("admin", "superadmin") AND business_id = ? AND is_active = 1',
        [businessId]
      );
      recipients = admins.map(a => [notificationId, a.id]);
      console.log('Cashier sending to admins:', recipients.length);
    } else if (req.user.role === 'admin' || req.user.role === 'superadmin') {
      // Admin sends to cashiers (existing logic)
      let cashiersQuery = 'SELECT id FROM users WHERE role = "cashier" AND is_active = 1 AND business_id = ?';
      let cashiersParams = [businessId];
      if (target_cashiers && Array.isArray(target_cashiers) && target_cashiers.length > 0) {
        cashiersQuery += ' AND id IN (' + target_cashiers.map(() => '?').join(',') + ')';
        cashiersParams.push(...target_cashiers);
      }
      const [cashiers] = await pool.query(cashiersQuery, cashiersParams);
      recipients = cashiers.map(cashier => [notificationId, cashier.id]);
      console.log('Admin sending to cashiers:', recipients.length);
    }

    if (recipients.length === 0) {
      return res.status(400).json({ message: 'No recipients found' });
    }

    // Add the sender to recipients so they can see their sent messages
    recipients.push([notificationId, req.user.id]);

    await pool.query(
      'INSERT INTO user_notifications (notification_id, user_id) VALUES ?',
      [recipients]
    );

    console.log('User notifications created for recipients:', recipients.length);

    // Log the action
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'SEND_NOTIFICATION', 'notifications', notificationId, JSON.stringify({ 
        title: notificationTitle, 
        type, 
        priority, 
        target_count: recipients.length, 
        business_id: businessId,
        parent_id: parent_id || null
      })]
    );

    console.log('=== SEND NOTIFICATION COMPLETE ===');

    res.status(201).json({ 
      message: 'Notification sent successfully',
      notification_id: notificationId,
      sent_to: recipients.length,
      business_id: businessId,
      parent_id: parent_id || null
    });
  } catch (error) {
    console.error('Error sending notification:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get thread replies for a specific notification
router.get('/:id/thread', auth, async (req, res) => {
  try {
    const { id } = req.params;
    const { page = 1, limit = 10 } = req.query;
    const offset = (page - 1) * limit;

    // Get the original notification and all its replies
    const query = `
      SELECT 
        n.id,
        n.title,
        n.message,
        n.type,
        n.priority,
        n.created_by,
        n.business_id,
        n.parent_id,
        n.created_at,
        n.updated_at,
        un.is_read,
        un.read_at,
        u.username as created_by_name,
        u.role as created_by_role
      FROM notifications n
      INNER JOIN user_notifications un ON n.id = un.notification_id
      LEFT JOIN users u ON n.created_by = u.id
      WHERE (n.id = ? OR n.parent_id = ?) AND un.user_id = ? AND n.business_id = ?
      ORDER BY n.created_at ASC
      LIMIT ? OFFSET ?
    `;

    const [thread] = await pool.query(query, [id, id, req.user.id, req.user.business_id, parseInt(limit), offset]);

    // Process notifications
    const processedThread = thread.map(notification => ({
      id: notification.id || 0,
      title: notification.title || '',
      message: notification.message || '',
      type: notification.type || 'info',
      priority: notification.priority || 'medium',
      created_by: notification.created_by || 0,
      business_id: notification.business_id || 0,
      parent_id: notification.parent_id,
      created_at: notification.created_at,
      updated_at: notification.updated_at,
      is_read: Boolean(notification.is_read),
      read_at: notification.read_at,
      created_by_name: notification.created_by_name || 'Unknown',
      created_by_role: notification.created_by_role || '',
      direction: notification.created_by === req.user.id ? 'sent' : 'received'
    }));

    res.json({
      thread: processedThread,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: thread.length
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get notifications for current user (cashiers, admins, superadmins) with search and filtering
router.get('/my', auth, async (req, res) => {
  try {
    const { 
      page = 1, 
      limit = 10, 
      unread_only = false,
      search = '',
      type = '',
      priority = '',
      sender_role = '',
      date_from = '',
      date_to = ''
    } = req.query;
    const offset = (page - 1) * limit;

    console.log('Fetching notifications for user:', req.user.id, 'business:', req.user.business_id);

    // Build the base query to get both sent and received messages
    let query = `
      SELECT 
        n.id,
        n.title,
        n.message,
        n.type,
        n.priority,
        n.created_by,
        n.business_id,
        n.parent_id,
        n.created_at,
        n.updated_at,
        COALESCE(un.is_read, 0) as is_read,
        un.read_at,
        u.username as created_by_name,
        u.role as created_by_role,
        CASE 
          WHEN n.created_by = ? THEN 'sent'
          ELSE 'received'
        END as direction
      FROM notifications n
      LEFT JOIN user_notifications un ON n.id = un.notification_id AND un.user_id = ?
      LEFT JOIN users u ON n.created_by = u.id
      WHERE n.business_id = ? AND (n.created_by = ? OR un.user_id = ?)
    `;

    const queryParams = [req.user.id, req.user.id, req.user.business_id, req.user.id, req.user.id];

    // Add search filter
    if (search && search.length > 0) {
      query += ' AND (n.title LIKE ? OR n.message LIKE ? OR u.username LIKE ?)';
      const searchTerm = `%${search}%`;
      queryParams.push(searchTerm, searchTerm, searchTerm);
    }

    // Add type filter
    if (type && type.length > 0) {
      query += ' AND n.type = ?';
      queryParams.push(type);
    }

    // Add priority filter
    if (priority && priority.length > 0) {
      query += ' AND n.priority = ?';
      queryParams.push(priority);
    }

    // Add sender role filter
    if (sender_role && sender_role.length > 0) {
      query += ' AND u.role = ?';
      queryParams.push(sender_role);
    }

    // Add date range filters
    if (date_from && date_from.length > 0) {
      query += ' AND DATE(n.created_at) >= ?';
      queryParams.push(date_from);
    }

    if (date_to && date_to.length > 0) {
      query += ' AND DATE(n.created_at) <= ?';
      queryParams.push(date_to);
    }

    // Add unread filter (only applies to received messages)
    if (unread_only === 'true') {
      query += ' AND (n.created_by != ? OR un.is_read = 0)';
      queryParams.push(req.user.id);
    }

    query += ' ORDER BY n.created_at DESC LIMIT ? OFFSET ?';
    queryParams.push(parseInt(limit), offset);

    console.log('Query:', query);
    console.log('Query params:', queryParams);

    const [notifications] = await pool.query(query, queryParams);

    console.log('Raw notifications from DB:', notifications.length);

    // Process notifications to ensure all required fields are present
    const processedNotifications = notifications.map(notification => ({
      id: notification.id || 0,
      title: notification.title || '',
      message: notification.message || '',
      type: notification.type || 'info',
      priority: notification.priority || 'medium',
      created_by: notification.created_by || 0,
      business_id: notification.business_id || 0,
      parent_id: notification.parent_id,
      created_at: notification.created_at,
      updated_at: notification.updated_at,
      is_read: Boolean(notification.is_read),
      read_at: notification.read_at,
      created_by_name: notification.created_by_name || 'Unknown',
      created_by_role: notification.created_by_role || '',
      direction: notification.direction || 'received'
    }));

    console.log('Processed notifications:', processedNotifications.length);

    // Get total count for pagination (without limit/offset)
    let countQuery = `
      SELECT COUNT(*) as total
      FROM notifications n
      LEFT JOIN user_notifications un ON n.id = un.notification_id AND un.user_id = ?
      LEFT JOIN users u ON n.created_by = u.id
      WHERE n.business_id = ? AND (n.created_by = ? OR un.user_id = ?)
    `;
    const countParams = [req.user.id, req.user.business_id, req.user.id, req.user.id];

    // Add the same filters to count query
    if (search && search.length > 0) {
      countQuery += ' AND (n.title LIKE ? OR n.message LIKE ? OR u.username LIKE ?)';
      const searchTerm = `%${search}%`;
      countParams.push(searchTerm, searchTerm, searchTerm);
    }
    if (type && type.length > 0) {
      countQuery += ' AND n.type = ?';
      countParams.push(type);
    }
    if (priority && priority.length > 0) {
      countQuery += ' AND n.priority = ?';
      countParams.push(priority);
    }
    if (sender_role && sender_role.length > 0) {
      countQuery += ' AND u.role = ?';
      countParams.push(sender_role);
    }
    if (date_from && date_from.length > 0) {
      countQuery += ' AND DATE(n.created_at) >= ?';
      countParams.push(date_from);
    }
    if (date_to && date_to.length > 0) {
      countQuery += ' AND DATE(n.created_at) <= ?';
      countParams.push(date_to);
    }
    if (unread_only === 'true') {
      countQuery += ' AND (n.created_by != ? OR un.is_read = 0)';
      countParams.push(req.user.id);
    }

    const [totalCount] = await pool.query(countQuery, countParams);

    // Get unread count for received messages only
    const [unreadCount] = await pool.query(
      'SELECT COUNT(*) as count FROM user_notifications un INNER JOIN notifications n ON un.notification_id = n.id WHERE un.user_id = ? AND n.business_id = ? AND un.is_read = 0',
      [req.user.id, req.user.business_id]
    );

    console.log('Total count:', totalCount[0].total, 'Unread count:', unreadCount[0].count);

    res.json({
      notifications: processedNotifications,
      unread_count: unreadCount[0].count,
      total_count: totalCount[0].total,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalCount[0].total
      }
    });
  } catch (error) {
    console.error('Error fetching notifications:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Mark notification as read
router.put('/:id/read', auth, async (req, res) => {
  try {
    const { id } = req.params;

    console.log('Marking notification as read:', { notification_id: id, user_id: req.user.id });

    // First, check if the user is the creator of this notification
    const [notification] = await pool.query(
      'SELECT id, created_by, business_id FROM notifications WHERE id = ? AND business_id = ?',
      [id, req.user.business_id]
    );

    if (notification.length === 0) {
      return res.status(404).json({ message: 'Notification not found' });
    }

    const notificationData = notification[0];
    let result;

    if (notificationData.created_by === req.user.id) {
      // User is the creator - for sent messages, we don't need to mark as read
      // But we can create a user_notifications entry to track read status
      console.log('User is creator of notification, creating user_notifications entry');
      
      // Check if entry already exists
      const [existing] = await pool.query(
        'SELECT id FROM user_notifications WHERE notification_id = ? AND user_id = ?',
        [id, req.user.id]
      );

      if (existing.length === 0) {
        // Create entry for sent message
        await pool.query(
          'INSERT INTO user_notifications (notification_id, user_id, is_read, read_at) VALUES (?, ?, 1, NOW())',
          [id, req.user.id]
        );
      } else {
        // Update existing entry
        await pool.query(
          'UPDATE user_notifications SET is_read = 1, read_at = NOW() WHERE notification_id = ? AND user_id = ?',
          [id, req.user.id]
        );
      }
      
      result = { affectedRows: 1 };
    } else {
      // User is a recipient - update the existing user_notifications entry
      console.log('User is recipient of notification, updating user_notifications');
      
      result = await pool.query(
        'UPDATE user_notifications SET is_read = 1, read_at = NOW() WHERE notification_id = ? AND user_id = ?',
        [id, req.user.id]
      );
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'Notification not found or already marked as read' });
    }

    console.log('Notification marked as read successfully');

    res.json({ message: 'Notification marked as read' });
  } catch (error) {
    console.error('Error marking notification as read:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Mark all notifications as read
router.put('/read-all', auth, async (req, res) => {
  try {
    console.log('Marking all notifications as read for user:', req.user.id);

    // First, mark all received notifications as read
    await pool.query(
      'UPDATE user_notifications SET is_read = 1, read_at = NOW() WHERE user_id = ? AND is_read = 0',
      [req.user.id]
    );

    // Then, ensure all sent notifications have user_notifications entries marked as read
    const [sentNotifications] = await pool.query(
      'SELECT id FROM notifications WHERE created_by = ? AND business_id = ?',
      [req.user.id, req.user.business_id]
    );

    for (const notification of sentNotifications) {
      // Check if entry exists
      const [existing] = await pool.query(
        'SELECT id FROM user_notifications WHERE notification_id = ? AND user_id = ?',
        [notification.id, req.user.id]
      );

      if (existing.length === 0) {
        // Create entry for sent message
        await pool.query(
          'INSERT INTO user_notifications (notification_id, user_id, is_read, read_at) VALUES (?, ?, 1, NOW())',
          [notification.id, req.user.id]
        );
      } else {
        // Update existing entry
        await pool.query(
          'UPDATE user_notifications SET is_read = 1, read_at = NOW() WHERE notification_id = ? AND user_id = ?',
          [notification.id, req.user.id]
        );
      }
    }

    console.log('All notifications marked as read successfully');

    res.json({ message: 'All notifications marked as read' });
  } catch (error) {
    console.error('Error marking all notifications as read:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Delete notification (admin only)
router.delete('/:id', auth, adminOnly, async (req, res) => {
  try {
    const { id } = req.params;

    // Delete user notifications first
    await pool.query('DELETE FROM user_notifications WHERE notification_id = ?', [id]);

    // Delete the notification (soft delete if is_deleted column exists, otherwise hard delete)
    let result;
    try {
      result = await pool.query('UPDATE notifications SET is_deleted = 1 WHERE id = ?', [id]);
    } catch (error) {
      // If is_deleted column doesn't exist, do hard delete
      if (error.code === 'ER_BAD_FIELD_ERROR') {
        result = await pool.query('DELETE FROM notifications WHERE id = ?', [id]);
      } else {
        throw error;
      }
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'Notification not found' });
    }

    // Log the action
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'DELETE_NOTIFICATION', 'notifications', id, JSON.stringify({ deleted: true })]
    );

    res.json({ message: 'Notification deleted successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get cashiers list for admin to select from
router.get('/cashiers', auth, adminOnly, async (req, res) => {
  try {
    let query = 'SELECT id, username, email, is_active, last_login FROM users WHERE role = "cashier"';
    let params = [];

    // If user is not superadmin, filter by their business_id
    if (req.user.role !== 'superadmin' && req.user.business_id) {
      query += ' AND business_id = ?';
      params.push(req.user.business_id);
    }

    query += ' ORDER BY username';

    const [cashiers] = await pool.query(query, params);

    res.json({ cashiers });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get notification statistics for admin
router.get('/stats', auth, adminOnly, async (req, res) => {
  try {
    let whereClause = 'WHERE 1=1';
    let params = [];

    // If user is not superadmin, filter by their business_id
    if (req.user.role !== 'superadmin' && req.user.business_id) {
      whereClause += ' AND n.created_by IN (SELECT id FROM users WHERE business_id = ?)';
      params.push(req.user.business_id);
    }

    // Total notifications sent by this admin
    const [totalSent] = await pool.query(
      `SELECT COUNT(*) as count FROM notifications n ${whereClause}`,
      params
    );

    // Notifications by type
    const [byType] = await pool.query(
      `SELECT type, COUNT(*) as count FROM notifications n ${whereClause} GROUP BY type`,
      params
    );

    // Notifications by priority
    const [byPriority] = await pool.query(
      `SELECT priority, COUNT(*) as count FROM notifications n ${whereClause} GROUP BY priority`,
      params
    );

    // Recent notifications (last 7 days)
    const [recent] = await pool.query(
      `SELECT COUNT(*) as count FROM notifications n ${whereClause} AND n.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)`,
      params
    );

    // Total unread notifications for cashiers in this business
    let unreadQuery = `
      SELECT COUNT(*) as count 
      FROM user_notifications un 
      INNER JOIN notifications n ON un.notification_id = n.id 
      INNER JOIN users u ON un.user_id = u.id 
      WHERE un.is_read = 0 AND u.role = 'cashier'
    `;
    let unreadParams = [];

    if (req.user.role !== 'superadmin' && req.user.business_id) {
      unreadQuery += ' AND u.business_id = ?';
      unreadParams.push(req.user.business_id);
    }

    const [unread] = await pool.query(unreadQuery, unreadParams);

    res.json({
      total_sent: totalSent[0].count,
      by_type: byType,
      by_priority: byPriority,
      recent_7_days: recent[0].count,
      unread_total: unread[0].count
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router; 