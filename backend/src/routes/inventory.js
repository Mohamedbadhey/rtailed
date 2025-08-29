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

// Get inventory transactions
router.get('/transactions', [auth, checkRole(['admin', 'manager', 'cashier'])], async (req, res) => {
  try {
    const { start_date, end_date, user_id } = req.query;
    
    console.log('🔍 INVENTORY TRANSACTIONS: Request params:', { start_date, end_date, user_id });
    console.log('🔍 INVENTORY TRANSACTIONS: User:', req.user.id, req.user.role, req.user.business_id);
    
    let query = `
      SELECT 
        it.id,
        it.created_at,
        it.transaction_type,
        it.quantity,
        it.notes,
        it.reference_id,
        p.name AS product_name,
        s.id AS sale_id,
        s.status,
        s.payment_method,
        s.sale_mode,
        COALESCE(s.user_id, dp.reported_by) AS cashier_id,
        COALESCE(u.username, dp_reporter.username) AS cashier_name,
        c.name AS customer_name,
        si.unit_price AS sale_unit_price,
        si.total_price AS sale_total_price,
        (si.total_price - (si.quantity * p.cost_price)) AS profit
      FROM inventory_transactions it
      LEFT JOIN products p ON it.product_id = p.id
      LEFT JOIN sales s ON it.reference_id = s.id
      LEFT JOIN users u ON s.user_id = u.id
      LEFT JOIN customers c ON s.customer_id = c.id
      LEFT JOIN sale_items si ON si.sale_id = s.id AND si.product_id = it.product_id
      LEFT JOIN damaged_products dp ON it.notes LIKE CONCAT('%Damaged:%') AND dp.product_id = it.product_id AND dp.created_at = it.created_at
      LEFT JOIN users dp_reporter ON dp.reported_by = dp_reporter.id
      WHERE it.business_id = ?
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
      params.push(startDateTime);
      console.log('🔍 INVENTORY TRANSACTIONS: Added start_date filter:', startDateTime);
    }
    if (end_date) {
      // Convert end_date to end of day for proper comparison
      // Handle both ISO strings (with T) and space-separated strings
      let endDateTime;
      if (end_date.includes('T')) {
        // ISO string like "2025-08-29T23:59:59.999Z" - extract just the date part
        const datePart = end_date.split('T')[0];
        endDateTime = datePart + ' 23:59:59';
      } else if (end_date.includes(' ')) {
        // Already has time, use as is
        endDateTime = end_date;
      } else {
        // Just date, add end of day
        endDateTime = end_date + ' 23:59:59';
      }
      query += ' AND it.created_at <= ?';
      params.push(endDateTime);
      console.log('🔍 INVENTORY TRANSACTIONS: Added end_date filter:', endDateTime);
    }
    
    // Add cashier filter if provided
    if (user_id && user_id !== 'all') {
      query += ' AND (s.user_id = ? OR dp.reported_by = ?)';
      params.push(user_id, user_id);
      console.log('🔍 INVENTORY TRANSACTIONS: Added cashier filter:', user_id);
    }
    
    query += ' ORDER BY it.created_at DESC';
    
    if (req.user.role === 'superadmin') {
      query = query.replace('WHERE it.business_id = ?', '');
      params = params.slice(1); // Remove business_id from params
      console.log('🔍 INVENTORY TRANSACTIONS: Superadmin - removed business_id filter');
    }
    
    console.log('🔍 INVENTORY TRANSACTIONS: Final query:', query);
    console.log('🔍 INVENTORY TRANSACTIONS: Final params:', params);
    
    const [transactions] = await pool.query(query, params);
    console.log('🔍 INVENTORY TRANSACTIONS: Found', transactions.length, 'transactions');
    
    res.json(transactions);
  } catch (error) {
    console.error('🔍 INVENTORY TRANSACTIONS ERROR:', error);
    res.status(500).json({ message: error.message || 'Server error' });
  }
});

// Get enhanced inventory transactions for PDF export
router.get('/transactions/pdf', [auth, checkRole(['admin', 'manager', 'cashier'])], async (req, res) => {
  try {
    const { start_date, end_date, user_id, limit } = req.query;
    
    console.log('📄 PDF TRANSACTIONS: Request params:', { start_date, end_date, user_id, limit });
    console.log('📄 PDF TRANSACTIONS: User:', req.user.id, req.user.role, req.user.business_id);
    
    let query = `
      SELECT 
        it.id,
        it.created_at,
        it.transaction_type,
        it.quantity,
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
        (si.total_price - (si.quantity * p.cost_price)) AS profit,
        (si.quantity * p.cost_price) AS total_cost
      FROM inventory_transactions it
      LEFT JOIN products p ON it.product_id = p.id
      LEFT JOIN sales s ON it.reference_id = s.id
      LEFT JOIN users u ON s.user_id = u.id
      LEFT JOIN customers c ON s.customer_id = c.id
      LEFT JOIN sale_items si ON si.sale_id = s.id AND si.product_id = it.product_id
      LEFT JOIN damaged_products dp ON it.notes LIKE CONCAT('%Damaged:%') AND dp.product_id = it.product_id AND dp.created_at = it.created_at
      LEFT JOIN users dp_reporter ON dp.reported_by = dp_reporter.id
      WHERE it.business_id = ?
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
      console.log('📄 PDF TRANSACTIONS: Added start_date filter:', startDateTime);
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
      console.log('📄 PDF TRANSACTIONS: Added end_date filter:', endDateTime);
    }
    
    // Add cashier filter if provided
    if (user_id && user_id !== 'all') {
      query += ' AND (s.user_id = ? OR dp.reported_by = ?)';
      params.push(user_id, user_id);
    }
    
    query += ' ORDER BY it.created_at DESC';
    
    // Add limit if provided
    if (limit) {
      query += ' LIMIT ?';
      params.push(parseInt(limit));
    }
    
    if (req.user.role === 'superadmin') {
      query = query.replace('WHERE it.business_id = ?', '');
      params = params.slice(1); // Remove business_id from params
      console.log('📄 PDF TRANSACTIONS: Superadmin - removed business_id filter');
    }
    
    console.log('📄 PDF TRANSACTIONS: Final query:', query);
    console.log('📄 PDF TRANSACTIONS: Final params:', params);
    
    const [transactions] = await pool.query(query, params);
    console.log('📄 PDF TRANSACTIONS: Found', transactions.length, 'transactions');
    
    res.json(transactions);
  } catch (error) {
    console.error('📄 PDF TRANSACTIONS ERROR:', error);
    res.status(500).json({ message: error.message || 'Server error' });
  }
});

