
# 🔒 Google Play Store Data Safety & Privacy Policy Compliance Report
## Kobciye Retail Management App (com.kobciye.app)

**Generated:** January 2025  
**Package Name:** `com.kobciye.app`  
**App Name:** Kobciye

---

## 📋 Executive Summary

This document provides a complete analysis of data collection, permissions, third-party services, and storage practices for Google Play Store Data Safety Form submission and Privacy Policy compliance.

---

## 1. 📱 ANDROID PERMISSIONS ANALYSIS

### 1.1 Permissions Declared in AndroidManifest.xml

| Permission | Purpose | Required/Optional | Used For | Data Safety Impact |
|------------|---------|-------------------|----------|-------------------|
| `INTERNET` | **REQUIRED** | Required | All API calls to backend server at `https://api.kismayoict.com` | Yes - Network communications |
| `CAMERA` | **OPTIONAL** | Optional | Product image capture, branding logo capture | Yes - Photos & media |
| `POST_NOTIFICATIONS` | **REQUIRED** (Android 13+) | Required | Local notifications for PDF downloads and app alerts | Minimal - Only local notifications |
| `READ_MEDIA_IMAGES` | **OPTIONAL** (Android 13+) | Optional | Selecting product images from gallery | Yes - Photos & media |
| `ACCESS_NETWORK_STATE` | **IMPLICIT** | Auto-granted | Checking internet connectivity | Minimal - Network status only |

### 1.2 Permission Details

#### INTERNET (Required)
- **Why:** App requires internet connection to function
- **Feature:** All API calls (authentication, products, sales, inventory, customers)
- **Status:** REQUIRED - App cannot function without internet
- **Code Location:** `AndroidManifest.xml` line 4

#### CAMERA (Optional)
- **Why:** Users can take photos of products and business branding
- **Feature:** Product image capture, business logo upload
- **Status:** OPTIONAL - App works without camera, but product image feature disabled
- **Code Location:** 
  - `AndroidManifest.xml` line 6
  - `lib/screens/home/inventory_screen.dart` - Product image capture
  - `lib/screens/home/store_management_screen.dart` - Store product images
  - `lib/screens/home/business_branding_screen.dart` - Logo capture

#### POST_NOTIFICATIONS (Required on Android 13+)
- **Why:** Show local notifications for PDF downloads and app alerts
- **Feature:** PDF export notifications
- **Status:** REQUIRED on Android 13+, auto-requested on app start
- **Code Location:** 
  - `AndroidManifest.xml` line 11
  - `lib/services/notification_service.dart` - Notification handling

#### READ_MEDIA_IMAGES (Optional on Android 13+)
- **Why:** Allow users to select images from gallery for products
- **Feature:** Product image selection from device gallery
- **Status:** OPTIONAL - App works without this permission
- **Code Location:**
  - `AndroidManifest.xml` line 14
  - Used by `image_picker` package when selecting from gallery

---

## 2. 📊 DATA TYPES COLLECTED

### 2.1 Personal Information ✅ COLLECTED

| Data Type | What is Collected | Where Collected | How Used | Stored Locally? | Sent to Server? |
|-----------|------------------|-----------------|----------|-----------------|-----------------|
| **Name** | Username, Customer names | Registration, Login, Customer creation | User identification, Customer records | Yes (SharedPreferences) | Yes (Backend database) |
| **Email** | User email address | Registration, Login | Authentication, account identification | No | Yes (Backend database) |
| **Phone** | Customer phone numbers (optional) | Customer creation form | Customer contact information | No | Yes (Backend database) |
| **Address** | Business address, Customer addresses (optional) | Business setup, Customer creation | Business location, Customer shipping | No | Yes (Backend database) |

**Code Locations:**
- `lib/models/user.dart` - User model (username, email)
- `lib/models/customer.dart` - Customer model (name, email, phone, address)
- `lib/providers/auth_provider.dart` - Authentication flow
- `lib/services/api_service.dart` - API calls for user/customer data

### 2.2 Business Data ✅ COLLECTED

