const axios = require('axios');

// Test configuration
const BASE_URL = process.env.BASE_URL || 'https://api.kismayoict.com';
const TEST_EMAIL = process.env.TEST_EMAIL || 's@gmail.com';
const TEST_PASSWORD = process.env.TEST_PASSWORD || '123456';

async function testExpensesEndpoints() {
  console.log('🧪 Testing Expenses Endpoints...\n');

  let token;
  let createdExpenseId;

  try {
    // 1) Login
    console.log('1️⃣ Logging in...');
    const loginRes = await axios.post(`${BASE_URL}/api/auth/login`, {
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
    });
    token = loginRes.data.token;
    const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
    console.log('✅ Login OK as', loginRes.data.user?.username, `(${loginRes.data.user?.role})`);

    // 2) List expenses (unfiltered)
    console.log('\n2️⃣ Listing expenses...');
    const listRes = await axios.get(`${BASE_URL}/api/admin/accounting/expenses`, { headers });
    console.log(`✅ Got ${Array.isArray(listRes.data) ? listRes.data.length : 0} expenses`);

    // 3) Create an expense (and then clean it up)
    console.log('\n3️⃣ Creating a test expense...');
    const today = new Date().toISOString().slice(0, 10);
    const createBody = {
      date: today,
      amount: 1.11,
      category: 'TEST-AUTOMATION',
      vendor_id: null,
      notes: 'TEST-DELETE-ME (automated)'
    };
    const createRes = await axios.post(`${BASE_URL}/api/admin/accounting/expenses`, createBody, { headers });
    console.log('✅ Create response:', createRes.data?.message || 'OK');

    // Refetch list to find the created expense id (latest by date desc)
    const afterCreate = await axios.get(`${BASE_URL}/api/admin/accounting/expenses?start_date=${today}&end_date=${today}&category=TEST-AUTOMATION`, { headers });
    const created = Array.isArray(afterCreate.data) ? afterCreate.data.find(e => e.notes?.includes('TEST-DELETE-ME')) : null;
    if (!created) throw new Error('Created expense not found');
    createdExpenseId = created.id;
    console.log('✅ Created expense id:', createdExpenseId);

    // 4) Update the expense
    console.log('\n4️⃣ Updating the test expense...');
    await axios.put(`${BASE_URL}/api/admin/accounting/expenses/${createdExpenseId}`, {
      ...createBody,
      amount: 2.22,
      notes: 'TEST-DELETE-ME (updated)',
    }, { headers });
    console.log('✅ Update OK');

    // 5) Summary endpoint
    console.log('\n5️⃣ Fetching expenses summary (today)...');
    const summaryRes = await axios.get(`${BASE_URL}/api/admin/accounting/expenses/summary?start_date=${today}&end_date=${today}`, { headers });
    console.log('✅ Summary keys:', Object.keys(summaryRes.data || {}));

    // 6) Delete the created expense
    console.log('\n6️⃣ Deleting the test expense...');
    await axios.delete(`${BASE_URL}/api/admin/accounting/expenses/${createdExpenseId}`, { headers });
    console.log('✅ Delete OK');

    console.log('\n🎉 Expenses endpoints test completed successfully!');
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    if (error.response) {
      console.error('   Status:', error.response.status);
      console.error('   Data:', error.response.data);
    }
    // Try to cleanup if we created an expense
    if (token && createdExpenseId) {
      try {
        const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
        await axios.delete(`${BASE_URL}/api/admin/accounting/expenses/${createdExpenseId}`, { headers });
        console.log('🧹 Cleaned up test expense');
      } catch (_) {}
    }
    process.exit(1);
  }
}

if (require.main === module) {
  testExpensesEndpoints();
}
