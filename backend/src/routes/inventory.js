const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { auth, checkRole } = require('../middleware/auth');

// Get inventory status
router.get('/', auth, async (req, res) => {
  try {
    const [inventory] = await pool.query(
      `SELECT 
        p.id,
        p.name,
        p.sku,
        p.stock_quantity as stockQuantity,
        p.low_stock_threshold as lowStockThreshold,
        c.name as categoryName
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      ORDER BY p.name`
    );
    res.json(inventory);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get low stock items
router.get('/low-stock', auth, async (req, res) => {
  try {
    const [items] = await pool.query(`
      SELECT 
        p.id,
        p.name,
        p.sku,
        p.stock_quantity as stockQuantity,
        p.low_stock_threshold as lowStockThreshold,
        c.name as categoryName
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.stock_quantity <= p.low_stock_threshold
      ORDER BY p.stock_quantity ASC`
    );
    res.json(items);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Update stock quantity
router.put('/:id/stock', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const { quantity, type, notes } = req.body;
    const productId = req.params.id;

    // Get current stock
    const [products] = await connection.query(
      'SELECT stock_quantity FROM products WHERE id = ?',
      [productId]
    );

    if (products.length === 0) {
      throw new Error('Product not found');
    }

    const currentStock = products[0].stock_quantity;
    let newQuantity;

    if (type === 'add') {
      newQuantity = currentStock + quantity;
    } else if (type === 'subtract') {
      if (currentStock < quantity) {
        throw new Error('Insufficient stock');
      }
      newQuantity = currentStock - quantity;
    } else {
      throw new Error('Invalid operation type');
    }

    // Update product stock
    await connection.query(
      'UPDATE products SET stock_quantity = ? WHERE id = ?',
      [newQuantity, productId]
    );

    const businessId = req.user.business_id;
    // Record transaction
    await connection.query(
      `INSERT INTO inventory_transactions (
        product_id, quantity, transaction_type, notes, business_id
      ) VALUES (?, ?, ?, ?, ?)`,
      [
        productId,
        type === 'add' ? quantity : -quantity,
        'adjustment',
        notes || `${type === 'add' ? 'Added' : 'Removed'} ${quantity} units`,
        businessId
      ]
    );

    await connection.commit();

    res.json({
      message: 'Stock updated successfully',
      new_quantity: newQuantity
    });
  } catch (error) {
    await connection.rollback();
    console.error(error);
    res.status(500).json({ message: error.message || 'Server error' });
  } finally {
    connection.release();
  }
});

router.get('/transactions', [auth, checkRole(['admin', 'manager', 'cashier'])], async (req, res) => {
  try {
    const { start_date, end_date, user_id, category_id, product_id, transaction_type, payment_method, page = 1, limit = 50 } = req.query;
    
    const offset = (parseInt(page) - 1) * parseInt(limit);


    let countQuery = `
      SELECT COUNT(it.id) as total
      FROM inventory_transactions it
      LEFT JOIN products p ON it.product_id = p.id
      LEFT JOIN sales s ON it.reference_id = s.id
      LEFT JOIN damaged_products dp ON dp.id = it.reference_id AND dp.business_id = it.business_id
      WHERE it.business_id = ? AND (s.status IS NULL OR s.status != 'cancelled')
    `;
    let countParams = [req.user.business_id];

    let query = `
      SELECT 
        it.id,
        it.created_at,
        it.transaction_type,
        ABS(it.quantity) AS quantity,
        it.notes,
        it.reference_id,
        p.name AS product_name,
        p.cost_price AS product_cost_price,
        s.id AS sale_id,
        s.status,
        s.payment_method,
        s.sale_mode,
        COALESCE(s.user_id, dp.reported_by) AS cashier_id,
        COALESCE(u.username, dp_reporter.username) AS cashier_name,
        c.name AS customer_name,
        si.unit_price AS sale_unit_price,
        si.total_price AS sale_total_price,
        si.costprice AS sale_cost_price,
        (si.total_price - (si.quantity * COALESCE(si.costprice, p.cost_price))) AS profit
      FROM inventory_transactions it
      LEFT JOIN products p ON it.product_id = p.id
      LEFT JOIN sales s ON it.reference_id = s.id
      LEFT JOIN users u ON s.user_id = u.id
      LEFT JOIN customers c ON s.customer_id = c.id
      LEFT JOIN sale_items si ON si.sale_id = s.id AND si.product_id = it.product_id
      LEFT JOIN damaged_products dp ON dp.id = it.reference_id AND dp.business_id = it.business_id
      LEFT JOIN users dp_reporter ON dp.reported_by = dp_reporter.id
      WHERE it.business_id = ? AND (s.status IS NULL OR s.status != 'cancelled')
    `;
    let params = [req.user.business_id];

    // Add date filters if provided
    if (start_date) {
      // Convert start_date to start of day for proper comparison
      // Handle both ISO strings (with T) and space-separated strings
      let startDateTime;
      if (start_date.includes('T')) {
        // ISO string like "2025-08-29T00:00:00.000Z" - extract just the date part
        const datePart = start_date.split('T')[0];
        startDateTime = datePart + ' 00:00:00';
      } else if (start_date.includes(' ')) {
        // Already has time, use as is
        startDateTime = start_date;
      } else {
        // Just date, add start of day
        startDateTime = start_date + ' 00:00:00';
      }
      query += ' AND it.created_at >= ?';
      countQuery += ' AND it.created_at >= ?';
      params.push(startDateTime);
      countParams.push(startDateTime);
    }
    if (end_date) {
      let endDateTime;
      if (end_date.includes('T')) {
        const datePart = end_date.split('T')[0];
        endDateTime = datePart + ' 23:59:59';
      } else if (end_date.includes(' ')) {
        endDateTime = end_date;
      } else {
        endDateTime = end_date + ' 23:59:59';
      }
      query += ' AND it.created_at <= ?';
      countQuery += ' AND it.created_at <= ?';
      params.push(endDateTime);
      countParams.push(endDateTime);
    }

    if (user_id && user_id !== 'all') {
      query += ' AND (s.user_id = ? OR dp.reported_by = ?)';
      countQuery += ' AND (s.user_id = ? OR dp.reported_by = ?)';
      params.push(user_id, user_id);
      countParams.push(user_id, user_id);
    }

    if (category_id) {
      query += ' AND p.category_id = ?';
      countQuery += ' AND p.category_id = ?';
      params.push(category_id);
      countParams.push(category_id);
    }

    if (product_id) {
      query += ' AND it.product_id = ?';
      countQuery += ' AND it.product_id = ?';
      params.push(product_id);
      countParams.push(product_id);
    }

    if (transaction_type) {
      query += ' AND it.transaction_type = ?';
      countQuery += ' AND it.transaction_type = ?';
      params.push(transaction_type);
      countParams.push(transaction_type);
    }

    if (payment_method) {
      query += ' AND s.payment_method = ?';
      countQuery += ' AND s.payment_method = ?';
      params.push(payment_method);
      countParams.push(payment_method);
    }

    query += ' ORDER BY it.created_at DESC LIMIT ? OFFSET ?';
    params.push(parseInt(limit), offset);

    if (req.user.role === 'superadmin') {
      query = query.replace('WHERE it.business_id = ? AND (s.status IS NULL OR s.status != \'cancelled\')', 'WHERE (s.status IS NULL OR s.status != \'cancelled\')');
      countQuery = countQuery.replace('WHERE it.business_id = ? AND (s.status IS NULL OR s.status != \'cancelled\')', 'WHERE (s.status IS NULL OR s.status != \'cancelled\')');
      params = params.slice(1);
      countParams = countParams.slice(1);
    }

    const [transactions] = await pool.query(query, params);
    const [countResult] = await pool.query(countQuery, countParams);
    const totalCount = countResult[0].total;

    res.json({
      items: transactions,
      total: totalCount,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(totalCount / parseInt(limit))
    });
  } catch (error) {
    res.status(500).json({ message: error.message || 'Server error' });
  }
});

router.get('/transactions/pdf', [auth, checkRole(['admin', 'manager', 'cashier'])], async (req, res) => {
  try {
    const { start_date, end_date, user_id, category_id, product_id, transaction_type, payment_method, limit } = req.query;

    console.log('ðŸ“„ PDF TRANSACTIONS: Request params:', { start_date, end_date, user_id, limit });
    console.log('ðŸ“„ PDF TRANSACTIONS: User:', req.user.id, req.user.role, req.user.business_id);

    let query = `
      SELECT 
        it.id,
        it.created_at,
        it.transaction_type,
        ABS(it.quantity) AS quantity,
        it.notes,
        it.reference_id,
        p.name AS product_name,
        p.sku AS product_sku,
        p.cost_price AS product_cost_price,
        p.price AS product_price,
        s.id AS sale_id,
        s.status,
        s.payment_method,
        s.sale_mode,
        COALESCE(s.user_id, dp.reported_by) AS cashier_id,
        COALESCE(u.username, dp_reporter.username) AS cashier_name,
        c.name AS customer_name,
        si.unit_price AS sale_unit_price,
        si.total_price AS sale_total_price,
        si.costprice AS sale_cost_price,
        (si.total_price - (si.quantity * COALESCE(si.costprice, p.cost_price))) AS profit,
        (si.quantity * COALESCE(si.costprice, p.cost_price)) AS total_cost
      FROM inventory_transactions it
      LEFT JOIN products p ON it.product_id = p.id
      LEFT JOIN sales s ON it.reference_id = s.id
      LEFT JOIN users u ON s.user_id = u.id
      LEFT JOIN customers c ON s.customer_id = c.id
      LEFT JOIN sale_items si ON si.sale_id = s.id AND si.product_id = it.product_id
      LEFT JOIN damaged_products dp ON dp.id = it.reference_id AND dp.business_id = it.business_id
      LEFT JOIN users dp_reporter ON dp.reported_by = dp_reporter.id
      WHERE it.business_id = ? AND (s.status IS NULL OR s.status != 'cancelled')
    `;
    let params = [req.user.business_id];

    // Add date filters if provided
    if (start_date) {
      // Convert start_date to start of day for proper comparison
      let startDateTime;
      if (start_date.includes('T')) {
        const datePart = start_date.split('T')[0];
        startDateTime = datePart + ' 00:00:00';
      } else if (start_date.includes(' ')) {
        startDateTime = start_date;
      } else {
        startDateTime = start_date + ' 00:00:00';
      }
      query += ' AND it.created_at >= ?';
      params.push(startDateTime);
      console.log('ðŸ“„ PDF TRANSACTIONS: Added start_date filter:', startDateTime);
    }
    if (end_date) {
      // Convert end_date to end of day for proper comparison
      let endDateTime;
      if (end_date.includes('T')) {
        const datePart = end_date.split('T')[0];
        endDateTime = datePart + ' 23:59:59';
      } else if (end_date.includes(' ')) {
        endDateTime = end_date;
      } else {
        endDateTime = end_date + ' 23:59:59';
      }
      query += ' AND it.created_at <= ?';
      params.push(endDateTime);
      console.log('ðŸ“„ PDF TRANSACTIONS: Added end_date filter:', endDateTime);
    }

    // Add cashier filter if provided
    if (user_id && user_id !== 'all') {
      query += ' AND (s.user_id = ? OR dp.reported_by = ?)';
      params.push(user_id, user_id);
    }

    // Add category filter if provided
    if (category_id) {
      query += ' AND p.category_id = ?';
      params.push(category_id);
      console.log('ðŸ“„ PDF TRANSACTIONS: Added category filter:', category_id);
    }

    // Add product filter if provided
    if (product_id) {
      query += ' AND it.product_id = ?';
      params.push(product_id);
      console.log('ðŸ“„ PDF TRANSACTIONS: Added product filter:', product_id);
    }

    // Add transaction type filter if provided
    if (transaction_type) {
      query += ' AND it.transaction_type = ?';
      params.push(transaction_type);
      console.log('ðŸ“„ PDF TRANSACTIONS: Added transaction_type filter:', transaction_type);
    }

    // Add payment method filter if provided
    if (payment_method) {
      query += ' AND s.payment_method = ?';
      params.push(payment_method);
      console.log('ðŸ“„ PDF TRANSACTIONS: Added payment_method filter:', payment_method);
    }

    query += ' ORDER BY it.created_at DESC';

    // Add limit if provided
    if (limit) {
      query += ' LIMIT ?';
      params.push(parseInt(limit));
    }

    if (req.user.role === 'superadmin') {
      query = query.replace('WHERE it.business_id = ? AND (s.status IS NULL OR s.status != \'cancelled\')', 'WHERE (s.status IS NULL OR s.status != \'cancelled\')');
      params = params.slice(1); // Remove business_id from params
      console.log('ðŸ“„ PDF TRANSACTIONS: Superadmin - removed business_id filter');
    }

    console.log('ðŸ“„ PDF TRANSACTIONS: Final query:', query);
    console.log('ðŸ“„ PDF TRANSACTIONS: Final params:', params);

    const [transactions] = await pool.query(query, params);
    console.log('ðŸ“„ PDF TRANSACTIONS: Found', transactions.length, 'transactions');

    res.json(transactions);
  } catch (error) {
    console.error('ðŸ“„ PDF TRANSACTIONS ERROR:', error);
    res.status(500).json({ message: error.message || 'Server error' });
  }
});

// Get inventory value report
router.get('/value-report', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  try {
    const { start_date, end_date, category_id, product_id } = req.query;
    // Get all products with optional filtering
    let query = `
      SELECT 
        p.id,
        p.name,
        p.sku,
        p.stock_quantity as quantity_remaining,
        p.low_stock_threshold,
        c.name as categoryName
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.business_id = ?
    `;
    let params = [req.user.business_id];

    // Add category filter
    if (category_id && category_id !== 'All') {
      query += ` AND p.category_id = ?`;
      params.push(category_id);
    }

    // Add product filter
    if (product_id && product_id !== 'All') {
      query += ` AND p.id = ?`;
      params.push(product_id);
    }

    query += ` ORDER BY p.name`;

    if (req.user.role === 'superadmin') {
      query = `
        SELECT 
          p.id,
          p.name,
          p.sku,
          p.stock_quantity as quantity_remaining,
          p.low_stock_threshold,
          c.name as categoryName
        FROM products p
        LEFT JOIN categories c ON p.category_id = c.id
        WHERE 1=1
      `;
      params = [];

      // Add category filter for superadmin
      if (category_id && category_id !== 'All') {
        query += ` AND p.category_id = ?`;
        params.push(category_id);
      }

      // Add product filter for superadmin
      if (product_id && product_id !== 'All') {
        query += ` AND p.id = ?`;
        params.push(product_id);
      }

      query += ` ORDER BY p.name`;
    }
    const [products] = await pool.query(query, params);

    // For each product, calculate starting quantity, sold quantity, revenue, and profit in the period
    const productDetails = await Promise.all(products.map(async (p) => {
      // Starting quantity: stock at start_date = current + all sold after start_date - all added after start_date
      // If no start_date, use all-time
      let startingQuantity = p.quantity_remaining;
      let soldQty = 0;
      let revenue = 0;
      let profit = 0;
      if (start_date) {
        // Get all sales after start_date
        // Format start date the same way as transactions
        let startDateTime;

        if (start_date.includes('T')) {
          const datePart = start_date.split('T')[0];
          startDateTime = datePart + ' 00:00:00';
        } else if (start_date.includes(' ')) {
          startDateTime = start_date;
        } else {
          startDateTime = start_date + ' 00:00:00';
        }

        const [[{ sold_after = 0 } = {}]] = await pool.query(
          `SELECT IFNULL(SUM(ABS(it.quantity)),0) as sold_after
           FROM inventory_transactions it
           LEFT JOIN sales s ON it.reference_id = s.id AND s.business_id = it.business_id
           WHERE it.product_id = ? AND it.created_at >= ? AND it.business_id = ? AND it.transaction_type = 'sale' AND (s.status IS NULL OR s.status != 'cancelled')` , [p.id, startDateTime, req.user.business_id]);
        // Get all stock added after start_date (purchases, adjustments, etc.)
        const [[{ added_after = 0 } = {}]] = await pool.query(
          `SELECT IFNULL(SUM(CASE WHEN quantity > 0 THEN quantity ELSE 0 END),0) as added_after
           FROM inventory_transactions
           WHERE product_id = ? AND created_at >= ?`, [p.id, startDateTime]);
        startingQuantity = p.quantity_remaining + sold_after - added_after;
      } else {
        // All-time starting quantity
        const [[{ sold_all = 0 } = {}]] = await pool.query(
          `SELECT IFNULL(SUM(ABS(it.quantity)),0) as sold_all
           FROM inventory_transactions it
           LEFT JOIN sales s ON it.reference_id = s.id AND s.business_id = it.business_id
           WHERE it.product_id = ? AND it.business_id = ? AND it.transaction_type = 'sale' AND (s.status IS NULL OR s.status != 'cancelled')`, [p.id, req.user.business_id]);
        startingQuantity = p.quantity_remaining + sold_all;
      }
      // Sold quantity, revenue, profit in period
      if (start_date && end_date) {
        // Format dates the same way as transactions
        let startDateTime, endDateTime;

        if (start_date.includes('T')) {
          const datePart = start_date.split('T')[0];
          startDateTime = datePart + ' 00:00:00';
        } else if (start_date.includes(' ')) {
          startDateTime = start_date;
        } else {
          startDateTime = start_date + ' 00:00:00';
        }

        if (end_date.includes('T')) {
          const datePart = end_date.split('T')[0];
          endDateTime = datePart + ' 23:59:59';
        } else if (end_date.includes(' ')) {
          endDateTime = end_date;
        } else {
          endDateTime = end_date + ' 23:59:59';
        }

        const [[sales = {}]] = await pool.query(
          `SELECT 
            IFNULL(SUM(ABS(it.quantity)),0) as sold_qty,
            IFNULL(SUM(COALESCE(si.total_price, 0)),0) as revenue,
            IFNULL(SUM(COALESCE((si.unit_price - COALESCE(si.costprice, p.cost_price, 0)) * ABS(it.quantity), 0)),0) as profit
           FROM inventory_transactions it
           LEFT JOIN sales s ON it.reference_id = s.id AND s.business_id = it.business_id
           LEFT JOIN sale_items si ON si.sale_id = s.id AND si.product_id = it.product_id AND si.business_id = it.business_id
           LEFT JOIN products p ON it.product_id = p.id AND p.business_id = it.business_id
           WHERE it.product_id = ? AND it.created_at >= ? AND it.created_at <= ? AND it.business_id = ? AND it.transaction_type = 'sale' AND (s.status IS NULL OR s.status != 'cancelled')`, [p.id, startDateTime, endDateTime, req.user.business_id]);
        soldQty = sales.sold_qty || 0;
        revenue = sales.revenue || 0;
        profit = sales.profit || 0;
      } else if (start_date) {
        // Format start date the same way as transactions
        let startDateTime;

        if (start_date.includes('T')) {
          const datePart = start_date.split('T')[0];
          startDateTime = datePart + ' 00:00:00';
        } else if (start_date.includes(' ')) {
          startDateTime = start_date;
        } else {
          startDateTime = start_date + ' 00:00:00';
        }

        const [[sales = {}]] = await pool.query(
          `SELECT 
            IFNULL(SUM(ABS(it.quantity)),0) as sold_qty,
            IFNULL(SUM(COALESCE(si.total_price, 0)),0) as revenue,
            IFNULL(SUM(COALESCE((si.unit_price - COALESCE(si.costprice, p.cost_price, 0)) * ABS(it.quantity), 0)),0) as profit
           FROM inventory_transactions it
           LEFT JOIN sales s ON it.reference_id = s.id AND s.business_id = it.business_id
           LEFT JOIN sale_items si ON si.sale_id = s.id AND si.product_id = it.product_id AND si.business_id = it.business_id
           LEFT JOIN products p ON it.product_id = p.id AND p.business_id = it.business_id
           WHERE it.product_id = ? AND it.created_at >= ? AND it.business_id = ? AND it.transaction_type = 'sale' AND (s.status IS NULL OR s.status != 'cancelled')`, [p.id, startDateTime, req.user.business_id]);
        soldQty = sales.sold_qty || 0;
        revenue = sales.revenue || 0;
        profit = sales.profit || 0;
      } else if (end_date) {
        // Format end date the same way as transactions
        let endDateTime;

        if (end_date.includes('T')) {
          const datePart = end_date.split('T')[0];
          endDateTime = datePart + ' 23:59:59';
        } else if (end_date.includes(' ')) {
          endDateTime = end_date;
        } else {
          endDateTime = end_date + ' 23:59:59';
        }

        const [[sales = {}]] = await pool.query(
          `SELECT 
            IFNULL(SUM(ABS(it.quantity)),0) as sold_qty,
            IFNULL(SUM(COALESCE(si.total_price, 0)),0) as revenue,
            IFNULL(SUM(COALESCE((si.unit_price - COALESCE(si.costprice, p.cost_price, 0)) * ABS(it.quantity), 0)),0) as profit
           FROM inventory_transactions it
           LEFT JOIN sales s ON it.reference_id = s.id AND s.business_id = it.business_id
           LEFT JOIN sale_items si ON si.sale_id = s.id AND si.product_id = it.product_id AND si.business_id = it.business_id
           LEFT JOIN products p ON it.product_id = p.id AND p.business_id = it.business_id
           WHERE it.product_id = ? AND it.created_at <= ? AND it.business_id = ? AND it.transaction_type = 'sale' AND (s.status IS NULL OR s.status != 'cancelled')`, [p.id, endDateTime, req.user.business_id]);
        soldQty = sales.sold_qty || 0;
        revenue = sales.revenue || 0;
        profit = sales.profit || 0;
      } else {
        const [[sales = {}]] = await pool.query(
          `SELECT 
            IFNULL(SUM(ABS(it.quantity)),0) as sold_qty,
            IFNULL(SUM(COALESCE(si.total_price, 0)),0) as revenue,
            IFNULL(SUM(COALESCE((si.unit_price - COALESCE(si.costprice, p.cost_price, 0)) * ABS(it.quantity), 0)),0) as profit
           FROM inventory_transactions it
           LEFT JOIN sales s ON it.reference_id = s.id AND s.business_id = it.business_id
           LEFT JOIN sale_items si ON si.sale_id = s.id AND si.product_id = it.product_id AND si.business_id = it.business_id
           LEFT JOIN products p ON it.product_id = p.id AND p.business_id = it.business_id
           WHERE it.product_id = ? AND it.business_id = ? AND it.transaction_type = 'sale' AND (s.status IS NULL OR s.status != 'cancelled')`, [p.id, req.user.business_id]);
        soldQty = sales.sold_qty || 0;
        revenue = sales.revenue || 0;
        profit = sales.profit || 0;
      }
      // Debug logging

      return {
        product_id: p.id,
        product_name: p.name,
        sku: p.sku,
        category_name: p.categoryName,
        starting_quantity: startingQuantity,
        quantity_sold: soldQty,
        quantity_remaining: p.quantity_remaining,
        revenue,
        profit,
        low_stock_threshold: p.low_stock_threshold,
        is_low_stock: p.quantity_remaining <= p.low_stock_threshold
      };
    }));
    res.json({ products: productDetails });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router; 