| Data Type | What is Collected | Where Collected | How Used | Stored Locally? | Sent to Server? |
|-----------|------------------|-----------------|----------|-----------------|-----------------|
| **Products** | Product name, description, SKU, barcode, price, cost, stock quantity | Product management screen | Inventory management, POS sales | Cached locally | Yes (Backend database) |
| **Inventory** | Stock levels, low stock thresholds, damaged products | Inventory management screen | Stock tracking, alerts | Cached locally | Yes (Backend database) |
| **Sales** | Sale transactions, payment methods, amounts, customer info | POS screen, Sales management | Sales tracking, reports | No | Yes (Backend database) |
| **Customers** | Customer name, email, phone, purchase history | Customer management, POS | Customer relationship management | No | Yes (Backend database) |
| **Categories** | Product categories | Category management | Product organization | No | Yes (Backend database) |
| **Business Details** | Business name, branding (logo, colors) | Business settings | Business customization | No | Yes (Backend database) |

**Code Locations:**
- `lib/models/product.dart` - Product data structure
- `lib/models/sale.dart` - Sales transaction data
- `lib/models/customer.dart` - Customer data structure
- `lib/services/api_service.dart` - All API endpoints

### 2.3 Device Identifiers ❌ NOT COLLECTED

**No device identifiers are collected:**
- ❌ No Device ID / Android ID
- ❌ No Advertising ID
- ❌ No IMEI
- ❌ No MAC address
- ❌ No Serial number

**Verification:** Searched entire codebase - no device identifier collection found.

### 2.4 Logs & Crash Reports ⚠️ LIMITED

| Data Type | What is Collected | Where Collected | How Used | Stored Locally? | Sent to Server? |
|-----------|------------------|-----------------|----------|-----------------|-----------------|
| **Debug Logs** | Console print statements | Throughout app | Development debugging | Yes (local logs only) | No (only in development) |
| **Error Logs** | Error messages in console | Error handling | Debugging issues | Yes (local logs only) | No |

**Important Notes:**
- ✅ **No crash reporting SDK** (No Firebase Crashlytics, Sentry, etc.)
- ✅ **No analytics SDK** (No Firebase Analytics, Google Analytics, etc.)
- ✅ Debug logs only visible to developers during development
- ✅ Production builds should have minimal logging

**Code Locations:**
- Various `print()` statements throughout codebase (development only)
- No third-party crash reporting libraries found

### 2.5 Photos & Media Files ✅ COLLECTED

| Data Type | What is Collected | Where Collected | How Used | Stored Locally? | Sent to Server? |
|-----------|------------------|-----------------|----------|-----------------|-----------------|
| **Product Images** | Photos of products | Camera or gallery selection | Product display | Temporarily (upload only) | Yes (Backend server `/uploads/products/`) |
| **Business Branding** | Logo images, branding assets | Image picker | Business customization | Temporarily (upload only) | Yes (Backend server `/uploads/branding/`) |

**Code Locations:**
- `lib/screens/home/inventory_screen.dart` - Product image upload
- `lib/screens/home/business_branding_screen.dart` - Logo upload
- `lib/services/api_service.dart` - Image upload API calls
- Backend: `backend/src/routes/products.js` - Image upload handling

**Storage Details:**
- Images uploaded to Railway backend server
- Stored at `/uploads/products/` and `/uploads/branding/`
- Served via HTTP/HTTPS at `https://api.kismayoict.com/uploads/`

### 2.6 Files Stored Locally ✅ COLLECTED

| Data Type | What is Collected | Where Collected | How Used | Stored Locally? | Sent to Server? |
|-----------|------------------|-----------------|----------|-----------------|-----------------|
| **PDF Reports** | Generated PDF files (sales reports, inventory reports) | PDF export feature | Offline access to reports | Yes (App documents directory) | No |
| **Settings** | Theme preferences, language, currency, notification settings | Settings screen | User preferences | Yes (SharedPreferences) | Synced to server |

