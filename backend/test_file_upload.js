const axios = require('axios');
const fs = require('fs');
const FormData = require('form-data');
const path = require('path');

async function testFileUpload() {
  try {
    console.log('Testing file upload functionality...');
    
    // First, login to get a token
    console.log('1. Logging in...');
    const loginResponse = await axios.post('http://localhost:3000/api/auth/login', {
      username: 'superadmin',
      password: 'admin123'
    });
    
    const token = loginResponse.data.token;
    console.log('Login successful, token received');
    
    // Create a test image file
    console.log('2. Creating test image...');
    const testImagePath = path.join(__dirname, 'test_image.jpg');
    
    // Create a simple test image (1x1 pixel JPEG)
    const testImageData = Buffer.from([
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
      0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
      0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
      0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
      0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
      0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
      0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x01,
      0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
      0xFF, 0xC4, 0x00, 0x14, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0xFF, 0xC4,
      0x00, 0x14, 0x10, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xDA, 0x00, 0x0C,
      0x03, 0x01, 0x00, 0x02, 0x11, 0x03, 0x11, 0x00, 0x3F, 0x00, 0x8A, 0x00,
      0x00, 0xFF, 0xD9
    ]);
    
    fs.writeFileSync(testImagePath, testImageData);
    console.log('Test image created at:', testImagePath);
    
    // Test system branding upload
    console.log('3. Testing system branding upload...');
    const formData = new FormData();
    formData.append('file', fs.createReadStream(testImagePath));
    formData.append('type', 'logo');
    
    const uploadResponse = await axios.post('http://localhost:3000/api/branding/system/upload', formData, {
      headers: {
        'Authorization': `Bearer ${token}`,
        ...formData.getHeaders()
      }
    });
    
    console.log('Upload response:', uploadResponse.data);
    
    // Check if file was created
    console.log('4. Checking if file was created...');
    const uploadsDir = path.join(__dirname, 'uploads/branding');
    if (fs.existsSync(uploadsDir)) {
      const files = fs.readdirSync(uploadsDir);
      console.log('Files in uploads/branding:', files);
    } else {
      console.log('uploads/branding directory does not exist');
    }
    
    // Clean up test file
    fs.unlinkSync(testImagePath);
    console.log('Test completed successfully!');
    
  } catch (error) {
    console.error('Error testing file upload:', error.response?.data || error.message);
    if (error.response) {
      console.error('Response status:', error.response.status);
      console.error('Response headers:', error.response.headers);
    }
  }
}

// Check if backend is running
async function checkBackend() {
  try {
    const response = await axios.get('http://localhost:3000/api/auth/login');
    console.log('Backend is running');
    return true;
  } catch (error) {
    console.log('Backend is not running or not accessible');
    return false;
  }
}

async function main() {
  const isBackendRunning = await checkBackend();
  if (isBackendRunning) {
    await testFileUpload();
  } else {
    console.log('Please start the backend first: npm start');
  }
}

main(); 