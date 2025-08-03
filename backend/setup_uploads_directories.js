#!/usr/bin/env node

/**
 * Setup script to ensure uploads directories exist
 * This is especially important for Railway deployment where the file system is ephemeral
 */

const fs = require('fs');
const path = require('path');

console.log('🔧 Setting up uploads directories...');

// Define the directories to create
const directories = [
  'uploads',
  'uploads/products',
  'uploads/branding'
];

// Create each directory
directories.forEach(dir => {
  const fullPath = path.join(__dirname, dir);
  
  try {
    if (!fs.existsSync(fullPath)) {
      fs.mkdirSync(fullPath, { recursive: true });
      console.log(`✅ Created directory: ${dir}`);
    } else {
      console.log(`📁 Directory already exists: ${dir}`);
    }
  } catch (error) {
    console.error(`❌ Error creating directory ${dir}:`, error.message);
  }
});

// Create .gitkeep files to ensure directories are tracked
directories.forEach(dir => {
  const gitkeepPath = path.join(__dirname, dir, '.gitkeep');
  
  try {
    if (!fs.existsSync(gitkeepPath)) {
      fs.writeFileSync(gitkeepPath, '# This file ensures the directory is tracked by git\n');
      console.log(`📝 Created .gitkeep in: ${dir}`);
    }
  } catch (error) {
    console.error(`❌ Error creating .gitkeep in ${dir}:`, error.message);
  }
});

// Test write permissions
directories.forEach(dir => {
  const testFile = path.join(__dirname, dir, 'test-write-permission.tmp');
  
  try {
    fs.writeFileSync(testFile, 'test');
    fs.unlinkSync(testFile);
    console.log(`✅ Write permission verified for: ${dir}`);
  } catch (error) {
    console.error(`❌ Write permission failed for ${dir}:`, error.message);
  }
});

console.log('🎉 Uploads directories setup complete!');
console.log('');
console.log('📋 Directory structure:');
console.log('uploads/');
console.log('├── products/');
console.log('│   └── .gitkeep');
console.log('├── branding/');
console.log('│   └── .gitkeep');
console.log('└── .gitkeep');
console.log('');
console.log('💡 Note: On Railway, these directories will be recreated on each deployment.');
console.log('   Files uploaded during runtime will be lost when the container restarts.');
console.log('   Consider using cloud storage (AWS S3, Cloudinary, etc.) for production.'); 