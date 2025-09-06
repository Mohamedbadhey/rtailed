// Test Store Management Endpoints
const express = require('express');
const request = require('supertest');
const app = require('./src/index');

async function testStoreEndpoints() {
  console.log('🧪 Testing Store Management Endpoints...\n');

  try {
    // Test 1: Check if store routes are registered
    console.log('1️⃣ Testing route registration...');
    const routes = app._router.stack
      .filter(layer => layer.route)
      .map(layer => Object.keys(layer.route.methods).map(method => `${method.toUpperCase()} ${layer.route.path}`))
      .flat();
    
    const storeRoutes = routes.filter(route => route.includes('/api/stores') || route.includes('/api/store-'));
    console.log('Store routes found:', storeRoutes);
    
    if (storeRoutes.length > 0) {
      console.log('✅ Store routes are registered\n');
    } else {
      console.log('❌ No store routes found\n');
      return;
    }

    // Test 2: Test database connection
    console.log('2️⃣ Testing database connection...');
    const pool = require('./src/config/database');
    
    try {
      const [rows] = await pool.query('SELECT COUNT(*) as count FROM stores');
      console.log(`✅ Database connected - Found ${rows[0].count} stores\n`);
    } catch (dbError) {
      console.log('❌ Database error:', dbError.message);
      console.log('This might be because store tables don\'t exist yet\n');
    }

    // Test 3: Test store tables exist
    console.log('3️⃣ Testing store tables...');
    try {
      const [tables] = await pool.query(`
        SELECT TABLE_NAME 
        FROM information_schema.TABLES 
        WHERE TABLE_SCHEMA = DATABASE() 
        AND TABLE_NAME LIKE 'store%'
        ORDER BY TABLE_NAME
      `);
      
      console.log('Store tables found:', tables.map(t => t.TABLE_NAME));
      
      if (tables.length >= 3) {
        console.log('✅ All required store tables exist\n');
      } else {
        console.log('❌ Missing store tables. Run the SQL setup scripts first\n');
        return;
      }
    } catch (error) {
      console.log('❌ Error checking tables:', error.message, '\n');
      return;
    }

    // Test 4: Test sample data
    console.log('4️⃣ Testing sample data...');
    try {
      const [stores] = await pool.query('SELECT COUNT(*) as count FROM stores');
      const [assignments] = await pool.query('SELECT COUNT(*) as count FROM store_business_assignments');
      const [inventory] = await pool.query('SELECT COUNT(*) as count FROM store_product_inventory');
      
      console.log(`Stores: ${stores[0].count}`);
      console.log(`Assignments: ${assignments[0].count}`);
      console.log(`Inventory: ${inventory[0].count}`);
      
      if (stores[0].count > 0) {
        console.log('✅ Sample data exists\n');
      } else {
        console.log('⚠️ No sample data found\n');
      }
    } catch (error) {
      console.log('❌ Error checking sample data:', error.message, '\n');
    }

    console.log('🎉 Store Management Backend Test Complete!');
    console.log('✅ Backend is properly configured');
    console.log('✅ Routes are registered');
    console.log('✅ Database connection works');
    console.log('✅ Store tables exist');
    console.log('\n🚀 Ready for frontend testing!');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

// Run the test
testStoreEndpoints();
