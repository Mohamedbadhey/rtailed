const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { auth, checkRole } = require('../middleware/auth');

// =====================================================
// STORE INVENTORY MANAGEMENT API
// =====================================================

// Add products to store inventory (with increment tracking)
router.post('/:storeId/add-products', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { storeId } = req.params;
    const { business_id, products } = req.body; // products: [{product_id, quantity, unit_cost, notes}]
    const user = req.user;
    
    if (!business_id || !products || products.length === 0) {
      return res.status(400).json({ message: 'Business ID and products are required' });
    }
    
    // Check if user has access to this store and business
    if (user.role !== 'superadmin') {
      const [accessCheck] = await pool.query(
        `SELECT 1 FROM store_business_assignments sba 
         WHERE sba.store_id = ? AND sba.business_id = ? AND sba.is_active = 1`,
        [storeId, business_id]
      );
      
      if (accessCheck.length === 0) {
        return res.status(403).json({ message: 'Access denied: No permission for this store-business combination' });
      }
    }
    
    // Start transaction
    const connection = await pool.getConnection();
    await connection.beginTransaction();
    
    try {
      const results = [];
      
      for (const product of products) {
        const { product_id, quantity, unit_cost, notes } = product;
        
        if (!product_id || !quantity || !unit_cost) {
          throw new Error('Product ID, quantity, and unit cost are required for each product');
        }
        
        // Check if inventory record already exists
        const [existing] = await connection.query(
          'SELECT id, quantity FROM store_product_inventory WHERE store_id = ? AND business_id = ? AND product_id = ?',
          [storeId, business_id, product_id]
        );
        
        if (existing.length > 0) {
          // Update existing inventory (increment)
          const currentQuantity = existing[0].quantity;
          const newQuantity = currentQuantity + quantity;
          
          await connection.query(
            'UPDATE store_product_inventory SET quantity = ?, updated_by = ?, last_updated = CURRENT_TIMESTAMP WHERE id = ?',
            [newQuantity, user.id, existing[0].id]
          );
          
          // Record the increment movement
          await connection.query(
            `INSERT INTO store_inventory_movements (
              store_id, business_id, product_id, movement_type, 
              quantity_change, quantity_before, quantity_after,
              reference_type, notes, created_by
            ) VALUES (?, ?, ?, 'in', ?, ?, ?, 'manual', ?, ?)`,
            [storeId, business_id, product_id, quantity, currentQuantity, newQuantity, notes || 'Product increment', user.id]
          );
          
          results.push({
            product_id,
            action: 'incremented',
            previous_quantity: currentQuantity,
            added_quantity: quantity,
            new_quantity: newQuantity
          });
        } else {
          // Create new inventory record
          const [inventoryResult] = await connection.query(
            `INSERT INTO store_product_inventory (
              store_id, business_id, product_id, quantity, updated_by
            ) VALUES (?, ?, ?, ?, ?)`,
            [storeId, business_id, product_id, quantity, user.id]
          );
          
          // Record the initial movement (handled by trigger, but we can add notes)
          await connection.query(
            `INSERT INTO store_inventory_movements (
              store_id, business_id, product_id, movement_type, 
              quantity_change, quantity_before, quantity_after,
              reference_type, notes, created_by
            ) VALUES (?, ?, ?, 'in', ?, 0, ?, 'manual', ?, ?)`,
            [storeId, business_id, product_id, quantity, quantity, notes || 'Initial product addition', user.id]
          );
          
          results.push({
            product_id,
            action: 'created',
            previous_quantity: 0,
            added_quantity: quantity,
            new_quantity: quantity
          });
        }
      }
      
      await connection.commit();
      
      // Log the action
      await pool.query(
        'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
        [user.id, 'ADD_PRODUCTS_TO_STORE', 'store_product_inventory', storeId, JSON.stringify({ business_id, products_count: products.length, results })]
      );
      
      res.status(201).json({ 
        message: 'Products added to store successfully',
        results
      });
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error('Error adding products to store:', error);
    res.status(500).json({ message: error.message || 'Server error' });
  }
});

