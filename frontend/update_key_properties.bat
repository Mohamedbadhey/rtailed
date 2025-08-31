@echo off
echo ========================================
echo   Update Key Properties for SmartLedger
echo ========================================
echo.

echo Your keystore has been generated successfully!
echo.
echo Now you need to update the key.properties file with your actual passwords.
echo.
echo The keystore file is located at: android\app\upload-keystore.jks
echo.

echo Please enter the passwords you used when generating the keystore:
echo.

set /p store_password="Enter your keystore password: "
set /p key_password="Enter your key password: "

echo.
echo Updating key.properties file...

echo storePassword=%store_password% > android\key.properties
echo keyPassword=%key_password% >> android\key.properties
echo keyAlias=upload >> android\key.properties
echo storeFile=upload-keystore.jks >> android\key.properties

echo.
echo ✅ Key properties updated successfully!
echo.
echo Your keystore is now ready for Play Store publishing.
echo.
echo Next steps:
echo 1. Run build_release_aab.bat to build the release AAB
echo 2. Upload the AAB to Google Play Console
echo.
pause
