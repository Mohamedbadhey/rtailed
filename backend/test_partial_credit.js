const axios = require('axios');

const BASE_URL = 'http://localhost:3000'; // Adjust if your backend runs on different port

async function testPartialCredit() {
  try {
    console.log('🧪 Testing Partial Credit Functionality...\n');

    // Test 1: Create a partial credit sale
    console.log('1️⃣ Creating partial credit sale...');
    const saleData = {
      customer_id: 1, // Assuming customer ID 1 exists
      items: [
        {
          product_id: 1, // Assuming product ID 1 exists
          quantity: 2,
          unit_price: 100.00,
          mode: 'retail'
        }
      ],
      payment_method: 'partial_credit',
      partial_payment_amount: 150.00,
      remaining_credit_amount: 50.00,
      sale_mode: 'retail',
      customer_phone: '1234567890'
    };

    const saleResponse = await axios.post(`${BASE_URL}/api/sales`, saleData, {
      headers: {
        'Authorization': 'Bearer YOUR_TOKEN_HERE', // Replace with actual token
        'Content-Type': 'application/json'
      }
    });

    console.log('✅ Sale created successfully:', saleResponse.data);
    const saleId = saleResponse.data.sale_id;

    // Test 2: Record partial credit payment
    console.log('\n2️⃣ Recording partial credit payment...');
    const paymentData = {
      amount: 25.00,
      payment_method: 'evc'
    };

    const paymentResponse = await axios.post(`${BASE_URL}/api/sales/${saleId}/partial-credit-payment`, paymentData, {
      headers: {
        'Authorization': 'Bearer YOUR_TOKEN_HERE', // Replace with actual token
        'Content-Type': 'application/json'
      }
    });

    console.log('✅ Payment recorded successfully:', paymentResponse.data);

    // Test 3: Get sale details
    console.log('\n3️⃣ Getting sale details...');
    const detailsResponse = await axios.get(`${BASE_URL}/api/sales/${saleId}`, {
      headers: {
        'Authorization': 'Bearer YOUR_TOKEN_HERE' // Replace with actual token
      }
    });

    console.log('✅ Sale details retrieved:', detailsResponse.data);

    console.log('\n🎉 All tests passed! Partial credit system is working correctly.');

  } catch (error) {
    console.error('❌ Test failed:', error.response?.data || error.message);
  }
}

// Run the test
testPartialCredit();
