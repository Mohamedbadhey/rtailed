import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:toast/toast.dart';

abstract class PdfExportPlatform {
  static Future<Map<String, dynamic>> savePdf(Uint8List pdfBytes, String fileName) async {
    try {
      Directory? output;
      String userFriendlyPath = '';
      
      // For Android, request storage permissions first
      if (Platform.isAndroid) {
        // Request storage permissions
        Map<Permission, PermissionStatus> statuses = await [
          Permission.storage,
          Permission.manageExternalStorage,
        ].request();
        
        print('🔍 PDF: Permission statuses: $statuses');
        
        // Check if permissions are granted
        if (statuses[Permission.storage] != PermissionStatus.granted &&
            statuses[Permission.manageExternalStorage] != PermissionStatus.granted) {
          return {
            'success': false,
            'error': 'Storage permission denied',
            'message': 'Please grant storage permission to save PDF files',
          };
        }
        
        try {
          // For Android, try to get the user's Downloads directory
          if (Platform.isAndroid) {
            // Try multiple possible Downloads paths that users can access
            final downloadsPaths = [
              '/storage/emulated/0/Download',
              '/storage/emulated/0/Downloads', 
              '/sdcard/Download',
              '/sdcard/Downloads',
            ];
            
            for (String path in downloadsPaths) {
              final testDir = Directory(path);
              if (await testDir.exists()) {
                output = testDir;
                userFriendlyPath = 'Downloads folder';
                print('🔍 PDF: Found Downloads directory: $path');
                break;
              }
            }
            
            // If no Downloads folder found, try external storage
            if (output == null) {
              final List<Directory>? directories = await getExternalStorageDirectories();
              if (directories != null && directories.isNotEmpty) {
                for (Directory dir in directories) {
                  final downloadsDir = Directory('${dir.path}/Download');
                  if (await downloadsDir.exists()) {
                    output = downloadsDir;
                    userFriendlyPath = 'Downloads folder';
                    print('🔍 PDF: Using external Downloads: ${downloadsDir.path}');
                    break;
                  }
                }
              }
            }
            
            // Last resort: create Downloads in external storage
            if (output == null) {
              final externalDir = await getExternalStorageDirectory();
              if (externalDir != null) {
                final downloadsDir = Directory('${externalDir.path}/Download');
                await downloadsDir.create(recursive: true);
                output = downloadsDir;
                userFriendlyPath = 'Downloads folder';
                print('🔍 PDF: Created Downloads: ${downloadsDir.path}');
              }
            }
          }
          
          // Fallback to app documents directory
          if (output == null) {
            output = await getApplicationDocumentsDirectory();
            userFriendlyPath = 'App Documents folder';
            print('🔍 PDF: Using app documents: ${output.path}');
          }
        } catch (e) {
          print('🔍 PDF: Error accessing storage: $e');
          output = await getApplicationDocumentsDirectory();
          userFriendlyPath = 'App Documents folder';
        }
      } else {
        // For other platforms, use app documents directory
        output = await getApplicationDocumentsDirectory();
        userFriendlyPath = 'App Documents folder';
      }
      
              // Output directory is now guaranteed to be non-null
        
        // Ensure fileName is clean and has timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cleanFileName = '${fileName}_$timestamp'.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        final file = File('${output.path}/$cleanFileName.pdf');
        
        print('🔍 PDF: Saving file to: ${file.path}');
        
        // Write PDF bytes
        await file.writeAsBytes(pdfBytes);
        
        // Verify file was actually created
        if (await file.exists()) {
          final fileSize = await file.length();
          print('🔍 PDF: File created successfully! Size: $fileSize bytes');
          
          // For Android, verify the file is actually accessible
          if (Platform.isAndroid) {
            try {
              // Try to read the file to verify it's accessible
              final testRead = await file.readAsBytes();
              print('🔍 PDF: File is readable! Size verified: ${testRead.length} bytes');
              
                                            // File is ready to be opened by user
                print('🔍 PDF: File ready at: ${file.path}');
             } catch (e) {
               print('🔍 PDF: Could not read or open file: $e');
               // Even if notification/opening fails, the file is saved
             }
           }
           
           // Show success notification
           await _showDownloadNotification(cleanFileName, userFriendlyPath);
          
          // Return success info with user-friendly path
          return {
            'success': true,
            'filePath': file.path,
            'fileName': '$cleanFileName.pdf',
            'directory': output.path,
            'userFriendlyPath': userFriendlyPath,
            'message': 'PDF downloaded successfully! Check your Downloads folder 📁',
          };
        } else {
          throw Exception('File was not created successfully');
        }
    } catch (e) {
      print('🔍 PDF: Error saving PDF: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to download PDF: $e',
      };
    }
  }
  
  // Show download notification
  static Future<void> _showDownloadNotification(String fileName, String location) async {
    try {
      // Show a toast notification
      Toast.show(
        'PDF Downloaded! 📄\n$fileName saved to $location',
        duration: Toast.lengthLong,
        gravity: Toast.bottom,
      );
      
      print('🔍 PDF: Notification shown for $fileName');
    } catch (e) {
      print('🔍 PDF: Error showing notification: $e');
    }
  }
}
