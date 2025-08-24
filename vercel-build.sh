#!/bin/bash

# Install Flutter
echo "🚀 Installing Flutter..."
curl -sSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz | tar -xJ
export PATH="$PWD/flutter/bin:$PATH"

# Verify Flutter installation
echo "📱 Flutter version:"
flutter --version

# Build Flutter web app
echo "🏗️ Building Flutter web app..."
cd frontend
flutter build web --release --web-renderer canvaskit

echo "✅ Build completed!"
ls -la build/web/
