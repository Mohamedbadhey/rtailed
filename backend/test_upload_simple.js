const http = require('http');
const fs = require('fs');
const path = require('path');

// Simple test to check if the upload endpoint is accessible
function testUploadEndpoint() {
  console.log('Testing upload endpoint accessibility...');
  
  const options = {
    hostname: 'localhost',
    port: 3000,
    path: '/api/branding/system/upload',
    method: 'POST',
    headers: {
      'Content-Type': 'multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW'
    }
  };

  const req = http.request(options, (res) => {
    console.log(`Status: ${res.statusCode}`);
    console.log(`Headers: ${JSON.stringify(res.headers)}`);
    
    let data = '';
    res.on('data', (chunk) => {
      data += chunk;
    });
    
    res.on('end', () => {
      console.log('Response:', data);
    });
  });

  req.on('error', (e) => {
    console.error(`Problem with request: ${e.message}`);
  });

  req.end();
}

// Test if uploads directory exists and is writable
function testUploadsDirectory() {
  console.log('\nTesting uploads directory...');
  
  const uploadsDir = path.join(__dirname, 'uploads');
  const brandingDir = path.join(uploadsDir, 'branding');
  
  console.log('Uploads directory exists:', fs.existsSync(uploadsDir));
  console.log('Branding directory exists:', fs.existsSync(brandingDir));
  
  if (!fs.existsSync(brandingDir)) {
    try {
      fs.mkdirSync(brandingDir, { recursive: true });
      console.log('Created branding directory');
    } catch (error) {
      console.error('Error creating branding directory:', error.message);
    }
  }
  
  // Test if we can write to the directory
  const testFile = path.join(brandingDir, 'test.txt');
  try {
    fs.writeFileSync(testFile, 'test');
    fs.unlinkSync(testFile);
    console.log('Directory is writable');
  } catch (error) {
    console.error('Directory is not writable:', error.message);
  }
}

// Test database connection
function testDatabaseConnection() {
  console.log('\nTesting database connection...');
  
  const mysql = require('mysql2/promise');
  
  async function testConnection() {
    try {
      const connection = await mysql.createConnection({
        host: 'localhost',
        user: 'root',
        password: '',
        database: 'retail_management'
      });
      
      console.log('Database connection successful');
      
      // Test if branding_files table exists
      const [rows] = await connection.execute('SHOW TABLES LIKE "branding_files"');
      console.log('branding_files table exists:', rows.length > 0);
      
      // Test if system_branding_info table exists
      const [rows2] = await connection.execute('SHOW TABLES LIKE "system_branding_info"');
      console.log('system_branding_info table exists:', rows2.length > 0);
      
      await connection.end();
    } catch (error) {
      console.error('Database connection failed:', error.message);
    }
  }
  
  testConnection();
}

// Run all tests
console.log('=== File Upload Test ===');
testUploadsDirectory();
testDatabaseConnection();
testUploadEndpoint(); 