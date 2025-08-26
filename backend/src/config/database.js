const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'retail_management',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  // Configure SQL mode to be compatible with our queries
  multipleStatements: true,
  // Set SQL mode to be more permissive for GROUP BY queries
  sql_mode: 'STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO',
  // Set timezone to match your local timezone
  timezone: process.env.TIMEZONE || '+03:00', // Use environment variable or default to East Africa timezone
});

module.exports = pool; 