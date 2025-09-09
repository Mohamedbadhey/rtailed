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
        
        // Check if store has enough inventory for the source business (warehouse stock)
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
        
        // Update store inventory (reduce for source business)
        await connection.query(
          'UPDATE store_product_inventory SET quantity = ?, updated_by = ?, last_updated = CURRENT_TIMESTAMP WHERE store_id = ? AND business_id = ? AND product_id = ?',
          [newQuantity, user.id, storeId, from_business_id, product_id]
        );
        
        // Record store inventory movement (transfer_out from source business)
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
        
        // No need to create store inventory for target business
        // The product is now assigned to the target business in the products table
        // and the business inventory is tracked in inventory_transactions
        
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
      console.log(`🔍 DEBUG: store_quantity type: ${typeof inventory[0].store_quantity}, value: ${inventory[0].store_quantity}`);
      console.log(`🔍 DEBUG: quantity type: ${typeof inventory[0].quantity}, value: ${inventory[0].quantity}`);
      console.log(`🔍 DEBUG: min_stock_level type: ${typeof inventory[0].min_stock_level}, value: ${inventory[0].min_stock_level}`);
      console.log(`🔍 DEBUG: price type: ${typeof inventory[0].price}, value: ${inventory[0].price}`);
      console.log(`🔍 DEBUG: cost_price type: ${typeof inventory[0].cost_price}, value: ${inventory[0].cost_price}`);
    }
    
    const responseData = {
      store_id: parseInt(storeId),
      business_id: parseInt(businessId),
      inventory,
      total_products: inventory.length,
      total_quantity: inventory.reduce((sum, item) => sum + item.quantity, 0)
    };
    
    console.log(`🔍 DEBUG: Response data structure:`, {
      store_id: typeof responseData.store_id,
      business_id: typeof responseData.business_id,
      inventory_count: responseData.inventory.length,
      total_products: typeof responseData.total_products,
      total_quantity: typeof responseData.total_quantity
    });
    
    if (responseData.inventory.length > 0) {
      console.log(`🔍 DEBUG: First item in response:`, {
        store_quantity: typeof responseData.inventory[0].store_quantity,
        quantity: typeof responseData.inventory[0].quantity,
        min_stock_level: typeof responseData.inventory[0].min_stock_level
      });
    }
    
    res.json(responseData);
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
         COALESCE(u.email, CONCAT('User ', u.id), 'Unknown') as created_by_username,
         b.name as business_name,
         b.id as business_id
       FROM store_inventory_movements sim
       JOIN products p ON sim.product_id = p.id
       LEFT JOIN users u ON sim.created_by = u.id
       LEFT JOIN businesses b ON sim.business_id = b.id
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

