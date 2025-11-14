import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:toast/toast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'notification_service.dart';

abstract class PdfExportPlatform {
  static Future<Map<String, dynamic>> savePdf(Uint8List pdfBytes, String fileName) async {
    try {
      // Use app-specific directory (scoped storage) - no permissions required
      Directory? output;
      String userFriendlyPath = '';
      
      // Always use app documents directory (scoped storage compliant)
      output = await getApplicationDocumentsDirectory();
      userFriendlyPath = 'App folder';
      
      // Create a subdirectory for PDFs if it doesn't exist
      final pdfsDir = Directory('${output.path}/PDFs');
      if (!await pdfsDir.exists()) {
        await pdfsDir.create(recursive: true);
      }
      output = pdfsDir;
      
      print('🔍 PDF: Using scoped storage directory: ${output.path}');
        
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
        
        // For Android, share the file using share_plus to allow user to save to Downloads
        if (Platform.isAndroid) {
          try {
            // Share the file using system share sheet
            // This allows users to save to Downloads or any location they choose
            final result = await Share.shareXFiles(
              [XFile(file.path, mimeType: 'application/pdf', name: '$cleanFileName.pdf')],
              text: 'Share PDF: $cleanFileName',
              subject: '$cleanFileName.pdf',
            );
            
            print('🔍 PDF: Share result: $result');
            
            // Show success notification
            await _showDownloadNotification(
              cleanFileName, 
              'Shared successfully. You can save it to Downloads from the share menu.',
              file.path
            );
            
            // Return success info
            return {
              'success': true,
              'filePath': file.path,
              'fileName': '$cleanFileName.pdf',
              'directory': output.path,
              'userFriendlyPath': 'Shared - Save to Downloads via share menu',
              'message': 'PDF saved! Use the share menu to save it to your Downloads folder 📁',
            };
          } catch (shareError) {
            print('🔍 PDF: Error sharing file: $shareError');
            // Even if sharing fails, the file is saved in app directory
            await _showDownloadNotification(
              cleanFileName, 
              'Saved to app folder',
              file.path
            );
            
            return {
              'success': true,
              'filePath': file.path,
              'fileName': '$cleanFileName.pdf',
              'directory': output.path,
              'userFriendlyPath': 'App folder',
              'message': 'PDF saved to app folder! You can access it from the app.',
            };
          }
        } else {
          // For iOS and other platforms
          await _showDownloadNotification(cleanFileName, userFriendlyPath, file.path);
          
          return {
            'success': true,
            'filePath': file.path,
            'fileName': '$cleanFileName.pdf',
            'directory': output.path,
            'userFriendlyPath': userFriendlyPath,
            'message': 'PDF saved successfully! 📁',
          };
        }
      } else {
        throw Exception('File was not created successfully');
      }
    } catch (e) {
      print('🔍 PDF: Error saving PDF: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to save PDF: $e',
      };
    }
  }
  
  // Show download notification
  static Future<void> _showDownloadNotification(String fileName, String location, String filePath) async {
    try {
      // Show system notification that can be tapped to open PDF
      await NotificationService.showPdfDownloadNotification(
        fileName: fileName,
        filePath: filePath,
        location: location,
      );
      
      // Also show toast as backup
      Toast.show(
        'PDF Downloaded! 📄\n$fileName saved to $location',
        duration: Toast.lengthLong,
        gravity: Toast.bottom,
      );
      
      print('🔍 PDF: System notification and toast shown for $fileName');
    } catch (e) {
      print('🔍 PDF: Error showing notification: $e');
      
      // Fallback to toast only if system notification fails
      try {
        Toast.show(
          'PDF Downloaded! 📄\n$fileName saved to $location',
          duration: Toast.lengthLong,
          gravity: Toast.bottom,
        );
      } catch (toastError) {
        print('🔍 PDF: Error showing toast notification: $toastError');
      }
    }
  }
}
