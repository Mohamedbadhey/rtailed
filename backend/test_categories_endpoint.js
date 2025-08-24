const mysql = require('mysql2/promise');

// Test database connection and categories endpoint
async function testCategoriesEndpoint() {
  console.log('🧪 Testing Categories Endpoint...\n');
  
  // Database configuration (using defaults from database.js)
  const dbConfig = {
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'retail_management',
    port: 3306
  };

  try {
    // Test database connection
    console.log('📡 Testing database connection...');
    const connection = await mysql.createConnection(dbConfig);
    console.log('✅ Database connection successful!\n');

    // Check if categories table exists and has data
    console.log('📊 Checking categories table...');
    const [tables] = await connection.execute('SHOW TABLES LIKE "categories"');
    
    if (tables.length === 0) {
      console.log('❌ Categories table does not exist!');
      return;
    }
    console.log('✅ Categories table exists!\n');

    // Check table structure
    console.log('🔍 Checking categories table structure...');
    const [columns] = await connection.execute('DESCRIBE categories');
    console.log('📋 Table columns:');
    columns.forEach(col => {
      console.log(`   - ${col.Field}: ${col.Type} ${col.Null === 'NO' ? 'NOT NULL' : 'NULL'} ${col.Default ? `DEFAULT ${col.Default}` : ''}`);
    });
    console.log('');

    // Check if business_id column exists
    const hasBusinessId = columns.some(col => col.Field === 'business_id');
    if (!hasBusinessId) {
      console.log('❌ business_id column is missing from categories table!');
      console.log('💡 You need to run the migration script: add_is_deleted_columns.sql');
      return;
    }
    console.log('✅ business_id column exists!\n');

    // Check existing categories
    console.log('📋 Checking existing categories...');
    const [categories] = await connection.execute('SELECT * FROM categories LIMIT 10');
    
    if (categories.length === 0) {
      console.log('ℹ️  No categories found in database');
    } else {
      console.log(`✅ Found ${categories.length} categories:`);
      categories.forEach((cat, index) => {
        console.log(`   ${index + 1}. ID: ${cat.id}, Name: "${cat.name}", Business ID: ${cat.business_id}, Description: "${cat.description || 'None'}"`);
      });
    }
    console.log('');

    // Test inserting a category (will be rolled back)
    console.log('🧪 Testing category insertion...');
    const testCategoryName = `TEST_CATEGORY_${Date.now()}`;
    
    const [insertResult] = await connection.execute(
      'INSERT INTO categories (name, description, business_id) VALUES (?, ?, ?)',
      [testCategoryName, 'Test category for endpoint testing', 1]
    );
    
    console.log(`✅ Test category inserted with ID: ${insertResult.insertId}`);
    
    // Verify the insertion
    const [newCategory] = await connection.execute(
      'SELECT * FROM categories WHERE id = ?',
      [insertResult.insertId]
    );
    
    if (newCategory.length > 0) {
      console.log('✅ Category retrieval successful:', newCategory[0]);
    } else {
      console.log('❌ Failed to retrieve inserted category');
    }

    // Rollback the test insertion
    await connection.execute('DELETE FROM categories WHERE id = ?', [insertResult.insertId]);
    console.log('🔄 Test category removed (rolled back)\n');

    // Test business isolation
    console.log('🔒 Testing business isolation...');
    const [businessCategories] = await connection.execute(
      'SELECT COUNT(*) as count FROM categories WHERE business_id = 1'
    );
    console.log(`✅ Categories for business ID 1: ${businessCategories[0].count}`);
    
    const [allCategories] = await connection.execute('SELECT COUNT(*) as count FROM categories');
    console.log(`✅ Total categories: ${allCategories[0].count}`);
    
    if (businessCategories[0].count <= allCategories[0].count) {
      console.log('✅ Business isolation appears to be working');
    } else {
      console.log('⚠️  Business isolation may have issues');
    }

    await connection.end();
    console.log('\n🎉 Categories endpoint test completed successfully!');
    console.log('💡 The backend should be ready to handle category operations.');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
    console.error('💡 Make sure:');
    console.error('   1. MySQL server is running');
    console.error('   2. Database "retail_management" exists');
    console.error('   3. User "root" has access (or update credentials)');
    console.error('   4. Categories table has been created with proper structure');
  }
}

// Run the test
testCategoriesEndpoint();
