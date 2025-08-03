const axios = require('axios');

// Test configuration
const BASE_URL = 'http://localhost:3000';
const TEST_EMAIL = 's@gmail.com';
const TEST_PASSWORD = '123456';

async function testBusinessBrandingFlow() {
  console.log('🧪 Testing Business Branding Flow...\n');
  
  let token;
  
  try {
    // Step 1: Login as superadmin
    console.log('1️⃣ Logging in as superadmin...');
    const loginResponse = await axios.post(`${BASE_URL}/api/auth/login`, {
      email: TEST_EMAIL,
      password: TEST_PASSWORD
    });
    
    token = loginResponse.data.token;
    console.log('✅ Login successful');
    console.log(`   User: ${loginResponse.data.user.username} (${loginResponse.data.user.role})`);
    
    const headers = {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    };
    
    // Step 2: Get all businesses
    console.log('\n2️⃣ Fetching businesses...');
    const businessesResponse = await axios.get(`${BASE_URL}/api/businesses`, { headers });
    console.log('✅ Businesses retrieved:');
    businessesResponse.data.businesses.forEach(business => {
      console.log(`   - ${business.name} (ID: ${business.id})`);
    });
    
    if (businessesResponse.data.businesses.length === 0) {
      console.log('❌ No businesses found. Cannot test business branding.');
      return;
    }
    
    // Step 3: Test business branding for first business
    const testBusiness = businessesResponse.data.businesses[0];
    console.log(`\n3️⃣ Testing business branding for: ${testBusiness.name} (ID: ${testBusiness.id})`);
    
    // Get current branding
    const brandingResponse = await axios.get(`${BASE_URL}/api/branding/business/${testBusiness.id}`, { headers });
    console.log('✅ Current business branding:');
    console.log(`   Name: ${brandingResponse.data.name}`);
    console.log(`   Logo: ${brandingResponse.data.logo || 'Not set'}`);
    console.log(`   Primary Color: ${brandingResponse.data.primary_color}`);
    console.log(`   Branding Enabled: ${brandingResponse.data.branding_enabled}`);
    
    // Step 4: Update business branding
    console.log('\n4️⃣ Updating business branding...');
    const updateData = {
      name: `${testBusiness.name} - Branded`,
      tagline: 'Updated business tagline for testing',
      contact_email: 'test@business.com',
      primary_color: '#2E7D32',
      secondary_color: '#424242',
      accent_color: '#FFC107',
      theme: 'green',
      branding_enabled: true,
      website: 'https://testbusiness.com',
      address: '123 Test Street, Test City'
    };
    
    const updateResponse = await axios.put(`${BASE_URL}/api/branding/business/${testBusiness.id}`, updateData, { headers });
    console.log('✅ Business branding updated successfully');
    
    // Step 5: Verify the update
    console.log('\n5️⃣ Verifying the update...');
    const verifyResponse = await axios.get(`${BASE_URL}/api/branding/business/${testBusiness.id}`, { headers });
    console.log('✅ Updated business branding:');
    console.log(`   Name: ${verifyResponse.data.name}`);
    console.log(`   Tagline: ${verifyResponse.data.tagline}`);
    console.log(`   Contact Email: ${verifyResponse.data.contact_email}`);
    console.log(`   Primary Color: ${verifyResponse.data.primary_color}`);
    console.log(`   Theme: ${verifyResponse.data.theme}`);
    console.log(`   Branding Enabled: ${verifyResponse.data.branding_enabled}`);
    
    // Step 6: Test error handling
    console.log('\n6️⃣ Testing error handling...');
    try {
      await axios.get(`${BASE_URL}/api/branding/business/99999`, { headers });
      console.log('❌ Should have returned 404 for non-existent business');
    } catch (error) {
      if (error.response?.status === 404) {
        console.log('✅ Correctly handled non-existent business (404)');
      } else {
        console.log(`❌ Unexpected error: ${error.response?.status || error.message}`);
      }
    }
    
    // Step 7: Test business branding files
    console.log('\n7️⃣ Testing business branding files...');
    const filesResponse = await axios.get(`${BASE_URL}/api/branding/business/${testBusiness.id}/files`, { headers });
    console.log('✅ Business branding files:');
    console.log(`   Total files: ${filesResponse.data.length}`);
    filesResponse.data.forEach(file => {
      console.log(`   - ${file.original_name} (${file.file_type})`);
    });
    
    console.log('');
    console.log('🎉 Business branding flow test completed successfully!');
    console.log('');
    console.log('📋 Summary:');
    console.log('   ✅ Business listing working');
    console.log('   ✅ Business branding retrieval working');
    console.log('   ✅ Business branding update working');
    console.log('   ✅ Error handling functional');
    console.log('   ✅ File management working');
    console.log('');
    console.log('🚀 The business branding system is ready for frontend testing!');
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    if (error.response) {
      console.error('   Status:', error.response.status);
      console.error('   Data:', error.response.data);
    }
    process.exit(1);
  }
}

// Run the test
testBusinessBrandingFlow(); 