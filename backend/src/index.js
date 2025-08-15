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

// Define base directories for Railway
const baseDir = process.env.RAILWAY_VOLUME_MOUNT_PATH || path.join(__dirname, '..');
const uploadsDir = baseDir;

// Try multiple possible paths for the Flutter web app
let webAppPath = path.join(__dirname, '..', 'web-app'); // Relative to src folder
if (!fs.existsSync(webAppPath)) {
  webAppPath = path.join(baseDir, 'web-app'); // Railway volume path
}
if (!fs.existsSync(webAppPath)) {
  webAppPath = path.join(__dirname, '..', '..', 'web-app'); // Go up two levels
}

console.log('🔧 Base directory:', baseDir);
console.log('🔧 Uploads directory:', uploadsDir);
console.log('🔧 Web app path:', webAppPath);
console.log('🔧 __dirname:', __dirname);
console.log('🔧 Railway volume path:', process.env.RAILWAY_VOLUME_MOUNT_PATH);

// Log all possible paths being checked
const possiblePaths = [
  path.join(__dirname, '..', 'web-app'),
  path.join(baseDir, 'web-app'),
  path.join(__dirname, '..', '..', 'web-app')
];

console.log('🔍 Checking possible web-app paths:');
possiblePaths.forEach((p, i) => {
  console.log(`  ${i + 1}. ${p} - ${fs.existsSync(p) ? 'EXISTS' : 'NOT FOUND'}`);
});

// Serve Flutter web app static files from root (like flutter run -d chrome)
if (fs.existsSync(webAppPath)) {
  console.log('🌐 Serving Flutter web app static files from root');
  app.use('/', express.static(webAppPath, {
    setHeaders: (res, path) => {
      // Set proper MIME types for Flutter web assets
      if (path.endsWith('.js')) {
        res.setHeader('Content-Type', 'application/javascript');
      } else if (path.endsWith('.css')) {
        res.setHeader('Content-Type', 'text/css');
      } else if (path.endsWith('.json')) {
        res.setHeader('Content-Type', 'application/json');
      } else if (path.endsWith('.png') || path.endsWith('.jpg') || path.endsWith('.jpeg')) {
        res.setHeader('Content-Type', 'image/png');
      }
    }
  }));
} else {
  console.log('⚠️  Flutter web app static files not found at:', webAppPath);
}

// Custom image serving route with CORS headers for products
app.get('/uploads/products/:filename', (req, res) => {
  try {
    const { filename } = req.params;
    const fullPath = path.join(uploadsDir, 'products', filename);
    
    console.log('🖼️ ===== PRODUCT IMAGE REQUEST START =====');
    console.log('🖼️ Request path:', req.path);
    console.log('🖼️ Filename:', filename);
    console.log('🖼️ Full path:', fullPath);
    console.log('🖼️ Uploads dir:', uploadsDir);
    console.log('🖼️ Base dir:', baseDir);
    console.log('🖼️ Railway volume path:', process.env.RAILWAY_VOLUME_MOUNT_PATH);
    console.log('🖼️ Request headers:', req.headers);
    console.log('🖼️ Request method:', req.method);
    console.log('🖼️ Request URL:', req.url);
    
    // Check if file exists
    console.log('🖼️ Checking if file exists:', fullPath);
    if (!fs.existsSync(fullPath)) {
      console.log('🖼️ ❌ File not found:', fullPath);
      console.log('🖼️ ===== PRODUCT IMAGE REQUEST END (404) =====');
      return res.status(404).json({ error: 'Image not found', path: fullPath });
    }
    console.log('🖼️ ✅ File exists:', fullPath);
    
    // Get file stats
    const stats = fs.statSync(fullPath);
    console.log('🖼️ File size:', stats.size, 'bytes');
    console.log('🖼️ File permissions:', stats.mode);
    
    // Set CORS headers
    console.log('🖼️ Setting CORS headers...');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept, Range, Authorization');
    res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range');
    res.setHeader('Cache-Control', 'public, max-age=31536000');
    console.log('🖼️ ✅ CORS headers set');
    
    // Set proper MIME type
    console.log('🖼️ Setting MIME type for:', filename);
    if (filename.endsWith('.jpg') || filename.endsWith('.jpeg')) {
      res.setHeader('Content-Type', 'image/jpeg');
      console.log('🖼️ ✅ MIME type: image/jpeg');
    } else if (filename.endsWith('.png')) {
      res.setHeader('Content-Type', 'image/png');
      console.log('🖼️ ✅ MIME type: image/png');
    } else if (filename.endsWith('.gif')) {
      res.setHeader('Content-Type', 'image/gif');
      console.log('🖼️ ✅ MIME type: image/gif');
    } else if (filename.endsWith('.webp')) {
      res.setHeader('Content-Type', 'image/webp');
      console.log('🖼️ ✅ MIME type: image/webp');
    }
    
    console.log('🖼️ Sending file:', fullPath);
    console.log('🖼️ Response headers before send:', res.getHeaders());
    res.sendFile(fullPath, (err) => {
      if (err) {
        console.log('🖼️ ❌ Error sending file:', err);
        console.log('🖼️ ===== PRODUCT IMAGE REQUEST END (ERROR) =====');
      } else {
        console.log('🖼️ ✅ File sent successfully');
        console.log('🖼️ ===== PRODUCT IMAGE REQUEST END (SUCCESS) =====');
      }
    });
    
  } catch (error) {
    console.log('🖼️ ❌ Error serving product image:', error);
    console.log('🖼️ Error stack:', error.stack);
    console.log('🖼️ ===== PRODUCT IMAGE REQUEST END (EXCEPTION) =====');
    res.status(500).json({ error: 'Internal server error', details: error.message });
  }
});

