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
              quantity, previous_quantity, new_quantity,
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
              quantity, previous_quantity, new_quantity,
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
    
    console.log('=== TRANSFER STORE TO BUSINESS ===');
    console.log('Store ID:', storeId);
    console.log('From Business ID:', from_business_id);
    console.log('To Business ID:', to_business_id);
    console.log('Products:', JSON.stringify(products, null, 2));
    console.log('Notes:', notes);
    console.log('User:', { id: user.id, role: user.role, business_id: user.business_id });
    console.log('Transfer Type:', from_business_id === to_business_id ? 'SAME BUSINESS' : 'DIFFERENT BUSINESS');
    
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
    
    // Check if target business has access to this store
    const [targetAccessCheck] = await pool.query(
      `SELECT 1 FROM store_business_assignments sba 
       WHERE sba.store_id = ? AND sba.business_id = ? AND sba.is_active = 1`,
      [storeId, to_business_id]
    );
    
    if (targetAccessCheck.length === 0) {
      return res.status(403).json({ message: 'Target business does not have access to this store' });
    }
    
    // Start transaction
    const connection = await pool.getConnection();
    await connection.beginTransaction();
    
    try {
      const results = [];
      
      for (const product of products) {
        const { product_id, quantity, unit_cost } = product;
        
        console.log(`Processing product ${product_id} with quantity ${quantity}`);
        
        // Check if store has enough inventory
        const [storeInventory] = await connection.query(
          'SELECT quantity FROM store_product_inventory WHERE store_id = ? AND business_id = ? AND product_id = ?',
          [storeId, from_business_id, product_id]
        );
        
        console.log(`Store inventory check for product ${product_id}:`, storeInventory);
        
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
            quantity, previous_quantity, new_quantity,
            reference_type, notes, created_by
          ) VALUES (?, ?, ?, 'transfer_out', ?, ?, ?, 'transfer', ?, ?)`,
          [storeId, from_business_id, product_id, quantity, currentQuantity, newQuantity, notes || 'Transfer to business', user.id]
        );
        
        // Update product business_id from NULL to target business
        // This assigns the product to the target business
        const [productCheck] = await connection.query(
          'SELECT id, business_id, stock_quantity FROM products WHERE id = ?',
          [product_id]
        );
        
        console.log(`Product check for product ${product_id}:`, productCheck);
        
        if (productCheck.length === 0) {
          throw new Error(`Product ID ${product_id} not found`);
        }
        
        const currentBusinessId = productCheck[0].business_id;
        const currentStockQuantity = productCheck[0].stock_quantity;
        
        // Update product business_id and increment stock_quantity
        if (currentBusinessId === null) {
          // Product is global, assign to business and set initial stock
          console.log(`Updating product ${product_id} business_id: NULL -> ${to_business_id}, stock: ${currentStockQuantity} -> ${quantity}`);
          
          await connection.query(
            'UPDATE products SET business_id = ?, stock_quantity = ? WHERE id = ?',
            [to_business_id, quantity, product_id]
          );
        } else {
          // Product already belongs to a business, increment stock quantity
          const newStockQuantity = currentStockQuantity + quantity;
          console.log(`Updating product ${product_id} stock: ${currentStockQuantity} -> ${newStockQuantity}`);
          
          await connection.query(
            'UPDATE products SET stock_quantity = ? WHERE id = ?',
            [newStockQuantity, product_id]
          );
        }
        
        // Create or update store_product_inventory for target business
        const [targetStoreInventory] = await connection.query(
          'SELECT id, quantity FROM store_product_inventory WHERE store_id = ? AND business_id = ? AND product_id = ?',
          [storeId, to_business_id, product_id]
        );
        
        if (targetStoreInventory.length === 0) {
          // Create new store inventory record for target business
          console.log(`Creating new store inventory record for business ${to_business_id}, product ${product_id}`);
          await connection.query(
            `INSERT INTO store_product_inventory 
             (store_id, business_id, product_id, quantity, min_stock_level, updated_by)
             VALUES (?, ?, ?, ?, 10, ?)`,
            [storeId, to_business_id, product_id, quantity, user.id]
          );
        } else {
          // Update existing store inventory record for target business
          const currentTargetQuantity = targetStoreInventory[0].quantity;
          const newTargetQuantity = currentTargetQuantity + quantity;
          console.log(`Updating target business store inventory: ${currentTargetQuantity} -> ${newTargetQuantity}`);
          
          await connection.query(
            'UPDATE store_product_inventory SET quantity = ?, updated_by = ? WHERE store_id = ? AND business_id = ? AND product_id = ?',
            [newTargetQuantity, user.id, storeId, to_business_id, product_id]
          );
        }
        
        // No need to create transfer_in record for store-to-business transfers
        // The transfer_out record above already tracks the movement from store to business
        console.log(`Transfer completed: ${quantity} units of product ${product_id} transferred from store to business ${to_business_id}`);
        
        // Record business inventory movement (in)
        await connection.query(
          `INSERT INTO inventory_transactions (
            business_id, product_id, transaction_type, quantity, 
            notes, created_at
          ) VALUES (?, ?, 'transfer_in', ?, ?, NOW())`,
          [to_business_id, product_id, quantity, notes || 'Transfer from store']
        );
        
        results.push({
          product_id,
          from_store_quantity_before: currentQuantity,
          from_store_quantity_after: newQuantity,
          to_business_id: to_business_id,
          to_store_quantity_before: targetStoreInventory.length > 0 ? targetStoreInventory[0].quantity : 0,
          to_store_quantity_after: targetStoreInventory.length > 0 ? targetStoreInventory[0].quantity + quantity : quantity,
          business_id_before: currentBusinessId,
          business_id_after: to_business_id,
          stock_quantity_before: currentStockQuantity,
          stock_quantity_after: currentBusinessId === null ? quantity : currentStockQuantity + quantity,
          transferred_quantity: quantity
        });
      }
      
      await connection.commit();
      
      console.log('✅ Transfer completed successfully');
      console.log('Results:', JSON.stringify(results, null, 2));
      
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
      // Store-focused query - show store inventory data with current quantity from last movement
      query = `SELECT 
         spi.id as inventory_id,
         spi.store_id,
         spi.business_id,
         spi.product_id,
         COALESCE(last_movement.new_quantity, spi.quantity) as store_quantity,
         spi.min_stock_level,
         spi.updated_by,
         spi.last_updated,
         p.name as product_name,
         p.sku,
         p.barcode,
         p.description,
         p.image_url,
         p.price,
         p.cost_price,
         c.name as category_name,
         CASE 
           WHEN COALESCE(last_movement.new_quantity, spi.quantity) <= spi.min_stock_level THEN 'LOW_STOCK'
           WHEN COALESCE(last_movement.new_quantity, spi.quantity) = 0 THEN 'OUT_OF_STOCK'
           ELSE 'IN_STOCK'
         END as stock_status
       FROM store_product_inventory spi
       JOIN products p ON spi.product_id = p.id
       LEFT JOIN categories c ON p.category_id = c.id
       LEFT JOIN (
         SELECT 
           store_id, business_id, product_id, new_quantity,
           ROW_NUMBER() OVER (PARTITION BY store_id, business_id, product_id ORDER BY created_at DESC) as rn
         FROM store_inventory_movements
       ) last_movement ON spi.store_id = last_movement.store_id 
                       AND spi.business_id = last_movement.business_id 
                       AND spi.product_id = last_movement.product_id 
                       AND last_movement.rn = 1
       WHERE spi.store_id = ? AND spi.business_id = ?
       ORDER BY p.name`;
    } else {
      // Store-focused query - show store inventory data with current quantity from last movement
      query = `SELECT 
         spi.id as inventory_id,
         spi.store_id,
         spi.business_id,
         spi.product_id,
         COALESCE(last_movement.new_quantity, spi.quantity) as store_quantity,
         spi.min_stock_level,
         spi.updated_by,
         spi.last_updated,
         p.name as product_name,
         p.sku,
         p.barcode,
         p.description,
         p.image_url,
         p.price,
         p.cost_price,
         p.category as category_name,
         CASE 
           WHEN COALESCE(last_movement.new_quantity, spi.quantity) <= spi.min_stock_level THEN 'LOW_STOCK'
           WHEN COALESCE(last_movement.new_quantity, spi.quantity) = 0 THEN 'OUT_OF_STOCK'
           ELSE 'IN_STOCK'
         END as stock_status
       FROM store_product_inventory spi
       JOIN products p ON spi.product_id = p.id
       LEFT JOIN (
         SELECT 
           store_id, business_id, product_id, new_quantity,
           ROW_NUMBER() OVER (PARTITION BY store_id, business_id, product_id ORDER BY created_at DESC) as rn
         FROM store_inventory_movements
       ) last_movement ON spi.store_id = last_movement.store_id 
                       AND spi.business_id = last_movement.business_id 
                       AND spi.product_id = last_movement.product_id 
                       AND last_movement.rn = 1
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
    
    console.log(`🔍 Store Movements Request: storeId=${storeId}, businessId=${businessId}, userRole=${user.role}`);
    
    // Check access
    if (user.role !== 'superadmin' && user.business_id != businessId) {
      console.log('❌ Access denied: user.business_id != businessId');
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
         COALESCE(u.email, CONCAT('User ', u.id), 'Unknown') as created_by_username
       FROM store_inventory_movements sim
       JOIN products p ON sim.product_id = p.id
       LEFT JOIN users u ON sim.created_by = u.id
       ${whereClause}
       ORDER BY sim.created_at DESC
       LIMIT ? OFFSET ?`,
      [...params, parseInt(limit), parseInt(offset)]
    );
    
    console.log(`✅ Movements query successful! Found ${movements.length} movement records`);
    res.json(movements);
  } catch (error) {
    console.error('❌ Error fetching inventory movements:', error);
    console.error('❌ Error details:', {
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

// Get store inventory reports
router.get('/:storeId/reports/:businessId', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { storeId, businessId } = req.params;
    const { start_date, end_date } = req.query;
    const user = req.user;
    
    console.log(`🔍 Store Reports Request: storeId=${storeId}, businessId=${businessId}, userRole=${user.role}`);
    
    // Check access
    if (user.role !== 'superadmin' && user.business_id != businessId) {
      console.log('❌ Access denied: user.business_id != businessId');
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
         SUM(CASE WHEN sim.movement_type = 'in' THEN sim.quantity ELSE 0 END) as total_in,
         SUM(CASE WHEN sim.movement_type = 'out' THEN ABS(sim.quantity) ELSE 0 END) as total_out,
         SUM(CASE WHEN sim.movement_type = 'transfer_out' THEN ABS(sim.quantity) ELSE 0 END) as total_transferred,
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
         SUM(CASE WHEN sim.movement_type = 'in' THEN sim.quantity ELSE 0 END) as total_in,
         SUM(CASE WHEN sim.movement_type = 'transfer_out' THEN ABS(sim.quantity) ELSE 0 END) as total_transferred,
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
         SUM(CASE WHEN sim.movement_type = 'in' THEN sim.quantity ELSE 0 END) as in_quantity,
         SUM(CASE WHEN sim.movement_type = 'transfer_out' THEN ABS(sim.quantity) ELSE 0 END) as transfer_quantity
       FROM store_inventory_movements sim
       WHERE sim.store_id = ? AND sim.business_id = ? ${dateFilter}
       GROUP BY DATE(sim.created_at)
       ORDER BY date DESC
       LIMIT 30`,
      params
    );
    
    console.log(`✅ Reports query successful! Summary: ${JSON.stringify(summary[0])}`);
    res.json({
      summary: summary[0],
      top_products: topProducts,
      daily_trends: dailyTrends
    });
  } catch (error) {
    console.error('❌ Error fetching store reports:', error);
    console.error('❌ Error details:', {
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

// Get store inventory reports with date filtering
router.get('/:storeId/reports/:businessId', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { storeId, businessId } = req.params;
    const { start_date, end_date } = req.query;
    const user = req.user;
    
    console.log(`📊 Store Inventory Report Request: storeId=${storeId}, businessId=${businessId}, start_date=${start_date}, end_date=${end_date}, userRole=${user.role}`);
    
    // Check access
    if (user.role !== 'superadmin' && user.business_id != businessId) {
      console.log('❌ Access denied: user.business_id != businessId');
      return res.status(403).json({ message: 'Access denied' });
    }
    
    // Validate date parameters
    if (!start_date || !end_date) {
      return res.status(400).json({ message: 'Start date and end date are required' });
    }
    
    const startDate = new Date(start_date);
    const endDate = new Date(end_date);
    
    if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
      return res.status(400).json({ message: 'Invalid date format' });
    }
    
    // Set end date to end of day
    endDate.setHours(23, 59, 59, 999);
    
    console.log(`📅 Date range: ${startDate.toISOString()} to ${endDate.toISOString()}`);
    
    // Get summary statistics
    const [summaryResult] = await pool.query(
      `SELECT 
         COUNT(DISTINCT spi.product_id) as total_products,
         SUM(CASE WHEN sim.movement_type = 'in' THEN sim.quantity ELSE 0 END) as total_in,
         SUM(CASE WHEN sim.movement_type = 'out' THEN sim.quantity ELSE 0 END) as total_out,
         SUM(CASE WHEN sim.movement_type = 'transfer_in' THEN sim.quantity ELSE 0 END) as total_transfer_in,
         SUM(CASE WHEN sim.movement_type = 'transfer_out' THEN sim.quantity ELSE 0 END) as total_transfer_out,
         COUNT(sim.id) as total_movements,
         SUM(CASE WHEN sim.movement_type = 'in' THEN sim.quantity * COALESCE(p.cost_price, 0) ELSE 0 END) as total_in_value,
         SUM(CASE WHEN sim.movement_type = 'out' THEN sim.quantity * COALESCE(p.cost_price, 0) ELSE 0 END) as total_out_value
       FROM store_product_inventory spi
       LEFT JOIN store_inventory_movements sim ON spi.store_id = sim.store_id 
         AND spi.business_id = sim.business_id 
         AND spi.product_id = sim.product_id
         AND sim.created_at BETWEEN ? AND ?
       LEFT JOIN products p ON spi.product_id = p.id
       WHERE spi.store_id = ? AND spi.business_id = ?`,
      [startDate, endDate, storeId, businessId]
    );
    
    // Get top products by movement count
    const [topProductsResult] = await pool.query(
      `SELECT 
         p.id as product_id,
         p.name as product_name,
         p.sku,
         p.cost_price,
         p.price,
         COUNT(sim.id) as movement_count,
         SUM(CASE WHEN sim.movement_type = 'in' THEN sim.quantity ELSE 0 END) as total_in,
         SUM(CASE WHEN sim.movement_type = 'out' THEN sim.quantity ELSE 0 END) as total_out,
         SUM(CASE WHEN sim.movement_type = 'transfer_in' THEN sim.quantity ELSE 0 END) as total_transfer_in,
         SUM(CASE WHEN sim.movement_type = 'transfer_out' THEN sim.quantity ELSE 0 END) as total_transfer_out,
         spi.quantity as current_stock
       FROM store_product_inventory spi
       JOIN products p ON spi.product_id = p.id
       LEFT JOIN store_inventory_movements sim ON spi.store_id = sim.store_id 
         AND spi.business_id = sim.business_id 
         AND spi.product_id = sim.product_id
         AND sim.created_at BETWEEN ? AND ?
       WHERE spi.store_id = ? AND spi.business_id = ?
       GROUP BY p.id, p.name, p.sku, p.cost_price, p.price, spi.quantity
       HAVING movement_count > 0
       ORDER BY movement_count DESC, total_in DESC
       LIMIT 10`,
      [startDate, endDate, storeId, businessId]
    );
    
    // Get daily trends
    const [dailyTrendsResult] = await pool.query(
      `SELECT 
         DATE(sim.created_at) as date,
         COUNT(sim.id) as movements_count,
         SUM(CASE WHEN sim.movement_type = 'in' THEN sim.quantity ELSE 0 END) as total_in,
         SUM(CASE WHEN sim.movement_type = 'out' THEN sim.quantity ELSE 0 END) as total_out,
         SUM(CASE WHEN sim.movement_type = 'in' THEN sim.quantity * COALESCE(p.cost_price, 0) ELSE 0 END) as in_value,
         SUM(CASE WHEN sim.movement_type = 'out' THEN sim.quantity * COALESCE(p.cost_price, 0) ELSE 0 END) as out_value
       FROM store_inventory_movements sim
       LEFT JOIN products p ON sim.product_id = p.id
       WHERE sim.store_id = ? AND sim.business_id = ? 
         AND sim.created_at BETWEEN ? AND ?
       GROUP BY DATE(sim.created_at)
       ORDER BY date ASC`,
      [storeId, businessId, startDate, endDate]
    );
    
    // Get low stock products
    const [lowStockResult] = await pool.query(
      `SELECT 
         p.id as product_id,
         p.name as product_name,
         p.sku,
         p.cost_price,
         p.price,
         spi.quantity as current_stock,
         spi.min_stock_level,
         (spi.quantity - spi.min_stock_level) as stock_difference
       FROM store_product_inventory spi
       JOIN products p ON spi.product_id = p.id
       WHERE spi.store_id = ? AND spi.business_id = ? 
         AND spi.quantity <= spi.min_stock_level
       ORDER BY stock_difference ASC, p.name ASC`,
      [storeId, businessId]
    );
    
    // Get movement types breakdown
    const [movementTypesResult] = await pool.query(
      `SELECT 
         sim.movement_type,
         COUNT(sim.id) as count,
         SUM(sim.quantity) as total_quantity,
         SUM(sim.quantity * COALESCE(p.cost_price, 0)) as total_value
       FROM store_inventory_movements sim
       LEFT JOIN products p ON sim.product_id = p.id
       WHERE sim.store_id = ? AND sim.business_id = ? 
         AND sim.created_at BETWEEN ? AND ?
       GROUP BY sim.movement_type
       ORDER BY count DESC`,
      [storeId, businessId, startDate, endDate]
    );
    
    const reportData = {
      period: {
        start_date: start_date,
        end_date: end_date,
        days: Math.ceil((endDate - startDate) / (1000 * 60 * 60 * 24))
      },
      summary: summaryResult[0] || {},
      top_products: topProductsResult,
      daily_trends: dailyTrendsResult,
      low_stock_products: lowStockResult,
      movement_types: movementTypesResult,
      generated_at: new Date().toISOString(),
      generated_by: user.id
    };
    
    console.log(`✅ Store inventory report generated successfully for store ${storeId}, business ${businessId}`);
    res.json(reportData);
    
  } catch (error) {
    console.error('❌ Error generating store inventory report:', error);
    console.error('❌ Error details:', {
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

module.exports = router;