// Get inventory value report
router.get('/value-report', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  try {
    const { start_date, end_date } = req.query;
    // Get all products
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
      ORDER BY p.name
    `;
    let params = [req.user.business_id];
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
        ORDER BY p.name
      `;
      params = [];
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
        const [[{ sold_after = 0 } = {}]] = await pool.query(
          `SELECT IFNULL(SUM(si.quantity),0) as sold_after
           FROM sale_items si
           JOIN sales s ON si.sale_id = s.id
           WHERE si.product_id = ? AND s.created_at >= ?` , [p.id, start_date]);
        // Get all stock added after start_date (purchases, adjustments, etc.)
        const [[{ added_after = 0 } = {}]] = await pool.query(
          `SELECT IFNULL(SUM(CASE WHEN quantity > 0 THEN quantity ELSE 0 END),0) as added_after
           FROM inventory_transactions
           WHERE product_id = ? AND created_at >= ?`, [p.id, start_date]);
        startingQuantity = p.quantity_remaining + sold_after - added_after;
      } else {
        // All-time starting quantity
        const [[{ sold_all = 0 } = {}]] = await pool.query(
          `SELECT IFNULL(SUM(si.quantity),0) as sold_all
           FROM sale_items si WHERE si.product_id = ?`, [p.id]);
        startingQuantity = p.quantity_remaining + sold_all;
      }
      // Sold quantity, revenue, profit in period
      if (start_date && end_date) {
        const [[sales = {}]] = await pool.query(
          `SELECT 
            IFNULL(SUM(si.quantity),0) as sold_qty,
            IFNULL(SUM(si.total_price),0) as revenue,
            IFNULL(SUM(si.total_price - (si.quantity * p.cost_price)),0) as profit
           FROM sale_items si
           JOIN sales s ON si.sale_id = s.id
           JOIN products p ON si.product_id = p.id
           WHERE si.product_id = ? AND s.created_at >= ? AND s.created_at <= ?`, [p.id, start_date, end_date]);
        soldQty = sales.sold_qty || 0;
        revenue = sales.revenue || 0;
        profit = sales.profit || 0;
      } else if (start_date) {
        const [[sales = {}]] = await pool.query(
          `SELECT 
            IFNULL(SUM(si.quantity),0) as sold_qty,
            IFNULL(SUM(si.total_price),0) as revenue,
            IFNULL(SUM(si.total_price - (si.quantity * p.cost_price)),0) as profit
           FROM sale_items si
           JOIN sales s ON si.sale_id = s.id
           JOIN products p ON si.product_id = p.id
           WHERE si.product_id = ? AND s.created_at >= ?`, [p.id, start_date]);
        soldQty = sales.sold_qty || 0;
        revenue = sales.revenue || 0;
        profit = sales.profit || 0;
      } else if (end_date) {
        const [[sales = {}]] = await pool.query(
          `SELECT 
            IFNULL(SUM(si.quantity),0) as sold_qty,
            IFNULL(SUM(si.total_price),0) as revenue,
            IFNULL(SUM(si.total_price - (si.quantity * p.cost_price)),0) as profit
           FROM sale_items si
           JOIN sales s ON si.sale_id = s.id
           JOIN products p ON si.product_id = p.id
           WHERE si.product_id = ? AND s.created_at <= ?`, [p.id, end_date]);
        soldQty = sales.sold_qty || 0;
        revenue = sales.revenue || 0;
        profit = sales.profit || 0;
      } else {
        const [[sales = {}]] = await pool.query(
      `SELECT 
            IFNULL(SUM(si.quantity),0) as sold_qty,
            IFNULL(SUM(si.total_price),0) as revenue,
            IFNULL(SUM(si.total_price - (si.quantity * p.cost_price)),0) as profit
           FROM sale_items si
           JOIN products p ON si.product_id = p.id
           WHERE si.product_id = ?`, [p.id]);
        soldQty = sales.sold_qty || 0;
        revenue = sales.revenue || 0;
        profit = sales.profit || 0;
      }
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