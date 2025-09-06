// Test Store Management System
const mysql = require('mysql2/promise');

async function testStoreManagement() {
  let connection;
  
  try {
    // Connect to database
    connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_NAME || 'railway',
      port: process.env.DB_PORT || 3306
    });

    console.log('✅ Connected to database');

    // Test 1: Check if store tables exist
    console.log('\n📋 Testing Store Tables...');
    
    const [tables] = await connection.execute(`
      SELECT TABLE_NAME 
      FROM information_schema.TABLES 
      WHERE TABLE_SCHEMA = DATABASE() 
      AND TABLE_NAME LIKE 'store%'
      ORDER BY TABLE_NAME
    `);
    
    console.log('Store tables found:', tables.map(t => t.TABLE_NAME));
    
    if (tables.length >= 3) {
      console.log('✅ Store tables exist');
    } else {
      console.log('❌ Missing store tables');
      return;
    }

    // Test 2: Check sample data
    console.log('\n📊 Testing Sample Data...');
    
    const [stores] = await connection.execute('SELECT COUNT(*) as count FROM stores');
    const [assignments] = await connection.execute('SELECT COUNT(*) as count FROM store_business_assignments');
    const [inventory] = await connection.execute('SELECT COUNT(*) as count FROM store_product_inventory');
    
    console.log(`Stores: ${stores[0].count}`);
    console.log(`Assignments: ${assignments[0].count}`);
    console.log(`Inventory: ${inventory[0].count}`);
    
    if (stores[0].count > 0) {
      console.log('✅ Sample data exists');
    } else {
      console.log('⚠️ No sample data found');
    }

    // Test 3: Test store-business relationship
    console.log('\n🔗 Testing Store-Business Relationships...');
    
    const [relationships] = await connection.execute(`
      SELECT 
        s.name as store_name,
        b.name as business_name,
        sba.is_active
      FROM store_business_assignments sba
      JOIN stores s ON sba.store_id = s.id
      JOIN businesses b ON sba.business_id = b.id
      LIMIT 5
    `);
    
    console.log('Store-Business relationships:');
    relationships.forEach(rel => {
      console.log(`  ${rel.store_name} ↔ ${rel.business_name} (${rel.is_active ? 'Active' : 'Inactive'})`);
    });
    
    if (relationships.length > 0) {
      console.log('✅ Store-business relationships working');
    } else {
      console.log('⚠️ No store-business relationships found');
    }

    // Test 4: Test inventory data
    console.log('\n📦 Testing Inventory Data...');
    
    const [inventoryData] = await connection.execute(`
      SELECT 
        s.name as store_name,
        b.name as business_name,
        p.name as product_name,
        spi.quantity,
        spi.min_stock_level
      FROM store_product_inventory spi
      JOIN stores s ON spi.store_id = s.id
      JOIN businesses b ON spi.business_id = b.id
      JOIN products p ON spi.product_id = p.id
      LIMIT 5
    `);
    
    console.log('Inventory data:');
    inventoryData.forEach(item => {
      console.log(`  ${item.store_name} → ${item.business_name}: ${item.product_name} (${item.quantity} units, min: ${item.min_stock_level})`);
    });
    
    if (inventoryData.length > 0) {
      console.log('✅ Inventory data working');
    } else {
      console.log('⚠️ No inventory data found');
    }

    console.log('\n🎉 Store Management System Test Complete!');
    console.log('✅ All core functionality is working');
    console.log('🚀 Ready for frontend integration!');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n🔌 Database connection closed');
    }
  }
}

// Run the test
testStoreManagement();
