#!/usr/bin/env python3
"""
Update all localhost URLs to Railway URL
"""

import os
import re

def update_urls_in_file(file_path):
    """Update URLs in a single file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Replace localhost URLs with Railway URL
        old_content = content
        content = content.replace('http://localhost:3000', 'https://api.kismayoict.com')
        
        # Only write if content changed
        if content != old_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ Updated: {file_path}")
            return True
        else:
            print(f"⏭️  No changes: {file_path}")
            return False
            
    except Exception as e:
        print(f"❌ Error updating {file_path}: {e}")
        return False

def find_dart_files(directory):
    """Find all Dart files in directory"""
    dart_files = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                dart_files.append(os.path.join(root, file))
    return dart_files

def main():
    """Update all URLs in Dart files"""
    print("🔄 Updating all URLs to Railway backend...")
    print()
    
    # Find all Dart files
    dart_files = find_dart_files('.')
    
    updated_count = 0
    total_count = len(dart_files)
    
    for file_path in dart_files:
        if update_urls_in_file(file_path):
            updated_count += 1
    
    print()
    print(f"🎉 Update complete!")
    print(f"📁 Files processed: {total_count}")
    print(f"✅ Files updated: {updated_count}")
    print()
    print("📱 Next steps:")
    print("1. Run: flutter clean")
    print("2. Run: flutter pub get")
    print("3. Run: flutter build apk --release")
    print()
    print("All URLs now point to: https://api.kismayoict.com")

if __name__ == "__main__":
    main() 