// Custom image serving route with CORS headers for branding
app.get('/uploads/branding/:filename', (req, res) => {
  try {
    const { filename } = req.params;
    const fullPath = path.join(uploadsDir, 'branding', filename);
    
    console.log('📁 Branding image request:', req.path);
    console.log('📁 Filename:', filename);
    console.log('📁 Full path:', fullPath);
    
    // Check if file exists
    if (!fs.existsSync(fullPath)) {
      console.log('📁 File not found:', fullPath);
      return res.status(404).json({ error: 'Image not found' });
    }
    
    // Set CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept, Range, Authorization');
    res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range');
    res.setHeader('Cache-Control', 'public, max-age=31536000');
    
    // Set proper MIME type
    if (filename.endsWith('.jpg') || filename.endsWith('.jpeg')) {
      res.setHeader('Content-Type', 'image/jpeg');
    } else if (filename.endsWith('.png')) {
      res.setHeader('Content-Type', 'image/png');
    } else if (filename.endsWith('.gif')) {
      res.setHeader('Content-Type', 'image/gif');
    } else if (filename.endsWith('.webp')) {
      res.setHeader('Content-Type', 'image/webp');
    }
    
    console.log('📁 Serving branding image with CORS headers:', fullPath);
    res.sendFile(fullPath);
    
  } catch (error) {
    console.error('📁 Error serving branding image:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Handle CORS preflight requests for uploads
app.options('/uploads/products/:filename', (req, res) => {
  console.log('📁 CORS preflight request for products:', req.path);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept, Range, Authorization');
  res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range');
  res.status(200).end();
});

app.options('/uploads/branding/:filename', (req, res) => {
  console.log('📁 CORS preflight request for branding:', req.path);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept, Range, Authorization');
  res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range');
  res.status(200).end();
});

// Test endpoint to verify route is working
app.get('/test-uploads', (req, res) => {
  console.log('📁 Test uploads endpoint hit');
  res.json({ 
    message: 'Uploads route is working',
    uploadsDir,
    baseDir,
    railwayVolumePath: process.env.RAILWAY_VOLUME_MOUNT_PATH
  });
});

// Root endpoint removed - Flutter web app will handle root path

// Health check endpoint (keeping for backward compatibility)
app.get('/api/health', (req, res) => {
  console.log('🏥 API health check requested');
  res.json({ 
    status: 'OK', 
    message: 'Retail Management API is running',
    timestamp: new Date().toISOString()
  });
});

// Railway-specific health check endpoint
app.get('/health', (req, res) => {
  console.log('🏥 Railway health check requested');
  res.status(200).send('OK');
});

// Test image serving endpoint
app.get('/api/test-image/:filename', (req, res) => {
  try {
    const { filename } = req.params;
    const baseDir = process.env.RAILWAY_VOLUME_MOUNT_PATH || path.join(__dirname, '..');
    const uploadsDir = baseDir;
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
    const uploadsDir = baseDir;
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
    const uploadsDir = baseDir;
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

// 404 handler for API routes
app.use('/api/*', (req, res) => {
  res.status(404).json({
    status: 'error',
    message: 'API endpoint not found'
  });
});

// Railway health check endpoint (moved to /health for Flutter app to use root)
app.get('/health', (req, res) => {
  console.log('🏥 Railway health check requested');
  res.json({ 
    status: 'OK', 
    message: 'Retail Management API is running',
    timestamp: new Date().toISOString(),
    endpoints: {
      health: '/api/health',
      api: '/api'
    }
  });
});

// Test route to verify routing is working
app.get('/test', (req, res) => {
  const possiblePaths = [
    path.join(__dirname, '..', 'web-app'),
    path.join(baseDir, 'web-app'),
    path.join(__dirname, '..', '..', 'web-app')
  ];
  
  res.json({ 
    message: 'Test route working!', 
    webAppPath: webAppPath, 
    exists: fs.existsSync(webAppPath),
    baseDir: baseDir,
    __dirname: __dirname,
    railwayVolume: process.env.RAILWAY_VOLUME_MOUNT_PATH,
    possiblePaths: possiblePaths.map(p => ({ path: p, exists: fs.existsSync(p) }))
  });
});

// Handle Flutter web app routing (SPA) - serve from root like flutter run -d chrome
if (fs.existsSync(webAppPath)) {
  console.log('🌐 Flutter web app routing enabled for:', webAppPath);
  
  // Serve Flutter web app from root (like flutter run -d chrome)
  app.get('/', (req, res) => {
    const indexPath = path.join(webAppPath, 'index.html');
    if (fs.existsSync(indexPath)) {
      console.log('🌐 Serving Flutter web app from root');
      res.sendFile(indexPath);
    } else {
      console.log('❌ Flutter web app index.html not found at:', indexPath);
      res.status(404).send('Web app not found. Please build and deploy the Flutter web app.');
    }
  });
  
  // Handle Flutter web app SPA routing for all other paths (except API)
  app.get('*', (req, res) => {
    // Don't interfere with API routes or uploads
    if (req.path.startsWith('/api/') || req.path.startsWith('/uploads/')) {
      return res.status(404).json({
        status: 'error',
        message: 'Route not found'
      });
    }
    
    // Serve index.html for all other routes (Flutter SPA routing)
    const indexPath = path.join(webAppPath, 'index.html');
    if (fs.existsSync(indexPath)) {
      console.log('🌐 Serving Flutter web app SPA route:', req.path);
      res.sendFile(indexPath);
    } else {
      console.log('❌ Flutter web app index.html not found at:', indexPath);
      res.status(404).send('Web app not found. Please build and deploy the Flutter web app.');
    }
  });
  
} else {
  console.log('⚠️  Flutter web app directory not found at:', webAppPath);
  console.log('📝 To serve the web app, build Flutter web and copy to:', webAppPath);
}

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

const server = app.listen(PORT, HOST, () => {
  console.log(`🚀 Server is running on http://${HOST}:${PORT}`);
  console.log(`📊 Health check: http://${HOST}:${PORT}/`);
  console.log(`🔗 API Base URL: http://${HOST}:${PORT}/api`);
  console.log(`📁 Uploads served from: http://${HOST}:${PORT}/uploads`);
  console.log(`🔧 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔧 Railway Volume: ${process.env.RAILWAY_VOLUME_MOUNT_PATH || 'Not set'}`);
  console.log(`🔧 Port: ${PORT}`);
  console.log(`🔧 Host: ${HOST}`);
});

// Graceful shutdown handling
process.on('SIGTERM', () => {
  console.log('🛑 Received SIGTERM, shutting down gracefully...');
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('🛑 Received SIGINT, shutting down gracefully...');
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
}); 