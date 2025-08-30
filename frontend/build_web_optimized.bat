@echo off
echo Building optimized Flutter web app...

cd /d "%~dp0"

echo Cleaning previous build...
flutter clean

echo Getting dependencies...
flutter pub get

echo Building optimized web app...
flutter build web ^
  --release ^
  --dart-define=FLUTTER_WEB_USE_SKIA=true ^
  --dart-define=FLUTTER_WEB_USE_CANVASKIT=true ^
  --web-renderer canvaskit ^
  --tree-shake-icons ^
  --split-debug-info=build/debug-info ^
  --obfuscate ^
  --split-per-abi

echo Build complete! Serving from build/web...
echo.
echo To serve locally, run: flutter run -d chrome --web-port 3000
echo Or serve the build folder with: cd build/web && python -m http.server 8000
echo.
pause
