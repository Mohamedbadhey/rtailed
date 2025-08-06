const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { auth, checkRole } = require('../middleware/auth');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const uploadErrorHandler = require('../middleware/uploadErrorHandler');

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    // Use Railway's persistent storage directory
    const baseDir = process.env.RAILWAY_VOLUME_MOUNT_PATH || path.join(__dirname, '../../uploads');
    const uploadDir = path.join(baseDir, 'products');
    
    console.log('📁 File upload destination:', uploadDir);
    console.log('📁 Railway volume path:', process.env.RAILWAY_VOLUME_MOUNT_PATH);
    console.log('📁 Environment:', process.env.RAILWAY_VOLUME_MOUNT_PATH ? 'Railway' : 'Local');
    
    // Ensure directory exists
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
      console.log('✅ Created uploads/products directory for file upload:', uploadDir);
    } else {
      console.log('✅ Upload directory already exists:', uploadDir);
    }
    
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    // Sanitize filename to prevent issues
    const sanitizedName = file.originalname.replace(/[^a-zA-Z0-9.-]/g, '_');
    const finalFilename = `${Date.now()}-${sanitizedName}`;
    console.log('📁 File will be saved as:', finalFilename);
    cb(null, finalFilename);
  }
});

const allowedExtensions = ['.png', '.jpg', '.jpeg'];

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
  fileFilter: (req, file, cb) => {
    // Debug log
    console.log('File received by Multer:', {
      originalname: file.originalname,
      mimetype: file.mimetype,
      fieldname: file.fieldname,
      size: file.size,
    });
    // Check extension (case-insensitive)
    const ext = file.originalname
      .toLowerCase()
      .substring(file.originalname.lastIndexOf('.'));
    if (allowedExtensions.includes(ext)) {
      return cb(null, true);
    }
    cb(new Error('Only .png, .jpg and .jpeg format allowed!'), false);
  }
});

// Get all products
router.get('/', auth, async (req, res) => {
  try {
    console.log('🛍️ ===== PRODUCTS GET REQUEST START =====');
    console.log('🛍️ User role:', req.user.role);
    console.log('🛍️ Business ID:', req.user.business_id);
    console.log('🛍️ User ID:', req.user.id);
    
    let query = 'SELECT * FROM products WHERE business_id = ? ORDER BY name';
    let params = [req.user.business_id];
    if (req.user.role === 'superadmin') {
      query = 'SELECT * FROM products ORDER BY name';
      params = [];
    }
    
    console.log('🛍️ Query:', query);
    console.log('🛍️ Params:', params);
    const [products] = await pool.query(query, params);
    console.log('🛍️ Found', products.length, 'products');
    
    // Debug each product's image URL
    products.forEach((product, index) => {
      console.log(`🛍️ Product ${index + 1}:`);
      console.log(`  - ID: ${product.id}`);
      console.log(`  - Name: ${product.name}`);
      console.log(`  - Image URL: ${product.image_url || 'NULL'}`);
      if (product.image_url) {
        const fullUrl = `https://rtailed-production.up.railway.app${product.image_url}`;
        console.log(`  - Full URL: ${fullUrl}`);
      }
    });
    
    console.log('🛍️ ===== PRODUCTS GET REQUEST END =====');
    res.json(products);
  } catch (error) {
    console.log('🛍️ ❌ Error in products GET:', error);
    console.log('🛍️ Error stack:', error.stack);
    console.log('🛍️ ===== PRODUCTS GET REQUEST END (ERROR) =====');
    res.status(500).json({ message: 'Server error', details: error.message });
  }
});

