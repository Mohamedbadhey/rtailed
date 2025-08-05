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
  const uploadsDir = path.join(__dirname, '../uploads');
  const productsDir = path.join(uploadsDir, 'products');
  const brandingDir = path.join(uploadsDir, 'branding');

  try {
    // Create main uploads directory
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
      console.log('✅ Created uploads directory');
    }

    // Create products subdirectory
    if (!fs.existsSync(productsDir)) {
      fs.mkdirSync(productsDir, { recursive: true });
      console.log('✅ Created uploads/products directory');
    }

    // Create branding subdirectory
    if (!fs.existsSync(brandingDir)) {
      fs.mkdirSync(brandingDir, { recursive: true });
      console.log('✅ Created uploads/branding directory');
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
  origin: '*', // Allow all origins
  credentials: false, // Disable credentials for cross-origin requests
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept', 'Origin', 'Range'],
  exposedHeaders: ['Content-Length', 'Content-Range']
};

// Global CORS middleware for all routes
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, Accept, Origin, Range');
  res.header('Access-Control-Expose-Headers', 'Content-Length, Content-Range');
  
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }
  next();
});

// Middleware
app.use(helmet());
app.use(cors(corsOptions));
app.use(morgan('dev'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Serve static files (for product images) - Updated for Railway volume
const baseDir = process.env.RAILWAY_VOLUME_MOUNT_PATH || path.join(__dirname, '..');
const uploadsDir = baseDir.endsWith('uploads') ? baseDir : path.join(baseDir, 'uploads');

// Serve static files with proper MIME types and CORS
app.use('/uploads', (req, res, next) => {
  console.log('📁 Static file request:', req.url);
  console.log('📁 Base directory:', baseDir);
  console.log('📁 Uploads directory:', uploadsDir);
  console.log('📁 Full path:', path.join(uploadsDir, req.url));
  console.log('📁 Environment:', process.env.RAILWAY_VOLUME_MOUNT_PATH ? 'Railway' : 'Local');
  
  // Set CORS headers for all static file requests
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept, Range');
  res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range');
  
  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }
  
  next();
});

// Serve static files with proper MIME types and CORS headers
app.use('/uploads', express.static(uploadsDir, {
  setHeaders: (res, filePath) => {
    console.log('📁 Setting headers for:', filePath);
    
    // Set proper MIME types for images
    if (filePath.endsWith('.jpg') || filePath.endsWith('.jpeg')) {
      res.setHeader('Content-Type', 'image/jpeg');
    } else if (filePath.endsWith('.png')) {
      res.setHeader('Content-Type', 'image/png');
    } else if (filePath.endsWith('.gif')) {
      res.setHeader('Content-Type', 'image/gif');
    } else if (filePath.endsWith('.webp')) {
      res.setHeader('Content-Type', 'image/webp');
    }
    
    // CORS headers for images - CRITICAL for browser access
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept, Range');
    res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range');
    res.setHeader('Cache-Control', 'public, max-age=31536000'); // Cache for 1 year
    
    console.log('📁 CORS headers set for:', filePath);
  }
}));

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'Retail Management API is running',
    timestamp: new Date().toISOString()
  });
});

