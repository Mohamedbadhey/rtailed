@echo off
echo Starting Retail Management Frontend...
echo.

cd frontend

echo Getting Flutter dependencies...
flutter pub get

echo.
echo Starting Flutter web server...
echo Frontend will be available at: https://rtailed-production.up.railway.app:8080
echo.

flutter run -d web-server --web-port 8080

pause 