const http = require('http');

// Quick test for revenue analytics endpoint
async function testRevenueEndpoint() {
  console.log('💰 Testing Revenue Analytics Endpoint...\n');
  
  try {
    // Test without authentication first
    const data = await makeRequest('/api/admin/revenue-analytics');
    console.log('✅ Endpoint responds without auth (expected 401)');
    console.log('Status:', data.status || 'No status');
    console.log('Message:', data.message || 'No message');
    
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
  console.log('🚀 Quick Revenue Analytics Test...\n');
  console.log('⚠️  Make sure backend is running: npm start\n');
  
  testRevenueEndpoint();
} 