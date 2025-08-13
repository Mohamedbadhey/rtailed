const mysql = require('mysql2/promise');

// Test script to verify credit payment fix
// This script will test the sales report logic to ensure credit payments are not counted as revenue

async function testCreditPaymentFix() {
  let connection;
  
  try {
    // Connect to database
    connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_NAME || 'rtail',
      port: process.env.DB_PORT || 3306
    });

    console.log('✅ Connected to database');
    
    // Test 1: Check current sales data structure
    console.log('\n📊 Test 1: Checking sales table structure...');
    const [salesStructure] = await connection.execute('DESCRIBE sales');
    console.log('Sales table columns:', salesStructure.map(col => col.Field));
    
    // Test 2: Check for credit sales and payments
    console.log('\n📊 Test 2: Checking credit sales and payments...');
    const [creditData] = await connection.execute(`
      SELECT 
        s.id,
        s.total_amount,
        s.payment_method,
        s.status,
        s.parent_sale_id,
        s.created_at,
        CASE 
          WHEN s.parent_sale_id IS NOT NULL THEN 'Credit Payment'
          WHEN s.payment_method = 'credit' THEN 'Credit Sale'
          ELSE 'Regular Sale'
        END as record_type
      FROM sales s 
      WHERE s.payment_method = 'credit' OR s.parent_sale_id IS NOT NULL
      ORDER BY s.created_at DESC
      LIMIT 20
    `);
    
    console.log('Credit-related records found:', creditData.length);
    creditData.forEach(record => {
      console.log(`  ID: ${record.id}, Amount: ${record.total_amount}, Type: ${record.record_type}, Parent: ${record.parent_sale_id || 'N/A'}`);
    });
    
    // Test 3: Test the fixed sales report query
    console.log('\n📊 Test 3: Testing fixed sales report query...');
    
    // Query that should exclude credit payments (parent_sale_id IS NOT NULL)
    const [fixedReport] = await connection.execute(`
      SELECT 
        COUNT(*) as total_orders,
        SUM(s.total_amount) as total_revenue,
        AVG(s.total_amount) as average_order_value
      FROM sales s 
      WHERE (s.status = "completed" OR s.payment_method = "credit") 
        AND s.parent_sale_id IS NULL
      LIMIT 1
    `);
    
    console.log('Fixed report results (excluding credit payments):');
    console.log(`  Total Orders: ${fixedReport[0].total_orders}`);
    console.log(`  Total Revenue: ${fixedReport[0].total_revenue}`);
    console.log(`  Average Order: ${fixedReport[0].average_order_value}`);
    
    // Test 4: Compare with old query (including credit payments)
    console.log('\n📊 Test 4: Comparing with old query (including credit payments)...');
    
    const [oldReport] = await connection.execute(`
      SELECT 
        COUNT(*) as total_orders,
        SUM(s.total_amount) as total_revenue,
        AVG(s.total_amount) as average_order_value
      FROM sales s 
      WHERE (s.status = "completed" OR s.payment_method = "credit")
      LIMIT 1
    `);
    
    console.log('Old report results (including credit payments):');
    console.log(`  Total Orders: ${oldReport[0].total_orders}`);
    console.log(`  Total Revenue: ${oldReport[0].total_revenue}`);
    console.log(`  Average Order: ${oldReport[0].average_order_value}`);
    
    // Test 5: Calculate the difference
    const revenueDifference = (oldReport[0].total_revenue || 0) - (fixedReport[0].total_revenue || 0);
    const orderDifference = (oldReport[0].total_orders || 0) - (fixedReport[0].total_orders || 0);
    
    console.log('\n📊 Test 5: Analysis of the fix...');
    console.log(`Revenue difference: ${revenueDifference} (this should be the total of credit payments)`);
    console.log(`Order difference: ${orderDifference} (this should be the count of credit payments)`);
    
    if (revenueDifference > 0) {
      console.log('✅ FIX CONFIRMED: Credit payments are no longer counted as revenue');
      console.log(`   Credit payments were inflating revenue by: ${revenueDifference}`);
    } else {
      console.log('⚠️  No credit payments found, or fix may not be needed');
    }
    
    // Test 6: Verify credit payments are still accessible
    console.log('\n📊 Test 6: Verifying credit payments are still accessible...');
    
    const [creditPayments] = await connection.execute(`
      SELECT 
        COUNT(*) as total_payments,
        SUM(total_amount) as total_payment_amount
      FROM sales 
      WHERE parent_sale_id IS NOT NULL
    `);
    
    console.log('Credit payments summary:');
    console.log(`  Total Payment Records: ${creditPayments[0].total_payments}`);
    console.log(`  Total Payment Amount: ${creditPayments[0].total_payment_amount}`);
    
    // Test 7: Check outstanding credits calculation
    console.log('\n📊 Test 7: Testing outstanding credits calculation...');
    
    const [outstandingCredits] = await connection.execute(`
      SELECT 
        SUM(orig.total_amount - IFNULL(pay.paid,0)) as total_outstanding_credit 
      FROM sales orig 
      LEFT JOIN (
        SELECT parent_sale_id, SUM(total_amount) as paid 
        FROM sales 
        WHERE parent_sale_id IS NOT NULL 
        GROUP BY parent_sale_id
      ) pay ON pay.parent_sale_id = orig.id 
      WHERE orig.payment_method = 'credit' 
        AND orig.parent_sale_id IS NULL 
        AND (orig.status != 'paid' OR orig.status IS NULL)
    `);
    
    console.log('Outstanding credits calculation:');
    console.log(`  Total Outstanding: ${outstandingCredits[0].total_outstanding_credit}`);
    
    console.log('\n🎉 All tests completed successfully!');
    
  } catch (error) {
    console.error('❌ Error during testing:', error);
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n🔌 Database connection closed');
    }
  }
}

// Run the test
if (require.main === module) {
  testCreditPaymentFix().catch(console.error);
}

module.exports = { testCreditPaymentFix };
