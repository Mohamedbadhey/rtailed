const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { auth, checkRole } = require('../middleware/auth');

// =====================================================
// STORE WAREHOUSE MANAGEMENT API
// This handles the first tier: Products stored in stores (warehouses)
// =====================================================

// Test endpoint to verify the API is working
router.get('/test', (req, res) => {
  res.json({ message: 'Store warehouse API is working', timestamp: new Date().toISOString() });
});

// Add product directly to store inventory (simplified approach)
router.post('/:storeId/add-product', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { storeId } = req.params;
    const { product_id, quantity, notes } = req.body;
    const user = req.user;
    
    console.log('=== ADD PRODUCT TO STORE INVENTORY ===');
    console.log('Store ID:', storeId);
    console.log('Product ID:', product_id);
    console.log('Quantity:', quantity);
    console.log('User:', { id: user.id, role: user.role, business_id: user.business_id });
    
    if (!product_id || !quantity) {
      return res.status(400).json({ message: 'Product ID and quantity are required' });
    }
    
    // Check if user has access to this store
    if (user.role !== 'superadmin') {
      const [accessCheck] = await pool.query(
        `SELECT 1 FROM store_business_assignments sba 
         WHERE sba.store_id = ? AND sba.business_id = ? AND sba.is_active = 1`,
        [storeId, user.business_id]
      );
      
      if (accessCheck.length === 0) {
        return res.status(403).json({ message: 'Access denied: No permission for this store' });
      }
    }
    
    // Start transaction
    const connection = await pool.getConnection();
    await connection.beginTransaction();
    
    try {
      // Check if product exists
      const [productCheck] = await connection.query(
        'SELECT id, name, sku FROM products WHERE id = ? AND is_deleted = 0',
        [product_id]
      );
      
      if (productCheck.length === 0) {
        throw new Error(`Product with ID ${product_id} not found`);
      }
      
      // Check if inventory record already exists for this store and business
      const [existing] = await connection.query(
        'SELECT id, quantity FROM store_product_inventory WHERE store_id = ? AND product_id = ? AND business_id = ?',
        [storeId, product_id, user.business_id]
      );
      
      if (existing.length > 0) {
        // Update existing inventory (increment)
        const currentQuantity = existing[0].quantity;
        const newQuantity = currentQuantity + quantity;
        
        await connection.query(
          `UPDATE store_product_inventory 
           SET quantity = ?, updated_by = ?
           WHERE store_id = ? AND product_id = ? AND business_id = ?`,
          [newQuantity, user.id, storeId, product_id, user.business_id]
        );
        
        // Record the increment movement
        await connection.query(
          `INSERT INTO store_inventory_movements 
           (store_id, business_id, product_id, movement_type, quantity, previous_quantity, new_quantity, reference_type, notes, created_by)
           VALUES (?, ?, ?, 'in', ?, ?, ?, 'purchase', ?, ?)`,
          [storeId, user.business_id, product_id, quantity, currentQuantity, newQuantity, notes || 'Product added to store', user.id]
        );
        
        console.log('Updated existing inventory - previous:', currentQuantity, 'added:', quantity, 'new:', newQuantity);
      } else {
        // Create new inventory record
        await connection.query(
          `INSERT INTO store_product_inventory 
           (store_id, business_id, product_id, quantity, min_stock_level, updated_by)
           VALUES (?, ?, ?, ?, 10, ?)`,
          [storeId, user.business_id, product_id, quantity, user.id]
        );
        
        // Record the initial movement
        await connection.query(
          `INSERT INTO store_inventory_movements 
           (store_id, business_id, product_id, movement_type, quantity, previous_quantity, new_quantity, reference_type, notes, created_by)
           VALUES (?, ?, ?, 'in', ?, 0, ?, 'purchase', ?, ?)`,
          [storeId, user.business_id, product_id, quantity, quantity, notes || 'Initial product addition', user.id]
        );
        
        console.log('Created new inventory record - quantity:', quantity);
      }
      
      await connection.commit();
      
      res.json({
        message: 'Product added to store inventory successfully',
        product_id: product_id,
        store_id: storeId,
        quantity: quantity
      });
      
    } catch (error) {
      console.error('Database transaction error:', error);
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error('Error adding product to store inventory:', error);
    res.status(500).json({ message: error.message || 'Server error' });
  }
});