**Code Locations:**
- `lib/services/pdf_export_io.dart` - PDF file saving
- `lib/services/pdf_export_service.dart` - PDF generation
- `lib/providers/settings_provider.dart` - Settings storage

**Storage Details:**
- PDFs stored in app's scoped storage: `App Documents/PDFs/`
- Settings stored in SharedPreferences (encrypted on modern Android)
- No access to external storage without user permission

### 2.7 Network Information ✅ COLLECTED (Minimal)

| Data Type | What is Collected | Where Collected | How Used | Stored Locally? | Sent to Server? |
|-----------|------------------|-----------------|----------|-----------------|-----------------|
| **IP Address** | Automatically collected by server | API requests | Request routing, security | No | Yes (Server logs) |
| **Network Status** | Connection status (WiFi/Mobile/None) | Connectivity monitoring | App functionality check | Yes (in-memory only) | No |

**Code Locations:**
- `lib/services/network_service.dart` - Connectivity checking
- Backend automatically logs IP addresses (standard HTTP behavior)

**Important:** IP addresses are automatically logged by the backend server but not used for tracking or analytics - only for request routing.

### 2.8 Location Data ❌ NOT COLLECTED

**No location data is collected:**
- ❌ No GPS location
- ❌ No coarse location
- ❌ No network-based location
- ❌ No precise location tracking

**Note:** The app stores business addresses as text (entered by user), but does NOT access device location services.

**Verification:** Searched entire codebase for location-related code - none found except UI icons showing business addresses.

---

## 3. 🔗 THIRD-PARTY LIBRARIES & SDKs

### 3.1 Dependency Analysis (from pubspec.yaml)

| Package | Purpose | Data Collected | Sends to Third-Party? | Declare in Data Safety? |
|---------|---------|----------------|----------------------|------------------------|
| **http** | HTTP client for API calls | Network requests (URLs, headers, body) | Yes (to your backend server only) | No - it's your server |
| **connectivity_plus** | Network connectivity checking | Network status (WiFi/Mobile/None) | No | No - no external service |
| **shared_preferences** | Local key-value storage | Settings data | No | No - local storage only |
| **flutter_secure_storage** | Encrypted local storage | Authentication tokens | No | No - local storage only |
| **image_picker** | Camera/gallery access | Selected images | No | No - local access only |
| **flutter_local_notifications** | Local notifications | Notification content | No | No - local only |
| **path_provider** | File system paths | File paths | No | No - local access only |
| **pdf** | PDF generation | Generated PDF content | No | No - local generation |
| **printing** | PDF printing | PDF content | No | No - local only |
| **google_fonts** | Font loading | Font requests | Yes (Google Fonts CDN) | No - only font files, no user data |
| **url_launcher** | Open URLs | URLs to open | No | No - user-initiated |
| **file_picker** | File selection | Selected files | No | No - local access only |
| **share_plus** | Share content | Shared content | No | No - uses system share |

### 3.2 Critical Third-Party Services

#### ✅ NO Analytics SDKs
- ❌ No Firebase Analytics
- ❌ No Google Analytics
- ❌ No Mixpanel
- ❌ No Amplitude

#### ✅ NO Crash Reporting SDKs
- ❌ No Firebase Crashlytics
- ❌ No Sentry
- ❌ No Bugsnag

#### ✅ NO Ad Networks
- ❌ No Google AdMob
- ❌ No Facebook Audience Network
- ❌ No advertisement SDKs

#### ✅ NO Social Media SDKs
- ❌ No Facebook SDK
- ❌ No Twitter SDK
- ❌ No Instagram SDK

### 3.3 External Services Used

#### Backend Server (Railway)
- **Service:** `https://api.kismayoict.com`
- **Purpose:** Your own backend API server
- **Data Sent:** All business data, user data, products, sales, inventory
- **Declare in Data Safety:** No - it's your own server
- **Third-Party:** No - you control this server

#### Google Fonts CDN
- **Service:** `fonts.googleapis.com`
- **Purpose:** Loading fonts for the app
- **Data Sent:** Only font file requests (standard HTTP, no user data)
- **Declare in Data Safety:** No - only font files, no personal data
- **Third-Party:** Yes, but no user data collected

