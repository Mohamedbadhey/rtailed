# Fix App Name and Icon for Kobciye

## ✅ Changes Made in Code

### 1. Updated Frontend Code
- ✅ Changed `main.dart` title from "SmartLedger" to "Kobciye"
- ✅ Updated default app name fallback in `branding_provider.dart` to "Kobciye"
- ✅ Updated AndroidManifest.xml label to "Kobciye"

## 📋 What You Need to Do

### 1. Update System Branding in Database (Backend)

The app name "SmartLedger" is stored in the database. You need to update it to "Kobciye".

**Option A: Through the App (Recommended)**
1. Log in as superadmin
2. Go to System Branding Settings (or Admin Settings → Branding)
3. Update the "App Name" field to "Kobciye"
4. Save the changes

**Option B: Direct Database Update**
Run this SQL query in your MySQL database:

```sql
UPDATE system_branding_info 
SET setting_value = 'Kobciye' 
WHERE setting_key = 'app_name';

-- If the record doesn't exist, insert it:
INSERT INTO system_branding_info (setting_key, setting_value, setting_type) 
VALUES ('app_name', 'Kobciye', 'string')
ON DUPLICATE KEY UPDATE setting_value = 'Kobciye';
```

### 2. Update App Icon

Your app icon currently shows your ICT solution name instead of "Kobciye". 

**Steps to Fix:**

1. **Create a new app icon:**
   - Design a 512x512 pixel PNG icon
   - Include "Kobciye" text/logo on the icon
   - Make sure it's clear and readable at small sizes

2. **Replace the icon file:**
   - Location: `backend/uploads/branding/logo.png`
   - Replace the existing file with your new "Kobciye" icon

3. **Update Android launcher icon:**
   - After replacing the logo.png file, run:
   ```bash
   cd frontend
   flutter pub run flutter_launcher_icons
   ```
   Or use the batch file:
   ```bash
   update_app_icon.bat
   ```

4. **Update system branding in app:**
   - Log in as superadmin
   - Go to System Branding Settings
   - Upload the new logo (it should update automatically)

### 3. Update Screenshots for Play Store

Since your screenshots show "SmartLedger" on the login page:

1. **After updating the database:**
   - Open the app
   - Go to the login screen
   - Take new screenshots showing "Kobciye" instead of "SmartLedger"

2. **Update Play Store screenshots:**
   - Go to Google Play Console
   - Navigate to: Store presence → Main store listing → Screenshots
   - Upload the new screenshots showing "Kobciye"

### 4. Verify Everything

Before resubmitting to Play Store:

- [ ] App name in database = "Kobciye"
- [ ] Login screen shows "Kobciye" (not "SmartLedger")
- [ ] App icon shows "Kobciye" (not ICT solution name)
- [ ] AndroidManifest.xml label = "Kobciye"
- [ ] New screenshots show "Kobciye"
- [ ] Play Store listing name = "Kobciye"

## 🔍 How to Check Current App Name

1. Open the app
2. Go to login screen
3. The app name displayed should be "Kobciye"
4. If it still shows "SmartLedger", update the database as described above

## 📱 After Making Changes

1. Rebuild the app:
   ```bash
   cd frontend
   flutter clean
   flutter pub get
   flutter build appbundle --release
   ```

2. Test the app:
   - Install on a test device
   - Verify login screen shows "Kobciye"
   - Verify app icon shows "Kobciye"

3. Update Play Store listing:
   - Upload new screenshots
   - Verify app name is "Kobciye"
   - Resubmit for review

## 🎨 App Icon Requirements

- **Size:** 512x512 pixels (PNG format)
- **Content:** Should clearly show "Kobciye"
- **Background:** Transparent or solid color
- **Readability:** Text should be readable at small sizes (icon appears small on devices)

## ⚠️ Important Notes

- The app name comes from the database first, then falls back to "Kobciye" in code
- If you don't update the database, it will still show "SmartLedger" from the backend
- The icon file path is: `backend/uploads/branding/logo.png`
- After updating the logo, you need to regenerate the Android launcher icons