// Add products to store warehouse (first tier - bulk storage)
router.post('/:storeId/add-products', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { storeId } = req.params;
    const { products } = req.body; // products: [{product_id, quantity, supplier, batch_number, expiry_date, notes}]
    const user = req.user;
    
    console.log('=== STORE WAREHOUSE ADD PRODUCTS DEBUG ===');
    console.log('Store ID (from params):', storeId);
    console.log('Store ID type:', typeof storeId);
    console.log('User:', { id: user.id, role: user.role, business_id: user.business_id });
    console.log('Products:', products);
    console.log('Request body:', req.body);
    
    if (!products || products.length === 0) {
      console.log('ERROR: No products provided');
      return res.status(400).json({ message: 'Products are required' });
    }
    
    // Check if user has access to this store
    console.log('Checking user access - Role:', user.role, 'Business ID:', user.business_id);
    
    if (user.role !== 'superadmin') {
      // For non-superadmin, check if they have access to any business assigned to this store
      console.log('User is not superadmin, checking store access for business:', user.business_id, 'store:', storeId);
      const query = `SELECT 1 FROM store_business_assignments sba 
         WHERE sba.store_id = ? AND sba.business_id = ? AND sba.is_active = 1`;
      const params = [storeId, user.business_id];
      console.log('Executing query:', query);
      console.log('With parameters:', params);
      
      const [accessCheck] = await pool.query(query, params);
      
      console.log('Access check result:', accessCheck);
      
      if (accessCheck.length === 0) {
        console.log('ACCESS DENIED: Business', user.business_id, 'not assigned to store', storeId);
        return res.status(403).json({ message: 'Access denied: No permission for this store' });
      }
    } else {
      console.log('User is superadmin, access granted');
    }
    
    // Start transaction
    const connection = await pool.getConnection();
    await connection.beginTransaction();
    
    try {
      const results = [];
      
      for (const product of products) {
        const { 
          product_id, 
          quantity, 
          supplier, 
          batch_number, 
          expiry_date, 
          notes 
        } = product;
        
        if (!product_id || !quantity) {
          throw new Error('Product ID and quantity are required for each product');
        }
        
        // Verify product exists in the products table
        const [productCheck] = await connection.query(
          'SELECT id, name, sku FROM products WHERE id = ? AND is_deleted = 0',
          [product_id]
        );
        
        if (productCheck.length === 0) {
          throw new Error(`Product with ID ${product_id} not found`);
        }
        
        // Check if inventory record already exists for this store and business
        console.log('Checking existing inventory for store:', storeId, 'product:', product_id, 'business:', user.business_id);
        const [existing] = await connection.query(
          'SELECT id, quantity FROM store_product_inventory WHERE store_id = ? AND product_id = ? AND business_id = ?',
          [storeId, product_id, user.business_id]
        );
        console.log('Existing inventory found:', existing);
        
        if (existing.length > 0) {
          // Update existing inventory (increment)
          const currentQuantity = existing[0].quantity;
          const newQuantity = currentQuantity + quantity;
          
          await connection.query(
            `UPDATE store_product_inventory 
             SET quantity = ?, updated_by = ?
             WHERE store_id = ? AND product_id = ? AND business_id = ?`,
            [newQuantity, user.id, storeId, product_id, user.business_id]
          );
          
          // Record the increment movement
          await connection.query(
            `INSERT INTO store_inventory_movements 
             (store_id, business_id, product_id, movement_type, quantity, previous_quantity, new_quantity, reference_type, notes, created_by)
             VALUES (?, ?, ?, 'in', ?, ?, ?, 'purchase', ?, ?)`,
            [storeId, user.business_id, product_id, quantity, currentQuantity, newQuantity, notes || 'Bulk restock', user.id]
          );
          
          results.push({
            product_id,
            product_name: productCheck[0].name,
            sku: productCheck[0].sku,
            previous_quantity: currentQuantity,
            added_quantity: quantity,
            new_quantity: newQuantity,
            action: 'incremented'
          });
        } else {
          // Create new inventory record
          console.log('Creating new inventory record for store:', storeId, 'product:', product_id, 'quantity:', quantity, 'business:', user.business_id);
          await connection.query(
            `INSERT INTO store_product_inventory 
             (store_id, business_id, product_id, quantity, min_stock_level, updated_by)
             VALUES (?, ?, ?, ?, 10, ?)`,
            [storeId, user.business_id, product_id, quantity, user.id]
          );
          console.log('New inventory record created successfully');
          
          // Record the initial movement
          await connection.query(
            `INSERT INTO store_inventory_movements 
             (store_id, business_id, product_id, movement_type, quantity, previous_quantity, new_quantity, reference_type, notes, created_by)
             VALUES (?, ?, ?, 'in', ?, 0, ?, 'purchase', ?, ?)`,
            [storeId, user.business_id, product_id, quantity, quantity, notes || 'Initial stock', user.id]
          );
          
          results.push({
            product_id,
            product_name: productCheck[0].name,
            sku: productCheck[0].sku,
            previous_quantity: 0,
            added_quantity: quantity,
            new_quantity: quantity,
            action: 'created'
          });
        }
      }
      
      await connection.commit();
      
      res.json({
        message: 'Products added to store warehouse successfully',
        results,
        total_products: results.length
      });
      
    } catch (error) {
      console.error('Database transaction error:', error);
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error('Error adding products to store warehouse:', error);
    console.error('Error stack:', error.stack);
    res.status(500).json({ message: error.message || 'Server error' });
  }
});

