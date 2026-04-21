const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'retail_management',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  dateStrings: true, // Return DATE/DATETIME/TIMESTAMP as 'YYYY-MM-DD HH:mm:ss' strings (no TZ conversion)
  // Configure SQL mode to be compatible with our queries
  multipleStatements: true,
  // Set SQL mode to be more permissive for GROUP BY queries
  sql_mode: 'STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO',
  // Set timezone to match your local timezone (still used for NOW(), etc.)
  timezone: process.env.TIMEZONE || '+03:00', // Use environment variable or default to East Africa timezone
});

// NOTE:
// - With dateStrings: true, MySQL DATETIME/TIMESTAMP values are not converted to JS Date objects,
//   preventing implicit UTC serialization. The API will return the exact DB string like 'YYYY-MM-DD HH:mm:ss'.
// - Keep timezone for server-side functions (e.g., NOW()) but it will not alter returned strings.

module.exports = pool; 