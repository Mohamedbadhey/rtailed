// Test Superadmin Store Management Workflow
const mysql = require('mysql2/promise');

async function testSuperadminWorkflow() {
  let connection;
  
  try {
    // Connect to database
    connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_NAME || 'retail_management',
      port: process.env.DB_PORT || 3306
    });

    console.log('🧪 Testing Superadmin Store Management Workflow...\n');

    // Test 1: Check if we have businesses to assign stores to
    console.log('1️⃣ Checking available businesses...');
    const [businesses] = await connection.execute('SELECT id, name, business_code FROM businesses LIMIT 5');
    
    if (businesses.length === 0) {
      console.log('❌ No businesses found. Create businesses first.');
      return;
    }
    
    console.log('Available businesses:');
    businesses.forEach(business => {
      console.log(`  - ${business.name} (ID: ${business.id}, Code: ${business.business_code})`);
    });
    console.log('');

    // Test 2: Check current store assignments
    console.log('2️⃣ Checking current store-business assignments...');
    const [assignments] = await connection.execute(`
      SELECT 
        s.name as store_name,
        b.name as business_name,
        sba.is_active
      FROM store_business_assignments sba
      JOIN stores s ON sba.store_id = s.id
      JOIN businesses b ON sba.business_id = b.id
      ORDER BY s.name, b.name
    `);
    
    if (assignments.length === 0) {
      console.log('⚠️ No store-business assignments found.');
      console.log('   Superadmin needs to assign stores to businesses.\n');
    } else {
      console.log('Current assignments:');
      assignments.forEach(assignment => {
        console.log(`  - ${assignment.store_name} → ${assignment.business_name} (${assignment.is_active ? 'Active' : 'Inactive'})`);
      });
      console.log('');
    }

    // Test 3: Check which businesses have no store assignments
    console.log('3️⃣ Checking businesses without store assignments...');
    const [unassignedBusinesses] = await connection.execute(`
      SELECT b.id, b.name, b.business_code
      FROM businesses b
      LEFT JOIN store_business_assignments sba ON b.id = sba.business_id AND sba.is_active = 1
      WHERE sba.id IS NULL
    `);
    
    if (unassignedBusinesses.length === 0) {
      console.log('✅ All businesses have store assignments.\n');
    } else {
      console.log('Businesses without store assignments:');
      unassignedBusinesses.forEach(business => {
        console.log(`  - ${business.name} (ID: ${business.id}, Code: ${business.business_code})`);
      });
      console.log('');
    }

    // Test 4: Check available stores
    console.log('4️⃣ Checking available stores...');
    const [stores] = await connection.execute('SELECT id, name, store_code, store_type FROM stores ORDER BY name');
    
    if (stores.length === 0) {
      console.log('❌ No stores found. Superadmin needs to create stores first.\n');
    } else {
      console.log('Available stores:');
      stores.forEach(store => {
        console.log(`  - ${store.name} (ID: ${store.id}, Code: ${store.store_code}, Type: ${store.store_type})`);
      });
      console.log('');
    }

    // Test 5: Provide recommendations
    console.log('5️⃣ Recommendations:');
    
    if (stores.length === 0) {
      console.log('🔧 Superadmin should:');
      console.log('   1. Create stores using the Store Management interface');
      console.log('   2. Assign stores to businesses');
    } else if (unassignedBusinesses.length > 0) {
      console.log('🔧 Superadmin should:');
      console.log('   1. Assign existing stores to unassigned businesses');
      console.log('   2. Use the Store Management → Assignments tab');
    } else {
      console.log('✅ Store management setup looks good!');
      console.log('   All businesses have store assignments.');
    }

    console.log('\n📋 How to fix the issue:');
    console.log('1. Login as superadmin');
    console.log('2. Go to Settings → Store Management');
    console.log('3. Create stores if needed (click + button)');
    console.log('4. Go to Assignments tab');
    console.log('5. Assign stores to businesses');
    console.log('6. Admin users will then see their assigned stores');

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
testSuperadminWorkflow();
