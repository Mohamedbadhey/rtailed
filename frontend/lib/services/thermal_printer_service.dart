// Cross-platform facade for direct thermal printing.
// Uses QZ Tray on Web when available; no-ops on other platforms.

import 'thermal_printer_service_stub.dart'
    if (dart.library.html) 'thermal_printer_service_web.dart' as impl;

class ThermalPrinterService {
  /// Check if a direct-print provider is available on this platform.
  static Future<bool> isAvailable() => impl.isAvailable();

  /// Attempt to print ESC/POS bytes directly.
  /// Returns true if a provider handled the print, otherwise false.
  static Future<bool> printEscPosBytes({
    required List<int> bytes,
    String? printer,
  }) => impl.printEscPosBytes(bytes: bytes, printer: printer);
}
