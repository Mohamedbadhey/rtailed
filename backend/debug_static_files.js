const path = require('path');
const fs = require('fs');

console.log('🔍 Debugging static file paths...');

// Test different path configurations
const baseDir = process.env.RAILWAY_VOLUME_MOUNT_PATH || path.join(__dirname, '..');
const uploadsDir = path.join(baseDir, 'uploads');
const productsDir = path.join(uploadsDir, 'products');

console.log('🔍 Environment variables:');
console.log('  RAILWAY_VOLUME_MOUNT_PATH:', process.env.RAILWAY_VOLUME_MOUNT_PATH);
console.log('  NODE_ENV:', process.env.NODE_ENV);

console.log('\n🔍 Paths:');
console.log('  Base directory:', baseDir);
console.log('  Uploads directory:', uploadsDir);
console.log('  Products directory:', productsDir);

console.log('\n🔍 Directory existence:');
console.log('  Base directory exists:', fs.existsSync(baseDir));
console.log('  Uploads directory exists:', fs.existsSync(uploadsDir));
console.log('  Products directory exists:', fs.existsSync(productsDir));

if (fs.existsSync(productsDir)) {
  console.log('\n🔍 Files in products directory:');
  try {
    const files = fs.readdirSync(productsDir);
    files.forEach(file => {
      const filePath = path.join(productsDir, file);
      const stats = fs.statSync(filePath);
      console.log(`  - ${file} (${stats.size} bytes)`);
    });
  } catch (error) {
    console.log('  Error reading directory:', error.message);
  }
}

// Test specific file path
const testFile = '1754387753641-WhatsApp_Image_2025-07-27_at_11.57.42.jpeg';
const testFilePath = path.join(productsDir, testFile);
console.log(`\n🔍 Test file: ${testFile}`);
console.log(`  Full path: ${testFilePath}`);
console.log(`  Exists: ${fs.existsSync(testFilePath)}`);

if (fs.existsSync(testFilePath)) {
  const stats = fs.statSync(testFilePath);
  console.log(`  Size: ${stats.size} bytes`);
  console.log(`  Readable: ${fs.accessSync(testFilePath, fs.constants.R_OK) ? 'Yes' : 'No'}`);
} 