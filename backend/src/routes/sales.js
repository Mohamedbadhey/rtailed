const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { auth, checkRole } = require('../middleware/auth');
const { executeQueryWithRelaxedGroupBy } = require('../utils/databaseUtils');

// Get all sales
router.get('/', auth, async (req, res) => {
  try {
    let query = 'SELECT * FROM sales WHERE business_id = ? ORDER BY created_at DESC';
    let params = [req.user.business_id];
    if (req.user.role === 'superadmin') {
      query = 'SELECT * FROM sales ORDER BY created_at DESC';
      params = [];
    }
    const [sales] = await pool.query(query, params);
    res.json(sales);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Create new sale
router.post('/', auth, async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const {
      customer_id,
      items,
      payment_method,
      tax_rate = 0.1, // Default 10% tax rate
      customer_phone, // Optionally sent from frontend
      sale_mode // 'retail' or 'wholesale'
    } = req.body;

    // Validate credit sales
    if (payment_method === 'credit') {
      if (!customer_id) {
        throw new Error('Customer must be selected for credit sales');
      }
      // Fetch customer and check phone
      const [customerRows] = await connection.query('SELECT phone FROM customers WHERE id = ?', [customer_id]);
      let phone = customer_phone;
      if (customerRows.length > 0) {
        phone = customerRows[0].phone || phone;
      }
      if (!phone || phone.trim() === '') {
        throw new Error('Customer phone number is required for credit sales');
      }
      // Optionally update phone if provided
      if (customerRows.length > 0 && customer_phone && customerRows[0].phone !== customer_phone) {
        await connection.query('UPDATE customers SET phone = ? WHERE id = ?', [customer_phone, customer_id]);
      }
    }

    // Validate stock for each item
    for (const item of items) {
      const [productRows] = await connection.query('SELECT stock_quantity FROM products WHERE id = ?', [item.product_id]);
      if (!productRows.length) {
        throw new Error(`Product with ID ${item.product_id} not found`);
      }
      const availableStock = productRows[0].stock_quantity;
      if (item.quantity > availableStock) {
        throw new Error(`Insufficient stock for product ID ${item.product_id}. Available: ${availableStock}, requested: ${item.quantity}`);
      }
    }

    // Calculate totals
    let totalAmount = items.reduce((sum, item) => sum + (item.unit_price * item.quantity), 0);

    // Debug log for sale insert
    console.log('Creating sale with:', {
      customer_id,
      user_id: req.user.id,
      total_amount: totalAmount,
      payment_method,
      status: 'completed'
    });

    // Create sale record
    let saleStatus = 'completed';
    if (payment_method === 'credit') {
      saleStatus = 'unpaid';
    }
    const businessId = req.user.business_id;
    const [saleResult] = await connection.query(
      `INSERT INTO sales (
        customer_id, user_id, total_amount, tax_amount,
        payment_method, status, sale_mode, business_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [customer_id, req.user.id, totalAmount, 0.00, payment_method, saleStatus, sale_mode || 'retail', businessId]
    );

    const sale_id = saleResult.insertId;

    // Create sale items and update inventory
    for (const item of items) {
      const [product] = await connection.query(
        'SELECT cost_price FROM products WHERE id = ?',
        [item.product_id]
      );

      // Add sale item
      await connection.query(
        `INSERT INTO sale_items (
          sale_id, product_id, quantity, unit_price, total_price, mode, business_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          sale_id,
          item.product_id,
          item.quantity,
          item.unit_price,
          item.unit_price * item.quantity,
          item.mode || 'retail',
          businessId
        ]
      );

      // NOTE: Stock quantity is automatically updated by database trigger after_sale_item_insert
      // No need for manual UPDATE here to avoid double deduction

      // Add inventory transaction
      await connection.query(
        `INSERT INTO inventory_transactions (
          product_id, quantity, transaction_type, reference_id, notes, business_id
        ) VALUES (?, ?, ?, ?, ?, ?)`,
        [
          item.product_id,
          -item.quantity,
          'sale',
          sale_id,
          'Sale transaction',
          businessId
        ]
      );
    }

    // Update customer loyalty points if customer exists
    if (customer_id) {
      const points = Math.floor(totalAmount); // 1 point per currency unit
      await connection.query(
        'UPDATE customers SET loyalty_points = loyalty_points + ? WHERE id = ?',
        [points, customer_id]
      );
    }

    await connection.commit();

    res.status(201).json({
      message: 'Sale completed successfully',
      sale_id,
      total_amount: totalAmount
    });
  } catch (error) {
    await connection.rollback();
    console.error(error);
    res.status(500).json({ message: error.message || 'Server error' });
  } finally {
    connection.release();
  }
});

