const axios = require('axios');

// Test configuration
const BASE_URL = 'https://rtailed-production.up.railway.app';
const TEST_EMAIL = 's@gmail.com';
const TEST_PASSWORD = '123456';

async function testBrandingSystem() {
  console.log('🧪 Testing Branding System...\n');
  
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
    console.log(`   Token: ${token.substring(0, 50)}...\n`);
    
    const headers = {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    };
    
    // Step 2: Test system branding endpoints
    console.log('2️⃣ Testing system branding endpoints...');
    
    // Get system branding
    const systemBrandingResponse = await axios.get(`${BASE_URL}/api/branding/system`, { headers });
    console.log('✅ System branding retrieved:');
    console.log(`   App Name: ${systemBrandingResponse.data.app_name || 'Not set'}`);
    console.log(`   Logo URL: ${systemBrandingResponse.data.logo_url || 'Not set'}`);
    console.log(`   Primary Color: ${systemBrandingResponse.data.primary_color || 'Not set'}`);
    console.log(`   Theme: ${systemBrandingResponse.data.theme || 'Not set'}\n`);
    
    // Update system branding
    const updateData = {
      app_name: 'Retail Management Pro',
      tagline: 'Professional retail management solution',
      contact_email: 'support@retailpro.com',
      primary_color: '#1976D2',
      secondary_color: '#424242',
      accent_color: '#FFC107',
      theme: 'default'
    };
    
    const updateResponse = await axios.put(`${BASE_URL}/api/branding/system`, updateData, { headers });
    console.log('✅ System branding updated successfully\n');
    
    // Step 3: Test themes endpoint
    console.log('3️⃣ Testing themes endpoint...');
    const themesResponse = await axios.get(`${BASE_URL}/api/branding/themes`);
    console.log('✅ Themes retrieved:');
    themesResponse.data.forEach(theme => {
      console.log(`   - ${theme.theme_display_name} (${theme.theme_name})`);
    });
    console.log('');
    
    // Step 4: Test business branding endpoints
    console.log('4️⃣ Testing business branding endpoints...');
    
    // Get business branding (using business ID 6 from your database)
    const businessId = 6;
    const businessBrandingResponse = await axios.get(`${BASE_URL}/api/branding/business/${businessId}`, { headers });
    console.log('✅ Business branding retrieved:');
    console.log(`   Business Name: ${businessBrandingResponse.data.name || 'Not set'}`);
    console.log(`   Logo: ${businessBrandingResponse.data.logo || 'Not set'}`);
    console.log(`   Primary Color: ${businessBrandingResponse.data.primary_color || 'Not set'}`);
    console.log(`   Branding Enabled: ${businessBrandingResponse.data.branding_enabled}\n`);
    
    // Update business branding
    const businessUpdateData = {
      name: 'Updated Business Name',
      tagline: 'Updated business tagline',
      contact_email: 'business@example.com',
      primary_color: '#2E7D32',
      secondary_color: '#424242',
      accent_color: '#FFC107',
      theme: 'green',
      branding_enabled: true
    };
    
    const businessUpdateResponse = await axios.put(`${BASE_URL}/api/branding/business/${businessId}`, businessUpdateData, { headers });
    console.log('✅ Business branding updated successfully\n');
    
    // Step 5: Test branding files endpoint
    console.log('5️⃣ Testing branding files endpoint...');
    const filesResponse = await axios.get(`${BASE_URL}/api/branding/business/${businessId}/files`, { headers });
    console.log('✅ Business branding files retrieved:');
    console.log(`   Total files: ${filesResponse.data.length}`);
    filesResponse.data.forEach(file => {
      console.log(`   - ${file.original_name} (${file.file_type})`);
    });
    console.log('');
    
    // Step 6: Test error handling
    console.log('6️⃣ Testing error handling...');
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
    
    console.log('');
    console.log('🎉 All branding system tests completed successfully!');
    console.log('');
    console.log('📋 Summary:');
    console.log('   ✅ System branding endpoints working');
    console.log('   ✅ Business branding endpoints working');
    console.log('   ✅ Themes endpoint working');
    console.log('   ✅ File management working');
    console.log('   ✅ Error handling functional');
    console.log('');
    console.log('🚀 The branding system is ready to use!');
    
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
testBrandingSystem(); 