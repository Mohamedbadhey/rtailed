const mysql = require('mysql2/promise');

async function setupBranding() {
  const pool = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'retail_management'
  });

  try {
    console.log('Setting up branding...');

    // Set up system branding with the uploaded images
    const systemBrandingData = [
      { key: 'app_name', value: 'My Business App', type: 'string' },
      { key: 'logo_url', value: '/uploads/branding/file-1754047808502-889792832.png', type: 'file' },
      { key: 'favicon_url', value: '/uploads/branding/file-1754047811346-749514891.png', type: 'file' },
      { key: 'primary_color', value: '#1976D2', type: 'color' },
      { key: 'secondary_color', value: '#424242', type: 'color' },
      { key: 'accent_color', value: '#FFC107', type: 'color' },
      { key: 'theme', value: 'default', type: 'string' }
    ];

    for (const branding of systemBrandingData) {
      await pool.query(
        'INSERT INTO system_branding_info (setting_key, setting_value, setting_type) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE setting_value = ?',
        [branding.key, branding.value, branding.type, branding.value]
      );
      console.log(`✅ Set ${branding.key} = ${branding.value}`);
    }

    // Set up business branding for each business
    const businesses = [
      {
        id: 1,
        name: 'Business 1',
        logo: '/uploads/branding/file-1754047808502-889792832.png',
        favicon: '/uploads/branding/file-1754047811346-749514891.png',
        primary_color: '#1976D2',
        secondary_color: '#424242',
        accent_color: '#FFC107'
      },
      {
        id: 2,
        name: 'Business 2',
        logo: '/uploads/branding/file-1754049436337-160209782.png',
        favicon: '/uploads/branding/file-1754049441639-310495830.png',
        primary_color: '#4CAF50',
        secondary_color: '#2E7D32',
        accent_color: '#FF9800'
      },
      {
        id: 3,
        name: 'Business 3',
        logo: '/uploads/branding/file-1754049441639-310495830.png',
        favicon: '/uploads/branding/file-1754047808502-889792832.png',
        primary_color: '#9C27B0',
        secondary_color: '#6A1B9A',
        accent_color: '#FF5722'
      }
    ];

    for (const business of businesses) {
      await pool.query(
        `UPDATE businesses SET 
          name = ?, logo = ?, favicon = ?, 
          primary_color = ?, secondary_color = ?, accent_color = ?
         WHERE id = ?`,
        [
          business.name,
          business.logo,
          business.favicon,
          business.primary_color,
          business.secondary_color,
          business.accent_color,
          business.id
        ]
      );
      console.log(`✅ Updated business ${business.id}: ${business.name}`);
    }

    // Verify the setup
    console.log('\n📋 Verifying branding setup...');
    
    const [systemRows] = await pool.query('SELECT * FROM system_branding_info');
    console.log('\nSystem Branding:');
    systemRows.forEach(row => {
      console.log(`  ${row.setting_key}: ${row.setting_value}`);
    });

    const [businessRows] = await pool.query('SELECT id, name, logo, favicon, primary_color FROM businesses WHERE id IN (1,2,3)');
    console.log('\nBusiness Branding:');
    businessRows.forEach(row => {
      console.log(`  Business ${row.id} (${row.name}):`);
      console.log(`    Logo: ${row.logo}`);
      console.log(`    Favicon: ${row.favicon}`);
      console.log(`    Primary Color: ${row.primary_color}`);
    });

    console.log('\n🎉 Branding setup completed successfully!');
    console.log('\n📱 Next steps:');
    console.log('1. Restart your Flutter app');
    console.log('2. You should now see your custom branding on the login screen');
    console.log('3. Each business will have its own branding when logged in');

  } catch (error) {
    console.error('❌ Error setting up branding:', error);
  } finally {
    await pool.end();
  }
}

setupBranding(); 