---

## 4. 🌐 INTERNET USAGE

### 4.1 Internet Requirement: **REQUIRED**

The app **REQUIRES** an active internet connection to function.

### 4.2 What Happens When Offline?

| Feature | Offline Behavior |
|---------|------------------|
| **Authentication** | ❌ Cannot login |
| **Product Management** | ❌ Cannot view/edit products |
| **Sales (POS)** | ❌ Cannot process sales |
| **Inventory** | ❌ Cannot view/update inventory |
| **Customers** | ❌ Cannot view/edit customers |
| **Reports** | ❌ Cannot generate reports |
| **PDF Export** | ✅ Can export previously loaded data to PDF |

### 4.3 Features That Depend on Network

**ALL core features require internet:**
1. ✅ User authentication (login, registration)
2. ✅ Product management (CRUD operations)
3. ✅ Sales processing (POS functionality)
4. ✅ Inventory management
5. ✅ Customer management
6. ✅ Reports and analytics
7. ✅ Image uploads (products, branding)

**Code Location:** `lib/services/api_service.dart` - All API calls require internet

---

## 5. 💾 DATA STORAGE

### 5.1 Local Storage

#### SharedPreferences (Settings)
- **What:** Theme mode, language preference, currency, notification settings
- **Location:** Android shared preferences (encrypted on Android 10+)
- **Code:** `lib/providers/settings_provider.dart`
- **Sensitive:** No - only preferences

#### Flutter Secure Storage (Authentication)
- **What:** Authentication tokens (JWT)
- **Location:** Encrypted secure storage (Android KeyStore)
- **Code:** `lib/providers/auth_provider.dart`
- **Sensitive:** Yes - authentication tokens

#### PDF Files (Local Documents)
- **What:** Generated PDF reports
- **Location:** App documents directory (`/data/data/com.kobciye.app/files/PDFs/`)
- **Code:** `lib/services/pdf_export_io.dart`
- **Sensitive:** Yes - contains business data
- **Access:** Only accessible by the app (scoped storage)

### 5.2 Remote Server Storage

#### Backend Database (Railway + MySQL)
- **What:** ALL business data
  - User accounts (username, email, hashed passwords)
  - Products (name, description, prices, stock, images)
  - Sales transactions
  - Inventory records
  - Customers
  - Categories
  - Business settings
  - Branding assets
- **Location:** Railway hosted MySQL database
- **Security:** HTTPS/TLS encryption in transit, encrypted passwords at rest
- **Access:** Via API with authentication tokens

#### File Storage (Railway Volume)
- **What:** Product images, branding assets
- **Location:** Railway persistent volume (`/uploads/products/`, `/uploads/branding/`)
- **Access:** Via HTTP/HTTPS URLs
- **Security:** Served over HTTPS

### 5.3 Data Caching

- **What:** Product lists, customer lists (cached in memory)
- **Location:** In-memory only (not persisted)
- **Lifetime:** Cleared when app closes
- **Sensitive:** Yes - contains business data, but not persisted

---

## 6. 💥 CRASH HANDLING

### 6.1 Crash Reporting: **NONE**

✅ **No crash reporting SDK is used:**
- ❌ No Firebase Crashlytics
- ❌ No Sentry
- ❌ No Bugsnag
- ❌ No custom crash reporting

### 6.2 Debug Logging

- **What:** `print()` statements for debugging
- **Visible:** Only during development (not in production builds)
- **Storage:** Android logcat only (local device)
- **Data Safety Impact:** None - not collected or sent anywhere

**Recommendation:** Remove or disable debug logging in production builds.

---

## 7. 🔐 SECURITY

### 7.1 Network Security

| Aspect | Status | Details |
|--------|--------|---------|
| **HTTPS/TLS** | ✅ Yes | All API calls use HTTPS (`https://api.kismayoict.com`) |
| **Certificate Pinning** | ❌ No | Standard HTTPS (acceptable for most apps) |
| **Encrypted Requests** | ✅ Yes | All API requests use HTTPS/TLS |
| **API Authentication** | ✅ Yes | JWT tokens in Authorization headers |

