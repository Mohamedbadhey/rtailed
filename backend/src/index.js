require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const fs = require('fs');

const app = express();

// Create uploads directories if they don't exist
const createUploadsDirectories = () => {
  // Use Railway's persistent storage directory if available
  const baseDir = process.env.RAILWAY_VOLUME_MOUNT_PATH || path.join(__dirname, '..');
  const uploadsDir = path.join(baseDir, 'uploads');
  const productsDir = path.join(uploadsDir, 'products');
  const brandingDir = path.join(uploadsDir, 'branding');

  try {
    // Create main uploads directory
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
      console.log('✅ Created uploads directory:', uploadsDir);
    }

    // Create products subdirectory
    if (!fs.existsSync(productsDir)) {
      fs.mkdirSync(productsDir, { recursive: true });
      console.log('✅ Created uploads/products directory:', productsDir);
    }

    // Create branding subdirectory
    if (!fs.existsSync(brandingDir)) {
      fs.mkdirSync(brandingDir, { recursive: true });
      console.log('✅ Created uploads/branding directory:', brandingDir);
    }

    console.log('📁 Uploads directories ready');
  } catch (error) {
    console.error('❌ Error creating uploads directories:', error);
  }
};

// Initialize uploads directories
createUploadsDirectories();

// Check and log database SQL mode
const checkDatabaseMode = async () => {
  try {
    const pool = require('./config/database');
    const [rows] = await pool.query('SELECT @@sql_mode as sql_mode');
    console.log('🔧 Database SQL Mode:', rows[0].sql_mode);
    
    // Check if ONLY_FULL_GROUP_BY is enabled
    const hasOnlyFullGroupBy = rows[0].sql_mode.includes('ONLY_FULL_GROUP_BY');
    console.log('🔧 ONLY_FULL_GROUP_BY enabled:', hasOnlyFullGroupBy);
    
    if (hasOnlyFullGroupBy) {
      console.log('⚠️  ONLY_FULL_GROUP_BY is enabled - queries must be compliant');
    } else {
      console.log('✅ ONLY_FULL_GROUP_BY is disabled - queries are more permissive');
    }
  } catch (error) {
    console.error('❌ Error checking database SQL mode:', error);
  }
};

// Check database mode on startup
checkDatabaseMode();

// CORS configuration for Flutter web
const corsOptions = {
  origin: true, // Allow all origins for development
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept', 'Origin']
};

// Middleware
app.use(helmet());
app.use(cors(corsOptions));
app.use(morgan('dev'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Serve static files (for product images)
const baseDir = process.env.RAILWAY_VOLUME_MOUNT_PATH || path.join(__dirname, '..');
app.use('/uploads', express.static(path.join(baseDir, 'uploads')));

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'Retail Management API is running',
    timestamp: new Date().toISOString()
  });
});

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/products', require('./routes/products'));
app.use('/api/categories', require('./routes/categories'));
app.use('/api/customers', require('./routes/customers'));
app.use('/api/sales', require('./routes/sales'));
app.use('/api/inventory', require('./routes/inventory'));
app.use('/api/damaged-products', require('./routes/damaged_products'));
app.use('/api/admin', require('./routes/admin'));
app.use('/api/businesses', require('./routes/businesses'));
app.use('/api/notifications', require('./routes/notifications'));
app.use('/api/branding', require('./routes/branding'));
app.use('/api/business-payments', require('./routes/business_payments'));

// 404 handler
app.use('/api/*', (req, res) => {
  res.status(404).json({
    status: 'error',
    message: 'API endpoint not found'
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    status: 'error',
    message: err.message || 'Something went wrong!',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

app.listen(PORT, HOST, () => {
  console.log(`🚀 Server is running on http://${HOST}:${PORT}`);
  console.log(`📊 Health check: http://${HOST}:${PORT}/api/health`);
  console.log(`🔗 API Base URL: http://${HOST}:${PORT}/api`);
  console.log(`📁 Uploads served from: http://${HOST}:${PORT}/uploads`);
}); 