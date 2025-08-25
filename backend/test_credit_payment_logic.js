const mysql = require('mysql2/promise');

// Test script to verify credit payment logic
async function testCreditPaymentLogic() {
  const pool = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'retail_management',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
  });

  try {
    console.log('🔍 Testing Credit Payment Logic...\n');

    // Test 1: Check all credit sales
    console.log('1. All Credit Sales (should include both paid and unpaid):');
    const [allCreditSales] = await pool.query(
      `SELECT id, total_amount, status, parent_sale_id, payment_method, created_at 
       FROM sales 
       WHERE payment_method = 'credit' AND parent_sale_id IS NULL 
       ORDER BY created_at DESC`
    );
    console.log('   Found', allCreditSales.length, 'credit sales');
    allCreditSales.forEach(sale => {
      console.log(`   - Sale #${sale.id}: $${sale.total_amount}, Status: ${sale.status}, Date: ${sale.created_at}`);
    });

    // Test 2: Check credit payments
    console.log('\n2. Credit Payments (should NOT appear in reports):');
    const [creditPayments] = await pool.query(
      `SELECT id, total_amount, payment_method, parent_sale_id, created_at 
       FROM sales 
       WHERE parent_sale_id IS NOT NULL 
       ORDER BY created_at DESC`
    );
    console.log('   Found', creditPayments.length, 'credit payments');
    creditPayments.forEach(payment => {
      console.log(`   - Payment #${payment.id}: $${payment.total_amount} via ${payment.payment_method} for Sale #${payment.parent_sale_id}, Date: ${payment.created_at}`);
    });

    // Test 3: Check outstanding credits calculation
    console.log('\n3. Outstanding Credits Calculation:');
    const [outstandingCredits] = await pool.query(
      `SELECT 
        SUM(orig.total_amount) as total_original_credit,
        SUM(IFNULL(pay.total_paid, 0)) as total_paid_amount,
        SUM(orig.total_amount - IFNULL(pay.total_paid, 0)) as total_outstanding_credit
       FROM sales orig 
       LEFT JOIN (
         SELECT parent_sale_id, SUM(total_amount) as total_paid 
         FROM sales 
         WHERE parent_sale_id IS NOT NULL 
         GROUP BY parent_sale_id
       ) pay ON pay.parent_sale_id = orig.id 
       WHERE orig.payment_method = 'credit' 
         AND orig.parent_sale_id IS NULL 
       HAVING total_outstanding_credit > 0`
    );
    console.log('   Outstanding credits result:', outstandingCredits[0]);

    // Test 4: Check payment methods breakdown (should show outstanding credits and actual payment methods)
    console.log('\n4. Payment Methods Breakdown (should show outstanding credits and actual payment methods):');
    const [paymentMethods] = await pool.query(
      `SELECT 
        CASE 
          WHEN s.payment_method = 'credit' THEN 'credit'
          ELSE s.payment_method 
        END as payment_method,
        COUNT(*) as count, 
        SUM(s.total_amount) as total_amount 
       FROM sales s 
       WHERE s.status = "completed" AND s.parent_sale_id IS NULL
       GROUP BY payment_method 
       ORDER BY total_amount DESC`
    );
    console.log('   Payment methods result:');
    paymentMethods.forEach(pm => {
      console.log(`   - ${pm.payment_method}: ${pm.count} transactions, $${pm.total_amount} total`);
    });
    
    // Test 4b: Check what the final payment methods should look like with outstanding credits
    console.log('\n4b. Expected Final Payment Methods (with outstanding credits):');
    const outstandingAmount = 2.00; // Based on your data: $5.00 - $3.00 = $2.00
    console.log(`   - Credit: $${outstandingAmount} (outstanding amount)`);
    console.log(`   - EVC: $3.00 (sale #86: $1.00 + payment #88: $2.00)`);
    console.log(`   - Edahab: $1.00 (payment #89: $1.00)`);

    // Test 5: Check individual credit sale status
    console.log('\n5. Individual Credit Sale Status:');
    for (const sale of allCreditSales) {
      const [payments] = await pool.query(
        'SELECT IFNULL(SUM(total_amount), 0) as total_paid FROM sales WHERE parent_sale_id = ?',
        [sale.id]
      );
      const totalPaid = Number(payments[0].total_paid) || 0;
      const outstanding = Math.max(0, Number(sale.total_amount) - totalPaid);
      const isFullyPaid = outstanding <= 0;
      
      console.log(`   - Sale #${sale.id}: $${sale.total_amount} original, $${totalPaid} paid, $${outstanding} outstanding, Fully Paid: ${isFullyPaid}`);
    }

    console.log('\n✅ Credit Payment Logic Test Complete!');

  } catch (error) {
    console.error('❌ Test failed:', error);
  } finally {
    await pool.end();
  }
}

// Run the test
testCreditPaymentLogic();
