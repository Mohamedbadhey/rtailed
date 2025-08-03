const http = require('http');

// Simple backend test
async function testBackend() {
  console.log('🔍 Testing Backend Connection...\n');
  
  try {
    // Test 1: Basic connection
    console.log('📡 Test 1: Basic connection...');
    const basicTest = await makeRequest('/');
    console.log('Status:', basicTest.status);
    console.log('');
    
    // Test 2: Businesses endpoint (should work)
    console.log('📡 Test 2: Businesses endpoint...');
    const businesses = await makeRequest('/api/businesses');
    console.log('Status:', businesses.status);
    if (businesses.status === 200) {
      console.log('✅ Businesses endpoint works');
      console.log('Number of businesses:', businesses.businesses?.length || 0);
    } else {
      console.log('❌ Businesses endpoint failed:', businesses.message);
    }
    console.log('');
    
    // Test 3: Revenue analytics endpoint (should fail without auth)
    console.log('📡 Test 3: Revenue analytics endpoint...');
    const revenue = await makeRequest('/api/admin/revenue-analytics');
    console.log('Status:', revenue.status);
    console.log('Response:', revenue.message || revenue.error || 'No error message');
    console.log('');
    
  } catch (error) {
    console.log('❌ Connection failed:', error.message);
    console.log('Make sure the backend server is running: npm start');
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
    req.setTimeout(3000, () => reject(new Error('Request timeout - backend not running')));
    req.end();
  });
}

if (require.main === module) {
  console.log('🚀 Simple Backend Test...\n');
  console.log('⚠️  This will test if the backend is running and responding\n');
  
  testBackend();
} 