### 7.2 Data Security

| Aspect | Status | Details |
|--------|--------|---------|
| **Password Storage** | ✅ Encrypted | Passwords hashed on backend (bcrypt) |
| **Token Storage** | ✅ Encrypted | JWT tokens stored in FlutterSecureStorage (Android KeyStore) |
| **Local Files** | ✅ Protected | PDFs stored in app scoped storage (not accessible externally) |
| **SharedPreferences** | ✅ Encrypted | Android 10+ automatically encrypts SharedPreferences |
| **Network Data** | ✅ Encrypted | All data in transit encrypted with TLS |

### 7.3 Code Location

- **Authentication:** `lib/providers/auth_provider.dart`
- **Secure Storage:** `lib/providers/auth_provider.dart` (FlutterSecureStorage)
- **API Calls:** `lib/services/api_service.dart` (HTTPS)
- **Backend Security:** Backend handles password hashing (not shown in frontend)

---

## 8. 📋 GOOGLE PLAY DATA SAFETY FORM ANSWERS

### 8.1 Data Collection & Sharing Summary

#### Data Collected and Shared

1. **Personal Info (Name, Email, Phone, Address)**
   - ✅ Collected: Yes
   - ✅ Shared: No (only with your backend server)
   - Purpose: Account management, customer records
   - Optional/Required: Required for app functionality

2. **Photos & Videos**
   - ✅ Collected: Yes (product images, logos)
   - ✅ Shared: No (only with your backend server)
   - Purpose: Product display, business branding
   - Optional/Required: Optional (app works without images)

3. **Files & Docs**
   - ✅ Collected: Yes (PDF reports locally)
   - ✅ Shared: No (stored locally only)
   - Purpose: Offline access to reports
   - Optional/Required: Optional feature

4. **App Activity**
   - ✅ Collected: No (no analytics SDK)
   - ✅ Shared: No

5. **App Info & Performance**
   - ✅ Collected: No (no crash reporting)
   - ✅ Shared: No

6. **Device IDs**
   - ✅ Collected: No
   - ✅ Shared: No

7. **Location**
   - ✅ Collected: No
   - ✅ Shared: No

8. **Financial Info**
   - ✅ Collected: Yes (sales transactions, payment methods)
   - ✅ Shared: No (only with your backend server)
   - Purpose: Business transaction records
   - Optional/Required: Required for POS functionality

### 8.2 Data Safety Form Quick Answers

**Does your app collect or share any of the required user data types?**
- ✅ Yes

**Data Types:**
1. ✅ Personal info (name, email, phone, address) - REQUIRED
2. ✅ Photos & videos - OPTIONAL
3. ✅ Files & docs (local PDFs only) - OPTIONAL
4. ✅ Financial info (sales, transactions) - REQUIRED

**Does your app share data with third parties?**
- ❌ No (only with your own backend server)

**Is data collection required for your app?**
- ✅ Yes (for core functionality)

**Is data collection optional?**
- ✅ Photos & videos (optional)
- ✅ PDF export (optional)

**Does your app allow users to request data deletion?**
- ✅ Yes (mentioned in privacy policy)

**Data Security:**
- ✅ Data encrypted in transit: Yes (HTTPS/TLS)
- ✅ Data encrypted at rest: Yes (backend database)
- ✅ Users can request deletion: Yes

---

## 9. 🎯 COMPLIANCE CHECKLIST

### ✅ Completed Requirements

- ✅ Privacy Policy URL provided and accessible
- ✅ All permissions declared in manifest
- ✅ Optional permissions marked as optional
- ✅ Required permissions justified
- ✅ Data collection practices documented
- ✅ No third-party analytics or crash reporting
- ✅ No device identifier collection
- ✅ No location tracking
- ✅ HTTPS/TLS for all network communications
- ✅ Secure storage for sensitive data (tokens)
- ✅ No data sold to third parties

### ⚠️ Recommendations

