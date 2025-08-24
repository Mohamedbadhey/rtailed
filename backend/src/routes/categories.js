const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { auth, checkRole } = require('../middleware/auth');

// Get all categories
router.get('/', auth, async (req, res) => {
  try {
    let query = 'SELECT * FROM categories WHERE business_id = ? ORDER BY name';
    let params = [req.user.business_id];
    if (req.user.role === 'superadmin') {
      query = 'SELECT * FROM categories ORDER BY name';
      params = [];
    }
    const [categories] = await pool.query(query, params);
    res.json(categories);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get single category
router.get('/:id', auth, async (req, res) => {
  try {
    let query = 'SELECT * FROM categories WHERE id = ? AND business_id = ?';
    let params = [req.params.id, req.user.business_id];
    if (req.user.role === 'superadmin') {
      query = 'SELECT * FROM categories WHERE id = ?';
      params = [req.params.id];
    }
    const [categories] = await pool.query(query, params);
    if (categories.length === 0) {
      return res.status(404).json({ message: 'Category not found' });
    }
    res.json(categories[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Create category
router.post('/', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  try {
    const { name, description } = req.body;

    if (!name) {
      return res.status(400).json({ message: 'Category name is required' });
    }

    const [result] = await pool.query(
      'INSERT INTO categories (name, description, business_id) VALUES (?, ?, ?)',
      [name, description || null, req.user.business_id]
    );

    res.status(201).json({
      message: 'Category created successfully',
      categoryId: result.insertId
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Update category
router.put('/:id', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  try {
    const { name, description } = req.body;

    if (!name) {
      return res.status(400).json({ message: 'Category name is required' });
    }

    // Check if category belongs to user's business (unless superadmin)
    if (req.user.role !== 'superadmin') {
      const [existingCategory] = await pool.query(
        'SELECT id FROM categories WHERE id = ? AND business_id = ?',
        [req.params.id, req.user.business_id]
      );
      
      if (existingCategory.length === 0) {
        return res.status(404).json({ message: 'Category not found' });
      }
    }

    const [result] = await pool.query(
      'UPDATE categories SET name = ?, description = ? WHERE id = ?',
      [name, description || null, req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'Category not found' });
    }

    res.json({ message: 'Category updated successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Delete category
router.delete('/:id', [auth, checkRole(['admin'])], async (req, res) => {
  try {
    // Check if category belongs to user's business (unless superadmin)
    if (req.user.role !== 'superadmin') {
      const [existingCategory] = await pool.query(
        'SELECT id FROM categories WHERE id = ? AND business_id = ?',
        [req.params.id, req.user.business_id]
      );
      
      if (existingCategory.length === 0) {
        return res.status(404).json({ message: 'Category not found' });
      }
    }

    // Check if category is being used by any products
    const [products] = await pool.query(
      'SELECT COUNT(*) as count FROM products WHERE category_id = ?',
      [req.params.id]
    );

    if (products[0].count > 0) {
      return res.status(400).json({ 
        message: 'Cannot delete category that has associated products' 
      });
    }

    const [result] = await pool.query(
      'DELETE FROM categories WHERE id = ?',
      [req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'Category not found' });
    }

    res.json({ message: 'Category deleted successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router; 