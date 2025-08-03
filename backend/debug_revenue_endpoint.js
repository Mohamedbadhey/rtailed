const http = require('http');

// Debug revenue analytics endpoint
async function debugRevenueEndpoint() {
  console.log('🔍 Debugging Revenue Analytics Endpoint...\n');
  
  try {
    // Test 1: Check if endpoint exists
    console.log('📡 Test 1: Checking endpoint availability...');
    const data = await makeRequest('/api/admin/revenue-analytics');
    console.log('Status:', data.status);
    console.log('Response:', data.message || data);
    console.log('');
    
    // Test 2: Check if monthly_bills table exists
    console.log('📡 Test 2: Checking monthly_bills table...');
    const tableCheck = await makeRequest('/api/admin/test-business-isolation');
    console.log('Business isolation test status:', tableCheck.status);
    console.log('');
    
    // Test 3: Check businesses endpoint
    console.log('📡 Test 3: Checking businesses endpoint...');
    const businesses = await makeRequest('/api/businesses');
    console.log('Businesses endpoint status:', businesses.status);
    if (businesses.businesses) {
      console.log('Number of businesses:', businesses.businesses.length);
      if (businesses.businesses.length > 0) {
        console.log('Sample business:', businesses.businesses[0]);
      }
    }
    console.log('');
    
  } catch (error) {
    console.log('❌ Error:', error.message);
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
        'Content-Type': 'application/json'
      }
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ ...parsed, status: res.statusCode });
        } catch (error) {
          resolve({ status: res.statusCode, message: data });
        }
      });
    });

    req.on('error', (error) => reject(new Error(`Request failed: ${error.message}`)));
    req.setTimeout(5000, () => reject(new Error('Request timeout')));
    req.end();
  });
}

if (require.main === module) {
  console.log('🚀 Revenue Analytics Debug Test...\n');
  console.log('⚠️  Make sure backend is running: npm start\n');
  
  debugRevenueEndpoint();
} 