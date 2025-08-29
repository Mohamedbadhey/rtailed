import 'dart:typed_data';
import 'dart:html' as html;

abstract class PdfExportPlatform {
  static Future<String> savePdf(Uint8List pdfBytes, String fileName) async {
    // Create a blob from the PDF bytes
    final blob = html.Blob([pdfBytes], 'application/pdf');
    
    // Create a download link
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '$fileName.pdf')
      ..click();
    
    // Clean up the URL
    html.Url.revokeObjectUrl(url);
    
    return 'Downloaded to browser downloads folder';
  }
}
