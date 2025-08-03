# 🚀 Railway Deployment Guide for Retail Management System

## 📋 Prerequisites

- GitHub account
- Railway account (free at [railway.app](https://railway.app))
- Your code pushed to GitHub

## 🎯 Step-by-Step Deployment

### Step 1: Push Your Code to GitHub

```bash
# Initialize git if not already done
git init

# Add all files
git add .

# Commit changes
git commit -m "Ready for Railway deployment"

# Add your GitHub repository as remote
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git

# Push to GitHub
git push -u origin main
```

### Step 2: Deploy to Railway

1. **Go to Railway**: Visit [railway.app](https://railway.app) and sign up/login
2. **Create New Project**: Click "New Project"
3. **Deploy from GitHub**: Select "Deploy from GitHub repo"
4. **Select Repository**: Choose your retail management repository
5. **Railway will automatically detect** it's a Node.js project

### Step 3: Set Up Database

1. **Add MySQL Database**:
   - In your Railway project, click "New"
   - Select "Database" → "MySQL"
   - Railway will create a MySQL database

2. **Get Database Credentials**:
   - Click on your MySQL database
   - Go to "Connect" tab
   - Copy the connection details

### Step 4: Configure Environment Variables

In your Railway project settings, add these environment variables:

```
DB_HOST=your-railway-mysql-host
DB_USER=your-railway-mysql-user
DB_PASSWORD=your-railway-mysql-password
DB_NAME=your-railway-mysql-database
JWT_SECRET=your-super-secret-jwt-key-change-this
NODE_ENV=production
CORS_ORIGIN=*
ADMIN_CODE=SUPERADMIN2024
```

### Step 5: Set Up Database Schema

1. **Connect to MySQL**:
   - Go to your MySQL database in Railway
   - Click "Connect" → "MySQL"
   - Copy the connection string

2. **Import Your Exact Database**:
   - **Option A**: Use Railway's built-in SQL editor
     - Go to your MySQL database in Railway
     - Click "Query" tab
     - Copy the entire content of `backend/retail_management (3).sql`
     - Paste and execute the script
   
   - **Option B**: Use a MySQL client
     - Connect to your Railway MySQL database
     - Import the file `backend/retail_management (3).sql`
   
   - **Option C**: Use Railway's file import
     - Upload `backend/retail_management (3).sql` directly to Railway

### Step 6: Test Your Deployment

Your API will be available at: `https://your-app-name.railway.app`

Test the health endpoint:
```
https://your-app-name.railway.app/api/health
```

### Step 7: Update Frontend Configuration

Update your Flutter app's API base URL:

```dart
// In lib/services/api_service.dart
static const String baseUrl = 'https://your-app-name.railway.app';
```

## 🔧 Railway Configuration Files

### `backend/railway.json`
- Configures Railway deployment settings
- Sets health check endpoint
- Defines restart policies

### `backend/env.example`
- Template for environment variables
- Copy values to Railway environment variables

### `backend/retail_management (3).sql`
- Your exact database with all advanced features
- Includes multi-tenant support, billing, branding, etc.
- Import this file directly to Railway MySQL database

## 📊 Railway Free Tier Limits

- **500 hours/month** of runtime
- **1GB RAM** per service
- **Shared CPU**
- **Sleeps after 15 minutes** of inactivity
- **Automatic deployments** from GitHub

## 🚨 Important Notes

### Database Connection
- Railway provides the database credentials automatically
- Use the environment variables provided by Railway
- The database is persistent and survives deployments

### File Uploads
- Railway provides persistent storage
- Uploads are stored in the `/uploads` directory
- Files persist between deployments

### Environment Variables
- Set all required environment variables in Railway dashboard
- Never commit sensitive data to GitHub
- Use Railway's environment variable system

## 🔍 Troubleshooting

### Common Issues:

1. **Build Fails**
   - Check that `package.json` has correct start script
   - Ensure all dependencies are listed
   - Check Railway logs for specific errors

2. **Database Connection Fails**
   - Verify environment variables are set correctly
   - Check database credentials in Railway
   - Ensure database schema is set up

3. **App Won't Start**
   - Check Railway logs for errors
   - Verify PORT environment variable
   - Ensure all required environment variables are set

4. **Health Check Fails**
   - Verify `/api/health` endpoint exists
   - Check that server is listening on correct port
   - Review Railway logs

### Checking Logs:
- Go to your Railway project
- Click on your service
- Check the "Logs" tab for error messages

## 🎉 Success!

Once deployed, your retail management system will be:
- ✅ **Live on the internet**
- ✅ **Accessible from anywhere**
- ✅ **Automatically deployed** from GitHub
- ✅ **Database backed** with MySQL
- ✅ **File uploads working**
- ✅ **Multi-tenant ready**

## 📱 Next Steps

1. **Test all features** on the live deployment
2. **Update your Flutter app** to use the new API URL
3. **Deploy Flutter web** (optional) to Vercel/Firebase
4. **Set up custom domain** (optional)
5. **Monitor usage** and upgrade if needed

## 💰 Cost

- **Free tier**: 500 hours/month
- **Paid tier**: $5/month for unlimited hours
- **Database**: Included in free tier
- **Storage**: Included in free tier

Your retail management system is now live and free! 🎉 