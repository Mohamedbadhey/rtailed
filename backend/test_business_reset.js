// Test script for business reset verification
// Usage: node test_business_reset.js

const http = require('http');

const BASE_URL = 'https://rtailed-production.up.railway.app';
const BUSINESS_ID = 1; // Change this to test business ID
const SUPERADMIN_TOKEN = 'YOUR_TOKEN_HERE'; // Replace with actual token

async function testBusinessReset() {
  console.log('🧪 Testing Business Reset...');
  
  try {
    // Get initial counts
    console.log('📊 Getting initial data counts...');
    const initialCounts = await makeRequest('GET', `/api/admin/business-data-counts/${BUSINESS_ID}`);
    
    if (initialCounts.statusCode === 200) {
      console.log('✅ Initial counts:', initialCounts.data.data_counts);
    }
    
    // Perform reset
    console.log('🗑️ Performing business reset...');
    const resetResult = await makeRequest('POST', '/api/admin/reset-business-data', {
      businessId: BUSINESS_ID
    });
    
    if (resetResult.statusCode === 200) {
      console.log('✅ Reset completed:', resetResult.data.deleted_counts);
    }
    
    // Get final counts
    console.log('📊 Getting final data counts...');
    const finalCounts = await makeRequest('GET', `/api/admin/business-data-counts/${BUSINESS_ID}`);
    
    if (finalCounts.statusCode === 200) {
      console.log('✅ Final counts:', finalCounts.data.data_counts);
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error);
  }
}

function makeRequest(method, path, data = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'rtailed-production.up.railway.app',
      port: 443,
      path: path,
      method: method,
      headers: {
        'Authorization': `Bearer ${SUPERADMIN_TOKEN}`,
        'Content-Type': 'application/json',
      },
    };

    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          resolve({ statusCode: res.statusCode, data: JSON.parse(body) });
        } catch (e) {
          resolve({ statusCode: res.statusCode, data: body });
        }
      });
    });

    req.on('error', reject);
    if (data) req.write(JSON.stringify(data));
    req.end();
  });
}

if (SUPERADMIN_TOKEN === 'YOUR_TOKEN_HERE') {
  console.log('❌ Please set your superadmin token');
} else {
  testBusinessReset();
}