// Get single product
router.get('/:id', auth, async (req, res) => {
  try {
    let query = 'SELECT * FROM products WHERE id = ? AND business_id = ?';
    let params = [req.params.id, req.user.business_id];
    if (req.user.role === 'superadmin') {
      query = 'SELECT * FROM products WHERE id = ?';
      params = [req.params.id];
    }
    const [products] = await pool.query(query, params);
    if (products.length === 0) {
      return res.status(404).json({ message: 'Product not found' });
    }
    res.json(products[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Create product
router.post('/', [auth, checkRole(['admin', 'manager']), upload.single('image')], async (req, res, next) => {
  const connection = await pool.getConnection();
  try {
    console.log('=== PRODUCT CREATION DEBUG ===');
    console.log('User info:', { id: req.user.id, role: req.user.role, business_id: req.user.business_id });
    console.log('Request body:', req.body);
    console.log('File info:', req.file ? { filename: req.file.filename, size: req.file.size } : 'No file');
    
    await connection.beginTransaction();

    const {
      name,
      description,
      sku,
      barcode,
      category_id,
      price,
      wholesale_price,
      cost_price,
      stock_quantity,
      low_stock_threshold
    } = req.body;

    // Validate required fields
    if (!name || !sku || !price || !cost_price) {
      await connection.rollback();
      return res.status(400).json({ 
        message: 'Missing required fields: name, sku, price, and cost_price are required' 
      });
    }

    // Validate numeric fields
    if (isNaN(parseFloat(price)) || isNaN(parseFloat(cost_price))) {
      await connection.rollback();
      return res.status(400).json({ 
        message: 'Price and cost_price must be valid numbers' 
      });
    }

    // Check if SKU already exists
    const [existingProducts] = await connection.query(
      'SELECT id FROM products WHERE sku = ?',
      [sku]
    );

    if (existingProducts.length > 0) {
      await connection.rollback();
      return res.status(400).json({ 
        message: 'Product with this SKU already exists' 
      });
    }

    const image_url = req.file ? `/uploads/products/${req.file.filename}` : null;
    const businessId = req.user.business_id;
    
    const insertValues = [
      name, 
      description || null, 
      sku, 
      barcode || null, 
      category_id || null,
      parseFloat(price), 
      wholesale_price !== undefined ? parseFloat(wholesale_price) : null,
      parseFloat(cost_price), 
      parseInt(stock_quantity) || 0, 
      parseInt(low_stock_threshold) || 10, 
      image_url,
      businessId
    ];
    
    console.log('=== INSERT VALUES ===');
    console.log('name:', name);
    console.log('description:', description || null);
    console.log('sku:', sku);
    console.log('barcode:', barcode || null);
    console.log('category_id:', category_id || null);
    console.log('price:', parseFloat(price));
    console.log('wholesale_price:', wholesale_price !== undefined ? parseFloat(wholesale_price) : null);
    console.log('cost_price:', parseFloat(cost_price));
    console.log('stock_quantity:', parseInt(stock_quantity) || 0);
    console.log('low_stock_threshold:', parseInt(low_stock_threshold) || 10);
    console.log('image_url:', image_url);
    console.log('business_id:', businessId);
    console.log('All insert values:', insertValues);

    const [result] = await connection.query(
      `INSERT INTO products (
        name, description, sku, barcode, category_id, 
        price, wholesale_price, cost_price, stock_quantity, low_stock_threshold, image_url, business_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      insertValues
    );

    // Add inventory transaction for initial stock
    if (parseInt(stock_quantity) > 0) {
      console.log('=== INVENTORY TRANSACTION ===');
      console.log('Adding inventory transaction for product_id:', result.insertId, 'quantity:', parseInt(stock_quantity), 'business_id:', businessId);
      await connection.query(
        'INSERT INTO inventory_transactions (product_id, quantity, transaction_type, notes, business_id) VALUES (?, ?, ?, ?, ?)',
        [result.insertId, parseInt(stock_quantity), 'purchase', 'Initial stock', businessId]
      );
    }

    await connection.commit();
    console.log('=== PRODUCT CREATED SUCCESSFULLY ===');
    console.log('Product ID:', result.insertId);
    console.log('=====================================');

    res.status(201).json({
      message: 'Product created successfully',
      productId: result.insertId
    });
  } catch (error) {
    await connection.rollback();
    console.error('Create Product Error:', error);
    res.status(500).json({ message: error.message || 'Server error' });
  } finally {
    connection.release();
  }
});

// Update product
router.put('/:id', [auth, checkRole(['admin', 'manager']), upload.single('image')], async (req, res, next) => {
  try {
    console.log('=== PRODUCT UPDATE DEBUG ===');
    console.log('User info:', { id: req.user.id, role: req.user.role, business_id: req.user.business_id });
    console.log('Product ID to update:', req.params.id);
    console.log('Request body:', req.body);
    console.log('File info:', req.file ? { filename: req.file.filename, size: req.file.size } : 'No file');
    
    const {
      name,
      description,
      sku,
      barcode,
      category_id,
      price,
      wholesale_price,
      cost_price,
      stock_quantity,
      low_stock_threshold
    } = req.body;

    // First, check if product exists and belongs to user's business
    let checkQuery = 'SELECT * FROM products WHERE id = ?';
    let checkParams = [req.params.id];
    
    if (req.user.role !== 'superadmin') {
      if (!req.user.business_id) {
        return res.status(400).json({ message: 'Business ID is required for this operation.' });
      }
      checkQuery += ' AND business_id = ?';
      checkParams.push(req.user.business_id);
    }
    
    const [existingProducts] = await pool.query(checkQuery, checkParams);
    if (existingProducts.length === 0) {
      return res.status(404).json({ message: 'Product not found or access denied' });
    }
    
    console.log('Found existing product:', existingProducts[0]);

    const image_url = req.file ? `/uploads/products/${req.file.filename}` : undefined;

    const updateFields = [];
    const updateValues = [];

    if (name) {
      updateFields.push('name = ?');
      updateValues.push(name);
    }
    if (description !== undefined) {
      updateFields.push('description = ?');
      updateValues.push(description);
    }
    if (sku) {
      updateFields.push('sku = ?');
      updateValues.push(sku);
    }
    if (barcode) {
      updateFields.push('barcode = ?');
      updateValues.push(barcode);
    }
    if (category_id) {
      updateFields.push('category_id = ?');
      updateValues.push(category_id);
    }
    if (price !== undefined) {
      updateFields.push('price = ?');
      updateValues.push(parseFloat(price));
    }
    if (wholesale_price !== undefined) {
      updateFields.push('wholesale_price = ?');
      updateValues.push(wholesale_price === '' ? null : parseFloat(wholesale_price));
    }
    if (cost_price !== undefined) {
      updateFields.push('cost_price = ?');
      updateValues.push(parseFloat(cost_price));
    }
    if (stock_quantity !== undefined) {
      updateFields.push('stock_quantity = ?');
      updateValues.push(parseInt(stock_quantity));
    }
    if (low_stock_threshold !== undefined) {
      updateFields.push('low_stock_threshold = ?');
      updateValues.push(parseInt(low_stock_threshold));
    }
    if (image_url) {
      updateFields.push('image_url = ?');
      updateValues.push(image_url);
    }

    console.log('=== UPDATE FIELDS ===');
    console.log('Fields to update:', updateFields);
    console.log('Values to update:', updateValues);

    if (updateFields.length === 0) {
      return res.status(400).json({ message: 'No fields to update' });
    }

    updateValues.push(req.params.id);

    const updateQuery = `UPDATE products SET ${updateFields.join(', ')} WHERE id = ?`;
    console.log('Update query:', updateQuery);
    console.log('Update params:', updateValues);

    await pool.query(updateQuery, updateValues);

    // Fetch the updated product to verify the changes
    const [updatedProducts] = await pool.query(
      'SELECT * FROM products WHERE id = ?',
      [req.params.id]
    );
    
    console.log('=== PRODUCT UPDATED SUCCESSFULLY ===');
    console.log('Product ID:', req.params.id);
    console.log('Updated product data:', updatedProducts[0]);
    console.log('=====================================');

    res.json({ 
      message: 'Product updated successfully',
      product: updatedProducts[0]
    });
  } catch (error) {
    console.error('Product update error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Delete product
router.delete('/:id', [auth, checkRole(['admin'])], async (req, res) => {
  const connection = await pool.getConnection();
  try {
    console.log('=== PRODUCT DELETE DEBUG ===');
    console.log('User info:', { id: req.user.id, role: req.user.role, business_id: req.user.business_id });
    console.log('Product ID to delete:', req.params.id);
    
    await connection.beginTransaction();

    const productId = req.params.id;

    // Check if product exists and belongs to user's business
    let checkQuery = 'SELECT * FROM products WHERE id = ?';
    let checkParams = [productId];
    
    if (req.user.role !== 'superadmin') {
      if (!req.user.business_id) {
        await connection.rollback();
        return res.status(400).json({ message: 'Business ID is required for this operation.' });
      }
      checkQuery += ' AND business_id = ?';
      checkParams.push(req.user.business_id);
    }
    
    const [products] = await connection.query(checkQuery, checkParams);
    
    if (products.length === 0) {
      await connection.rollback();
      return res.status(404).json({ message: 'Product not found or access denied' });
    }
    
    console.log('Found product to delete:', products[0]);

    // Delete related records first (due to foreign key constraints)
    // Delete from sale_items
    await connection.query(
      'DELETE FROM sale_items WHERE product_id = ?',
      [productId]
    );

    // Delete from inventory_transactions
    await connection.query(
      'DELETE FROM inventory_transactions WHERE product_id = ?',
      [productId]
    );

    // Now soft delete the product
    const [result] = await connection.query(
      'UPDATE products SET is_deleted = 1 WHERE id = ?',
      [productId]
    );

    await connection.commit();
    
    console.log('=== PRODUCT DELETED SUCCESSFULLY ===');
    console.log('Product ID:', productId);
    console.log('=====================================');

    res.json({ message: 'Product deleted successfully' });
  } catch (error) {
    await connection.rollback();
    console.error('Delete Product Error:', error);
    res.status(500).json({ message: error.message || 'Server error' });
  } finally {
    connection.release();
  }
});

// Get low stock products
router.get('/inventory/low-stock', auth, async (req, res) => {
  try {
    const [products] = await pool.query(`
      SELECT 
        p.id,
        p.name,
        p.description,
        p.sku,
        p.barcode,
        p.category_id as categoryId,
        c.name as categoryName,
        p.price,
        p.wholesale_price as wholesalePrice,
        p.cost_price as costPrice,
        p.stock_quantity as stockQuantity,
        p.low_stock_threshold as lowStockThreshold,
        p.image_url as imageUrl,
        p.created_at as createdAt,
        p.updated_at as updatedAt
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.stock_quantity <= p.low_stock_threshold AND p.is_deleted = 0
      ORDER BY p.stock_quantity ASC
    `);
    res.json(products);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router; 