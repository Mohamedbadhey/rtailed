const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.MYSQLHOST || process.env.DB_HOST || 'localhost',
  user: process.env.MYSQLUSER || process.env.DB_USER || 'root',
  password: process.env.MYSQLPASSWORD || process.env.DB_PASSWORD || '',
  database: process.env.MYSQLDATABASE || process.env.DB_NAME || 'retail_management',
  port: process.env.MYSQLPORT || process.env.DB_PORT || 3306,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  dateStrings: true, // Return DATE/DATETIME/TIMESTAMP as 'YYYY-MM-DD HH:mm:ss' strings (no TZ conversion)
  multipleStatements: true,
  // Set timezone to match your local timezone
  timezone: process.env.TIMEZONE || '+03:00',
});

// NOTE:
// - With dateStrings: true, MySQL DATETIME/TIMESTAMP values are not converted to JS Date objects,
//   preventing implicit UTC serialization. The API will return the exact DB string like 'YYYY-MM-DD HH:mm:ss'.
// - Keep timezone for server-side functions (e.g., NOW()) but it will not alter returned strings.

module.exports = pool; 