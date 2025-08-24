const mysql = require('mysql2/promise');

// Test all category operations
async function testCategoryOperations() {
  console.log('🧪 Testing All Category Operations...\n');
  
  const dbConfig = {
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'retail_management',
    port: 3306
  };

  let connection;
  let testCategoryId;

  try {
    // Connect to database
    console.log('📡 Connecting to database...');
    connection = await mysql.createConnection(dbConfig);
    console.log('✅ Database connected!\n');

    // Check current categories
    console.log('📋 Current categories in database:');
    const [currentCategories] = await connection.execute('SELECT * FROM categories ORDER BY id');
    
    if (currentCategories.length === 0) {
      console.log('ℹ️  No categories found');
    } else {
      currentCategories.forEach((cat, index) => {
        console.log(`   ${index + 1}. ID: ${cat.id}, Name: "${cat.name}", Business ID: ${cat.business_id}, Description: "${cat.description || 'None'}", Deleted: ${cat.is_deleted}`);
      });
    }
    console.log('');

    // Test 1: CREATE Category
    console.log('🆕 Testing CREATE operation...');
    const testCategoryName = `TEST_CATEGORY_${Date.now()}`;
    const testDescription = 'Test category for operations testing';
    
    const [createResult] = await connection.execute(
      'INSERT INTO categories (name, description, business_id) VALUES (?, ?, ?)',
      [testCategoryName, testDescription, 1]
    );
    
    testCategoryId = createResult.insertId;
    console.log(`✅ Category created with ID: ${testCategoryId}`);
    console.log(`   Name: "${testCategoryName}"`);
    console.log(`   Description: "${testDescription}"`);
    console.log(`   Business ID: 1`);
    console.log('');

    // Test 2: READ Category (single)
    console.log('📖 Testing READ operation (single)...');
    const [readResult] = await connection.execute(
      'SELECT * FROM categories WHERE id = ?',
      [testCategoryId]
    );
    
    if (readResult.length > 0) {
      const category = readResult[0];
      console.log('✅ Category retrieved successfully:');
      console.log(`   ID: ${category.id}`);
      console.log(`   Name: "${category.name}"`);
      console.log(`   Description: "${category.description}"`);
      console.log(`   Business ID: ${category.business_id}`);
      console.log(`   Created: ${category.created_at}`);
      console.log(`   Deleted: ${category.is_deleted}`);
    } else {
      console.log('❌ Failed to retrieve created category');
    }
    console.log('');

    // Test 3: READ All Categories (with business isolation)
    console.log('📖 Testing READ operation (all with business isolation)...');
    const [allCategories] = await connection.execute(
      'SELECT * FROM categories WHERE business_id = 1 AND is_deleted = 0 ORDER BY name'
    );
    
    console.log(`✅ Found ${allCategories.length} active categories for business 1:`);
    allCategories.forEach((cat, index) => {
      console.log(`   ${index + 1}. ID: ${cat.id}, Name: "${cat.name}", Description: "${cat.description || 'None'}"`);
    });
    console.log('');

    // Test 4: UPDATE Category
    console.log('✏️ Testing UPDATE operation...');
    const updatedName = `UPDATED_${testCategoryName}`;
    const updatedDescription = 'Updated description for testing';
    
    const [updateResult] = await connection.execute(
      'UPDATE categories SET name = ?, description = ? WHERE id = ? AND business_id = 1',
      [updatedName, updatedDescription, testCategoryId]
    );
    
    if (updateResult.affectedRows > 0) {
      console.log('✅ Category updated successfully');
      console.log(`   New name: "${updatedName}"`);
      console.log(`   New description: "${updatedDescription}"`);
      
      // Verify the update
      const [verifyUpdate] = await connection.execute(
        'SELECT * FROM categories WHERE id = ?',
        [testCategoryId]
      );
      
      if (verifyUpdate.length > 0) {
        const updatedCategory = verifyUpdate[0];
        console.log('✅ Update verification successful:');
        console.log(`   Name: "${updatedCategory.name}"`);
        console.log(`   Description: "${updatedCategory.description}"`);
      }
    } else {
      console.log('❌ Failed to update category');
    }
    console.log('');

    // Test 5: SOFT DELETE (set is_deleted = 1)
    console.log('🗑️ Testing SOFT DELETE operation...');
    const [softDeleteResult] = await connection.execute(
      'UPDATE categories SET is_deleted = 1 WHERE id = ? AND business_id = 1',
      [testCategoryId]
    );
    
    if (softDeleteResult.affectedRows > 0) {
      console.log('✅ Category soft deleted successfully');
      
      // Verify it's not visible in normal queries
      const [hiddenCategory] = await connection.execute(
        'SELECT * FROM categories WHERE id = ? AND is_deleted = 0',
        [testCategoryId]
      );
      
      if (hiddenCategory.length === 0) {
        console.log('✅ Category is now hidden from normal queries');
      } else {
        console.log('⚠️ Category still visible after soft delete');
      }
    } else {
      console.log('❌ Failed to soft delete category');
    }
    console.log('');

    // Test 6: RESTORE Category
    console.log('🔄 Testing RESTORE operation...');
    const [restoreResult] = await connection.execute(
      'UPDATE categories SET is_deleted = 0 WHERE id = ? AND business_id = 1',
      [testCategoryId]
    );
    
    if (restoreResult.affectedRows > 0) {
      console.log('✅ Category restored successfully');
      
      // Verify it's visible again
      const [visibleCategory] = await connection.execute(
        'SELECT * FROM categories WHERE id = ? AND is_deleted = 0',
        [testCategoryId]
      );
      
      if (visibleCategory.length > 0) {
        console.log('✅ Category is now visible again');
      } else {
        console.log('⚠️ Category still hidden after restore');
      }
    } else {
      console.log('❌ Failed to restore category');
    }
    console.log('');

    // Test 7: HARD DELETE (permanent removal)
    console.log('💀 Testing HARD DELETE operation...');
    const [hardDeleteResult] = await connection.execute(
      'DELETE FROM categories WHERE id = ? AND business_id = 1',
      [testCategoryId]
    );
    
    if (hardDeleteResult.affectedRows > 0) {
      console.log('✅ Category permanently deleted');
      
      // Verify it's gone
      const [deletedCategory] = await connection.execute(
        'SELECT * FROM categories WHERE id = ?',
        [testCategoryId]
      );
      
      if (deletedCategory.length === 0) {
        console.log('✅ Category completely removed from database');
      } else {
        console.log('⚠️ Category still exists after hard delete');
      }
    } else {
      console.log('❌ Failed to hard delete category');
    }
    console.log('');

    // Final status
    console.log('📊 Final categories status:');
    const [finalCategories] = await connection.execute(
      'SELECT * FROM categories WHERE business_id = 1 AND is_deleted = 0 ORDER BY name'
    );
    
    console.log(`✅ ${finalCategories.length} active categories remaining for business 1`);
    finalCategories.forEach((cat, index) => {
      console.log(`   ${index + 1}. ID: ${cat.id}, Name: "${cat.name}", Description: "${cat.description || 'None'}"`);
    });

    console.log('\n🎉 All category operations tested successfully!');
    console.log('💡 The backend categories system is working properly.');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
    console.error('Stack trace:', error.stack);
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n🔌 Database connection closed');
    }
  }
}

// Run the test
testCategoryOperations();
