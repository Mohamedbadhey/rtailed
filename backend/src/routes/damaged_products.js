const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { auth, checkRole } = require('../middleware/auth');

// Get all damaged products
router.get('/', auth, async (req, res) => {
  try {
    let query = `
      SELECT 
        dp.id,
        dp.product_id,
        dp.quantity,
        dp.damage_type,
        dp.damage_date,
        dp.damage_reason,
        dp.estimated_loss,
        dp.reported_by,
        dp.created_at,
        p.name as product_name,
        p.sku as product_sku,
        p.cost_price as product_cost,
        p.price as product_price,
        c.name as category_name,
        u.username as reported_by_name
      FROM damaged_products dp
      JOIN products p ON dp.product_id = p.id
      LEFT JOIN categories c ON p.category_id = c.id
      JOIN users u ON dp.reported_by = u.id
      WHERE dp.business_id = ?
      ORDER BY dp.created_at DESC
    `;
    let params = [req.user.business_id];
    
    if (req.user.role === 'superadmin') {
      query = query.replace('WHERE dp.business_id = ?', '');
      params = [];
    }
    
    const [damagedProducts] = await pool.query(query, params);
    res.json(damagedProducts);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get single damaged product
router.get('/:id', auth, async (req, res) => {
  try {
    let query = `
      SELECT 
        dp.id,
        dp.product_id,
        dp.quantity,
        dp.damage_type,
        dp.damage_date,
        dp.damage_reason,
        dp.estimated_loss,
        dp.reported_by,
        dp.created_at,
        p.name as product_name,
        p.sku as product_sku,
        p.cost_price as product_cost,
        p.price as product_price,
        c.name as category_name,
        u.username as reported_by_name
      FROM damaged_products dp
      JOIN products p ON dp.product_id = p.id
      LEFT JOIN categories c ON p.category_id = c.id
      JOIN users u ON dp.reported_by = u.id
      WHERE dp.id = ? AND dp.business_id = ?
    `;
    let params = [req.params.id, req.user.business_id];
    
    if (req.user.role === 'superadmin') {
      query = query.replace('AND dp.business_id = ?', '');
      params = [req.params.id];
    }
    
    const [damagedProducts] = await pool.query(query, params);
    
    if (damagedProducts.length === 0) {
      return res.status(404).json({ message: 'Damaged product record not found' });
    }
    
    res.json(damagedProducts[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Report damaged product
router.post('/', [auth, checkRole(['admin', 'manager', 'cashier'])], async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const {
      product_id,
      quantity,
      damage_type,
      damage_date,
      damage_reason,
      estimated_loss
    } = req.body;

    // Validate required fields
    if (!product_id || !quantity || !damage_type || !damage_date) {
      await connection.rollback();
      return res.status(400).json({ 
        message: 'Missing required fields: product_id, quantity, damage_type, and damage_date are required' 
      });
    }

    // Check if product exists and belongs to user's business
    let productQuery = 'SELECT * FROM products WHERE id = ?';
    let productParams = [product_id];
    
    if (req.user.role !== 'superadmin') {
      productQuery += ' AND business_id = ?';
      productParams.push(req.user.business_id);
    }
    
    const [products] = await connection.query(productQuery, productParams);
    
    if (products.length === 0) {
      await connection.rollback();
      return res.status(404).json({ message: 'Product not found or access denied' });
    }

    const product = products[0];
    
    // Check if requested quantity is available
    if (product.stock_quantity < quantity) {
      await connection.rollback();
      return res.status(400).json({ 
        message: `Insufficient stock. Available: ${product.stock_quantity}, Requested: ${quantity}` 
      });
    }

    // Calculate estimated loss: if not provided, use product cost price * quantity
    let calculatedEstimatedLoss = estimated_loss ? parseFloat(estimated_loss) : null;
    if (calculatedEstimatedLoss === null || calculatedEstimatedLoss === 0) {
      calculatedEstimatedLoss = parseFloat(product.cost_price) * quantity;
    }

    // Insert damaged product record
    const [result] = await connection.query(
      `INSERT INTO damaged_products (
        product_id, quantity, damage_type, damage_date, damage_reason, 
        estimated_loss, reported_by, business_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        product_id,
        quantity,
        damage_type,
        damage_date,
        damage_reason || null,
        calculatedEstimatedLoss,
        req.user.id,
        req.user.business_id
      ]
    );

    // Update product stock and damaged quantity
    await connection.query(
      'UPDATE products SET stock_quantity = stock_quantity - ?, damaged_quantity = damaged_quantity + ? WHERE id = ?',
      [quantity, quantity, product_id]
    );

    // Add inventory transaction for the damage
    await connection.query(
      `INSERT INTO inventory_transactions (
        product_id, quantity, transaction_type, notes, business_id
      ) VALUES (?, ?, ?, ?, ?)`,
      [
        product_id,
        -quantity,
        'adjustment',
        `Damaged: ${damage_type} - ${damage_reason || 'No reason provided'}`,
        req.user.business_id
      ]
    );

    await connection.commit();

    res.status(201).json({
      message: 'Damaged product reported successfully',
      damagedProductId: result.insertId
    });
  } catch (error) {
    await connection.rollback();
    console.error('Report Damaged Product Error:', error);
    res.status(500).json({ message: error.message || 'Server error' });
  } finally {
    connection.release();
  }
});

// Update damaged product record
router.put('/:id', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const {
      quantity,
      damage_type,
      damage_date,
      damage_reason,
      estimated_loss
    } = req.body;

    // Check if damaged product record exists
    let checkQuery = 'SELECT * FROM damaged_products WHERE id = ?';
    let checkParams = [req.params.id];
    
    if (req.user.role !== 'superadmin') {
      checkQuery += ' AND business_id = ?';
      checkParams.push(req.user.business_id);
    }
    
    const [damagedProducts] = await connection.query(checkQuery, checkParams);
    
    if (damagedProducts.length === 0) {
      await connection.rollback();
      return res.status(404).json({ message: 'Damaged product record not found or access denied' });
    }

    const damagedProduct = damagedProducts[0];

    // Get product info for cost price calculation
    let productQuery = 'SELECT cost_price FROM products WHERE id = ?';
    let productParams = [damagedProduct.product_id];
    
    if (req.user.role !== 'superadmin') {
      productQuery += ' AND business_id = ?';
      productParams.push(req.user.business_id);
    }
    
    const [products] = await connection.query(productQuery, productParams);
    const product = products[0];

    // Update the record
    const updateFields = [];
    const updateValues = [];

    if (quantity !== undefined) {
      updateFields.push('quantity = ?');
      updateValues.push(quantity);
    }
    if (damage_type) {
      updateFields.push('damage_type = ?');
      updateValues.push(damage_type);
    }
    if (damage_date) {
      updateFields.push('damage_date = ?');
      updateValues.push(damage_date);
    }
    if (damage_reason !== undefined) {
      updateFields.push('damage_reason = ?');
      updateValues.push(damage_reason);
    }
    if (estimated_loss !== undefined) {
      // Calculate estimated loss: if not provided, use product cost price * quantity
      let calculatedEstimatedLoss = estimated_loss ? parseFloat(estimated_loss) : null;
      if (calculatedEstimatedLoss === null || calculatedEstimatedLoss === 0) {
        const currentQuantity = quantity !== undefined ? quantity : damagedProduct.quantity;
        calculatedEstimatedLoss = parseFloat(product.cost_price) * currentQuantity;
      }
      
      updateFields.push('estimated_loss = ?');
      updateValues.push(calculatedEstimatedLoss);
    }

    if (updateFields.length === 0) {
      await connection.rollback();
      return res.status(400).json({ message: 'No fields to update' });
    }

    updateValues.push(req.params.id);

    await connection.query(
      `UPDATE damaged_products SET ${updateFields.join(', ')} WHERE id = ?`,
      updateValues
    );

    // If quantity changed, update product stock accordingly
    if (quantity !== undefined && quantity !== damagedProduct.quantity) {
      const quantityDifference = quantity - damagedProduct.quantity;
      
      await connection.query(
        'UPDATE products SET stock_quantity = stock_quantity - ?, damaged_quantity = damaged_quantity + ? WHERE id = ?',
        [quantityDifference, quantityDifference, damagedProduct.product_id]
      );
    }

    await connection.commit();

    res.json({ message: 'Damaged product record updated successfully' });
  } catch (error) {
    await connection.rollback();
    console.error('Update Damaged Product Error:', error);
    res.status(500).json({ message: error.message || 'Server error' });
  } finally {
    connection.release();
  }
});

// Delete damaged product record
router.delete('/:id', [auth, checkRole(['admin'])], async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    // Check if damaged product record exists
    let checkQuery = 'SELECT * FROM damaged_products WHERE id = ?';
    let checkParams = [req.params.id];
    
    if (req.user.role !== 'superadmin') {
      checkQuery += ' AND business_id = ?';
      checkParams.push(req.user.business_id);
    }
    
    const [damagedProducts] = await connection.query(checkQuery, checkParams);
    
    if (damagedProducts.length === 0) {
      await connection.rollback();
      return res.status(404).json({ message: 'Damaged product record not found or access denied' });
    }

    const damagedProduct = damagedProducts[0];

    // Restore the quantity back to stock
    await connection.query(
      'UPDATE products SET stock_quantity = stock_quantity + ?, damaged_quantity = damaged_quantity - ? WHERE id = ?',
      [damagedProduct.quantity, damagedProduct.quantity, damagedProduct.product_id]
    );

    // Delete the damaged product record
    await connection.query(
      'DELETE FROM damaged_products WHERE id = ?',
      [req.params.id]
    );

    await connection.commit();

    res.json({ message: 'Damaged product record deleted successfully' });
  } catch (error) {
    await connection.rollback();
    console.error('Delete Damaged Product Error:', error);
    res.status(500).json({ message: error.message || 'Server error' });
  } finally {
    connection.release();
  }
});

// Get damaged products report
router.get('/reports/summary', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  try {
    const { start_date, end_date, damage_type, user_id } = req.query;
    
    let whereClause = 'WHERE dp.business_id = ?';
    let params = [req.user.business_id];
    
    if (req.user.role === 'superadmin') {
      whereClause = '';
      params = [];
    }
    
    if (start_date) {
      // Convert start_date to start of day for proper comparison
      const startDateTime = start_date.includes(' ') ? start_date : start_date + ' 00:00:00';
      whereClause += whereClause ? ' AND dp.damage_date >= ?' : 'WHERE dp.damage_date >= ?';
      params.push(startDateTime);
    }
    
    if (end_date) {
      // Convert end_date to end of day for proper comparison
      const endDateTime = end_date.includes(' ') ? end_date : end_date + ' 23:59:59';
      whereClause += whereClause ? ' AND dp.damage_date <= ?' : 'WHERE dp.damage_date <= ?';
      params.push(endDateTime);
    }
    
    if (damage_type) {
      whereClause += whereClause ? ' AND dp.damage_type = ?' : 'WHERE dp.damage_type = ?';
      params.push(damage_type);
    }
    
    // Add cashier filter if provided
    if (user_id && user_id !== 'all') {
      whereClause += whereClause ? ' AND dp.reported_by = ?' : 'WHERE dp.reported_by = ?';
      params.push(user_id);
    }

    // Get summary statistics
    const [summary] = await pool.query(
      `SELECT 
        COUNT(*) as total_incidents,
        SUM(dp.quantity) as total_quantity_damaged,
        SUM(dp.estimated_loss) as total_estimated_loss,
        AVG(dp.estimated_loss) as avg_loss_per_item
      FROM damaged_products dp
      ${whereClause}`,
      params
    );

    // Get breakdown by damage type
    const [damageTypeBreakdown] = await pool.query(
      `SELECT 
        dp.damage_type,
        COUNT(*) as incident_count,
        SUM(dp.quantity) as total_quantity,
        SUM(dp.estimated_loss) as total_loss
      FROM damaged_products dp
      ${whereClause}
      GROUP BY dp.damage_type
      ORDER BY total_loss DESC`,
      params
    );

    // Get top products by damage
    const [topDamagedProducts] = await pool.query(
      `SELECT 
        p.name as product_name,
        p.sku as product_sku,
        COUNT(dp.id) as incident_count,
        SUM(dp.quantity) as total_quantity_damaged,
        SUM(dp.estimated_loss) as total_loss
      FROM damaged_products dp
      JOIN products p ON dp.product_id = p.id
      ${whereClause}
      GROUP BY dp.product_id, p.name, p.sku
      ORDER BY total_loss DESC
      LIMIT 10`,
      params
    );

    // Get breakdown by cashier
    const [cashierBreakdown] = await pool.query(
      `SELECT 
        u.username as cashier_name,
        COUNT(dp.id) as incident_count,
        SUM(dp.quantity) as total_quantity_damaged,
        SUM(dp.estimated_loss) as total_loss
      FROM damaged_products dp
      JOIN users u ON dp.reported_by = u.id
      ${whereClause}
      GROUP BY dp.reported_by, u.username
      ORDER BY total_loss DESC`,
      params
    );

    res.json({
      summary: summary[0],
      damageTypeBreakdown,
      topDamagedProducts,
      cashierBreakdown
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get damaged products by product ID
router.get('/product/:productId', auth, async (req, res) => {
  try {
    let query = `
      SELECT 
        dp.id,
        dp.quantity,
        dp.damage_type,
        dp.damage_date,
        dp.damage_reason,
        dp.estimated_loss,
        dp.created_at,
        u.username as reported_by_name
      FROM damaged_products dp
      JOIN users u ON dp.reported_by = u.id
      WHERE dp.product_id = ? AND dp.business_id = ?
      ORDER BY dp.created_at DESC
    `;
    let params = [req.params.productId, req.user.business_id];
    
    if (req.user.role === 'superadmin') {
      query = query.replace('AND dp.business_id = ?', '');
      params = [req.params.productId];
    }
    
    const [damagedProducts] = await pool.query(query, params);
    res.json(damagedProducts);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router; 