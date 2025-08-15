#!/bin/bash

echo "🚀 Starting Flutter web build process..."

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "📥 Flutter not found, downloading..."
    curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.0-stable.tar.xz | tar -xJ
    export PATH="$PATH:$PWD/flutter/bin"
fi

# Verify Flutter installation
echo "🔍 Checking Flutter installation..."
flutter doctor

# Navigate to frontend directory
cd frontend

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Build web app
echo "🌐 Building Flutter web app..."
flutter build web --release --web-renderer canvaskit

# Check if build was successful
if [ -d "build/web" ]; then
    echo "✅ Flutter web build successful!"
    echo "📁 Build directory: $(pwd)/build/web"
    ls -la build/web/
else
    echo "❌ Flutter web build failed!"
    exit 1
fi

# Navigate back to root
cd ..

echo "🎉 Flutter web build process completed!"
