const http = require('http');

// Quick test for business isolation
async function quickTest() {
  console.log('🚀 Quick Business Isolation Test...\n');
  
  try {
    // Test business 1
    console.log('Testing Business 1...');
    const business1 = await makeRequest('/api/admin/businesses/1/details');
    console.log(`Users: ${business1.users.total_users}`);
    console.log(`Products: ${business1.products.total_products}`);
    console.log(`Customers: ${business1.customers.total_customers}`);
    console.log(`Sales: ${business1.sales.total_sales}`);
    console.log(`Revenue: $${business1.sales.total_revenue}`);
    console.log('');
    
    // Test business 2
    console.log('Testing Business 2...');
    const business2 = await makeRequest('/api/admin/businesses/2/details');
    console.log(`Users: ${business2.users.total_users}`);
    console.log(`Products: ${business2.products.total_products}`);
    console.log(`Customers: ${business2.customers.total_customers}`);
    console.log(`Sales: ${business2.sales.total_sales}`);
    console.log(`Revenue: $${business2.sales.total_revenue}`);
    console.log('');
    
    // Compare data
    console.log('Data Comparison:');
    console.log(`Users different: ${business1.users.total_users !== business2.users.total_users ? '✅' : '❌'}`);
    console.log(`Products different: ${business1.products.total_products !== business2.products.total_products ? '✅' : '❌'}`);
    console.log(`Customers different: ${business1.customers.total_customers !== business2.customers.total_customers ? '✅' : '❌'}`);
    console.log(`Sales different: ${business1.sales.total_sales !== business2.sales.total_sales ? '✅' : '❌'}`);
    console.log(`Revenue different: ${business1.sales.total_revenue !== business2.sales.total_revenue ? '✅' : '❌'}`);
    
    console.log('\n🎉 Business isolation test completed!');
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

function makeRequest(path) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: path,
      method: 'GET',
      headers: {
        'Authorization': 'Bearer your_superadmin_token_here',
        'Content-Type': 'application/json'
      }
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (error) {
          reject(new Error(`Failed to parse response: ${error.message}`));
        }
      });
    });

    req.on('error', (error) => reject(new Error(`Request failed: ${error.message}`)));
    req.end();
  });
}

if (require.main === module) {
  quickTest();
} 