// Get comprehensive store inventory reports
router.get('/:storeId/reports/:businessId', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { storeId, businessId } = req.params;
    const { start_date, end_date, report_type = 'comprehensive' } = req.query;
    const user = req.user;
    
    console.log(`🔍 Store Reports Request: storeId=${storeId}, businessId=${businessId}, userRole=${user.role}, reportType=${report_type}`);
    
    // Check access
    if (user.role !== 'superadmin' && user.business_id != businessId) {
      console.log('❌ Access denied: user.business_id != businessId');
      return res.status(403).json({ message: 'Access denied' });
    }
    
    let dateFilter = '';
    let params = [storeId, businessId];
    
    if (start_date && end_date) {
      dateFilter = 'AND created_at BETWEEN ? AND ?';
      params.push(start_date, end_date);
    }
    
    // 1. CURRENT STOCK STATUS - Real-time inventory from store_product_inventory
    const [currentStock] = await pool.query(
      `SELECT 
         spi.id as inventory_id,
         spi.product_id,
         spi.quantity as current_quantity,
         spi.min_stock_level,
         spi.last_updated,
         p.name as product_name,
         p.sku,
         p.barcode,
         p.cost_price,
         p.price,
         p.category,
         CASE 
           WHEN spi.quantity <= 0 THEN 'OUT_OF_STOCK'
           WHEN spi.quantity <= spi.min_stock_level THEN 'LOW_STOCK'
           ELSE 'IN_STOCK'
         END as stock_status,
         (spi.quantity * p.cost_price) as total_cost_value,
         (spi.quantity * p.price) as total_selling_value
       FROM store_product_inventory spi
       JOIN products p ON spi.product_id = p.id
       WHERE spi.store_id = ? AND spi.business_id = ?
       ORDER BY spi.quantity ASC, p.name ASC`,
      [storeId, businessId]
    );
    
    // 2. MOVEMENT SUMMARY STATISTICS
    const [movementSummary] = await pool.query(
      `SELECT 
         COUNT(DISTINCT sim.product_id) as total_products_with_movements,
         SUM(CASE WHEN sim.movement_type = 'in' THEN sim.quantity ELSE 0 END) as total_stock_in,
         SUM(CASE WHEN sim.movement_type = 'transfer_out' THEN sim.quantity ELSE 0 END) as total_transferred_out,
         COUNT(CASE WHEN sim.movement_type = 'in' THEN 1 END) as stock_in_count,
         COUNT(CASE WHEN sim.movement_type = 'transfer_out' THEN 1 END) as transfer_out_count,
         MIN(sim.created_at) as first_movement_date,
         MAX(sim.created_at) as last_movement_date
       FROM store_inventory_movements sim
       WHERE sim.store_id = ? AND sim.business_id = ? ${dateFilter}`,
      params
    );
    
    // 3. TOP PERFORMING PRODUCTS (by movement activity)
    const [topProducts] = await pool.query(
      `SELECT 
         p.id as product_id,
         p.name as product_name,
         p.sku,
         p.cost_price,
         p.price,
         COALESCE(current_stock.quantity, 0) as current_stock,
         COALESCE(movements.total_in, 0) as total_stock_in,
         COALESCE(movements.total_transferred, 0) as total_transferred,
         COALESCE(movements.movement_count, 0) as movement_count,
         COALESCE(movements.last_movement_date, 'N/A') as last_movement_date
       FROM products p
       LEFT JOIN (
         SELECT 
           product_id,
           quantity
         FROM store_product_inventory 
         WHERE store_id = ? AND business_id = ?
       ) current_stock ON p.id = current_stock.product_id
       LEFT JOIN (
         SELECT 
           product_id,
           SUM(CASE WHEN movement_type = 'in' THEN quantity ELSE 0 END) as total_in,
           SUM(CASE WHEN movement_type = 'transfer_out' THEN quantity ELSE 0 END) as total_transferred,
           COUNT(*) as movement_count,
           MAX(created_at) as last_movement_date
         FROM store_inventory_movements
         WHERE store_id = ? AND business_id = ? ${dateFilter}
         GROUP BY product_id
       ) movements ON p.id = movements.product_id
       WHERE current_stock.product_id IS NOT NULL OR movements.product_id IS NOT NULL
       ORDER BY COALESCE(movements.movement_count, 0) DESC, COALESCE(current_stock.quantity, 0) DESC
       LIMIT 20`,
      [storeId, businessId, storeId, businessId, ...(start_date && end_date ? [start_date, end_date] : [])]
    );
    
    // 4. LOW STOCK ALERTS
    const [lowStockAlerts] = await pool.query(
      `SELECT 
         spi.product_id,
         p.name as product_name,
         p.sku,
         spi.quantity as current_quantity,
         spi.min_stock_level,
         (spi.min_stock_level - spi.quantity) as shortage_quantity,
         p.cost_price,
         p.price,
         spi.last_updated,
         CASE 
           WHEN spi.quantity = 0 THEN 'CRITICAL - OUT OF STOCK'
           WHEN spi.quantity <= spi.min_stock_level THEN 'WARNING - LOW STOCK'
         END as alert_level
       FROM store_product_inventory spi
       JOIN products p ON spi.product_id = p.id
       WHERE spi.store_id = ? AND spi.business_id = ? 
         AND spi.quantity <= spi.min_stock_level
       ORDER BY spi.quantity ASC, (spi.min_stock_level - spi.quantity) DESC`,
      [storeId, businessId]
    );
    
    // 5. DAILY MOVEMENT TRENDS
    const [dailyTrends] = await pool.query(
      `SELECT 
         DATE(sim.created_at) as date,
         COUNT(CASE WHEN sim.movement_type = 'in' THEN 1 END) as stock_in_count,
         COUNT(CASE WHEN sim.movement_type = 'transfer_out' THEN 1 END) as transfer_out_count,
         SUM(CASE WHEN sim.movement_type = 'in' THEN sim.quantity ELSE 0 END) as stock_in_quantity,
         SUM(CASE WHEN sim.movement_type = 'transfer_out' THEN sim.quantity ELSE 0 END) as transfer_out_quantity,
         COUNT(DISTINCT sim.product_id) as unique_products_moved
       FROM store_inventory_movements sim
       WHERE sim.store_id = ? AND sim.business_id = ? ${dateFilter}
       GROUP BY DATE(sim.created_at)
       ORDER BY date DESC
       LIMIT 30`,
      params
    );
    
    // 6. FINANCIAL SUMMARY
    const [financialSummary] = await pool.query(
      `SELECT 
         COUNT(*) as total_products_in_store,
         SUM(spi.quantity) as total_units_in_store,
         SUM(spi.quantity * p.cost_price) as total_cost_value,
         SUM(spi.quantity * p.price) as total_selling_value,
         SUM(spi.quantity * (p.price - p.cost_price)) as total_profit_potential,
         AVG(p.cost_price) as average_cost_price,
         AVG(p.price) as average_selling_price
       FROM store_product_inventory spi
       JOIN products p ON spi.product_id = p.id
       WHERE spi.store_id = ? AND spi.business_id = ?`,
      [storeId, businessId]
    );
    
    // 7. RECENT MOVEMENTS (Last 10 activities)
    const [recentMovements] = await pool.query(
      `SELECT 
         sim.id,
         sim.product_id,
         p.name as product_name,
         p.sku,
         sim.movement_type,
         sim.quantity,
         sim.previous_quantity,
         sim.new_quantity,
         sim.reference_type,
         sim.notes,
         sim.created_at,
         COALESCE(u.email, CONCAT('User ', u.id), 'Unknown') as created_by_name
       FROM store_inventory_movements sim
       JOIN products p ON sim.product_id = p.id
       LEFT JOIN users u ON sim.created_by = u.id
       WHERE sim.store_id = ? AND sim.business_id = ? ${dateFilter}
       ORDER BY sim.created_at DESC
       LIMIT 10`,
      params
    );
    
    // 8. TRANSFER ANALYTICS
    const [transferAnalytics] = await pool.query(
      `SELECT 
         COUNT(*) as total_transfers,
         SUM(quantity) as total_units_transferred,
         COUNT(DISTINCT product_id) as unique_products_transferred,
         AVG(quantity) as average_transfer_quantity,
         MIN(created_at) as first_transfer_date,
         MAX(created_at) as last_transfer_date
       FROM store_inventory_movements
       WHERE store_id = ? AND business_id = ? AND movement_type = 'transfer_out' ${dateFilter}`,
      params
    );
    
    console.log(`✅ Comprehensive reports generated successfully!`);
    
    res.json({
      report_metadata: {
        store_id: parseInt(storeId),
        business_id: parseInt(businessId),
        generated_at: new Date().toISOString(),
        date_range: start_date && end_date ? { start_date, end_date } : 'All time',
        report_type: report_type
      },
      current_stock: {
        summary: {
          total_products: currentStock.length,
          total_units: currentStock.reduce((sum, item) => sum + item.current_quantity, 0),
          out_of_stock: currentStock.filter(item => item.stock_status === 'OUT_OF_STOCK').length,
          low_stock: currentStock.filter(item => item.stock_status === 'LOW_STOCK').length,
          in_stock: currentStock.filter(item => item.stock_status === 'IN_STOCK').length
        },
        products: currentStock
      },
      movement_summary: movementSummary[0],
      financial_summary: financialSummary[0],
      top_products: topProducts,
      low_stock_alerts: lowStockAlerts,
      daily_trends: dailyTrends,
      recent_movements: recentMovements,
      transfer_analytics: transferAnalytics[0]
    });
    
  } catch (error) {
    console.error('❌ Error fetching comprehensive store reports:', error);
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

// =====================================================
// DETAILED REPORTS ENDPOINTS
// =====================================================

// 1. DETAILED MOVEMENTS REPORT
router.get('/:storeId/detailed-movements/:businessId', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { storeId, businessId } = req.params;
    const { 
      start_date, 
      end_date, 
      product_id, 
      category_id,
      movement_type, 
      reference_type,
      page = 1, 
      limit = 50 
    } = req.query;
    const user = req.user;
    
    console.log(`🔍 Detailed Movements Report: storeId=${storeId}, businessId=${businessId}`);
    
    // Check access
    if (user.role !== 'superadmin' && user.business_id != businessId) {
      return res.status(403).json({ message: 'Access denied' });
    }
    
    // Build dynamic filters
    let whereConditions = ['sim.store_id = ?', 'sim.business_id = ?'];
    let params = [storeId, businessId];
    
    if (start_date && end_date) {
      whereConditions.push('sim.created_at BETWEEN ? AND ?');
      params.push(start_date, end_date);
    }
    
    if (product_id) {
      whereConditions.push('sim.product_id = ?');
      params.push(product_id);
    }
    
    if (category_id) {
      whereConditions.push('p.category_id = ?');
      params.push(category_id);
    }
    
    if (movement_type) {
      whereConditions.push('sim.movement_type = ?');
      params.push(movement_type);
    }
    
    if (reference_type) {
      whereConditions.push('sim.reference_type = ?');
      params.push(reference_type);
    }
    
    const whereClause = whereConditions.join(' AND ');
    
    // Get total count for pagination
    const countQuery = category_id 
      ? `SELECT COUNT(*) as total FROM store_inventory_movements sim JOIN products p ON sim.product_id = p.id WHERE ${whereClause}`
      : `SELECT COUNT(*) as total FROM store_inventory_movements sim WHERE ${whereClause}`;
    
    const [countResult] = await pool.query(countQuery, params);
    
    const totalRecords = countResult[0].total;
    const offset = (page - 1) * limit;
    
    // Get detailed movements with pagination
    const [movements] = await pool.query(
      `SELECT 
         sim.id,
         sim.product_id,
         p.name as product_name,
         p.sku,
         p.barcode,
         p.cost_price,
         p.price,
         sim.movement_type,
         sim.quantity,
         sim.previous_quantity,
         sim.new_quantity,
         sim.reference_type,
         sim.reference_id,
         sim.notes,
         sim.created_at,
         COALESCE(u.email, CONCAT('User ', u.id), 'Unknown') as created_by_name,
         s.name as store_name,
         b.name as business_name
       FROM store_inventory_movements sim
       JOIN products p ON sim.product_id = p.id
       JOIN stores s ON sim.store_id = s.id
       JOIN businesses b ON sim.business_id = b.id
       LEFT JOIN users u ON sim.created_by = u.id
       WHERE ${whereClause}
       ORDER BY sim.created_at DESC
       LIMIT ? OFFSET ?`,
      [...params, parseInt(limit), offset]
    );
    
    // Get summary statistics
    const summaryQuery = category_id 
      ? `SELECT 
           COUNT(*) as total_movements,
           COUNT(DISTINCT sim.product_id) as unique_products,
           SUM(CASE WHEN sim.movement_type = 'in' THEN sim.quantity ELSE 0 END) as total_stock_in,
           SUM(CASE WHEN sim.movement_type = 'transfer_out' THEN sim.quantity ELSE 0 END) as total_transferred_out,
           SUM(CASE WHEN sim.movement_type = 'adjustment' THEN sim.quantity ELSE 0 END) as total_adjustments,
           MIN(sim.created_at) as first_movement,
           MAX(sim.created_at) as last_movement
         FROM store_inventory_movements sim
         JOIN products p ON sim.product_id = p.id
         WHERE ${whereClause}`
      : `SELECT 
           COUNT(*) as total_movements,
           COUNT(DISTINCT sim.product_id) as unique_products,
           SUM(CASE WHEN sim.movement_type = 'in' THEN sim.quantity ELSE 0 END) as total_stock_in,
           SUM(CASE WHEN sim.movement_type = 'transfer_out' THEN sim.quantity ELSE 0 END) as total_transferred_out,
           SUM(CASE WHEN sim.movement_type = 'adjustment' THEN sim.quantity ELSE 0 END) as total_adjustments,
           MIN(sim.created_at) as first_movement,
           MAX(sim.created_at) as last_movement
         FROM store_inventory_movements sim
         WHERE ${whereClause}`;
    
    const [summary] = await pool.query(summaryQuery, params);
    
    res.json({
      report_metadata: {
        store_id: parseInt(storeId),
        business_id: parseInt(businessId),
        generated_at: new Date().toISOString(),
        filters: {
          start_date,
          end_date,
          product_id,
          category_id,
          movement_type,
          reference_type
        },
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total_records: totalRecords,
          total_pages: Math.ceil(totalRecords / limit)
        }
      },
      summary: summary[0],
      movements: movements
    });
    
  } catch (error) {
    console.error('❌ Error fetching detailed movements report:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// 2. PURCHASES REPORT
router.get('/:storeId/purchases/:businessId', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { storeId, businessId } = req.params;
    const { 
      start_date, 
      end_date, 
      product_id,
      page = 1, 
      limit = 50 
    } = req.query;
    const user = req.user;
    
    console.log(`🔍 Purchases Report: storeId=${storeId}, businessId=${businessId}`);
    
    // Check access
    if (user.role !== 'superadmin' && user.business_id != businessId) {
      return res.status(403).json({ message: 'Access denied' });
    }
    
    // Build dynamic filters
    let whereConditions = ['sim.store_id = ?', 'sim.business_id = ?', 'sim.movement_type = "in"'];
    let params = [storeId, businessId];
    
    if (start_date && end_date) {
      whereConditions.push('sim.created_at BETWEEN ? AND ?');
      params.push(start_date, end_date);
    }
    
    if (product_id) {
      whereConditions.push('sim.product_id = ?');
      params.push(product_id);
    }
    
    const whereClause = whereConditions.join(' AND ');
    
    // Get total count for pagination
    const [countResult] = await pool.query(
      `SELECT COUNT(*) as total FROM store_inventory_movements sim WHERE ${whereClause}`,
      params
    );
    
    const totalRecords = countResult[0].total;
    const offset = (page - 1) * limit;
    
    // Get purchases with pagination
    const [purchases] = await pool.query(
      `SELECT 
         sim.id,
         sim.product_id,
         p.name as product_name,
         p.sku,
         p.barcode,
         p.cost_price,
         p.price,
         sim.quantity as units_purchased,
         sim.previous_quantity,
         sim.new_quantity,
         sim.reference_type,
         sim.notes,
         sim.created_at as purchase_date,
         COALESCE(u.email, CONCAT('User ', u.id), 'Unknown') as purchased_by,
         s.name as store_name,
         b.name as business_name,
         (sim.quantity * p.cost_price) as total_cost,
         (sim.quantity * p.price) as total_selling_value
       FROM store_inventory_movements sim
       JOIN products p ON sim.product_id = p.id
       JOIN stores s ON sim.store_id = s.id
       JOIN businesses b ON sim.business_id = b.id
       LEFT JOIN users u ON sim.created_by = u.id
       WHERE ${whereClause}
       ORDER BY sim.created_at DESC
       LIMIT ? OFFSET ?`,
      [...params, parseInt(limit), offset]
    );
    
    // Get summary statistics
    const [summary] = await pool.query(
      `SELECT 
         COUNT(*) as total_purchases,
         COUNT(DISTINCT sim.product_id) as unique_products_purchased,
         SUM(sim.quantity) as total_units_purchased,
         SUM(sim.quantity * p.cost_price) as total_purchase_cost,
         SUM(sim.quantity * p.price) as total_purchase_value,
         AVG(p.cost_price) as average_cost_price,
         MIN(sim.created_at) as first_purchase,
         MAX(sim.created_at) as last_purchase
       FROM store_inventory_movements sim
       JOIN products p ON sim.product_id = p.id
       WHERE ${whereClause}`,
      params
    );
    
    res.json({
      report_metadata: {
        store_id: parseInt(storeId),
        business_id: parseInt(businessId),
        generated_at: new Date().toISOString(),
        filters: {
          start_date,
          end_date,
          product_id
        },
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total_records: totalRecords,
          total_pages: Math.ceil(totalRecords / limit)
        }
      },
      summary: summary[0],
      purchases: purchases
    });
    
  } catch (error) {
    console.error('❌ Error fetching purchases report:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// 3. INCREMENTS REPORT (Stock additions)
router.get('/:storeId/increments/:businessId', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { storeId, businessId } = req.params;
    const { 
      start_date, 
      end_date, 
      product_id,
      page = 1, 
      limit = 50 
    } = req.query;
    const user = req.user;
    
    console.log(`🔍 Increments Report: storeId=${storeId}, businessId=${businessId}`);
    
    // Check access
    if (user.role !== 'superadmin' && user.business_id != businessId) {
      return res.status(403).json({ message: 'Access denied' });
    }
    
    // Build dynamic filters
    let whereConditions = ['sim.store_id = ?', 'sim.business_id = ?', 'sim.movement_type = "in"'];
    let params = [storeId, businessId];
    
    if (start_date && end_date) {
      whereConditions.push('sim.created_at BETWEEN ? AND ?');
      params.push(start_date, end_date);
    }
    
    if (product_id) {
      whereConditions.push('sim.product_id = ?');
      params.push(product_id);
    }
    
    const whereClause = whereConditions.join(' AND ');
    
    // Get total count for pagination
    const [countResult] = await pool.query(
      `SELECT COUNT(*) as total FROM store_inventory_movements sim WHERE ${whereClause}`,
      params
    );
    
    const totalRecords = countResult[0].total;
    const offset = (page - 1) * limit;
    
    // Get increments with pagination
    const [increments] = await pool.query(
      `SELECT 
         sim.id,
         sim.product_id,
         p.name as product_name,
         p.sku,
         p.barcode,
         p.cost_price,
         p.price,
         sim.quantity as units_added,
         sim.previous_quantity as stock_before,
         sim.new_quantity as stock_after,
         sim.reference_type,
         sim.notes,
         sim.created_at as increment_date,
         COALESCE(u.email, CONCAT('User ', u.id), 'Unknown') as added_by,
         s.name as store_name,
         b.name as business_name,
         (sim.quantity * p.cost_price) as total_cost_added,
         (sim.quantity * p.price) as total_value_added
       FROM store_inventory_movements sim
       JOIN products p ON sim.product_id = p.id
       JOIN stores s ON sim.store_id = s.id
       JOIN businesses b ON sim.business_id = b.id
       LEFT JOIN users u ON sim.created_by = u.id
       WHERE ${whereClause}
       ORDER BY sim.created_at DESC
       LIMIT ? OFFSET ?`,
      [...params, parseInt(limit), offset]
    );
    
    // Get summary statistics
    const [summary] = await pool.query(
      `SELECT 
         COUNT(*) as total_increments,
         COUNT(DISTINCT sim.product_id) as unique_products_incremented,
         SUM(sim.quantity) as total_units_added,
         SUM(sim.quantity * p.cost_price) as total_cost_added,
         SUM(sim.quantity * p.price) as total_value_added,
         AVG(sim.quantity) as average_increment_size,
         MIN(sim.created_at) as first_increment,
         MAX(sim.created_at) as last_increment
       FROM store_inventory_movements sim
       JOIN products p ON sim.product_id = p.id
       WHERE ${whereClause}`,
      params
    );
    
    res.json({
      report_metadata: {
        store_id: parseInt(storeId),
        business_id: parseInt(businessId),
        generated_at: new Date().toISOString(),
        filters: {
          start_date,
          end_date,
          product_id
        },
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total_records: totalRecords,
          total_pages: Math.ceil(totalRecords / limit)
        }
      },
      summary: summary[0],
      increments: increments
    });
    
  } catch (error) {
    console.error('❌ Error fetching increments report:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get business transfer reports - NEW IMPLEMENTATION
router.get('/:storeId/transfer-reports/:businessId', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { storeId, businessId } = req.params;
    const { 
      time_period = 'all',
      start_date, 
      end_date, 
      page = 1, 
      limit = 50 
    } = req.query;

    console.log('🚀 NEW TRANSFER REPORTS ENDPOINT CALLED');
    console.log('Store ID:', storeId, 'Business ID:', businessId);
    console.log('Time Period:', time_period);

    // Validate parameters
    if (!storeId || isNaN(parseInt(storeId))) {
      return res.status(400).json({ message: 'Invalid store ID' });
    }
    if (!businessId || isNaN(parseInt(businessId))) {
      return res.status(400).json({ message: 'Invalid business ID' });
    }

    const pageNum = Math.max(1, parseInt(page) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit) || 50));

    // Access control
    if (req.user.role !== 'superadmin' && req.user.business_id != parseInt(businessId)) {
      return res.status(403).json({ message: 'Access denied' });
    }

    // Check store access
    const [storeCheck] = await pool.execute(
      'SELECT 1 FROM stores s LEFT JOIN store_business_assignments sba ON s.id = sba.store_id WHERE s.id = ? AND (sba.business_id = ? OR ? = "superadmin")',
      [parseInt(storeId), req.user.business_id, req.user.role]
    );
    
    if (storeCheck.length === 0) {
      return res.status(404).json({ message: 'Store not found or access denied' });
    }

    // Build date filter
    let dateFilter = '';
    let dateParams = [];
    
    if (time_period === 'today') {
      dateFilter = 'AND DATE(sim.created_at) = CURDATE()';
    } else if (time_period === 'week') {
      dateFilter = 'AND sim.created_at >= DATE_SUB(NOW(), INTERVAL 1 WEEK)';
    } else if (time_period === 'month') {
      dateFilter = 'AND sim.created_at >= DATE_SUB(NOW(), INTERVAL 1 MONTH)';
    } else if (time_period === 'custom' && start_date && end_date) {
      dateFilter = 'AND DATE(sim.created_at) >= ? AND DATE(sim.created_at) <= ?';
      dateParams = [start_date, end_date];
    }

    // Get transfer reports
    const offset = (pageNum - 1) * limitNum;
    
    const transfersQuery = `
      SELECT 
        sim.id,
        sim.product_id,
        sim.quantity,
        sim.created_at as transfer_date,
        sim.movement_type,
        sim.reference_type,
        p.name as product_name,
        p.sku,
        p.price,
        p.cost_price,
        b.name as target_business_name,
        u.email as created_by_email
      FROM store_inventory_movements sim
      LEFT JOIN products p ON sim.product_id = p.id
      LEFT JOIN businesses b ON sim.business_id = b.id
      LEFT JOIN users u ON sim.created_by = u.id
      WHERE sim.store_id = ? 
        AND sim.movement_type = 'transfer_out' 
        AND sim.reference_type = 'transfer'
        ${dateFilter}
      ORDER BY sim.created_at DESC
      LIMIT ? OFFSET ?
    `;

    const queryParams = [parseInt(storeId), ...dateParams, limitNum, offset];
    console.log('Executing query with params:', queryParams);
    
    const [transfers] = await pool.execute(transfersQuery, queryParams);

    // Get summary
    const summaryQuery = `
      SELECT 
        COUNT(*) as total_transfers,
        COALESCE(SUM(sim.quantity), 0) as total_quantity_transferred,
        COUNT(DISTINCT sim.business_id) as unique_businesses,
        COUNT(DISTINCT sim.product_id) as unique_products,
        COALESCE(SUM(sim.quantity * p.cost_price), 0) as total_cost_value
      FROM store_inventory_movements sim
      LEFT JOIN products p ON sim.product_id = p.id
      WHERE sim.store_id = ? 
        AND sim.movement_type = 'transfer_out' 
        AND sim.reference_type = 'transfer'
        ${dateFilter}
    `;

    const summaryParams = [parseInt(storeId), ...dateParams];
    const [summaryRows] = await pool.execute(summaryQuery, summaryParams);
    const summary = summaryRows[0] || {};

    // Get total count
    const countQuery = `
      SELECT COUNT(*) as total
      FROM store_inventory_movements sim
      WHERE sim.store_id = ? 
        AND sim.movement_type = 'transfer_out' 
        AND sim.reference_type = 'transfer'
        ${dateFilter}
    `;

    const [countRows] = await pool.execute(countQuery, summaryParams);
    const total = countRows[0]?.total || 0;

    console.log('✅ Transfer reports generated:', {
      transfersCount: transfers.length,
      summary,
      total
    });

    res.json({
      success: true,
      transfers,
      summary,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum)
      },
      filters: {
        time_period,
        start_date,
        end_date
      }
    });

  } catch (error) {
    console.error('Error getting transfer reports:', error);
    res.status(500).json({ message: 'Internal server error', error: error.message });
  }
});

module.exports = router;
