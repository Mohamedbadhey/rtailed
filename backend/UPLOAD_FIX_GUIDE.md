# File Upload Fix Guide for Railway Deployment

## Problem
The error `ENOENT: no such file or directory, open 'uploads/products/...'` occurs because Railway's file system is ephemeral, meaning directories created during development don't persist in the deployed environment.

## Solution Implemented

### 1. Automatic Directory Creation
The backend now automatically creates required directories at startup:

```javascript
// In src/index.js
const createUploadsDirectories = () => {
  const uploadsDir = path.join(__dirname, '../uploads');
  const productsDir = path.join(uploadsDir, 'products');
  const brandingDir = path.join(uploadsDir, 'branding');

  try {
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
      console.log('✅ Created uploads directory');
    }
    // ... similar for other directories
  } catch (error) {
    console.error('❌ Error creating uploads directories:', error);
  }
};
```

### 2. Enhanced Multer Configuration
Updated multer to create directories on-demand:

```javascript
// In src/routes/products.js
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, '../../uploads/products');
    
    // Ensure directory exists
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
      console.log('✅ Created uploads/products directory for file upload');
    }
    
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    // Sanitize filename to prevent issues
    const sanitizedName = file.originalname.replace(/[^a-zA-Z0-9.-]/g, '_');
    cb(null, `${Date.now()}-${sanitizedName}`);
  }
});
```

### 3. Error Handling Middleware
Created comprehensive error handling for upload issues:

```javascript
// In src/middleware/uploadErrorHandler.js
const uploadErrorHandler = (error, req, res, next) => {
  if (error.code === 'ENOENT') {
    // Try to create missing directories
    // Return retry message to user
  }
  // ... other error handling
};
```

### 4. Setup Scripts
Added npm scripts to ensure directories exist:

```json
// In package.json
{
  "scripts": {
    "setup": "node setup_uploads_directories.js",
    "postinstall": "node setup_uploads_directories.js"
  }
}
```

## Deployment Steps

### 1. Redeploy to Railway
```bash
# Commit and push your changes
git add .
git commit -m "Fix file upload directories for Railway"
git push origin main
```

### 2. Verify Directory Creation
Check Railway logs for these messages:
```
✅ Created uploads directory
✅ Created uploads/products directory
✅ Created uploads/branding directory
📁 Uploads directories ready
```

### 3. Test File Upload
Try uploading a product image again. The directories should now be created automatically.

## Important Notes

### Railway File System Limitations
- **Ephemeral Storage**: Files uploaded during runtime are lost when the container restarts
- **No Persistence**: The file system is recreated on each deployment
- **Temporary Solution**: This fix ensures uploads work, but files won't persist

### Production Recommendations
For a production environment, consider:

1. **Cloud Storage**: Use AWS S3, Google Cloud Storage, or Cloudinary
2. **CDN**: Serve images through a content delivery network
3. **Database Storage**: Store small images as base64 in the database
4. **External Service**: Use services like Cloudinary for image management

### Example Cloud Storage Implementation
```javascript
// Example with AWS S3
const AWS = require('aws-sdk');
const s3 = new AWS.S3();

const uploadToS3 = async (file, key) => {
  const params = {
    Bucket: process.env.S3_BUCKET,
    Key: key,
    Body: file.buffer,
    ContentType: file.mimetype
  };
  
  return s3.upload(params).promise();
};
```

## Troubleshooting

### If Upload Still Fails

1. **Check Railway Logs**:
   ```bash
   railway logs
   ```

2. **Verify Directory Creation**:
   Look for these log messages:
   ```
   ✅ Created uploads directory
   ✅ Created uploads/products directory
   ```

3. **Test Directory Permissions**:
   The setup script tests write permissions automatically.

4. **Check File Size**:
   Ensure files are under 5MB limit.

### Common Issues

1. **Permission Denied**: Railway should handle this automatically
2. **File Too Large**: Check the 5MB limit
3. **Invalid File Type**: Only .png, .jpg, .jpeg allowed
4. **Network Issues**: Check Railway's status

## Testing

### Local Testing
```bash
# Run setup script
npm run setup

# Start development server
npm run dev

# Test file upload
curl -X POST -F "image=@test.jpg" -F "name=Test Product" http://localhost:3000/api/products
```

### Railway Testing
1. Deploy changes
2. Check logs for directory creation
3. Test file upload through the Flutter app
4. Verify images are served correctly

## Monitoring

### Log Messages to Watch
- ✅ Directory creation success
- ❌ Directory creation errors
- 📁 Upload directory status
- 🔧 Setup script completion

### Health Check
The health endpoint now includes upload directory status:
```json
{
  "status": "OK",
  "message": "Retail Management API is running",
  "uploads": "ready",
  "timestamp": "2025-01-XX..."
}
```

## Future Improvements

1. **Cloud Storage Integration**: Implement S3 or Cloudinary
2. **Image Optimization**: Add image resizing and compression
3. **File Validation**: Enhanced file type and content validation
4. **Upload Progress**: Add progress tracking for large files
5. **Batch Upload**: Support for multiple file uploads

## Support

If issues persist:
1. Check Railway logs for specific error messages
2. Verify environment variables are set correctly
3. Test with smaller files first
4. Contact support with specific error details 