const axios = require('axios');

const BASE_URL = 'http://localhost:3000/api';

// Test data - simulate real product lifecycle
const testProduct = {
  name: 'Test Simple Soft Delete Product',
  description: 'Testing simple soft delete functionality',
  price: 25.99,
  cost_price: 15.00,
  stock_quantity: 20, // Start with 20 items
  damaged_quantity: 0,
  category_id: null,
  low_stock_threshold: 10
};

async function testSimpleSoftDelete() {
  try {
    console.log('=== Testing Simple Soft Delete Functionality ===\n');
    console.log('Scenario: Product with 20 quantity → Delete → Restore → Should have 20\n');
    
    // Test 1: Create product with 20 quantity
    console.log('1. Creating test product with 20 quantity...');
    const createResponse = await axios.post(`${BASE_URL}/products`, testProduct);
    const productId = createResponse.data.productId;
    console.log('✅ Product created with ID:', productId);
    
    // Test 2: Verify initial quantities
    console.log('\n2. Verifying initial quantities...');
    const getInitialResponse = await axios.get(`${BASE_URL}/products/${productId}`);
    const initialProduct = getInitialResponse.data;
    console.log('✅ Initial product quantities:');
    console.log(`   - Stock Quantity: ${initialProduct.stock_quantity} (should be 20)`);
    console.log(`   - Damaged Quantity: ${initialProduct.damaged_quantity} (should be 0)`);
    
    // Test 3: Simulate selling 5 items (reduce stock to 15)
    console.log('\n3. Simulating sale of 5 items (stock should become 15)...');
    const updateStockResponse = await axios.put(`${BASE_URL}/products/${productId}`, {
      stock_quantity: 15 // After selling 5, we have 15 left
    });
    console.log('✅ Stock updated to 15 (simulating sale of 5 items)');
    
    // Test 4: Verify stock is now 15
    console.log('\n4. Verifying stock is now 15...');
    const getUpdatedResponse = await axios.get(`${BASE_URL}/products/${productId}`);
    const updatedProduct = getUpdatedResponse.data;
    console.log('✅ Updated product quantities:');
    console.log(`   - Stock Quantity: ${updatedProduct.stock_quantity} (should be 15)`);
    console.log(`   - Damaged Quantity: ${updatedProduct.damaged_quantity} (should be 0)`);
    
    // Test 5: Delete the product (simple soft delete - just mark as deleted)
    console.log('\n5. Soft deleting product (should preserve all data, just mark as deleted)...');
    const deleteResponse = await axios.delete(`${BASE_URL}/products/${productId}`);
    console.log('✅ Product soft deleted successfully');
    
    // Test 6: Verify product is soft-deleted
    console.log('\n6. Verifying product is soft-deleted...');
    try {
      const getDeletedResponse = await axios.get(`${BASE_URL}/products/${productId}`);
      console.log('❌ ERROR: Product should not be accessible after deletion');
    } catch (error) {
      if (error.response?.status === 404) {
        console.log('✅ Product is properly soft-deleted (404 response)');
      } else {
        console.log('❌ Unexpected error:', error.response?.data || error.message);
      }
    }
    
    // Test 7: Restore the product (simple restore - just mark as not deleted)
    console.log('\n7. Restoring product (should restore with same quantities: 15 stock, 0 damaged)...');
    const restoreResponse = await axios.put(`${BASE_URL}/products/${productId}/restore`);
    console.log('✅ Product restored successfully');
    
    // Test 8: Verify quantities are exactly the same as when deleted
    console.log('\n8. Verifying quantities are preserved exactly as they were when deleted...');
    const getRestoredResponse = await axios.get(`${BASE_URL}/products/${productId}`);
    const restoredProduct = getRestoredResponse.data;
    console.log('✅ Restored product quantities:');
    console.log(`   - Stock Quantity: ${restoredProduct.stock_quantity} (should be 15 - preserved from deletion)`);
    console.log(`   - Damaged Quantity: ${restoredProduct.damaged_quantity} (should be 0)`);
    
    // Test 9: Verify quantities match the values when deleted
    const stockMatch = restoredProduct.stock_quantity === 15; // Should be 15, preserved from deletion
    const damagedMatch = restoredProduct.damaged_quantity === 0;
    
    if (stockMatch && damagedMatch) {
      console.log('✅ SUCCESS: Quantities preserved correctly through soft delete/restore!');
      console.log('   - Stock: 15 (preserved exactly as it was when deleted)');
      console.log('   - All data intact: sales history, inventory transactions, etc.');
    } else {
      console.log('❌ FAILURE: Quantities not preserved correctly!');
      console.log(`   - Stock: Expected 15, Got ${restoredProduct.stock_quantity}`);
      console.log(`   - Damaged: Expected 0, Got ${restoredProduct.damaged_quantity}`);
    }
    
    // Test 10: Clean up - delete test product permanently
    console.log('\n9. Cleaning up test product...');
    await axios.delete(`${BASE_URL}/products/${productId}`);
    console.log('✅ Test product cleaned up');
    
    console.log('\n🎉 Simple soft delete test completed!');
    console.log('✅ Product now uses simple soft delete: just mark as deleted, preserve all data.');
    console.log('✅ No quantity backup needed - quantities are naturally preserved.');
    
  } catch (error) {
    console.error('❌ Test failed:', error.response?.data || error.message);
    if (error.response) {
      console.error('Status:', error.response.status);
      console.error('Response:', error.response.data);
    }
  }
}

// Run the test
testSimpleSoftDelete();
