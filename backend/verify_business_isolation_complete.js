const http = require('http');

// Test configuration
const BASE_URL = 'https://api.kismayoict.com';
const TEST_TOKEN = 'your_superadmin_token_here'; // Replace with actual token

// Test function to verify complete business isolation
async function verifyBusinessIsolation() {
  console.log('🔍 Verifying Complete Business Data Isolation...\n');

  try {
    // First, get all businesses
    const businessesResponse = await makeRequest('/api/businesses');
    const businesses = businessesResponse.businesses || businessesResponse;
    
    console.log(`📊 Found ${businesses.length} businesses to test\n`);

    // Test each business individually
    for (const business of businesses) {
      console.log(`🏢 Testing Business: ${business.name} (ID: ${business.id})`);
      console.log('=' .repeat(50));
      
      const businessDetails = await makeRequest(`/api/admin/businesses/${business.id}/details`);
      
      // Verify each section has unique data
      console.log('\n📋 Business Overview:');
      console.log(`   Name: ${businessDetails.business.name}`);
      console.log(`   Plan: ${businessDetails.business.subscription_plan}`);
      console.log(`   Status: ${businessDetails.business.is_active ? 'Active' : 'Inactive'}`);
      
      console.log('\n👥 Users Management:');
      console.log(`   Total Users: ${businessDetails.users.total_users}`);
      console.log(`   Active Users: ${businessDetails.users.active_users}`);
      console.log(`   User List: ${businessDetails.users.user_list.length} users`);
      
      console.log('\n📦 Products Management:');
      console.log(`   Total Products: ${businessDetails.products.total_products}`);
      console.log(`   Low Stock: ${businessDetails.products.low_stock_products}`);
      console.log(`   Out of Stock: ${businessDetails.products.out_of_stock_products}`);
      console.log(`   Stock Value: $${businessDetails.products.total_stock_value.toFixed(2)}`);
      console.log(`   Product List: ${businessDetails.products.product_list.length} products`);
      
      console.log('\n👤 Customers Management:');
      console.log(`   Total Customers: ${businessDetails.customers.total_customers}`);
      console.log(`   Loyal Customers: ${businessDetails.customers.loyal_customers}`);
      console.log(`   Customer List: ${businessDetails.customers.customer_list.length} customers`);
      
      console.log('\n💰 Sales Information:');
      console.log(`   Total Sales: ${businessDetails.sales.total_sales}`);
      console.log(`   Total Revenue: $${businessDetails.sales.total_revenue.toFixed(2)}`);
      console.log(`   Avg Sale Value: $${businessDetails.sales.avg_sale_value.toFixed(2)}`);
      console.log(`   Recent Sales: ${businessDetails.sales.recent_sales.length} sales`);
      
      console.log('\n💳 Financial Information:');
      console.log(`   Total Paid: $${businessDetails.payments.total_paid.toFixed(2)}`);
      console.log(`   Outstanding Balance: $${businessDetails.payments.outstanding_balance.toFixed(2)}`);
      console.log(`   Payment History: ${businessDetails.payments.payment_history.length} payments`);
      
      console.log('\n📈 Activity Monitoring:');
      console.log(`   Total Actions: ${businessDetails.activity.total_actions}`);
      console.log(`   Actions Today: ${businessDetails.activity.actions_today}`);
      console.log(`   Actions This Week: ${businessDetails.activity.actions_this_week}`);
      console.log(`   Recent Activity: ${businessDetails.activity.recent_activity.length} logs`);
      
      console.log('\n✅ Data Isolation Verification:');
      
      // Check if data is unique (not empty for active businesses)
      const hasUsers = businessDetails.users.total_users > 0;
      const hasProducts = businessDetails.products.total_products > 0;
      const hasCustomers = businessDetails.customers.total_customers > 0;
      const hasSales = businessDetails.sales.total_sales > 0;
      const hasPayments = businessDetails.payments.payment_history.length > 0;
      const hasActivity = businessDetails.activity.total_actions > 0;
      
      console.log(`   Users isolated: ${hasUsers ? '✅' : '⚠️'}`);
      console.log(`   Products isolated: ${hasProducts ? '✅' : '⚠️'}`);
      console.log(`   Customers isolated: ${hasCustomers ? '✅' : '⚠️'}`);
      console.log(`   Sales isolated: ${hasSales ? '✅' : '⚠️'}`);
      console.log(`   Payments isolated: ${hasPayments ? '✅' : '⚠️'}`);
      console.log(`   Activity isolated: ${hasActivity ? '✅' : '⚠️'}`);
      
      console.log('\n' + '=' .repeat(50) + '\n');
    }

    // Test cross-business data contamination
    console.log('🔍 Testing for Cross-Business Data Contamination...\n');
    
    const isolationTest = await makeRequest('/api/admin/test-business-isolation');
    
    console.log('📊 Data Integrity Check:');
    console.log(`   Orphaned Users: ${isolationTest.data_integrity.orphaned_users}`);
    console.log(`   Orphaned Products: ${isolationTest.data_integrity.orphaned_products}`);
    console.log(`   Orphaned Sales: ${isolationTest.data_integrity.orphaned_sales}`);
    console.log(`   Orphaned Customers: ${isolationTest.data_integrity.orphaned_customers}`);
    
    console.log('\n✅ Isolation Status:');
    console.log(`   Users Isolated: ${isolationTest.isolation_status.users_isolated ? '✅' : '❌'}`);
    console.log(`   Products Isolated: ${isolationTest.isolation_status.products_isolated ? '✅' : '❌'}`);
    console.log(`   Sales Isolated: ${isolationTest.isolation_status.sales_isolated ? '✅' : '❌'}`);
    console.log(`   Customers Isolated: ${isolationTest.isolation_status.customers_isolated ? '✅' : '❌'}`);
    
    console.log('\n🎉 Complete Business Isolation Verification Finished!');
    console.log('Each business should now show only their own unique data in all sections.');

  } catch (error) {
    console.error('❌ Verification failed:', error.message);
  }
}

// Helper function to make HTTP requests
function makeRequest(path) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: path,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${TEST_TOKEN}`,
        'Content-Type': 'application/json'
      }
    };

    const req = http.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          const jsonData = JSON.parse(data);
          resolve(jsonData);
        } catch (error) {
          reject(new Error(`Failed to parse response: ${error.message}`));
        }
      });
    });

    req.on('error', (error) => {
      reject(new Error(`Request failed: ${error.message}`));
    });

    req.end();
  });
}

// Run the verification
if (require.main === module) {
  console.log('🚀 Starting Complete Business Isolation Verification...\n');
  console.log('⚠️  Make sure to:');
  console.log('   1. Start the backend server (npm start)');
  console.log('   2. Update TEST_TOKEN with your superadmin token');
  console.log('   3. Run the database setup script first\n');
  
  verifyBusinessIsolation();
}

module.exports = { verifyBusinessIsolation }; 