// Get store warehouse inventory (all products in store, not assigned to specific business)
router.get('/:storeId/inventory', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { storeId } = req.params;
    const user = req.user;
    
    // Check access
    if (user.role !== 'superadmin') {
      const [accessCheck] = await pool.query(
        `SELECT 1 FROM store_business_assignments sba 
         WHERE sba.store_id = ? AND sba.business_id = ? AND sba.is_active = 1`,
        [storeId, user.business_id]
      );
      
      if (accessCheck.length === 0) {
        return res.status(403).json({ message: 'Access denied' });
      }
    }
    
    const [inventory] = await pool.query(
      `SELECT 
         spi.*,
         p.name as product_name,
         p.sku,
         p.barcode,
         p.price,
         p.cost_price,
         p.stock_quantity as business_stock,
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
       ORDER BY p.name`,
      [storeId, user.business_id]
    );
    
    res.json({
      store_id: parseInt(storeId),
      inventory,
      total_products: inventory.length,
      total_quantity: inventory.reduce((sum, item) => sum + item.quantity, 0)
    });
    
  } catch (error) {
    console.error('Error getting store warehouse inventory:', error);
    res.status(500).json({ message: error.message || 'Server error' });
  }
});

// Transfer products from store warehouse to business (second tier)
router.post('/:storeId/transfer-to-business', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { storeId } = req.params;
    const { business_id, products } = req.body; // products: [{product_id, quantity, notes}]
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
        const { product_id, quantity, notes } = product;
        
        if (!product_id || !quantity) {
          throw new Error('Product ID and quantity are required for each product');
        }
        
        // Check store warehouse inventory
        const [storeInventory] = await connection.query(
          'SELECT id, quantity FROM store_product_inventory WHERE store_id = ? AND product_id = ? AND business_id IS NULL',
          [storeId, product_id]
        );
        
        if (storeInventory.length === 0) {
          throw new Error(`Product ${product_id} not found in store warehouse`);
        }
        
        const availableQuantity = storeInventory[0].quantity;
        if (availableQuantity < quantity) {
          throw new Error(`Insufficient stock in store warehouse. Available: ${availableQuantity}, Requested: ${quantity}`);
        }
        
        // Update store warehouse inventory (reduce)
        const newStoreQuantity = availableQuantity - quantity;
        await connection.query(
          'UPDATE store_product_inventory SET quantity = ?, updated_by = ? WHERE store_id = ? AND product_id = ? AND business_id IS NULL',
          [newStoreQuantity, user.id, storeId, product_id]
        );
        
        // Update or create business inventory
        const [businessInventory] = await connection.query(
          'SELECT id, quantity FROM store_product_inventory WHERE store_id = ? AND business_id = ? AND product_id = ?',
          [storeId, business_id, product_id]
        );
        
        if (businessInventory.length > 0) {
          // Update existing business inventory
          const currentBusinessQuantity = businessInventory[0].quantity;
          const newBusinessQuantity = currentBusinessQuantity + quantity;
          
          await connection.query(
            'UPDATE store_product_inventory SET quantity = ?, updated_by = ? WHERE store_id = ? AND business_id = ? AND product_id = ?',
            [newBusinessQuantity, user.id, storeId, business_id, product_id]
          );
          
          // Update business products table stock
          await connection.query(
            'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ? AND business_id = ?',
            [quantity, product_id, business_id]
          );
          
          results.push({
            product_id,
            previous_business_quantity: currentBusinessQuantity,
            transferred_quantity: quantity,
            new_business_quantity: newBusinessQuantity,
            action: 'incremented'
          });
        } else {
          // Create new business inventory record
          await connection.query(
            `INSERT INTO store_product_inventory 
             (store_id, business_id, product_id, quantity, min_stock_level, updated_by)
             VALUES (?, ?, ?, ?, 10, ?)`,
            [storeId, business_id, product_id, quantity, user.id]
          );
          
          // Update business products table stock
          await connection.query(
            'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ? AND business_id = ?',
            [quantity, product_id, business_id]
          );
          
          results.push({
            product_id,
            previous_business_quantity: 0,
            transferred_quantity: quantity,
            new_business_quantity: quantity,
            action: 'created'
          });
        }
        
        // Record movements
        await connection.query(
          `INSERT INTO store_inventory_movements 
           (store_id, business_id, product_id, movement_type, quantity, previous_quantity, new_quantity, reference_type, notes, created_by)
           VALUES (?, NULL, ?, 'out', ?, ?, ?, 'transfer', ?, ?)`,
          [storeId, product_id, quantity, availableQuantity, newStoreQuantity, notes || 'Transfer to business', user.id]
        );
        
        await connection.query(
          `INSERT INTO store_inventory_movements 
           (store_id, business_id, product_id, movement_type, quantity, previous_quantity, new_quantity, reference_type, notes, created_by)
           VALUES (?, ?, ?, 'in', ?, ?, ?, 'transfer', ?, ?)`,
          [storeId, business_id, product_id, quantity, businessInventory.length > 0 ? businessInventory[0].quantity : 0, businessInventory.length > 0 ? businessInventory[0].quantity + quantity : quantity, notes || 'Transfer from store', user.id]
        );
      }
      
      await connection.commit();
      
      res.json({
        message: 'Products transferred from store warehouse to business successfully',
        results,
        total_products: results.length
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

// Get business inventory (products assigned to specific business from this store)
router.get('/:storeId/business-inventory/:businessId', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { storeId, businessId } = req.params;
    const user = req.user;
    
    // Check access
    if (user.role !== 'superadmin' && user.business_id != businessId) {
      return res.status(403).json({ message: 'Access denied' });
    }
    
    const [inventory] = await pool.query(
      `SELECT 
         spi.*,
         p.name as product_name,
         p.sku,
         p.barcode,
         p.price,
         p.cost_price,
         p.stock_quantity as business_stock,
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
       ORDER BY p.name`,
      [storeId, businessId]
    );
    
    res.json({
      store_id: parseInt(storeId),
      business_id: parseInt(businessId),
      inventory,
      total_products: inventory.length,
      total_quantity: inventory.reduce((sum, item) => sum + item.quantity, 0)
    });
    
  } catch (error) {
    console.error('Error getting business inventory:', error);
    res.status(500).json({ message: error.message || 'Server error' });
  }
});

module.exports = router;
