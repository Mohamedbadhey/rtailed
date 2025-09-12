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
    const { start_date, end_date, user_id, category_id, product_id, transaction_type } = req.query;
    
    console.log('🔍 INVENTORY TRANSACTIONS: Request params:', { start_date, end_date, user_id });
    console.log('🔍 INVENTORY TRANSACTIONS: User:', req.user.id, req.user.role, req.user.business_id);
    console.log('🔍 INVENTORY TRANSACTIONS: Business ID type:', typeof req.user.business_id);
    console.log('🔍 INVENTORY TRANSACTIONS: Business ID value:', req.user.business_id);
    
    // Test: Run the exact working query to see if it works
    try {
      const [testWorkingQuery] = await pool.query(
        `SELECT 
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
        ORDER BY it.created_at DESC
        LIMIT 3`,
        [req.user.business_id]
      );
      console.log('🔍 INVENTORY TRANSACTIONS: Test working query result:', testWorkingQuery);
      
      if (testWorkingQuery.length > 0) {
        const firstResult = testWorkingQuery[0];
        console.log('🔍 INVENTORY TRANSACTIONS: First result fields:', Object.keys(firstResult));
        console.log('🔍 INVENTORY TRANSACTIONS: Has product_cost_price:', firstResult.hasOwnProperty('product_cost_price'));
        console.log('🔍 INVENTORY TRANSACTIONS: product_cost_price value:', firstResult.product_cost_price);
        
        // Check for case sensitivity issues - look for any field that might contain 'cost'
        const costRelatedFields = Object.keys(firstResult).filter(key => 
          key.toLowerCase().includes('cost') || 
          key.toLowerCase().includes('price')
        );
        console.log('🔍 INVENTORY TRANSACTIONS: Cost/price related fields:', costRelatedFields);
        
        // Check raw data for any field variations
        console.log('🔍 INVENTORY TRANSACTIONS: Raw first result:', JSON.stringify(firstResult, null, 2));
        
        // Test: Check if MySQL is returning the field with different case
        const allFields = Object.keys(firstResult);
        const costFieldVariations = allFields.filter(key => 
          key.toLowerCase().includes('cost') || 
          key.toLowerCase().includes('price')
        );
        console.log('🔍 INVENTORY TRANSACTIONS: All fields with cost/price:', costFieldVariations);
        
        // Test: Check if the field exists with exact case match
        console.log('🔍 INVENTORY TRANSACTIONS: Exact field checks:');
        console.log('  product_cost_price:', firstResult.product_cost_price);
        console.log('  PRODUCT_COST_PRICE:', firstResult.PRODUCT_COST_PRICE);
        console.log('  Product_Cost_Price:', firstResult.Product_Cost_Price);
        console.log('  productCostPrice:', firstResult.productCostPrice);
      }
    } catch (testError) {
      console.log('🔍 INVENTORY TRANSACTIONS: Error testing working query:', testError.message);
    }
    
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
    
    // Add category filter if provided
    if (category_id) {
      query += ' AND p.category_id = ?';
      params.push(category_id);
      console.log('🔍 INVENTORY TRANSACTIONS: Added category filter:', category_id);
    }
    
    // Add product filter if provided
    if (product_id) {
      query += ' AND it.product_id = ?';
      params.push(product_id);
      console.log('🔍 INVENTORY TRANSACTIONS: Added product filter:', product_id);
    }
    
    // Add transaction type filter if provided
    if (transaction_type) {
      query += ' AND it.transaction_type = ?';
      params.push(transaction_type);
      console.log('🔍 INVENTORY TRANSACTIONS: Added transaction_type filter:', transaction_type);
    }
    
    query += ' ORDER BY it.created_at DESC';
    
    if (req.user.role === 'superadmin') {
      query = query.replace('WHERE it.business_id = ?', '');
      params = params.slice(1); // Remove business_id from params
      console.log('🔍 INVENTORY TRANSACTIONS: Superadmin - removed business_id filter');
    } else {
      console.log('🔍 INVENTORY TRANSACTIONS: Regular user - using business_id filter:', req.user.business_id);
    }
    
    console.log('🔍 INVENTORY TRANSACTIONS: Final query:', query);
    console.log('🔍 INVENTORY TRANSACTIONS: Final params:', params);
    
    // Test: Check if products table has cost_price data
    try {
      const [testProducts] = await pool.query(
        'SELECT id, name, cost_price FROM products WHERE business_id = ? LIMIT 3',
        [req.user.business_id]
      );
      console.log('🔍 INVENTORY TRANSACTIONS: Test products with cost_price:', testProducts);
      
      // Test: Check inventory_transactions to see what product_ids we have
      const [testTransactions] = await pool.query(
        'SELECT id, product_id, transaction_type, reference_id FROM inventory_transactions WHERE business_id = ? LIMIT 5',
        [req.user.business_id]
      );
      console.log('🔍 INVENTORY TRANSACTIONS: Test inventory_transactions:', testTransactions);
      
      // Test: Check if the JOIN is working by testing a specific transaction
      if (testTransactions.length > 0) {
        const testTx = testTransactions[0];
        const [testJoin] = await pool.query(
          `SELECT 
            it.id,
            it.product_id,
            it.business_id AS transaction_business_id,
            p.id AS product_table_id,
            p.business_id AS product_business_id,
            p.name AS product_name,
            p.cost_price AS product_cost_price
          FROM inventory_transactions it
          LEFT JOIN products p ON it.product_id = p.id
          WHERE it.id = ?`,
          [testTx.id]
        );
        console.log('🔍 INVENTORY TRANSACTIONS: Test JOIN result:', testJoin);
        
        // Test: Check if products exist for this business
        const [productsForBusiness] = await pool.query(
          'SELECT id, name, cost_price, business_id FROM products WHERE business_id = ? LIMIT 3',
          [req.user.business_id]
        );
        console.log('🔍 INVENTORY TRANSACTIONS: Products for business:', productsForBusiness);
        
        // Test: Check if the JOIN condition is working by testing the exact JOIN
        const [testExactJoin] = await pool.query(
          `SELECT 
            it.id,
            it.product_id,
            it.business_id AS transaction_business_id,
            p.id AS product_table_id,
            p.business_id AS product_business_id,
            p.name AS product_name,
            p.cost_price AS product_cost_price
          FROM inventory_transactions it
          LEFT JOIN products p ON it.product_id = p.id
          WHERE it.business_id = ?
          LIMIT 3`,
          [req.user.business_id]
        );
        console.log('🔍 INVENTORY TRANSACTIONS: Test exact JOIN with business filter:', testExactJoin);
      }
    } catch (testError) {
      console.log('🔍 INVENTORY TRANSACTIONS: Error testing products:', testError.message);
    }
    
    const [transactions] = await pool.query(query, params);
    console.log('🔍 INVENTORY TRANSACTIONS: Found', transactions.length, 'transactions');
    
    // Test: Check what fields are actually returned
    if (transactions.length > 0) {
      const firstTx = transactions[0];
      console.log('🔍 INVENTORY TRANSACTIONS: First transaction fields:');
      console.log('  All keys:', Object.keys(firstTx));
      console.log('  Raw data:', firstTx);
    }
    
    // Debug: Log first few transactions to see the data structure
    if (transactions.length > 0) {
      console.log('🔍 INVENTORY TRANSACTIONS: Sample transaction data:');
      for (let i = 0; i < Math.min(3, transactions.length); i++) {
        const tx = transactions[i];
        console.log(`  Transaction ${i}:`);
        console.log(`    Product: ${tx.product_name}`);
        console.log(`    Cost Price: ${tx.product_cost_price} (type: ${typeof tx.product_cost_price})`);
        console.log(`    Unit Price: ${tx.sale_unit_price} (type: ${typeof tx.sale_unit_price})`);
        console.log(`    Total Price: ${tx.sale_total_price} (type: ${typeof tx.sale_total_price})`);
        console.log(`    Profit: ${tx.profit} (type: ${typeof tx.profit})`);
        console.log(`    Transaction Type: ${tx.transaction_type}`);
        console.log(`    Reference ID: ${tx.reference_id}`);
        console.log(`    Sale ID: ${tx.sale_id}`);
        console.log(`    ---`);
      }
    }
    
    res.json(transactions);
  } catch (error) {
    console.error('🔍 INVENTORY TRANSACTIONS ERROR:', error);
    res.status(500).json({ message: error.message || 'Server error' });
  }
});

