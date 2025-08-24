# 🚀 Deploy Flutter Web App to Vercel

## 📋 Prerequisites

1. **Vercel Account**: Sign up at [vercel.com](https://vercel.com)
2. **GitHub Account**: For connecting your repository
3. **Flutter SDK**: Latest stable version
4. **Node.js**: For Vercel CLI

## 🔧 Setup Steps

### Step 1: Prepare Your Repository

1. **Push to GitHub** (if not already done):
   ```bash
   git add .
   git commit -m "Prepare for Vercel deployment"
   git push origin main
   ```

2. **Ensure web build is ready**:
   ```bash
   cd frontend
   flutter build web --release --web-renderer canvaskit
   ```

### Step 2: Deploy to Vercel

#### Option A: Using Vercel CLI (Recommended)

1. **Install Vercel CLI**:
   ```bash
   npm install -g vercel
   ```

2. **Login to Vercel**:
   ```bash
   vercel login
   ```

3. **Deploy**:
   ```bash
   vercel --prod
   ```

#### Option B: Using Vercel Dashboard

1. **Go to [vercel.com](https://vercel.com)**
2. **Click "New Project"**
3. **Import your GitHub repository**
4. **Configure build settings**:
   - **Framework Preset**: Other
   - **Build Command**: `cd frontend && flutter build web --release --web-renderer canvaskit`
   - **Output Directory**: `frontend/build/web`
   - **Install Command**: `npm install -g @vercel/static`

### Step 3: Configure Environment Variables

In your Vercel project dashboard, add these environment variables:

```
FLUTTER_WEB_RENDERER=canvaskit
NODE_ENV=production
```

### Step 4: Update Backend URLs

After deployment, update your Flutter app's API base URL:

1. **Find your Vercel domain** (e.g., `your-app.vercel.app`)
2. **Update API configuration** in your Flutter app
3. **Ensure backend CORS allows your Vercel domain**

## 🌐 Configuration Files

### vercel.json
This file is already created and configured for:
- ✅ Static file serving
- ✅ API routing to your backend
- ✅ Upload file routing
- ✅ Security headers
- ✅ CORS configuration

### Build Configuration
- **Source**: `frontend/build/web/**`
- **Framework**: `@vercel/static`
- **Routes**: Handles SPA routing and API proxying

## 🔄 Deployment Workflow

### For Updates:
1. **Make changes** to your Flutter code
2. **Build web app**:
   ```bash
   cd frontend
   flutter build web --release --web-renderer canvaskit
   ```
3. **Commit and push** to GitHub
4. **Vercel auto-deploys** (if connected to GitHub)

### Manual Deployment:
```bash
vercel --prod
```

## 🚨 Important Notes

### Backend Requirements:
- ✅ Your backend must be deployed (Railway recommended)
- ✅ CORS must allow your Vercel domain
- ✅ API endpoints must be accessible

### Flutter Web Specifics:
- ✅ Uses CanvasKit renderer for better performance
- ✅ Optimized for production builds
- ✅ Handles routing properly

### Domain Configuration:
- ✅ Custom domains supported
- ✅ HTTPS automatically enabled
- ✅ Global CDN included

## 🎯 Post-Deployment

### 1. Test Your App
- ✅ Login functionality
- ✅ API connections
- ✅ Image uploads
- ✅ All major features

### 2. Performance Monitoring
- ✅ Vercel Analytics
- ✅ Core Web Vitals
- ✅ Error tracking

### 3. Custom Domain (Optional)
- ✅ Add custom domain in Vercel dashboard
- ✅ Configure DNS records
- ✅ SSL certificate automatically managed

## 🔍 Troubleshooting

### Build Failures:
- Check Flutter version: `flutter --version`
- Verify web support: `flutter devices`
- Clear build cache: `flutter clean`

### API Connection Issues:
- Verify backend URL in Vercel config
- Check CORS settings on backend
- Test API endpoints directly

### Image Loading Issues:
- Ensure upload routes are properly configured
- Check file permissions on backend
- Verify CORS headers for uploads

## 📱 Benefits of Vercel Deployment

- ✅ **Global CDN**: Fast loading worldwide
- ✅ **Auto-scaling**: Handles traffic spikes
- ✅ **Zero downtime**: Automatic deployments
- ✅ **Analytics**: Built-in performance monitoring
- ✅ **Custom domains**: Professional URLs
- ✅ **SSL certificates**: Automatic HTTPS
- ✅ **Git integration**: Auto-deploy on push

## 🎉 Success!

After deployment, your Flutter web app will be available at:
- **Vercel URL**: `https://your-app.vercel.app`
- **Custom Domain**: `https://yourdomain.com` (if configured)

Your retail management system will now be accessible from anywhere in the world! 🌍

---

**Need help? Check Vercel's documentation or your deployment logs for specific errors.**
