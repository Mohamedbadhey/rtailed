# Railway Deployment Guide for Flutter Web App

This guide explains how to deploy your Flutter web app on Railway so it runs exactly like when you run `flutter run -d chrome` locally.

## 🚀 Quick Deploy

1. **Push your code to Railway:**
   ```bash
   railway up
   ```

2. **The app will automatically:**
   - Install Flutter
   - Build the Flutter web app
   - Start the Node.js backend
   - Serve the Flutter app at your Railway URL

## 🔧 How It Works

### 1. **Flutter Web Build Process**
- Railway automatically downloads Flutter during build
- Builds the web app with production optimizations:
  ```bash
  flutter build web --release --web-renderer canvaskit --dart-define=FLUTTER_WEB_USE_SKIA=true
  ```

### 2. **Backend Integration**
- The Node.js backend serves both:
  - API endpoints at `/api/*`
  - Flutter web app at all other routes
- Proper MIME types and caching for web assets
- SPA routing support for Flutter navigation

### 3. **Asset Serving**
- Static Flutter assets (JS, WASM, images) with proper caching
- Product images from `/uploads/products/*`
- Branding images from `/uploads/branding/*`

## 📁 File Structure After Deployment

```
your-railway-app/
├── backend/          # Node.js backend
├── frontend/         # Flutter source code
├── frontend/build/web/  # Built Flutter web app (generated)
└── uploads/          # User uploaded files
```

## 🌐 Access Your App

- **Main App**: `https://your-app.railway.app/`
- **API Endpoints**: `https://your-app.railway.app/api/*`
- **Health Check**: `https://your-app.railway.app/`

## 🔍 Troubleshooting

### Flutter Build Issues
```bash
# Check Flutter installation
flutter doctor

# Clean and rebuild
flutter clean
flutter pub get
flutter build web
```

### Backend Issues
```bash
# Check logs
railway logs

# Restart service
railway service restart
```

### Asset Loading Issues
- Ensure `flutter build web` completed successfully
- Check that `frontend/build/web/` directory exists
- Verify MIME types in browser dev tools

## 🎯 Key Features

✅ **Native App Experience**: Runs exactly like `flutter run -d chrome`  
✅ **Production Optimized**: CanvasKit renderer with Skia  
✅ **Proper Caching**: Long-term caching for web assets  
✅ **SPA Routing**: Flutter navigation works correctly  
✅ **API Integration**: Backend serves both app and API  
✅ **File Uploads**: Product and branding image support  

## 🚀 Local Development

```bash
# Build Flutter web for development
npm run build:web:dev

# Start backend in development mode
npm run dev

# Full production build
npm run build:web
```

## 📱 Browser Compatibility

- **Chrome**: Full support with CanvasKit
- **Firefox**: Full support with CanvasKit  
- **Safari**: Full support with CanvasKit
- **Edge**: Full support with CanvasKit

## 🔒 Security Features

- CORS properly configured for web app
- Helmet.js security headers
- Input validation with Joi
- JWT authentication
- File upload restrictions

Your Flutter app will now run on Railway exactly like it does locally with `flutter run -d chrome`! 🎉
