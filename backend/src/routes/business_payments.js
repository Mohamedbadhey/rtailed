const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { auth, checkRole } = require('../middleware/auth');

// Get business payment status (superadmin only)
router.get('/status/:businessId', [auth, checkRole(['superadmin'])], async (req, res) => {
  try {
    const { businessId } = req.params;
    
    const [businesses] = await pool.query(
      `SELECT 
        b.id, b.name, b.business_code, b.payment_status, b.is_active,
        b.last_payment_date, b.next_payment_due_date, b.grace_period_end_date,
        b.suspension_date, b.suspension_reason, b.auto_suspension_enabled,
        b.subscription_plan, b.monthly_fee,
        COUNT(DISTINCT u.id) as active_users,
        COUNT(DISTINCT p.id) as total_products
       FROM businesses b
       LEFT JOIN users u ON b.id = u.business_id AND u.is_deleted = 0
       LEFT JOIN products p ON b.id = p.business_id AND p.is_deleted = 0
       WHERE b.id = ?
       GROUP BY b.id`,
      [businessId]
    );
    
    if (businesses.length === 0) {
      return res.status(404).json({ message: 'Business not found' });
    }
    
    const business = businesses[0];
    
    // Get overdue bills
    const [overdueBills] = await pool.query(
      `SELECT id, billing_month, total_amount, due_date, status
       FROM monthly_bills 
       WHERE business_id = ? AND status IN ('pending', 'overdue')
       ORDER BY due_date DESC`,
      [businessId]
    );
    
    // Get payment status history
    const [statusHistory] = await pool.query(
      `SELECT status_from, status_to, reason, triggered_by, created_at
       FROM business_payment_status_log 
       WHERE business_id = ?
       ORDER BY created_at DESC
       LIMIT 10`,
      [businessId]
    );
    
    res.json({
      business,
      overdueBills,
      statusHistory
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get all businesses payment status (superadmin only)
router.get('/all-status', [auth, checkRole(['superadmin'])], async (req, res) => {
  try {
    const { status, page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;
    
    let whereClause = 'WHERE 1=1';
    const params = [];
    
    if (status) {
      whereClause += ' AND b.payment_status = ?';
      params.push(status);
    }
    
    const [businesses] = await pool.query(
      `SELECT 
        b.id, b.name, b.business_code, b.payment_status, b.is_active,
        b.last_payment_date, b.next_payment_due_date, b.grace_period_end_date,
        b.suspension_date, b.suspension_reason,
        b.subscription_plan, b.monthly_fee,
        COUNT(DISTINCT u.id) as active_users,
        COUNT(DISTINCT p.id) as total_products,
        (SELECT COUNT(*) FROM monthly_bills mb WHERE mb.business_id = b.id AND mb.status IN ('pending', 'overdue')) as overdue_bills_count
       FROM businesses b
       LEFT JOIN users u ON b.id = u.business_id AND u.is_deleted = 0
       LEFT JOIN products p ON b.id = p.business_id AND p.is_deleted = 0
       ${whereClause}
       GROUP BY b.id
       ORDER BY b.payment_status DESC, b.next_payment_due_date ASC
       LIMIT ? OFFSET ?`,
      [...params, parseInt(limit), offset]
    );
    
    // Get total count
    const [countResult] = await pool.query(
      `SELECT COUNT(*) as total FROM businesses b ${whereClause}`,
      params
    );
    
    res.json({
      businesses,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: countResult[0].total,
        pages: Math.ceil(countResult[0].total / limit)
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Manually suspend a business (superadmin only)
router.post('/suspend/:businessId', [auth, checkRole(['superadmin'])], async (req, res) => {
  try {
    const { businessId } = req.params;
    const { reason } = req.body;
    
    const [businesses] = await pool.query(
      'SELECT id, name, payment_status FROM businesses WHERE id = ?',
      [businessId]
    );
    
    if (businesses.length === 0) {
      return res.status(404).json({ message: 'Business not found' });
    }
    
    const business = businesses[0];
    
    if (business.payment_status === 'suspended') {
      return res.status(400).json({ message: 'Business is already suspended' });
    }
    
    // Update business status
    await pool.query(
      `UPDATE businesses 
       SET payment_status = 'suspended', 
           suspension_date = NOW(), 
           suspension_reason = ?,
           is_active = 0
       WHERE id = ?`,
      [reason || 'Manually suspended by administrator', businessId]
    );
    
    // Log status change
    await pool.query(
      `INSERT INTO business_payment_status_log 
       (business_id, status_from, status_to, reason, triggered_by, triggered_by_user_id)
       VALUES (?, ?, 'suspended', ?, 'manual', ?)`,
      [businessId, business.payment_status, reason || 'Manually suspended', req.user.id]
    );
    
    // Create suspension notification
    await pool.query(
      `INSERT INTO business_suspension_notifications 
       (business_id, notification_type, message)
       VALUES (?, 'suspension_notice', ?)`,
      [businessId, reason || 'Your business has been suspended by an administrator.']
    );
    
    res.json({ 
      message: 'Business suspended successfully',
      businessId,
      reason: reason || 'Manually suspended by administrator'
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Reactivate a business (superadmin only)
router.post('/reactivate/:businessId', [auth, checkRole(['superadmin'])], async (req, res) => {
  try {
    const { businessId } = req.params;
    const { reason } = req.body;
    
    const [businesses] = await pool.query(
      'SELECT id, name, payment_status FROM businesses WHERE id = ?',
      [businessId]
    );
    
    if (businesses.length === 0) {
      return res.status(404).json({ message: 'Business not found' });
    }
    
    const business = businesses[0];
    
    if (business.payment_status === 'active') {
      return res.status(400).json({ message: 'Business is already active' });
    }
    
    // Update business status
    await pool.query(
      `UPDATE businesses 
       SET payment_status = 'active', 
           suspension_date = NULL, 
           suspension_reason = NULL,
           is_active = 1,
           last_payment_date = CURDATE()
       WHERE id = ?`,
      [businessId]
    );
    
    // Log status change
    await pool.query(
      `INSERT INTO business_payment_status_log 
       (business_id, status_from, status_to, reason, triggered_by, triggered_by_user_id)
       VALUES (?, ?, 'active', ?, 'manual', ?)`,
      [businessId, business.payment_status, reason || 'Manually reactivated', req.user.id]
    );
    
    // Create reactivation notification
    await pool.query(
      `INSERT INTO business_suspension_notifications 
       (business_id, notification_type, message)
       VALUES (?, 'reactivation_notice', ?)`,
      [businessId, reason || 'Your business has been reactivated by an administrator.']
    );
    
    res.json({ 
      message: 'Business reactivated successfully',
      businessId,
      reason: reason || 'Manually reactivated'
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Update business payment due date (superadmin only)
router.put('/update-due-date/:businessId', [auth, checkRole(['superadmin'])], async (req, res) => {
  try {
    const { businessId } = req.params;
    const { next_payment_due_date, grace_period_days } = req.body;
    
    const [businesses] = await pool.query(
      'SELECT id, name FROM businesses WHERE id = ?',
      [businessId]
    );
    
    if (businesses.length === 0) {
      return res.status(404).json({ message: 'Business not found' });
    }
    
    const updateFields = [];
    const params = [];
    
    if (next_payment_due_date) {
      updateFields.push('next_payment_due_date = ?');
      params.push(next_payment_due_date);
    }
    
    if (grace_period_days !== undefined) {
      updateFields.push('grace_period_days = ?');
      params.push(grace_period_days);
    }
    
    if (updateFields.length === 0) {
      return res.status(400).json({ message: 'No fields to update' });
    }
    
    params.push(businessId);
    
    await pool.query(
      `UPDATE businesses SET ${updateFields.join(', ')} WHERE id = ?`,
      params
    );
    
    res.json({ 
      message: 'Business payment settings updated successfully',
      businessId
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get business payment notifications (superadmin only)
router.get('/notifications/:businessId', [auth, checkRole(['superadmin'])], async (req, res) => {
  try {
    const { businessId } = req.params;
    
    const [notifications] = await pool.query(
      `SELECT id, notification_type, message, sent_at, is_read, read_at
       FROM business_suspension_notifications 
       WHERE business_id = ?
       ORDER BY sent_at DESC
       LIMIT 50`,
      [businessId]
    );
    
    res.json({ notifications });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Mark notification as read (superadmin only)
router.put('/notifications/:notificationId/read', [auth, checkRole(['superadmin'])], async (req, res) => {
  try {
    const { notificationId } = req.params;
    
    await pool.query(
      `UPDATE business_suspension_notifications 
       SET is_read = 1, read_at = NOW()
       WHERE id = ?`,
      [notificationId]
    );
    
    res.json({ message: 'Notification marked as read' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get payment status summary (superadmin only)
router.get('/summary', [auth, checkRole(['superadmin'])], async (req, res) => {
  try {
    // Get counts by payment status
    const [statusCounts] = await pool.query(
      `SELECT 
        payment_status,
        COUNT(*) as count
       FROM businesses 
       GROUP BY payment_status`
    );
    
    // Get overdue businesses count
    const [overdueCount] = await pool.query(
      `SELECT COUNT(DISTINCT b.id) as count
       FROM businesses b
       JOIN monthly_bills mb ON b.id = mb.business_id
       WHERE mb.status IN ('pending', 'overdue') 
       AND mb.due_date < CURDATE()`
    );
    
    // Get suspended businesses count
    const [suspendedCount] = await pool.query(
      `SELECT COUNT(*) as count
       FROM businesses 
       WHERE payment_status = 'suspended'`
    );
    
    // Get total revenue from active subscriptions
    const [revenueData] = await pool.query(
      `SELECT 
        COALESCE(SUM(monthly_fee), 0) as total_monthly_revenue,
        COUNT(*) as active_businesses
       FROM businesses 
       WHERE payment_status = 'active'`
    );
    
    res.json({
      statusCounts,
      overdueCount: overdueCount[0].count,
      suspendedCount: suspendedCount[0].count,
      totalMonthlyRevenue: revenueData[0].total_monthly_revenue,
      activeBusinesses: revenueData[0].active_businesses
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Manually trigger payment status check (superadmin only)
router.post('/check-status', [auth, checkRole(['superadmin'])], async (req, res) => {
  try {
    // Call the stored procedure to check business payment status
    await pool.query('CALL CheckBusinessPaymentStatus()');
    
    res.json({ message: 'Business payment status check completed' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router; 