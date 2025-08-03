const http = require('http');

async function testBrandingAPI() {
  console.log('🧪 Testing Branding API...\n');

  // Test 1: Check system branding endpoint
  console.log('1️⃣ Testing system branding endpoint...');
  try {
    const systemResponse = await makeRequest('GET', '/api/branding/system');
    console.log('✅ System branding response:', JSON.stringify(systemResponse, null, 2));
  } catch (error) {
    console.log('❌ System branding error:', error.message);
  }

  // Test 2: Check if images are accessible
  console.log('\n2️⃣ Testing image accessibility...');
  const testImages = [
    '/uploads/branding/file-1754047808502-889792832.png',
    '/uploads/branding/file-1754047811346-749514891.png',
    '/uploads/branding/file-1754049436337-160209782.png',
    '/uploads/branding/file-1754049441639-310495830.png'
  ];

  for (const imagePath of testImages) {
    try {
      const imageResponse = await makeRequest('GET', imagePath);
      console.log(`✅ Image ${imagePath}: ${imageResponse.statusCode}`);
    } catch (error) {
      console.log(`❌ Image ${imagePath}: ${error.message}`);
    }
  }

  // Test 3: Check health endpoint
  console.log('\n3️⃣ Testing health endpoint...');
  try {
    const healthResponse = await makeRequest('GET', '/api/health');
    console.log('✅ Health check response:', JSON.stringify(healthResponse, null, 2));
  } catch (error) {
    console.log('❌ Health check error:', error.message);
  }
}

function makeRequest(method, path) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: path,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      }
    };

    const req = http.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        if (res.headers['content-type']?.includes('application/json')) {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            resolve({ statusCode: res.statusCode, data: data });
          }
        } else {
          resolve({ statusCode: res.statusCode, data: data });
        }
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.end();
  });
}

testBrandingAPI(); 