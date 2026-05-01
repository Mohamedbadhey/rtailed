const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { auth, checkRole } = require('../middleware/auth');
const { executeQueryWithRelaxedGroupBy } = require('../utils/databaseUtils');

// Get all sales
router.get('/', auth, async (req, res) => {
  try {
    let query = `
      SELECT s.*, 
             u.username as cancelled_by_name
      FROM sales s
      LEFT JOIN users u ON s.cancelled_by = u.id
      WHERE s.business_id = ? 
      ORDER BY s.created_at DESC
    `;
    let params = [req.user.business_id];
    
    if (req.user.role === 'superadmin') {
      query = `
        SELECT s.*, 
               u.username as cancelled_by_name
        FROM sales s
        LEFT JOIN users u ON s.cancelled_by = u.id
        ORDER BY s.created_at DESC
      `;
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
    // First, let's check the sale_items table structure
    try {
      const [columns] = await connection.query('DESCRIBE sale_items');
      // Check if mode column exists and its type
      const modeColumn = columns.find(col => col.Field === 'mode');
      if (modeColumn) {
      } else {
      }
    } catch (error) {
    }
    
    // Extract sale data
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
      const [productRows] = await connection.query('SELECT stock_quantity FROM products WHERE id = ? AND business_id = ?', [item.product_id, req.user.business_id]);
      if (!productRows.length) {
        throw new Error(`Product with ID ${item.product_id} not found in your business`);
      }
      const availableStock = productRows[0].stock_quantity;
      if (item.quantity > availableStock) {
        throw new Error(`Insufficient stock for product ID ${item.product_id}. Available: ${availableStock}, requested: ${item.quantity}`);
      }
    }

    // Calculate totals
    let totalAmount = items.reduce((sum, item) => sum + (item.unit_price * item.quantity), 0);

    // Debug log for sale insert
    // Debug log for complete request body
    // Debug log for items
    // Note: No overall sale_mode is set - each item maintains its individual mode
    // Determine the actual sale mode based on items
    let actualSaleMode = 'retail'; // Default
    if (items.some(item => item.mode === 'wholesale')) {
      actualSaleMode = 'wholesale';
    }
    // Create sale record with the correct sale_mode
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
      [customer_id, req.user.id, totalAmount, 0.00, payment_method, saleStatus, actualSaleMode, businessId]
    );

    const sale_id = saleResult.insertId;
    // Insert sale items
    for (const item of items) {
      const [product] = await connection.query(
        'SELECT cost_price FROM products WHERE id = ? AND business_id = ?',
        [item.product_id, req.user.business_id]
      );

      // Get the current cost price for this product
      const currentCostPrice = product.length > 0 ? product[0].cost_price : 0.00;
      // Add sale item
      const itemMode = item.mode || 'retail';
      // Log the exact INSERT query values
      const insertValues = [
        sale_id,
        item.product_id,
        item.quantity,
        item.unit_price,
        item.unit_price * item.quantity,
        itemMode,
        businessId,
        currentCostPrice
      ];
      await connection.query(
        `INSERT INTO sale_items (
          sale_id, product_id, quantity, unit_price, total_price, mode, business_id, costprice
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        insertValues
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

    // Create cash flow entry for non-credit sales to track cash in hand
    if (payment_method !== 'credit') {
      await connection.query(
        `INSERT INTO cash_flows (type, amount, date, reference, notes, business_id) 
         VALUES (?, ?, CURDATE(), ?, ?, ?)`,
        ['in', totalAmount, `Sale #${sale_id}`, `Sale completed via ${payment_method}`, businessId]
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

router.get('/report', auth, async (req, res) => {
  try {
    
    const { start_date, end_date, group_by = 'day', user_id } = req.query;
    const isCashier = req.user.role === 'cashier';
    
    
    // Debug: Show all filter combinations that will be applied
    
    // Build the WHERE clause - include both completed sales and credit sales (unpaid) but EXCLUDE credit payments and cancelled sales
    // Credit payments have parent_sale_id IS NOT NULL and should not be counted as revenue
    // Cancelled sales should never be counted regardless of payment method
    
    let whereClause = 'WHERE ((s.parent_sale_id IS NULL AND (s.status = "completed" OR (s.payment_method = "credit" AND s.status != "cancelled"))) OR (s.parent_sale_id IS NOT NULL AND s.status = "returned"))';
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
    
    
    // Debug: Check what sales exist for this business
    if (req.user.role !== 'superadmin' && req.user.business_id) {
      const [debugSales] = await pool.query(
        'SELECT id, total_amount, status, business_id, created_at, parent_sale_id, payment_method FROM sales WHERE business_id = ? ORDER BY created_at DESC LIMIT 10',
        [req.user.business_id]
      );
      
      // Debug: Show cancelled sales that are being excluded
      const [cancelledSales] = await pool.query(
        'SELECT id, total_amount, status, business_id, created_at, parent_sale_id, payment_method FROM sales WHERE business_id = ? AND status = "cancelled" ORDER BY created_at DESC LIMIT 5',
        [req.user.business_id]
      );
      if (cancelledSales.length > 0) {
        cancelledSales.forEach((sale, index) => {
        });
      } else {
      }
    }

    // All queries below use whereClause and params
    // Date check
    const [dateCheck] = await pool.query(
      `SELECT COUNT(*) as total_sales_in_range, MIN(s.created_at) as earliest_date, MAX(s.created_at) as latest_date FROM sales s ${whereClause}`,
      params
    );
    
    // Sales by period - use a completely different approach to avoid parameter confusion
    
    const dateFormat = group_by === 'day' ? '%Y-%m-%d' : group_by === 'week' ? '%Y-%u' : '%Y-%m';
    
    // Build the query with explicit values instead of parameters to avoid confusion
    let salesByPeriodQuery = `SELECT DATE_FORMAT(s.created_at, '${dateFormat}') as period, COUNT(*) as total_sales, SUM(s.total_amount) as total_revenue, AVG(s.total_amount) as average_sale FROM sales s WHERE ((s.parent_sale_id IS NULL AND (s.status = "completed" OR (s.payment_method = "credit" AND s.status != "cancelled"))) OR (s.parent_sale_id IS NOT NULL AND s.status = 'returned'))`;
    const salesByPeriodParams = [];
    
    
    // Add business_id filter unless superadmin
    if (req.user.role !== 'superadmin') {
      if (!req.user.business_id) {
        return res.status(400).json({ message: 'Business ID is required for this report.' });
      }
      salesByPeriodQuery += ' AND s.business_id = ?';
      salesByPeriodParams.push(req.user.business_id);
    }
    
    // Add user_id filter
    if (isCashier) {
      salesByPeriodQuery += ' AND s.user_id = ?';
      salesByPeriodParams.push(req.user.id);
    } else if (user_id) {
      salesByPeriodQuery += ' AND s.user_id = ?';
      salesByPeriodParams.push(user_id);
    }
    
    // Add date filters
    if (start_date) {
      salesByPeriodQuery += ' AND DATE(s.created_at) >= ?';
      salesByPeriodParams.push(start_date);
    }
    if (end_date) {
      salesByPeriodQuery += ' AND DATE(s.created_at) <= ?';
      salesByPeriodParams.push(end_date);
    }
    
    // Add GROUP BY and ORDER BY
    salesByPeriodQuery += ` GROUP BY DATE_FORMAT(s.created_at, '${dateFormat}') ORDER BY period DESC`;
    
    
    let salesByPeriod;
    try {
      // Try the normal query first
      
      [salesByPeriod] = await pool.query(salesByPeriodQuery, salesByPeriodParams);
      
      
    } catch (error) {
      
      if (error.code === 'ER_WRONG_FIELD_WITH_GROUP') {
        // Fallback to relaxed GROUP BY mode
        salesByPeriod = await executeQueryWithRelaxedGroupBy(salesByPeriodQuery, salesByPeriodParams);
      } else {
        throw error;
      }
    }
    
    // Payment methods - show only actual payment methods (completed sales + credit payments, exclude original credits)
    // Debug: Show the exact WHERE clause being built
    let paymentMethodsWhereClause = `(
      (s.status = "completed" AND s.parent_sale_id IS NULL) OR 
      (s.parent_sale_id IS NOT NULL)
    )`;
    
    if (req.user.role !== 'superadmin') {
      paymentMethodsWhereClause += ` AND s.business_id = ${req.user.business_id}`;
    }
    if (isCashier) {
      paymentMethodsWhereClause += ` AND s.user_id = ${req.user.id}`;
    } else if (user_id) {
      paymentMethodsWhereClause += ` AND s.user_id = ${user_id}`;
    }
    if (start_date) {
      paymentMethodsWhereClause += ` AND DATE(s.created_at) >= '${start_date}'`;
    }
    if (end_date) {
      paymentMethodsWhereClause += ` AND DATE(s.created_at) <= '${end_date}'`;
    }
    const [paymentMethods] = await pool.query(
      `SELECT s.payment_method, COUNT(*) as count, SUM(s.total_amount) as total_amount 
       FROM sales s 
       WHERE (
         (s.status = "completed" AND s.parent_sale_id IS NULL) OR 
         (s.parent_sale_id IS NOT NULL AND s.status != "cancelled")
       )
         ${req.user.role !== 'superadmin' ? 'AND s.business_id = ?' : ''}
         ${isCashier ? 'AND s.user_id = ?' : ''}
         ${user_id && !isCashier ? 'AND s.user_id = ?' : ''}
         ${start_date ? 'AND DATE(s.created_at) >= ?' : ''}
         ${end_date ? 'AND DATE(s.created_at) <= ?' : ''}
       GROUP BY s.payment_method 
       ORDER BY total_amount DESC`,
      [
        ...(req.user.role !== 'superadmin' ? [req.user.business_id] : []),
        ...(isCashier ? [req.user.id] : []),
        ...(user_id && !isCashier ? [user_id] : []),
        ...(start_date ? [start_date] : []),
        ...(end_date ? [end_date] : [])
      ]
    );
    paymentMethods.forEach((pm, index) => {
    });
    // Customer insights - exclude credit payments
    const [customerInsights] = await pool.query(
      `SELECT COUNT(DISTINCT s.customer_id) as unique_customers, COUNT(*) as total_transactions, AVG(s.total_amount) as average_customer_spend FROM sales s ${whereClause} AND s.customer_id IS NOT NULL`,
      params
    );
    
    // Summary statistics - exclude credit payments from revenue calculation
    const [summary] = await pool.query(
      `SELECT COUNT(*) as total_orders, SUM(s.total_amount) as total_revenue, AVG(s.total_amount) as average_order_value, MIN(s.total_amount) as min_order, MAX(s.total_amount) as max_order FROM sales s ${whereClause}`,
      params
    );
    
    // Credit sales summary - only original credit sales, not payments
    const [creditSummary] = await pool.query(
      `SELECT COUNT(*) as total_credit_sales, SUM(s.total_amount) as total_credit_amount, COUNT(DISTINCT s.customer_id) as unique_credit_customers FROM sales s ${whereClause} AND s.payment_method = 'credit'`,
      params
    );
    
    // Calculate outstanding credits more accurately
    let outstandingCreditsQuery = `
      SELECT 
        SUM(orig.total_amount) as total_original_credit,
        SUM(IFNULL(pay.total_paid, 0)) as total_paid_amount,
        SUM(orig.total_amount - IFNULL(pay.total_paid, 0)) as total_outstanding_credit
      FROM sales orig 
      LEFT JOIN (
        SELECT parent_sale_id, SUM(total_amount) as total_paid 
        FROM sales 
        WHERE parent_sale_id IS NOT NULL 
        GROUP BY parent_sale_id
      ) pay ON pay.parent_sale_id = orig.id 
      WHERE orig.payment_method = 'credit' 
        AND orig.parent_sale_id IS NULL 
        AND (orig.status != 'paid' OR orig.status IS NULL)
    `;
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
    
    
    // Product breakdown - exclude credit payments
    const [productBreakdown] = await pool.query(
      `SELECT p.id, p.name, SUM(si.quantity) as quantity_sold, SUM(si.total_price) as revenue, SUM(si.total_price - (si.quantity * COALESCE(si.costprice, p.cost_price))) as profit FROM sale_items si JOIN products p ON si.product_id = p.id JOIN sales s ON si.sale_id = s.id ${whereClause} GROUP BY p.id, p.name ORDER BY revenue DESC`,
      params
    );
    
    // Calculate total cost of goods sold (COGS) for profit calculation - exclude credit payments and cancelled sales
    let cogsQuery = `
      SELECT SUM(si.quantity * COALESCE(si.costprice, p.cost_price)) as total_cost 
      FROM sale_items si 
      JOIN products p ON si.product_id = p.id 
      JOIN sales s ON si.sale_id = s.id 
      WHERE (s.status = "completed" OR (s.payment_method = "credit" AND s.status != "cancelled")) AND s.parent_sale_id IS NULL
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
    const totalProductsSold = productBreakdown.reduce((sum, p) => sum + (Number(p.quantity_sold) || 0), 0);
    
    // Calculate profit using the same logic as Profit & Loss: Revenue - COGS
    const totalRevenue = summary[0]?.total_revenue || 0;
    const totalProfit = totalRevenue - total_cost;
    
    // Calculate cash in hand from completed non-credit sales + credit payments
    // Debug: Show the exact WHERE clause being built for cash in hand
    let cashInHandWhereClause = `s.status = "completed" AND s.payment_method != "credit"`;
    
    if (req.user.role !== 'superadmin') {
      cashInHandWhereClause += ` AND s.business_id = ${req.user.business_id}`;
    }
    if (isCashier) {
      cashInHandWhereClause += ` AND s.user_id = ${req.user.id}`;
    } else if (user_id) {
      cashInHandWhereClause += ` AND s.user_id = ${user_id}`;
    }
    if (start_date) {
      cashInHandWhereClause += ` AND DATE(s.created_at) >= '${start_date}'`;
    }
    if (end_date) {
      cashInHandWhereClause += ` AND DATE(s.created_at) <= '${end_date}'`;
    }
    // Debug: Show exactly what rows will be included in cash in hand
    let debugCashQuery = `
      SELECT id, total_amount, payment_method, status, parent_sale_id, business_id, user_id, created_at
      FROM sales s 
      WHERE s.status = "completed" 
        AND s.payment_method != "credit"
        AND s.status != "cancelled"
        AND s.business_id = ?
        AND DATE(s.created_at) >= ?
        AND DATE(s.created_at) <= ?
      ORDER BY s.created_at DESC
    `;
    
    try {
      const [debugCashRows] = await pool.query(debugCashQuery, [req.user.business_id, start_date, end_date]);
      debugCashRows.forEach((row, index) => {
      });
      
      const totalDebugAmount = debugCashRows.reduce((sum, row) => sum + Number(row.total_amount), 0);
    } catch (error) {
    }
    
    // Debug: Show exactly what the main cash in hand query will return
    let cashInHandQuery = `
      SELECT 
        SUM(s.total_amount) as total_cash_in_hand
      FROM sales s 
      WHERE (
        (s.status = "completed" AND s.parent_sale_id IS NULL) OR 
        (s.parent_sale_id IS NOT NULL AND s.status != "cancelled")
      )
        AND s.payment_method != "credit"
        AND s.status != "cancelled"
    `;
    let cashInHandParams = [];
    
    // Add business_id filter unless superadmin
    if (req.user.role !== 'superadmin') {
      if (!req.user.business_id) {
        return res.status(400).json({ message: 'Business ID is required for this report.' });
      }
      cashInHandQuery += ' AND s.business_id = ?';
      cashInHandParams.push(req.user.business_id);
    }
    
    // Add user filter for cashiers
    if (isCashier) {
      cashInHandQuery += ' AND s.user_id = ?';
      cashInHandParams.push(req.user.id);
    } else if (user_id) {
      cashInHandQuery += ' AND s.user_id = ?';
      cashInHandParams.push(user_id);
    }
    
    // Add date filters if specified
    if (start_date) {
      cashInHandQuery += ' AND DATE(s.created_at) >= ?';
      cashInHandParams.push(start_date);
    }
    if (end_date) {
      cashInHandQuery += ' AND DATE(s.created_at) <= ?';
      cashInHandParams.push(end_date);
    }
    const [cashInHandResult] = await pool.query(cashInHandQuery, cashInHandParams);
    const actualCashInHand = Number(cashInHandResult[0]?.total_cash_in_hand) || 0;
    // Debug: Show exactly what the main cash in hand query will return
    // Final summary of all calculations
    
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


    
    const response = {
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
      cashInHand: actualCashInHand,
      outstandingCredits: Number(outstandingCredits[0]?.total_outstanding_credit) || 0,
      paymentMethodBreakdown: safePaymentMethods,
      // Enhanced credit information
      creditBreakdown: {
        totalOriginalCredit: Number(outstandingCredits[0]?.total_original_credit) || 0,
        totalPaidAmount: Number(outstandingCredits[0]?.total_paid_amount) || 0,
        totalOutstanding: Number(outstandingCredits[0]?.total_outstanding_credit) || 0
      }
    };
    
    
    res.json(response);
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
      HAVING credit_sales_count > 0
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
    
    // Get all credit sales for this customer
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
    
    // Get product details for each credit sale
    const creditSalesWithProducts = await Promise.all(creditSales.map(async (sale) => {
      const [products] = await pool.query(
        `SELECT 
          si.quantity,
          si.unit_price,
          si.total_price,
          p.name as product_name,
          p.description as product_description,
          p.image_url as product_image
        FROM sale_items si
        JOIN products p ON si.product_id = p.id
        WHERE si.sale_id = ?`,
        [sale.id]
      );
      
      return {
        ...sale,
        products: products
      };
    }));
    
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
        orig.total_amount as original_credit_amount,
        orig.id as original_sale_id
      FROM sales s
      LEFT JOIN users u ON s.user_id = u.id
      LEFT JOIN sales orig ON s.parent_sale_id = orig.id
      ${whereClause} AND s.parent_sale_id IS NOT NULL
      ORDER BY s.created_at DESC`,
      params
    );
    
    // Calculate outstanding amounts for each credit sale
    const creditSalesWithOutstanding = await Promise.all(creditSalesWithProducts.map(async (sale) => {
      const [paymentSum] = await pool.query(
        'SELECT IFNULL(SUM(total_amount), 0) as total_paid FROM sales WHERE parent_sale_id = ?',
        [sale.id]
      );
      const totalPaid = Number(paymentSum[0].total_paid) || 0;
      const outstanding = Math.max(0, Number(sale.total_amount) - totalPaid);
      
      // Debug logging
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
    
    // Create comprehensive transaction history combining credit sales and payments
    const allTransactions = [];
    
    // Add credit sales with their payment details
    creditSalesWithOutstanding.forEach(creditSale => {
      // Add the credit sale
      allTransactions.push({
        id: creditSale.id,
        transaction_type: 'credit_sale',
        total_amount: creditSale.total_amount, // Keep consistent with frontend expectation
        amount: creditSale.total_amount, // Also include amount for compatibility
        created_at: creditSale.created_at,
        status: creditSale.status,
        payment_method: creditSale.payment_method,
        cashier_name: creditSale.cashier_name,
        total_paid: creditSale.total_paid,
        outstanding_amount: creditSale.outstanding_amount,
        is_fully_paid: creditSale.is_fully_paid,
        description: `Credit sale of $${creditSale.total_amount}`,
        parent_sale_id: null,
        products: creditSale.products // Include product details
      });
      
      // Add all payments for this credit sale
      const salePayments = paymentsByParent[creditSale.id] || [];
      salePayments.forEach(payment => {
        allTransactions.push({
          id: payment.id,
          transaction_type: 'payment',
          total_amount: payment.total_amount, // Keep consistent
          amount: payment.total_amount, // Also include amount for compatibility
          created_at: payment.created_at,
          status: payment.status,
          payment_method: payment.payment_method,
          cashier_name: payment.cashier_name,
          total_paid: null, // Not applicable for payments
          outstanding_amount: null, // Not applicable for payments
          is_fully_paid: null, // Not applicable for payments
          description: `Payment of $${payment.total_amount} for credit sale #${payment.parent_sale_id}`,
          parent_sale_id: payment.parent_sale_id,
          original_credit_amount: payment.original_credit_amount
        });
      });
    });
    
    // Sort all transactions by priority: unpaid first, then partially paid, then fully paid, then by date
    allTransactions.sort((a, b) => {
      const aIsCreditSale = a.transaction_type === 'credit_sale';
      const bIsCreditSale = b.transaction_type === 'credit_sale';
      
      if (aIsCreditSale && bIsCreditSale) {
        // Both are credit sales - sort by payment status priority
        const aOutstanding = Number(a.outstanding_amount) || 0;
        const bOutstanding = Number(b.outstanding_amount) || 0;
        
        if (aOutstanding > 0 && bOutstanding > 0) {
          // Both have outstanding amounts - sort by amount (highest first)
          return bOutstanding - aOutstanding;
        } else if (aOutstanding > 0) {
          return -1; // A has outstanding, B doesn't - A comes first
        } else if (bOutstanding > 0) {
          return 1; // B has outstanding, A doesn't - B comes first
        } else {
          // Both fully paid - sort by date (newest first)
          return new Date(b.created_at) - new Date(a.created_at);
        }
      } else if (aIsCreditSale) {
        return -1; // Credit sales come before payments
      } else if (bIsCreditSale) {
        return 1; // Credit sales come before payments
      } else {
        // Both are payments - sort by date (newest first)
        return new Date(b.created_at) - new Date(a.created_at);
      }
    });
    
    // Create detailed summary with payment breakdown
    const summary = {
      total_credit_amount: creditSalesWithOutstanding.reduce((sum, sale) => sum + Number(sale.total_amount), 0),
      total_paid_amount: payments.reduce((sum, payment) => sum + Number(payment.total_amount), 0),
      total_outstanding: creditSalesWithOutstanding.reduce((sum, sale) => sum + sale.outstanding_amount, 0),
      credit_sales_count: creditSalesWithOutstanding.length,
      payments_count: payments.length,
      fully_paid_credits: creditSalesWithOutstanding.filter(sale => sale.is_fully_paid).length,
      partially_paid_credits: creditSalesWithOutstanding.filter(sale => !sale.is_fully_paid && sale.total_paid > 0).length,
      unpaid_credits: creditSalesWithOutstanding.filter(sale => sale.total_paid === 0).length
    };
    
    res.json({
      customer_id: customerId,
      credit_sales: creditSalesWithOutstanding,
      payments: payments,
      payments_by_parent: paymentsByParent,
      all_transactions: allTransactions, // New comprehensive transaction list
      summary: summary
    });
  } catch (error) {
    console.error('Error getting customer credit transactions:', error);
    res.status(500).json({ message: 'Failed to get customer credit transactions' });
  }
});

// Get all transactions for a specific customer (for invoice generation)
router.get('/customer/:customerId/all-transactions', [auth, checkRole(['admin', 'manager', 'cashier'])], async (req, res) => {
  try {
    const customerId = req.params.customerId;
    const { start_date, end_date } = req.query;
    
    let whereClause = 'WHERE s.customer_id = ?';
    const params = [customerId];
    
    // Add business isolation
    if (req.user.role !== 'superadmin') {
      whereClause += ' AND s.business_id = ?';
      params.push(req.user.business_id);
    }
    
    // Add date filtering if provided
    if (start_date) {
      whereClause += ' AND DATE(s.created_at) >= ?';
      params.push(start_date);
    }
    
    if (end_date) {
      whereClause += ' AND DATE(s.created_at) <= ?';
      params.push(end_date);
    }
    
    // Get all sales for this customer with product details
    const [sales] = await pool.query(
      `SELECT 
        s.id,
        s.total_amount,
        s.tax_amount,
        s.payment_method,
        s.status,
        s.sale_mode,
        s.created_at,
        s.parent_sale_id,
        u.username as cashier_name,
        c.name as customer_name,
        c.email as customer_email,
        c.phone as customer_phone,
        c.address as customer_address
      FROM sales s
      LEFT JOIN users u ON s.user_id = u.id
      LEFT JOIN customers c ON s.customer_id = c.id
      ${whereClause}
      ORDER BY s.created_at DESC`,
      params
    );
    
    // Get sale items for each sale
    const salesWithItems = await Promise.all(sales.map(async (sale) => {
      const [items] = await pool.query(
        `SELECT 
          si.id,
          si.product_id,
          si.quantity,
          si.unit_price,
          si.total_price,
          si.mode,
          p.name as product_name,
          p.sku,
          p.description as product_description,
          cat.name as category_name
        FROM sale_items si
        LEFT JOIN products p ON si.product_id = p.id
        LEFT JOIN categories cat ON p.category_id = cat.id
        WHERE si.sale_id = ?
        ORDER BY si.id`,
        [sale.id]
      );
      
      return {
        ...sale,
        items: items
      };
    }));
    
    // Calculate summary statistics
    const totalAmount = salesWithItems.reduce((sum, sale) => sum + parseFloat(sale.total_amount || 0), 0);
    const totalTransactions = salesWithItems.length;
    const paymentMethods = [...new Set(salesWithItems.map(sale => sale.payment_method))];
    
    res.json({
      customer: salesWithItems.length > 0 ? {
        id: customerId,
        name: salesWithItems[0].customer_name,
        email: salesWithItems[0].customer_email,
        phone: salesWithItems[0].customer_phone,
        address: salesWithItems[0].customer_address
      } : null,
      transactions: salesWithItems,
      summary: {
        total_amount: totalAmount,
        total_transactions: totalTransactions,
        payment_methods: paymentMethods,
        date_range: {
          start_date: start_date || null,
          end_date: end_date || null
        }
      }
    });
  } catch (error) {
    console.error('Error getting customer transactions:', error);
    res.status(500).json({ message: 'Failed to get customer transactions' });
  }
});

// Mark a credit sale as paid (partial payments supported, single sales table)
router.put('/:id/pay', auth, async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    
    const saleId = req.params.id;
    const { amount, payment_method } = req.body;
    if (!amount || isNaN(amount) || amount <= 0) {
      return res.status(400).json({ message: 'A valid payment amount is required' });
    }
    if (!payment_method || typeof payment_method !== 'string') {
      return res.status(400).json({ message: 'A valid payment method is required' });
    }
    // Get the original credit sale
    const [sales] = await connection.query('SELECT * FROM sales WHERE id = ?', [saleId]);
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
    const [payments] = await connection.query('SELECT IFNULL(SUM(total_amount),0) as total_paid FROM sales WHERE parent_sale_id = ? AND status = "paid"', [saleId]);
    const totalPaid = Number(payments[0].total_paid) || 0;
    const remaining = Number(sale.total_amount) - totalPaid;
    if (amount > remaining) {
      return res.status(400).json({ message: 'Payment exceeds amount owed' });
    }
    
    // Insert payment as a new sale row with parent_sale_id set
    await connection.query(
      `INSERT INTO sales (parent_sale_id, customer_id, user_id, total_amount, tax_amount, payment_method, status, business_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [saleId, sale.customer_id, req.user.id, amount, 0.00, payment_method, 'paid', sale.business_id]
    );
    
    // Create cash flow entry to increase cash in hand
    await connection.query(
      `INSERT INTO cash_flows (type, amount, date, reference, notes, business_id) 
       VALUES (?, ?, CURDATE(), ?, ?, ?)`,
      ['in', amount, `Sale #${saleId} Payment`, `Payment of $${amount} for credit sale #${saleId}`, sale.business_id]
    );
    
    await connection.commit();
    res.status(200).json({ message: 'Payment recorded successfully' });
  } catch (error) {
    await connection.rollback();
    console.error(error);
    res.status(500).json({ message: error.message || 'Server error' });
  } finally {
    connection.release();
  }
});

// Cancel/Refund a sale transaction
router.post('/:id/cancel', auth, async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    
    const saleId = req.params.id;
    const { reason, refund_method } = req.body;
    
    if (!reason || reason.trim() === '') {
      return res.status(400).json({ message: 'Cancellation reason is required' });
    }
    
    // Get the sale to cancel
    const [sales] = await connection.query(
      'SELECT * FROM sales WHERE id = ? AND business_id = ?',
      [saleId, req.user.business_id]
    );
    
    if (sales.length === 0) {
      return res.status(404).json({ message: 'Sale not found' });
    }
    
    const sale = sales[0];
    
    // Check if sale can be cancelled
    if (sale.status === 'cancelled') {
      return res.status(400).json({ message: 'Sale is already cancelled' });
    }
    
    if (sale.parent_sale_id) {
      return res.status(400).json({ message: 'Credit payments cannot be cancelled directly' });
    }
    
    // Get sale items to restore inventory
    const [saleItems] = await connection.query(
      'SELECT product_id, quantity FROM sale_items WHERE sale_id = ?',
      [saleId]
    );
    
    // Restore product stock quantities
    for (const item of saleItems) {
      await connection.query(
        'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ? AND business_id = ?',
        [item.quantity, item.product_id, req.user.business_id]
      );
      
      // Add inventory transaction for stock restoration
      await connection.query(
        `INSERT INTO inventory_transactions (
          product_id, quantity, transaction_type, reference_id, notes, business_id
        ) VALUES (?, ?, ?, ?, ?, ?)`,
        [
          item.product_id,
          item.quantity,
          'cancellation',
          saleId,
          `Sale cancellation - stock restored`,
          req.user.business_id
        ]
      );
    }
    
    // Update sale status to cancelled
    await connection.query(
      `UPDATE sales SET 
        status = 'cancelled',
        cancelled_at = NOW(),
        cancelled_by = ?,
        cancellation_reason = ?
       WHERE id = ?`,
      [req.user.id, reason.trim(), saleId]
    );
    
    // Handle refunds if payment was made
    if (sale.payment_method !== 'credit' && sale.status === 'completed') {
      // Create cash flow entry for refund (decreases cash in hand)
      await connection.query(
        `INSERT INTO cash_flows (type, amount, date, reference, notes, business_id) 
         VALUES (?, ?, CURDATE(), ?, ?, ?)`,
        ['out', sale.total_amount, `Sale #${saleId} Cancellation`, `Refund for cancelled sale #${saleId}: ${reason}`, req.user.business_id]
      );
      
      // If customer loyalty points were given, deduct them
      if (sale.customer_id) {
        const pointsToDeduct = Math.floor(sale.total_amount);
        await connection.query(
          'UPDATE customers SET loyalty_points = GREATEST(0, loyalty_points - ?) WHERE id = ? AND business_id = ?',
          [pointsToDeduct, sale.customer_id, req.user.business_id]
        );
      }
    }
    
    // Handle credit sales differently
    if (sale.payment_method === 'credit') {
      // For credit sales, we don't need to handle refunds, just mark as cancelled
      // The customer won't owe anything for cancelled credit sales
    }
    
    await connection.commit();
    
    res.json({
      message: 'Sale cancelled successfully',
      sale_id: saleId,
      status: 'cancelled',
      cancelled_at: new Date(),
      cancelled_by: req.user.id,
      cancellation_reason: reason
    });
    
  } catch (error) {
    await connection.rollback();
    console.error('Error cancelling sale:', error);
    res.status(500).json({ message: error.message || 'Server error' });
  } finally {
    connection.release();
  }
});

// Return a single item from a sale (child negative sale entry)
router.post('/:saleId/items/:itemId/return', auth, async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const saleId = parseInt(req.params.saleId, 10);
    const saleItemId = parseInt(req.params.itemId, 10);
    const { quantity, reason, refund_method } = req.body || {};
    const qty = Number(quantity) > 0 ? parseInt(quantity, 10) : 1;

    // Validate sale
    const [sales] = await connection.query('SELECT * FROM sales WHERE id = ? AND business_id = ?', [saleId, req.user.business_id]);
    if (!sales.length) {
      return res.status(404).json({ message: 'Sale not found' });
    }
    const sale = sales[0];
    if (sale.status === 'cancelled') {
      return res.status(400).json({ message: 'Original sale is cancelled' });
    }
    if (sale.parent_sale_id) {
      return res.status(400).json({ message: 'Cannot return items from a payment/child sale' });
    }
    // Support item returns for credit sales: create a child return as before but do NOT create cash refund; it reduces outstanding automatically by negative child amount.
    // No extra action is required here; the reports/outstanding logic already treats child rows distinctly.

    // Fetch original sale item
    const [origItems] = await connection.query(
      'SELECT * FROM sale_items WHERE id = ? AND sale_id = ? AND business_id = ? LIMIT 1',
      [saleItemId, saleId, req.user.business_id]
    );
    if (!origItems.length) {
      return res.status(404).json({ message: 'Sale item not found' });
    }
    const origItem = origItems[0];

    // Compute already returned qty for this product within child return sales of this parent
    const [returnedRows] = await connection.query(
      `SELECT ABS(IFNULL(SUM(si.quantity),0)) AS returned_qty
       FROM sale_items si
       JOIN sales cs ON cs.id = si.sale_id
       WHERE cs.parent_sale_id = ? AND cs.status != 'cancelled' AND si.product_id = ? AND si.business_id = ?`,
      [saleId, origItem.product_id, req.user.business_id]
    );
    const alreadyReturned = Number(returnedRows[0].returned_qty) || 0;
    const maxReturnable = Math.max(0, Number(origItem.quantity) - alreadyReturned);
    if (qty > maxReturnable) {
      return res.status(400).json({ message: `Return quantity exceeds available (${maxReturnable})` });
    }

    const refundAmount = Number(origItem.unit_price) * qty;

    // Create child return sale with negative total
    const [childResult] = await connection.query(
      `INSERT INTO sales (parent_sale_id, customer_id, user_id, total_amount, tax_amount, payment_method, status, business_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [saleId, sale.customer_id, req.user.id, -refundAmount, 0.00, sale.payment_method, 'returned', sale.business_id]
    );
    const childSaleId = childResult.insertId;

    // Insert negative sale_item row for the returned quantity
    await connection.query(
      `INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, total_price, mode, business_id, costprice)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [childSaleId, origItem.product_id, -qty, origItem.unit_price, -refundAmount, origItem.mode || 'retail', sale.business_id, origItem.costprice || 0.00]
    );

    // Restore inventory
    await connection.query(
      'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ? AND business_id = ?',
      [qty, origItem.product_id, sale.business_id]
    );
    await connection.query(
      `INSERT INTO inventory_transactions (product_id, quantity, transaction_type, reference_id, notes, business_id)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [origItem.product_id, qty, 'return', childSaleId, reason && reason.trim() ? reason.trim() : `Return from sale #${saleId}` , sale.business_id]
    );

    // Cash refund only for non-credit original sales
    if (sale.payment_method !== 'credit') {
      await connection.query(
        `INSERT INTO cash_flows (type, amount, date, reference, notes, business_id)
         VALUES (?, ?, CURDATE(), ?, ?, ?)`,
        ['out', refundAmount, `Sale #${saleId} Item Return`, `Refund for returned item from sale #${saleId}${reason ? ': ' + reason : ''}`, sale.business_id]
      );
    }

    await connection.commit();
    res.status(201).json({ message: 'Item returned successfully', child_sale_id: childSaleId, refund_amount: refundAmount });
  } catch (error) {
    await connection.rollback();
    console.error('Error returning sale item:', error);
    res.status(500).json({ message: error.message || 'Server error' });
  } finally {
    connection.release();
  }
});

