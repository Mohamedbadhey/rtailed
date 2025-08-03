# App Icon Update Guide

## 🎯 **App Name: "No Name"**

The app name has been updated to "No Name" in:
- ✅ Android Manifest
- ✅ App title in main.dart
- ✅ App description

## 🖼️ **Update App Icon with Branding Logo**

### **Step 1: Get Your Branding Logo**
Your branding logos are in: `../backend/uploads/branding/`
- `logo.png` (recommended)
- `file-1754049441639-310495830.png`
- `file-1754049436337-160209782.png`
- `file-1754047811346-749514891.png`

### **Step 2: Generate App Icons**

**Option A: Online Icon Generator (Recommended)**
1. Go to [https://appicon.co/](https://appicon.co/)
2. Upload your branding logo
3. Download the generated icon pack
4. Replace icons in `android/app/src/main/res/mipmap-*`

**Option B: Use the Helper Script**
1. Run `update_app_icon.bat` in this directory
2. Follow the instructions

### **Step 3: Replace Android Icons**

Replace these files with your generated icons:
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`

### **Step 4: Build and Install**

```bash
flutter clean
flutter pub get
flutter build apk --release
```

## 🎉 **Result**

Your app will now:
- ✅ Display as "No Name" on the phone
- ✅ Use your branding logo as the app icon
- ✅ Connect to your Railway backend
- ✅ Have all retail management features

## 📱 **Install on Phone**

1. Transfer the APK to your phone
2. Enable "Install from Unknown Sources"
3. Install the app
4. Test all features with your Railway backend 