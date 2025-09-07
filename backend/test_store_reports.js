const axios = require('axios');

// Test the store inventory reports endpoint
async function testStoreReports() {
  try {
    console.log('🧪 Testing Store Inventory Reports API...');
    
    // Test with sample data
    const storeId = 1;
    const businessId = 16;
    const startDate = '2025-01-01';
    const endDate = '2025-01-31';
    
    const url = `https://rtailed-production.up.railway.app/api/store-inventory/${storeId}/reports/${businessId}?start_date=${startDate}&end_date=${endDate}`;
    
    console.log('📡 Making request to:', url);
    
    const response = await axios.get(url, {
      headers: {
        'Authorization': 'Bearer YOUR_TOKEN_HERE', // You'll need to replace this with a valid token
        'Content-Type': 'application/json'
      }
    });
    
    console.log('✅ Response Status:', response.status);
    console.log('📊 Response Data:', JSON.stringify(response.data, null, 2));
    
  } catch (error) {
    console.error('❌ Error testing store reports:', error.response?.data || error.message);
    if (error.response) {
      console.error('Status:', error.response.status);
      console.error('Headers:', error.response.headers);
    }
  }
}

// Run the test
testStoreReports();
