#!/usr/bin/env python3
"""
Generate Android app icons from branding logo
"""

import os
from PIL import Image, ImageDraw

def create_icon(size, output_path):
    """Create an icon of the specified size"""
    try:
        # Open the original logo
        with Image.open("app_icon.png") as img:
            # Convert to RGBA if needed
            if img.mode != 'RGBA':
                img = img.convert('RGBA')
            
            # Resize to the target size
            img = img.resize((size, size), Image.Resampling.LANCZOS)
            
            # Create a new image with the target size
            icon = Image.new('RGBA', (size, size), (0, 0, 0, 0))
            
            # Paste the resized logo
            icon.paste(img, (0, 0))
            
            # Save the icon
            icon.save(output_path, 'PNG')
            print(f"✅ Created {output_path} ({size}x{size})")
            
    except Exception as e:
        print(f"❌ Error creating {output_path}: {e}")

def main():
    """Generate all required icon sizes"""
    print("🎨 Generating Android app icons from branding logo...")
    print()
    
    # Check if app_icon.png exists
    if not os.path.exists("app_icon.png"):
        print("❌ app_icon.png not found!")
        print("Please copy your branding logo to app_icon.png first.")
        return
    
    # Android icon sizes
    icon_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192
    }
    
    # Create icons for each size
    for folder, size in icon_sizes.items():
        # Create folder if it doesn't exist
        folder_path = f"android/app/src/main/res/{folder}"
        os.makedirs(folder_path, exist_ok=True)
        
        # Generate icon
        output_path = f"{folder_path}/ic_launcher.png"
        create_icon(size, output_path)
    
    print()
    print("🎉 All app icons generated successfully!")
    print()
    print("📱 Next steps:")
    print("1. Run: flutter clean")
    print("2. Run: flutter pub get")
    print("3. Run: flutter build apk --release")
    print("4. Install the APK on your phone")
    print()
    print("Your app will now display as 'No Name' with your branding logo!")

if __name__ == "__main__":
    main() 