// Get enhanced inventory transactions for PDF export
router.get('/transactions/pdf', [auth, checkRole(['admin', 'manager', 'cashier'])], async (req, res) => {
  try {
    const { start_date, end_date, user_id, category_id, product_id, transaction_type, limit } = req.query;
    
    console.log('📄 PDF TRANSACTIONS: Request params:', { start_date, end_date, user_id, limit });
    console.log('📄 PDF TRANSACTIONS: User:', req.user.id, req.user.role, req.user.business_id);
    
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
    
    // Add category filter if provided
    if (category_id) {
      query += ' AND p.category_id = ?';
      params.push(category_id);
      console.log('📄 PDF TRANSACTIONS: Added category filter:', category_id);
    }
    
    // Add product filter if provided
    if (product_id) {
      query += ' AND it.product_id = ?';
      params.push(product_id);
      console.log('📄 PDF TRANSACTIONS: Added product filter:', product_id);
    }
    
    // Add transaction type filter if provided
    if (transaction_type) {
      query += ' AND it.transaction_type = ?';
      params.push(transaction_type);
      console.log('📄 PDF TRANSACTIONS: Added transaction_type filter:', transaction_type);
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
            IFNULL(SUM(COALESCE((si.unit_price - COALESCE(p.cost_price, 0)) * ABS(it.quantity), 0)),0) as profit
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
            IFNULL(SUM(COALESCE((si.unit_price - COALESCE(p.cost_price, 0)) * ABS(it.quantity), 0)),0) as profit
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
            IFNULL(SUM(COALESCE((si.unit_price - COALESCE(p.cost_price, 0)) * ABS(it.quantity), 0)),0) as profit
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
            IFNULL(SUM(COALESCE((si.unit_price - COALESCE(p.cost_price, 0)) * ABS(it.quantity), 0)),0) as profit
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
      console.log(`🔍 STOCK SUMMARY: Product ${p.id} (${p.name}): sold=${soldQty} (from inventory_transactions, transaction_type='sale'), revenue=${revenue}, profit=${profit}, cost_price=${p.cost_price}`);
      console.log(`🔍 STOCK SUMMARY: Date filters - start_date: ${start_date}, end_date: ${end_date}`);
      
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