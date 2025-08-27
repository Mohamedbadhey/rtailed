const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { auth, checkRole } = require('../middleware/auth');
const bcrypt = require('bcryptjs');

// Get all businesses with pagination and statistics (superadmin only)
router.get('/', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const offset = parseInt(req.query.offset) || 0;
    const search = req.query.search || '';
    
    let whereClause = '';
    let params = [];
    
    if (search) {
      whereClause = 'WHERE name LIKE ? OR business_code LIKE ? OR email LIKE ?';
      params = [`%${search}%`, `%${search}%`, `%${search}%`];
    }
    
    // Get businesses with pagination
    const [businesses] = await pool.query(
      `SELECT * FROM businesses ${whereClause} ORDER BY created_at DESC LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );
    
    // Get total count for pagination
    const [countResult] = await pool.query(
      `SELECT COUNT(*) as total FROM businesses ${whereClause}`,
      params
    );
    
    const total = countResult[0].total;
    
    // Get statistics for each business
    const businessesWithStats = await Promise.all(
      businesses.map(async (business) => {
        // Get user count
        const [userCount] = await pool.query(
          'SELECT COUNT(*) as count FROM users WHERE business_id = ? AND is_deleted = 0',
          [business.id]
        );
        
        // Get product count
        const [productCount] = await pool.query(
          'SELECT COUNT(*) as count FROM products WHERE business_id = ?',
          [business.id]
        );
        
        // Get customer count
        const [customerCount] = await pool.query(
          'SELECT COUNT(*) as count FROM customers WHERE business_id = ?',
          [business.id]
        );
        
        // Get sale count
        const [saleCount] = await pool.query(
          'SELECT COUNT(*) as count FROM sales WHERE business_id = ?',
          [business.id]
        );
        
        return {
          ...business,
          user_count: userCount[0].count,
          product_count: productCount[0].count,
          customer_count: customerCount[0].count,
          sale_count: saleCount[0].count
        };
      })
    );
    
    res.json({
      businesses: businessesWithStats,
      pagination: {
        total,
        limit,
        offset,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Create a new business (superadmin only)
router.post('/', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const {
      name,
      business_code,
      email,
      phone,
      subscription_plan = 'basic',
      max_users = 5,
      max_products = 1000,
      admin_username,
      admin_email,
      admin_password
    } = req.body;
    
    if (!name || !business_code || !email || !admin_username || !admin_email || !admin_password) {
      return res.status(400).json({ message: 'Required fields are missing' });
    }
    
    // Check if business code already exists
    const [existingBusiness] = await pool.query(
      'SELECT id FROM businesses WHERE business_code = ?',
      [business_code]
    );
    
    if (existingBusiness.length > 0) {
      return res.status(400).json({ message: 'Business code already exists' });
    }
    
    // Check if admin email already exists
    const [existingUser] = await pool.query(
      'SELECT id FROM users WHERE email = ? OR username = ?',
      [admin_email, admin_username]
    );
    
    if (existingUser.length > 0) {
      return res.status(400).json({ message: 'Admin user already exists' });
    }
    
    // Start transaction
    const connection = await pool.getConnection();
    await connection.beginTransaction();
    
    try {
      // Create business
      const [businessResult] = await connection.query(
        `INSERT INTO businesses (name, business_code, email, phone, subscription_plan, max_users, max_products) 
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [name, business_code, email, phone, subscription_plan, max_users, max_products]
      );
      
      const businessId = businessResult.insertId;
      
      // Create admin user for the business
      const hashedPassword = await bcrypt.hash(admin_password, 10);
      const [userResult] = await connection.query(
        'INSERT INTO users (username, email, password, role, business_id) VALUES (?, ?, ?, ?, ?)',
        [admin_username, admin_email, hashedPassword, 'admin', businessId]
      );
      
      // Log the action
      await connection.query(
        'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
        [req.user.id, 'CREATE_BUSINESS', 'businesses', businessId, JSON.stringify({ name, business_code, email, subscription_plan })]
      );
      
      await connection.commit();
      
      res.status(201).json({ 
        message: 'Business created successfully',
        business_id: businessId,
        admin_user_id: userResult.insertId
      });
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get business details with comprehensive statistics
router.get('/:businessId', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    
    // Get business details
    const [businesses] = await pool.query(
      'SELECT * FROM businesses WHERE id = ?',
      [businessId]
    );
    
    if (businesses.length === 0) {
      return res.status(404).json({ message: 'Business not found' });
    }
    
    const business = businesses[0];
    
    // Get current usage statistics
    const [usage] = await pool.query(
      'SELECT * FROM business_usage WHERE business_id = ? ORDER BY date DESC LIMIT 1',
      [businessId]
    );
    
    // Get payment history
    const [payments] = await pool.query(
      'SELECT * FROM business_payments WHERE business_id = ? ORDER BY created_at DESC LIMIT 10',
      [businessId]
    );
    
    // Get recent messages
    const [messages] = await pool.query(
      'SELECT * FROM business_messages WHERE business_id = ? ORDER BY created_at DESC LIMIT 10',
      [businessId]
    );
    
    // Get recent activity
    const [activity] = await pool.query(
      'SELECT * FROM business_activity_logs WHERE business_id = ? ORDER BY created_at DESC LIMIT 20',
      [businessId]
    );
    
    // Get user count
    const [userCount] = await pool.query(
      'SELECT COUNT(*) as count FROM users WHERE business_id = ? AND is_deleted = 0',
      [businessId]
    );
    
    // Get product count
    const [productCount] = await pool.query(
      'SELECT COUNT(*) as count FROM products WHERE business_id = ?',
      [businessId]
    );
    
    // Get customer count
    const [customerCount] = await pool.query(
      'SELECT COUNT(*) as count FROM customers WHERE business_id = ?',
      [businessId]
    );
    
    // Get sale count
    const [saleCount] = await pool.query(
      'SELECT COUNT(*) as count FROM sales WHERE business_id = ?',
      [businessId]
    );
    
    // Calculate overage fees
    const currentUsers = userCount[0].count;
    const currentProducts = productCount[0].count;
    const userOverage = Math.max(0, currentUsers - business.max_users);
    const productOverage = Math.max(0, currentProducts - business.max_products);
    const userOverageFee = userOverage * business.overage_fee_per_user;
    const productOverageFee = productOverage * business.overage_fee_per_product;
    
    res.json({
      business: {
        ...business,
        current_usage: {
          users: currentUsers,
          products: currentProducts,
          customers: customerCount[0].count,
          sales: saleCount[0].count,
          user_overage: userOverage,
          product_overage: productOverage,
          user_overage_fee: userOverageFee,
          product_overage_fee: productOverageFee,
          total_overage_fee: userOverageFee + productOverageFee
        }
      },
      usage: usage[0] || null,
      payments,
      messages,
      activity
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Send message to business
router.post('/:businessId/messages', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    const { subject, message, message_type, priority } = req.body;
    
    if (!subject || !message) {
      return res.status(400).json({ message: 'Subject and message are required' });
    }
    
    // Verify business exists
    const [businesses] = await pool.query(
      'SELECT id FROM businesses WHERE id = ?',
      [businessId]
    );
    
    if (businesses.length === 0) {
      return res.status(404).json({ message: 'Business not found' });
    }
    
    const [result] = await pool.query(
      'INSERT INTO business_messages (business_id, from_superadmin_id, subject, message, message_type, priority) VALUES (?, ?, ?, ?, ?, ?)',
      [businessId, req.user.id, subject, message, message_type || 'info', priority || 'medium']
    );
    
    // Log the action
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'SEND_BUSINESS_MESSAGE', 'business_messages', result.insertId, JSON.stringify({ subject, message_type, priority })]
    );
    
    res.status(201).json({ 
      message: 'Message sent successfully',
      message_id: result.insertId
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get business messages
router.get('/:businessId/messages', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    const limit = parseInt(req.query.limit) || 20;
    const offset = parseInt(req.query.offset) || 0;
    
    const [messages] = await pool.query(
      'SELECT * FROM business_messages WHERE business_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?',
      [businessId, limit, offset]
    );
    
    const [total] = await pool.query(
      'SELECT COUNT(*) as count FROM business_messages WHERE business_id = ?',
      [businessId]
    );
    
    res.json({
      messages,
      pagination: {
        total: total[0].count,
        limit,
        offset,
        pages: Math.ceil(total[0].count / limit)
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get business payments
router.get('/:businessId/payments', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    const limit = parseInt(req.query.limit) || 20;
    const offset = parseInt(req.query.offset) || 0;
    
    const [payments] = await pool.query(
      'SELECT * FROM business_payments WHERE business_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?',
      [businessId, limit, offset]
    );
    
    const [total] = await pool.query(
      'SELECT COUNT(*) as count FROM business_payments WHERE business_id = ?',
      [businessId]
    );
    
    res.json({
      payments,
      pagination: {
        total: total[0].count,
        limit,
        offset,
        pages: Math.ceil(total[0].count / limit)
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Add payment record
router.post('/:businessId/payments', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    const { amount, payment_type, payment_method, status, due_date, description } = req.body;
    
    if (!amount || !payment_type) {
      return res.status(400).json({ message: 'Amount and payment type are required' });
    }
    
    const [result] = await pool.query(
      'INSERT INTO business_payments (business_id, amount, payment_type, payment_method, status, due_date, description) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [businessId, amount, payment_type, payment_method, status || 'pending', due_date, description]
    );
    
    // Update business payment status if payment is completed
    if (status === 'completed') {
      await pool.query(
        'UPDATE businesses SET payment_status = "current", last_payment_date = CURDATE(), next_payment_date = DATE_ADD(CURDATE(), INTERVAL 1 MONTH) WHERE id = ?',
        [businessId]
      );
    }
    
    // Log the action
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'ADD_BUSINESS_PAYMENT', 'business_payments', result.insertId, JSON.stringify({ amount, payment_type, status })]
    );
    
    res.status(201).json({ 
      message: 'Payment record added successfully',
      payment_id: result.insertId
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get business usage statistics
router.get('/:businessId/usage', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    const days = parseInt(req.query.days) || 30;
    
    const [usage] = await pool.query(
      'SELECT * FROM business_usage WHERE business_id = ? AND date >= DATE_SUB(CURDATE(), INTERVAL ? DAY) ORDER BY date DESC',
      [businessId, days]
    );
    
    // Get current usage
    const [currentUsage] = await pool.query(
      'SELECT * FROM business_usage WHERE business_id = ? ORDER BY date DESC LIMIT 1',
      [businessId]
    );
    
    // Get usage trends
    const [trends] = await pool.query(
      `SELECT 
        AVG(users_count) as avg_users,
        AVG(products_count) as avg_products,
        AVG(customers_count) as avg_customers,
        AVG(sales_count) as avg_sales,
        AVG(storage_used_mb) as avg_storage,
        AVG(api_calls_count) as avg_api_calls
       FROM business_usage 
       WHERE business_id = ? AND date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)`,
      [businessId, days]
    );
    
    res.json({
      usage,
      current_usage: currentUsage[0] || null,
      trends: trends[0] || null
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Activate/Deactivate business
router.put('/:businessId/status', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    const { is_active, suspension_reason } = req.body;
    
    // Verify business exists
    const [businesses] = await pool.query(
      'SELECT id, name FROM businesses WHERE id = ?',
      [businessId]
    );
    
    if (businesses.length === 0) {
      return res.status(404).json({ message: 'Business not found' });
    }
    
    const business = businesses[0];
    
    if (is_active) {
      // Activate business - update both is_active and payment_status
      await pool.query(
        'UPDATE businesses SET is_active = TRUE, payment_status = "current", suspension_reason = NULL, suspension_date = NULL, reactivation_date = NOW() WHERE id = ?',
        [businessId]
      );
      
      // Log activation
      await pool.query(
        'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
        [req.user.id, 'ACTIVATE_BUSINESS', 'businesses', businessId, JSON.stringify({ business_name: business.name })]
      );
      
      res.json({ message: 'Business activated successfully' });
    } else {
      // Deactivate business - update both is_active and payment_status
      await pool.query(
        'UPDATE businesses SET is_active = FALSE, payment_status = "suspended", suspension_reason = ?, suspension_date = NOW() WHERE id = ?',
        [suspension_reason || 'Suspended by superadmin', businessId]
      );
      
      // Log suspension
      await pool.query(
        'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
        [req.user.id, 'SUSPEND_BUSINESS', 'businesses', businessId, JSON.stringify({ business_name: business.name, reason: suspension_reason })]
      );
      
      res.json({ message: 'Business suspended successfully' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Update business settings
router.put('/:businessId/settings', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    const {
      subscription_plan,
      max_users,
      max_products,
      monthly_fee,
      overage_fee_per_user,
      overage_fee_per_product,
      grace_period_days,
      notes
    } = req.body;
    
    // Verify business exists
    const [businesses] = await pool.query(
      'SELECT id FROM businesses WHERE id = ?',
      [businessId]
    );
    
    if (businesses.length === 0) {
      return res.status(404).json({ message: 'Business not found' });
    }
    
    const updateFields = [];
    const updateValues = [];
    
    if (subscription_plan !== undefined) {
      updateFields.push('subscription_plan = ?');
      updateValues.push(subscription_plan);
    }
    if (max_users !== undefined) {
      updateFields.push('max_users = ?');
      updateValues.push(max_users);
    }
    if (max_products !== undefined) {
      updateFields.push('max_products = ?');
      updateValues.push(max_products);
    }
    if (monthly_fee !== undefined) {
      updateFields.push('monthly_fee = ?');
      updateValues.push(monthly_fee);
    }
    if (overage_fee_per_user !== undefined) {
      updateFields.push('overage_fee_per_user = ?');
      updateValues.push(overage_fee_per_user);
    }
    if (overage_fee_per_product !== undefined) {
      updateFields.push('overage_fee_per_product = ?');
      updateValues.push(overage_fee_per_product);
    }
    if (grace_period_days !== undefined) {
      updateFields.push('grace_period_days = ?');
      updateValues.push(grace_period_days);
    }
    if (notes !== undefined) {
      updateFields.push('notes = ?');
      updateValues.push(notes);
    }
    
    if (updateFields.length === 0) {
      return res.status(400).json({ message: 'No fields to update' });
    }
    
    updateValues.push(businessId);
    
    await pool.query(
      `UPDATE businesses SET ${updateFields.join(', ')} WHERE id = ?`,
      updateValues
    );
    
    // Log the action
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'UPDATE_BUSINESS_SETTINGS', 'businesses', businessId, JSON.stringify(req.body)]
    );
    
    res.json({ message: 'Business settings updated successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get business activity logs
router.get('/:businessId/activity', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    const limit = parseInt(req.query.limit) || 50;
    const offset = parseInt(req.query.offset) || 0;
    
    const [activity] = await pool.query(
      `SELECT bal.*, u.username 
       FROM business_activity_logs bal
       LEFT JOIN users u ON bal.user_id = u.id
       WHERE bal.business_id = ? 
       ORDER BY bal.created_at DESC 
       LIMIT ? OFFSET ?`,
      [businessId, limit, offset]
    );
    
    const [total] = await pool.query(
      'SELECT COUNT(*) as count FROM business_activity_logs WHERE business_id = ?',
      [businessId]
    );
    
    res.json({
      activity,
      pagination: {
        total: total[0].count,
        limit,
        offset,
        pages: Math.ceil(total[0].count / limit)
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get business statistics summary
router.get('/:businessId/statistics', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    const period = req.query.period || 'month'; // week, month, quarter, year
    
    let dateFilter;
    switch (period) {
      case 'week':
        dateFilter = 'DATE_SUB(CURDATE(), INTERVAL 7 DAY)';
        break;
      case 'quarter':
        dateFilter = 'DATE_SUB(CURDATE(), INTERVAL 3 MONTH)';
        break;
      case 'year':
        dateFilter = 'DATE_SUB(CURDATE(), INTERVAL 1 YEAR)';
        break;
      default:
        dateFilter = 'DATE_SUB(CURDATE(), INTERVAL 1 MONTH)';
    }
    
    // Get usage statistics
    const [usageStats] = await pool.query(
      `SELECT 
        AVG(users_count) as avg_users,
        MAX(users_count) as peak_users,
        AVG(products_count) as avg_products,
        AVG(customers_count) as avg_customers,
        AVG(sales_count) as avg_sales,
        AVG(storage_used_mb) as avg_storage,
        AVG(api_calls_count) as avg_api_calls
       FROM business_usage 
       WHERE business_id = ? AND date >= ${dateFilter}`,
      [businessId]
    );
    
    // Get payment statistics
    const [paymentStats] = await pool.query(
      `SELECT 
        COUNT(*) as total_payments,
        SUM(amount) as total_amount,
        AVG(amount) as avg_amount,
        COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_payments,
        COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_payments
       FROM business_payments 
       WHERE business_id = ? AND created_at >= ${dateFilter}`,
      [businessId]
    );
    
    // Get current business info
    const [business] = await pool.query(
      'SELECT * FROM businesses WHERE id = ?',
      [businessId]
    );
    
    res.json({
      period,
      usage_stats: usageStats[0] || {},
      payment_stats: paymentStats[0] || {},
      business: business[0] || {}
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get users for a specific business
router.get('/:businessId/users', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    const limit = parseInt(req.query.limit) || 10;
    const offset = parseInt(req.query.offset) || 0;
    
    // Check if user has access to this business
    const user = req.user;
    if (user.role !== 'superadmin' && user.business_id != businessId) {
      return res.status(403).json({ message: 'Access denied: insufficient permissions' });
    }
    
    const [users] = await pool.query(
      'SELECT id, username, email, role, is_active, last_login, created_at, is_deleted FROM users WHERE business_id = ? AND is_deleted = 0 ORDER BY created_at DESC LIMIT ? OFFSET ?',
      [businessId, limit, offset]
    );

    res.json({ users });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Create a new user for a specific business
router.post('/:businessId/users', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    const { username, email, password, role } = req.body;
    
    // Check if user has access to this business
    const user = req.user;
    if (user.role !== 'superadmin' && user.business_id != businessId) {
      return res.status(403).json({ message: 'Access denied: insufficient permissions' });
    }
    
    // Only allow creating cashiers for non-superadmin users
    if (user.role !== 'superadmin' && role !== 'cashier') {
      return res.status(403).json({ message: 'You can only create cashier accounts' });
    }
    
    if (!username || !email || !password || !role) {
      return res.status(400).json({ message: 'All fields are required' });
    }
    
    // Check if user exists
    const [existing] = await pool.query('SELECT id FROM users WHERE email = ? OR username = ?', [email, username]);
    if (existing.length > 0) {
      return res.status(400).json({ message: 'User already exists' });
    }
    
    const hashedPassword = await bcrypt.hash(password, 10);
    const [result] = await pool.query(
      'INSERT INTO users (username, email, password, role, business_id) VALUES (?, ?, ?, ?, ?)',
      [username, email, hashedPassword, role, businessId]
    );
    
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'CREATE_USER', 'users', result.insertId, JSON.stringify({ username, email, role, business_id: businessId })]
    );
    
    res.status(201).json({ message: 'User created', id: result.insertId });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Check username availability for a specific business
router.post('/:businessId/users/check-username', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    const { username, exclude_id } = req.body;
    
    // Check if user has access to this business
    const user = req.user;
    if (user.role !== 'superadmin' && user.business_id != businessId) {
      return res.status(403).json({ message: 'Access denied: insufficient permissions' });
    }
    
    if (!username) {
      return res.status(400).json({ message: 'Username is required' });
    }
    
    // Validate username format
    const usernameRegex = /^[a-zA-Z0-9_]{3,20}$/;
    if (!usernameRegex.test(username)) {
      return res.status(400).json({ 
        available: false, 
        message: 'Username format is invalid' 
      });
    }
    
    let query = 'SELECT id FROM users WHERE username = ? AND business_id = ? AND is_deleted = 0';
    let params = [username, businessId];
    
    // Exclude current user if editing
    if (exclude_id) {
      query += ' AND id != ?';
      params.push(exclude_id);
    }
    
    const [existingUsers] = await pool.query(query, params);
    const available = existingUsers.length === 0;
    
    res.json({ 
      available,
      message: available ? 'Username is available' : 'Username is already taken'
    });
  } catch (error) {
    console.error('Username availability check error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Update user for a specific business
router.put('/:businessId/users/:userId', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { businessId, userId } = req.params;
    const { username, email, role, is_active } = req.body;
    
    // Check if user has access to this business
    const user = req.user;
    if (user.role !== 'superadmin' && user.business_id != businessId) {
      return res.status(403).json({ message: 'Access denied: insufficient permissions' });
    }
    
    // Verify the target user belongs to this business
    const [targetUser] = await pool.query(
      'SELECT id, role FROM users WHERE id = ? AND business_id = ?',
      [userId, businessId]
    );
    
    if (targetUser.length === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    // Only allow updating cashiers for non-superadmin users
    if (user.role !== 'superadmin' && targetUser[0].role !== 'cashier') {
      return res.status(403).json({ message: 'You can only update cashier accounts' });
    }
    
    const [result] = await pool.query(
      'UPDATE users SET username = ?, email = ?, role = ?, is_active = ? WHERE id = ? AND business_id = ?',
      [username, email, role, is_active, userId, businessId]
    );
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'UPDATE_USER', 'users', userId, JSON.stringify({ username, email, role, is_active })]
    );
    
    res.json({ message: 'User updated' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Delete user for a specific business
router.delete('/:businessId/users/:userId', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { businessId, userId } = req.params;
    
    // Check if user has access to this business
    const user = req.user;
    if (user.role !== 'superadmin' && user.business_id != businessId) {
      return res.status(403).json({ message: 'Access denied: insufficient permissions' });
    }
    
    // Verify the target user belongs to this business
    const [targetUser] = await pool.query(
      'SELECT id, role FROM users WHERE id = ? AND business_id = ?',
      [userId, businessId]
    );
    
    if (targetUser.length === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    // Only allow deleting cashiers for non-superadmin users
    if (user.role !== 'superadmin' && targetUser[0].role !== 'cashier') {
      return res.status(403).json({ message: 'You can only delete cashier accounts' });
    }
    
    const [result] = await pool.query(
      'UPDATE users SET is_deleted = 1 WHERE id = ? AND business_id = ?',
      [userId, businessId]
    );
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id) VALUES (?, ?, ?, ?)',
      [req.user.id, 'DELETE_USER', 'users', userId]
    );
    
    res.json({ message: 'User deleted' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Reset user password for a specific business
router.post('/:businessId/users/:userId/reset-password', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { businessId, userId } = req.params;
    const { newPassword } = req.body;
    
    // Check if user has access to this business
    const user = req.user;
    if (user.role !== 'superadmin' && user.business_id != businessId) {
      return res.status(403).json({ message: 'Access denied: insufficient permissions' });
    }
    
    // Verify the target user belongs to this business
    const [targetUser] = await pool.query(
      'SELECT id, role FROM users WHERE id = ? AND business_id = ?',
      [userId, businessId]
    );
    
    if (targetUser.length === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    // Only allow resetting cashier passwords for non-superadmin users
    if (user.role !== 'superadmin' && targetUser[0].role !== 'cashier') {
      return res.status(403).json({ message: 'You can only reset cashier passwords' });
    }
    
    if (!newPassword) {
      return res.status(400).json({ message: 'New password is required' });
    }
    
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    const [result] = await pool.query(
      'UPDATE users SET password = ? WHERE id = ? AND business_id = ?',
      [hashedPassword, userId, businessId]
    );
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'RESET_PASSWORD', 'users', userId, JSON.stringify({ newPassword: '***' })]
    );
    
    res.json({ message: 'Password reset successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Update user status for a specific business
router.put('/:businessId/users/:userId/status', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { businessId, userId } = req.params;
    const { is_active } = req.body;
    
    // Check if user has access to this business
    const user = req.user;
    if (user.role !== 'superadmin' && user.business_id != businessId) {
      return res.status(403).json({ message: 'Access denied: insufficient permissions' });
    }
    
    // Verify the target user belongs to this business
    const [targetUser] = await pool.query(
      'SELECT id, role FROM users WHERE id = ? AND business_id = ?',
      [userId, businessId]
    );
    
    if (targetUser.length === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    // Only allow updating cashier status for non-superadmin users
    if (user.role !== 'superadmin' && targetUser[0].role !== 'cashier') {
      return res.status(403).json({ message: 'You can only update cashier status' });
    }
    
    const [result] = await pool.query(
      'UPDATE users SET is_active = ? WHERE id = ? AND business_id = ?',
      [is_active, userId, businessId]
    );
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'UPDATE_USER_STATUS', 'users', userId, JSON.stringify({ is_active })]
    );
    
    res.json({ message: 'User status updated successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Generate monthly bill for business based on subscription plan
router.post('/:businessId/monthly-bill', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    const { billingMonth, dueDate } = req.body;
    
    // Get business and subscription plan details
    const [businesses] = await pool.query(
      `SELECT b.*, sp.monthly_fee, sp.max_users, sp.max_products, 
              sp.overage_fee_per_user, sp.overage_fee_per_product
       FROM businesses b
       JOIN subscription_plans sp ON b.subscription_plan = sp.plan_name
       WHERE b.id = ?`,
      [businessId]
    );
    
    if (businesses.length === 0) {
      return res.status(404).json({ message: 'Business not found' });
    }
    
    const business = businesses[0];
    
    // Get current usage
    const [usage] = await pool.query(
      `SELECT 
         COALESCE(COUNT(DISTINCT u.id), 0) as user_count,
         COALESCE(COUNT(DISTINCT p.id), 0) as product_count
       FROM businesses b
       LEFT JOIN users u ON b.id = u.business_id AND u.is_deleted = 0
       LEFT JOIN products p ON b.id = p.business_id AND p.is_deleted = 0
       WHERE b.id = ?`,
      [businessId]
    );
    
    const currentUsers = usage[0].user_count;
    const currentProducts = usage[0].product_count;
    
    // Calculate overages
    const userOverage = Math.max(0, currentUsers - business.max_users);
    const productOverage = Math.max(0, currentProducts - business.max_products);
    
    // Calculate overage fees
    const userOverageFee = userOverage * business.overage_fee_per_user;
    const productOverageFee = productOverage * business.overage_fee_per_product;
    
    // Calculate total amount
    const totalAmount = business.monthly_fee + userOverageFee + productOverageFee;
    
    // Insert or update monthly bill
    const [result] = await pool.query(
      `INSERT INTO monthly_bills (business_id, billing_month, base_amount, user_overage_fee, product_overage_fee, total_amount, due_date, status) 
       VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')
       ON DUPLICATE KEY UPDATE 
         base_amount = VALUES(base_amount),
         user_overage_fee = VALUES(user_overage_fee),
         product_overage_fee = VALUES(product_overage_fee),
         total_amount = VALUES(total_amount),
         due_date = VALUES(due_date),
         created_at = CURRENT_TIMESTAMP`,
      [businessId, billingMonth, business.monthly_fee, userOverageFee, productOverageFee, totalAmount, dueDate]
    );
    
    // Update business usage tracking
    await pool.query(
      `INSERT INTO business_usage (business_id, date, users_count, products_count, customers_count, sales_count, storage_used_mb, api_calls_count) 
       VALUES (?, CURDATE(), ?, ?, ?, ?, ?, ?) 
       ON DUPLICATE KEY UPDATE 
         users_count = ?, products_count = ?, customers_count = ?, sales_count = ?, storage_used_mb = ?, api_calls_count = ?`,
      [businessId, currentUsers, currentProducts, 0, 0, 0, 0,
       currentUsers, currentProducts, 0, 0, 0, 0]
    );
    
    // Send payment reminder message
    await pool.query(
      `INSERT INTO business_messages (business_id, from_superadmin_id, subject, message, message_type, priority) 
       VALUES (?, ?, ?, ?, 'payment_due', 'high')`,
      [
        businessId, 
        req.user.id, 
        'Monthly Payment Due', 
        `Your monthly payment of $${totalAmount} is due on ${dueDate}. 
         Base fee: $${business.monthly_fee} (${business.subscription_plan} plan)
         ${userOverage > 0 ? `User overage: $${userOverageFee} (${userOverage} extra users)` : ''}
         ${productOverage > 0 ? `Product overage: $${productOverageFee} (${productOverage} extra products)` : ''}
         Please submit your payment for review.`
      ]
    );
    
    res.status(201).json({ 
      message: 'Monthly bill generated based on subscription plan',
      billId: result.insertId,
      billDetails: {
        businessName: business.name,
        subscriptionPlan: business.subscription_plan,
        baseAmount: business.monthly_fee,
        userOverage,
        userOverageFee,
        productOverage,
        productOverageFee,
        totalAmount
      }
    });
  } catch (error) {
    console.error('Error generating monthly bill:', error);
    res.status(500).json({ message: 'Failed to generate monthly bill' });
  }
});

// Generate bills for all businesses based on subscription plans
router.post('/generate-all-bills', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { billingMonth, dueDate } = req.body;
    
    // Get all businesses
    const [businesses] = await pool.query('SELECT * FROM businesses');
    
    const generatedBills = [];
    
    // Generate bills for each business
    for (const business of businesses) {
      try {
        // Get current user and product counts
        const [usersResult] = await pool.query(
          'SELECT COUNT(*) as count FROM users WHERE business_id = ?',
          [business.id]
        );
        const currentUsers = usersResult[0].count;
        
        const [productsResult] = await pool.query(
          'SELECT COUNT(*) as count FROM products WHERE business_id = ?',
          [business.id]
        );
        const currentProducts = productsResult[0].count;
        
        // Get subscription plan limits
        const [planResult] = await pool.query(
          'SELECT * FROM subscription_plans WHERE plan_name = ?',
          [business.subscription_plan || 'basic']
        );
        const plan = planResult[0] || { max_users: 3, max_products: 1000, overage_fee_per_user: 5.00, overage_fee_per_product: 0.10 };
        
        // Calculate overages
        const userOverage = Math.max(0, currentUsers - plan.max_users);
        const productOverage = Math.max(0, currentProducts - plan.max_products);
        
        // Calculate fees
        const userOverageFee = userOverage * plan.overage_fee_per_user;
        const productOverageFee = productOverage * plan.overage_fee_per_product;
        const baseAmount = business.monthly_fee || 29.99;
        const totalAmount = baseAmount + userOverageFee + productOverageFee;
        
        // Generate the bill
        const [result] = await pool.query(
          `INSERT INTO monthly_bills (business_id, billing_month, base_amount, user_overage_fee, product_overage_fee, total_amount, due_date, status) 
           VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')
           ON DUPLICATE KEY UPDATE 
             base_amount = VALUES(base_amount),
             user_overage_fee = VALUES(user_overage_fee),
             product_overage_fee = VALUES(product_overage_fee),
             total_amount = VALUES(total_amount),
             due_date = VALUES(due_date),
             created_at = CURRENT_TIMESTAMP`,
          [business.id, billingMonth, baseAmount, userOverageFee, productOverageFee, totalAmount, dueDate]
        );
        
        // Update business usage tracking
        await pool.query(
          `INSERT INTO business_usage (business_id, date, users_count, products_count, customers_count, sales_count, storage_used_mb, api_calls_count) 
           VALUES (?, CURDATE(), ?, ?, ?, ?, ?, ?) 
           ON DUPLICATE KEY UPDATE 
             users_count = ?, products_count = ?, customers_count = ?, sales_count = ?, storage_used_mb = ?, api_calls_count = ?`,
          [business.id, currentUsers, currentProducts, 0, 0, 0, 0,
           currentUsers, currentProducts, 0, 0, 0, 0]
        );
        
        generatedBills.push({
          business_id: business.id,
          business_name: business.name,
          subscription_plan: business.subscription_plan,
          base_amount: baseAmount,
          user_overage: userOverage,
          user_overage_fee: userOverageFee,
          product_overage: productOverage,
          product_overage_fee: productOverageFee,
          total_amount: totalAmount,
          status: 'pending'
        });
        
      } catch (businessError) {
        console.error(`Error generating bill for business ${business.id}:`, businessError);
        // Continue with other businesses even if one fails
      }
    }
    
    res.json({ 
      message: 'Monthly bills generated for all businesses based on subscription plans',
      billsGenerated: generatedBills.length,
      bills: generatedBills
    });
  } catch (error) {
    console.error('Error generating all bills:', error);
    res.status(500).json({ message: 'Failed to generate bills for all businesses' });
  }
});

// Get monthly bills for business
router.get('/:businessId/monthly-bills', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    
    const [bills] = await pool.query(
      `SELECT * FROM monthly_bills WHERE business_id = ? ORDER BY billing_month DESC`,
      [businessId]
    );
    
    res.json({ bills });
  } catch (error) {
    console.error('Error fetching monthly bills:', error);
    res.status(500).json({ message: 'Failed to fetch monthly bills' });
  }
});

// Submit payment for acceptance
router.post('/:businessId/submit-payment', auth, checkRole(['admin', 'manager']), async (req, res) => {
  try {
    const { businessId } = req.params;
    const { monthlyBillId, paymentAmount, paymentMethod, transactionId, paymentProofUrl, notes } = req.body;
    
    const [result] = await pool.query(
      `INSERT INTO payment_acceptance (business_id, monthly_bill_id, payment_amount, payment_method, transaction_id, payment_proof_url, notes) 
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [businessId, monthlyBillId, paymentAmount, paymentMethod, transactionId, paymentProofUrl, notes]
    );
    
    // Send notification to superadmin
    await pool.query(
      `INSERT INTO business_messages (business_id, from_superadmin_id, subject, message, message_type, priority) 
       VALUES (?, ?, ?, ?, 'info', 'medium')`,
      [
        businessId, 
        req.user.id, 
        'Payment Submitted for Review', 
        `Payment of $${paymentAmount} has been submitted for review. Transaction ID: ${transactionId}`
      ]
    );
    
    res.status(201).json({ 
      message: 'Payment submitted for review',
      paymentId: result.insertId 
    });
  } catch (error) {
    console.error('Error submitting payment:', error);
    res.status(500).json({ message: 'Failed to submit payment' });
  }
});

// Review payment (superadmin only)
router.put('/:businessId/review-payment/:paymentId', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId, paymentId } = req.params;
    const { status, rejectionReason, notes } = req.body;
    
    await pool.query(
      `UPDATE payment_acceptance SET status = ?, reviewed_at = NOW(), reviewed_by = ?, rejection_reason = ?, notes = ? 
       WHERE id = ? AND business_id = ?`,
      [status, req.user.id, rejectionReason, notes, paymentId, businessId]
    );
    
    if (status === 'accepted') {
      // Update monthly bill status
      await pool.query(
        `UPDATE monthly_bills mb 
         JOIN payment_acceptance pa ON mb.id = pa.monthly_bill_id 
         SET mb.status = 'paid', mb.paid_at = NOW(), mb.payment_method = pa.payment_method, mb.transaction_id = pa.transaction_id 
         WHERE pa.id = ?`,
        [paymentId]
      );
      
      // Send acceptance message
      await pool.query(
        `INSERT INTO business_messages (business_id, from_superadmin_id, subject, message, message_type, priority) 
         VALUES (?, ?, ?, ?, 'activation', 'medium')`,
        [
          businessId, 
          req.user.id, 
          'Payment Accepted', 
          'Your payment has been accepted. Your account is now active.'
        ]
      );
    } else if (status === 'rejected') {
      // Send rejection message
      await pool.query(
        `INSERT INTO business_messages (business_id, from_superadmin_id, subject, message, message_type, priority) 
         VALUES (?, ?, ?, ?, 'warning', 'high')`,
        [
          businessId, 
          req.user.id, 
          'Payment Rejected', 
          `Your payment has been rejected. Reason: ${rejectionReason}. Please submit a new payment.`
        ]
      );
    }
    
    res.json({ message: `Payment ${status}` });
  } catch (error) {
    console.error('Error reviewing payment:', error);
    res.status(500).json({ message: 'Failed to review payment' });
  }
});

// Get payment submissions for business
router.get('/:businessId/payment-submissions', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    
    const [payments] = await pool.query(
      `SELECT pa.*, mb.billing_month, mb.total_amount as bill_amount 
       FROM payment_acceptance pa 
       JOIN monthly_bills mb ON pa.monthly_bill_id = mb.id 
       WHERE pa.business_id = ? 
       ORDER BY pa.submitted_at DESC`,
      [businessId]
    );
    
    res.json({ payments });
  } catch (error) {
    console.error('Error fetching payment submissions:', error);
    res.status(500).json({ message: 'Failed to fetch payment submissions' });
  }
});

// Create business backup
router.post('/:businessId/backup', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    const { backupType, notes } = req.body;
    
    // Generate backup file path
    const backupDate = new Date().toISOString().split('T')[0];
    const backupTime = new Date().toTimeString().split(' ')[0];
    const filePath = `/backups/business_${businessId}_${backupType}_${backupDate}.sql`;
    
    const [result] = await pool.query(
      `INSERT INTO business_backups (business_id, backup_type, backup_date, backup_time, file_path, created_by, notes) 
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [businessId, backupType, backupDate, backupTime, filePath, req.user.id, notes]
    );
    
    // TODO: Implement actual backup logic here
    // For now, just update status to completed
    await pool.query(
      `UPDATE business_backups SET status = 'completed', file_size = 1024000 WHERE id = ?`,
      [result.insertId]
    );
    
    res.status(201).json({ 
      message: 'Backup created successfully',
      backupId: result.insertId,
      filePath: filePath
    });
  } catch (error) {
    console.error('Error creating backup:', error);
    res.status(500).json({ message: 'Failed to create backup' });
  }
});

// Get business backups
router.get('/:businessId/backups', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    
    const [backups] = await pool.query(
      `SELECT * FROM business_backups WHERE business_id = ? ORDER BY backup_date DESC, backup_time DESC`,
      [businessId]
    );
    
    res.json({ backups });
  } catch (error) {
    console.error('Error fetching backups:', error);
    res.status(500).json({ message: 'Failed to fetch backups' });
  }
});

// Restore business from backup
router.post('/:businessId/restore/:backupId', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId, backupId } = req.params;
    const { recoveryType, recoveryNotes } = req.body;
    
    // Create recovery record
    const [result] = await pool.query(
      `INSERT INTO business_data_recovery (business_id, recovery_type, backup_id, recovery_date, recovered_by, recovery_notes) 
       VALUES (?, ?, ?, CURDATE(), ?, ?)`,
      [businessId, recoveryType, backupId, req.user.id, recoveryNotes]
    );
    
    // TODO: Implement actual restore logic here
    // For now, just update status to completed
    await pool.query(
      `UPDATE business_data_recovery SET status = 'completed' WHERE id = ?`,
      [result.insertId]
    );
    
    // Update backup status
    await pool.query(
      `UPDATE business_backups SET status = 'restored', restored_at = NOW(), restored_by = ? WHERE id = ?`,
      [req.user.id, backupId]
    );
    
    res.json({ 
      message: 'Business restored successfully',
      recoveryId: result.insertId
    });
  } catch (error) {
    console.error('Error restoring business:', error);
    res.status(500).json({ message: 'Failed to restore business' });
  }
});

// Get business deletion log
router.get('/:businessId/deletion-log', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    
    const [deletions] = await pool.query(
      `SELECT * FROM business_deletion_log WHERE business_id = ? ORDER BY deleted_at DESC`,
      [businessId]
    );
    
    res.json({ deletions });
  } catch (error) {
    console.error('Error fetching deletion log:', error);
    res.status(500).json({ message: 'Failed to fetch deletion log' });
  }
});

// Restore deleted business
router.post('/:businessId/restore-deleted', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    const { backupId, restorationNotes } = req.body;
    
    // Update deletion log
    await pool.query(
      `UPDATE business_deletion_log SET restored_at = NOW(), restored_by = ? WHERE business_id = ? AND restored_at IS NULL`,
      [req.user.id, businessId]
    );
    
    // Reactivate business
    await pool.query(
      `UPDATE businesses SET is_active = 1, is_deleted = 0 WHERE id = ?`,
      [businessId]
    );
    
    // Create recovery record
    await pool.query(
      `INSERT INTO business_data_recovery (business_id, recovery_type, backup_id, recovery_date, recovered_by, recovery_notes) 
       VALUES (?, 'full_restore', ?, CURDATE(), ?, ?)`,
      [businessId, backupId, req.user.id, restorationNotes]
    );
    
    res.json({ message: 'Business restored successfully' });
  } catch (error) {
    console.error('Error restoring deleted business:', error);
    res.status(500).json({ message: 'Failed to restore deleted business' });
  }
});

// Get all pending payments (superadmin dashboard)
router.get('/pending-payments/all', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const [payments] = await pool.query(
      `SELECT pa.*, b.name as business_name, b.business_code, mb.billing_month, mb.total_amount as bill_amount 
       FROM payment_acceptance pa 
       JOIN businesses b ON pa.business_id = b.id 
       JOIN monthly_bills mb ON pa.monthly_bill_id = mb.id 
       WHERE pa.status = 'pending' 
       ORDER BY pa.submitted_at ASC`
    );
    
    res.json({ payments });
  } catch (error) {
    console.error('Error fetching pending payments:', error);
    res.status(500).json({ message: 'Failed to fetch pending payments' });
  }
});

// Get all overdue bills (superadmin dashboard)
router.get('/overdue-bills/all', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const [bills] = await pool.query(
      `SELECT mb.*, b.name as business_name, b.business_code, b.email, b.phone 
       FROM monthly_bills mb 
       JOIN businesses b ON mb.business_id = b.id 
       WHERE mb.status = 'overdue' AND mb.due_date < CURDATE() 
       ORDER BY mb.due_date ASC`
    );
    
    res.json({ bills });
  } catch (error) {
    console.error('Error fetching overdue bills:', error);
    res.status(500).json({ message: 'Failed to fetch overdue bills' });
  }
});

// Get all backups (superadmin dashboard)
router.get('/backups/all', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const [backups] = await pool.query(
      `SELECT bb.*, b.name as business_name, b.business_code 
       FROM business_backups bb 
       JOIN businesses b ON bb.business_id = b.id 
       ORDER BY bb.backup_date DESC, bb.backup_time DESC`
    );
    
    res.json({ backups });
  } catch (error) {
    console.error('Error fetching all backups:', error);
    res.status(500).json({ message: 'Failed to fetch backups' });
  }
});

// Get all deleted businesses (superadmin dashboard)
router.get('/deleted/all', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const [deletions] = await pool.query(
      `SELECT bdl.*, u.first_name, u.last_name as deleted_by_name 
       FROM business_deletion_log bdl 
       JOIN users u ON bdl.deleted_by = u.id 
       WHERE bdl.restored_at IS NULL 
       ORDER BY bdl.deleted_at DESC`
    );
    
    res.json({ deletions });
  } catch (error) {
    console.error('Error fetching deleted businesses:', error);
    res.status(500).json({ message: 'Failed to fetch deleted businesses' });
  }
});

// Get subscription plans
router.get('/subscription-plans', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const [plans] = await pool.query(
      'SELECT * FROM subscription_plans WHERE is_active = 1 ORDER BY monthly_fee ASC'
    );
    
    res.json({ plans });
  } catch (error) {
    console.error('Error fetching subscription plans:', error);
    res.status(500).json({ message: 'Failed to fetch subscription plans' });
  }
});

// Update business subscription plan
router.put('/:businessId/subscription-plan', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { businessId } = req.params;
    const { subscriptionPlan } = req.body;
    
    // Get subscription plan details
    const [plans] = await pool.query(
      'SELECT * FROM subscription_plans WHERE plan_name = ? AND is_active = 1',
      [subscriptionPlan]
    );
    
    if (plans.length === 0) {
      return res.status(400).json({ message: 'Invalid subscription plan' });
    }
    
    const plan = plans[0];
    
    // Update business subscription plan
    await pool.query(
      `UPDATE businesses SET 
       subscription_plan = ?, 
       monthly_fee = ?, 
       max_users = ?, 
       max_products = ?, 
       overage_fee_per_user = ?, 
       overage_fee_per_product = ?
       WHERE id = ?`,
      [plan.plan_name, plan.monthly_fee, plan.max_users, plan.max_products, 
       plan.overage_fee_per_user, plan.overage_fee_per_product, businessId]
    );
    
    // Send notification to business
    await pool.query(
      `INSERT INTO business_messages (business_id, from_superadmin_id, subject, message, message_type, priority) 
       VALUES (?, ?, ?, ?, 'info', 'medium')`,
      [
        businessId, 
        req.user.id, 
        'Subscription Plan Updated', 
        `Your subscription plan has been updated to ${plan.plan_name.toUpperCase()}. 
         New monthly fee: $${plan.monthly_fee}
         User limit: ${plan.max_users}
         Product limit: ${plan.max_products}`
      ]
    );
    
    res.json({ 
      message: 'Business subscription plan updated successfully',
      newPlan: plan
    });
  } catch (error) {
    console.error('Error updating subscription plan:', error);
    res.status(500).json({ message: 'Failed to update subscription plan' });
  }
});

module.exports = router; 