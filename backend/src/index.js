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
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }
    if (!fs.existsSync(productsDir)) {
      fs.mkdirSync(productsDir, { recursive: true });
    }
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
      const pool = require('./config/database');
      const [rows] = await pool.query('SELECT @@sql_mode as sql_mode');
      // Optionally log whether ONLY_FULL_GROUP_BY is enabled
      const hasOnlyFullGroupBy = String(rows?.[0]?.sql_mode || '').includes('ONLY_FULL_GROUP_BY');
      console.log(`DB connected. ONLY_FULL_GROUP_BY: ${hasOnlyFullGroupBy}`);
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

// CORS configuration (Flutter web friendly)
const corsOptions = {
  origin: '*',
  credentials: false,
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

// Serve static files (for product/branding images)
const baseDir = process.env.RAILWAY_VOLUME_MOUNT_PATH || path.join(__dirname, '../uploads');
const uploadsDir = baseDir;

// Helper: resolve a filename across multiple possible locations
function findUploadFile(subdir, filename) {
  const paths = [
    path.join(uploadsDir, subdir, filename),
    path.join(uploadsDir, `uploads/${subdir}`, filename),
    path.join(__dirname, `../uploads/${subdir}`, filename),
    path.join(__dirname, `../../uploads/${subdir}`, filename),
    path.join(process.cwd(), `uploads/${subdir}`, filename),
    path.join('/data', subdir, filename),
    path.join('/data/uploads', subdir, filename),
  ];
  return paths.find(p => fs.existsSync(p));
}

// Products images
app.get('/uploads/products/:filename', (req, res) => {
  try {
    const filename = decodeURIComponent(req.params.filename);
    const fullPath = findUploadFile('products', filename);
    if (!fullPath) {
      // Provide debug info to help locate files in containerized envs
      let filesInProducts = [];
      try {
        const debugDir = path.join(uploadsDir, 'products');
        if (fs.existsSync(debugDir)) {
          filesInProducts = fs.readdirSync(debugDir).slice(0, 20);
        }
      } catch (_) {}
      return res.status(404).json({
        error: 'Image not found',
        filename,
        uploadsDir,
        checkedPathsSample: [path.join(uploadsDir, 'products', filename), path.join(__dirname, '../uploads/products', filename)],
        availableFilesSample: filesInProducts,
        envVolumePath: process.env.RAILWAY_VOLUME_MOUNT_PATH
      });
    }

    // MIME
    if (filename.endsWith('.jpg') || filename.endsWith('.jpeg')) res.setHeader('Content-Type', 'image/jpeg');
    else if (filename.endsWith('.png')) res.setHeader('Content-Type', 'image/png');
    else if (filename.endsWith('.gif')) res.setHeader('Content-Type', 'image/gif');
    else if (filename.endsWith('.webp')) res.setHeader('Content-Type', 'image/webp');

    // CORS + cache
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept, Range, Authorization');
    res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range');
    res.setHeader('Cache-Control', 'public, max-age=31536000');

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

// Branding images
app.get('/uploads/branding/:filename', (req, res) => {
  try {
    const filename = decodeURIComponent(req.params.filename);
    const fullPath = findUploadFile('branding', filename);
    if (!fullPath) {
      return res.status(404).json({ error: 'Branding image not found', filename });
    }

    if (filename.endsWith('.jpg') || filename.endsWith('.jpeg')) res.setHeader('Content-Type', 'image/jpeg');
    else if (filename.endsWith('.png')) res.setHeader('Content-Type', 'image/png');
    else if (filename.endsWith('.gif')) res.setHeader('Content-Type', 'image/gif');
    else if (filename.endsWith('.webp')) res.setHeader('Content-Type', 'image/webp');

    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept, Range, Authorization');
    res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range');
    res.setHeader('Cache-Control', 'public, max-age=31536000');

    res.sendFile(fullPath);
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

// CORS preflight for uploads
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

// Simple diagnostics
app.get('/test-uploads', (req, res) => {
  res.json({ message: 'Uploads route is working', uploadsDir, baseDir, railwayVolumePath: process.env.RAILWAY_VOLUME_MOUNT_PATH });
});

app.get('/api/debug-find-images', (req, res) => {
  const { exec } = require('child_process');
  exec('find /app -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" | head -n 50', (err, stdout, stderr) => {
    res.json({ stdout: stdout ? stdout.split('\n').filter(Boolean) : [], stderr, err: err ? err.message : null, cwd: process.cwd(), dirname: __dirname });
  });
});

// Database startup diagnostic (rich logs)
async function logDbInfoOnStartup() {
  try {
    const db = require('./config/database');
    const [ver] = await db.query("SELECT @@version AS version, @@sql_mode AS sql_mode, @@time_zone AS time_zone, @@global.time_zone AS global_time_zone, DATABASE() AS db, USER() AS user, NOW() AS now");
    const info = (ver && ver[0]) || {};
    const hasOnlyFullGroupBy = String(info.sql_mode || '').includes('ONLY_FULL_GROUP_BY');
    console.log('🔗 Database connected');
    console.log(`  • Version: ${info.version}`);
    console.log(`  • Database: ${info.db}`);
    console.log(`  • User: ${info.user}`);
    console.log(`  • Time zone: ${info.time_zone} (global: ${info.global_time_zone})`);
    console.log(`  • SQL_MODE: ${info.sql_mode}`);
    console.log(`  • ONLY_FULL_GROUP_BY: ${hasOnlyFullGroupBy}`);
    const [test] = await db.query('SELECT 1 AS ok');
    const ok = test && test[0] && test[0].ok === 1;
    console.log(`  • Test query: ${ok ? 'OK' : 'Unexpected result'}`);
  } catch (err) {
    console.error('❌ Database check failed on startup:', err.message);
  }
}

// Health and diagnostics
function getDbHost() {
  try {
    const u = new URL(process.env.DATABASE_URL || process.env.MYSQL_URL || '');
    if (u.hostname) return u.hostname;
  } catch (_) {}
  return process.env.MYSQLHOST || process.env.DB_HOST || 'localhost';
}

app.get('/', (req, res) => {
  res.json({ status: 'OK', message: 'Retail Management API is running', timestamp: new Date().toISOString(), endpoints: { health: '/api/health', api: '/api' } });
});

app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', message: 'Retail Management API is running', timestamp: new Date().toISOString() });
});

app.get('/health', (req, res) => {
  res.status(200).json({ ok: true, status: 'OK' });
});

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

// Filesystem test
// DB info endpoint for diagnostics
app.get('/api/db-info', async (req, res) => {
  try {
    const db = require('./config/database');
    const [ver] = await db.query("SELECT @@version AS version, @@sql_mode AS sql_mode, @@time_zone AS time_zone, @@global.time_zone AS global_time_zone, DATABASE() AS db, USER() AS user, NOW() AS now");
    const [test] = await db.query('SELECT 1 AS ok');
    res.json({ ok: true, info: (ver && ver[0]) || {}, test: (test && test[0]) || {} });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

app.get('/api/test-filesystem', (req, res) => {
  try {
    const productsDir = path.join(uploadsDir, 'products');
    const uploadsExists = fs.existsSync(uploadsDir);
    const productsExists = fs.existsSync(productsDir);
    let files = [];
    if (productsExists) {
      try { files = fs.readdirSync(productsDir); } catch (_) {}
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
    res.status(500).json({ status: 'ERROR', message: error.message, stack: error.stack });
  }
});

// API routes
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

// Privacy policy and legal pages
app.get('/privacy-policy', (req, res) => {
  const privacyPolicyPath = path.join(__dirname, '../../privacy_policy.html');
  res.sendFile(privacyPolicyPath, (err) => {
    if (err) {
      console.error('❌ Error serving privacy policy:', err);
      res.status(500).send('Privacy policy not found');
    }
  });
});
app.get('/privacy', (req, res) => {
  const privacyPolicyPath = path.join(__dirname, '../../privacy_policy.html');
  res.sendFile(privacyPolicyPath, (err) => {
    if (err) {
      console.error('❌ Error serving privacy policy:', err);
      res.status(500).send('Privacy policy not found');
    }
  });
});
app.get('/data-deletion-request', (req, res) => {
  const dataDeletionPath = path.join(__dirname, '../../data_deletion_request.html');
  res.sendFile(dataDeletionPath, (err) => {
    if (err) {
      console.error('❌ Error serving data deletion request page:', err);
      res.status(500).send('Data deletion request page not found');
    }
  });
});
app.get('/delete-data', (req, res) => {
  const dataDeletionPath = path.join(__dirname, '../../data_deletion_request.html');
  res.sendFile(dataDeletionPath, (err) => {
    if (err) {
      console.error('❌ Error serving data deletion request page:', err);
      res.status(500).send('Data deletion request page not found');
    }
  });
});
app.get('/account-deletion-request', (req, res) => {
  const accountDeletionPath = path.join(__dirname, '../../account_deletion_request.html');
  res.sendFile(accountDeletionPath, (err) => {
    if (err) {
      console.error('❌ Error serving account deletion request page:', err);
      res.status(500).send('Account deletion request page not found');
    }
  });
});
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
  res.status(404).json({ status: 'error', message: 'API endpoint not found' });
});

// Serve Flutter web app
app.use(express.static(path.join(__dirname, '../web-app')));
app.get('*', (req, res) => {
  // Skip API and file routes
  if (req.path.startsWith('/api/')) {
    return res.status(404).json({ status: 'error', message: 'API endpoint not found' });
  }
  if (req.path.startsWith('/uploads/')) {
    return res.status(404).json({ status: 'error', message: 'File not found' });
  }
  // Skip legal pages already handled
  const passthrough = new Set(['/privacy-policy', '/privacy', '/data-deletion-request', '/delete-data', '/account-deletion-request', '/delete-account']);
  if (passthrough.has(req.path)) return;

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

const http = require('http');
const server = http.createServer(app);

// Handle port in-use gracefully by retrying on next port BEFORE listening
server.on('error', (err) => {
  if (err && err.code === 'EADDRINUSE') {
    const nextPort = Number(PORT) + 1;
    console.warn(`⚠️  Port ${PORT} is in use, retrying on ${nextPort}...`);
    try { server.close(); } catch (_) {}
    server.listen(nextPort, HOST);
  } else {
    console.error('❌ Server error:', err);
  }
});

server.on('listening', () => {
  const os = require('os');
  const addr = server.address();
  const usedPort = typeof addr === 'object' && addr ? addr.port : PORT;
  const isWildcard = (h) => !h || h === '0.0.0.0' || h === '::' || h === '0:0:0:0:0:0:0:0';
  const display = isWildcard(HOST) ? `http://localhost:${usedPort}` : `http://${HOST}:${usedPort}`;

  // Try to find a LAN IPv4 address for convenience
  let lan = null;
  try {
    const nets = os.networkInterfaces();
    for (const name of Object.keys(nets)) {
      for (const net of nets[name] || []) {
        if (net.family === 'IPv4' && !net.internal && /^10\.|^192\.168\.|^172\.(1[6-9]|2[0-9]|3[0-1])\./.test(net.address)) {
          lan = `http://${net.address}:${usedPort}`;
          break;
        }
      }
      if (lan) break;
    }
  } catch (_) {}

  const publicCandidates = [
    process.env.APP_URL,
    process.env.PUBLIC_URL,
    process.env.RAILWAY_PUBLIC_DOMAIN && `https://${process.env.RAILWAY_PUBLIC_DOMAIN}`,
    process.env.VERCEL_URL && `https://${process.env.VERCEL_URL}`,
  ].filter(Boolean);

  console.log('✅ Server started');
  console.log(`  • Bound:   http://${HOST}:${usedPort}`);
  console.log(`  • Local:   ${display}`);
  if (lan) console.log(`  • LAN:     ${lan}`);
  for (const url of publicCandidates) console.log(`  • Public:  ${url}`);

  // Show DB connectivity details on startup (enabled by default)
  if (String(process.env.DB_CHECK_ON_STARTUP || 'true').toLowerCase() === 'true') {
    logDbInfoOnStartup();
  }
});

server.listen(PORT, HOST);

// Handle port in-use gracefully by retrying on next port
server.on('error', (err) => {
  if (err && err.code === 'EADDRINUSE') {
    const nextPort = Number(PORT) + 1;
    console.warn(`⚠️  Port ${PORT} is in use, retrying on ${nextPort}...`);
    app.listen(nextPort, HOST, () => {
      const isWildcard = (h) => !h || h === '0.0.0.0' || h === '::' || h === '0:0:0:0:0:0:0:0';
      const displayHost = isWildcard(HOST) ? 'localhost' : HOST;
      console.log(`✅ Server moved to http://${displayHost}:${nextPort}`);
    });
  } else {
    console.error('❌ Server error:', err);
  }
});

// Tune Node HTTP timeouts for proxies/load balancers
server.keepAliveTimeout = Number(process.env.KEEP_ALIVE_TIMEOUT_MS || 65000);
server.headersTimeout = Number(process.env.HEADERS_TIMEOUT_MS || 66000);

// Extra diagnostics
process.on('beforeExit', (code) => console.log('ℹ️ beforeExit', code));
process.on('exit', (code) => console.log('ℹ️ exit', code));
process.on('unhandledRejection', (reason) => console.error('❌ UnhandledRejection', reason));
process.on('uncaughtException', (err) => console.error('❌ UncaughtException', err));

// Graceful shutdown
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
});
