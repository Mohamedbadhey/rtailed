const mysql = require('mysql2/promise');

// Database configuration - update these with your Railway database credentials
const dbConfig = {
  host: 'shortline.proxy.rlwy.net',
  port: 14691,
  user: 'root',
  password: 'svQKdaFJQGdSTyAPjRybeqlJSolFYltF',
  database: 'railway'
};

async function checkAndFixBusinessStatus() {
  let connection;
  
  try {
    console.log('🔌 Connecting to database...');
    connection = await mysql.createConnection(dbConfig);
    console.log('✅ Connected to database');
    
    // Check current business status
    console.log('\n📊 Current Business Status:');
    const [businesses] = await connection.execute(
      'SELECT id, name, is_active, payment_status, suspension_reason FROM businesses ORDER BY id'
    );
    
    if (businesses.length === 0) {
      console.log('No businesses found');
      return;
    }
    
    let issuesFound = 0;
    
    businesses.forEach(business => {
      const isActive = business.is_active === 1 || business.is_active === true;
      const paymentActive = business.payment_status === 'active';
      const status = isActive && paymentActive ? '✅ Active' : '❌ Inactive/Suspended';
      
      console.log(`   ${business.id}. ${business.name}`);
      console.log(`      - is_active: ${business.is_active} (${isActive ? 'true' : 'false'})`);
      console.log(`      - payment_status: ${business.payment_status}`);
      console.log(`      - Status: ${status}`);
      
      if (business.suspension_reason) {
        console.log(`      - Suspension Reason: ${business.suspension_reason}`);
      }
      
      // Check for inconsistencies
      if (isActive !== paymentActive) {
        console.log(`      ⚠️  INCONSISTENCY: is_active (${isActive}) != payment_status (${paymentActive})`);
        issuesFound++;
      }
      
      console.log('');
    });
    
    if (issuesFound > 0) {
      console.log(`\n🔧 Found ${issuesFound} inconsistencies. Fixing...`);
      
      // Fix inconsistencies
      for (const business of businesses) {
        const isActive = business.is_active === 1 || business.is_active === true;
        const paymentActive = business.payment_status === 'active';
        
        if (isActive !== paymentActive) {
          console.log(`\n🔄 Fixing business ${business.id} (${business.name})...`);
          
          if (isActive) {
            // Business is marked as active but payment_status is not 'active'
            console.log(`   Setting payment_status to 'active'`);
            await connection.execute(
              'UPDATE businesses SET payment_status = "active", suspension_reason = NULL, suspension_date = NULL WHERE id = ?',
              [business.id]
            );
          } else {
            // Business is marked as inactive but payment_status is 'active'
            console.log(`   Setting payment_status to 'suspended'`);
            await connection.execute(
              'UPDATE businesses SET payment_status = "suspended", is_active = FALSE WHERE id = ?',
              [business.id]
            );
          }
          
          console.log(`   ✅ Fixed business ${business.id}`);
        }
      }
      
      console.log('\n✅ All inconsistencies fixed!');
      
      // Show updated status
      console.log('\n📊 Updated Business Status:');
      const [updatedBusinesses] = await connection.execute(
        'SELECT id, name, is_active, payment_status, suspension_reason FROM businesses ORDER BY id'
      );
      
      updatedBusinesses.forEach(business => {
        const isActive = business.is_active === 1 || business.is_active === true;
        const paymentActive = business.payment_status === 'active';
        const status = isActive && paymentActive ? '✅ Active' : '❌ Inactive/Suspended';
        
        console.log(`   ${business.id}. ${business.name} - ${status}`);
      });
      
    } else {
      console.log('✅ No inconsistencies found. All businesses have consistent status.');
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n🔌 Database connection closed');
    }
  }
}

// Function to manually activate a business
async function activateBusiness(businessId) {
  let connection;
  
  try {
    console.log('🔌 Connecting to database...');
    connection = await mysql.createConnection(dbConfig);
    console.log('✅ Connected to database');
    
    console.log(`\n🔄 Activating business ${businessId}...`);
    
    // Update both is_active and payment_status
    await connection.execute(
      'UPDATE businesses SET is_active = TRUE, payment_status = "active", suspension_reason = NULL, suspension_date = NULL, reactivation_date = NOW() WHERE id = ?',
      [businessId]
    );
    
    // Verify the change
    const [businesses] = await connection.execute(
      'SELECT id, name, is_active, payment_status FROM businesses WHERE id = ?',
      [businessId]
    );
    
    if (businesses.length > 0) {
      const business = businesses[0];
      console.log(`✅ Business ${business.id} (${business.name}) activated successfully!`);
      console.log(`   - is_active: ${business.is_active}`);
      console.log(`   - payment_status: ${business.payment_status}`);
    } else {
      console.log('❌ Business not found');
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n🔌 Database connection closed');
    }
  }
}

// Main execution
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log('🚀 Business Status Check & Fix Tool');
    console.log('===================================');
    console.log('\nUsage:');
    console.log('  node check_and_fix_business_status.js check                    - Check and fix inconsistencies');
    console.log('  node check_and_fix_business_status.js activate <businessId>     - Activate a specific business');
    console.log('\nExamples:');
    console.log('  node check_and_fix_business_status.js check');
    console.log('  node check_and_fix_business_status.js activate 1');
    return;
  }
  
  const command = args[0];
  
  if (command === 'check') {
    await checkAndFixBusinessStatus();
  } else if (command === 'activate') {
    const businessId = parseInt(args[1]);
    
    if (!businessId || isNaN(businessId)) {
      console.log('❌ Please provide a valid business ID');
      return;
    }
    
    await activateBusiness(businessId);
  } else {
    console.log('❌ Unknown command. Use "check" or "activate"');
  }
}

main().catch(console.error); 