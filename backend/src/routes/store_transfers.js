const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { auth, checkRole } = require('../middleware/auth');

// =====================================================
// STORE TRANSFER MANAGEMENT API - PART 1: BASIC OPERATIONS
// =====================================================

// Get all transfers with pagination
router.get('/', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const offset = parseInt(req.query.offset) || 0;
    const search = req.query.search || '';
    const status = req.query.status || '';
    const transfer_type = req.query.transfer_type || '';
    const user = req.user;
    
    let whereClause = '';
    let params = [];
    
    const conditions = [];
    
    // Filter by business access for non-superadmin users
    if (user.role !== 'superadmin') {
      conditions.push('(st.from_business_id = ? OR st.to_business_id = ?)');
      params.push(user.business_id, user.business_id);
    }
    
    if (search) {
      conditions.push('(st.transfer_code LIKE ? OR fs.name LIKE ? OR ts.name LIKE ? OR fb.name LIKE ? OR tb.name LIKE ?)');
      params.push(`%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`);
    }
    
    if (status) {
      conditions.push('st.status = ?');
      params.push(status);
    }
    
    if (transfer_type) {
      conditions.push('st.transfer_type = ?');
      params.push(transfer_type);
    }
    
    if (conditions.length > 0) {
      whereClause = 'WHERE ' + conditions.join(' AND ');
    }
    
    // Get transfers with pagination
    const [transfers] = await pool.query(
      `SELECT st.*,
              fs.name as from_store_name,
              ts.name as to_store_name,
              fb.name as from_business_name,
              tb.name as to_business_name,
              req_user.username as requested_by_username,
              app_user.username as approved_by_username,
              del_user.username as delivered_by_username,
              COUNT(sti.id) as items_count,
              SUM(sti.total_cost) as total_cost
       FROM store_transfers st
       LEFT JOIN stores fs ON st.from_store_id = fs.id
       LEFT JOIN stores ts ON st.to_store_id = ts.id
       LEFT JOIN businesses fb ON st.from_business_id = fb.id
       LEFT JOIN businesses tb ON st.to_business_id = tb.id
       LEFT JOIN users req_user ON st.requested_by = req_user.id
       LEFT JOIN users app_user ON st.approved_by = app_user.id
       LEFT JOIN users del_user ON st.delivered_by = del_user.id
       LEFT JOIN store_transfer_items sti ON st.id = sti.transfer_id
       ${whereClause}
       GROUP BY st.id
       ORDER BY st.requested_at DESC 
       LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );
    
    // Get total count for pagination
    const [countResult] = await pool.query(
      `SELECT COUNT(*) as total FROM store_transfers st ${whereClause}`,
      params
    );
    
    const total = countResult[0].total;
    
    res.json({
      transfers,
      pagination: {
        total,
        limit,
        offset,
        hasMore: offset + limit < total
      }
    });
  } catch (error) {
    console.error('Error fetching transfers:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get transfer details by ID
router.get('/:transferId', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const { transferId } = req.params;
    const user = req.user;
    
    // Check if user has access to this transfer
    let accessCheck = '';
    let params = [transferId];
    
    if (user.role !== 'superadmin') {
      accessCheck = `AND (st.from_business_id = ? OR st.to_business_id = ?)`;
      params.push(user.business_id, user.business_id);
    }
    
    const [transfers] = await pool.query(
      `SELECT st.*,
              fs.name as from_store_name,
              fs.store_code as from_store_code,
              ts.name as to_store_name,
              ts.store_code as to_store_code,
              fb.name as from_business_name,
              tb.name as to_business_name,
              req_user.username as requested_by_username,
              app_user.username as approved_by_username,
              del_user.username as delivered_by_username
       FROM store_transfers st
       LEFT JOIN stores fs ON st.from_store_id = fs.id
       LEFT JOIN stores ts ON st.to_store_id = ts.id
       LEFT JOIN businesses fb ON st.from_business_id = fb.id
       LEFT JOIN businesses tb ON st.to_business_id = tb.id
       LEFT JOIN users req_user ON st.requested_by = req_user.id
       LEFT JOIN users app_user ON st.approved_by = app_user.id
       LEFT JOIN users del_user ON st.delivered_by = del_user.id
       WHERE st.id = ? ${accessCheck}`,
      params
    );
    
    if (transfers.length === 0) {
      return res.status(404).json({ message: 'Transfer not found or access denied' });
    }
    
    const transfer = transfers[0];
    
    // Get transfer items
    const [items] = await pool.query(
      `SELECT sti.*, p.name as product_name, p.sku, p.barcode
       FROM store_transfer_items sti
       JOIN products p ON sti.product_id = p.id
       WHERE sti.transfer_id = ?
       ORDER BY sti.id`,
      [transferId]
    );
    
    res.json({
      ...transfer,
      items
    });
  } catch (error) {
    console.error('Error fetching transfer details:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Create a new transfer request
router.post('/', auth, checkRole(['admin', 'manager', 'superadmin']), async (req, res) => {
  try {
    const {
      transfer_type,
      from_store_id,
      to_store_id,
      to_business_id,
      expected_delivery_date,
      notes,
      items
    } = req.body;
    
    const user = req.user;
    const from_business_id = user.business_id;
    
    if (!transfer_type || !items || items.length === 0) {
      return res.status(400).json({ message: 'Transfer type and items are required' });
    }
    
    // Validate transfer type and required fields
    if (transfer_type === 'store_to_store' && (!from_store_id || !to_store_id)) {
      return res.status(400).json({ message: 'From store and to store are required for store-to-store transfers' });
    }
    
    if (transfer_type === 'business_to_business' && !to_business_id) {
      return res.status(400).json({ message: 'To business is required for business-to-business transfers' });
    }
    
    // Generate transfer code
    const transfer_code = `TRF-${Date.now()}-${Math.random().toString(36).substr(2, 4).toUpperCase()}`;
    
    // Start transaction
    const connection = await pool.getConnection();
    await connection.beginTransaction();
    
    try {
      // Create transfer record
      const [transferResult] = await connection.query(
        `INSERT INTO store_transfers (
          transfer_code, transfer_type, from_store_id, to_store_id,
          from_business_id, to_business_id, requested_by,
          expected_delivery_date, notes, status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
        [
          transfer_code, transfer_type, from_store_id, to_store_id,
          from_business_id, to_business_id, user.id,
          expected_delivery_date, notes
        ]
      );
      
      const transferId = transferResult.insertId;
      
      // Add transfer items
      for (const item of items) {
        const { product_id, requested_quantity, unit_cost, notes: item_notes } = item;
        
        if (!product_id || !requested_quantity || !unit_cost) {
          throw new Error('Product ID, quantity, and unit cost are required for each item');
        }
        
        await connection.query(
          `INSERT INTO store_transfer_items (
            transfer_id, product_id, requested_quantity, unit_cost, notes
          ) VALUES (?, ?, ?, ?, ?)`,
          [transferId, product_id, requested_quantity, unit_cost, item_notes]
        );
      }
      
      await connection.commit();
      
      // Log the action
      await pool.query(
        'INSERT INTO system_logs (user_id, action, table_name, record_id, new_values) VALUES (?, ?, ?, ?, ?)',
        [user.id, 'CREATE_TRANSFER', 'store_transfers', transferId, JSON.stringify({ transfer_code, transfer_type, items_count: items.length })]
      );
      
      res.status(201).json({ 
        message: 'Transfer request created successfully',
        transfer_id: transferId,
        transfer_code
      });
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error('Error creating transfer:', error);
    res.status(500).json({ message: error.message || 'Server error' });
  }
});

module.exports = router;
