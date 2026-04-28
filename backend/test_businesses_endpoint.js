const mysql = require('mysql2/promise');
require('dotenv').config();

async function testBusinessesEndpoint() {
  let connection;
  
  try {
    // Connect to database
    connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_NAME || 'retail_management'
    });

    console.log('✅ Database connection successful');

    // Check if businesses table exists
    const [tables] = await connection.execute(
      "SHOW TABLES LIKE 'businesses'"
    );
    
    if (tables.length === 0) {
      console.log('❌ Businesses table does not exist');
      console.log('💡 Run the multi-tenant setup: setup_multi_tenant.bat');
      return;
    }

    console.log('✅ Businesses table exists');

    // Check if businesses table has data
    const [businesses] = await connection.execute(
      'SELECT COUNT(*) as count FROM businesses'
    );
    
    console.log(`📊 Found ${businesses[0].count} businesses in database`);

    if (businesses[0].count === 0) {
      console.log('⚠️  No businesses found in database');
      console.log('💡 Run the multi-tenant setup to create sample businesses');
    }

    // Check if users table has business_id column
    const [columns] = await connection.execute(
      "SHOW COLUMNS FROM users LIKE 'business_id'"
    );
    
    if (columns.length === 0) {
      console.log('❌ Users table missing business_id column');
      console.log('💡 Run the multi-tenant setup to add business_id column');
      return;
    }

    console.log('✅ Users table has business_id column');

    // Check if users table has is_deleted column
    const [deletedColumns] = await connection.execute(
      "SHOW COLUMNS FROM users LIKE 'is_deleted'"
    );
    
    if (deletedColumns.length === 0) {
      console.log('❌ Users table missing is_deleted column');
      console.log('💡 Run: mysql -u root -p retail_management < backend/add_is_deleted_columns.sql');
      return;
    }

    console.log('✅ Users table has is_deleted column');

    // Test the businesses query that the endpoint uses
    const [testBusinesses] = await connection.execute(
      'SELECT * FROM businesses ORDER BY created_at DESC LIMIT 9'
    );
    
    console.log(`✅ Successfully queried ${testBusinesses.length} businesses`);

    if (testBusinesses.length > 0) {
      console.log('📋 Sample business data:');
      console.log(JSON.stringify(testBusinesses[0], null, 2));
    }

    console.log('\n🎉 Database setup looks good!');
    console.log('💡 Start the backend server: npm start');
    console.log('💡 Then test the endpoint: GET https://api.kismayoict.com/api/businesses');

  } catch (error) {
    console.error('❌ Error:', error.message);
    
    if (error.code === 'ER_ACCESS_DENIED_ERROR') {
      console.log('💡 Check your database credentials in .env file');
    } else if (error.code === 'ECONNREFUSED') {
      console.log('💡 Make sure MySQL server is running');
    } else if (error.code === 'ER_BAD_DB_ERROR') {
      console.log('💡 Database does not exist. Run the initial setup first');
    }
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

testBusinessesEndpoint(); 