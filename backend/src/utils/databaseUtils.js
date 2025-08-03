/**
 * Database utilities for handling MySQL GROUP BY issues
 */

const pool = require('../config/database');

/**
 * Execute a query with ONLY_FULL_GROUP_BY temporarily disabled
 * This is useful for complex GROUP BY queries that are difficult to make compliant
 */
const executeQueryWithRelaxedGroupBy = async (query, params = []) => {
  const connection = await pool.getConnection();
  try {
    // Store original SQL mode
    const [originalMode] = await connection.query('SELECT @@sql_mode as sql_mode');
    const originalSqlMode = originalMode[0].sql_mode;
    
    // Temporarily disable ONLY_FULL_GROUP_BY
    await connection.query("SET sql_mode = (SELECT REPLACE(@@sql_mode, 'ONLY_FULL_GROUP_BY', ''))");
    
    // Execute the query
    const [results] = await connection.query(query, params);
    
    // Restore original SQL mode
    await connection.query(`SET sql_mode = ?`, [originalSqlMode]);
    
    return results;
  } catch (error) {
    console.error('Error in executeQueryWithRelaxedGroupBy:', error);
    throw error;
  } finally {
    connection.release();
  }
};

/**
 * Check if ONLY_FULL_GROUP_BY is enabled
 */
const isOnlyFullGroupByEnabled = async () => {
  try {
    const [rows] = await pool.query('SELECT @@sql_mode as sql_mode');
    return rows[0].sql_mode.includes('ONLY_FULL_GROUP_BY');
  } catch (error) {
    console.error('Error checking ONLY_FULL_GROUP_BY:', error);
    return false;
  }
};

/**
 * Get current SQL mode
 */
const getCurrentSqlMode = async () => {
  try {
    const [rows] = await pool.query('SELECT @@sql_mode as sql_mode');
    return rows[0].sql_mode;
  } catch (error) {
    console.error('Error getting SQL mode:', error);
    return null;
  }
};

module.exports = {
  executeQueryWithRelaxedGroupBy,
  isOnlyFullGroupByEnabled,
  getCurrentSqlMode
}; 