// Get a specific sale with items - MUST be placed AFTER all specific routes
router.get('/:id', auth, async (req, res) => {
  try {
    const saleId = req.params.id;
    
    // Get sale details
    const [sales] = await pool.query(
      `SELECT s.*, 
              c.name as customer_name,
              u.username as cashier_name,
              u2.username as cancelled_by_name
       FROM sales s
       LEFT JOIN customers c ON s.customer_id = c.id
       LEFT JOIN users u ON s.user_id = u.id
       LEFT JOIN users u2 ON s.cancelled_by = u2.id
       WHERE s.id = ? AND s.business_id = ?`,
      [saleId, req.user.business_id]
    );
    
    if (sales.length === 0) {
      return res.status(404).json({ message: 'Sale not found' });
    }
    
    const sale = sales[0];
    
    // Get sale items
    const [items] = await pool.query(
      `SELECT si.*, p.name as product_name, p.description as product_description, p.image_url as product_image
       FROM sale_items si
       JOIN products p ON si.product_id = p.id
       WHERE si.sale_id = ?`,
      [saleId]
    );
    
    // Get payment history if this is a credit sale
    let payments = [];
    if (sale.payment_method === 'credit' && !sale.parent_sale_id) {
      const [paymentRows] = await pool.query(
        `SELECT s.*, u.username as cashier_name
         FROM sales s
         LEFT JOIN users u ON s.user_id = u.id
         WHERE s.parent_sale_id = ? AND s.status != 'cancelled'
         ORDER BY s.created_at DESC`,
        [saleId]
      );
      payments = paymentRows;
    }
    
    res.json({
      ...sale,
      items: items,
      payments: payments
    });
    
  } catch (error) {
    console.error('Error getting sale:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
