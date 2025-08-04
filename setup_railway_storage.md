# Railway Persistent Storage Setup Guide

## Problem
Images aren't displaying on Railway because the file system is ephemeral - uploaded files get lost when the container restarts.

## Solution
Use Railway's persistent storage volumes to store uploaded files.

## Setup Steps

### 1. Create a Volume in Railway Dashboard
1. Go to your Railway project dashboard
2. Click on "New" → "Volume"
3. Name it `uploads`
4. Set the mount path to `/data/uploads`
5. Click "Deploy"

### 2. Set Environment Variable
1. Go to your backend service in Railway
2. Click on "Variables" tab
3. Add a new variable:
   - **Name**: `RAILWAY_VOLUME_MOUNT_PATH`
   - **Value**: `/data`
4. Click "Add"

### 3. Redeploy Your Application
1. Go to your backend service
2. Click "Deploy" to trigger a new deployment
3. Wait for the deployment to complete

## Alternative Solutions

### Option 2: Use Cloud Storage (Recommended for Production)
For better scalability, consider using cloud storage services:

#### AWS S3
```bash
npm install @aws-sdk/client-s3 multer-s3
```

#### Google Cloud Storage
```bash
npm install @google-cloud/storage multer-gcs
```

#### Cloudinary
```bash
npm install cloudinary multer-storage-cloudinary
```

### Option 3: Use Railway's Built-in Storage
Railway also offers built-in storage solutions that can be configured through their dashboard.

## Verification
After setup:
1. Upload a product image
2. Check if the image displays correctly
3. Restart your Railway service
4. Verify the image still displays (it should persist)

## File Structure
With persistent storage, your files will be stored at:
```
/data/uploads/
├── products/
│   ├── 1234567890-image1.jpg
│   └── 1234567891-image2.png
└── branding/
    ├── logo.png
    └── favicon.ico
```

## Troubleshooting
- If images still don't show, check the Railway logs for any errors
- Verify the volume is properly mounted by checking the deployment logs
- Ensure the `RAILWAY_VOLUME_MOUNT_PATH` environment variable is set correctly 