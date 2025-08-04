const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const pool = require('../config/database');
const { auth } = require('../middleware/auth');

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    // Use Railway's persistent storage directory
    const uploadDir = process.env.RAILWAY_VOLUME_MOUNT_PATH 
      ? path.join(process.env.RAILWAY_VOLUME_MOUNT_PATH, 'uploads', 'branding')
      : path.join(__dirname, '../../uploads/branding');
    
    try {
      if (!fs.existsSync(uploadDir)) {
        fs.mkdirSync(uploadDir, { recursive: true });
        console.log('Created upload directory:', uploadDir);
      }
      cb(null, uploadDir);
    } catch (error) {
      console.error('Error creating upload directory:', error);
      cb(error);
    }
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB limit
  },
  fileFilter: (req, file, cb) => {
    console.log('File filter check:', {
      originalname: file.originalname,
      mimetype: file.mimetype,
      fieldname: file.fieldname
    });
    
    const allowedTypes = /jpeg|jpg|png|gif|svg|ico|webp/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);
    
    console.log('Validation results:', {
      extname: extname,
      mimetype: mimetype,
      allowed: extname || mimetype
    });
    
    // Accept if either extension or mimetype is valid
    if (extname || mimetype) {
      return cb(null, true);
    } else {
      cb(new Error(`Only image files are allowed! Received: ${file.originalname} (${file.mimetype})`));
    }
  }
});

// Get system branding info
router.get('/system', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM system_branding_info');
    const brandingInfo = {};
    
    rows.forEach(row => {
      brandingInfo[row.setting_key] = row.setting_value;
    });
    
    res.json(brandingInfo);
  } catch (error) {
    console.error('Error fetching system branding:', error);
    res.status(500).json({ message: 'Error fetching system branding' });
  }
});

// Update system branding info
router.put('/system', auth, async (req, res) => {
  try {
    const { app_name, logo_url, favicon_url, primary_color, secondary_color, accent_color, theme } = req.body;
    
    // Update or insert branding settings
    const settings = [
      { key: 'app_name', value: app_name },
      { key: 'logo_url', value: logo_url },
      { key: 'favicon_url', value: favicon_url },
      { key: 'primary_color', value: primary_color },
      { key: 'secondary_color', value: secondary_color },
      { key: 'accent_color', value: accent_color },
      { key: 'theme', value: theme }
    ];
    
    for (const setting of settings) {
      if (setting.value !== undefined) {
        await pool.query(
          'INSERT INTO system_branding_info (setting_key, setting_value, setting_type) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE setting_value = ?',
          [setting.key, setting.value, 'string', setting.value]
        );
      }
    }
    
    res.json({ message: 'System branding updated successfully' });
  } catch (error) {
    console.error('Error updating system branding:', error);
    res.status(500).json({ message: 'Error updating system branding' });
  }
});

// Upload system logo/favicon
router.post('/system/upload', auth, upload.single('file'), async (req, res) => {
  try {
    console.log('Upload request received:', {
      file: req.file ? req.file.filename : 'No file',
      type: req.body.type,
      user: req.user.id
    });
    
    if (!req.file) {
      console.log('No file uploaded');
      return res.status(400).json({ message: 'No file uploaded' });
    }
    
    const fileUrl = `/uploads/branding/${req.file.filename}`;
    const fileType = req.body.type; // 'logo' or 'favicon'
    
    console.log('File details:', {
      filename: req.file.filename,
      originalname: req.file.originalname,
      size: req.file.size,
      mimetype: req.file.mimetype,
      fileUrl: fileUrl,
      fileType: fileType
    });
    
    // Save file info to branding_files table
    console.log('Saving to branding_files table...');
    await pool.query(
      'INSERT INTO branding_files (file_name, original_name, file_path, file_size, file_type, mime_type, entity_type, entity_id, uploaded_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        req.file.filename,
        req.file.originalname,
        fileUrl,
        req.file.size,
        path.extname(req.file.originalname),
        req.file.mimetype,
        'system',
        null, // entity_id is null for system files
        req.user.id
      ]
    );
    console.log('File info saved to branding_files table');
    
    // Update system branding info
    const settingKey = fileType === 'favicon' ? 'favicon_url' : 'logo_url';
    console.log('Updating system branding info with key:', settingKey);
    await pool.query(
      'INSERT INTO system_branding_info (setting_key, setting_value, setting_type) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE setting_value = ?',
      [settingKey, fileUrl, 'file', fileUrl]
    );
    console.log('System branding info updated');
    
    res.json({ 
      message: 'File uploaded successfully',
      fileUrl: fileUrl,
      fileName: req.file.filename
    });
  } catch (error) {
    console.error('Error uploading file:', error);
    res.status(500).json({ message: `Error uploading file: ${error.message}` });
  }
});

// Get business branding info
router.get('/business/:businessId', auth, async (req, res) => {
  try {
    const { businessId } = req.params;
    
    // Get business branding info
    const [businessRows] = await pool.query(
      'SELECT name, logo, favicon, primary_color, secondary_color, accent_color, theme, branding_enabled, tagline, contact_email, contact_phone, website, address, social_media, business_hours, currency, timezone, language FROM businesses WHERE id = ?',
      [businessId]
    );
    
    if (businessRows.length === 0) {
      return res.status(404).json({ message: 'Business not found' });
    }
    
    const business = businessRows[0];
    
    // Parse JSON fields
    if (business.social_media) {
      business.social_media = JSON.parse(business.social_media);
    }
    if (business.business_hours) {
      business.business_hours = JSON.parse(business.business_hours);
    }
    
    res.json(business);
  } catch (error) {
    console.error('Error fetching business branding:', error);
    res.status(500).json({ message: 'Error fetching business branding' });
  }
});

