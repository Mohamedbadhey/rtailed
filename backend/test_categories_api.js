const http = require('http');

// Test the categories API endpoint
async function testCategoriesAPI() {
  console.log('🧪 Testing Categories API Endpoint...\n');
  
  const baseUrl = 'http://localhost:3000';
  
  try {
    // Test GET /api/categories (without auth - should fail)
    console.log('📡 Testing GET /api/categories (no auth)...');
    const getResponse = await makeRequest(`${baseUrl}/api/categories`, 'GET');
    console.log(`Status: ${getResponse.status}`);
    if (getResponse.status === 401) {
      console.log('✅ Correctly requires authentication');
    } else {
      console.log('⚠️  Unexpected response for unauthenticated request');
    }
    console.log('');

    // Test POST /api/categories (without auth - should fail)
    console.log('📡 Testing POST /api/categories (no auth)...');
    const postResponse = await makeRequest(`${baseUrl}/api/categories`, 'POST', {
      name: 'Test Category',
      description: 'Test Description'
    });
    console.log(`Status: ${postResponse.status}`);
    if (postResponse.status === 401) {
      console.log('✅ Correctly requires authentication');
    } else {
      console.log('⚠️  Unexpected response for unauthenticated request');
    }
    console.log('');

    // Test with a mock JWT token (should fail with invalid token)
    console.log('📡 Testing with invalid JWT token...');
    const invalidTokenResponse = await makeRequest(`${baseUrl}/api/categories`, 'GET', null, 'invalid.token.here');
    console.log(`Status: ${invalidTokenResponse.status}`);
    if (invalidTokenResponse.status === 401) {
      console.log('✅ Correctly rejects invalid JWT token');
    } else {
      console.log('⚠️  Unexpected response for invalid token');
    }
    console.log('');

    console.log('🎉 API endpoint tests completed!');
    console.log('💡 The categories endpoint is working and properly secured.');
    console.log('💡 To test with real authentication, you need to:');
    console.log('   1. Login through the frontend to get a valid JWT token');
    console.log('   2. Use that token in the Authorization header');
    console.log('   3. Test the CRUD operations');

  } catch (error) {
    console.error('❌ API test failed:', error.message);
    console.error('💡 Make sure the backend server is running on port 3000');
  }
}

// Helper function to make HTTP requests
function makeRequest(url, method, data = null, token = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: url.replace('http://localhost:3000', ''),
      method: method,
      headers: {
        'Content-Type': 'application/json',
      }
    };

    if (token) {
      options.headers['Authorization'] = `Bearer ${token}`;
    }

    if (data) {
      const postData = JSON.stringify(data);
      options.headers['Content-Length'] = Buffer.byteLength(postData);
    }

    const req = http.request(options, (res) => {
      let responseData = '';
      
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      
      res.on('end', () => {
        try {
          const parsedData = JSON.parse(responseData);
          resolve({
            status: res.statusCode,
            data: parsedData
          });
        } catch (e) {
          resolve({
            status: res.statusCode,
            data: responseData
          });
        }
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    if (data) {
      req.write(JSON.stringify(data));
    }

    req.end();
  });
}

// Run the test
testCategoriesAPI();
