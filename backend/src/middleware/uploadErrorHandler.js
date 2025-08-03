/**
 * Middleware to handle file upload errors
 */

const uploadErrorHandler = (error, req, res, next) => {
  console.error('File upload error:', error);

  // Handle specific multer errors
  if (error.code === 'LIMIT_FILE_SIZE') {
    return res.status(400).json({
      status: 'error',
      message: 'File size too large. Maximum size is 5MB.'
    });
  }

  if (error.code === 'LIMIT_UNEXPECTED_FILE') {
    return res.status(400).json({
      status: 'error',
      message: 'Unexpected file field. Please check your form data.'
    });
  }

  if (error.message && error.message.includes('Only')) {
    return res.status(400).json({
      status: 'error',
      message: error.message
    });
  }

  // Handle file system errors
  if (error.code === 'ENOENT') {
    console.error('Directory not found error:', error.path);
    
    // Try to create the directory
    const fs = require('fs');
    const path = require('path');
    
    try {
      const uploadsDir = path.join(__dirname, '../../uploads');
      const productsDir = path.join(uploadsDir, 'products');
      const brandingDir = path.join(uploadsDir, 'branding');

      // Create directories if they don't exist
      if (!fs.existsSync(uploadsDir)) {
        fs.mkdirSync(uploadsDir, { recursive: true });
      }
      if (!fs.existsSync(productsDir)) {
        fs.mkdirSync(productsDir, { recursive: true });
      }
      if (!fs.existsSync(brandingDir)) {
        fs.mkdirSync(brandingDir, { recursive: true });
      }

      console.log('✅ Created missing upload directories');
      
      // Return a retry message
      return res.status(500).json({
        status: 'error',
        message: 'Upload directories were missing and have been created. Please try uploading again.',
        retry: true
      });
    } catch (createError) {
      console.error('Failed to create upload directories:', createError);
      return res.status(500).json({
        status: 'error',
        message: 'Server configuration error. Please contact support.'
      });
    }
  }

  // Handle permission errors
  if (error.code === 'EACCES') {
    return res.status(500).json({
      status: 'error',
      message: 'Server permission error. Please contact support.'
    });
  }

  // Generic error response
  res.status(500).json({
    status: 'error',
    message: 'File upload failed. Please try again.',
    ...(process.env.NODE_ENV === 'development' && { details: error.message })
  });
};

module.exports = uploadErrorHandler; 