// Transfer products from store to business
router.post('/:storeId/transfer-to-business', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { storeId } = req.params;
    const { to_business_id, products, notes } = req.body; // products: [{product_id, quantity, unit_cost}]
    const user = req.user;
    const from_business_id = user.business_id;
    
    if (!to_business_id || !products || products.length === 0) {
      return res.status(400).json({ message: 'To business ID and products are required' });
    }
    
    // Check if user has access to this store
    if (user.role !== 'superadmin') {
      const [accessCheck] = await pool.query(
        `SELECT 1 FROM store_business_assignments sba 
         WHERE sba.store_id = ? AND sba.business_id = ? AND sba.is_active = 1`,
        [storeId, from_business_id]
      );
      
      if (accessCheck.length === 0) {
        return res.status(403).json({ message: 'Access denied: No permission for this store' });
      }
    }
    
    // Start transaction
    const connection = await pool.getConnection();
    await connection.beginTransaction();
    
    try {
      const results = [];
      
      for (const product of products) {
        const { product_id, quantity, unit_cost } = product;
        
        // Check if store has enough inventory
        const [storeInventory] = await connection.query(
          'SELECT quantity FROM store_product_inventory WHERE store_id = ? AND business_id = ? AND product_id = ?',
          [storeId, from_business_id, product_id]
        );
        
        if (storeInventory.length === 0 || storeInventory[0].quantity < quantity) {
          throw new Error(`Insufficient inventory for product ID ${product_id}. Available: ${storeInventory[0]?.quantity || 0}, Requested: ${quantity}`);
        }
        
        const currentQuantity = storeInventory[0].quantity;
        const newQuantity = currentQuantity - quantity;
        
        // Update store inventory (reduce)
        await connection.query(
          'UPDATE store_product_inventory SET quantity = ?, updated_by = ?, last_updated = CURRENT_TIMESTAMP WHERE store_id = ? AND business_id = ? AND product_id = ?',
          [newQuantity, user.id, storeId, from_business_id, product_id]
        );
        
        // Record store inventory movement (out)
        await connection.query(
          `INSERT INTO store_inventory_movements (
            store_id, business_id, product_id, movement_type, 
            quantity_change, quantity_before, quantity_after,
            reference_type, notes, created_by
          ) VALUES (?, ?, ?, 'transfer_out', ?, ?, ?, 'transfer', ?, ?)`,
          [storeId, from_business_id, product_id, -quantity, currentQuantity, newQuantity, notes || 'Transfer to business', user.id]
        );
        
        // Update business product inventory (increase)
        const [businessInventory] = await connection.query(
          'SELECT id, stock_quantity FROM products WHERE id = ? AND business_id = ?',
          [product_id, to_business_id]
        );
        
        if (businessInventory.length === 0) {
          throw new Error(`Product ID ${product_id} not found in target business`);
        }
        
        const currentBusinessQuantity = businessInventory[0].stock_quantity;
        const newBusinessQuantity = currentBusinessQuantity + quantity;
        
        await connection.query(
          'UPDATE products SET stock_quantity = ? WHERE id = ?',
          [newBusinessQuantity, product_id]
        );
        
        // Record business inventory movement (in)
        await connection.query(
          `INSERT INTO inventory_transactions (
            product_id, transaction_type, quantity, 
            quantity_before, quantity_after, notes, created_by
          ) VALUES (?, 'transfer_in', ?, ?, ?, ?, ?)`,
          [product_id, quantity, currentBusinessQuantity, newBusinessQuantity, notes || 'Transfer from store', user.id]
        );
        
        results.push({
          product_id,
          store_quantity_before: currentQuantity,
          store_quantity_after: newQuantity,
          business_quantity_before: currentBusinessQuantity,
          business_quantity_after: newBusinessQuantity,
          transferred_quantity: quantity
        });
      }
      
      await connection.commit();
      
      // Log the action
      await pool.query(
        'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
        [user.id, 'TRANSFER_STORE_TO_BUSINESS', 'store_product_inventory', storeId, JSON.stringify({ to_business_id, products_count: products.length, results })]
      );
      
      res.status(201).json({ 
        message: 'Products transferred to business successfully',
        results
      });
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error('Error transferring products to business:', error);
    res.status(500).json({ message: error.message || 'Server error' });
  }
});

