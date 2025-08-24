const mysql = require('mysql2/promise');

// Check database status
async function checkDatabaseStatus() {
  console.log('🔍 Checking Database Status...\n');
  
  const dbConfig = {
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'retail_management',
    port: 3306
  };

  let connection;

  try {
    // Connect to database
    console.log('📡 Connecting to database...');
    connection = await mysql.createConnection(dbConfig);
    console.log('✅ Database connected!\n');

    // Check users table
    console.log('👥 Checking users table...');
    const [users] = await connection.execute('SELECT id, username, email, role, business_id FROM users LIMIT 10');
    
    if (users.length === 0) {
      console.log('ℹ️  No users found in database');
    } else {
      console.log(`✅ Found ${users.length} users:`);
      users.forEach((user, index) => {
        console.log(`   ${index + 1}. ID: ${user.id}, Username: "${user.username}", Role: ${user.role}, Business ID: ${user.business_id}`);
      });
    }
    console.log('');

    // Check categories table
    console.log('📂 Checking categories table...');
    const [categories] = await connection.execute('SELECT * FROM categories LIMIT 10');
    
    if (categories.length === 0) {
      console.log('ℹ️  No categories found in database');
    } else {
      console.log(`✅ Found ${categories.length} categories:`);
      categories.forEach((cat, index) => {
        console.log(`   ${index + 1}. ID: ${cat.id}, Name: "${cat.name}", Business ID: ${cat.business_id}, Description: "${cat.description || 'None'}", Deleted: ${cat.is_deleted}`);
      });
    }
    console.log('');

    // Check businesses table
    console.log('🏢 Checking businesses table...');
    const [businesses] = await connection.execute('SELECT id, name, status FROM businesses LIMIT 10');
    
    if (businesses.length === 0) {
      console.log('ℹ️  No businesses found in database');
    } else {
      console.log(`✅ Found ${businesses.length} businesses:`);
      businesses.forEach((business, index) => {
        console.log(`   ${index + 1}. ID: ${business.id}, Name: "${business.name}", Status: ${business.status}`);
      });
    }
    console.log('');

    // Check if we have a superadmin user
    const [superadminUsers] = await connection.execute('SELECT id, username, email FROM users WHERE role = "superadmin" LIMIT 5');
    
    if (superadminUsers.length > 0) {
      console.log('👑 Superadmin users found:');
      superadminUsers.forEach((user, index) => {
        console.log(`   ${index + 1}. ID: ${user.id}, Username: "${user.username}", Email: "${user.email}"`);
      });
      console.log('💡 You can use these credentials to test the API');
    } else {
      console.log('⚠️  No superadmin users found');
      console.log('💡 You may need to create a superadmin user first');
    }

    console.log('\n🎉 Database status check completed!');

  } catch (error) {
    console.error('❌ Check failed:', error.message);
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n🔌 Database connection closed');
    }
  }
}

// Run the check
checkDatabaseStatus();
