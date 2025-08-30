import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

abstract class PdfExportPlatform {
  static Future<Map<String, dynamic>> savePdf(Uint8List pdfBytes, String fileName) async {
    try {
      Directory? output;
      String userFriendlyPath = '';
      
      // Try to get Downloads directory first (Android)
      if (Platform.isAndroid) {
        try {
          // For Android, try to get external storage directory
          final List<Directory>? directories = await getExternalStorageDirectories();
          if (directories != null && directories.isNotEmpty) {
            // Look for Downloads folder
            for (Directory dir in directories) {
              final downloadsDir = Directory('${dir.path}/Download');
              if (await downloadsDir.exists()) {
                output = downloadsDir;
                userFriendlyPath = 'Downloads folder';
                break;
              }
            }
          }
          
          // Fallback to external storage root
          if (output == null) {
            final externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              final downloadsDir = Directory('${externalDir.path}/Download');
              if (await downloadsDir.exists()) {
                output = downloadsDir;
                userFriendlyPath = 'Downloads folder';
              } else {
                // Create Downloads folder if it doesn't exist
                await downloadsDir.create(recursive: true);
                output = downloadsDir;
                userFriendlyPath = 'Downloads folder';
              }
            }
          }
          
          // If still no output, try app documents directory
          if (output == null) {
            output = await getApplicationDocumentsDirectory();
            userFriendlyPath = 'App Documents folder';
          }
        } catch (e) {
          print('🔍 PDF: Could not access external storage: $e');
          // Fallback to app documents directory
          output = await getApplicationDocumentsDirectory();
          userFriendlyPath = 'App Documents folder';
        }
      } else {
        // For other platforms, use app documents directory
        output = await getApplicationDocumentsDirectory();
        userFriendlyPath = 'App Documents folder';
      }
      
      // Ensure fileName is clean and has timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cleanFileName = '${fileName}_$timestamp'.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final file = File('${output.path}/$cleanFileName.pdf');
      
      // Write PDF bytes
      await file.writeAsBytes(pdfBytes);
      
      // Return success info with user-friendly path
      return {
        'success': true,
        'filePath': file.path,
        'fileName': '$cleanFileName.pdf',
        'directory': output.path,
        'userFriendlyPath': userFriendlyPath,
        'message': 'PDF saved successfully to $userFriendlyPath!',
      };
      
    } catch (e) {
      print('🔍 PDF: Error saving PDF: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to save PDF: $e',
      };
    }
  }
}
