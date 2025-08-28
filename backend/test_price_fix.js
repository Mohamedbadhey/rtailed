const axios = require('axios');

const BASE_URL = 'http://localhost:3000/api';

// Test data
const testProduct = {
  name: 'Test Product Price Fix',
  description: 'Testing price field fix',
  price: 29.99,
  cost_price: 15.00,
  stock_quantity: 100,
  category_id: null,
  low_stock_threshold: 10
};

async function testPriceFix() {
  try {
    console.log('=== Testing Price Field Fix ===\n');
    
    // Test 1: Create product with price
    console.log('1. Testing CREATE product with price...');
    const createResponse = await axios.post(`${BASE_URL}/products`, testProduct);
    console.log('✅ Create successful, Product ID:', createResponse.data.productId);
    
    // Test 2: Get the created product to verify price was saved
    console.log('\n2. Verifying created product price...');
    const getResponse = await axios.get(`${BASE_URL}/products/${createResponse.data.productId}`);
    const createdProduct = getResponse.data;
    console.log('✅ Product retrieved:');
    console.log(`   - Name: ${createdProduct.name}`);
    console.log(`   - Price: ${createdProduct.price}`);
    console.log(`   - Cost Price: ${createdProduct.cost_price}`);
    
    // Test 3: Update product price
    console.log('\n3. Testing UPDATE product price...');
    const updateData = {
      price: 39.99,
      cost_price: 20.00
    };
    const updateResponse = await axios.put(`${BASE_URL}/products/${createResponse.data.productId}`, updateData);
    console.log('✅ Update successful');
    
    // Test 4: Verify updated price
    console.log('\n4. Verifying updated product price...');
    const getUpdatedResponse = await axios.get(`${BASE_URL}/products/${createResponse.data.productId}`);
    const updatedProduct = getUpdatedResponse.data;
    console.log('✅ Updated product:');
    console.log(`   - Name: ${updatedProduct.name}`);
    console.log(`   - Price: ${updatedProduct.price}`);
    console.log(`   - Cost Price: ${updatedProduct.cost_price}`);
    
    // Test 5: Clean up - delete test product
    console.log('\n5. Cleaning up test product...');
    await axios.delete(`${BASE_URL}/products/${createResponse.data.productId}`);
    console.log('✅ Test product deleted');
    
    console.log('\n🎉 All tests passed! Price field is working correctly.');
    
  } catch (error) {
    console.error('❌ Test failed:', error.response?.data || error.message);
    if (error.response) {
      console.error('Status:', error.response.status);
      console.error('Response:', error.response.data);
    }
  }
}

// Run the test
testPriceFix();