// Test image serving endpoint
app.get('/api/test-image/:filename', (req, res) => {
  try {
    const { filename } = req.params;
    const baseDir = process.env.RAILWAY_VOLUME_MOUNT_PATH || path.join(__dirname, '..');
    const uploadsDir = baseDir.endsWith('uploads') ? baseDir : path.join(baseDir, 'uploads');
    const imagePath = path.join(uploadsDir, 'products', filename);
    
    console.log('🖼️ Testing image serving for:', filename);
    console.log('🖼️ Full path:', imagePath);
    
    if (!fs.existsSync(imagePath)) {
      return res.status(404).json({
        status: 'ERROR',
        message: 'Image not found',
        filename,
        path: imagePath
      });
    }
    
    // Set proper headers for image serving
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept, Range');
    res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range');
    res.setHeader('Cache-Control', 'public, max-age=31536000');
    
    // Determine MIME type
    let mimeType = 'image/jpeg'; // default
    if (filename.endsWith('.png')) mimeType = 'image/png';
    else if (filename.endsWith('.gif')) mimeType = 'image/gif';
    else if (filename.endsWith('.webp')) mimeType = 'image/webp';
    
    res.setHeader('Content-Type', mimeType);
    
    // Send the image file
    res.sendFile(imagePath);
    
  } catch (error) {
    console.error('🖼️ Image test error:', error);
    res.status(500).json({
      status: 'ERROR',
      message: error.message
    });
  }
});

// Direct image serving route with CORS for Flutter app
app.get('/api/images/:filename', (req, res) => {
  try {
    const { filename } = req.params;
    const baseDir = process.env.RAILWAY_VOLUME_MOUNT_PATH || path.join(__dirname, '..');
    const uploadsDir = baseDir.endsWith('uploads') ? baseDir : path.join(baseDir, 'uploads');
    const imagePath = path.join(uploadsDir, 'products', filename);
    
    console.log('🖼️ Direct image request:', filename);
    console.log('🖼️ Full path:', imagePath);
    
    if (!fs.existsSync(imagePath)) {
      return res.status(404).json({
        status: 'ERROR',
        message: 'Image not found',
        filename,
        path: imagePath
      });
    }
    
    // Set CORS headers explicitly - CRITICAL for browser access
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept, Range');
    res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range');
    res.setHeader('Cache-Control', 'public, max-age=31536000');
    
    // Determine MIME type
    let mimeType = 'image/jpeg'; // default
    if (filename.endsWith('.png')) mimeType = 'image/png';
    else if (filename.endsWith('.gif')) mimeType = 'image/gif';
    else if (filename.endsWith('.webp')) mimeType = 'image/webp';
    
    res.setHeader('Content-Type', mimeType);
    
    console.log('🖼️ Serving image via API with CORS:', imagePath);
    res.sendFile(imagePath);
    
  } catch (error) {
    console.error('🖼️ Direct image error:', error);
    res.status(500).json({
      status: 'ERROR',
      message: error.message
    });
  }
});

// Test file system endpoint
app.get('/api/test-filesystem', (req, res) => {
  try {
    const baseDir = process.env.RAILWAY_VOLUME_MOUNT_PATH || path.join(__dirname, '..');
    const uploadsDir = baseDir.endsWith('uploads') ? baseDir : path.join(baseDir, 'uploads');
    const productsDir = path.join(uploadsDir, 'products');
    
    console.log('🔍 Testing file system access...');
    console.log('🔍 Base directory:', baseDir);
    console.log('🔍 Uploads directory:', uploadsDir);
    console.log('🔍 Products directory:', productsDir);
    
    const uploadsExists = fs.existsSync(uploadsDir);
    const productsExists = fs.existsSync(productsDir);
    
    let files = [];
    if (productsExists) {
      try {
        files = fs.readdirSync(productsDir);
        console.log('🔍 Found files in products directory:', files);
      } catch (error) {
        console.log('🔍 Error reading products directory:', error.message);
      }
    }
    
    res.json({
      status: 'OK',
      environment: process.env.RAILWAY_VOLUME_MOUNT_PATH ? 'Railway' : 'Local',
      railwayVolumePath: process.env.RAILWAY_VOLUME_MOUNT_PATH,
      baseDirectory: baseDir,
      uploadsDirectory: uploadsDir,
      productsDirectory: productsDir,
      uploadsExists,
      productsExists,
      files,
      fileCount: files.length
    });
  } catch (error) {
    console.error('🔍 File system test error:', error);
    res.status(500).json({
      status: 'ERROR',
      message: error.message,
      stack: error.stack
    });
  }
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