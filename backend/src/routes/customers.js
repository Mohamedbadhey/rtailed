const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { auth, checkRole } = require('../middleware/auth');

// Get all customers
router.get('/', auth, async (req, res) => {
  try {
    let query = 'SELECT * FROM customers WHERE business_id = ? ORDER BY name';
    let params = [req.user.business_id];
    if (req.user.role === 'superadmin') {
      query = 'SELECT * FROM customers ORDER BY name';
      params = [];
    }
    const [customers] = await pool.query(query, params);
    res.json(customers);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get single customer
router.get('/:id', auth, async (req, res) => {
  try {
    let query = 'SELECT * FROM customers WHERE id = ? AND business_id = ?';
    let params = [req.params.id, req.user.business_id];
    if (req.user.role === 'superadmin') {
      query = 'SELECT * FROM customers WHERE id = ?';
      params = [req.params.id];
    }
    const [customers] = await pool.query(query, params);
    if (customers.length === 0) {
      return res.status(404).json({ message: 'Customer not found' });
    }
    res.json(customers[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Create new customer
router.post('/', auth, async (req, res) => {
  try {
    const { name, email, phone, address } = req.body;
    const businessId = req.user.business_id;

    const [result] = await pool.query(
      'INSERT INTO customers (name, email, phone, address, business_id) VALUES (?, ?, ?, ?, ?)',
      [name, email, phone, address, businessId]
    );

    // Get the created customer
    const [customers] = await pool.query(
      'SELECT * FROM customers WHERE id = ?',
      [result.insertId]
    );

    res.status(201).json(customers[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Update customer
router.put('/:id', auth, async (req, res) => {
  try {
    const { name, email, phone, address } = req.body;

    const [result] = await pool.query(
      `UPDATE customers 
       SET name = ?, email = ?, phone = ?, address = ?
       WHERE id = ?`,
      [name, email, phone, address, req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'Customer not found' });
    }

    res.json({ message: 'Customer updated successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Delete customer
router.delete('/:id', [auth, checkRole(['admin'])], async (req, res) => {
  try {
    const [result] = await pool.query(
      'DELETE FROM customers WHERE id = ?',
      [req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'Customer not found' });
    }

    res.json({ message: 'Customer deleted successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get customer loyalty points
router.get('/:id/loyalty', auth, async (req, res) => {
  try {
    const [customers] = await pool.query(
      'SELECT loyalty_points FROM customers WHERE id = ?',
      [req.params.id]
    );

    if (customers.length === 0) {
      return res.status(404).json({ message: 'Customer not found' });
    }

    res.json({ loyalty_points: customers[0].loyalty_points });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Update customer loyalty points
router.put('/:id/loyalty', [auth, checkRole(['admin', 'manager'])], async (req, res) => {
  try {
    const { points, operation = 'add' } = req.body;

    let query;
    if (operation === 'add') {
      query = 'UPDATE customers SET loyalty_points = loyalty_points + ? WHERE id = ?';
    } else if (operation === 'subtract') {
      query = 'UPDATE customers SET loyalty_points = loyalty_points - ? WHERE id = ?';
    } else {
      return res.status(400).json({ message: 'Invalid operation' });
    }

    const [result] = await pool.query(query, [points, req.params.id]);

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'Customer not found' });
    }

    res.json({ message: 'Loyalty points updated successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Search customers
router.get('/search/:query', auth, async (req, res) => {
  try {
    const searchQuery = `%${req.params.query}%`;
    const [customers] = await pool.query(
      `SELECT * FROM customers 
       WHERE name LIKE ? OR email LIKE ? OR phone LIKE ?
       ORDER BY name
       LIMIT 10`,
      [searchQuery, searchQuery, searchQuery]
    );

    res.json(customers);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router; 