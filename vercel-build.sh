#!/bin/bash

set -e  # Exit on any error

echo "🚀 Starting Flutter web build on Vercel..."

# Install Flutter
echo "📱 Installing Flutter..."
curl -sSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz | tar -xJ
export PATH="$PWD/flutter/bin:$PATH"

# Fix Flutter git ownership issues
echo "🔧 Fixing Flutter git configuration..."
cd ../flutter
git config --global --add safe.directory /vercel/path0/flutter
git config --global --add safe.directory /vercel/path0/flutter/.git
cd ../frontend

# Verify Flutter installation
echo "📱 Flutter version:"
../flutter/bin/flutter --version

# Check Flutter doctor
echo "🔍 Flutter doctor:"
../flutter/bin/flutter doctor

# Clean any existing build
echo "🧹 Cleaning previous build..."
../flutter/bin/flutter clean

# Get dependencies
echo "📦 Getting Flutter dependencies..."
../flutter/bin/flutter pub get

# Verify dependencies resolved
echo "✅ Dependencies resolved successfully"

# Build Flutter web app
echo "🏗️ Building Flutter web app..."
../flutter/bin/flutter build web --release --web-renderer canvaskit

echo "✅ Build completed successfully!"
echo "📁 Build output:"
ls -la build/web/

# Verify key files exist
if [ -f "build/web/index.html" ]; then
    echo "✅ index.html found"
else
    echo "❌ index.html missing"
    exit 1
fi

if [ -f "build/web/main.dart.js" ]; then
    echo "✅ main.dart.js found"
else
    echo "❌ main.dart.js missing"
    exit 1
fi

echo "🎉 All build files verified successfully!"
