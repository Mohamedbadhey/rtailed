const http = require('http');

// Test billing data to ensure no null comparison errors
async function testBillingData() {
  console.log('🧪 Testing Billing Data Format...\n');
  
  try {
    // Test businesses endpoint to get billing data
    const businessesResponse = await makeRequest('/api/businesses');
    const businesses = businessesResponse.businesses || businessesResponse;
    
    console.log(`📊 Found ${businesses.length} businesses to test billing data\n`);
    
    for (const business of businesses) {
      console.log(`🏢 Testing Business: ${business.name} (ID: ${business.id})`);
      
      // Test monthly bills
      try {
        const billsResponse = await makeRequest(`/api/businesses/${business.id}/monthly-bills`);
        const bills = billsResponse.bills || billsResponse;
        
        console.log(`   Monthly Bills: ${bills.length}`);
        
        for (const bill of bills) {
          console.log(`   - Bill ID: ${bill.id}`);
          console.log(`   - Status: ${bill.status}`);
          console.log(`   - Amount: ${bill.amount} (type: ${typeof bill.amount})`);
          console.log(`   - User Overage Fee: ${bill.user_overage_fee} (type: ${typeof bill.user_overage_fee})`);
          console.log(`   - Product Overage Fee: ${bill.product_overage_fee} (type: ${typeof bill.product_overage_fee})`);
          
          // Test safe conversion
          const userOverage = safeToDouble(bill.user_overage_fee);
          const productOverage = safeToDouble(bill.product_overage_fee);
          
          console.log(`   - Safe User Overage: ${userOverage} (type: ${typeof userOverage})`);
          console.log(`   - Safe Product Overage: ${productOverage} (type: ${typeof productOverage})`);
          
          // Test comparison
          const userOverageValid = userOverage > 0;
          const productOverageValid = productOverage > 0;
          
          console.log(`   - User Overage > 0: ${userOverageValid}`);
          console.log(`   - Product Overage > 0: ${productOverageValid}`);
          console.log('');
        }
      } catch (error) {
        console.log(`   ❌ Error testing bills: ${error.message}`);
      }
      
      // Test payments
      try {
        const paymentsResponse = await makeRequest(`/api/businesses/${business.id}/payments`);
        const payments = paymentsResponse.payments || paymentsResponse;
        
        console.log(`   Payments: ${payments.length}`);
        
        for (const payment of payments) {
          console.log(`   - Payment ID: ${payment.id}`);
          console.log(`   - Amount: ${payment.amount} (type: ${typeof payment.amount})`);
          console.log(`   - Status: ${payment.status}`);
          
          // Test safe conversion
          const amount = safeToDouble(payment.amount);
          console.log(`   - Safe Amount: ${amount} (type: ${typeof amount})`);
          console.log('');
        }
      } catch (error) {
        console.log(`   ❌ Error testing payments: ${error.message}`);
      }
      
      console.log('---');
    }
    
    console.log('✅ Billing data test completed!');
    console.log('All numeric values should be properly converted to numbers.');
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

// Safe conversion function (same as Flutter)
function safeToDouble(value) {
  if (value === null || value === undefined) return 0.0;
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    const parsed = parseFloat(value);
    return isNaN(parsed) ? 0.0 : parsed;
  }
  return 0.0;
}

function makeRequest(path) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: path,
      method: 'GET',
      headers: {
        'Authorization': 'Bearer your_superadmin_token_here',
        'Content-Type': 'application/json'
      }
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (error) {
          reject(new Error(`Failed to parse response: ${error.message}`));
        }
      });
    });

    req.on('error', (error) => reject(new Error(`Request failed: ${error.message}`)));
    req.end();
  });
}

if (require.main === module) {
  console.log('🚀 Starting Billing Data Test...\n');
  console.log('⚠️  Make sure to:');
  console.log('   1. Start the backend server (npm start)');
  console.log('   2. Update the token in the script\n');
  
  testBillingData();
} 