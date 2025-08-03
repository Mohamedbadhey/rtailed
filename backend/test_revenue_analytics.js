const http = require('http');

// Test revenue analytics with date filtering
async function testRevenueAnalytics() {
  console.log('💰 Testing Revenue Analytics...\n');
  
  try {
    // Test different date ranges
    const testCases = [
      { name: 'Last 7 Days', start_date: '2024-01-01', end_date: '2024-01-07' },
      { name: 'Last 30 Days', start_date: '2024-01-01', end_date: '2024-01-30' },
      { name: 'Last 90 Days', start_date: '2023-11-01', end_date: '2024-01-30' },
      { name: 'All Time', start_date: null, end_date: null },
    ];
    
    for (const testCase of testCases) {
      console.log(`📊 Testing: ${testCase.name}`);
      
      let url = 'http://localhost:3000/api/admin/revenue-analytics';
      if (testCase.start_date && testCase.end_date) {
        url += `?start_date=${testCase.start_date}&end_date=${testCase.end_date}`;
      }
      
      const data = await makeRequest(url);
      
      console.log(`   Total Revenue: $${data.revenue_stats.total_revenue.toFixed(2)}`);
      console.log(`   Basic Revenue: $${data.revenue_stats.basic_revenue.toFixed(2)}`);
      console.log(`   Premium Revenue: $${data.revenue_stats.premium_revenue.toFixed(2)}`);
      console.log(`   Enterprise Revenue: $${data.revenue_stats.enterprise_revenue.toFixed(2)}`);
      console.log(`   Overdue Payments: ${data.payment_status.overdue}`);
      console.log(`   Current Payments: ${data.payment_status.current}`);
      console.log(`   Businesses: ${data.business_revenues.length}`);
      
      // Show top 3 businesses by revenue
      console.log('   Top 3 Businesses by Revenue:');
      data.business_revenues.slice(0, 3).forEach((business, index) => {
        console.log(`     ${index + 1}. ${business.business_name}: $${business.total_revenue.toFixed(2)}`);
      });
      
      console.log('');
    }
    
    console.log('✅ Revenue analytics test completed!');
    
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
  console.log('🚀 Starting Revenue Analytics Test...\n');
  console.log('⚠️  Make sure to:');
  console.log('   1. Start the backend server (npm start)');
  console.log('   2. Update the token in the script\n');
  
  testRevenueAnalytics();
} 