// Get store inventory for a specific business
router.get('/:storeId/inventory/:businessId', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { storeId, businessId } = req.params;
    const user = req.user;
    
    console.log(`🔍 Store Inventory Request: storeId=${storeId}, businessId=${businessId}, userRole=${user.role}, userBusinessId=${user.business_id}`);
    
    // Check access
    if (user.role !== 'superadmin' && user.business_id != businessId) {
      console.log('❌ Access denied: user.business_id != businessId');
      return res.status(403).json({ message: 'Access denied' });
    }
    
    // Check if categories table exists first
    let hasCategoriesTable = false;
    try {
      const [catCheck] = await pool.query("SHOW TABLES LIKE 'categories'");
      hasCategoriesTable = catCheck.length > 0;
    } catch (error) {
      console.log('Categories table check failed:', error.message);
    }
    
    let query, params;
    
    if (hasCategoriesTable) {
      // Use the full query with categories
      query = `SELECT 
         spi.*,
         p.name as product_name,
         p.sku,
         p.barcode,
         p.price,
         p.cost_price,
         c.name as category_name,
         CASE 
           WHEN spi.quantity <= spi.min_stock_level THEN 'LOW_STOCK'
           WHEN spi.quantity = 0 THEN 'OUT_OF_STOCK'
           ELSE 'IN_STOCK'
         END as stock_status
       FROM store_product_inventory spi
       JOIN products p ON spi.product_id = p.id
       LEFT JOIN categories c ON p.category_id = c.id
       WHERE spi.store_id = ? AND spi.business_id = ?
       ORDER BY p.name`;
    } else {
      // Use simplified query without categories
      query = `SELECT 
         spi.*,
         p.name as product_name,
         p.sku,
         p.barcode,
         p.price,
         p.cost_price,
         p.category as category_name,
         CASE 
           WHEN spi.quantity <= spi.min_stock_level THEN 'LOW_STOCK'
           WHEN spi.quantity = 0 THEN 'OUT_OF_STOCK'
           ELSE 'IN_STOCK'
         END as stock_status
       FROM store_product_inventory spi
       JOIN products p ON spi.product_id = p.id
       WHERE spi.store_id = ? AND spi.business_id = ?
       ORDER BY p.name`;
    }
    
    params = [storeId, businessId];
    
    console.log(`🔍 Executing query: ${query}`);
    console.log(`🔍 With params: [${params.join(', ')}]`);
    
    const [inventory] = await pool.query(query, params);
    
    console.log(`✅ Query successful! Found ${inventory.length} inventory records`);
    if (inventory.length > 0) {
      console.log(`📊 Sample record:`, inventory[0]);
    }
    
    res.json({
      store_id: parseInt(storeId),
      business_id: parseInt(businessId),
      inventory,
      total_products: inventory.length,
      total_quantity: inventory.reduce((sum, item) => sum + item.quantity, 0)
    });
  } catch (error) {
    console.error('Error fetching store inventory:', error);
    console.error('Error details:', {
      message: error.message,
      code: error.code,
      errno: error.errno,
      sqlState: error.sqlState
    });
    res.status(500).json({ 
      message: 'Server error',
      error: error.message,
      code: error.code
    });
  }
});