// Get sales report
router.get('/report', auth, async (req, res) => {
  try {
    const { start_date, end_date, group_by = 'day', user_id } = req.query;
    const isCashier = req.user.role === 'cashier';
    console.log('SALES REPORT: user_id param =', user_id, 'isCashier =', isCashier, 'req.user.id =', req.user.id);
    
    // Build the WHERE clause - include both completed sales and credit sales (unpaid) but EXCLUDE credit payments
    // Credit payments have parent_sale_id IS NOT NULL and should not be counted as revenue
    let whereClause = 'WHERE (s.status = "completed" OR s.payment_method = "credit") AND s.parent_sale_id IS NULL';
    const params = [];
    
    // Add business_id filter unless superadmin
    if (req.user.role !== 'superadmin') {
      if (!req.user.business_id) {
        return res.status(400).json({ message: 'Business ID is required for this report.' });
      }
      whereClause += ' AND s.business_id = ?';
      params.push(req.user.business_id);
    }
    
    if (isCashier) {
      whereClause += ' AND s.user_id = ?';
      params.push(req.user.id);
    } else if (user_id) {
      whereClause += ' AND s.user_id = ?';
      params.push(user_id);
    }
    
    // Add date filters
    if (start_date) {
      whereClause += ' AND DATE(s.created_at) >= ?';
      params.push(start_date);
    }
    if (end_date) {
      whereClause += ' AND DATE(s.created_at) <= ?';
      params.push(end_date);
    }
    
    console.log('SALES REPORT: whereClause =', whereClause, 'params =', params);
    console.log('SALES REPORT: Date filters - start_date:', start_date, 'end_date:', end_date);
    
    // Debug: Check what sales exist for this business
    if (req.user.role !== 'superadmin' && req.user.business_id) {
      const [debugSales] = await pool.query(
        'SELECT id, total_amount, status, business_id, created_at, parent_sale_id, payment_method FROM sales WHERE business_id = ? ORDER BY created_at DESC LIMIT 10',
        [req.user.business_id]
      );
      console.log('SALES REPORT: Found', debugSales.length, 'sales for business_id', req.user.business_id, ':', debugSales);
    }

    // All queries below use whereClause and params
    // Date check
    const [dateCheck] = await pool.query(
      `SELECT COUNT(*) as total_sales_in_range, MIN(s.created_at) as earliest_date, MAX(s.created_at) as latest_date FROM sales s ${whereClause}`,
      params
    );
    
    // Sales by period - use a completely different approach to avoid parameter confusion
    const dateFormat = group_by === 'day' ? '%Y-%m-%d' : group_by === 'week' ? '%Y-%u' : '%Y-%m';
    
    // Build the query string directly with values instead of parameters to avoid confusion
    let salesByPeriodQuery = `SELECT DATE_FORMAT(s.created_at, '${dateFormat}') as period, COUNT(*) as total_sales, SUM(s.total_amount) as total_revenue, AVG(s.total_amount) as average_sale FROM sales s WHERE (s.status = "completed" OR s.payment_method = "credit") AND s.parent_sale_id IS NULL`;
    const salesByPeriodParams = [];
    
    // Add business_id filter unless superadmin
    if (req.user.role !== 'superadmin') {
      if (!req.user.business_id) {
        return res.status(400).json({ message: 'Business ID is required for this report.' });
      }
      salesByPeriodQuery += ` AND s.business_id = ${req.user.business_id}`;
    }
    
    // Add user_id filter
    if (isCashier) {
      salesByPeriodQuery += ` AND s.user_id = ${req.user.id}`;
    } else if (user_id) {
      salesByPeriodQuery += ` AND s.user_id = ${user_id}`;
    }
    
    // Add date filters
    if (start_date) {
      salesByPeriodQuery += ` AND DATE(s.created_at) >= '${start_date}'`;
    }
    if (end_date) {
      salesByPeriodQuery += ` AND DATE(s.created_at) <= '${end_date}'`;
    }
    
    salesByPeriodQuery += ` GROUP BY DATE_FORMAT(s.created_at, '${dateFormat}') ORDER BY period DESC`;
    
    console.log('SALES REPORT: Sales by period query:', salesByPeriodQuery);
    console.log('SALES REPORT: Sales by period params:', salesByPeriodParams);
    console.log('SALES REPORT: salesByPeriodWhereClause:', salesByPeriodWhereClause);
    console.log('SALES REPORT: req.user.business_id:', req.user.business_id);
    console.log('SALES REPORT: user_id param:', user_id);
    console.log('SALES REPORT: start_date:', start_date);
    console.log('SALES REPORT: end_date:', end_date);
    
    let salesByPeriod;
    try {
      // Try the normal query first - no parameters needed now
      console.log('SALES REPORT: Executing query without params:', salesByPeriodQuery);
      [salesByPeriod] = await pool.query(salesByPeriodQuery);
      console.log('SALES REPORT: Query executed successfully, result:', salesByPeriod);
    } catch (error) {
      console.log('SALES REPORT: Query failed with error:', error.message);
      console.log('SALES REPORT: Error code:', error.code);
      if (error.code === 'ER_WRONG_FIELD_WITH_GROUP') {
        console.log('⚠️  GROUP BY error detected, using relaxed mode...');
        // Fallback to relaxed GROUP BY mode
        salesByPeriod = await executeQueryWithRelaxedGroupBy(salesByPeriodQuery, []);
      } else {
        throw error;
      }
    }
    
    // Payment methods - exclude credit payments from this calculation
    const [paymentMethods] = await pool.query(
      `SELECT s.payment_method, COUNT(*) as count, SUM(s.total_amount) as total_amount FROM sales s ${whereClause} GROUP BY s.payment_method ORDER BY total_amount DESC`,
      params
    );
    
    // Customer insights - exclude credit payments
    const [customerInsights] = await pool.query(
      `SELECT COUNT(DISTINCT s.customer_id) as unique_customers, COUNT(*) as total_transactions, AVG(s.total_amount) as average_customer_spend FROM sales s ${whereClause} AND s.customer_id IS NOT NULL`,
      params
    );
    
    // Summary statistics - exclude credit payments from revenue calculation
    console.log('SALES REPORT: Running summary query with whereClause =', whereClause, 'params =', params);
    const [summary] = await pool.query(
      `SELECT COUNT(*) as total_orders, SUM(s.total_amount) as total_revenue, AVG(s.total_amount) as average_order_value, MIN(s.total_amount) as min_order, MAX(s.total_amount) as max_order FROM sales s ${whereClause}`,
      params
    );
    console.log('SALES REPORT: Summary result =', summary[0]);
    
    // Credit sales summary - only original credit sales, not payments
    const [creditSummary] = await pool.query(
      `SELECT COUNT(*) as total_credit_sales, SUM(s.total_amount) as total_credit_amount, COUNT(DISTINCT s.customer_id) as unique_credit_customers FROM sales s ${whereClause} AND s.payment_method = 'credit'`,
      params
    );
    
    // Product breakdown - exclude credit payments
    console.log('SALES REPORT: Running product breakdown query with whereClause =', whereClause, 'params =', params);
    const [productBreakdown] = await pool.query(
      `SELECT p.id, p.name, SUM(si.quantity) as quantity_sold, SUM(si.total_price) as revenue, SUM(si.total_price - (si.quantity * p.cost_price)) as profit FROM sale_items si JOIN products p ON si.product_id = p.id JOIN sales s ON si.sale_id = s.id ${whereClause} GROUP BY p.id, p.name ORDER BY revenue DESC`,
      params
    );
    console.log('SALES REPORT: Product breakdown result =', productBreakdown);
    
    // Calculate total cost of goods sold (COGS) for profit calculation - exclude credit payments
    let cogsQuery = `
      SELECT SUM(si.quantity * p.cost_price) as total_cost 
      FROM sale_items si 
      JOIN products p ON si.product_id = p.id 
      JOIN sales s ON si.sale_id = s.id 
      WHERE (s.status = "completed" OR s.payment_method = "credit") AND s.parent_sale_id IS NULL
    `;
    let cogsParams = [];
    if (req.user.role !== 'superadmin') {
      if (!req.user.business_id) {
        return res.status(400).json({ message: 'Business ID is required for this report.' });
      }
      cogsQuery += ' AND s.business_id = ?';
      cogsParams.push(req.user.business_id);
    }
    if (isCashier) {
      cogsQuery += ' AND s.user_id = ?';
      cogsParams.push(req.user.id);
    } else if (user_id) {
      cogsQuery += ' AND s.user_id = ?';
      cogsParams.push(user_id);
    }
    
    // Add date filters to COGS query
    if (start_date) {
      cogsQuery += ' AND DATE(s.created_at) >= ?';
      cogsParams.push(start_date);
    }
    if (end_date) {
      cogsQuery += ' AND DATE(s.created_at) <= ?';
      cogsParams.push(end_date);
    }
    const [cogs] = await pool.query(cogsQuery, cogsParams);
    const total_cost = cogs[0]?.total_cost || 0;
    
    // Net revenue (total - credit) - this calculation is now correct since we excluded payments
    const netRevenue = (summary[0]?.total_revenue || 0) - (creditSummary[0]?.total_credit_amount || 0);
    const totalProductsSold = productBreakdown.reduce((sum, p) => sum + (p.quantity_sold || 0), 0);
    
    // Calculate profit using the same logic as Profit & Loss: Revenue - COGS
    const totalRevenue = summary[0]?.total_revenue || 0;
    const totalProfit = totalRevenue - total_cost;
    
    console.log('SALES REPORT: Profit calculation:');
    console.log('  - Total Revenue:', totalRevenue);
    console.log('  - Total COGS:', total_cost);
    console.log('  - Calculated totalProfit:', totalProfit);
    
    // Outstanding credits - this query is already correct as it only looks at original credit sales
    let outstandingCreditsQuery = `SELECT SUM(orig.total_amount - IFNULL(pay.paid,0)) as total_outstanding_credit FROM sales orig LEFT JOIN (SELECT parent_sale_id, SUM(total_amount) as paid FROM sales WHERE parent_sale_id IS NOT NULL GROUP BY parent_sale_id) pay ON pay.parent_sale_id = orig.id WHERE orig.payment_method = 'credit' AND orig.parent_sale_id IS NULL AND (orig.status != 'paid' OR orig.status IS NULL)`;
    let outstandingCreditsParams = [];
    
    // Add business_id filter unless superadmin
    if (req.user.role !== 'superadmin') {
      if (!req.user.business_id) {
        return res.status(400).json({ message: 'Business ID is required for this report.' });
      }
      outstandingCreditsQuery += ' AND orig.business_id = ?';
      outstandingCreditsParams.push(req.user.business_id);
    }
    
    // Add user filter for cashiers
    if (isCashier || user_id) {
      outstandingCreditsQuery += ' AND orig.user_id = ?';
      outstandingCreditsParams.push(isCashier ? req.user.id : user_id);
    }
    
    // Add date filters
    if (start_date) {
      outstandingCreditsQuery += ' AND orig.created_at >= ?';
      outstandingCreditsParams.push(start_date);
    }
    if (end_date) {
      outstandingCreditsQuery += ' AND orig.created_at <= ?';
      outstandingCreditsParams.push(end_date);
    }
    
    const [outstandingCredits] = await pool.query(outstandingCreditsQuery, outstandingCreditsParams);
    
    // Prepare safe response data
    const safeSummary = {
      total_orders: Number(summary[0]?.total_orders) || 0,
      total_revenue: Number(summary[0]?.total_revenue) || 0,
      average_order_value: Number(summary[0]?.average_order_value) || 0,
      min_order: Number(summary[0]?.min_order) || 0,
      max_order: Number(summary[0]?.max_order) || 0,
    };
    
    const safeCreditSummary = {
      total_credit_sales: Number(creditSummary[0]?.total_credit_sales) || 0,
      total_credit_amount: Number(creditSummary[0]?.total_credit_amount) || 0,
      unique_credit_customers: Number(creditSummary[0]?.unique_credit_customers) || 0,
    };
    
    const safeCustomerInsights = {
      unique_customers: Number(customerInsights[0]?.unique_customers) || 0,
      total_transactions: Number(customerInsights[0]?.total_transactions) || 0,
      average_customer_spend: Number(customerInsights[0]?.average_customer_spend) || 0,
    };
    
    const safeProductBreakdown = Array.isArray(productBreakdown) ? productBreakdown.map(p => ({
      id: p.id,
      name: p.name,
      quantity_sold: Number(p.quantity_sold) || 0,
      revenue: Number(p.revenue) || 0,
    })) : [];
    
    const safeSalesByPeriod = Array.isArray(salesByPeriod) ? salesByPeriod : [];
    const safePaymentMethods = Array.isArray(paymentMethods) ? paymentMethods.map(m => ({
      payment_method: m.payment_method,
      count: Number(m.count) || 0,
      total_amount: Number(m.total_amount) || 0,
    })) : [];
    
    const safeNetRevenue = Number(netRevenue) || 0;
    const safeTotalProductsSold = Number(totalProductsSold) || 0;
    const safeTotalProfit = Number(totalProfit) || 0;

    console.log('SALES REPORT: Final response values:');
    console.log('  - totalSales (safeSummary.total_revenue):', safeSummary.total_revenue);
    console.log('  - totalProfit:', safeTotalProfit);
    console.log('  - outstandingCredits:', Number(outstandingCredits[0]?.total_outstanding_credit) || 0);

    res.json({
      summary: safeSummary,
      salesByPeriod: safeSalesByPeriod,
      paymentMethods: safePaymentMethods,
      customerInsights: safeCustomerInsights,
      creditSummary: safeCreditSummary,
      productBreakdown: safeProductBreakdown,
      netRevenue: safeNetRevenue,
      totalProductsSold: safeTotalProductsSold,
      totalProfit: safeTotalProfit,
      period: {
        start_date,
        end_date,
        group_by
      },
      // New fields for dashboard
      totalSales: safeSummary.total_revenue,
      totalOrders: safeSummary.total_orders,
      cashInHand: safeNetRevenue,
      outstandingCredits: Number(outstandingCredits[0]?.total_outstanding_credit) || 0,
      paymentMethodBreakdown: safePaymentMethods,
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get top selling products
router.get('/top-products', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  try {
    const { start_date, end_date, limit = 10 } = req.query;

    const [products] = await pool.query(
      `SELECT 
        p.id,
        p.name,
        SUM(si.quantity) as total_quantity,
        SUM(si.total_price) as total_revenue
      FROM sale_items si
      JOIN products p ON si.product_id = p.id
      JOIN sales s ON si.sale_id = s.id
      WHERE s.status = 'completed' AND s.parent_sale_id IS NULL
      ${start_date ? 'AND s.created_at >= ?' : ''}
      ${end_date ? 'AND s.created_at <= ?' : ''}
      GROUP BY p.id, p.name
      ORDER BY total_quantity DESC
      LIMIT ?`,
      [
        ...(start_date ? [start_date] : []),
        ...(end_date ? [end_date] : []),
        parseInt(limit)
      ]
    );

    res.json(products);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Credit report endpoint
router.get('/credit-report', [auth, checkRole(['admin', 'manager', 'cashier'])], async (req, res) => {
  try {
    const { start_date, end_date } = req.query;
    // Only include original credit sales, exclude credit payments (parent_sale_id IS NOT NULL)
    let whereClause = 'WHERE s.payment_method = "credit" AND s.parent_sale_id IS NULL';
    const params = [];
    
    // Add business_id filter unless superadmin
    if (req.user.role !== 'superadmin') {
      if (!req.user.business_id) {
        return res.status(400).json({ message: 'Business ID is required for this report.' });
      }
      whereClause += ' AND s.business_id = ?';
      params.push(req.user.business_id);
    }
    
    // Add date filters
    if (start_date) {
      whereClause += ' AND DATE(s.created_at) >= ?';
      params.push(start_date);
    }
    if (end_date) {
      whereClause += ' AND DATE(s.created_at) <= ?';
      params.push(end_date);
    }
    
    // Credit sales by customer, now include cashier info
    const [byCustomer] = await pool.query(
      `SELECT 
        c.id as customer_id,
        c.name as customer_name,
        c.email as customer_email,
        c.phone as customer_phone,
        COUNT(s.id) as credit_sales_count,
        SUM(s.total_amount) as total_credit_amount,
        MAX(s.created_at) as last_credit_sale,
        u.username as cashier_name
      FROM sales s
      LEFT JOIN customers c ON s.customer_id = c.id
      LEFT JOIN users u ON s.user_id = u.id
      ${whereClause}
      GROUP BY c.id, c.name, c.email, c.phone, u.username
      ORDER BY total_credit_amount DESC`,
      params
    );
    
    console.log('Credit report byCustomer result:', byCustomer);
    
    // Summary statistics
    const [summary] = await pool.query(
      `SELECT 
        COUNT(*) as total_credit_sales,
        SUM(s.total_amount) as total_credit_amount,
        COUNT(DISTINCT s.customer_id) as unique_credit_customers,
        AVG(s.total_amount) as average_credit_sale
      FROM sales s ${whereClause}`,
      params
    );
    
    res.json({
      byCustomer,
      summary: summary[0]
    });
  } catch (error) {
    console.error('Error getting credit report:', error);
    res.status(500).json({ message: 'Failed to get credit report' });
  }
});

// Get credit customers
router.get('/credit-customers', [auth, checkRole(['admin', 'manager', 'cashier'])], async (req, res) => {
  try {
    let whereClause = 'WHERE orig.payment_method = "credit"';
    const params = [];
    
    // Add business_id filter unless superadmin
    if (req.user.role !== 'superadmin') {
      if (!req.user.business_id) {
        return res.status(400).json({ message: 'Business ID is required for this report.' });
      }
      whereClause += ' AND orig.business_id = ?';
      params.push(req.user.business_id);
    }
    
    // Get customers with outstanding credit sales only
    const [customers] = await pool.query(
      `SELECT 
        c.id,
        c.name,
        c.email,
        c.phone,
        COUNT(orig.id) as credit_sales_count,
        SUM(orig.total_amount) as total_credit_amount,
        MAX(orig.created_at) as last_credit_sale,
        SUM(COALESCE(payments.total_paid, 0)) as total_paid_amount,
        (SUM(orig.total_amount) - SUM(COALESCE(payments.total_paid, 0))) as outstanding_amount
      FROM sales orig
      LEFT JOIN customers c ON orig.customer_id = c.id
      LEFT JOIN (
        SELECT parent_sale_id, SUM(total_amount) as total_paid 
        FROM sales 
        WHERE parent_sale_id IS NOT NULL 
        GROUP BY parent_sale_id
      ) payments ON payments.parent_sale_id = orig.id
      ${whereClause} AND orig.parent_sale_id IS NULL
      GROUP BY c.id, c.name, c.email, c.phone
      HAVING outstanding_amount > 0
      ORDER BY outstanding_amount DESC`,
      params
    );
    
    res.json({
      customers: customers
    });
  } catch (error) {
    console.error('Error getting credit customers:', error);
    res.status(500).json({ message: 'Failed to get credit customers' });
  }
});

// Get customer credit transactions (credit sales and payment history)
router.get('/customer/:customerId/credit-transactions', [auth, checkRole(['admin', 'manager', 'cashier'])], async (req, res) => {
  try {
    const customerId = req.params.customerId;
    let whereClause = 'WHERE s.customer_id = ?';
    const params = [customerId];
    
    // Add business_id filter unless superadmin
    if (req.user.role !== 'superadmin') {
      if (!req.user.business_id) {
        return res.status(400).json({ message: 'Business ID is required for this report.' });
      }
      whereClause += ' AND s.business_id = ?';
      params.push(req.user.business_id);
    }
    
    // Get all credit sales for this customer (original credit sales only)
    const [creditSales] = await pool.query(
      `SELECT 
        s.id,
        s.total_amount,
        s.created_at,
        s.status,
        s.payment_method,
        u.username as cashier_name,
        'credit_sale' as transaction_type,
        NULL as parent_sale_id
      FROM sales s
      LEFT JOIN users u ON s.user_id = u.id
      ${whereClause} AND s.payment_method = 'credit' AND s.parent_sale_id IS NULL
      ORDER BY s.created_at DESC`,
      params
    );
    
    // Get all payment history for this customer's credit sales
    const [payments] = await pool.query(
      `SELECT 
        s.id,
        s.total_amount,
        s.created_at,
        s.status,
        s.payment_method,
        u.username as cashier_name,
        'payment' as transaction_type,
        s.parent_sale_id,
        orig.total_amount as original_credit_amount
      FROM sales s
      LEFT JOIN users u ON s.user_id = u.id
      LEFT JOIN sales orig ON s.parent_sale_id = orig.id
      ${whereClause} AND s.parent_sale_id IS NOT NULL
      ORDER BY s.created_at DESC`,
      params
    );
    
    // Calculate outstanding amounts for each credit sale
    const creditSalesWithOutstanding = await Promise.all(creditSales.map(async (sale) => {
      const [paymentSum] = await pool.query(
        'SELECT IFNULL(SUM(total_amount), 0) as total_paid FROM sales WHERE parent_sale_id = ?',
        [sale.id]
      );
      const totalPaid = Number(paymentSum[0].total_paid) || 0;
      const outstanding = Math.max(0, Number(sale.total_amount) - totalPaid);
      
      return {
        ...sale,
        total_paid: totalPaid,
        outstanding_amount: outstanding,
        is_fully_paid: outstanding <= 0
      };
    }));
    
    // Group payments by parent sale for better organization
    const paymentsByParent = {};
    payments.forEach(payment => {
      const parentId = payment.parent_sale_id;
      if (!paymentsByParent[parentId]) {
        paymentsByParent[parentId] = [];
      }
      paymentsByParent[parentId].push(payment);
    });
    
    res.json({
      customer_id: customerId,
      credit_sales: creditSalesWithOutstanding,
      payments: payments,
      payments_by_parent: paymentsByParent,
      summary: {
        total_credit_amount: creditSalesWithOutstanding.reduce((sum, sale) => sum + Number(sale.total_amount), 0),
        total_paid_amount: payments.reduce((sum, payment) => sum + Number(payment.total_amount), 0),
        total_outstanding: creditSalesWithOutstanding.reduce((sum, sale) => sum + sale.outstanding_amount, 0),
        credit_sales_count: creditSalesWithOutstanding.length,
        payments_count: payments.length
      }
    });
  } catch (error) {
    console.error('Error getting customer credit transactions:', error);
    res.status(500).json({ message: 'Failed to get customer credit transactions' });
  }
});

// Mark a credit sale as paid (partial payments supported, single sales table)
router.put('/:id/pay', auth, async (req, res) => {
  try {
    const saleId = req.params.id;
    const { amount, payment_method } = req.body;
    if (!amount || isNaN(amount) || amount <= 0) {
      return res.status(400).json({ message: 'A valid payment amount is required' });
    }
    if (!payment_method || typeof payment_method !== 'string') {
      return res.status(400).json({ message: 'A valid payment method is required' });
    }
    // Get the original credit sale
    const [sales] = await pool.query('SELECT * FROM sales WHERE id = ?', [saleId]);
    if (sales.length === 0) {
      return res.status(404).json({ message: 'Sale not found' });
    }
    const sale = sales[0];
    if (sale.payment_method !== 'credit' || sale.parent_sale_id) {
      return res.status(400).json({ message: 'Only original credit sales can be paid' });
    }
    if (sale.status === 'paid') {
      return res.status(400).json({ message: 'Sale is already paid' });
    }
    // Get total paid so far
    const [payments] = await pool.query('SELECT IFNULL(SUM(total_amount),0) as total_paid FROM sales WHERE parent_sale_id = ?', [saleId]);
    const totalPaid = Number(payments[0].total_paid) || 0;
    const remaining = Number(sale.total_amount) - totalPaid;
    if (amount > remaining) {
      return res.status(400).json({ message: 'Payment exceeds amount owed' });
    }
    // Insert payment as a new sale row with parent_sale_id set
    await pool.query(
      `INSERT INTO sales (parent_sale_id, customer_id, user_id, total_amount, tax_amount, payment_method, status, business_id)
       VALUES (?, ?, ?, ?, ?, ?, 'completed', ?)`,
      [saleId, sale.customer_id, req.user.id, amount, 0.00, payment_method, sale.business_id]
    );
    // If fully paid, update sale status
    const newTotalPaid = totalPaid + Number(amount);
    if (newTotalPaid >= Number(sale.total_amount)) {
      await pool.query('UPDATE sales SET status = ? WHERE id = ?', ['paid', saleId]);
    }
    res.json({ message: 'Payment recorded', remaining: Math.max(0, Number(sale.total_amount) - newTotalPaid) });
  } catch (error) {
    console.error('Error marking credit sale as paid:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get sale details
router.get('/:id', auth, async (req, res) => {
  try {
    let query = 'SELECT * FROM sales WHERE id = ? AND business_id = ?';
    let params = [req.params.id, req.user.business_id];
    if (req.user.role === 'superadmin') {
      query = 'SELECT * FROM sales WHERE id = ?';
      params = [req.params.id];
    }
    const [sales] = await pool.query(query, params);

    if (sales.length === 0) {
      console.log('Sale not found for ID:', req.params.id);
      return res.status(404).json({ message: 'Sale not found' });
    }

    const [items] = await pool.query(
      `SELECT 
        si.*,
        p.name as product_name,
        p.sku
      FROM sale_items si
      JOIN products p ON si.product_id = p.id
      WHERE si.sale_id = ?`,
      [req.params.id]
    );

    // Get total paid and remaining
    const [payments] = await pool.query('SELECT IFNULL(SUM(total_amount),0) as total_paid FROM sales WHERE parent_sale_id = ?', [req.params.id]);
    const paid = Number(payments[0].total_paid) || 0;
    const totalAmount = Number(sales[0].total_amount) || 0;
    const remaining = Math.max(0, totalAmount - paid);

    // Get payment history from child sales
    const [paymentHistory] = await pool.query(
      'SELECT total_amount as amount, created_at as payment_date, payment_method FROM sales WHERE parent_sale_id = ? ORDER BY created_at ASC',
      [req.params.id]
    );

    const result = {
      ...sales[0],
      items,
      paid,
      remaining,
      payments: paymentHistory
    };
    
    console.log('Sale details result:', result);
    res.json(result);
  } catch (error) {
    console.error('Get sale details error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router; 