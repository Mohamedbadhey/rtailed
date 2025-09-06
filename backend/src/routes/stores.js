const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { auth, checkRole } = require('../middleware/auth');

// =====================================================
// STORE MANAGEMENT API - PART 1: BASIC STORE OPERATIONS
// =====================================================

// Get all stores with pagination (admin, manager, superadmin)
router.get('/', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const offset = parseInt(req.query.offset) || 0;
    const search = req.query.search || '';
    const store_type = req.query.store_type || '';
    const is_active = req.query.is_active !== undefined ? req.query.is_active === 'true' : null;
    
    let whereClause = '';
    let params = [];
    
    const conditions = [];
    
    if (search) {
      conditions.push('(s.name LIKE ? OR s.store_code LIKE ? OR s.address LIKE ?)');
      params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }
    
    if (store_type) {
      conditions.push('s.store_type = ?');
      params.push(store_type);
    }
    
    if (is_active !== null) {
      conditions.push('s.is_active = ?');
      params.push(is_active);
    }
    
    if (conditions.length > 0) {
      whereClause = 'WHERE ' + conditions.join(' AND ');
    }
    
    // Get stores with pagination
    const [stores] = await pool.query(
      `SELECT s.*, 
              u.username as created_by_username,
              COUNT(DISTINCT sba.business_id) as assigned_businesses_count,
              COUNT(DISTINCT spi.product_id) as total_products
       FROM stores s
       LEFT JOIN users u ON s.created_by = u.id
       LEFT JOIN store_business_assignments sba ON s.id = sba.store_id AND sba.is_active = 1
       LEFT JOIN store_product_inventory spi ON s.id = spi.store_id
       ${whereClause}
       GROUP BY s.id
       ORDER BY s.created_at DESC 
       LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );
    
    // Get total count for pagination
    const [countResult] = await pool.query(
      `SELECT COUNT(*) as total FROM stores s ${whereClause}`,
      params
    );
    
    const total = countResult[0].total;
    
    res.json({
      stores,
      pagination: {
        total,
        limit,
        offset,
        hasMore: offset + limit < total
      }
    });
  } catch (error) {
    console.error('Error fetching stores:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get store details by ID
router.get('/:storeId', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { storeId } = req.params;
    const user = req.user;
    
    // Check if user has access to this store
    let accessCheck = '';
    let params = [storeId];
    
    if (user.role !== 'superadmin') {
      accessCheck = `AND EXISTS (
        SELECT 1 FROM store_business_assignments sba 
        WHERE sba.store_id = s.id 
        AND sba.business_id = ? 
        AND sba.is_active = 1
      )`;
      params.push(user.business_id);
    }
    
    const [stores] = await pool.query(
      `SELECT s.*, 
              u.username as created_by_username,
              COUNT(DISTINCT sba.business_id) as assigned_businesses_count
       FROM stores s
       LEFT JOIN users u ON s.created_by = u.id
       LEFT JOIN store_business_assignments sba ON s.id = sba.store_id AND sba.is_active = 1
       WHERE s.id = ? ${accessCheck}
       GROUP BY s.id`,
      params
    );
    
    if (stores.length === 0) {
      return res.status(404).json({ message: 'Store not found or access denied' });
    }
    
    const store = stores[0];
    
    // Get assigned businesses
    const [businesses] = await pool.query(
      `SELECT b.id, b.name, b.business_code, sba.assigned_at, sba.notes
       FROM businesses b
       JOIN store_business_assignments sba ON b.id = sba.business_id
       WHERE sba.store_id = ? AND sba.is_active = 1
       ORDER BY sba.assigned_at DESC`,
      [storeId]
    );
    
    // Get inventory summary
    const [inventory] = await pool.query(
      `SELECT 
         COUNT(DISTINCT spi.product_id) as total_products,
         SUM(spi.quantity) as total_quantity,
         SUM(spi.reserved_quantity) as total_reserved,
         SUM(spi.available_quantity) as total_available,
         COUNT(CASE WHEN spi.quantity <= spi.min_stock_level THEN 1 END) as low_stock_products,
         COUNT(CASE WHEN spi.quantity = 0 THEN 1 END) as out_of_stock_products
       FROM store_product_inventory spi
       WHERE spi.store_id = ?`,
      [storeId]
    );
    
    res.json({
      ...store,
      assigned_businesses: businesses,
      inventory_summary: inventory[0]
    });
  } catch (error) {
    console.error('Error fetching store details:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Create a new store (superadmin only)
router.post('/', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const {
      name,
      store_code,
      description,
      address,
      city,
      state,
      country = 'Nigeria',
      postal_code,
      phone,
      email,
      manager_name,
      manager_phone,
      manager_email,
      store_type = 'warehouse',
      capacity
    } = req.body;
    
    if (!name || !store_code || !address) {
      return res.status(400).json({ message: 'Name, store code, and address are required' });
    }
    
    // Check if store code already exists
    const [existingStore] = await pool.query(
      'SELECT id FROM stores WHERE store_code = ?',
      [store_code]
    );
    
    if (existingStore.length > 0) {
      return res.status(400).json({ message: 'Store code already exists' });
    }
    
    const [result] = await pool.query(
      `INSERT INTO stores (
        name, store_code, description, address, city, state, country, 
        postal_code, phone, email, manager_name, manager_phone, 
        manager_email, store_type, capacity, created_by
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        name, store_code, description, address, city, state, country,
        postal_code, phone, email, manager_name, manager_phone,
        manager_email, store_type, capacity, req.user.id
      ]
    );
    
    // Log the action
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'CREATE_STORE', 'stores', result.insertId, JSON.stringify({ name, store_code, store_type })]
    );
    
    res.status(201).json({ 
      message: 'Store created successfully',
      store_id: result.insertId
    });
  } catch (error) {
    console.error('Error creating store:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// =====================================================
// STORE-BUSINESS ASSIGNMENT MANAGEMENT
// =====================================================

// Assign business to store (superadmin only)
router.post('/:storeId/assign-business', auth, checkRole(['superadmin']), async (req, res) => {
  try {
    const { storeId } = req.params;
    const { business_id, notes } = req.body;
    
    if (!business_id) {
      return res.status(400).json({ message: 'Business ID is required' });
    }
    
    // Check if store exists
    const [store] = await pool.query('SELECT id FROM stores WHERE id = ?', [storeId]);
    if (store.length === 0) {
      return res.status(404).json({ message: 'Store not found' });
    }
    
    // Check if business exists
    const [business] = await pool.query('SELECT id FROM businesses WHERE id = ?', [business_id]);
    if (business.length === 0) {
      return res.status(404).json({ message: 'Business not found' });
    }
    
    // Check if assignment already exists
    const [existing] = await pool.query(
      'SELECT id FROM store_business_assignments WHERE store_id = ? AND business_id = ?',
      [storeId, business_id]
    );
    
    if (existing.length > 0) {
      // Update existing assignment to active
      await pool.query(
        'UPDATE store_business_assignments SET is_active = 1, notes = ?, assigned_at = CURRENT_TIMESTAMP WHERE store_id = ? AND business_id = ?',
        [notes, storeId, business_id]
      );
    } else {
      // Create new assignment
      await pool.query(
        'INSERT INTO store_business_assignments (store_id, business_id, assigned_by, notes) VALUES (?, ?, ?, ?)',
        [storeId, business_id, req.user.id, notes]
      );
    }
    
    // Log the action
    await pool.query(
      'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'ASSIGN_BUSINESS_TO_STORE', 'store_business_assignments', storeId, JSON.stringify({ business_id, notes })]
    );
    
    res.json({ message: 'Business assigned to store successfully' });
  } catch (error) {
    console.error('Error assigning business to store:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
