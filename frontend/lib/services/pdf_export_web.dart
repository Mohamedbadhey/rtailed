import 'dart:typed_data';
import 'dart:html' as html;

abstract class PdfExportPlatform {
  static Future<Map<String, dynamic>> savePdf(Uint8List pdfBytes, String fileName) async {
    try {
      // Create a blob from the PDF bytes
      final blob = html.Blob([pdfBytes], 'application/pdf');
      
      // Create a download link
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', '$fileName.pdf')
        ..click();
      
      // Clean up the URL
      html.Url.revokeObjectUrl(url);
      
      return {
        'success': true,
        'filePath': 'Browser Downloads',
        'fileName': '$fileName.pdf',
        'directory': 'Browser Downloads',
        'message': 'PDF downloaded to browser downloads folder',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to download PDF: $e',
      };
    }
  }
}
