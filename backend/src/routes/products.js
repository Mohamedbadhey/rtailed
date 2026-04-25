const express = require('express');
const router = express.Router();
const ExcelJS = require('exceljs');

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
    
    // Ensure directory exists
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    // Sanitize filename to prevent issues
    const sanitizedName = file.originalname.replace(/[^a-zA-Z0-9.-]/g, '_');
    const finalFilename = `${Date.now()}-${sanitizedName}`;
    cb(null, finalFilename);
  }
});

const allowedExtensions = ['.png', '.jpg', '.jpeg'];

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
  fileFilter: (req, file, cb) => {
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

// Get all active products (for POS, sales, etc.)
router.get('/', auth, async (req, res) => {
  try {
    let query = `
      SELECT p.*, 
             CASE 
               WHEN p.category_id IS NULL THEN 'Uncategorized'
               ELSE c.name 
             END as category_name 
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id 
      WHERE p.business_id = ? AND p.is_deleted = 0
      ORDER BY p.name
    `;
    let params = [req.user.business_id];
    if (req.user.role === 'superadmin') {
      query = `
        SELECT p.*, 
               CASE 
                 WHEN p.category_id IS NULL THEN 'Uncategorized'
               ELSE c.name 
             END as category_name 
        FROM products p 
        LEFT JOIN categories c ON p.category_id = c.id 
        WHERE p.is_deleted = 0
        ORDER BY p.name
      `;
      params = [];
    }
    
    const [products] = await pool.query(query, params);
    res.json(products);
  } catch (error) {
    console.error('🛍️ Error in products GET:', error);
    res.status(500).json({ message: 'Server error', details: error.message });
  }
});

// Get all products including deleted ones (for inventory management)
router.get('/all', auth, async (req, res) => {
  try {
    let query = `
      SELECT p.*, 
             CASE 
               WHEN p.category_id IS NULL THEN 'Uncategorized'
               ELSE c.name 
             END as category_name 
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id 
      WHERE p.business_id = ?
      ORDER BY p.name
    `;
    let params = [req.user.business_id];
    if (req.user.role === 'superadmin') {
      query = `
        SELECT p.*, 
               CASE 
                 WHEN p.category_id IS NULL THEN 'Uncategorized'
               ELSE c.name 
             END as category_name 
        FROM products p 
        LEFT JOIN categories c ON p.category_id = c.id 
        ORDER BY p.name
      `;
      params = [];
    }
    const [products] = await pool.query(query, params);
    res.json(products);
  } catch (error) {
    console.error('🛍️ Error in all products GET:', error);
    res.status(500).json({ message: 'Server error', details: error.message });
  }
});

// Get single product
router.get('/:id(\\d+)', auth, async (req, res) => {
  try {
    let query = `
      SELECT p.*, 
             CASE 
               WHEN p.category_id IS NULL THEN 'Uncategorized'
               ELSE c.name 
             END as category_name 
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id 
      WHERE p.id = ? AND (p.business_id = ? OR p.business_id IS NULL)
    `;
    let params = [req.params.id, req.user.business_id];
    if (req.user.role === 'superadmin') {
      query = `
        SELECT p.*, 
               CASE 
                 WHEN p.category_id IS NULL THEN 'Uncategorized'
               ELSE c.name 
             END as category_name 
        FROM products p 
        LEFT JOIN categories c ON p.category_id = c.id 
        WHERE p.id = ?
      `;
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

// Check product name availability
router.post('/check-name', auth, async (req, res) => {
  try {
    const { name, exclude_id } = req.body;
    
    if (!name) {
      return res.status(400).json({ 
        message: 'Product name is required' 
      });
    }

    let query = 'SELECT id FROM products WHERE name = ? AND is_deleted = 0';
    let params = [name];
    
    // Exclude specific product ID if provided (for editing)
    if (exclude_id) {
      query += ' AND id != ?';
      params.push(exclude_id);
    }
    
    // Filter by business_id for non-superadmin users
    if (req.user.role !== 'superadmin') {
      if (!req.user.business_id) {
        return res.status(400).json({ 
          message: 'Business ID is required for this operation' 
        });
      }
      query += ' AND (business_id = ? OR business_id IS NULL)';
      params.push(req.user.business_id);
    }
    
    const [products] = await pool.query(query, params);
    const isAvailable = products.length === 0;
    
    res.json({ 
      available: isAvailable,
      message: isAvailable ? 'Product name is available' : 'Product name already exists'
    });
    
  } catch (error) {
    console.error('Error checking product name:', error);
    res.status(500).json({ 
      message: 'Error checking product name availability' 
    });
  }
});

// Create product
router.post('/', [auth, checkRole(['admin', 'manager']), upload.single('image')], async (req, res, next) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const {
      name,
      description,
      barcode,
      category_id,
      price,
      wholesale_price,
      cost_price,
      stock_quantity,
      low_stock_threshold,
      sku
    } = req.body;

    // Validate required fields
    if (!name || !cost_price || !price) {
      await connection.rollback();
      return res.status(400).json({ 
        message: 'Missing required fields: name, price, and cost_price are required' 
      });
    }

    // Validate numeric fields
    if (isNaN(parseFloat(price))) {
      await connection.rollback();
      return res.status(400).json({ 
        message: 'Price must be a valid number' 
      });
    }
    if (isNaN(parseFloat(cost_price))) {
      await connection.rollback();
      return res.status(400).json({ 
        message: 'Cost_price must be a valid number' 
      });
    }



    const image_url = req.file ? `/uploads/products/${req.file.filename}` : null;
    
    // Determine business_id based on the creation context:
    // - If storeId is provided: This is store management (global products, business_id = NULL)
    // - If storeId is NOT provided: This is inventory screen (business-specific products, business_id = req.user.business_id)
    const { storeId } = req.body;
    const businessId = storeId ? null : req.user.business_id;
    
    console.log('=== BUSINESS ID LOGIC ===');
    console.log('storeId provided:', !!storeId);
    console.log('storeId value:', storeId);
    console.log('user business_id:', req.user.business_id);
    console.log('final businessId:', businessId);
    console.log('context:', storeId ? 'Store Management (Global Product)' : 'Inventory Screen (Business-Specific Product)');
    console.log('========================');
    
    const finalSku = (sku && sku.trim() !== '') ? sku.trim() : `SKU-${Date.now()}`;
    
    const insertValues = [
      name, 
      description || null, 
      finalSku, // Use provided SKU or auto-generate
      barcode || null, 
      category_id || null,
      parseFloat(price), // Use price from request body instead of hardcoded 0.0
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
    console.log('sku received in body:', sku);
    console.log('sku being used for insertion:', finalSku);
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

    const productId = result.insertId;
    console.log('Product created with ID:', productId);

    // If storeId is provided, immediately add product to store inventory
    if (storeId && parseInt(stock_quantity) > 0) {
      console.log('Adding product to store inventory - Store ID:', storeId, 'Product ID:', productId, 'Quantity:', stock_quantity);
      
      // Check if user has access to this store
      if (req.user.role !== 'superadmin') {
        const [accessCheck] = await connection.query(
          `SELECT 1 FROM store_business_assignments sba 
           WHERE sba.store_id = ? AND sba.business_id = ? AND sba.is_active = 1`,
          [storeId, req.user.business_id]
        );
        
        if (accessCheck.length === 0) {
          throw new Error('Access denied: No permission for this store');
        }
      }

      // Check if inventory record already exists for this store and business
      const [existing] = await connection.query(
        'SELECT id, quantity FROM store_product_inventory WHERE store_id = ? AND product_id = ? AND business_id = ?',
        [storeId, productId, req.user.business_id]
      );
      
      if (existing.length > 0) {
        // Update existing inventory (increment)
        const currentQuantity = existing[0].quantity;
        const newQuantity = currentQuantity + parseInt(stock_quantity);
        
        await connection.query(
          `UPDATE store_product_inventory 
           SET quantity = ?, updated_by = ?
           WHERE store_id = ? AND product_id = ? AND business_id = ?`,
          [newQuantity, req.user.id, storeId, productId, req.user.business_id]
        );
        
        // Record the increment movement
        await connection.query(
          `INSERT INTO store_inventory_movements 
           (store_id, business_id, product_id, movement_type, quantity, previous_quantity, new_quantity, reference_type, notes, created_by)
           VALUES (?, ?, ?, 'in', ?, ?, ?, 'purchase', ?, ?)`,
          [storeId, req.user.business_id, productId, parseInt(stock_quantity), currentQuantity, newQuantity, 'Product created and added to store', req.user.id]
        );
        
        console.log('Updated existing store inventory - previous:', currentQuantity, 'added:', stock_quantity, 'new:', newQuantity);
      } else {
        // Create new inventory record
        await connection.query(
          `INSERT INTO store_product_inventory 
           (store_id, business_id, product_id, quantity, min_stock_level, updated_by)
           VALUES (?, ?, ?, ?, 10, ?)`,
          [storeId, req.user.business_id, productId, parseInt(stock_quantity), req.user.id]
        );
        
        // Record the initial movement
        await connection.query(
          `INSERT INTO store_inventory_movements 
           (store_id, business_id, product_id, movement_type, quantity, previous_quantity, new_quantity, reference_type, notes, created_by)
           VALUES (?, ?, ?, 'in', ?, 0, ?, 'purchase', ?, ?)`,
          [storeId, req.user.business_id, productId, parseInt(stock_quantity), parseInt(stock_quantity), 'Initial product addition to store', req.user.id]
        );
        
        console.log('Created new store inventory record - quantity:', stock_quantity);
      }
    }

    // Note: Product creation logic:
    // - Inventory Screen: Products are business-specific (business_id = user.business_id)
    // - Store Management: Products are global (business_id = NULL) and added to store inventory
    // This follows the two-tier inventory system: Store Warehouse → Business Inventory

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
      barcode,
      category_id,
      price,
      wholesale_price,
      cost_price,
      stock_quantity,
      low_stock_threshold,
      sku
    } = req.body;

    // First, check if product exists and belongs to user's business or is global
    let checkQuery = 'SELECT * FROM products WHERE id = ?';
    let checkParams = [req.params.id];
    
    if (req.user.role !== 'superadmin') {
      if (!req.user.business_id) {
        return res.status(400).json({ message: 'Business ID is required for this operation.' });
      }
      checkQuery += ' AND (business_id = ? OR business_id IS NULL)';
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

    if (barcode) {
      updateFields.push('barcode = ?');
      updateValues.push(barcode);
    }
    if (sku !== undefined) {
      const finalSku = sku.trim() !== '' ? sku.trim() : `SKU-${Date.now()}`;
      updateFields.push('sku = ?');
      updateValues.push(finalSku);
      console.log('Final SKU being used for update:', finalSku);
    }
    if (category_id !== undefined) {
      updateFields.push('category_id = ?');
      updateValues.push(category_id === '' ? null : category_id);
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

    console.log('sku received in body:', sku);
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
      checkQuery += ' AND (business_id = ? OR business_id IS NULL)';
      checkParams.push(req.user.business_id);
    }
    
    const [products] = await connection.query(checkQuery, checkParams);
    
    if (products.length === 0) {
      await connection.rollback();
      return res.status(404).json({ message: 'Product not found or access denied' });
    }
    
    console.log('Found product to delete:', products[0]);

    // Simple soft delete - just mark as deleted, preserve all data
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

// Restore product
router.put('/:id/restore', [auth, checkRole(['admin'])], async (req, res) => {
  const connection = await pool.getConnection();
  try {
    console.log('=== PRODUCT RESTORE DEBUG ===');
    console.log('User info:', { id: req.user.id, role: req.user.role, business_id: req.user.business_id });
    console.log('Product ID to restore:', req.params.id);
    
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
      checkQuery += ' AND (business_id = ? OR business_id IS NULL)';
      checkParams.push(req.user.business_id);
    }
    
    const [products] = await connection.query(checkQuery, checkParams);
    
    if (products.length === 0) {
      await connection.rollback();
      return res.status(404).json({ message: 'Product not found or access denied' });
    }
    

    // Simple restore - just mark as not deleted
    const [result] = await connection.query(
      'UPDATE products SET is_deleted = 0 WHERE id = ?',
      [productId]
    );

    await connection.commit();
    
    console.log('Product ID:', productId);
    console.log('=====================================');

    res.json({ message: 'Product restored successfully' });
  } catch (error) {
    await connection.rollback();
    console.error('Restore Product Error:', error);
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

// ===================== BULK IMPORT FROM EXCEL (embedded images) =====================
const excelMemoryStorage = multer.memoryStorage();
const excelUpload = multer({
  storage: excelMemoryStorage,
  limits: { fileSize: 25 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (ext === '.xlsx') return cb(null, true); // Only .xlsx supported for embedded images parsing (Open XML) // .xls not supported here
    return cb(new Error('Only .xlsx files are supported for bulk import'));
    return cb(new Error('Only .xlsx or .xls files are supported for bulk import'));
  }
});

const { extractEmbeddedImagesByRow, normalizeHeader } = require('../utils/excel_import');

// Helper: save image buffer to uploads/products and return relative URL
async function saveImageBuffer(buffer, ext) {
  const baseDir = process.env.RAILWAY_VOLUME_MOUNT_PATH || path.join(__dirname, '../../uploads');
  const productsDir = path.join(baseDir, 'products');
  if (!fs.existsSync(productsDir)) fs.mkdirSync(productsDir, { recursive: true });
  const safeExt = ['.png', '.jpg', '.jpeg', '.webp'].includes((ext || '').toLowerCase()) ? ext.toLowerCase() : '.png';
  const filename = `${Date.now()}-${Math.random().toString(36).slice(2,8)}${safeExt}`;
  const fullPath = path.join(productsDir, filename);
  await fs.promises.writeFile(fullPath, buffer);
  return `/uploads/products/${filename}`;
}

// POST /api/products/bulk-import
router.post('/bulk-import', [auth, checkRole(['admin', 'manager']), excelUpload.single('file')], async (req, res) => {
  try {
    if (!req.file || !req.file.buffer) {
      return res.status(400).json({ message: 'Excel file is required' });
    }

    const options = (() => {
      try { return req.body.options ? JSON.parse(req.body.options) : {}; } catch { return {}; }
    })();
    const dryRun = options.dryRun !== false; // default true
    const upsertBy = options.upsertBy || 'sku'; // 'sku' | 'barcode' | 'none'
    const createMissingCategories = options.category_create !== false; // default true

    // Parse Excel + embedded images
    const { headers, rows, imagesByRow, warnings } = await extractEmbeddedImagesByRow(req.file.buffer, { imageColumn: 'image' });

    // Required columns validation
    const requiredCols = ['name', 'price', 'cost'];
    const missing = requiredCols.filter(rc => !headers.includes(rc));
    if (missing.length) {
      console.log(`❌ Bulk Import: Missing required columns: ${missing.join(', ')}`);
      return res.status(400).json({ message: `Missing required columns: ${missing.join(', ')}` });
    }

    console.log(`🚀 Bulk Import started: dryRun=${dryRun}, upsertBy=${upsertBy}, rows=${rows.length}`);

    // Category pre-fetch cache
    const categoryCache = new Map(); // name -> id

    const results = [];
    let created = 0, updated = 0, failed = 0;

    for (let i = 0; i < rows.length; i++) {
      const r = rows[i];
      const rowNum = i + 2; // Excel visible row number
      const name = (r.name || '').trim();
      const sku = (r.sku || '').trim() || null;
      const description = (r.description || '').trim() || null;
      const cost = parseFloat(String(r.cost || '').replace(/,/g, ''));
      const price = parseFloat(String(r.price || '').replace(/,/g, ''));
      const quantity = parseInt(String(r.quantity || '0').replace(/,/g, '')) || 0;
      const categoryName = r.category && String(r.category).trim() !== '' ? String(r.category).trim() : null;

      const rowMsgs = [];
      if (!name) rowMsgs.push('name is required');
      if (!Number.isFinite(cost)) rowMsgs.push('cost must be a number');
      if (!Number.isFinite(price)) rowMsgs.push('price must be a number');
      if (rowMsgs.length) {
        failed++;
        results.push({ row: rowNum, status: 'error', messages: rowMsgs });
        continue;
      }

      // Resolve category id (optional)
      let categoryId = null;
      if (categoryName) {
        const normalizedCat = categoryName.trim();
        if (categoryCache.has(normalizedCat)) {
          categoryId = categoryCache.get(normalizedCat);
        } else {
          // Case-insensitive search for existing category (business-specific or global)
          const [existing] = await pool.query(
            'SELECT id FROM categories WHERE LOWER(name) = LOWER(?) AND (business_id = ? OR business_id IS NULL) LIMIT 1', 
            [normalizedCat, req.user.business_id]
          );
          
          if (existing.length) {
            categoryId = existing[0].id;
          } else if (createMissingCategories) {
            const [ins] = await pool.query(
              'INSERT INTO categories (name, business_id) VALUES (?, ?)', 
              [normalizedCat, req.user.business_id]
            );
            categoryId = ins.insertId;
          }
          categoryCache.set(normalizedCat, categoryId);
        }
      }

      // Image handling from embedded image map
      let image_url = null;
      if (imagesByRow.has(i)) {
        const { buffer, ext } = imagesByRow.get(i);
        try {
          image_url = await saveImageBuffer(buffer, ext);
        } catch (e) {
          rowMsgs.push(`image save failed: ${e.message}`);
        }
      }

      if (dryRun) {
        results.push({ row: rowNum, status: 'ok', action: upsertBy === 'none' ? 'create' : (sku ? 'upsert' : 'create'), name, sku, price, cost, quantity, categoryId, image: !!image_url, warnings: rowMsgs });
        continue;
      }

      // Upsert logic
      let productId = null;
      if (upsertBy === 'sku' && sku) {
        const [p] = await pool.query('SELECT id FROM products WHERE sku = ? AND business_id = ?', [sku, req.user.business_id]);
        if (p.length) productId = p[0].id;
      }
      if (!productId && upsertBy === 'barcode' && r.barcode) {
        const [p] = await pool.query('SELECT id FROM products WHERE barcode = ? AND business_id = ?', [String(r.barcode).trim(), req.user.business_id]);
        if (p.length) productId = p[0].id;
      }

      try {
        if (productId) {
          // Update existing
          const fields = ['name = ?', 'description = ?', 'price = ?', 'cost_price = ?', 'stock_quantity = ?', 'low_stock_threshold = ?'];
          const vals = [name, description, price, cost, quantity, 10];
          if (categoryId !== null) { fields.push('category_id = ?'); vals.push(categoryId); }
          if (image_url) { fields.push('image_url = ?'); vals.push(image_url); }
          if (sku) { fields.push('sku = ?'); vals.push(sku); }
          if (r.barcode) { fields.push('barcode = ?'); vals.push(String(r.barcode).trim()); }
          vals.push(productId);
          await pool.query(`UPDATE products SET ${fields.join(', ')} WHERE id = ?`, vals);
          updated++;
          results.push({ row: rowNum, status: 'updated', id: productId, name });
        } else {
          // Create new
          const finalSku = sku && sku.trim() !== '' ? sku.trim() : `SKU-${Date.now()}-${Math.random().toString(36).slice(2,6)}`;
          const insertValues = [
            name, description, finalSku, r.barcode ? String(r.barcode).trim() : null, categoryId,
            price, r.wholesale_price ? parseFloat(String(r.wholesale_price).replace(/,/g, '')) : null, cost,
            quantity, 10, image_url, req.user.business_id
          ];
          const [ins] = await pool.query(
            `INSERT INTO products (
              name, description, sku, barcode, category_id,
              price, wholesale_price, cost_price, stock_quantity, low_stock_threshold, image_url, business_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            insertValues
          );
          created++;
          results.push({ row: rowNum, status: 'created', id: ins.insertId, name });
        }
      } catch (e) {
        failed++;
        results.push({ row: rowNum, status: 'error', messages: [e.message] });
      }
    }

    const summary = { totals: { rows: rows.length, created, updated, failed }, warnings };
    res.status(200).json({ summary, results, dryRun });
  } catch (error) {
    console.error('Bulk import error:', error);
    res.status(500).json({ message: error.message || 'Server error during bulk import' });
  }
});

// GET /api/products/paged - active products with pagination and filters
router.get('/paged', auth, async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page || '1', 10), 1);
    const limitRaw = Math.max(parseInt(req.query.limit || '50', 10), 1);
    const limit = Math.min(limitRaw, 100);
    const offset = (page - 1) * limit;
    const search = (req.query.search || '').trim();
    const categoryId = req.query.category_id ? parseInt(req.query.category_id, 10) : null;
    const lowStock = String(req.query.low_stock || 'false') === 'true';

    let where = 'p.is_deleted = 0';
    const params = [];

    if (req.user.role !== 'superadmin') {
      if (!req.user.business_id) {
        return res.status(400).json({ message: 'Business ID is required' });
      }
      where += ' AND p.business_id = ?';
      params.push(req.user.business_id);
    }

    if (search) {
      where += ' AND (p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ?)';
      const like = `%${search}%`;
      params.push(like, like, like);
    }

    if (categoryId) {
      where += ' AND p.category_id = ?';
      params.push(categoryId);
    }

    if (lowStock) {
      where += ' AND p.stock_quantity <= p.low_stock_threshold';
    }

    const countQuery = `
      SELECT COUNT(*) as total
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE ${where}
    `;

    const dataQuery = `
      SELECT p.*, CASE WHEN p.category_id IS NULL THEN 'Uncategorized' ELSE c.name END AS category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE ${where}
      ORDER BY p.name
      LIMIT ? OFFSET ?
    `;

    const [countRows] = await pool.query(countQuery, params);
    const total = countRows[0]?.total || 0;

    const [items] = await pool.query(dataQuery, [...params, limit, offset]);

    res.json({ items, page, limit, total });
  } catch (err) {
    console.error('Pagination error (/products/paged):', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// GET /api/products/all/paged - include deleted filter + pagination
router.get('/all/paged', auth, async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page || '1', 10), 1);
    const limitRaw = Math.max(parseInt(req.query.limit || '50', 10), 1);
    const limit = Math.min(limitRaw, 100);
    const offset = (page - 1) * limit;
    const search = (req.query.search || '').trim();
    const categoryId = req.query.category_id ? parseInt(req.query.category_id, 10) : null;
    const lowStock = String(req.query.low_stock || 'false') === 'true';
    const deletedParam = (req.query.deleted || '').toString().toLowerCase(); // '0' | '1' | 'all'

    let where = '1=1';
    const params = [];

    if (req.user.role !== 'superadmin') {
      if (!req.user.business_id) {
        return res.status(400).json({ message: 'Business ID is required' });
      }
      where += ' AND p.business_id = ?';
      params.push(req.user.business_id);
    }

    if (deletedParam === '0') {
      where += ' AND p.is_deleted = 0';
    } else if (deletedParam === '1') {
      where += ' AND p.is_deleted = 1';
    } // else 'all' -> no filter

    if (search) {
      where += ' AND (p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ?)';
      const like = `%${search}%`;
      params.push(like, like, like);
    }

    if (categoryId) {
      where += ' AND p.category_id = ?';
      params.push(categoryId);
    }

    if (lowStock) {
      where += ' AND p.stock_quantity <= p.low_stock_threshold';
    }

    const countQuery = `
      SELECT COUNT(*) as total
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE ${where}
    `;

    const dataQuery = `
      SELECT p.*, CASE WHEN p.category_id IS NULL THEN 'Uncategorized' ELSE c.name END AS category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE ${where}
      ORDER BY p.name
      LIMIT ? OFFSET ?
    `;

    const [countRows] = await pool.query(countQuery, params);
    const total = countRows[0]?.total || 0;

    const [items] = await pool.query(dataQuery, [...params, limit, offset]);

    res.json({ items, page, limit, total });
  } catch (err) {
    console.error('Pagination error (/products/all/paged):', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// GET /api/products/bulk-export
router.get('/bulk-export', auth, async (req, res) => {
  try {
    let query = `
      SELECT p.*, 
             CASE 
               WHEN p.category_id IS NULL THEN 'Uncategorized'
               ELSE c.name 
             END as category_name 
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id 
      WHERE p.business_id = ? AND p.is_deleted = 0
      ORDER BY p.name
    `;
    let params = [req.user.business_id];
    
    if (req.user.role === 'superadmin') {
      query = `
        SELECT p.*, 
               CASE 
                 WHEN p.category_id IS NULL THEN 'Uncategorized'
               ELSE c.name 
             END as category_name 
        FROM products p 
        LEFT JOIN categories c ON p.category_id = c.id 
        WHERE p.is_deleted = 0
        ORDER BY p.name
      `;
      params = [];
    }

    const [products] = await pool.query(query, params);

    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet('Products');

    worksheet.columns = [
      { header: 'Name', key: 'name', width: 30 },
      { header: 'SKU', key: 'sku', width: 20 },
      { header: 'Description', key: 'description', width: 40 },
      { header: 'Barcode', key: 'barcode', width: 20 },
      { header: 'Category', key: 'category_name', width: 20 },
      { header: 'Price', key: 'price', width: 15 },
      { header: 'Wholesale Price', key: 'wholesale_price', width: 15 },
      { header: 'Cost Price', key: 'cost_price', width: 15 },
      { header: 'Quantity', key: 'stock_quantity', width: 15 },
      { header: 'Low Stock Threshold', key: 'low_stock_threshold', width: 15 },
      { header: 'Image', key: 'image', width: 20 },
    ];

    // Style the header
    worksheet.getRow(1).font = { bold: true };
    worksheet.getRow(1).alignment = { vertical: 'middle', horizontal: 'center' };

    const baseDir = process.env.RAILWAY_VOLUME_MOUNT_PATH || path.join(__dirname, '../../uploads');

    for (let i = 0; i < products.length; i++) {
      const p = products[i];
      const row = worksheet.addRow({
        name: p.name,
        sku: p.sku,
        description: p.description,
        barcode: p.barcode,
        category_name: p.category_name,
        price: p.price,
        wholesale_price: p.wholesale_price,
        cost_price: p.cost_price,
        stock_quantity: p.stock_quantity,
        low_stock_threshold: p.low_stock_threshold,
      });

      // Adjust row height for image
      row.height = 80;
      row.alignment = { vertical: 'middle', horizontal: 'left' };

      if (p.image_url) {
        try {
          let imagePath;
          if (p.image_url.startsWith('/uploads/')) {
             imagePath = path.join(baseDir, p.image_url.replace('/uploads/', ''));
          } else {
             const relativePath = p.image_url.startsWith('/') ? p.image_url.substring(1) : p.image_url;
             imagePath = path.join(baseDir, relativePath);
          }

          if (fs.existsSync(imagePath)) {
            const imageId = workbook.addImage({
              filename: imagePath,
              extension: path.extname(imagePath).substring(1).toLowerCase() || 'png',
            });

            worksheet.addImage(imageId, {
              tl: { col: 10, row: i + 1 },
              ext: { width: 100, height: 100 },
              editAs: 'oneCell'
            });
          }
        } catch (err) {
          console.error(`Error adding image for product ${p.id}:`, err);
        }
      }
    }

    res.setHeader(
      'Content-Type',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    );
    res.setHeader(
      'Content-Disposition',
      'attachment; filename=' + 'products_export.xlsx'
    );

    await workbook.xlsx.write(res);
    res.end();

  } catch (error) {
    console.error('Export error:', error);
    res.status(500).json({ message: 'Server error during export' });
  }
});


module.exports = router; 
