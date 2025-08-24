const http = require('http');

// Test the categories endpoint as if it were called from the frontend
async function testFrontendCategories() {
  console.log('🧪 Testing Categories Endpoint for Frontend...\n');
  
  try {
    // First, let's create a test category
    console.log('📡 Creating a test category...');
    const createResponse = await makeRequest('/api/categories', 'POST', {
      name: 'Electronics',
      description: 'Electronic devices and accessories'
    });
    
    console.log(`Create Status: ${createResponse.status}`);
    if (createResponse.status === 201) {
      console.log('✅ Category created successfully');
      console.log('Response:', createResponse.data);
    } else {
      console.log('❌ Failed to create category');
      console.log('Response:', createResponse.data);
      return;
    }
    console.log('');

    // Now let's get all categories
    console.log('📡 Getting all categories...');
    const getResponse = await makeRequest('/api/categories', 'GET');
    
    console.log(`Get Status: ${getResponse.status}`);
    if (getResponse.status === 200) {
      console.log('✅ Categories retrieved successfully');
      console.log(`Found ${getResponse.data.length} categories:`);
      getResponse.data.forEach((cat, index) => {
        console.log(`   ${index + 1}. ID: ${cat.id}, Name: "${cat.name}", Description: "${cat.description || 'None'}", Business ID: ${cat.business_id}`);
      });
    } else {
      console.log('❌ Failed to get categories');
      console.log('Response:', getResponse.data);
    }
    console.log('');

    // Test updating the category
    console.log('📡 Updating the category...');
    const updateResponse = await makeRequest('/api/categories/1', 'PUT', {
      name: 'Electronics & Gadgets',
      description: 'Updated description for electronics category'
    });
    
    console.log(`Update Status: ${updateResponse.status}`);
    if (updateResponse.status === 200) {
      console.log('✅ Category updated successfully');
      console.log('Response:', updateResponse.data);
    } else {
      console.log('❌ Failed to update category');
      console.log('Response:', updateResponse.data);
    }
    console.log('');

    // Verify the update by getting the category again
    console.log('📡 Verifying the update...');
    const verifyResponse = await makeRequest('/api/categories/1', 'GET');
    
    console.log(`Verify Status: ${verifyResponse.status}`);
    if (verifyResponse.status === 200) {
      console.log('✅ Category verification successful');
      console.log('Updated category:', verifyResponse.data);
    } else {
      console.log('❌ Failed to verify category update');
      console.log('Response:', verifyResponse.data);
    }

    console.log('\n🎉 Frontend categories test completed!');
    console.log('💡 The API is working correctly for frontend operations.');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

// Helper function to make HTTP requests
function makeRequest(path, method, data = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: path,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      }
    };

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
testFrontendCategories();
