const mysql = require('mysql2/promise');
require('dotenv').config();

async function debugCashierReports() {
  let connection;
  
  try {
    // Create connection
    connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_NAME || 'retail_management',
      port: process.env.DB_PORT || 3306
    });

    console.log('🔍 DEBUGGING CASHIER REPORTS');
    console.log('================================');

    // 1. Check if sales table exists and has data
    console.log('\n1. Checking sales table structure...');
    const [salesStructure] = await connection.execute('DESCRIBE sales');
    console.log('Sales table columns:', salesStructure.map(col => col.Field));

    // 2. Check total sales count
    const [totalSales] = await connection.execute('SELECT COUNT(*) as total FROM sales');
    console.log('Total sales in database:', totalSales[0].total);

    // 3. Check sales by business_id
    const [salesByBusiness] = await connection.execute(`
      SELECT business_id, COUNT(*) as count, SUM(total_amount) as total_revenue 
      FROM sales 
      GROUP BY business_id
    `);
    console.log('Sales by business:', salesByBusiness);

    // 4. Check sales by user_id (cashiers)
    const [salesByUser] = await connection.execute(`
      SELECT user_id, COUNT(*) as count, SUM(total_amount) as total_revenue 
      FROM sales 
      WHERE user_id IS NOT NULL
      GROUP BY user_id
    `);
    console.log('Sales by user (cashier):', salesByUser);

    // 5. Check users table for cashiers
    console.log('\n2. Checking users table...');
    const [cashiers] = await connection.execute(`
      SELECT id, username, role, business_id 
      FROM users 
      WHERE role = 'cashier'
    `);
    console.log('Cashiers found:', cashiers);

    // 6. Test the exact query that the sales report uses
    console.log('\n3. Testing sales report query...');
    
    // Simulate the sales report query for a specific cashier
    const testUserId = cashiers.length > 0 ? cashiers[0].id : 1;
    const testBusinessId = cashiers.length > 0 ? cashiers[0].business_id : 1;
    
    console.log(`Testing with user_id: ${testUserId}, business_id: ${testBusinessId}`);
    
    // Build the WHERE clause exactly as in the sales report
    let whereClause = 'WHERE (s.status = "completed" OR s.payment_method = "credit") AND s.parent_sale_id IS NULL';
    const params = [];
    
    // Add business_id filter
    whereClause += ' AND s.business_id = ?';
    params.push(testBusinessId);
    
    // Add user_id filter
    whereClause += ' AND s.user_id = ?';
    params.push(testUserId);
    
    console.log('WHERE clause:', whereClause);
    console.log('Parameters:', params);
    
    // Test the summary query
    const [summary] = await connection.execute(
      `SELECT COUNT(*) as total_orders, SUM(s.total_amount) as total_revenue, AVG(s.total_amount) as average_order_value, MIN(s.total_amount) as min_order, MAX(s.total_amount) as max_order FROM sales s ${whereClause}`,
      params
    );
    
    console.log('Summary result:', summary[0]);
    
    // Test sales by period
    const [salesByPeriod] = await connection.execute(
      `SELECT DATE_FORMAT(s.created_at, '%Y-%m-%d') as period, COUNT(*) as total_sales, SUM(s.total_amount) as total_revenue, AVG(s.total_amount) as average_sale FROM sales s ${whereClause} GROUP BY DATE_FORMAT(s.created_at, '%Y-%m-%d') ORDER BY period DESC`,
      params
    );
    
    console.log('Sales by period result:', salesByPeriod);
    
    // 7. Check if there are any sales for this specific cashier
    const [cashierSales] = await connection.execute(
      'SELECT id, total_amount, status, created_at, payment_method FROM sales WHERE user_id = ? AND business_id = ? ORDER BY created_at DESC LIMIT 10',
      [testUserId, testBusinessId]
    );
    
    console.log(`\n4. Sales for cashier ${testUserId}:`, cashierSales);
    
    // 8. Check if there are any sales at all for this business
    const [businessSales] = await connection.execute(
      'SELECT id, total_amount, status, created_at, payment_method, user_id FROM sales WHERE business_id = ? ORDER BY created_at DESC LIMIT 10',
      [testBusinessId]
    );
    
    console.log(`\n5. All sales for business ${testBusinessId}:`, businessSales);
    
    // 9. Check if the issue is with date filtering
    console.log('\n6. Testing without date filters...');
    const [noDateFilter] = await connection.execute(
      `SELECT COUNT(*) as total_orders, SUM(s.total_amount) as total_revenue FROM sales s ${whereClause}`,
      params
    );
    
    console.log('Result without date filters:', noDateFilter[0]);
    
    // 10. Check if there are any sales in the last 30 days
    const [recentSales] = await connection.execute(
      `SELECT COUNT(*) as total_orders, SUM(s.total_amount) as total_revenue FROM sales s ${whereClause} AND s.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)`,
      params
    );
    
    console.log('Result for last 30 days:', recentSales[0]);

  } catch (error) {
    console.error('❌ Error during debugging:', error);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

// Run the debug function
debugCashierReports().catch(console.error);