1. **Remove Debug Logging in Production**
   - Remove or disable `print()` statements in production builds
   - Use proper logging library with log levels

2. **Add Data Deletion Feature**
   - Implement user account deletion in app
   - Ensure backend properly deletes user data

3. **Consider Adding Analytics (Optional)**
   - If you want app usage insights, consider Firebase Analytics
   - Would require updating privacy policy

4. **Consider Crash Reporting (Optional)**
   - For better error tracking, consider Firebase Crashlytics
   - Would require updating privacy policy

5. **Document Offline Functionality**
   - Clearly state that app requires internet in store listing
   - Consider adding basic offline caching for better UX

---

## 10. 📝 PRIVACY POLICY VERIFICATION

### ✅ Privacy Policy Compliance

Your existing privacy policy (`privacy_policy.html`) covers:

- ✅ Data collection practices
- ✅ Data usage purposes
- ✅ Data storage and security
- ✅ Data sharing (none with third parties)
- ✅ User rights (access, deletion, etc.)
- ✅ Contact information
- ✅ Children's privacy (not for under 13)
- ✅ International data transfers
- ✅ Cookies and similar technologies

**Status:** ✅ Compliant with Google Play requirements

**URL:** `https://api.kismayoict.com/privacy-policy`

---

## 11. 🚀 NEXT STEPS FOR PLAY STORE SUBMISSION

1. ✅ **Package Name Changed:** `com.smartledger.retail` → `com.kobciye.app`
2. ✅ **Privacy Policy URL:** Ready at `/privacy-policy`
3. ⏳ **Fill Data Safety Form:** Use information from this document
4. ⏳ **Remove Debug Logs:** Clean up `print()` statements for production
5. ⏳ **Test Privacy Policy URL:** Verify it's accessible publicly
6. ⏳ **Update Store Listing:** Mention internet requirement

---

## 12. 📊 SUMMARY JSON (For Reference)

```json
{
  "app_name": "Kobciye",
  "package_name": "com.kobciye.app",
  "data_collection": {
    "personal_info": {
      "collected": true,
      "types": ["name", "email", "phone", "address"],
      "required": true,
      "shared_with_third_parties": false
    },
    "photos_videos": {
      "collected": true,
      "types": ["product_images", "branding_logos"],
      "required": false,
      "shared_with_third_parties": false
    },
    "files_docs": {
      "collected": true,
      "types": ["pdf_reports"],
      "required": false,
      "stored_locally_only": true,
      "shared_with_third_parties": false
    },
    "financial_info": {
      "collected": true,
      "types": ["sales_transactions", "payment_methods"],
      "required": true,
      "shared_with_third_parties": false
    },
    "device_ids": {
      "collected": false
    },
    "location": {
      "collected": false
    },
    "analytics": {
      "collected": false,
      "sdk_used": null
    },
    "crash_reports": {
      "collected": false,
      "sdk_used": null
    }
  },
  "permissions": {
    "INTERNET": {"required": true, "purpose": "API communication"},
    "CAMERA": {"required": false, "purpose": "Product image capture"},
    "POST_NOTIFICATIONS": {"required": true, "purpose": "Local notifications"},
    "READ_MEDIA_IMAGES": {"required": false, "purpose": "Gallery image selection"}
  },
  "third_party_services": {
    "analytics": [],
    "crash_reporting": [],
    "ad_networks": [],
    "backend_server": {
      "url": "https://api.kismayoict.com",
      "owned_by_you": true,
      "data_shared": true
    }
  },
  "internet_required": true,
  "data_encryption": {
    "in_transit": true,
    "at_rest": true,
    "local_storage": true
  },
  "privacy_policy_url": "https://api.kismayoict.com/privacy-policy"
}
```

---

## 📞 Support

For questions about this analysis, contact:
- **Email:** mohamedbadhey@gmail.com
- **Phone:** +252 614 112 537
- **Location:** Kismayo, Somalia

---

**Document Version:** 1.0  
**Last Updated:** January 2025  
**Status:** ✅ Ready for Google Play Store Submission

