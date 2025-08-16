const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { auth, checkRole, adminOrSuperadminForCashier } = require('../middleware/auth');
const bcrypt = require('bcryptjs');
const fs = require('fs');
const path = require('path');

// Utility function to convert MySQL data types to proper JavaScript types
const convertMySQLTypes = (data) => {
  if (Array.isArray(data)) {
    return data.map(item => convertMySQLTypes(item));
  }
  
  if (data && typeof data === 'object') {
    const converted = {};
    for (const [key, value] of Object.entries(data)) {
      if (key === 'is_active' || key === 'is_read') {
        converted[key] = Boolean(value);
      } else if (key === 'last_login' || key === 'read_at' || key === 'created_at' || key === 'updated_at') {
        converted[key] = value || null;
      } else if (typeof value === 'number' && Number.isInteger(value)) {
        converted[key] = value;
      } else {
        converted[key] = value;
      }
    }
    return converted;
  }
  
  return data;
};

// Middleware to ensure superadmin access
const superadminOnly = checkRole(['superadmin']);

// Get comprehensive business details for superadmin
router.get('/businesses/:businessId/details', auth, superadminOnly, async (req, res) => {
  try {
    const { businessId } = req.params;
    
    // Get business information
    const [businessData] = await pool.query(
      `SELECT b.*, 
              COUNT(DISTINCT u.id) as total_users,
              COUNT(DISTINCT p.id) as total_products,
              COUNT(DISTINCT c.id) as total_customers,
              COUNT(DISTINCT s.id) as total_sales,
              COALESCE(SUM(s.total_amount), 0) as total_revenue
       FROM businesses b
       LEFT JOIN users u ON b.id = u.business_id
       LEFT JOIN products p ON b.id = p.business_id
       LEFT JOIN customers c ON b.id = c.business_id
       LEFT JOIN sales s ON b.id = s.business_id
       WHERE b.id = ?
       GROUP BY b.id`,
      [businessId]
    );

    if (businessData.length === 0) {
      return res.status(404).json({ message: 'Business not found' });
    }

    const business = businessData[0];

    // Get users data
    const [users] = await pool.query(
      `SELECT id, username, email, role, last_login, is_active
       FROM users 
       WHERE business_id = ?
       ORDER BY last_login DESC`,
      [businessId]
    );

    const activeUsers = users.filter(user => user.is_active).length;

    // Get products data
    const [products] = await pool.query(
      `SELECT id, name, sku, stock_quantity, cost_price, price, low_stock_threshold
       FROM products 
       WHERE business_id = ?
       ORDER BY stock_quantity ASC`,
      [businessId]
    );

    const lowStockProducts = products.filter(p => p.stock_quantity <= p.low_stock_threshold).length;
    const outOfStockProducts = products.filter(p => p.stock_quantity === 0).length;
    const totalStockValue = products.reduce((sum, p) => sum + (p.stock_quantity * p.cost_price), 0);

    // Get sales data
    const [sales] = await pool.query(
      `SELECT s.id, c.name as customer_name, s.total_amount, s.created_at
       FROM sales s
       LEFT JOIN customers c ON s.customer_id = c.id
       WHERE s.business_id = ?
       ORDER BY s.created_at DESC
       LIMIT 10`,
      [businessId]
    );

    const [salesStats] = await pool.query(
      `SELECT COUNT(*) as total_sales,
              COALESCE(SUM(total_amount), 0) as total_revenue,
              COALESCE(AVG(total_amount), 0) as avg_sale_value
       FROM sales 
       WHERE business_id = ?`,
      [businessId]
    );

    // Get monthly sales data
    const [monthlySales] = await pool.query(
      `SELECT DATE_FORMAT(created_at, '%Y-%m') as month,
              COUNT(*) as sales_count,
              COALESCE(SUM(total_amount), 0) as revenue
       FROM sales 
       WHERE business_id = ?
       GROUP BY DATE_FORMAT(created_at, '%Y-%m')
       ORDER BY month DESC
       LIMIT 6`,
      [businessId]
    );

    // Get payments data
    const [payments] = await pool.query(
      `SELECT id, amount, status, created_at, description
       FROM business_payments 
       WHERE business_id = ?
       ORDER BY created_at DESC
       LIMIT 10`,
      [businessId]
    );

    const [paymentStats] = await pool.query(
      `SELECT COALESCE(SUM(CASE WHEN status = 'paid' THEN amount ELSE 0 END), 0) as total_paid,
              COALESCE(SUM(CASE WHEN status = 'pending' OR status = 'overdue' THEN amount ELSE 0 END), 0) as outstanding_balance
       FROM business_payments 
       WHERE business_id = ?`,
      [businessId]
    );

    // Get customers data
    const [customers] = await pool.query(
      `SELECT id, name, email, phone, address, loyalty_points, created_at
       FROM customers 
       WHERE business_id = ?
       ORDER BY created_at DESC
       LIMIT 10`,
      [businessId]
    );

    const [customerStats] = await pool.query(
      `SELECT COUNT(*) as total_customers,
              COUNT(CASE WHEN loyalty_points > 0 THEN 1 END) as loyal_customers
       FROM customers 
       WHERE business_id = ?`,
      [businessId]
    );

    // Get activity data
    const [activity] = await pool.query(
      `SELECT sl.*, u.username
       FROM system_logs sl
       LEFT JOIN users u ON sl.user_id = u.id
       WHERE sl.business_id = ?
       ORDER BY sl.created_at DESC
       LIMIT 20`,
      [businessId]
    );

    const [activityStats] = await pool.query(
      `SELECT COUNT(*) as total_actions,
              COUNT(CASE WHEN DATE(created_at) = CURDATE() THEN 1 END) as actions_today,
              COUNT(CASE WHEN created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 1 END) as actions_this_week
       FROM system_logs 
       WHERE business_id = ?`,
      [businessId]
    );

    // Add debugging information
    console.log(`Fetching details for business ID: ${businessId}`);
    console.log(`Found ${users.length} users for this business`);
    console.log(`Found ${products.length} products for this business`);
    console.log(`Found ${customers.length} customers for this business`);
    console.log(`Found ${sales.length} sales for this business`);
    console.log(`Found ${payments.length} payments for this business`);
    console.log(`Found ${activity.length} activity logs for this business`);

    res.json({
      business: {
        id: business.id,
        name: business.name,
        email: business.email,
        phone: business.phone,
        address: business.address,
        subscription_plan: business.subscription_plan,
        monthly_fee: business.monthly_fee,
        payment_status: business.payment_status,
        is_active: business.is_active,
        created_at: business.created_at,
        last_login: business.last_login,
      },
      users: {
        total_users: business.total_users,
        active_users: activeUsers,
        user_list: users.map(user => ({
          id: user.id,
          name: user.username,
          email: user.email,
          role: user.role,
          last_login: user.last_login,
        })),
      },
      products: {
        total_products: business.total_products,
        low_stock_products: lowStockProducts,
        out_of_stock_products: outOfStockProducts,
        total_stock_value: totalStockValue,
        product_list: products.map(product => ({
          id: product.id,
          name: product.name,
          sku: product.sku,
          stock_quantity: product.stock_quantity,
          cost_price: product.cost_price,
          price: product.price,
        })),
      },
      customers: {
        total_customers: customerStats[0].total_customers,
        loyal_customers: customerStats[0].loyal_customers,
        customer_list: customers.map(customer => ({
          id: customer.id,
          name: customer.name,
          email: customer.email,
          phone: customer.phone,
          loyalty_points: customer.loyalty_points,
          created_at: customer.created_at,
        })),
      },
      sales: {
        total_sales: salesStats[0].total_sales,
        total_revenue: salesStats[0].total_revenue,
        avg_sale_value: salesStats[0].avg_sale_value,
        sales_by_month: monthlySales,
        recent_sales: sales.map(sale => ({
          id: sale.id,
          customer: sale.customer_name,
          amount: sale.total_amount,
          date: sale.created_at,
        })),
      },
      payments: {
        total_paid: paymentStats[0].total_paid,
        outstanding_balance: paymentStats[0].outstanding_balance,
        payment_history: payments.map(payment => ({
          id: payment.id,
          amount: payment.amount,
          status: payment.status,
          date: payment.created_at,
        })),
      },
      activity: {
        total_actions: activityStats[0].total_actions,
        actions_today: activityStats[0].actions_today,
        actions_this_week: activityStats[0].actions_this_week,
        recent_activity: activity.map(act => ({
          action: act.action,
          user: act.username,
          timestamp: act.created_at,
        })),
      },
    });
  } catch (error) {
    console.error('Error fetching business details:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Test endpoint to verify business data isolation
router.get('/test-business-isolation', auth, superadminOnly, async (req, res) => {
  try {
    console.log('Testing business data isolation...');
    
    // Get all businesses with their data counts
    const [businesses] = await pool.query(
      `SELECT 
        b.id,
        b.name,
        b.subscription_plan,
        COUNT(DISTINCT u.id) as user_count,
        COUNT(DISTINCT p.id) as product_count,
        COUNT(DISTINCT s.id) as sale_count,
        COUNT(DISTINCT c.id) as customer_count,
        COUNT(DISTINCT bp.id) as payment_count,
        COUNT(DISTINCT sl.id) as activity_count,
        COALESCE(SUM(s.total_amount), 0) as total_revenue
       FROM businesses b
       LEFT JOIN users u ON b.id = u.business_id AND u.role != 'superadmin'
       LEFT JOIN products p ON b.id = p.business_id
       LEFT JOIN sales s ON b.id = s.business_id
       LEFT JOIN customers c ON b.id = c.business_id
       LEFT JOIN business_payments bp ON b.id = bp.business_id
       LEFT JOIN system_logs sl ON b.id = sl.business_id
       GROUP BY b.id, b.name, b.subscription_plan
       ORDER BY b.id`
    );

    // Check for any cross-business data contamination
    const [orphanedUsers] = await pool.query(
      'SELECT COUNT(*) as count FROM users WHERE business_id IS NULL AND role != "superadmin"'
    );

    const [orphanedProducts] = await pool.query(
      'SELECT COUNT(*) as count FROM products WHERE business_id IS NULL'
    );

    const [orphanedSales] = await pool.query(
      'SELECT COUNT(*) as count FROM sales WHERE business_id IS NULL'
    );

    const [orphanedCustomers] = await pool.query(
      'SELECT COUNT(*) as count FROM customers WHERE business_id IS NULL'
    );

    res.json({
      message: 'Business data isolation test completed',
      businesses: businesses,
      data_integrity: {
        orphaned_users: orphanedUsers[0].count,
        orphaned_products: orphanedProducts[0].count,
        orphaned_sales: orphanedSales[0].count,
        orphaned_customers: orphanedCustomers[0].count,
      },
      isolation_status: {
        users_isolated: orphanedUsers[0].count === 0,
        products_isolated: orphanedProducts[0].count === 0,
        sales_isolated: orphanedSales[0].count === 0,
        customers_isolated: orphanedCustomers[0].count === 0,
      }
    });
  } catch (error) {
    console.error('Error testing business isolation:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get system overview dashboard
router.get('/dashboard', auth, superadminOnly, async (req, res) => {
  try {
    // Get current date statistics
    const today = new Date().toISOString().split('T')[0];
    
    // Today's sales
    const [todaySales] = await pool.query(
      'SELECT COUNT(*) as count, COALESCE(SUM(total_amount), 0) as total FROM sales WHERE DATE(created_at) = ?',
      [today]
    );

    // Total users
    const [userCount] = await pool.query('SELECT COUNT(*) as count FROM users');
    
    // Total products
    const [productCount] = await pool.query('SELECT COUNT(*) as count FROM products');
    
    // Total customers
    const [customerCount] = await pool.query('SELECT COUNT(*) as count FROM customers');
    
    // Low stock products
    const [lowStockProducts] = await pool.query(
      'SELECT COUNT(*) as count FROM products WHERE stock_quantity <= low_stock_threshold'
    );

    // Recent system logs
    const [recentLogs] = await pool.query(
      `SELECT sl.*, u.username 
       FROM system_logs sl 
       LEFT JOIN users u ON sl.user_id = u.id 
       ORDER BY sl.created_at DESC 
       LIMIT 10`
    );

    // User activity (last 7 days)
    const [userActivity] = await pool.query(
      `SELECT DATE(last_login) as date, COUNT(*) as count 
       FROM users 
       WHERE last_login >= DATE_SUB(NOW(), INTERVAL 7 DAY)
       GROUP BY DATE(last_login) 
       ORDER BY date DESC`
    );

    res.json({
      // New top-level summary fields for frontend
      totalSales: todaySales[0].total,
      totalOrders: todaySales[0].count,
      totalUsers: userCount[0].count,
      totalProducts: productCount[0].count,
      totalCustomers: customerCount[0].count,
      lowStockCount: lowStockProducts[0].count,
      // Original fields for backward compatibility
      todaySales: todaySales[0],
      userCount: userCount[0].count,
      productCount: productCount[0].count,
      customerCount: customerCount[0].count,
      lowStockProducts: lowStockProducts[0].count,
      recentLogs,
      userActivity
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get all users with pagination
router.get('/users', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const offset = parseInt(req.query.offset) || 0;
    
    let query = 'SELECT id, username, email, role, is_active, last_login, created_at, is_deleted, business_id FROM users WHERE is_deleted = 0';
    let params = [];
    
    // If user is not superadmin, filter by their business_id
    if (req.user.role !== 'superadmin' && req.user.business_id) {
      query += ' AND business_id = ?';
      params.push(req.user.business_id);
    }
    
    query += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
    params.push(limit, offset);
    
    const [users] = await pool.query(query, params);

    // Convert MySQL data types to proper JavaScript types
    const processedUsers = convertMySQLTypes(users);

    res.json({ users: processedUsers });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Update user status (activate/deactivate)
router.put('/users/:id/status', auth, adminOrSuperadminForCashier, async (req, res) => {
  try {
    const { id } = req.params;
    const { is_active } = req.body;
    console.log('PUT /users/:id/status called', { id, is_active, user: req.user });
    
    // Verify the target user belongs to the same business (for non-superadmin users)
    if (req.user.role !== 'superadmin') {
      const [targetUser] = await pool.query(
        'SELECT id, role FROM users WHERE id = ? AND business_id = ?',
        [id, req.user.business_id]
      );
      
      if (targetUser.length === 0) {
        console.log('User not found for status update:', id);
        return res.status(404).json({ message: 'User not found' });
      }
      
      // Only allow updating cashier status for non-superadmin users
      if (targetUser[0].role !== 'cashier') {
        return res.status(403).json({ message: 'You can only update cashier status' });
      }
    }
    
    const [result] = await pool.query(
      'UPDATE users SET is_active = ? WHERE id = ?',
      [is_active, id]
    );
    console.log('UPDATE result:', result);
    if (result.affectedRows === 0) {
      console.log('User not found for deactivation:', id);
      return res.status(404).json({ message: 'User not found' });
    }
    // Log the action
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'UPDATE_USER_STATUS', 'users', id, JSON.stringify({ is_active })]
    );
    res.json({ message: 'User status updated successfully' });
  } catch (error) {
    console.error('Error in PUT /users/:id/status:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get system logs with pagination
router.get('/logs', auth, superadminOnly, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const action = req.query.action || '';
    const table = req.query.table || '';

    let query = `
      SELECT sl.*, u.username 
      FROM system_logs sl 
      LEFT JOIN users u ON sl.user_id = u.id
    `;
    let countQuery = 'SELECT COUNT(*) as total FROM system_logs sl';
    let whereClause = '';
    let params = [];
    let countParams = [];

    if (action || table) {
      whereClause = ' WHERE';
      if (action) {
        whereClause += ' sl.action = ?';
        params.push(action);
        countParams.push(action);
      }
      if (table) {
        if (action) whereClause += ' AND';
        whereClause += ' sl.table_name = ?';
        params.push(table);
        countParams.push(table);
      }
    }

    query += whereClause + ' ORDER BY sl.created_at DESC LIMIT ? OFFSET ?';
    countQuery += whereClause;
    params.push(limit, offset);

    const [logs] = await pool.query(query, params);
    const [totalResult] = await pool.query(countQuery, countParams);

    res.json({
      logs,
      pagination: {
        page,
        limit,
        total: totalResult[0].total,
        pages: Math.ceil(totalResult[0].total / limit)
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get system settings
router.get('/settings', auth, superadminOnly, async (req, res) => {
  try {
    const [settings] = await pool.query('SELECT * FROM system_settings ORDER BY setting_key');
    res.json(settings);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Update system settings
router.put('/settings/:key', auth, superadminOnly, async (req, res) => {
  try {
    const { key } = req.params;
    const { value, description } = req.body;

    // Validate required settings
    if (key === 'maintenance_mode' && !['true', 'false'].includes(value)) {
      return res.status(400).json({ message: 'Maintenance mode must be true or false' });
    }

    if (key === 'session_timeout' && (isNaN(value) || parseInt(value) < 300)) {
      return res.status(400).json({ message: 'Session timeout must be at least 300 seconds' });
    }

    if (key === 'max_login_attempts' && (isNaN(value) || parseInt(value) < 1 || parseInt(value) > 10)) {
      return res.status(400).json({ message: 'Max login attempts must be between 1 and 10' });
    }

    const [result] = await pool.query(
      'UPDATE system_settings SET setting_value = ?, description = ? WHERE setting_key = ?',
      [value, description, key]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'Setting not found' });
    }

    // Log the action
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'UPDATE_SETTING', 'system_settings', null, JSON.stringify({ key, value })]
    );

    res.json({ message: 'Setting updated successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Toggle maintenance mode
router.post('/settings/maintenance/toggle', auth, superadminOnly, async (req, res) => {
  try {
    // Get current maintenance mode
    const [current] = await pool.query(
      'SELECT setting_value FROM system_settings WHERE setting_key = ?',
      ['maintenance_mode']
    );

    const newValue = current[0]?.setting_value === 'true' ? 'false' : 'true';

    await pool.query(
      'UPDATE system_settings SET setting_value = ? WHERE setting_key = ?',
      [newValue, 'maintenance_mode']
    );

    // Log the action
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'TOGGLE_MAINTENANCE', 'system_settings', null, JSON.stringify({ maintenance_mode: newValue })]
    );

    res.json({ 
      message: `Maintenance mode ${newValue === 'true' ? 'enabled' : 'disabled'}`,
      maintenance_mode: newValue === 'true'
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Update admin code
router.post('/settings/admin-code/update', auth, superadminOnly, async (req, res) => {
  try {
    const { currentCode, newCode } = req.body;

    if (!currentCode || !newCode) {
      return res.status(400).json({ message: 'Current and new admin codes are required' });
    }

    if (newCode.length < 8) {
      return res.status(400).json({ message: 'Admin code must be at least 8 characters' });
    }

    // Verify current admin code (you might want to store this in settings)
    const currentAdminCode = process.env.ADMIN_CODE || 'SUPERADMIN2024';
    if (currentCode !== currentAdminCode) {
      return res.status(403).json({ message: 'Invalid current admin code' });
    }

    // Update environment variable (in production, you'd want to persist this)
    process.env.ADMIN_CODE = newCode;

    // Log the action
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'UPDATE_ADMIN_CODE', 'system_settings', null, JSON.stringify({ admin_code_updated: true })]
    );

    res.json({ message: 'Admin code updated successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get system configuration summary
router.get('/settings/config', auth, superadminOnly, async (req, res) => {
  try {
    const [settings] = await pool.query('SELECT * FROM system_settings ORDER BY setting_key');
    
    // Get system stats
    const [userCount] = await pool.query('SELECT COUNT(*) as count FROM users');
    const [productCount] = await pool.query('SELECT COUNT(*) as count FROM products');
    const [saleCount] = await pool.query('SELECT COUNT(*) as count FROM sales');
    
    const config = {
      settings: settings,
      stats: {
        totalUsers: userCount[0].count,
        totalProducts: productCount[0].count,
        totalSales: saleCount[0].count,
        maintenanceMode: settings.find(s => s.setting_key === 'maintenance_mode')?.setting_value === 'true',
        appVersion: settings.find(s => s.setting_key === 'app_version')?.setting_value,
        sessionTimeout: settings.find(s => s.setting_key === 'session_timeout')?.setting_value,
        maxLoginAttempts: settings.find(s => s.setting_key === 'max_login_attempts')?.setting_value,
      }
    };

    res.json(config);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get app statistics
router.get('/statistics', auth, superadminOnly, async (req, res) => {
  try {
    const days = parseInt(req.query.days) || 30;
    
    // Sales statistics
    const [salesStats] = await pool.query(
      `SELECT 
        DATE(created_at) as date,
        COUNT(*) as orders,
        SUM(total_amount) as revenue
       FROM sales 
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
       GROUP BY DATE(created_at)
       ORDER BY date DESC`,
      [days]
    );

    // User registration statistics
    const [userStats] = await pool.query(
      `SELECT 
        DATE(created_at) as date,
        COUNT(*) as registrations
       FROM users 
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
       GROUP BY DATE(created_at)
       ORDER BY date DESC`,
      [days]
    );

    // Product statistics
    const [productStats] = await pool.query(
      `SELECT 
        COUNT(*) as total_products,
        SUM(stock_quantity) as total_stock,
        COUNT(CASE WHEN stock_quantity <= low_stock_threshold THEN 1 END) as low_stock_count
       FROM products`
    );

    res.json({
      salesStats,
      userStats,
      productStats: productStats[0]
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Enhanced system health check with detailed metrics
router.get('/health', auth, superadminOnly, async (req, res) => {
  try {
    const health = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      version: process.version,
      database: 'healthy',
      databaseConnection: null,
      systemLoad: null,
      diskUsage: null,
      activeConnections: 0,
      errors: []
    };

    // Test database connection and get metrics
    try {
      const startTime = Date.now();
      await pool.query('SELECT 1');
      const dbResponseTime = Date.now() - startTime;
      
      // Get database metrics
      const [dbStats] = await pool.query(`
        SELECT 
          COUNT(*) as total_connections,
          SUM(CASE WHEN Command = 'Sleep' THEN 1 ELSE 0 END) as idle_connections,
          SUM(CASE WHEN Command != 'Sleep' THEN 1 ELSE 0 END) as active_connections
        FROM information_schema.PROCESSLIST
      `);
      
      health.databaseConnection = {
        responseTime: dbResponseTime,
        totalConnections: dbStats[0]?.total_connections || 0,
        idleConnections: dbStats[0]?.idle_connections || 0,
        activeConnections: dbStats[0]?.active_connections || 0
      };
      
      health.activeConnections = dbStats[0]?.active_connections || 0;
    } catch (dbError) {
      health.database = 'unhealthy';
      health.errors.push(`Database error: ${dbError.message}`);
    }

    // Get system load (simulated for Windows)
    try {
      const os = require('os');
      health.systemLoad = {
        cpuUsage: os.loadavg(),
        totalMemory: os.totalmem(),
        freeMemory: os.freemem(),
        memoryUsage: ((os.totalmem() - os.freemem()) / os.totalmem() * 100).toFixed(2),
        platform: os.platform(),
        arch: os.arch()
      };
    } catch (loadError) {
      health.errors.push(`System load error: ${loadError.message}`);
    }

    // Get recent system errors
    try {
      const [errors] = await pool.query(`
        SELECT * FROM system_logs 
        WHERE action LIKE '%ERROR%' OR action LIKE '%FAIL%'
        ORDER BY created_at DESC 
        LIMIT 10
      `);
      health.recentErrors = errors;
    } catch (error) {
      health.errors.push(`Error fetching logs: ${error.message}`);
    }

    res.json(health);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Database backup
router.post('/backup', auth, superadminOnly, async (req, res) => {
  try {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupDir = path.join(__dirname, '../../backups');
    
    // Create backup directory if it doesn't exist
    if (!fs.existsSync(backupDir)) {
      fs.mkdirSync(backupDir, { recursive: true });
    }
    
    const backupFile = path.join(backupDir, `backup-${timestamp}.sql`);
    
    // In a real implementation, you would use mysqldump or similar
    // For now, we'll create a simple backup by exporting data
    const tables = ['users', 'products', 'categories', 'customers', 'sales', 'sale_items', 'inventory_transactions', 'system_logs', 'app_statistics', 'system_settings'];
    let backupContent = '';
    
    for (const table of tables) {
      try {
        const [data] = await pool.query(`SELECT * FROM ${table}`);
        backupContent += `-- Table: ${table}\n`;
        backupContent += `-- Data count: ${data.length}\n\n`;
        
        if (data.length > 0) {
          backupContent += `INSERT INTO ${table} VALUES\n`;
          const values = data.map(row => {
            const rowValues = Object.values(row).map(value => {
              if (value === null) return 'NULL';
              if (typeof value === 'string') return `'${value.replace(/'/g, "''")}'`;
              return value;
            });
            return `(${rowValues.join(', ')})`;
          });
          backupContent += values.join(',\n') + ';\n\n';
        }
      } catch (error) {
        console.error(`Error backing up table ${table}:`, error);
      }
    }
    
    fs.writeFileSync(backupFile, backupContent);
    
    // Log the backup action
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'DATABASE_BACKUP', 'system', null, JSON.stringify({ backupFile, timestamp })]
    );
    
    res.json({ 
      message: 'Database backup created successfully',
      backupFile: path.basename(backupFile),
      timestamp,
      size: fs.statSync(backupFile).size
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// List available backups
router.get('/backups', auth, superadminOnly, async (req, res) => {
  try {
    const backupDir = path.join(__dirname, '../../backups');
    
    if (!fs.existsSync(backupDir)) {
      return res.json({ backups: [] });
    }
    
    const files = fs.readdirSync(backupDir)
      .filter(file => file.endsWith('.sql'))
      .map(file => {
        const filePath = path.join(backupDir, file);
        const stats = fs.statSync(filePath);
        return {
          filename: file,
          size: stats.size,
          created: stats.birthtime,
          modified: stats.mtime
        };
      })
      .sort((a, b) => b.modified.compareTo(a.modified));
    
    res.json({ backups: files });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Download backup file
router.get('/backups/:filename', auth, superadminOnly, async (req, res) => {
  try {
    const { filename } = req.params;
    const backupDir = path.join(__dirname, '../../backups');
    const filePath = path.join(backupDir, filename);
    
    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ message: 'Backup file not found' });
    }
    
    res.download(filePath);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Export data to CSV
router.get('/export/:table', auth, superadminOnly, async (req, res) => {
  try {
    const { table } = req.params;
    const allowedTables = ['users', 'products', 'categories', 'customers', 'sales', 'sale_items', 'inventory_transactions'];
    
    if (!allowedTables.includes(table)) {
      return res.status(400).json({ message: 'Invalid table name' });
    }
    
    const [data] = await pool.query(`SELECT * FROM ${table}`);
    
    if (data.length === 0) {
      return res.status(404).json({ message: 'No data found' });
    }
    
    // Convert to CSV
    const headers = Object.keys(data[0]);
    let csv = headers.join(',') + '\n';
    
    for (const row of data) {
      const values = headers.map(header => {
        const value = row[header];
        if (value === null) return '';
        if (typeof value === 'string') return `"${value.replace(/"/g, '""')}"`;
        return value;
      });
      csv += values.join(',') + '\n';
    }
    
    // Log the export action
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'EXPORT_DATA', table, null, JSON.stringify({ recordCount: data.length })]
    );
    
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="${table}-${new Date().toISOString().split('T')[0]}.csv"`);
    res.send(csv);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get exportable tables
router.get('/export', auth, superadminOnly, async (req, res) => {
  try {
    const tables = [
      { name: 'users', description: 'User accounts and roles' },
      { name: 'products', description: 'Product catalog and inventory' },
      { name: 'categories', description: 'Product categories' },
      { name: 'customers', description: 'Customer information' },
      { name: 'sales', description: 'Sales transactions' },
      { name: 'sale_items', description: 'Individual sale items' },
      { name: 'inventory_transactions', description: 'Inventory movements' }
    ];
    
    // Get record counts for each table
    const tablesWithCounts = await Promise.all(
      tables.map(async (table) => {
        try {
          const [result] = await pool.query(`SELECT COUNT(*) as count FROM ${table.name}`);
          return {
            ...table,
            recordCount: result[0].count
          };
        } catch (error) {
          return {
            ...table,
            recordCount: 0
          };
        }
      })
    );
    
    res.json({ tables: tablesWithCounts });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Create a new user
router.post('/users', auth, adminOrSuperadminForCashier, async (req, res) => {
  try {
    const { username, email, password, role } = req.body;
    
    // Validate required fields
    if (!username || !email || !password || !role) {
      return res.status(400).json({ 
        message: 'All fields are required',
        missing: {
          username: !username,
          email: !email,
          password: !password,
          role: !role
        }
      });
    }
    
    // Validate username format (alphanumeric and underscore only, 3-20 characters)
    const usernameRegex = /^[a-zA-Z0-9_]{3,20}$/;
    if (!usernameRegex.test(username)) {
      return res.status(400).json({ 
        message: 'Username must be 3-20 characters long and contain only letters, numbers, and underscores' 
      });
    }
    
    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ message: 'Invalid email format' });
    }
    
    // Validate password strength (minimum 6 characters)
    if (password.length < 6) {
      return res.status(400).json({ message: 'Password must be at least 6 characters long' });
    }
    
    // Only allow creating cashiers for non-superadmin users
    if (req.user.role !== 'superadmin' && role !== 'cashier') {
      return res.status(403).json({ message: 'You can only create cashier accounts' });
    }
    
    // Check if username already exists
    const [existingUsername] = await pool.query('SELECT id, username FROM users WHERE username = ? AND is_deleted = 0', [username]);
    if (existingUsername.length > 0) {
      return res.status(400).json({ 
        message: 'Username already exists',
        field: 'username',
        existingUser: existingUsername[0].username
      });
    }
    
    // Check if email already exists
    const [existingEmail] = await pool.query('SELECT id, email FROM users WHERE email = ? AND is_deleted = 0', [email]);
    if (existingEmail.length > 0) {
      return res.status(400).json({ 
        message: 'Email already exists',
        field: 'email',
        existingUser: existingEmail[0].email
      });
    }
    
    const hashedPassword = await bcrypt.hash(password, 10);
    const businessId = req.user.role === 'superadmin' ? null : req.user.business_id;
    
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

// Update user (username, email, role, is_active)
router.put('/users/:id', auth, adminOrSuperadminForCashier, async (req, res) => {
  try {
    const { id } = req.params;
    const { username, email, role, is_active } = req.body;
    
    // Verify the target user belongs to the same business (for non-superadmin users)
    if (req.user.role !== 'superadmin') {
      const [targetUser] = await pool.query(
        'SELECT id, role FROM users WHERE id = ? AND business_id = ?',
        [id, req.user.business_id]
      );
      
      if (targetUser.length === 0) {
        return res.status(404).json({ message: 'User not found' });
      }
      
      // Only allow updating cashiers for non-superadmin users
      if (targetUser[0].role !== 'cashier') {
        return res.status(403).json({ message: 'You can only update cashier accounts' });
      }
    }
    
    const [result] = await pool.query(
      'UPDATE users SET username = ?, email = ?, role = ?, is_active = ? WHERE id = ?',
      [username, email, role, is_active, id]
    );
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'UPDATE_USER', 'users', id, JSON.stringify({ username, email, role, is_active })]
    );
    
    res.json({ message: 'User updated' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Delete user
router.delete('/users/:id', auth, adminOrSuperadminForCashier, async (req, res) => {
  try {
    const { id } = req.params;
    
    // Verify the target user belongs to the same business (for non-superadmin users)
    if (req.user.role !== 'superadmin') {
      const [targetUser] = await pool.query(
        'SELECT id, role FROM users WHERE id = ? AND business_id = ?',
        [id, req.user.business_id]
      );
      
      if (targetUser.length === 0) {
        return res.status(404).json({ message: 'User not found' });
      }
      
      // Only allow deleting cashiers for non-superadmin users
      if (targetUser[0].role !== 'cashier') {
        return res.status(403).json({ message: 'You can only delete cashier accounts' });
      }
    }
    
    const [result] = await pool.query('UPDATE users SET is_deleted = 1 WHERE id = ?', [id]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id) VALUES (?, ?, ?, ?)',
      [req.user.id, 'DELETE_USER', 'users', id]
    );
    res.json({ message: 'User deleted' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Reset user password
router.post('/users/:id/reset-password', auth, adminOrSuperadminForCashier, async (req, res) => {
  try {
    const { id } = req.params;
    const { newPassword } = req.body;
    if (!newPassword) {
      return res.status(400).json({ message: 'New password is required' });
    }
    
    // Verify the target user belongs to the same business (for non-superadmin users)
    if (req.user.role !== 'superadmin') {
      const [targetUser] = await pool.query(
        'SELECT id, role FROM users WHERE id = ? AND business_id = ?',
        [id, req.user.business_id]
      );
      
      if (targetUser.length === 0) {
        return res.status(404).json({ message: 'User not found' });
      }
      
      // Only allow resetting cashier passwords for non-superadmin users
      if (targetUser[0].role !== 'cashier') {
        return res.status(403).json({ message: 'You can only reset cashier passwords' });
      }
    }
    
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    const [result] = await pool.query('UPDATE users SET password = ? WHERE id = ?', [hashedPassword, id]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'RESET_PASSWORD', 'users', id, JSON.stringify({ newPassword: '***' })]
    );
    res.json({ message: 'Password reset successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Force logout user (invalidate token - simulated)
router.post('/users/:id/force-logout', auth, superadminOnly, async (req, res) => {
  try {
    // In a real app, you would manage a token blacklist or session store
    // Here, just log the action
    const { id } = req.params;
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id) VALUES (?, ?, ?, ?)',
      [req.user.id, 'FORCE_LOGOUT', 'users', id]
    );
    res.json({ message: 'User force-logged out (simulated)' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get user activity logs
router.get('/users/:id/logs', auth, superadminOnly, async (req, res) => {
  try {
    const { id } = req.params;
    const [logs] = await pool.query(
      'SELECT * FROM system_logs WHERE record_id = ? AND table_name = ? ORDER BY created_at DESC',
      [id, 'users']
    );
    res.json({ logs });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get active sessions (users currently logged in)
router.get('/sessions', auth, superadminOnly, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    // Get users with recent activity (last 30 minutes)
    const [sessions] = await pool.query(`
      SELECT 
        u.id,
        u.username,
        u.email,
        u.role,
        u.last_login,
        u.is_active,
        COUNT(sl.id) as recent_actions
      FROM users u
      LEFT JOIN system_logs sl ON u.id = sl.user_id 
        AND sl.created_at >= DATE_SUB(NOW(), INTERVAL 30 MINUTE)
      WHERE u.last_login >= DATE_SUB(NOW(), INTERVAL 30 MINUTE)
      GROUP BY u.id
      ORDER BY u.last_login DESC
      LIMIT ? OFFSET ?
    `, [limit, offset]);

    // Get total count
    const [totalResult] = await pool.query(`
      SELECT COUNT(*) as total 
      FROM users 
      WHERE last_login >= DATE_SUB(NOW(), INTERVAL 30 MINUTE)
    `);

    // Convert MySQL data types to proper JavaScript types
    const processedSessions = convertMySQLTypes(sessions);

    res.json({
      sessions: processedSessions,
      pagination: {
        page,
        limit,
        total: totalResult[0].total,
        pages: Math.ceil(totalResult[0].total / limit)
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get system errors and exceptions
router.get('/errors', auth, superadminOnly, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const severity = req.query.severity || '';

    let query = `
      SELECT 
        sl.*,
        u.username
      FROM system_logs sl
      LEFT JOIN users u ON sl.user_id = u.id
      WHERE sl.action LIKE '%ERROR%' OR sl.action LIKE '%FAIL%' OR sl.action LIKE '%EXCEPTION%'
    `;
    let countQuery = `
      SELECT COUNT(*) as total 
      FROM system_logs 
      WHERE action LIKE '%ERROR%' OR action LIKE '%FAIL%' OR action LIKE '%EXCEPTION%'
    `;
    let params = [];
    let countParams = [];

    if (severity) {
      query += ' AND sl.action LIKE ?';
      countQuery += ' AND action LIKE ?';
      params.push(`%${severity}%`);
      countParams.push(`%${severity}%`);
    }

    query += ' ORDER BY sl.created_at DESC LIMIT ? OFFSET ?';
    params.push(limit, offset);

    const [errors] = await pool.query(query, params);
    const [totalResult] = await pool.query(countQuery, countParams);

    res.json({
      errors,
      pagination: {
        page,
        limit,
        total: totalResult[0].total,
        pages: Math.ceil(totalResult[0].total / limit)
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get performance metrics
router.get('/performance', auth, superadminOnly, async (req, res) => {
  try {
    const days = parseInt(req.query.days) || 7;
    
    // Database performance metrics
    const [dbMetrics] = await pool.query(`
      SELECT 
        COUNT(*) as total_queries,
        AVG(TIME_TO_SEC(TIMEDIFF(created_at, created_at))) as avg_response_time,
        MAX(created_at) as last_query_time
      FROM system_logs 
      WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
    `, [days]);

    // User activity metrics
    const [userMetrics] = await pool.query(`
      SELECT 
        COUNT(DISTINCT user_id) as active_users,
        COUNT(*) as total_actions,
        DATE(created_at) as date
      FROM system_logs 
      WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
      GROUP BY DATE(created_at)
      ORDER BY date DESC
    `, [days]);

    // System resource usage
    const os = require('os');
    const performance = {
      database: {
        totalQueries: dbMetrics[0]?.total_queries || 0,
        avgResponseTime: dbMetrics[0]?.avg_response_time || 0,
        lastQueryTime: dbMetrics[0]?.last_query_time
      },
      users: userMetrics,
      system: {
        cpuUsage: os.loadavg(),
        memoryUsage: ((os.totalmem() - os.freemem()) / os.totalmem() * 100).toFixed(2),
        uptime: process.uptime(),
        nodeVersion: process.version,
        platform: os.platform()
      }
    };

    res.json(performance);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// --- Notifications & Alerts System ---

// Create notification
router.post('/notifications', auth, superadminOnly, async (req, res) => {
  try {
    const { title, message, type, target_users, priority } = req.body;

    if (!title || !message || !type) {
      return res.status(400).json({ message: 'Title, message, and type are required' });
    }

    const validTypes = ['info', 'warning', 'error', 'success'];
    if (!validTypes.includes(type)) {
      return res.status(400).json({ message: 'Invalid notification type' });
    }

    const validPriorities = ['low', 'medium', 'high', 'urgent'];
    const notificationPriority = validPriorities.includes(priority) ? priority : 'medium';

    // Create notification
    const [result] = await pool.query(
      'INSERT INTO notifications (title, message, type, priority, created_by) VALUES (?, ?, ?, ?, ?)',
      [title, message, type, notificationPriority, req.user.id]
    );

    const notificationId = result.insertId;

    // If target_users is specified, create user-specific notifications
    if (target_users && Array.isArray(target_users) && target_users.length > 0) {
      const userNotifications = target_users.map(userId => [notificationId, userId]);
      await pool.query(
        'INSERT INTO user_notifications (notification_id, user_id) VALUES ?',
        [userNotifications]
      );
    } else {
      // Create notifications for all users
      const [users] = await pool.query('SELECT id FROM users');
      const userNotifications = users.map(user => [notificationId, user.id]);
      if (userNotifications.length > 0) {
        await pool.query(
          'INSERT INTO user_notifications (notification_id, user_id) VALUES ?',
          [userNotifications]
        );
      }
    }

    // Log the action
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'CREATE_NOTIFICATION', 'notifications', notificationId, JSON.stringify({ title, type, priority })]
    );

    res.status(201).json({ 
      message: 'Notification created successfully',
      notification_id: notificationId
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get notifications (for superadmin)
router.get('/notifications', auth, superadminOnly, async (req, res) => {
  try {
    const { page = 1, limit = 20, type, priority, read } = req.query;
    const offset = (page - 1) * limit;

    let query = `
      SELECT n.*, u.username as created_by_name, 
             COUNT(un.user_id) as target_count,
             COUNT(CASE WHEN un.is_read = 1 THEN 1 END) as read_count
      FROM notifications n
      LEFT JOIN users u ON n.created_by = u.id
      LEFT JOIN user_notifications un ON n.id = un.notification_id
    `;

    const whereConditions = [];
    const queryParams = [];

    if (type) {
      whereConditions.push('n.type = ?');
      queryParams.push(type);
    }

    if (priority) {
      whereConditions.push('n.priority = ?');
      queryParams.push(priority);
    }

    if (read !== undefined) {
      whereConditions.push('un.is_read = ?');
      queryParams.push(read === 'true' ? 1 : 0);
    }

    if (whereConditions.length > 0) {
      query += ' WHERE ' + whereConditions.join(' AND ');
    }

    query += ' GROUP BY n.id ORDER BY n.created_at DESC LIMIT ? OFFSET ?';
    queryParams.push(parseInt(limit), offset);

    const [notifications] = await pool.query(query, queryParams);

    // Get total count
    let countQuery = 'SELECT COUNT(DISTINCT n.id) as total FROM notifications n';
    if (whereConditions.length > 0) {
      countQuery += ' WHERE ' + whereConditions.join(' AND ');
    }
    const [countResult] = await pool.query(countQuery, queryParams.slice(0, -2));
    const total = countResult[0].total;

    res.json({
      notifications,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get user notifications (for regular users)
router.get('/notifications/user', auth, async (req, res) => {
  try {
    const { page = 1, limit = 10, unread_only = false } = req.query;
    const offset = (page - 1) * limit;

    let query = `
      SELECT n.*, un.is_read, un.read_at
      FROM notifications n
      INNER JOIN user_notifications un ON n.id = un.notification_id
      WHERE un.user_id = ?
    `;

    const queryParams = [req.user.id];

    if (unread_only === 'true') {
      query += ' AND un.is_read = 0';
    }

    query += ' ORDER BY n.created_at DESC LIMIT ? OFFSET ?';
    queryParams.push(parseInt(limit), offset);

    const [notifications] = await pool.query(query, queryParams);

    // Get unread count
    const [unreadCount] = await pool.query(
      'SELECT COUNT(*) as count FROM user_notifications WHERE user_id = ? AND is_read = 0',
      [req.user.id]
    );

    res.json({
      notifications,
      unread_count: unreadCount[0].count
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Mark notification as read
router.put('/notifications/:id/read', auth, async (req, res) => {
  try {
    const { id } = req.params;

    const [result] = await pool.query(
      'UPDATE user_notifications SET is_read = 1, read_at = NOW() WHERE notification_id = ? AND user_id = ?',
      [id, req.user.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'Notification not found' });
    }

    res.json({ message: 'Notification marked as read' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Mark all notifications as read
router.put('/notifications/read-all', auth, async (req, res) => {
  try {
    await pool.query(
      'UPDATE user_notifications SET is_read = 1, read_at = NOW() WHERE user_id = ? AND is_read = 0',
      [req.user.id]
    );

    res.json({ message: 'All notifications marked as read' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Delete notification (superadmin only)
router.delete('/notifications/:id', auth, superadminOnly, async (req, res) => {
  try {
    const { id } = req.params;

    // Delete user notifications first
    await pool.query('DELETE FROM user_notifications WHERE notification_id = ?', [id]);

    // Delete the notification
    const [result] = await pool.query('UPDATE notifications SET is_deleted = 1 WHERE id = ?', [id]);

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

// Get notification statistics
router.get('/notifications/stats', auth, superadminOnly, async (req, res) => {
  try {
    // Total notifications
    const [totalNotifications] = await pool.query('SELECT COUNT(*) as count FROM notifications');
    
    // Notifications by type
    const [byType] = await pool.query(
      'SELECT type, COUNT(*) as count FROM notifications GROUP BY type'
    );
    
    // Notifications by priority
    const [byPriority] = await pool.query(
      'SELECT priority, COUNT(*) as count FROM notifications GROUP BY priority'
    );
    
    // Recent notifications (last 7 days)
    const [recent] = await pool.query(
      'SELECT COUNT(*) as count FROM notifications WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)'
    );
    
    // Unread notifications
    const [unread] = await pool.query(
      'SELECT COUNT(*) as count FROM user_notifications WHERE is_read = 0'
    );

    res.json({
      total: totalNotifications[0].count,
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

// --- Audit Trail & Activity Logging ---

// Get audit logs with filtering
router.get('/audit-logs', auth, superadminOnly, async (req, res) => {
  try {
    const { 
      page = 1, 
      limit = 50, 
      user_id, 
      action, 
      table_name, 
      start_date, 
      end_date,
      record_id,
      sort_by = 'created_at',
      sort_order = 'DESC'
    } = req.query;
    
    const offset = (page - 1) * limit;

    let query = `
      SELECT sl.*, u.username, u.email
      FROM system_logs sl
      LEFT JOIN users u ON sl.user_id = u.id
    `;

    const whereConditions = [];
    const queryParams = [];

    if (user_id) {
      whereConditions.push('sl.user_id = ?');
      queryParams.push(user_id);
    }

    if (action) {
      whereConditions.push('sl.action = ?');
      queryParams.push(action);
    }

    if (table_name) {
      whereConditions.push('sl.table_name = ?');
      queryParams.push(table_name);
    }

    if (record_id) {
      whereConditions.push('sl.record_id = ?');
      queryParams.push(record_id);
    }

    if (start_date) {
      whereConditions.push('sl.created_at >= ?');
      queryParams.push(start_date);
    }

    if (end_date) {
      whereConditions.push('sl.created_at <= ?');
      queryParams.push(end_date + ' 23:59:59');
    }

    if (whereConditions.length > 0) {
      query += ' WHERE ' + whereConditions.join(' AND ');
    }

    // Validate sort parameters
    const validSortFields = ['created_at', 'action', 'table_name', 'user_id'];
    const validSortOrders = ['ASC', 'DESC'];
    
    const sortField = validSortFields.includes(sort_by) ? sort_by : 'created_at';
    const sortOrder = validSortOrders.includes(sort_order.toUpperCase()) ? sort_order.toUpperCase() : 'DESC';

    query += ` ORDER BY sl.${sortField} ${sortOrder} LIMIT ? OFFSET ?`;
    queryParams.push(parseInt(limit), offset);

    const [logs] = await pool.query(query, queryParams);

    // Get total count
    let countQuery = 'SELECT COUNT(*) as total FROM system_logs sl';
    if (whereConditions.length > 0) {
      countQuery += ' WHERE ' + whereConditions.join(' AND ');
    }
    const [countResult] = await pool.query(countQuery, queryParams.slice(0, -2));
    const total = countResult[0].total;

    // Get action statistics
    const [actionStats] = await pool.query(
      'SELECT action, COUNT(*) as count FROM system_logs GROUP BY action ORDER BY count DESC'
    );

    // Get table statistics
    const [tableStats] = await pool.query(
      'SELECT table_name, COUNT(*) as count FROM system_logs WHERE table_name IS NOT NULL GROUP BY table_name ORDER BY count DESC'
    );

    res.json({
      logs,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit)
      },
      statistics: {
        action_stats: actionStats,
        table_stats: tableStats
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Export audit logs to CSV
router.get('/audit-logs/export', auth, superadminOnly, async (req, res) => {
  try {
    const { 
      user_id, 
      action, 
      table_name, 
      start_date, 
      end_date,
      format = 'csv'
    } = req.query;

    let query = `
      SELECT sl.id, sl.user_id, u.username, u.email, sl.action, sl.table_name, 
             sl.record_id, sl.old_values, sl.new_values, sl.ip_address, sl.user_agent, sl.created_at
      FROM system_logs sl
      LEFT JOIN users u ON sl.user_id = u.id
    `;

    const whereConditions = [];
    const queryParams = [];

    if (user_id) {
      whereConditions.push('sl.user_id = ?');
      queryParams.push(user_id);
    }

    if (action) {
      whereConditions.push('sl.action = ?');
      queryParams.push(action);
    }

    if (table_name) {
      whereConditions.push('sl.table_name = ?');
      queryParams.push(table_name);
    }

    if (start_date) {
      whereConditions.push('sl.created_at >= ?');
      queryParams.push(start_date);
    }

    if (end_date) {
      whereConditions.push('sl.created_at <= ?');
      queryParams.push(end_date + ' 23:59:59');
    }

    if (whereConditions.length > 0) {
      query += ' WHERE ' + whereConditions.join(' AND ');
    }

    query += ' ORDER BY sl.created_at DESC';

    const [logs] = await pool.query(query, queryParams);

    if (format === 'csv') {
      // Generate CSV
      const csvHeaders = [
        'ID', 'User ID', 'Username', 'Email', 'Action', 'Table', 'Record ID', 
        'Old Values', 'New Values', 'IP Address', 'User Agent', 'Created At'
      ];

      const csvRows = logs.map(log => [
        log.id,
        log.user_id,
        log.username || '',
        log.email || '',
        log.action,
        log.table_name || '',
        log.record_id || '',
        log.old_values || '',
        log.new_values || '',
        log.ip_address || '',
        log.user_agent || '',
        log.created_at
      ]);

      const csvContent = [csvHeaders, ...csvRows]
        .map(row => row.map(field => `"${field}"`).join(','))
        .join('\n');

      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', 'attachment; filename="audit_logs.csv"');
      res.send(csvContent);
    } else {
      res.json({ logs });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get user activity summary
router.get('/audit-logs/user-activity', auth, superadminOnly, async (req, res) => {
  try {
    const { user_id, days = 30 } = req.query;

    if (!user_id) {
      return res.status(400).json({ message: 'User ID is required' });
    }

    // Get user's recent activity
    const [recentActivity] = await pool.query(
      `SELECT action, table_name, created_at, ip_address
       FROM system_logs 
       WHERE user_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
       ORDER BY created_at DESC`,
      [user_id, days]
    );

    // Get activity by action type
    const [actionBreakdown] = await pool.query(
      `SELECT action, COUNT(*) as count 
       FROM system_logs 
       WHERE user_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
       GROUP BY action 
       ORDER BY count DESC`,
      [user_id, days]
    );

    // Get activity by table
    const [tableBreakdown] = await pool.query(
      `SELECT table_name, COUNT(*) as count 
       FROM system_logs 
       WHERE user_id = ? AND table_name IS NOT NULL AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
       GROUP BY table_name 
       ORDER BY count DESC`,
      [user_id, days]
    );

    // Get daily activity for the last 7 days
    const [dailyActivity] = await pool.query(
      `SELECT DATE(created_at) as date, COUNT(*) as count
       FROM system_logs 
       WHERE user_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
       GROUP BY DATE(created_at)
       ORDER BY date DESC`,
      [user_id]
    );

    // Get unique IP addresses used
    const [ipAddresses] = await pool.query(
      `SELECT DISTINCT ip_address 
       FROM system_logs 
       WHERE user_id = ? AND ip_address IS NOT NULL AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)`,
      [user_id, days]
    );

    res.json({
      recent_activity: recentActivity,
      action_breakdown: actionBreakdown,
      table_breakdown: tableBreakdown,
      daily_activity: dailyActivity,
      ip_addresses: ipAddresses.map(ip => ip.ip_address),
      total_actions: recentActivity.length
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get system activity summary
router.get('/audit-logs/system-activity', auth, superadminOnly, async (req, res) => {
  try {
    const { days = 7 } = req.query;

    // Get total actions in the period
    const [totalActions] = await pool.query(
      'SELECT COUNT(*) as count FROM system_logs WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)',
      [days]
    );

    // Get actions by user
    const [actionsByUser] = await pool.query(
      `SELECT u.username, u.email, COUNT(sl.id) as action_count
       FROM system_logs sl
       LEFT JOIN users u ON sl.user_id = u.id
       WHERE sl.created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
       GROUP BY sl.user_id, u.username, u.email
       ORDER BY action_count DESC`,
      [days]
    );

    // Get most active hours
    const [activeHours] = await pool.query(
      `SELECT HOUR(created_at) as hour, COUNT(*) as count
       FROM system_logs 
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
       GROUP BY HOUR(created_at)
       ORDER BY count DESC
       LIMIT 10`,
      [days]
    );

    // Get most common actions
    const [commonActions] = await pool.query(
      `SELECT action, COUNT(*) as count
       FROM system_logs 
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
       GROUP BY action
       ORDER BY count DESC
       LIMIT 10`,
      [days]
    );

    // Get most affected tables
    const [affectedTables] = await pool.query(
      `SELECT table_name, COUNT(*) as count
       FROM system_logs 
       WHERE table_name IS NOT NULL AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
       GROUP BY table_name
       ORDER BY count DESC
       LIMIT 10`,
      [days]
    );

    // Get daily activity trend
    const [dailyTrend] = await pool.query(
      `SELECT DATE(created_at) as date, COUNT(*) as count
       FROM system_logs 
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
       GROUP BY DATE(created_at)
       ORDER BY date`,
      [days]
    );

    res.json({
      total_actions: totalActions[0].count,
      actions_by_user: actionsByUser,
      active_hours: activeHours,
      common_actions: commonActions,
      affected_tables: affectedTables,
      daily_trend: dailyTrend
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get audit log statistics
router.get('/audit-logs/stats', auth, superadminOnly, async (req, res) => {
  try {
    // Total logs
    const [totalLogs] = await pool.query('SELECT COUNT(*) as count FROM system_logs');
    
    // Logs today
    const [todayLogs] = await pool.query(
      'SELECT COUNT(*) as count FROM system_logs WHERE DATE(created_at) = CURDATE()'
    );
    
    // Logs this week
    const [weekLogs] = await pool.query(
      'SELECT COUNT(*) as count FROM system_logs WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)'
    );
    
    // Logs this month
    const [monthLogs] = await pool.query(
      'SELECT COUNT(*) as count FROM system_logs WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)'
    );
    
    // Unique users who performed actions
    const [uniqueUsers] = await pool.query(
      'SELECT COUNT(DISTINCT user_id) as count FROM system_logs WHERE user_id IS NOT NULL'
    );
    
    // Most recent log
    const [recentLog] = await pool.query(
      'SELECT created_at FROM system_logs ORDER BY created_at DESC LIMIT 1'
    );

    res.json({
      total_logs: totalLogs[0].count,
      today_logs: todayLogs[0].count,
      week_logs: weekLogs[0].count,
      month_logs: monthLogs[0].count,
      unique_users: uniqueUsers[0].count,
      last_activity: recentLog[0]?.created_at || null
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// --- Advanced Analytics & Reporting ---

// Get comprehensive sales analytics
router.get('/analytics/sales', auth, superadminOnly, async (req, res) => {
  try {
    const { start_date, end_date, group_by = 'day' } = req.query;
    
    let dateFilter = '';
    const queryParams = [];
    
    if (start_date && end_date) {
      dateFilter = 'WHERE s.created_at BETWEEN ? AND ?';
      queryParams.push(start_date, end_date + ' 23:59:59');
    }

    // Sales by date
    let groupByClause = 'DATE(s.created_at)';
    if (group_by === 'week') {
      groupByClause = 'YEARWEEK(s.created_at)';
    } else if (group_by === 'month') {
      groupByClause = 'DATE_FORMAT(s.created_at, "%Y-%m")';
    }

    const [salesByDate] = await pool.query(
      `SELECT ${groupByClause} as date, 
              COUNT(*) as total_sales,
              SUM(s.total_amount) as total_revenue,
              AVG(s.total_amount) as avg_sale_value
       FROM sales s
       ${dateFilter}
       GROUP BY ${groupByClause}
       ORDER BY date DESC`,
      queryParams
    );

    // Sales by payment method
    const [salesByPayment] = await pool.query(
      `SELECT payment_method, 
              COUNT(*) as count,
              SUM(total_amount) as total_amount
       FROM sales
       ${dateFilter}
       GROUP BY payment_method
       ORDER BY total_amount DESC`,
      queryParams
    );

    // Top selling products
    const [topProducts] = await pool.query(
      `SELECT p.name, p.sku,
              COUNT(si.id) as units_sold,
              SUM(si.quantity * si.unit_price) as revenue
       FROM sales s
       JOIN sale_items si ON s.id = si.sale_id
       JOIN products p ON si.product_id = p.id
       ${dateFilter}
       GROUP BY p.id, p.name, p.sku
       ORDER BY units_sold DESC
       LIMIT 10`,
      queryParams
    );

    // Sales by hour of day
    const [salesByHour] = await pool.query(
      `SELECT HOUR(s.created_at) as hour,
              COUNT(*) as sales_count,
              SUM(s.total_amount) as total_revenue
       FROM sales s
       ${dateFilter}
       GROUP BY HOUR(s.created_at)
       ORDER BY hour`,
      queryParams
    );

    // Sales performance summary
    const [salesSummary] = await pool.query(
      `SELECT 
              COUNT(*) as total_sales,
              SUM(total_amount) as total_revenue,
              AVG(total_amount) as avg_sale_value,
              MIN(total_amount) as min_sale,
              MAX(total_amount) as max_sale,
              COUNT(DISTINCT customer_id) as unique_customers
       FROM sales s
       ${dateFilter}`,
      queryParams
    );

    res.json({
      overall_stats: salesSummary[0],
      sales_by_date: salesByDate,
      sales_by_payment: salesByPayment,
      top_products: topProducts,
      sales_by_hour: salesByHour
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// --- Analytics Stubs ---
router.get('/analytics/users', auth, superadminOnly, async (req, res) => {
  try {
    const { start_date, end_date } = req.query;
    
    let dateFilter = '';
    const queryParams = [];
    
    if (start_date && end_date) {
      dateFilter = 'WHERE u.created_at BETWEEN ? AND ?';
      queryParams.push(start_date, end_date + ' 23:59:59');
    }

    // User statistics overview
    const [userStats] = await pool.query(
      `SELECT 
        COUNT(*) as total_users,
        COUNT(CASE WHEN u.role = 'admin' THEN 1 END) as admin_count,
        COUNT(CASE WHEN u.role = 'manager' THEN 1 END) as manager_count,
        COUNT(CASE WHEN u.role = 'cashier' THEN 1 END) as cashier_count,
        COUNT(CASE WHEN u.is_active = 1 THEN 1 END) as active_users,
        COUNT(CASE WHEN u.last_login >= DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 1 END) as recent_users
       FROM users u
       ${dateFilter}`,
      queryParams
    );

    // Roles distribution
    const [rolesDistribution] = await pool.query(
      `SELECT 
        role,
        COUNT(*) as count
       FROM users u
       ${dateFilter}
       GROUP BY role
       ORDER BY count DESC`,
      queryParams
    );

    // Most active users (by sales created)
    const [activeUsers] = await pool.query(
      `SELECT 
        u.username,
        u.email,
        u.role,
        COUNT(s.id) as sales_created,
        u.last_login
       FROM users u
       LEFT JOIN sales s ON u.id = s.user_id
       ${dateFilter.replace('u.created_at', 's.created_at')}
       GROUP BY u.id, u.username, u.email, u.role, u.last_login
       ORDER BY sales_created DESC
       LIMIT 10`,
      queryParams
    );

    // User registrations by date
    const [registrationsByDate] = await pool.query(
      `SELECT 
        DATE(u.created_at) as date,
        COUNT(*) as new_users
       FROM users u
       ${dateFilter}
       GROUP BY DATE(u.created_at)
       ORDER BY date DESC
       LIMIT 30`,
      queryParams
    );

    // User activity by hour
    const [userActivityByHour] = await pool.query(
      `SELECT 
        HOUR(u.last_login) as hour,
        COUNT(*) as active_users
       FROM users u
       WHERE u.last_login >= DATE_SUB(NOW(), INTERVAL 7 DAY)
       GROUP BY HOUR(u.last_login)
       ORDER BY hour`,
      []
    );

    res.json({
      user_stats: userStats[0],
      roles_distribution: rolesDistribution,
      active_users: activeUsers,
      registrations_by_date: registrationsByDate,
      user_activity_by_hour: userActivityByHour
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

router.get('/analytics/products', auth, superadminOnly, async (req, res) => {
  try {
    const { start_date, end_date } = req.query;
    
    let dateFilter = '';
    const queryParams = [];
    
    if (start_date && end_date) {
      dateFilter = 'WHERE p.created_at BETWEEN ? AND ?';
      queryParams.push(start_date, end_date + ' 23:59:59');
    }

    // Product statistics overview
    const [productStats] = await pool.query(
      `SELECT 
        COUNT(*) as total_products,
        COUNT(CASE WHEN p.stock_quantity > p.low_stock_threshold THEN 1 END) as in_stock,
        COUNT(CASE WHEN p.stock_quantity = 0 THEN 1 END) as out_of_stock,
        COUNT(CASE WHEN p.stock_quantity <= p.low_stock_threshold AND p.stock_quantity > 0 THEN 1 END) as low_stock,
        SUM(p.stock_quantity * p.cost_price) as total_stock_value,
        AVG(p.cost_price) as avg_product_cost_price,
        AVG(p.selling_price) as avg_product_selling_price
       FROM products p
       ${dateFilter}`,
      queryParams
    );

    // Category performance
    const [categoryPerformance] = await pool.query(
      `SELECT 
        c.name as category,
        COUNT(p.id) as product_count,
        SUM(p.stock_quantity * p.cost_price) as stock_value,
        SUM(si.quantity * si.unit_price) as total_revenue
       FROM categories c
       LEFT JOIN products p ON c.id = p.category_id
       LEFT JOIN sale_items si ON p.id = si.product_id
       LEFT JOIN sales s ON si.sale_id = s.id
       ${dateFilter.replace('p.created_at', 's.created_at')}
       GROUP BY c.id, c.name
       ORDER BY total_revenue DESC`,
      queryParams
    );

    // Low stock products
    const [lowStockProducts] = await pool.query(
      `SELECT 
        p.name,
        p.sku,
        p.stock_quantity,
        p.low_stock_threshold,
        c.name as category
       FROM products p
       LEFT JOIN categories c ON p.category_id = c.id
       WHERE p.stock_quantity <= p.low_stock_threshold
       ORDER BY p.stock_quantity ASC
       LIMIT 20`,
      []
    );

    // Top selling products
    const [topSellingProducts] = await pool.query(
      `SELECT 
        p.name,
        p.sku,
        COUNT(si.id) as units_sold,
        SUM(si.quantity * si.unit_price) as revenue,
        c.name as category
       FROM products p
       LEFT JOIN categories c ON p.category_id = c.id
       LEFT JOIN sale_items si ON p.id = si.product_id
       LEFT JOIN sales s ON si.sale_id = s.id
       ${dateFilter.replace('p.created_at', 's.created_at')}
       GROUP BY p.id, p.name, p.sku, c.name
       ORDER BY units_sold DESC
       LIMIT 10`,
      queryParams
    );

    // Inventory analysis (stock value by product)
    const [inventoryAnalysis] = await pool.query(
      `SELECT 
        p.name,
        p.sku,
        p.stock_quantity,
        p.cost_price,
        (p.stock_quantity * p.cost_price) as stock_value,
        c.name as category
       FROM products p
       LEFT JOIN categories c ON p.category_id = c.id
       ORDER BY stock_value DESC
       LIMIT 20`,
      []
    );

    // Products added by date
    const [productsByDate] = await pool.query(
      `SELECT 
        DATE(p.created_at) as date,
        COUNT(*) as new_products
       FROM products p
       ${dateFilter}
       GROUP BY DATE(p.created_at)
       ORDER BY date DESC
       LIMIT 30`,
      queryParams
    );

    res.json({
      product_stats: productStats[0],
      category_performance: categoryPerformance,
      low_stock_products: lowStockProducts,
      top_selling_products: topSellingProducts,
      inventory_analysis: inventoryAnalysis,
      products_by_date: productsByDate
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

router.get('/analytics/performance', auth, superadminOnly, async (req, res) => {
  try {
    const { days = 7 } = req.query;

    // System metrics overview
    const [systemMetrics] = await pool.query(
      `SELECT 
        (SELECT COUNT(*) FROM users) as total_users,
        (SELECT COUNT(*) FROM products) as total_products,
        (SELECT COUNT(*) FROM sales) as total_sales,
        (SELECT COUNT(*) FROM customers) as total_customers,
        (SELECT SUM(total_amount) FROM sales) as total_revenue,
        (SELECT COUNT(*) FROM system_logs WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)) as recent_actions
       FROM dual`,
      [days]
    );

    // Database performance metrics
    const [dbPerformance] = await pool.query(
      `SELECT 
        (SELECT COUNT(*) FROM sales WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)) as recent_sales,
        (SELECT COUNT(*) FROM system_logs WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)) as recent_logs,
        (SELECT COUNT(*) FROM users WHERE last_login >= DATE_SUB(NOW(), INTERVAL 30 MINUTE)) as active_users
       FROM dual`,
      [days, days]
    );

    // Error statistics
    const [errorStats] = await pool.query(
      `SELECT 
        COUNT(*) as total_errors,
        COUNT(CASE WHEN DATE(created_at) = CURDATE() THEN 1 END) as errors_today,
        COUNT(CASE WHEN created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 1 END) as errors_this_week
       FROM system_logs 
       WHERE action LIKE '%ERROR%' OR action LIKE '%FAIL%'`,
      []
    );

    // Response times (simulated - in real implementation, you'd track actual API response times)
    const responseTimes = {
      average_response_time: 150, // ms
      p95_response_time: 300,     // ms
      p99_response_time: 500      // ms
    };

    // System load metrics
    const [systemLoad] = await pool.query(
      `SELECT 
        COUNT(*) as total_connections,
        COUNT(CASE WHEN Command = 'Sleep' THEN 1 END) as idle_connections,
        COUNT(CASE WHEN Command != 'Sleep' THEN 1 END) as active_connections
       FROM information_schema.PROCESSLIST`,
      []
    );

    // User activity patterns
    const [userActivityPatterns] = await pool.query(
      `SELECT 
        HOUR(last_login) as hour,
        COUNT(*) as active_users
       FROM users 
       WHERE last_login >= DATE_SUB(NOW(), INTERVAL 7 DAY)
       GROUP BY HOUR(last_login)
       ORDER BY hour`,
      []
    );

    // Most common actions
    const [commonActions] = await pool.query(
      `SELECT 
        action,
        COUNT(*) as count
       FROM system_logs 
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
       GROUP BY action
       ORDER BY count DESC
       LIMIT 10`,
      [days]
    );

    // Peak usage hours
    const [peakUsageHours] = await pool.query(
      `SELECT 
        HOUR(created_at) as hour,
        COUNT(*) as actions
       FROM system_logs 
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
       GROUP BY HOUR(created_at)
       ORDER BY actions DESC
       LIMIT 5`,
      [days]
    );

    res.json({
      system_metrics: systemMetrics[0],
      db_performance: dbPerformance[0],
      error_stats: errorStats[0],
      response_times: responseTimes,
      system_load: systemLoad[0],
      user_activity_patterns: userActivityPatterns,
      common_actions: commonActions,
      peak_usage_hours: peakUsageHours
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// --- Deleted Data Endpoint ---
router.get('/deleted-data', auth, superadminOnly, async (req, res) => {
  try {
    const [users] = await pool.query('SELECT * FROM users WHERE is_deleted = 1');
    const [products] = await pool.query('SELECT * FROM products WHERE is_deleted = 1');
    const [sales] = await pool.query('SELECT * FROM sales WHERE is_deleted = 1');
    res.json({
      users,
      products,
      sales
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// --- Data Recovery Endpoints ---

// Get deleted data for a specific business
router.get('/businesses/:businessId/deleted-data', auth, superadminOnly, async (req, res) => {
  try {
    const { businessId } = req.params;
    const { dataType } = req.query; // Optional filter: users, products, sales, all
    
    let response = {};
    
    if (!dataType || dataType === 'all' || dataType === 'users') {
      const [users] = await pool.query(
        'SELECT * FROM users WHERE business_id = ? AND is_deleted = 1 ORDER BY created_at DESC',
        [businessId]
      );
      response.users = users;
    }
    
    if (!dataType || dataType === 'all' || dataType === 'products') {
      const [products] = await pool.query(
        'SELECT * FROM products WHERE business_id = ? AND is_deleted = 1 ORDER BY created_at DESC',
        [businessId]
      );
      response.products = products;
    }
    
    if (!dataType || dataType === 'all' || dataType === 'sales') {
      const [sales] = await pool.query(
        'SELECT s.*, c.name as customer_name, u.username as user_name FROM sales s LEFT JOIN customers c ON s.customer_id = c.id LEFT JOIN users u ON s.user_id = u.id WHERE s.business_id = ? AND s.is_deleted = 1 ORDER BY s.created_at DESC',
        [businessId]
      );
      response.sales = sales;
    }
    
    if (!dataType || dataType === 'all' || dataType === 'customers') {
      const [customers] = await pool.query(
        'SELECT * FROM customers WHERE business_id = ? AND is_deleted = 1 ORDER BY created_at DESC',
        [businessId]
      );
      response.customers = customers;
    }
    
    if (!dataType || dataType === 'all' || dataType === 'categories') {
      const [categories] = await pool.query(
        'SELECT * FROM categories WHERE business_id = ? AND is_deleted = 1 ORDER BY created_at DESC',
        [businessId]
      );
      response.categories = categories;
    }
    
    if (!dataType || dataType === 'all' || dataType === 'notifications') {
      const [notifications] = await pool.query(
        'SELECT * FROM notifications WHERE business_id = ? AND is_deleted = 1 ORDER BY created_at DESC',
        [businessId]
      );
      response.notifications = notifications;
    }
    
    // Get business info
    const [business] = await pool.query('SELECT id, name, subscription_plan FROM businesses WHERE id = ?', [businessId]);
    response.business = business[0];
    
    res.json(response);
  } catch (error) {
    console.error('Error fetching deleted data for business:', error);
    res.status(500).json({ message: 'Failed to fetch deleted data' });
  }
});

// Recover specific deleted item
router.post('/recover/:dataType/:id', auth, superadminOnly, async (req, res) => {
  try {
    const { dataType, id } = req.params;
    const { businessId } = req.body;
    
    let tableName, businessIdColumn;
    
    switch (dataType) {
      case 'user':
        tableName = 'users';
        businessIdColumn = 'business_id';
        break;
      case 'product':
        tableName = 'products';
        businessIdColumn = 'business_id';
        break;
      case 'sale':
        tableName = 'sales';
        businessIdColumn = 'business_id';
        break;
      case 'customer':
        tableName = 'customers';
        businessIdColumn = 'business_id';
        break;
      case 'category':
        tableName = 'categories';
        businessIdColumn = 'business_id';
        break;
      case 'notification':
        tableName = 'notifications';
        businessIdColumn = 'business_id';
        break;
      default:
        return res.status(400).json({ message: 'Invalid data type' });
    }
    
    // Verify the item belongs to the specified business
    const [item] = await pool.query(
      `SELECT * FROM ${tableName} WHERE id = ? AND ${businessIdColumn} = ? AND is_deleted = 1`,
      [id, businessId]
    );
    
    if (item.length === 0) {
      return res.status(404).json({ message: 'Deleted item not found or does not belong to the specified business' });
    }
    
    // Recover the item
    await pool.query(
      `UPDATE ${tableName} SET is_deleted = 0 WHERE id = ?`,
      [id]
    );
    
    // Log the recovery action
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, old_values, new_values) VALUES (?, ?, ?, ?, ?, ?)',
      [
        req.user.id,
        'recover_deleted_item',
        tableName,
        id,
        JSON.stringify({ is_deleted: 1 }),
        JSON.stringify({ is_deleted: 0 })
      ]
    );
    
    res.json({ 
      message: `${dataType} recovered successfully`,
      recoveredItem: item[0]
    });
  } catch (error) {
    console.error('Error recovering deleted item:', error);
    res.status(500).json({ message: 'Failed to recover deleted item' });
  }
});

// Recover multiple items at once
router.post('/recover-multiple', auth, superadminOnly, async (req, res) => {
  try {
    const { businessId, items } = req.body; // items: [{type: 'user', id: 1}, {type: 'product', id: 2}]
    
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ message: 'No items specified for recovery' });
    }
    
    const recoveredItems = [];
    const failedItems = [];
    
    for (const item of items) {
      try {
        let tableName, businessIdColumn;
        
        switch (item.type) {
          case 'user':
            tableName = 'users';
            businessIdColumn = 'business_id';
            break;
          case 'product':
            tableName = 'products';
            businessIdColumn = 'business_id';
            break;
          case 'sale':
            tableName = 'sales';
            businessIdColumn = 'business_id';
            break;
          case 'customer':
            tableName = 'customers';
            businessIdColumn = 'business_id';
            break;
          case 'category':
            tableName = 'categories';
            businessIdColumn = 'business_id';
            break;
          case 'notification':
            tableName = 'notifications';
            businessIdColumn = 'business_id';
            break;
          default:
            failedItems.push({ ...item, error: 'Invalid data type' });
            continue;
        }
        
        // Verify the item belongs to the specified business
        const [existingItem] = await pool.query(
          `SELECT * FROM ${tableName} WHERE id = ? AND ${businessIdColumn} = ? AND is_deleted = 1`,
          [item.id, businessId]
        );
        
        if (existingItem.length === 0) {
          failedItems.push({ ...item, error: 'Item not found or does not belong to the specified business' });
          continue;
        }
        
        // Recover the item
        await pool.query(
          `UPDATE ${tableName} SET is_deleted = 0 WHERE id = ?`,
          [item.id]
        );
        
        // Log the recovery action
        await pool.query(
          'INSERT INTO system_logs (user_id, action, table_name, record_id, old_values, new_values) VALUES (?, ?, ?, ?, ?, ?)',
          [
            req.user.id,
            'recover_deleted_item',
            tableName,
            item.id,
            JSON.stringify({ is_deleted: 1 }),
            JSON.stringify({ is_deleted: 0 })
          ]
        );
        
        recoveredItems.push({ ...item, success: true });
        
      } catch (itemError) {
        console.error(`Error recovering item ${item.type} ${item.id}:`, itemError);
        failedItems.push({ ...item, error: itemError.message });
      }
    }
    
    res.json({
      message: `Recovery completed. ${recoveredItems.length} items recovered, ${failedItems.length} failed`,
      recoveredItems,
      failedItems
    });
  } catch (error) {
    console.error('Error recovering multiple items:', error);
    res.status(500).json({ message: 'Failed to recover items' });
  }
});

// Permanently delete items (cannot be recovered)
router.delete('/permanently-delete/:dataType/:id', auth, superadminOnly, async (req, res) => {
  try {
    const { dataType, id } = req.params;
    const { businessId } = req.body;
    
    let tableName, businessIdColumn;
    
    switch (dataType) {
      case 'user':
        tableName = 'users';
        businessIdColumn = 'business_id';
        break;
      case 'product':
        tableName = 'products';
        businessIdColumn = 'business_id';
        break;
      case 'sale':
        tableName = 'sales';
        businessIdColumn = 'business_id';
        break;
      case 'customer':
        tableName = 'customers';
        businessIdColumn = 'business_id';
        break;
      case 'category':
        tableName = 'categories';
        businessIdColumn = 'business_id';
        break;
      case 'notification':
        tableName = 'notifications';
        businessIdColumn = 'business_id';
        break;
      default:
        return res.status(400).json({ message: 'Invalid data type' });
    }
    
    // Verify the item belongs to the specified business and is already soft deleted
    const [item] = await pool.query(
      `SELECT * FROM ${tableName} WHERE id = ? AND ${businessIdColumn} = ? AND is_deleted = 1`,
      [id, businessId]
    );
    
    if (item.length === 0) {
      return res.status(404).json({ message: 'Deleted item not found or does not belong to the specified business' });
    }
    
    // Log the permanent deletion action
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, old_values, new_values) VALUES (?, ?, ?, ?, ?, ?)',
      [
        req.user.id,
        'permanently_delete_item',
        tableName,
        id,
        JSON.stringify(item[0]),
        JSON.stringify({ permanently_deleted: true })
      ]
    );
    
    // Permanently delete the item
    await pool.query(
      `DELETE FROM ${tableName} WHERE id = ?`,
      [id]
    );
    
    res.json({ 
      message: `${dataType} permanently deleted`,
      deletedItem: item[0]
    });
  } catch (error) {
    console.error('Error permanently deleting item:', error);
    res.status(500).json({ message: 'Failed to permanently delete item' });
  }
});

// Get recovery statistics for a business
router.get('/businesses/:businessId/recovery-stats', auth, superadminOnly, async (req, res) => {
  try {
    const { businessId } = req.params;
    
    const [userStats] = await pool.query(
      'SELECT COUNT(*) as deleted_count FROM users WHERE business_id = ? AND is_deleted = 1',
      [businessId]
    );
    
    const [productStats] = await pool.query(
      'SELECT COUNT(*) as deleted_count FROM products WHERE business_id = ? AND is_deleted = 1',
      [businessId]
    );
    
    const [saleStats] = await pool.query(
      'SELECT COUNT(*) as deleted_count FROM sales WHERE business_id = ? AND is_deleted = 1',
      [businessId]
    );
    
    const [customerStats] = await pool.query(
      'SELECT COUNT(*) as deleted_count FROM customers WHERE business_id = ? AND is_deleted = 1',
      [businessId]
    );
    
    const [categoryStats] = await pool.query(
      'SELECT COUNT(*) as deleted_count FROM categories WHERE business_id = ? AND is_deleted = 1',
      [businessId]
    );
    
    const [notificationStats] = await pool.query(
      'SELECT COUNT(*) as deleted_count FROM notifications WHERE business_id = ? AND is_deleted = 1',
      [businessId]
    );
    
    res.json({
      business_id: businessId,
      deleted_counts: {
        users: userStats[0].deleted_count,
        products: productStats[0].deleted_count,
        sales: saleStats[0].deleted_count,
        customers: customerStats[0].deleted_count,
        categories: categoryStats[0].deleted_count,
        notifications: notificationStats[0].deleted_count
      },
      total_deleted: userStats[0].deleted_count + productStats[0].deleted_count + 
                    saleStats[0].deleted_count + customerStats[0].deleted_count + 
                    categoryStats[0].deleted_count + notificationStats[0].deleted_count
    });
  } catch (error) {
    console.error('Error fetching recovery stats:', error);
    res.status(500).json({ message: 'Failed to fetch recovery statistics' });
  }
});

// --- ACCOUNTING SECTION START ---

// Vendors CRUD
router.get('/accounting/vendors', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  let query = 'SELECT * FROM vendors WHERE business_id = ? ORDER BY name';
  let params = [req.user.business_id];
  if (req.user.role === 'superadmin') {
    query = 'SELECT * FROM vendors ORDER BY name';
    params = [];
  }
  const [vendors] = await pool.query(query, params);
  res.json(vendors);
});
router.post('/accounting/vendors', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  const { name, contact, email, phone, address } = req.body;
  const businessId = req.user.business_id;
  await pool.query('INSERT INTO vendors (name, contact, email, phone, address, business_id) VALUES (?, ?, ?, ?, ?, ?)', [name, contact, email, phone, address, businessId]);
  res.json({ message: 'Vendor added' });
});
router.put('/accounting/vendors/:id', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  const { name, contact, email, phone, address } = req.body;
  await pool.query('UPDATE vendors SET name=?, contact=?, email=?, phone=?, address=? WHERE id=?', [name, contact, email, phone, address, req.params.id]);
  res.json({ message: 'Vendor updated' });
});
router.delete('/accounting/vendors/:id', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  await pool.query('DELETE FROM vendors WHERE id=?', [req.params.id]);
  res.json({ message: 'Vendor deleted' });
});

// Expenses CRUD
router.get('/accounting/expenses', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  let query = 'SELECT e.*, v.name as vendor_name FROM expenses e LEFT JOIN vendors v ON e.vendor_id = v.id WHERE e.business_id = ? ORDER BY date DESC';
  let params = [req.user.business_id];
  if (req.user.role === 'superadmin') {
    query = 'SELECT e.*, v.name as vendor_name FROM expenses e LEFT JOIN vendors v ON e.vendor_id = v.id ORDER BY date DESC';
    params = [];
  }
  const [expenses] = await pool.query(query, params);
  res.json(expenses);
});
router.post('/accounting/expenses', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    
    const { date, amount, category, vendor_id, notes } = req.body;
    const businessId = req.user.business_id;
    
    // Insert the expense
    await connection.query(
      'INSERT INTO expenses (date, amount, category, vendor_id, notes, business_id) VALUES (?, ?, ?, ?, ?, ?)', 
      [date, amount, category, vendor_id, notes, businessId]
    );
    
    // Create cash flow entry to decrease cash in hand
    await connection.query(
      `INSERT INTO cash_flows (type, amount, date, reference, notes, business_id) 
       VALUES (?, ?, ?, ?, ?, ?)`,
      ['out', amount, date, `Expense - ${category}`, notes || `Expense for ${category}`, businessId]
    );
    
    await connection.commit();
    res.json({ message: 'Expense added' });
  } catch (error) {
    await connection.rollback();
    console.error('Error adding expense:', error);
    res.status(500).json({ message: 'Server error' });
  } finally {
    connection.release();
  }
});
router.put('/accounting/expenses/:id', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  const { date, amount, category, vendor_id, notes } = req.body;
  await pool.query('UPDATE expenses SET date=?, amount=?, category=?, vendor_id=?, notes=? WHERE id=?', [date, amount, category, vendor_id, notes, req.params.id]);
  res.json({ message: 'Expense updated' });
});
router.delete('/accounting/expenses/:id', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  await pool.query('DELETE FROM expenses WHERE id=?', [req.params.id]);
  res.json({ message: 'Expense deleted' });
});

// Accounts Payable CRUD
router.get('/accounting/payables', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  let query = 'SELECT ap.*, v.name as vendor_name FROM accounts_payable ap JOIN vendors v ON ap.vendor_id = v.id WHERE ap.business_id = ? ORDER BY due_date';
  let params = [req.user.business_id];
  if (req.user.role === 'superadmin') {
    query = 'SELECT ap.*, v.name as vendor_name FROM accounts_payable ap JOIN vendors v ON ap.vendor_id = v.id ORDER BY due_date';
    params = [];
  }
  const [payables] = await pool.query(query, params);
  res.json(payables);
});
router.post('/accounting/payables', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  const { vendor_id, amount, due_date, status, notes } = req.body;
  const businessId = req.user.business_id;
  await pool.query('INSERT INTO accounts_payable (vendor_id, amount, due_date, status, notes, business_id) VALUES (?, ?, ?, ?, ?, ?)', [vendor_id, amount, due_date, status, notes, businessId]);
  res.json({ message: 'Payable added' });
});
router.put('/accounting/payables/:id', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  const { vendor_id, amount, due_date, status, notes } = req.body;
  await pool.query('UPDATE accounts_payable SET vendor_id=?, amount=?, due_date=?, status=?, notes=? WHERE id=?', [vendor_id, amount, due_date, status, notes, req.params.id]);
  res.json({ message: 'Payable updated' });
});
router.delete('/accounting/payables/:id', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  await pool.query('DELETE FROM accounts_payable WHERE id=?', [req.params.id]);
  res.json({ message: 'Payable deleted' });
});

// Cash Flows CRUD
router.get('/accounting/cash-flows', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  let query = 'SELECT * FROM cash_flows WHERE business_id = ? ORDER BY date DESC';
  let params = [req.user.business_id];
  if (req.user.role === 'superadmin') {
    query = 'SELECT * FROM cash_flows ORDER BY date DESC';
    params = [];
  }
  const [flows] = await pool.query(query, params);
  res.json(flows);
});
router.post('/accounting/cash-flows', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  const { type, amount, date, reference, notes } = req.body;
  const businessId = req.user.business_id;
  await pool.query('INSERT INTO cash_flows (type, amount, date, reference, notes, business_id) VALUES (?, ?, ?, ?, ?, ?)', [type, amount, date, reference, notes, businessId]);
  res.json({ message: 'Cash flow entry added' });
});

// Reports: Profit & Loss, Balance Sheet, General Ledger, Cash Flow
router.get('/accounting/profit-loss', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  try {
    console.log('PROFIT-LOSS: Calculating profit for user business_id =', req.user.business_id);
    
    // Calculate total sales revenue (including credit sales)
    let salesQuery = 'SELECT SUM(total_amount) as total_revenue FROM sales WHERE (status = "completed" OR payment_method = "credit")';
    let salesParams = [];
    if (req.user.role !== 'superadmin' && req.user.business_id) {
      salesQuery += ' AND business_id = ?';
      salesParams.push(req.user.business_id);
    }
    const [sales] = await pool.query(salesQuery, salesParams);
    const total_revenue = sales[0]?.total_revenue || 0;
    
    // Calculate total cost of goods sold (COGS)
    let cogsQuery = `
      SELECT SUM(si.quantity * p.cost_price) as total_cost 
      FROM sale_items si 
      JOIN products p ON si.product_id = p.id 
      JOIN sales s ON si.sale_id = s.id 
      WHERE (s.status = "completed" OR s.payment_method = "credit")
    `;
    let cogsParams = [];
    if (req.user.role !== 'superadmin' && req.user.business_id) {
      cogsQuery += ' AND s.business_id = ?';
      cogsParams.push(req.user.business_id);
    }
    const [cogs] = await pool.query(cogsQuery, cogsParams);
    const total_cost = cogs[0]?.total_cost || 0;
    
    // Calculate total expenses
    let expensesQuery = 'SELECT SUM(amount) as total_expenses FROM expenses';
    let expensesParams = [];
    if (req.user.role !== 'superadmin' && req.user.business_id) {
      expensesQuery += ' WHERE business_id = ?';
      expensesParams.push(req.user.business_id);
    }
    const [expenses] = await pool.query(expensesQuery, expensesParams);
    const total_expenses = expenses[0]?.total_expenses || 0;
    
    // Calculate profit: Revenue - COGS - Expenses
    const gross_profit = total_revenue - total_cost;
    const net_profit = gross_profit - total_expenses;
    
    console.log('PROFIT-LOSS: Results:');
    console.log('  - Total Revenue:', total_revenue);
    console.log('  - Total COGS:', total_cost);
    console.log('  - Gross Profit:', gross_profit);
    console.log('  - Total Expenses:', total_expenses);
    console.log('  - Net Profit:', net_profit);
    
    res.json({ 
      total_income: total_revenue, 
      total_expenses: total_expenses,
      total_cost: total_cost,
      gross_profit: gross_profit,
      net_profit: net_profit 
    });
  } catch (error) {
    console.error('PROFIT-LOSS Error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

router.get('/accounting/balance-sheet', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  let salesQuery = 'SELECT SUM(total_amount) as total_sales FROM sales WHERE (status = "completed" OR payment_method = "credit")';
  let creditsQuery = 'SELECT SUM(total_amount) as total_credit FROM sales WHERE payment_method = "credit"';
  let expensesQuery = 'SELECT SUM(amount) as total_expenses FROM expenses';
  let payablesQuery = 'SELECT SUM(amount) as total_payables FROM accounts_payable WHERE status != "paid"';
  let salesParams = [];
  let creditsParams = [];
  let expensesParams = [];
  let payablesParams = [];
  if (req.user.role !== 'superadmin' && req.user.business_id) {
    salesQuery += ' AND business_id = ?';
    creditsQuery += ' AND business_id = ?';
    expensesQuery += ' WHERE business_id = ?';
    payablesQuery += ' AND business_id = ?';
    salesParams.push(req.user.business_id);
    creditsParams.push(req.user.business_id);
    expensesParams.push(req.user.business_id);
    payablesParams.push(req.user.business_id);
  }
  const [sales] = await pool.query(salesQuery, salesParams);
  const [credits] = await pool.query(creditsQuery, creditsParams);
  const [expenses] = await pool.query(expensesQuery, expensesParams);
  const [payables] = await pool.query(payablesQuery, payablesParams);
  const cash = (sales[0].total_sales || 0) - (credits[0].total_credit || 0) - (expenses[0].total_expenses || 0);
  const receivables = credits[0].total_credit || 0;
  const liabilities = payables[0].total_payables || 0;
  res.json({ cash, receivables, liabilities });
});

router.get('/accounting/general-ledger', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  let salesQuery = 'SELECT id, created_at as date, "sale" as type, total_amount as amount, "income" as category, NULL as vendor, NULL as notes FROM sales';
  let expensesQuery = 'SELECT id, date, "expense" as type, amount, category, vendor_id as vendor, notes FROM expenses';
  let payablesQuery = 'SELECT id, due_date as date, "payable" as type, amount, "accounts_payable" as category, vendor_id as vendor, notes FROM accounts_payable';
  let cashFlowsQuery = 'SELECT id, date, type, amount, reference as category, NULL as vendor, notes FROM cash_flows';
  let salesParams = [];
  let expensesParams = [];
  let payablesParams = [];
  let cashFlowsParams = [];
  if (req.user.role !== 'superadmin' && req.user.business_id) {
    salesQuery += ' WHERE business_id = ?';
    expensesQuery += ' WHERE business_id = ?';
    payablesQuery += ' WHERE business_id = ?';
    cashFlowsQuery += ' WHERE business_id = ?';
    salesParams.push(req.user.business_id);
    expensesParams.push(req.user.business_id);
    payablesParams.push(req.user.business_id);
    cashFlowsParams.push(req.user.business_id);
  }
  const [sales] = await pool.query(salesQuery, salesParams);
  const [expenses] = await pool.query(expensesQuery, expensesParams);
  const [payables] = await pool.query(payablesQuery, payablesParams);
  const [cashFlows] = await pool.query(cashFlowsQuery, cashFlowsParams);
  const ledger = [...sales, ...expenses, ...payables, ...cashFlows].sort((a, b) => new Date(a.date) - new Date(b.date));
  res.json(ledger);
});

router.get('/accounting/cash-flow-report', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  let inflowsQuery = 'SELECT SUM(amount) as total_inflow FROM cash_flows WHERE type = "in"';
  let outflowsQuery = 'SELECT SUM(amount) as total_outflow FROM cash_flows WHERE type = "out"';
  let inflowsParams = [];
  let outflowsParams = [];
  if (req.user.role !== 'superadmin' && req.user.business_id) {
    inflowsQuery += ' AND business_id = ?';
    outflowsQuery += ' AND business_id = ?';
    inflowsParams.push(req.user.business_id);
    outflowsParams.push(req.user.business_id);
  }
  const [inflows] = await pool.query(inflowsQuery, inflowsParams);
  const [outflows] = await pool.query(outflowsQuery, outflowsParams);
  res.json({ total_inflow: inflows[0].total_inflow || 0, total_outflow: outflows[0].total_outflow || 0 });
});

// --- ADVANCED REPORTS (QuickBooks-style) ---

// Profit by Product
router.get('/accounting/reports/product-profit', [auth, checkRole(['admin'])], async (req, res) => {
  const { start_date, end_date } = req.query;
  let where = '';
  const params = [];
  if (req.user.role !== 'superadmin' && req.user.business_id) {
    where += ' AND s.business_id = ?';
    params.push(req.user.business_id);
  }
  if (start_date) { where += ' AND s.created_at >= ?'; params.push(start_date); }
  if (end_date) { where += ' AND s.created_at <= ?'; params.push(end_date); }
  const [rows] = await pool.query(`
    SELECT p.id, p.name,
      SUM(si.quantity) as units_sold,
      SUM(si.total_price) as revenue,
      SUM(si.quantity * p.cost_price) as cost,
      SUM(si.total_price - si.quantity * p.cost_price) as profit
    FROM sale_items si
    JOIN products p ON si.product_id = p.id
    JOIN sales s ON si.sale_id = s.id
    WHERE s.status = 'completed' ${where}
    GROUP BY p.id, p.name
    ORDER BY profit DESC
  `, params);
  res.json(rows);
});

// Profit by Period (day/week/month)
router.get('/accounting/reports/period-profit', [auth, checkRole(['admin'])], async (req, res) => {
  const { start_date, end_date, group_by = 'day' } = req.query;
  let where = '';
  const params = [];
  if (req.user.role !== 'superadmin' && req.user.business_id) {
    where += ' AND s.business_id = ?';
    params.push(req.user.business_id);
  }
  if (start_date) { where += ' AND s.created_at >= ?'; params.push(start_date); }
  if (end_date) { where += ' AND s.created_at <= ?'; params.push(end_date); }
  let periodExpr = `DATE(s.created_at)`;
  if (group_by === 'week') periodExpr = `YEARWEEK(s.created_at)`;
  if (group_by === 'month') periodExpr = `DATE_FORMAT(s.created_at, '%Y-%m')`;
  const [rows] = await pool.query(`
    SELECT ${periodExpr} as period,
      SUM(s.total_amount) as sales,
      SUM(si.total_price - si.quantity * p.cost_price) as profit,
      (SELECT SUM(amount) FROM expenses e WHERE e.date = DATE(s.created_at)${req.user.role !== 'superadmin' && req.user.business_id ? ' AND e.business_id = ?' : ''}) as expenses
    FROM sales s
    JOIN sale_items si ON si.sale_id = s.id
    JOIN products p ON si.product_id = p.id
    WHERE s.status = 'completed' ${where}
    GROUP BY period
    ORDER BY period DESC
  `, req.user.role !== 'superadmin' && req.user.business_id ? [...params, req.user.business_id] : params);
  res.json(rows);
});

// Top Products
router.get('/accounting/reports/top-products', [auth, checkRole(['admin'])], async (req, res) => {
  const { start_date, end_date, limit = 10 } = req.query;
  let where = '';
  const params = [];
  if (req.user.role !== 'superadmin' && req.user.business_id) {
    where += ' AND s.business_id = ?';
    params.push(req.user.business_id);
  }
  if (start_date) { where += ' AND s.created_at >= ?'; params.push(start_date); }
  if (end_date) { where += ' AND s.created_at <= ?'; params.push(end_date); }
  const [rows] = await pool.query(`
    SELECT p.id, p.name, SUM(si.quantity) as units_sold, SUM(si.total_price) as revenue, SUM(si.total_price - si.quantity * p.cost_price) as profit
    FROM sale_items si
    JOIN products p ON si.product_id = p.id
    JOIN sales s ON si.sale_id = s.id
    WHERE s.status = 'completed' ${where}
    GROUP BY p.id, p.name
    ORDER BY revenue DESC
    LIMIT ?
  `, [...params, Number(limit)]);
  res.json(rows);
});

// Detailed Transactions
router.get('/accounting/reports/transactions', [auth, checkRole(['admin'])], async (req, res) => {
  const { start_date, end_date, product_id, customer_id, vendor_id, type } = req.query;
  let where = '';
  const params = [];
  if (req.user.role !== 'superadmin' && req.user.business_id) {
    where += ' AND t.business_id = ?';
    params.push(req.user.business_id);
  }
  if (start_date) { where += ' AND t.date >= ?'; params.push(start_date); }
  if (end_date) { where += ' AND t.date <= ?'; params.push(end_date); }
  if (product_id) { where += ' AND t.product_id = ?'; params.push(product_id); }
  if (customer_id) { where += ' AND t.customer_id = ?'; params.push(customer_id); }
  if (vendor_id) { where += ' AND t.vendor_id = ?'; params.push(vendor_id); }
  if (type) { where += ' AND t.type = ?'; params.push(type); }
  // Union sales, expenses, payables, cash flows
  const [rows] = await pool.query(`
    SELECT * FROM (
      SELECT s.created_at as date, 'sale' as type, s.id as ref_id, c.name as customer, NULL as vendor, si.product_id, p.name as product, si.quantity, si.total_price as amount, (si.total_price - si.quantity * p.cost_price) as profit, s.business_id
      FROM sales s
      JOIN sale_items si ON si.sale_id = s.id
      JOIN products p ON si.product_id = p.id
      LEFT JOIN customers c ON s.customer_id = c.id
      WHERE s.status = 'completed'${req.user.role !== 'superadmin' && req.user.business_id ? ' AND s.business_id = ?' : ''}
      UNION ALL
      SELECT e.date as date, 'expense' as type, e.id as ref_id, NULL as customer, v.name as vendor, NULL as product_id, NULL as product, NULL as quantity, e.amount as amount, NULL as profit, e.business_id
      FROM expenses e
      LEFT JOIN vendors v ON e.vendor_id = v.id
      ${req.user.role !== 'superadmin' && req.user.business_id ? 'WHERE e.business_id = ?' : ''}
      UNION ALL
      SELECT ap.due_date as date, 'payable' as type, ap.id as ref_id, NULL as customer, v.name as vendor, NULL as product_id, NULL as product, NULL as quantity, ap.amount as amount, NULL as profit, ap.business_id
      FROM accounts_payable ap
      LEFT JOIN vendors v ON ap.vendor_id = v.id
      ${req.user.role !== 'superadmin' && req.user.business_id ? 'WHERE ap.business_id = ?' : ''}
      UNION ALL
      SELECT cf.date as date, cf.type as type, cf.id as ref_id, NULL as customer, NULL as vendor, NULL as product_id, NULL as product, NULL as quantity, cf.amount as amount, NULL as profit, cf.business_id
      FROM cash_flows cf
      ${req.user.role !== 'superadmin' && req.user.business_id ? 'WHERE cf.business_id = ?' : ''}
    ) t
    WHERE 1=1 ${where}
    ORDER BY t.date DESC
    LIMIT 1000
  `, [...(req.user.role !== 'superadmin' && req.user.business_id ? [req.user.business_id, req.user.business_id, req.user.business_id, req.user.business_id] : []), ...params]);
  res.json(rows);
});

// Get detailed revenue analytics with date filtering
router.get('/revenue-analytics', auth, superadminOnly, async (req, res) => {
  try {
    const { start_date, end_date } = req.query;
    
    // Build date filter
    let dateFilter = '';
    let params = [];
    
    if (start_date && end_date) {
      dateFilter = 'WHERE b.created_at BETWEEN ? AND ?';
      params = [start_date, end_date];
    }
    
    // Get businesses with revenue data
    const [businesses] = await pool.query(`
      SELECT 
        b.id,
        b.name,
        b.subscription_plan,
        COALESCE(sp.monthly_fee, b.monthly_fee, 29.99) as monthly_fee,
        b.payment_status,
        b.created_at,
        COALESCE(SUM(mb.user_overage_fee), 0) as user_overage_fee,
        COALESCE(SUM(mb.product_overage_fee), 0) as product_overage_fee,
        COUNT(DISTINCT u.id) as user_count,
        COUNT(DISTINCT p.id) as product_count
      FROM businesses b
      LEFT JOIN subscription_plans sp ON b.subscription_plan = sp.plan_name
      LEFT JOIN users u ON b.id = u.business_id
      LEFT JOIN products p ON b.id = p.business_id
      LEFT JOIN monthly_bills mb ON b.id = mb.business_id
      ${dateFilter}
      GROUP BY b.id, b.name, b.subscription_plan, sp.monthly_fee, b.monthly_fee, b.payment_status, b.created_at
      ORDER BY COALESCE(sp.monthly_fee, b.monthly_fee, 29.99) DESC
    `, params);

    // Calculate revenue metrics
    let totalRevenue = 0;
    let basicRevenue = 0;
    let premiumRevenue = 0;
    let enterpriseRevenue = 0;
    let overdueCount = 0;
    let currentCount = 0;

    const businessRevenues = businesses.map(business => {
      const monthlyFee = parseFloat(business.monthly_fee) || 0;
      const userOverage = parseFloat(business.user_overage_fee) || 0;
      const productOverage = parseFloat(business.product_overage_fee) || 0;
      const overageFees = userOverage + productOverage;
      const businessTotalRevenue = monthlyFee + overageFees;

      totalRevenue += businessTotalRevenue;

      switch (business.subscription_plan) {
        case 'basic':
          basicRevenue += businessTotalRevenue;
          break;
        case 'premium':
          premiumRevenue += businessTotalRevenue;
          break;
        case 'enterprise':
          enterpriseRevenue += businessTotalRevenue;
          break;
      }

      if (business.payment_status === 'overdue') {
        overdueCount++;
      } else {
        currentCount++;
      }

      return {
        business_id: business.id,
        business_name: business.name,
        subscription_plan: business.subscription_plan,
        monthly_fee: monthlyFee,
        overage_fees: overageFees,
        total_revenue: businessTotalRevenue,
        payment_status: business.payment_status,
        created_at: business.created_at,
        user_count: business.user_count,
        product_count: business.product_count,
      };
    });

    // Get monthly revenue trend from actual bills
    const [monthlyRevenue] = await pool.query(`
      SELECT 
        DATE_FORMAT(mb.billing_month, '%Y-%m') as month,
        SUM(mb.total_amount) as revenue
      FROM monthly_bills mb
      ${dateFilter ? 'WHERE mb.billing_month BETWEEN ? AND ?' : ''}
      GROUP BY DATE_FORMAT(mb.billing_month, '%Y-%m')
      ORDER BY month DESC
      LIMIT 12
    `, dateFilter ? params : []);

    res.json({
      revenue_stats: {
        total_revenue: totalRevenue,
        basic_revenue: basicRevenue,
        premium_revenue: premiumRevenue,
        enterprise_revenue: enterpriseRevenue,
      },
      payment_status: {
        overdue: overdueCount,
        current: currentCount,
      },
      business_revenues: businessRevenues,
      monthly_revenue: monthlyRevenue,
      date_range: {
        start_date: start_date || null,
        end_date: end_date || null,
      }
    });

  } catch (error) {
    console.error('Error fetching revenue analytics:', error);
    console.error('Error details:', error.message);
    console.error('Error stack:', error.stack);
    res.status(500).json({ 
      message: 'Server error', 
      error: error.message,
      details: 'Check server logs for more information'
    });
  }
});

// --- ACCOUNTING SECTION END ---

module.exports = router;