// Update business branding info
router.put('/business/:businessId', auth, async (req, res) => {
  try {
    const { businessId } = req.params;
    const {
      name, logo, favicon, primary_color, secondary_color, accent_color, theme,
      branding_enabled, tagline, contact_email, contact_phone, website, address,
      social_media, business_hours, currency, timezone, language
    } = req.body;
    
    // Update business branding
    await pool.query(
      `UPDATE businesses SET 
        name = ?, logo = ?, favicon = ?, primary_color = ?, secondary_color = ?, 
        accent_color = ?, theme = ?, branding_enabled = ?, tagline = ?, 
        contact_email = ?, contact_phone = ?, website = ?, address = ?, 
        social_media = ?, business_hours = ?, currency = ?, timezone = ?, language = ?
       WHERE id = ?`,
      [
        name, logo, favicon, primary_color, secondary_color, accent_color, theme,
        branding_enabled, tagline, contact_email, contact_phone, website, address,
        JSON.stringify(social_media), JSON.stringify(business_hours), currency, timezone, language,
        businessId
      ]
    );
    
    res.json({ message: 'Business branding updated successfully' });
  } catch (error) {
    console.error('Error updating business branding:', error);
    res.status(500).json({ message: 'Error updating business branding' });
  }
});

// Upload business logo/favicon
router.post('/business/:businessId/upload', auth, upload.single('file'), async (req, res) => {
  try {
    const { businessId } = req.params;
    
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }
    
    const fileUrl = `/uploads/branding/${req.file.filename}`;
    const fileType = req.body.type; // 'logo' or 'favicon'
    
    // Save file info to branding_files table
    await pool.query(
      'INSERT INTO branding_files (file_name, original_name, file_path, file_size, file_type, mime_type, entity_type, entity_id, uploaded_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        req.file.filename,
        req.file.originalname,
        fileUrl,
        req.file.size,
        path.extname(req.file.originalname),
        req.file.mimetype,
        'business',
        businessId,
        req.user.id
      ]
    );
    
    // Update business branding
    const column = fileType === 'favicon' ? 'favicon' : 'logo';
    await pool.query(
      `UPDATE businesses SET ${column} = ? WHERE id = ?`,
      [fileUrl, businessId]
    );
    
    res.json({ 
      message: 'File uploaded successfully',
      fileUrl: fileUrl,
      fileName: req.file.filename
    });
  } catch (error) {
    console.error('Error uploading business file:', error);
    res.status(500).json({ message: 'Error uploading file' });
  }
});

// Get available themes
router.get('/themes', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM branding_themes WHERE is_active = 1');
    res.json(rows);
  } catch (error) {
    console.error('Error fetching themes:', error);
    res.status(500).json({ message: 'Error fetching themes' });
  }
});

// Get branding files for business
router.get('/business/:businessId/files', auth, async (req, res) => {
  try {
    const { businessId } = req.params;
    
    const [rows] = await pool.query(
      'SELECT * FROM branding_files WHERE entity_type = ? AND entity_id = ? ORDER BY created_at DESC',
      ['business', businessId]
    );
    
    res.json(rows);
  } catch (error) {
    console.error('Error fetching branding files:', error);
    res.status(500).json({ message: 'Error fetching branding files' });
  }
});

// Delete branding file
router.delete('/files/:fileId', auth, async (req, res) => {
  try {
    const { fileId } = req.params;
    
    // Get file info
    const [fileRows] = await pool.query('SELECT * FROM branding_files WHERE id = ?', [fileId]);
    
    if (fileRows.length === 0) {
      return res.status(404).json({ message: 'File not found' });
    }
    
    const file = fileRows[0];
    
    // Delete physical file
    const filePath = path.join(__dirname, '../..', file.file_path);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }
    
    // Delete from database
    await pool.query('DELETE FROM branding_files WHERE id = ?', [fileId]);
    
    // If this was a logo or favicon, update the business record
    if (file.entity_type === 'business') {
      const [businessRows] = await pool.query(
        'SELECT logo, favicon FROM businesses WHERE id = ?',
        [file.entity_id]
      );
      
      if (businessRows.length > 0) {
        const business = businessRows[0];
        let updateQuery = '';
        let updateParams = [];
        
        if (business.logo === file.file_path) {
          updateQuery = 'UPDATE businesses SET logo = NULL WHERE id = ?';
          updateParams = [file.entity_id];
        } else if (business.favicon === file.file_path) {
          updateQuery = 'UPDATE businesses SET favicon = NULL WHERE id = ?';
          updateParams = [file.entity_id];
        }
        
        if (updateQuery) {
          await pool.query(updateQuery, updateParams);
        }
      }
    }
    
    res.json({ message: 'File deleted successfully' });
  } catch (error) {
    console.error('Error deleting file:', error);
    res.status(500).json({ message: 'Error deleting file' });
  }
});

module.exports = router; 