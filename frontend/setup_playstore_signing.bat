@echo off
echo Setting up Play Store signing for SmartLedger...

REM Create android/key.properties file if it doesn't exist
if not exist "android\key.properties" (
    echo Creating key.properties file...
    echo storePassword=your_store_password_here > android\key.properties
    echo keyPassword=your_key_password_here >> android\key.properties
    echo keyAlias=upload >> android\key.properties
    echo storeFile=upload-keystore.jks >> android\key.properties
    echo.
    echo IMPORTANT: Edit android\key.properties and replace the placeholder passwords with your actual passwords!
    echo.
)

REM Generate keystore if it doesn't exist
if not exist "android\app\upload-keystore.jks" (
    echo Generating upload keystore...
    echo You will be prompted to enter passwords and information for the keystore.
    echo.
    echo IMPORTANT: Remember these passwords - you'll need them to update your app!
    echo.
    keytool -genkey -v -keystore android\app\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
    echo.
    echo Keystore generated successfully!
) else (
    echo Keystore already exists.
)

echo.
echo Next steps:
echo 1. Edit android\key.properties with your actual passwords
echo 2. Run build_release_aab.bat to build the release AAB
echo 3. Upload the AAB to Google Play Console
echo.
pause
