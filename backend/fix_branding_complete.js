const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

async function fixBrandingComplete() {
  const pool = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'retail_management'
  });

  try {
    console.log('🔧 Complete Branding Fix...\n');

    // Check what branding files exist
    const brandingDir = path.join(__dirname, 'uploads/branding');
    let brandingFiles = [];
    
    if (fs.existsSync(brandingDir)) {
      brandingFiles = fs.readdirSync(brandingDir);
      console.log('📁 Found branding files:', brandingFiles);
    } else {
      console.log('❌ Branding directory not found');
    }

    // Clear existing system branding
    await pool.query('DELETE FROM system_branding_info');
    console.log('✅ Cleared existing system branding');

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
        'INSERT INTO system_branding_info (setting_key, setting_value, setting_type) VALUES (?, ?, ?)',
        [branding.key, branding.value, branding.type]
      );
      console.log(`✅ Set ${branding.key} = ${branding.value}`);
    }

    // Update businesses with branding
    const businessBranding = [
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

    for (const business of businessBranding) {
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

    // Verify the fix
    console.log('\n📋 Updated system_branding_info:');
    const [updatedSystemRows] = await pool.query('SELECT * FROM system_branding_info');
    console.log(JSON.stringify(updatedSystemRows, null, 2));

    console.log('\n📋 Updated businesses:');
    const [updatedBusinessRows] = await pool.query('SELECT id, name, logo, favicon, primary_color FROM businesses WHERE id IN (1,2,3)');
    console.log(JSON.stringify(updatedBusinessRows, null, 2));

    console.log('\n🎉 Complete branding fix applied successfully!');
    console.log('\n📱 Next steps:');
    console.log('1. Restart your Flutter app (Ctrl+C, then flutter run -d chrome)');
    console.log('2. You should now see your custom branding on the login screen');
    console.log('3. The app name and logo should be updated');

  } catch (error) {
    console.error('❌ Error fixing branding:', error);
  } finally {
    await pool.end();
  }
}

fixBrandingComplete(); 