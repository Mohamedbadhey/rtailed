require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const fs = require('fs');
const dnsPromises = require('dns').promises;

const app = express();

// Create uploads directories if they don't exist
const createUploadsDirectories = () => {
  const baseDir = process.env.RAILWAY_VOLUME_MOUNT_PATH || path.join(__dirname, '../uploads');
  const uploadsDir = baseDir;
  const productsDir = path.join(uploadsDir, 'products');
  const brandingDir = path.join(uploadsDir, 'branding');

  try {
    // Create main uploads directory
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }

    // Create products subdirectory
    if (!fs.existsSync(productsDir)) {
      fs.mkdirSync(productsDir, { recursive: true });
    }

    // Create branding subdirectory
    if (!fs.existsSync(brandingDir)) {
      fs.mkdirSync(brandingDir, { recursive: true });
    }
  } catch (error) {
    console.error('❌ Error creating uploads directories:', error);
  }
};

// Initialize uploads directories
createUploadsDirectories();

// Check and log database SQL mode with retries
const STARTUP_RETRIES = Number(process.env.DB_STARTUP_RETRIES || 12);
const STARTUP_DELAY_MS = Number(process.env.DB_STARTUP_DELAY_MS || 7000);
const checkDatabaseMode = async (retries = STARTUP_RETRIES, delay = STARTUP_DELAY_MS) => {
  for (let i = 0; i < retries; i++) {
    try {
      let pool;
      try {
        pool = require('./config/database');
      } catch (err) {
        console.error('❌ Failed to load DB config:', err.message);
        return;
      }
      const [rows] = await pool.query('SELECT @@sql_mode as sql_mode');
      // Check if ONLY_FULL_GROUP_BY is enabled
      const hasOnlyFullGroupBy = rows[0].sql_mode.includes('ONLY_FULL_GROUP_BY');
      if (hasOnlyFullGroupBy) {
      } else {
      }
      return; // Success!
    } catch (error) {
      console.error(`❌ Database connection attempt ${i + 1} failed:`, error.message);
      if (i < retries - 1) {
        await new Promise(resolve => setTimeout(resolve, delay));
      } else {
        console.error('❌ All database connection attempts failed. The server will continue but DB features may fail.');
      }
    }
  }
};

// Optional startup DB check (disabled by default to avoid cold-start connection)
if (String(process.env.DB_CHECK_ON_STARTUP || 'false').toLowerCase() === 'true') {
  checkDatabaseMode(STARTUP_RETRIES, STARTUP_DELAY_MS);
}

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
const baseDir = process.env.RAILWAY_VOLUME_MOUNT_PATH || path.join(__dirname, '../uploads');
const uploadsDir = baseDir;

// Custom image serving route with CORS headers for products
app.get('/uploads/products/:filename', (req, res) => {
  try {
    const filename = decodeURIComponent(req.params.filename);

    // Comprehensive search for the file in all possible locations
    const possiblePaths = [
      path.join(uploadsDir, 'products', filename),
      path.join(uploadsDir, 'uploads/products', filename),
      path.join(__dirname, '../uploads/products', filename),
      path.join(__dirname, '../../uploads/products', filename),
      path.join(process.cwd(), 'uploads/products', filename),
      path.join('/data/products', filename),
      path.join('/data/uploads/products', filename)
    ];

    const fullPath = possiblePaths.find(p => fs.existsSync(p));
    // Check if file exists
    if (!fullPath) {
      // Debug: List files in the main products directory to see what IS there
      let filesInProducts = [];
      try {
        const debugDir = path.join(uploadsDir, 'products');
        if (fs.existsSync(debugDir)) {
          filesInProducts = fs.readdirSync(debugDir).slice(0, 20); // Just first 20 for brevity
        }
      } catch (e) { }

      return res.status(404).json({
        error: 'Image not found',
        filename,
        checkedPaths: possiblePaths,
        availableFilesSample: filesInProducts,
        uploadsDir: uploadsDir,
        envVolumePath: process.env.RAILWAY_VOLUME_MOUNT_PATH
      });
    }

    // Get file stats
    const stats = fs.statSync(fullPath);

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

    res.sendFile(fullPath, (err) => {
      if (err && !res.headersSent) {
        res.status(500).json({ error: 'Error sending file' });
      }
    });
  } catch (error) {
    if (!res.headersSent) {
      res.status(500).json({ error: 'Internal server error', details: error.message });
    }
  }
});

