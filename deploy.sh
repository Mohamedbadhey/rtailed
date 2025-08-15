#!/bin/bash

echo "🚀 Starting deployment process..."

# Set error handling
set -e

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: package.json not found. Please run this script from the project root."
    exit 1
fi

# Install Flutter if not available
if ! command -v flutter &> /dev/null; then
    echo "📥 Flutter not found, downloading..."
    curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.0-stable.tar.xz | tar -xJ
    export PATH="$PATH:$PWD/flutter/bin"
    echo "✅ Flutter downloaded and added to PATH"
fi

# Verify Flutter installation
echo "🔍 Checking Flutter installation..."
flutter doctor

# Navigate to frontend directory and build
echo "🌐 Building Flutter web app..."
cd frontend

# Clean and get dependencies
echo "🧹 Cleaning previous builds..."
flutter clean

echo "📦 Getting Flutter dependencies..."
flutter pub get

# Build web app with production settings
echo "🏗️ Building Flutter web app..."
flutter build web \
    --release \
    --web-renderer canvaskit \
    --dart-define=FLUTTER_WEB_USE_SKIA=true \
    --dart-define=FLUTTER_WEB_USE_SKIA_RENDERER=true

# Verify build
if [ ! -d "build/web" ]; then
    echo "❌ Flutter web build failed!"
    exit 1
fi

echo "✅ Flutter web build successful!"
echo "📁 Build directory: $(pwd)/build/web"
ls -la build/web/

# Navigate back to root
cd ..

# Install backend dependencies
echo "📦 Installing backend dependencies..."
npm install

# Create necessary directories
echo "📁 Setting up uploads directories..."
node backend/setup_uploads_directories.js

echo "🎉 Deployment setup completed!"
echo "🚀 Starting the application..."

# Start the application
npm start
