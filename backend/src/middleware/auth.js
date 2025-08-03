const jwt = require('jsonwebtoken');

const auth = (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ message: 'No authentication token, access denied' });
    }

    const verified = jwt.verify(token, process.env.JWT_SECRET);
    req.user = verified;
    next();
  } catch (err) {
    res.status(401).json({ message: 'Token verification failed, authorization denied' });
  }
};

const checkRole = (roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ message: 'Access denied: insufficient permissions' });
    }
    next();
  };
};

// Middleware: allow superadmin for any, admin/manager only for cashiers
const adminOrSuperadminForCashier = async (req, res, next) => {
  const pool = require('../config/database');
  const userRole = req.user.role;
  if (userRole === 'superadmin') return next();
  if (userRole === 'admin' || userRole === 'manager') {
    // For create: check req.body.role
    if (req.method === 'POST' && req.body && req.body.role === 'cashier') return next();
    // For update/delete: check target user's role
    const userId = req.params.id;
    if (userId) {
      try {
        const [rows] = await pool.query('SELECT role FROM users WHERE id = ? AND business_id = ?', [userId, req.user.business_id]);
        if (rows.length && rows[0].role === 'cashier') return next();
      } catch (e) {}
    }
  }
  return res.status(403).json({ message: 'Access denied: insufficient permissions' });
};

module.exports = { auth, checkRole, adminOrSuperadminForCashier }; 