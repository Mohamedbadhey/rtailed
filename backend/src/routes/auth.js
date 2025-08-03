const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/database');
const { auth } = require('../middleware/auth');

// Register new user
router.post('/register', async (req, res) => {
  try {
    const { username, email, password, role, adminCode, businessId } = req.body;

    // Validate superadmin registration
    if (role === 'superadmin') {
      const requiredAdminCode = process.env.ADMIN_CODE || 'SUPERADMIN2024';
      if (!adminCode || adminCode !== requiredAdminCode) {
        return res.status(403).json({ 
          message: 'Invalid admin code for superadmin registration' 
        });
      }
    } else {
      // Validate business assignment for non-superadmin users
      if (!businessId) {
        return res.status(400).json({ 
          message: 'Business ID is required for non-superadmin users' 
        });
      }
      
      // Check if business exists and is active
      const [businesses] = await pool.query(
        'SELECT id FROM businesses WHERE id = ? AND is_active = TRUE',
        [businessId]
      );
      
      if (businesses.length === 0) {
        return res.status(400).json({ 
          message: 'Invalid or inactive business' 
        });
      }
    }

    // Check if user already exists
    const [existingUsers] = await pool.query(
      'SELECT * FROM users WHERE email = ? OR username = ?',
      [email, username]
    );

    if (existingUsers.length > 0) {
      return res.status(400).json({ message: 'User already exists' });
    }

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    // Insert new user
    const [result] = await pool.query(
      'INSERT INTO users (username, email, password, role, business_id) VALUES (?, ?, ?, ?, ?)',
      [username, email, hashedPassword, role, businessId]
    );

    // Generate JWT
    const token = jwt.sign(
      { id: result.insertId, username, role, business_id: businessId },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.status(201).json({
      message: 'User registered successfully',
      token,
      user: { id: result.insertId, username, email, role, business_id: businessId, language: 'English' }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Login user
router.post('/login', async (req, res) => {
  try {
    const { username, email, password, identifier } = req.body;

    // Support both old format (username/email) and new format (identifier)
    let userIdentifier = identifier;
    
    if (!userIdentifier) {
      // Backward compatibility: check for username or email fields
    if (username && email) {
        return res.status(400).json({ message: 'Please provide either username OR email, not both' });
    } else if (username) {
        userIdentifier = username;
    } else if (email) {
        userIdentifier = email;
    } else {
        return res.status(400).json({ message: 'Username, email, or identifier is required' });
      }
    }

    // Check if user exists by username or email using the identifier
    const query = 'SELECT * FROM users WHERE (username = ? OR email = ?) AND is_deleted = 0';
    const params = [userIdentifier, userIdentifier];

    const [users] = await pool.query(query, params);

    if (users.length === 0) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    const user = users[0];

    // Check if user is active
    if (!user.is_active) {
      return res.status(400).json({ message: 'Account is deactivated. Please contact your administrator.' });
    }

    // Check business status for non-superadmin users
    if (user.business_id && user.role !== 'superadmin') {
      const [businesses] = await pool.query(
        'SELECT is_active, payment_status, suspension_reason FROM businesses WHERE id = ?',
        [user.business_id]
      );
      
      if (businesses.length === 0) {
        return res.status(400).json({ message: 'Business not found' });
      }
      
      const business = businesses[0];
      
      if (!business.is_active) {
        return res.status(400).json({ 
          message: 'Business account is deactivated. Please contact your administrator.' 
        });
      }
      
      if (business.payment_status !== 'current') {
        let errorMessage = 'Business account is suspended due to payment issues.';
        if (business.payment_status === 'overdue') {
          errorMessage = 'Business account is overdue on payments. Please contact support to resolve payment issues.';
        } else if (business.payment_status === 'suspended') {
          errorMessage = business.suspension_reason || 'Business account is suspended due to payment issues.';
        }
        return res.status(400).json({ message: errorMessage });
      }
    }

    // Verify password
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    // Generate JWT
    const token = jwt.sign(
      { id: user.id, username: user.username, role: user.role, business_id: user.business_id },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.json({
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
        business_id: user.business_id,
        language: user.language || 'English'
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get current user
router.get('/me', auth, async (req, res) => {
  try {
    const [users] = await pool.query(
      'SELECT id, username, email, role, language FROM users WHERE id = ?',
      [req.user.id]
    );

    if (users.length === 0) {
      return res.status(404).json({ message: 'User not found' });
    }

    res.json(users[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Update user profile
router.put('/profile', auth, async (req, res) => {
  try {
    const { username, email, currentPassword, newPassword, language } = req.body;
    const userId = req.user.id;

    // Get current user data
    const [users] = await pool.query(
      'SELECT * FROM users WHERE id = ?',
      [userId]
    );

    if (users.length === 0) {
      return res.status(404).json({ message: 'User not found' });
    }

    const user = users[0];
    const updates = [];
    const params = [];

    // Update username if provided
    if (username && username !== user.username) {
      // Check if username is already taken
      const [existingUsers] = await pool.query(
        'SELECT id FROM users WHERE username = ? AND id != ?',
        [username, userId]
      );
      if (existingUsers.length > 0) {
        return res.status(400).json({ message: 'Username already taken' });
      }
      updates.push('username = ?');
      params.push(username);
    }

    // Update email if provided
    if (email && email !== user.email) {
      // Check if email is already taken
      const [existingUsers] = await pool.query(
        'SELECT id FROM users WHERE email = ? AND id != ?',
        [email, userId]
      );
      if (existingUsers.length > 0) {
        return res.status(400).json({ message: 'Email already taken' });
      }
      updates.push('email = ?');
      params.push(email);
    }

    // Update password if provided
    if (currentPassword && newPassword) {
      const isMatch = await bcrypt.compare(currentPassword, user.password);
      if (!isMatch) {
        return res.status(400).json({ message: 'Current password is incorrect' });
      }
      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(newPassword, salt);
      updates.push('password = ?');
      params.push(hashedPassword);
    }

    // Update language if provided
    if (language && language !== user.language) {
      updates.push('language = ?');
      params.push(language);
    }

    if (updates.length === 0) {
      return res.status(400).json({ message: 'No changes to update' });
    }

    params.push(userId);
    const query = `UPDATE users SET ${updates.join(', ')} WHERE id = ?`;
    await pool.query(query, params);

    // Get updated user data
    const [updatedUsers] = await pool.query(
      'SELECT id, username, email, role, business_id, language FROM users WHERE id = ?',
      [userId]
    );

    res.json(updatedUsers[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get all users (superadmin can see all, others only their business)
router.get('/users', auth, async (req, res) => {
  try {
    let query = 'SELECT id, username, email, role, is_active, last_login, created_at, language FROM users WHERE business_id = ?';
    let params = [req.user.business_id];
    if (req.user.role === 'superadmin') {
      query = 'SELECT id, username, email, role, is_active, last_login, created_at, language FROM users';
      params = [];
    }
    const [users] = await pool.query(query, params);
    res.json(users);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router; 