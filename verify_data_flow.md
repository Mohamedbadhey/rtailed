# Data Flow Verification Guide

## Overview
This guide helps verify that the backend and frontend are correctly fetching and displaying deleted data.

## Backend Verification

### 1. Database Schema Check
✅ **Verified Issues Fixed:**
- Added missing `is_deleted` columns to `customers` and `categories` tables
- Added proper foreign key constraints
- Fixed recovery stats queries to include `is_deleted = 1` condition

### 2. API Endpoints Check
✅ **Verified Endpoints:**
- `GET /api/admin/deleted-data` - Global deleted data
- `GET /api/admin/businesses/:businessId/deleted-data` - Business-specific deleted data
- `GET /api/admin/businesses/:businessId/recovery-stats` - Recovery statistics

### 3. Run Backend Test
```bash
cd backend
./test_deleted_data.bat
```

**Expected Output:**
- ✅ Login successful
- ✅ Global deleted data response with counts
- ✅ Business deleted data response with counts
- ✅ Recovery stats with proper counts
- ✅ Data structure validation
- ✅ Error handling test

## Frontend Verification

### 1. Type Conversion Check
✅ **Verified Fixes:**
- Created `TypeConverter` utility class
- Fixed all `LinkedMap<dynamic, dynamic>` to `Map<String, dynamic>` conversions
- Fixed all `int` to `String` conversion errors
- Updated all API service methods to use safe conversions

### 2. UI Components Check
✅ **Verified Fixes:**
- Fixed RenderFlex overflow in dialogs
- Added proper error handling
- Fixed setState during build issues
- Added safe data display methods

### 3. Run Frontend Test
```bash
cd frontend
flutter test test_frontend_data_display.dart
```

**Expected Output:**
- ✅ TypeConverter tests pass
- ✅ Data display tests pass
- ✅ Error handling tests pass

## Manual Testing Steps

### 1. Start Backend
```bash
cd backend
npm start
```

### 2. Start Frontend
```bash
cd frontend
flutter run -d chrome
```

### 3. Test Deleted Data Flow
1. **Login as superadmin:**
   - Email: `s@gmail.com`
   - Password: `123456`

2. **Navigate to Deleted Tab:**
   - Click on "Deleted" tab in superadmin dashboard
   - Should load without errors

3. **Check Data Display:**
   - Users should show username
   - Products should show name and price
   - Sales should show ID and amount
   - All data should be properly formatted

4. **Test Recovery:**
   - Click "Restore" button on any deleted item
   - Should show success message
   - Item should disappear from deleted list

5. **Test Business-Specific Data:**
   - Click on a business to view its deleted data
   - Should show business-specific deleted items
   - Should show proper counts in tabs

## Expected Results

### Backend API Responses
```json
{
  "users": [
    {
      "id": 1,
      "username": "testuser",
      "email": "test@example.com",
      "is_deleted": true,
      "business_id": 6
    }
  ],
  "products": [
    {
      "id": 1,
      "name": "Test Product",
      "price": 100.0,
      "is_deleted": true,
      "business_id": 6
    }
  ],
  "sales": [
    {
      "id": 1,
      "total_amount": 150.0,
      "is_deleted": true,
      "business_id": 6
    }
  ]
}
```

### Frontend Display
- **Users Tab:** "testuser (ID: 1)"
- **Products Tab:** "Test Product (ID: 1)"
- **Sales Tab:** "Sale #1 - $150.00"
- **No Type Errors:** No LinkedMap or int/String conversion errors
- **No UI Errors:** No RenderFlex overflow or setState during build errors

## Troubleshooting

### If Backend Test Fails:
1. Check if MySQL is running
2. Verify database schema is updated
3. Check if backend server is running on port 3000
4. Verify authentication token is valid

### If Frontend Test Fails:
1. Run `flutter clean && flutter pub get`
2. Check if all imports are correct
3. Verify TypeConverter is properly imported
4. Check for any remaining type conversion issues

### If Manual Test Fails:
1. Check browser console for errors
2. Check backend logs for API errors
3. Verify database has deleted data
4. Check if all required columns exist

## Success Criteria
- ✅ Backend test passes with all endpoints working
- ✅ Frontend test passes with all type conversions working
- ✅ Manual test shows proper data display
- ✅ No errors in browser console
- ✅ No errors in backend logs
- ✅ Deleted data recovery functionality works
- ✅ UI displays data correctly without overflow

## Summary
The deleted data functionality should now work correctly with:
- Proper data fetching from backend
- Safe type conversion in frontend
- Correct data display in UI
- Functional recovery system
- No type errors or UI issues 