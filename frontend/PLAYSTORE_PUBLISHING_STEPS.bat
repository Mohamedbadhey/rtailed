@echo off
echo ========================================
echo   SmartLedger Play Store Publishing
echo ========================================
echo.

echo Step 1: Generate Signing Key
echo -----------------------------
echo This will create a keystore file to sign your app.
echo You'll be prompted for passwords - REMEMBER THESE!
echo.
pause
call setup_playstore_signing.bat

echo.
echo Step 2: Build Release AAB
echo -------------------------
echo This will build the release version of your app.
echo.
pause
call build_release_aab.bat

echo.
echo Step 3: Prepare Store Listing
echo -----------------------------
echo Now you need to prepare your store listing:
echo.
echo 1. Take screenshots of your app (see PLAYSTORE_LISTING_GUIDE.md)
echo 2. Create a feature graphic (1024x500 pixels)
echo 3. Write app description
echo 4. Prepare privacy policy
echo.
echo See PLAYSTORE_LISTING_GUIDE.md for detailed instructions.
echo.
pause

echo.
echo Step 4: Upload to Google Play Console
echo -------------------------------------
echo 1. Go to https://play.google.com/console
echo 2. Create a new app or select existing app
echo 3. Upload the AAB file from: build\app\outputs\bundle\release\app-release.aab
echo 4. Complete the store listing
echo 5. Submit for review
echo.
echo Your AAB file is ready at: build\app\outputs\bundle\release\app-release.aab
echo.
echo IMPORTANT REMINDERS:
echo - Keep your keystore file and passwords safe!
echo - You cannot change the package name after publishing
echo - First-time apps may take 1-3 days for review
echo - Test your release build before uploading
echo.
echo Good luck with your Play Store submission!
echo.
pause