// Custom image serving route with CORS headers for branding
app.get('/uploads/branding/:filename', (req, res) => {
  try {
    const filename = decodeURIComponent(req.params.filename);

    // Comprehensive search for the branding file
    const possiblePaths = [
      path.join(uploadsDir, 'branding', filename),
      path.join(uploadsDir, 'uploads/branding', filename),
      path.join(__dirname, '../uploads/branding', filename),
      path.join(__dirname, '../../uploads/branding', filename),
      path.join(process.cwd(), 'uploads/branding', filename),
      path.join('/data/branding', filename),
      path.join('/data/uploads/branding', filename)
    ];

    const fullPath = possiblePaths.find(p => fs.existsSync(p));
    if (!fullPath) {
      return res.status(404).json({ error: 'Branding image not found', filename });
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

    res.sendFile(fullPath);
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Handle CORS preflight requests for uploads
app.options('/uploads/products/:filename', (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept, Range, Authorization');
  res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range');
  res.status(200).end();
});

app.options('/uploads/branding/:filename', (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept, Range, Authorization');
  res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range');
  res.status(200).end();
});

// Test endpoint to verify route is working
app.get('/test-uploads', (req, res) => {
  res.json({
    message: 'Uploads route is working',
    uploadsDir,
    baseDir,
    railwayVolumePath: process.env.RAILWAY_VOLUME_MOUNT_PATH
  });
});

// TEMPORARY DEBUG: Find where images are actually located
app.get('/api/debug-find-images', (req, res) => {
  const { exec } = require('child_process'); exec('find /app -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" | head -n 50', (err, stdout, stderr) => {
    res.json({
      stdout: stdout ? stdout.split('\n').filter(Boolean) : [],
      stderr,
      err: err ? err.message : null,
      cwd: process.cwd(),
      dirname: __dirname
    });
  });
});

// Root endpoint for Railway health checks
app.get('/', (req, res) => {
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

// Health check endpoint (keeping for backward compatibility)
app.get('/api/health', (req, res) => {
  res.json({
    status: 'OK',
    message: 'Retail Management API is running',
    timestamp: new Date().toISOString()
  });
});

// Helper to determine DB host for diagnostics (uses DATABASE_URL if present)
function getDbHost() {
  try {
    const u = new URL(process.env.DATABASE_URL || process.env.MYSQL_URL || '');
    if (u.hostname) return u.hostname;
  } catch (_) {}
  return process.env.MYSQLHOST || process.env.DB_HOST || 'localhost';
}

// Railway-specific health check endpoint with DB DNS diagnostics
app.get('/health', async (req, res) => {
  try {
    const host = getDbHost();
    const answers = await dnsPromises.lookup(host, { all: true });
    res.status(200).json({ ok: true, dns: answers.map(a => ({ address: a.address, family: a.family })) });
  } catch (e) {
    res.status(200).json({ ok: true, dnsError: e.message });
  }
});

// DB ping endpoint for connectivity diagnostics
app.get('/api/db-ping', async (req, res) => {
  const host = getDbHost();
  try {
    const addrs = await dnsPromises.lookup(host, { all: true });
    const db = require('./config/database');
    const [rows] = await db.query('SELECT 1 AS ok');
    res.json({ ok: true, result: rows[0], dns: addrs.map(a => ({ address: a.address, family: a.family })) });
  } catch (err) {
    try {
      const addrs = await dnsPromises.lookup(host, { all: true });
      res.status(500).json({ ok: false, error: err.message, dns: addrs.map(a => ({ address: a.address, family: a.family })) });
    } catch (e) {
      res.status(500).json({ ok: false, error: err.message, dnsError: e.message });
    }
  }
});

// Test file system endpoint
app.get('/api/test-filesystem', (req, res) => {
  try {
    const baseDir = process.env.RAILWAY_VOLUME_MOUNT_PATH || path.join(__dirname, '..');
    const uploadsDir = baseDir;
    const productsDir = path.join(uploadsDir, 'products');
    const uploadsExists = fs.existsSync(uploadsDir);
    const productsExists = fs.existsSync(productsDir);

    let files = [];
    if (productsExists) {
      try {
        files = fs.readdirSync(productsDir);
      } catch (error) { }
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
app.use('/api/stores', require('./routes/stores'));
app.use('/api/store-transfers', require('./routes/store_transfers'));
app.use('/api/store-inventory', require('./routes/store_inventory'));
app.use('/api/store-warehouse', require('./routes/store_warehouse'));

// Privacy Policy route - must be before catch-all routes
app.get('/privacy-policy', (req, res) => {
  const privacyPolicyPath = path.join(__dirname, '../../privacy_policy.html');
  res.sendFile(privacyPolicyPath, (err) => {
    if (err) {
      console.error('❌ Error serving privacy policy:', err);
      res.status(500).send('Privacy policy not found');
    }
  });
});

// Also support /privacy for convenience
app.get('/privacy', (req, res) => {
  const privacyPolicyPath = path.join(__dirname, '../../privacy_policy.html');
  res.sendFile(privacyPolicyPath, (err) => {
    if (err) {
      console.error('❌ Error serving privacy policy:', err);
      res.status(500).send('Privacy policy not found');
    }
  });
});

// Data Deletion Request route
app.get('/data-deletion-request', (req, res) => {
  const dataDeletionPath = path.join(__dirname, '../../data_deletion_request.html');
  res.sendFile(dataDeletionPath, (err) => {
    if (err) {
      console.error('❌ Error serving data deletion request page:', err);
      res.status(500).send('Data deletion request page not found');
    }
  });
});

// Also support /delete-data for convenience
app.get('/delete-data', (req, res) => {
  const dataDeletionPath = path.join(__dirname, '../../data_deletion_request.html');
  res.sendFile(dataDeletionPath, (err) => {
    if (err) {
      console.error('❌ Error serving data deletion request page:', err);
      res.status(500).send('Data deletion request page not found');
    }
  });
});

// Account Deletion Request route
app.get('/account-deletion-request', (req, res) => {
  const accountDeletionPath = path.join(__dirname, '../../account_deletion_request.html');
  res.sendFile(accountDeletionPath, (err) => {
    if (err) {
      console.error('❌ Error serving account deletion request page:', err);
      res.status(500).send('Account deletion request page not found');
    }
  });
});

// Also support /delete-account for convenience
app.get('/delete-account', (req, res) => {
  const accountDeletionPath = path.join(__dirname, '../../account_deletion_request.html');
  res.sendFile(accountDeletionPath, (err) => {
    if (err) {
      console.error('❌ Error serving account deletion request page:', err);
      res.status(500).send('Account deletion request page not found');
    }
  });
});

// 404 handler for API routes only
app.use('/api/*', (req, res) => {
  res.status(404).json({
    status: 'error',
    message: 'API endpoint not found'
  });
});

// Serve Flutter web app
app.use(express.static(path.join(__dirname, '../web-app')));

// Handle Flutter web routing - serve index.html for all non-API routes
app.get('*', (req, res) => {
  // Skip API routes
  if (req.path.startsWith('/api/')) {
    return res.status(404).json({
      status: 'error',
      message: 'API endpoint not found'
    });
  }

  // Skip uploads routes
  if (req.path.startsWith('/uploads/')) {
    return res.status(404).json({
      status: 'error',
      message: 'File not found'
    });
  }

  // Skip privacy policy routes (already handled above)
  if (req.path === '/privacy-policy' || req.path === '/privacy') {
    return;
  }

  // Skip data deletion request routes (already handled above)
  if (req.path === '/data-deletion-request' || req.path === '/delete-data') {
    return;
  }

  // Skip account deletion request routes (already handled above)
  if (req.path === '/account-deletion-request' || req.path === '/delete-account') {
    return;
  }

  // Serve Flutter web app
  res.sendFile(path.join(__dirname, '../web-app/index.html'));
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

const server = app.listen(PORT, HOST, () => {
  console.log(`✅ Server listening on http://${HOST}:${PORT}`);
});

// Tune Node HTTP timeouts for proxies/load balancers
server.keepAliveTimeout = Number(process.env.KEEP_ALIVE_TIMEOUT_MS || 65000);
server.headersTimeout = Number(process.env.HEADERS_TIMEOUT_MS || 66000);

// Extra diagnostics to see why the platform might stop the container
process.on('beforeExit', (code) => console.log('ℹ️ beforeExit', code));
process.on('exit', (code) => console.log('ℹ️ exit', code));
process.on('unhandledRejection', (reason, p) => console.error('❌ UnhandledRejection', reason));
process.on('uncaughtException', (err) => console.error('❌ UncaughtException', err));

process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing server...');
  server.close(() => {
    console.log('HTTP server closed');
  });
  try {
    const { closePool } = require('./config/database');
    await closePool(3000);
    console.log('DB pool closed');
  } catch (e) {
    console.log('DB pool close error:', e && e.message);
  }
  // Do not call process.exit(); let Node exit naturally.
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully...');
  server.close(() => {
    console.log('HTTP server closed');
  });
  try {
    const { closePool } = require('./config/database');
    await closePool(3000);
    console.log('DB pool closed');
  } catch (e) {
    console.log('DB pool close error:', e && e.message);
  }
  // Do not force exit; allow natural shutdown.
}); 