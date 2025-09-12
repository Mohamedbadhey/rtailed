const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

// Database configuration
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'rtail',
  multipleStatements: true
};

async function runMigration() {
  let connection;
  
  try {
    console.log('🔄 Connecting to database...');
    connection = await mysql.createConnection(dbConfig);
    
    console.log('📄 Reading migration file...');
    const migrationPath = path.join(__dirname, 'migrations', 'add_costprice_to_sale_items.sql');
    const migrationSQL = fs.readFileSync(migrationPath, 'utf8');
    
    console.log('🚀 Running migration: add_costprice_to_sale_items.sql');
    console.log('📝 Migration SQL:');
    console.log(migrationSQL);
    
    await connection.execute(migrationSQL);
    
    console.log('✅ Migration completed successfully!');
    console.log('📊 Added costprice column to sale_items table');
    console.log('🔧 Updated existing records with current product cost prices');
    console.log('📈 Added index for better query performance');
    
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    console.error('🔍 Error details:', error);
    process.exit(1);
  } finally {
    if (connection) {
      await connection.end();
      console.log('🔌 Database connection closed');
    }
  }
}

// Run the migration
runMigration();
