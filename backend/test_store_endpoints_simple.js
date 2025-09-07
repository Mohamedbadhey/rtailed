// Simple test to check if store endpoints are working
const express = require('express');
const app = express();

// Test if the store routes are properly loaded
try {
  console.log('🧪 Testing Store Routes...');
  
  // Try to require the store routes
  const storeRoutes = require('./src/routes/stores');
  console.log('✅ Store routes loaded successfully');
  
  // Test if the routes are properly exported
  if (typeof storeRoutes === 'function') {
    console.log('✅ Store routes are properly exported');
  } else {
    console.log('❌ Store routes are not properly exported');
  }
  
  // Test database connection
  const pool = require('./src/config/database');
  console.log('✅ Database pool loaded successfully');
  
  // Test if store tables exist
  pool.query('SELECT COUNT(*) as count FROM stores')
    .then(([rows]) => {
      console.log(`✅ Store tables exist - Found ${rows[0].count} stores`);
    })
    .catch((error) => {
      console.log('❌ Store tables error:', error.message);
    });
    
} catch (error) {
  console.log('❌ Error loading store routes:', error.message);
}
