import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

abstract class PdfExportPlatform {
  static Future<String> savePdf(Uint8List pdfBytes, String fileName) async {
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/$fileName.pdf');
    await file.writeAsBytes(pdfBytes);
    return file.path;
  }
}
