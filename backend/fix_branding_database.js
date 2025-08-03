const mysql = require('mysql2/promise');

async function fixBrandingDatabase() {
  const pool = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'retail_management'
  });

  try {
    console.log('🔧 Fixing branding database...\n');

    // First, let's see what's currently in the tables
    console.log('📋 Current system_branding_info:');
    const [systemRows] = await pool.query('SELECT * FROM system_branding_info');
    console.log(JSON.stringify(systemRows, null, 2));

    console.log('\n📋 Current businesses branding:');
    const [businessRows] = await pool.query('SELECT id, name, logo, favicon, primary_color, secondary_color, accent_color FROM businesses WHERE id IN (1,2,3)');
    console.log(JSON.stringify(businessRows, null, 2));

    // Get the first business branding as system branding
    if (businessRows.length > 0) {
      const firstBusiness = businessRows[0];
      console.log('\n🎯 Using Business 1 branding as system branding...');

      // Clear existing system branding
      await pool.query('DELETE FROM system_branding_info');
      console.log('✅ Cleared existing system branding');

      // Insert system branding from business 1
      const systemBrandingData = [
        { key: 'app_name', value: firstBusiness.name || 'My Business App', type: 'string' },
        { key: 'logo_url', value: firstBusiness.logo || '/uploads/branding/file-1754047808502-889792832.png', type: 'file' },
        { key: 'favicon_url', value: firstBusiness.favicon || '/uploads/branding/file-1754047811346-749514891.png', type: 'file' },
        { key: 'primary_color', value: firstBusiness.primary_color || '#1976D2', type: 'color' },
        { key: 'secondary_color', value: firstBusiness.secondary_color || '#424242', type: 'color' },
        { key: 'accent_color', value: firstBusiness.accent_color || '#FFC107', type: 'color' },
        { key: 'theme', value: 'default', type: 'string' }
      ];

      for (const branding of systemBrandingData) {
        await pool.query(
          'INSERT INTO system_branding_info (setting_key, setting_value, setting_type) VALUES (?, ?, ?)',
          [branding.key, branding.value, branding.type]
        );
        console.log(`✅ Set ${branding.key} = ${branding.value}`);
      }

      // Verify the fix
      console.log('\n📋 Updated system_branding_info:');
      const [updatedSystemRows] = await pool.query('SELECT * FROM system_branding_info');
      console.log(JSON.stringify(updatedSystemRows, null, 2));

      console.log('\n🎉 Branding database fixed successfully!');
      console.log('\n📱 Next steps:');
      console.log('1. Restart your Flutter app (Ctrl+C, then flutter run -d chrome)');
      console.log('2. You should now see your custom branding on the login screen');
      console.log('3. The app name and logo should be updated');

    } else {
      console.log('❌ No businesses found in database');
    }

  } catch (error) {
    console.error('❌ Error fixing branding database:', error);
  } finally {
    await pool.end();
  }
}

fixBrandingDatabase(); 