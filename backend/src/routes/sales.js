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

    // Handle partial payments logic
    let cashAmount = 0;
    let creditAmount = 0;
    let hasCredit = false;
    
    if (partial_payments && Array.isArray(partial_payments) && partial_payments.length > 0) {
      for (const payment of partial_payments) {
        if (payment.payment_method === 'credit') {
          hasCredit = true;
          creditAmount += parseFloat(payment.amount);
        } else {
          cashAmount += parseFloat(payment.amount);
        }
      }
    } else {
      // Single payment method
      if (payment_method === 'credit') {
        hasCredit = true;
        creditAmount = totalAmount;
      } else {
        cashAmount = totalAmount;
      }
    }

    // Debug log for sale insert
    console.log('Creating sale with:', {
      customer_id,
      user_id: req.user.id,
      total_amount: totalAmount,
      payment_method,
      hasCredit,
      cashAmount,
      creditAmount,
      status: hasCredit ? 'unpaid' : 'completed'
    });

    // Create main sale record (for cash portion)
    let saleStatus = hasCredit ? 'unpaid' : 'completed';
    let mainPaymentMethod = hasCredit ? (cashAmount > 0 ? 'mixed' : 'credit') : payment_method;
    
    const businessId = req.user.business_id;
    const [saleResult] = await connection.query(
      `INSERT INTO sales (
        customer_id, user_id, total_amount, tax_amount,
        payment_method, status, sale_mode, business_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [customer_id, req.user.id, totalAmount, 0.00, mainPaymentMethod, saleStatus, sale_mode || 'retail', businessId]
    );

    const sale_id = saleResult.insertId;

    // Create separate credit sale if there's a credit portion
    let creditSaleId = null;
    if (hasCredit && creditAmount > 0) {
      const [creditSaleResult] = await connection.query(
        `INSERT INTO sales (
          customer_id, user_id, total_amount, tax_amount,
          payment_method, status, sale_mode, business_id, parent_sale_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [customer_id, req.user.id, creditAmount, 0.00, 'credit', 'unpaid', sale_mode || 'retail', businessId, sale_id]
      );
      creditSaleId = creditSaleResult.insertId;
      
      // Create sale items for credit sale (same items, but with credit amount)
      for (const item of items) {
        const [product] = await connection.query(
          'SELECT cost_price FROM products WHERE id = ?',
          [item.product_id]
        );

        // Calculate proportional credit amount for this item
        const itemTotal = item.unit_price * item.quantity;
        const proportionalCreditAmount = (itemTotal / totalAmount) * creditAmount;

        await connection.query(
          `INSERT INTO sale_items (
            sale_id, product_id, quantity, unit_price, total_price, mode, business_id
          ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [
            creditSaleId,
            item.product_id,
            item.quantity,
            item.unit_price,
            proportionalCreditAmount,
            item.mode || 'retail',
            businessId
          ]
        );
      }
    }

    // Create sale items and update inventory for main sale
    for (const item of items) {
      const [product] = await connection.query(
        'SELECT cost_price FROM products WHERE id = ?',
        [item.product_id]
      );

      // Add sale item
              // Calculate proportional cash amount for this item
        const itemTotal = item.unit_price * item.quantity;
        const proportionalCashAmount = hasCredit ? (itemTotal / totalAmount) * cashAmount : itemTotal;

        await connection.query(
          `INSERT INTO sale_items (
            sale_id, product_id, quantity, unit_price, total_price, mode, business_id
          ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [
            sale_id,
            item.product_id,
            item.quantity,
            item.unit_price,
            proportionalCashAmount,
            item.mode || 'retail',
            businessId
          ]
        );

      // NOTE: Stock quantity is automatically updated by database trigger after_sale_item_insert
      // No need for manual UPDATE here to avoid double deduction
      // Inventory is only deducted once from the main sale, not from the credit sale
    }

    // Update customer loyalty points if customer exists
    if (customer_id) {
      const points = Math.floor(totalAmount); // 1 point per currency unit
      await connection.query(
        'UPDATE customers SET loyalty_points = loyalty_points + ? WHERE id = ?',
        [points, customer_id]
      );
    }

    // Handle cash flow entries
    if (hasCredit) {
      // Partial payment scenario
      if (partial_payments && Array.isArray(partial_payments) && partial_payments.length > 0) {
        for (const payment of partial_payments) {
          if (payment.payment_method !== 'credit') {
            await connection.query(
              `INSERT INTO cash_flows (type, amount, date, reference, notes, business_id) 
               VALUES (?, ?, CURDATE(), ?, ?, ?)`,
              ['in', payment.amount, `Sale #${sale_id} - ${payment.payment_method}`, `Partial payment via ${payment.payment_method}`, businessId]
            );
          }
        }
      }
    } else {
      // Single payment method (existing logic)
      if (payment_method !== 'credit') {
        await connection.query(
          `INSERT INTO cash_flows (type, amount, date, reference, notes, business_id) 
           VALUES (?, ?, CURDATE(), ?, ?, ?)`,
          ['in', totalAmount, `Sale #${sale_id}`, `Sale completed via ${payment_method}`, businessId]
        );
      }
    }

    await connection.commit();

    res.status(201).json({
      message: hasCredit ? 'Partial payment sale completed successfully' : 'Sale completed successfully',
      sale_id,
      credit_sale_id: creditSaleId,
      total_amount: totalAmount,
      cash_amount: cashAmount,
      credit_amount: creditAmount,
      has_credit: hasCredit
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
    console.log('🔍 SALES REPORT: ===== START =====');
    console.log('🔍 SALES REPORT: Request query params:', req.query);
    console.log('🔍 SALES REPORT: Request user:', req.user);
    
    const { start_date, end_date, group_by = 'day', user_id } = req.query;
    const isCashier = req.user.role === 'cashier';
    
    console.log('🔍 SALES REPORT: Parsed params:');
    console.log('  - start_date:', start_date);
    console.log('  - end_date:', end_date);
    console.log('  - group_by:', group_by);
    console.log('  - user_id:', user_id);
    console.log('  - isCashier:', isCashier);
    console.log('  - req.user.id:', req.user.id);
    console.log('  - req.user.business_id:', req.user.business_id);
    
    // Build the WHERE clause - include both completed sales and credit sales (unpaid) but EXCLUDE credit payments
    // Credit payments have parent_sale_id IS NOT NULL and should not be counted as revenue
    console.log('🔍 SALES REPORT: Building WHERE clause...');
    
    let whereClause = 'WHERE (s.status = "completed" OR s.payment_method = "credit") AND s.parent_sale_id IS NULL';
    const params = [];
    
    console.log('🔍 SALES REPORT: Initial whereClause:', whereClause);
    console.log('🔍 SALES REPORT: Initial params array:', params);
    
    // Add business_id filter unless superadmin
    if (req.user.role !== 'superadmin') {
      if (!req.user.business_id) {
        console.log('❌ SALES REPORT: No business_id found for user');
        return res.status(400).json({ message: 'Business ID is required for this report.' });
      }
      whereClause += ' AND s.business_id = ?';
      params.push(req.user.business_id);
      console.log('🔍 SALES REPORT: Added business_id filter. whereClause:', whereClause);
      console.log('🔍 SALES REPORT: params array after business_id:', params);
    }
    
    if (isCashier) {
      whereClause += ' AND s.user_id = ?';
      params.push(req.user.id);
      console.log('🔍 SALES REPORT: Added cashier user_id filter. whereClause:', whereClause);
      console.log('🔍 SALES REPORT: params array after cashier user_id:', params);
    } else if (user_id) {
      whereClause += ' AND s.user_id = ?';
      params.push(user_id);
      console.log('🔍 SALES REPORT: Added specific user_id filter. whereClause:', whereClause);
      console.log('🔍 SALES REPORT: params array after specific user_id:', params);
    }
    
    // Add date filters
    if (start_date) {
      whereClause += ' AND DATE(s.created_at) >= ?';
      params.push(start_date);
      console.log('🔍 SALES REPORT: Added start_date filter. whereClause:', whereClause);
      console.log('🔍 SALES REPORT: params array after start_date:', params);
    }
    if (end_date) {
      whereClause += ' AND DATE(s.created_at) <= ?';
      params.push(end_date);
      console.log('🔍 SALES REPORT: Added end_date filter. whereClause:', whereClause);
      console.log('🔍 SALES REPORT: params array after end_date:', params);
    }
    
    console.log('🔍 SALES REPORT: Final whereClause:', whereClause);
    console.log('🔍 SALES REPORT: Final params array:', params);
    console.log('🔍 SALES REPORT: Date filters - start_date:', start_date, 'end_date:', end_date);
    
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
    console.log('🔍 SALES REPORT: Building salesByPeriodQuery...');
    
    const dateFormat = group_by === 'day' ? '%Y-%m-%d' : group_by === 'week' ? '%Y-%u' : '%Y-%m';
    console.log('🔍 SALES REPORT: dateFormat:', dateFormat);
    
    // Build the query with explicit values instead of parameters to avoid confusion
    let salesByPeriodQuery = `SELECT DATE_FORMAT(s.created_at, '${dateFormat}') as period, COUNT(*) as total_sales, SUM(s.total_amount) as total_revenue, AVG(s.total_amount) as average_sale FROM sales s WHERE (s.status = "completed" OR s.payment_method = "credit") AND s.parent_sale_id IS NULL`;
    const salesByPeriodParams = [];
    
    console.log('🔍 SALES REPORT: Initial salesByPeriodQuery:', salesByPeriodQuery);
    console.log('🔍 SALES REPORT: Initial salesByPeriodParams:', salesByPeriodParams);
    
    // Add business_id filter unless superadmin
    if (req.user.role !== 'superadmin') {
      if (!req.user.business_id) {
        console.log('❌ SALES REPORT: No business_id found for salesByPeriodQuery');
        return res.status(400).json({ message: 'Business ID is required for this report.' });
      }
      salesByPeriodQuery += ' AND s.business_id = ?';
      salesByPeriodParams.push(req.user.business_id);
      console.log('🔍 SALES REPORT: Added business_id to salesByPeriodQuery. Query:', salesByPeriodQuery);
      console.log('🔍 SALES REPORT: salesByPeriodParams after business_id:', salesByPeriodParams);
    }
    
    // Add user_id filter
    if (isCashier) {
      salesByPeriodQuery += ' AND s.user_id = ?';
      salesByPeriodParams.push(req.user.id);
      console.log('🔍 SALES REPORT: Added cashier user_id to salesByPeriodQuery. Query:', salesByPeriodQuery);
      console.log('🔍 SALES REPORT: salesByPeriodParams after cashier user_id:', salesByPeriodParams);
    } else if (user_id) {
      salesByPeriodQuery += ' AND s.user_id = ?';
      salesByPeriodParams.push(user_id);
      console.log('🔍 SALES REPORT: Added specific user_id to salesByPeriodQuery. Query:', salesByPeriodQuery);
      console.log('🔍 SALES REPORT: salesByPeriodParams after specific user_id:', salesByPeriodParams);
    }
    
    // Add date filters
    if (start_date) {
      salesByPeriodQuery += ' AND DATE(s.created_at) >= ?';
      salesByPeriodParams.push(start_date);
      console.log('🔍 SALES REPORT: Added start_date to salesByPeriodQuery. Query:', salesByPeriodQuery);
      console.log('🔍 SALES REPORT: salesByPeriodParams after start_date:', salesByPeriodParams);
    }
    if (end_date) {
      salesByPeriodQuery += ' AND DATE(s.created_at) <= ?';
      salesByPeriodParams.push(end_date);
      console.log('🔍 SALES REPORT: Added end_date to salesByPeriodQuery. Query:', salesByPeriodQuery);
      console.log('🔍 SALES REPORT: salesByPeriodParams after end_date:', salesByPeriodParams);
    }
    
    // Add GROUP BY and ORDER BY
    salesByPeriodQuery += ` GROUP BY DATE_FORMAT(s.created_at, '${dateFormat}') ORDER BY period DESC`;
    console.log('🔍 SALES REPORT: Final salesByPeriodQuery with GROUP BY:', salesByPeriodQuery);
    console.log('🔍 SALES REPORT: Final salesByPeriodParams:', salesByPeriodParams);
    
    console.log('SALES REPORT: Sales by period query:', salesByPeriodQuery);
    console.log('SALES REPORT: Sales by period params:', salesByPeriodParams);
    console.log('SALES REPORT: req.user.business_id:', req.user.business_id);
    console.log('SALES REPORT: user_id param:', user_id);
    console.log('SALES REPORT: start_date:', start_date);
    console.log('SALES REPORT: end_date:', end_date);
    
    let salesByPeriod;
    try {
      // Try the normal query first
      console.log('🔍 SALES REPORT: ===== EXECUTING QUERY =====');
      console.log('🔍 SALES REPORT: About to execute query with params:', salesByPeriodParams);
      console.log('🔍 SALES REPORT: Query to execute:', salesByPeriodQuery);
      console.log('🔍 SALES REPORT: Params count:', salesByPeriodParams.length);
      console.log('🔍 SALES REPORT: Params types:', salesByPeriodParams.map(p => typeof p));
      
      [salesByPeriod] = await pool.query(salesByPeriodQuery, salesByPeriodParams);
      
      console.log('✅ SALES REPORT: Query executed successfully!');
      console.log('✅ SALES REPORT: Result count:', salesByPeriod.length);
      console.log('✅ SALES REPORT: Result:', salesByPeriod);
      
    } catch (error) {
      console.log('❌ SALES REPORT: ===== QUERY FAILED =====');
      console.log('❌ SALES REPORT: Error message:', error.message);
      console.log('❌ SALES REPORT: Error code:', error.code);
      console.log('❌ SALES REPORT: Error SQL state:', error.sqlState);
      console.log('❌ SALES REPORT: Failed SQL query:', error.sql);
      console.log('❌ SALES REPORT: Query that failed:', salesByPeriodQuery);
      console.log('❌ SALES REPORT: Params that failed:', salesByPeriodParams);
      
      if (error.code === 'ER_WRONG_FIELD_WITH_GROUP') {
        console.log('⚠️  SALES REPORT: GROUP BY error detected, using relaxed mode...');
        // Fallback to relaxed GROUP BY mode
        salesByPeriod = await executeQueryWithRelaxedGroupBy(salesByPeriodQuery, salesByPeriodParams);
      } else {
        console.log('❌ SALES REPORT: Throwing error - not a GROUP BY issue');
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
    
    console.log('SALES REPORT: Credit calculations:');
    console.log('  - Total Original Credit Amount:', outstandingCredits[0]?.total_original_credit || 0);
    console.log('  - Total Paid Amount:', outstandingCredits[0]?.total_paid_amount || 0);
    console.log('  - Total Outstanding Credit:', outstandingCredits[0]?.total_outstanding_credit || 0);
    
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
    
    // Calculate actual cash in hand using cash flows table
    let cashInHandQuery = `
      SELECT 
        SUM(CASE WHEN type = 'in' THEN amount ELSE 0 END) as total_inflow,
        SUM(CASE WHEN type = 'out' THEN amount ELSE 0 END) as total_outflow
      FROM cash_flows 
      WHERE 1=1
    `;
    let cashInHandParams = [];
    
    // Add business_id filter unless superadmin
    if (req.user.role !== 'superadmin') {
      if (!req.user.business_id) {
        return res.status(400).json({ message: 'Business ID is required for this report.' });
      }
      cashInHandQuery += ' AND business_id = ?';
      cashInHandParams.push(req.user.business_id);
    }
    
    // Add date filters if specified
    if (start_date) {
      cashInHandQuery += ' AND date >= ?';
      cashInHandParams.push(start_date);
    }
    if (end_date) {
      cashInHandQuery += ' AND date <= ?';
      cashInHandParams.push(end_date);
    }
    
    const [cashFlows] = await pool.query(cashInHandQuery, cashInHandParams);
    const totalInflow = Number(cashFlows[0]?.total_inflow) || 0;
    const totalOutflow = Number(cashFlows[0]?.total_outflow) || 0;
    const actualCashInHand = totalInflow - totalOutflow;
    
    console.log('SALES REPORT: Cash in hand calculation:');
    console.log('  - Total Inflow (sales + credit payments):', totalInflow);
    console.log('  - Total Outflow (expenses):', totalOutflow);
    console.log('  - Actual Cash in Hand:', actualCashInHand);
    
    console.log('SALES REPORT: Profit calculation:');
    console.log('  - Total Revenue:', totalRevenue);
    console.log('  - Total COGS:', total_cost);
    console.log('  - Calculated totalProfit:', totalProfit);
    
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

    console.log('🔍 SALES REPORT: ===== PREPARING RESPONSE =====');
    console.log('🔍 SALES REPORT: safeSummary:', safeSummary);
    console.log('🔍 SALES REPORT: safeSalesByPeriod count:', safeSalesByPeriod.length);
    console.log('🔍 SALES REPORT: safePaymentMethods count:', safePaymentMethods.length);
    
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
    
    console.log('🔍 SALES REPORT: Final response object:', response);
    console.log('🔍 SALES REPORT: Cash in hand breakdown:');
    console.log('  - Total Inflow (sales + credit payments):', totalInflow);
    console.log('  - Total Outflow (expenses):', totalOutflow);
    console.log('  - Final Cash in Hand:', actualCashInHand);
    console.log('🔍 SALES REPORT: ===== SUCCESS - END =====');
    
    res.json(response);
  } catch (error) {
    console.log('❌ SALES REPORT: ===== FUNCTION FAILED =====');
    console.log('❌ SALES REPORT: Error in main function:', error);
    console.log('❌ SALES REPORT: Error stack:', error.stack);
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
      console.log(`🔍 Credit Sale #${sale.id} Calculation:`, {
        originalAmount: sale.total_amount,
        totalPaid: totalPaid,
        outstanding: outstanding,
        isFullyPaid: outstanding <= 0
      });
      
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
    const [payments] = await connection.query('SELECT IFNULL(SUM(total_amount),0) as total_paid FROM sales WHERE parent_sale_id = ?', [saleId]);
    const totalPaid = Number(payments[0].total_paid) || 0;
    const remaining = Number(sale.total_amount) - totalPaid;
    if (amount > remaining) {
      return res.status(400).json({ message: 'Payment exceeds amount owed' });
    }
    
    // Insert payment as a new sale row with parent_sale_id set
    await connection.query(
      `INSERT INTO sales (parent_sale_id, customer_id, user_id, total_amount, tax_amount, payment_method, status, business_id)
       VALUES (?, ?, ?, ?, ?, ?, 'completed', ?)`,
      [saleId, sale.customer_id, req.user.id, amount, 0.00, payment_method, sale.business_id]
    );
    
    // Create cash flow entry to increase cash in hand
    await connection.query(
      `INSERT INTO cash_flows (type, amount, date, reference, notes, business_id) 
       VALUES (?, ?, CURDATE(), ?, ?, ?)`,
      ['in', amount, `Credit Payment - Sale #${saleId}`, `Payment received for credit sale #${saleId} via ${payment_method}`, sale.business_id]
    );
    
    // If fully paid, update sale status
    const newTotalPaid = totalPaid + Number(amount);
    if (newTotalPaid >= Number(sale.total_amount)) {
      await connection.query('UPDATE sales SET status = ? WHERE id = ?', ['paid', saleId]);
    }
    
    await connection.commit();
    res.json({ message: 'Payment recorded', remaining: Math.max(0, Number(sale.total_amount) - newTotalPaid) });
  } catch (error) {
    await connection.rollback();
    console.error('Error marking credit sale as paid:', error);
    res.status(500).json({ message: 'Server error' });
  } finally {
    connection.release();
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