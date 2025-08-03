const http = require('http');

// Test configuration
const BASE_URL = 'http://localhost:3000';
const TEST_TOKEN = 'your_superadmin_token_here'; // Replace with actual token

// Test function to check business data isolation
async function testBusinessIsolation() {
  console.log('🧪 Testing Business Data Isolation...\n');

  try {
    // First, test the isolation endpoint
    const isolationData = await makeRequest('/api/admin/test-business-isolation');
    console.log('📊 Business Data Isolation Test Results:');
    console.log('==========================================');
    
    isolationData.businesses.forEach(business => {
      console.log(`\n🏢 ${business.name} (ID: ${business.id})`);
      console.log(`   Plan: ${business.subscription_plan}`);
      console.log(`   Users: ${business.user_count}`);
      console.log(`   Products: ${business.product_count}`);
      console.log(`   Sales: ${business.sale_count}`);
      console.log(`   Customers: ${business.customer_count}`);
      console.log(`   Payments: ${business.payment_count}`);
      console.log(`   Activities: ${business.activity_count}`);
      console.log(`   Revenue: $${business.total_revenue.toFixed(2)}`);
    });

    console.log('\n🔍 Data Integrity Check:');
    console.log('========================');
    console.log(`Orphaned Users: ${isolationData.data_integrity.orphaned_users}`);
    console.log(`Orphaned Products: ${isolationData.data_integrity.orphaned_products}`);
    console.log(`Orphaned Sales: ${isolationData.data_integrity.orphaned_sales}`);
    console.log(`Orphaned Customers: ${isolationData.data_integrity.orphaned_customers}`);

    console.log('\n✅ Isolation Status:');
    console.log('===================');
    console.log(`Users Isolated: ${isolationData.isolation_status.users_isolated ? '✅' : '❌'}`);
    console.log(`Products Isolated: ${isolationData.isolation_status.products_isolated ? '✅' : '❌'}`);
    console.log(`Sales Isolated: ${isolationData.isolation_status.sales_isolated ? '✅' : '❌'}`);
    console.log(`Customers Isolated: ${isolationData.isolation_status.customers_isolated ? '✅' : '❌'}`);

    // Test individual business details
    console.log('\n🔬 Testing Individual Business Details:');
    console.log('=======================================');

    for (const business of isolationData.businesses) {
      console.log(`\n📋 Testing ${business.name} (ID: ${business.id})...`);
      
      const businessDetails = await makeRequest(`/api/admin/businesses/${business.id}/details`);
      
      console.log(`   Users in details: ${businessDetails.users.total_users}`);
      console.log(`   Products in details: ${businessDetails.products.total_products}`);
      console.log(`   Sales in details: ${businessDetails.sales.total_sales}`);
      console.log(`   Revenue in details: $${businessDetails.sales.total_revenue.toFixed(2)}`);
      
      // Verify data matches
      const usersMatch = businessDetails.users.total_users === business.user_count;
      const productsMatch = businessDetails.products.total_products === business.product_count;
      const salesMatch = businessDetails.sales.total_sales === business.sale_count;
      const revenueMatch = Math.abs(businessDetails.sales.total_revenue - business.total_revenue) < 0.01;
      
      console.log(`   Data Verification:`);
      console.log(`     Users match: ${usersMatch ? '✅' : '❌'}`);
      console.log(`     Products match: ${productsMatch ? '✅' : '❌'}`);
      console.log(`     Sales match: ${salesMatch ? '✅' : '❌'}`);
      console.log(`     Revenue match: ${revenueMatch ? '✅' : '❌'}`);
    }

    console.log('\n🎉 Business Data Isolation Test Completed!');
    console.log('Each business should show only their own unique data.');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
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

// Run the test
if (require.main === module) {
  console.log('🚀 Starting Business Data Isolation Test...\n');
  console.log('⚠️  Make sure to:');
  console.log('   1. Start the backend server (npm start)');
  console.log('   2. Update TEST_TOKEN with your superadmin token');
  console.log('   3. Run the database setup script first\n');
  
  testBusinessIsolation();
}

module.exports = { testBusinessIsolation }; 