// Get inventory movement history
router.get('/:storeId/movements/:businessId', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { storeId, businessId } = req.params;
    const { limit = 50, offset = 0, movement_type = '', product_id = '' } = req.query;
    const user = req.user;
    
    // Check access
    if (user.role !== 'superadmin' && user.business_id != businessId) {
      return res.status(403).json({ message: 'Access denied' });
    }
    
    let whereClause = 'WHERE sim.store_id = ? AND sim.business_id = ?';
    let params = [storeId, businessId];
    
    if (movement_type) {
      whereClause += ' AND sim.movement_type = ?';
      params.push(movement_type);
    }
    
    if (product_id) {
      whereClause += ' AND sim.product_id = ?';
      params.push(product_id);
    }
    
    const [movements] = await pool.query(
      `SELECT 
         sim.*,
         p.name as product_name,
         p.sku,
         u.username as created_by_username
       FROM store_inventory_movements sim
       JOIN products p ON sim.product_id = p.id
       JOIN users u ON sim.created_by = u.id
       ${whereClause}
       ORDER BY sim.created_at DESC
       LIMIT ? OFFSET ?`,
      [...params, parseInt(limit), parseInt(offset)]
    );
    
    res.json(movements);
  } catch (error) {
    console.error('Error fetching inventory movements:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get store inventory reports
router.get('/:storeId/reports/:businessId', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { storeId, businessId } = req.params;
    const { start_date, end_date } = req.query;
    const user = req.user;
    
    // Check access
    if (user.role !== 'superadmin' && user.business_id != businessId) {
      return res.status(403).json({ message: 'Access denied' });
    }
    
    let dateFilter = '';
    let params = [storeId, businessId];
    
    if (start_date && end_date) {
      dateFilter = 'AND sim.created_at BETWEEN ? AND ?';
      params.push(start_date, end_date);
    }
    
    // Get summary statistics
    const [summary] = await pool.query(
      `SELECT 
         COUNT(DISTINCT sim.product_id) as total_products,
         SUM(CASE WHEN sim.movement_type = 'in' THEN sim.quantity_change ELSE 0 END) as total_in,
         SUM(CASE WHEN sim.movement_type = 'out' THEN ABS(sim.quantity_change) ELSE 0 END) as total_out,
         SUM(CASE WHEN sim.movement_type = 'transfer_out' THEN ABS(sim.quantity_change) ELSE 0 END) as total_transferred,
         COUNT(CASE WHEN sim.movement_type = 'in' THEN 1 END) as in_movements,
         COUNT(CASE WHEN sim.movement_type = 'out' THEN 1 END) as out_movements,
         COUNT(CASE WHEN sim.movement_type = 'transfer_out' THEN 1 END) as transfer_movements
       FROM store_inventory_movements sim
       WHERE sim.store_id = ? AND sim.business_id = ? ${dateFilter}`,
      params
    );
    
    // Get top products by movement
    const [topProducts] = await pool.query(
      `SELECT 
         p.name as product_name,
         p.sku,
         SUM(CASE WHEN sim.movement_type = 'in' THEN sim.quantity_change ELSE 0 END) as total_in,
         SUM(CASE WHEN sim.movement_type = 'transfer_out' THEN ABS(sim.quantity_change) ELSE 0 END) as total_transferred,
         COUNT(sim.id) as movement_count
       FROM store_inventory_movements sim
       JOIN products p ON sim.product_id = p.id
       WHERE sim.store_id = ? AND sim.business_id = ? ${dateFilter}
       GROUP BY p.id, p.name, p.sku
       ORDER BY movement_count DESC
       LIMIT 10`,
      params
    );
    
    // Get daily movement trends
    const [dailyTrends] = await pool.query(
      `SELECT 
         DATE(sim.created_at) as date,
         COUNT(CASE WHEN sim.movement_type = 'in' THEN 1 END) as in_count,
         COUNT(CASE WHEN sim.movement_type = 'transfer_out' THEN 1 END) as transfer_count,
         SUM(CASE WHEN sim.movement_type = 'in' THEN sim.quantity_change ELSE 0 END) as in_quantity,
         SUM(CASE WHEN sim.movement_type = 'transfer_out' THEN ABS(sim.quantity_change) ELSE 0 END) as transfer_quantity
       FROM store_inventory_movements sim
       WHERE sim.store_id = ? AND sim.business_id = ? ${dateFilter}
       GROUP BY DATE(sim.created_at)
       ORDER BY date DESC
       LIMIT 30`,
      params
    );
    
    res.json({
      summary: summary[0],
      top_products: topProducts,
      daily_trends: dailyTrends
    });
  } catch (error) {
    console.error('Error fetching store reports:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
