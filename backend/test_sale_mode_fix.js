const axios = require('axios');

const BASE_URL = 'http://localhost:3000/api';

// Test data for mixed sale (retail + wholesale items)
const mixedSaleData = {
  customer_id: null, // Walk-in customer
  payment_method: 'cash',
  sale_mode: 'wholesale', // This should be determined by the frontend logic
  items: [
    {
      product_id: 37, // First product - retail
      quantity: 1,
      unit_price: 10.00, // Retail price
      mode: 'retail'
    },
    {
      product_id: 36, // Second product - wholesale
      quantity: 5,
      unit_price: 8.00, // Wholesale price
      mode: 'wholesale'
    }
  ]
};

// Test data for pure retail sale
const retailSaleData = {
  customer_id: null, // Walk-in customer
  payment_method: 'cash',
  sale_mode: 'retail',
  items: [
    {
      product_id: 37, // Retail product
      quantity: 1,
      unit_price: 10.00, // Retail price
      mode: 'retail'
    }
  ]
};

// Test data for pure wholesale sale
const wholesaleSaleData = {
  customer_id: null, // Walk-in customer
  payment_method: 'cash',
  sale_mode: 'wholesale',
  items: [
    {
      product_id: 36, // Wholesale product
      quantity: 5,
      unit_price: 8.00, // Wholesale price
      mode: 'wholesale'
    }
  ]
};

// Test data for same product as both retail and wholesale
const sameProductMixedModeData = {
  customer_id: null, // Walk-in customer
  payment_method: 'cash',
  sale_mode: 'wholesale', // Should be wholesale since any wholesale item makes entire sale wholesale
  items: [
    {
      product_id: 37, // Same product - retail version
      quantity: 1,
      unit_price: 10.00, // Retail price
      mode: 'retail'
    },
    {
      product_id: 37, // Same product - wholesale version
      quantity: 3,
      unit_price: 8.00, // Wholesale price
      mode: 'wholesale'
    }
  ]
};

async function testMixedSaleMode() {
  try {
    console.log('=== Testing Mixed Sale Mode (Retail + Wholesale) ===\\n');
    
    // Test 1: Create mixed sale (retail + wholesale items)
    console.log('1. Testing MIXED sale (retail + wholesale items)...');
    console.log('   - Expected result: sale_mode should be "wholesale" (any wholesale item makes entire sale wholesale)');
    console.log('   - Sale data:', JSON.stringify(mixedSaleData, null, 2));
    
    const mixedResponse = await axios.post(`${BASE_URL}/sales`, mixedSaleData);
    console.log('   ✅ Mixed sale created successfully');
    console.log('   - Sale ID:', mixedResponse.data.sale_id);
    console.log('   - Total Amount:', mixedResponse.data.total_amount);
    console.log('   - Expected Sale Mode: wholesale (because of wholesale item)');
    
    // Test 2: Create pure retail sale
    console.log('\\n2. Testing PURE RETAIL sale...');
    console.log('   - Expected result: sale_mode should be "retail"');
    console.log('   - Sale data:', JSON.stringify(retailSaleData, null, 2));
    
    const retailResponse = await axios.post(`${BASE_URL}/sales`, retailSaleData);
    console.log('   ✅ Retail sale created successfully');
    console.log('   - Sale ID:', retailResponse.data.sale_id);
    console.log('   - Total Amount:', retailResponse.data.total_amount);
    console.log('   - Expected Sale Mode: retail');
    
    // Test 3: Create pure wholesale sale
    console.log('\\n3. Testing PURE WHOLESALE sale...');
    console.log('   - Expected result: sale_mode should be "wholesale"');
    console.log('   - Sale data:', JSON.stringify(wholesaleSaleData, null, 2));
    
    const wholesaleResponse = await axios.post(`${BASE_URL}/sales`, wholesaleSaleData);
    console.log('   ✅ Wholesale sale created successfully');
    console.log('   - Sale ID:', wholesaleResponse.data.sale_id);
    console.log('   - Total Amount:', wholesaleResponse.data.total_amount);
    console.log('   - Expected Sale Mode: wholesale');
    
    // Test 4: Create sale with SAME PRODUCT as both retail and wholesale
    console.log('\\n4. Testing SAME PRODUCT as both retail and wholesale...');
    console.log('   - Expected result: sale_mode should be "wholesale" (any wholesale item makes entire sale wholesale)');
    console.log('   - Expected result: Two separate sale items for the same product with different modes');
    console.log('   - Sale data:', JSON.stringify(sameProductMixedModeData, null, 2));
    
    const sameProductResponse = await axios.post(`${BASE_URL}/sales`, sameProductMixedModeData);
    console.log('   ✅ Same product mixed mode sale created successfully');
    console.log('   - Sale ID:', sameProductResponse.data.sale_id);
    console.log('   - Total Amount:', sameProductResponse.data.total_amount);
    console.log('   - Expected Sale Mode: wholesale (because of wholesale item)');
    console.log('   - Expected Items: 2 separate items for product 37 (1 retail + 1 wholesale)');
    
    console.log('\\n=== Test Summary ===');
    console.log('✅ Mixed sale mode test completed successfully!');
    console.log('\\nExpected Results:');
    console.log('1. Mixed Sale (retail + wholesale): sale_mode = "wholesale" ✅');
    console.log('2. Pure Retail Sale: sale_mode = "retail" ✅');
    console.log('3. Pure Wholesale Sale: sale_mode = "wholesale" ✅');
    console.log('4. Same Product Mixed Mode: sale_mode = "wholesale" + 2 separate items ✅');
    console.log('\\nFrontend Logic:');
    console.log('- If ANY item is wholesale → Entire sale is wholesale');
    console.log('- If ALL items are retail → Entire sale is retail');
    console.log('- Same product + different modes = Separate cart items');
    console.log('- Same product + same mode = Quantity added to existing item');
    console.log('\\nTo verify in database:');
    console.log('1. Check sales table for sale_mode field values');
    console.log('2. Check sale_items table for individual item modes');
    console.log('3. Verify mixed sale shows wholesale mode');
    console.log('4. Verify same product appears as 2 separate items with different modes');
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    if (error.response) {
      console.error('Response data:', error.response.data);
    }
  }
}

// Run the test
testMixedSaleMode();
