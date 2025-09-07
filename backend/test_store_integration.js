const pool = require('./src/config/database');

async function testStoreIntegration() {
  try {
    console.log('🔍 Testing Store-Product Integration...\n');
    
    // Test 1: Check if all required tables exist
    console.log('1. Checking table existence...');
    const tables = ['stores', 'store_business_assignments', 'store_product_inventory', 'store_transfers', 'store_transfer_items', 'store_inventory_movements'];
    
    for (const table of tables) {
      const [rows] = await pool.query(`SHOW TABLES LIKE '${table}'`);
      console.log(`   ${rows.length > 0 ? '✅' : '❌'} ${table} table`);
    }
    
    // Test 2: Check foreign key relationships
    console.log('\n2. Checking foreign key relationships...');
    const [fkRows] = await pool.query(`
      SELECT 
        TABLE_NAME,
        COLUMN_NAME,
        CONSTRAINT_NAME,
        REFERENCED_TABLE_NAME,
        REFERENCED_COLUMN_NAME
      FROM information_schema.KEY_COLUMN_USAGE 
      WHERE TABLE_SCHEMA = DATABASE() 
        AND REFERENCED_TABLE_NAME IS NOT NULL
        AND TABLE_NAME LIKE 'store_%'
      ORDER BY TABLE_NAME, COLUMN_NAME
    `);
    
    console.log(`   Found ${fkRows.length} foreign key relationships:`);
    fkRows.forEach(fk => {
      console.log(`   ✅ ${fk.TABLE_NAME}.${fk.COLUMN_NAME} → ${fk.REFERENCED_TABLE_NAME}.${fk.REFERENCED_COLUMN_NAME}`);
    });
    
    // Test 3: Test a sample query (like the one in the API)
    console.log('\n3. Testing sample inventory query...');
    try {
      const [testRows] = await pool.query(`
        SELECT 
          spi.*,
          p.name as product_name,
          p.sku,
          p.barcode,
          p.price,
          p.cost_price,
          c.name as category_name,
          CASE 
            WHEN spi.quantity <= spi.min_stock_level THEN 'LOW_STOCK'
            WHEN spi.quantity = 0 THEN 'OUT_OF_STOCK'
            ELSE 'IN_STOCK'
          END as stock_status
        FROM store_product_inventory spi
        JOIN products p ON spi.product_id = p.id
        LEFT JOIN categories c ON p.category_id = c.id
        LIMIT 1
      `);
      console.log(`   ✅ Sample query executed successfully (${testRows.length} rows returned)`);
    } catch (error) {
      console.log(`   ❌ Sample query failed: ${error.message}`);
    }
    
    // Test 4: Check if we have any sample data
    console.log('\n4. Checking sample data...');
    const [storeCount] = await pool.query('SELECT COUNT(*) as count FROM stores');
    const [assignmentCount] = await pool.query('SELECT COUNT(*) as count FROM store_business_assignments');
    const [inventoryCount] = await pool.query('SELECT COUNT(*) as count FROM store_product_inventory');
    
    console.log(`   📊 Stores: ${storeCount[0].count}`);
    console.log(`   📊 Assignments: ${assignmentCount[0].count}`);
    console.log(`   📊 Inventory records: ${inventoryCount[0].count}`);
    
    console.log('\n✅ Store integration test completed!');
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  } finally {
    pool.end();
  }
}

testStoreIntegration();
