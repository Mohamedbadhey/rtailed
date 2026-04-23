import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import 'thermal_printer_service.dart';
import 'escpos_builder.dart';
import 'package:flutter/foundation.dart'; // kIsWeb check
import 'dart:io' show Platform; // guarded by kIsWeb when building for web


import 'api_service.dart';
import '../providers/auth_provider.dart';

/// Paper widths supported for thermal receipts
enum ReceiptPaper { mm58, mm80 }

class ReceiptService {
  /// Render and open the platform print dialog for a sale receipt
  static Future<void> printSaleReceipt(
    BuildContext context, {
    required int saleId,
    ReceiptPaper paper = ReceiptPaper.mm58,
  }) async {
    try {
      final api = ApiService();
      // Resolve business id from current user
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final businessId = auth.user?.businessId ?? 1;

      // Fetch sale + items and business details
      final sale = await api.getSale(saleId);
      final items = await api.getSaleItems(saleId);
      final business = await api.getBusinessDetails(businessId);

      // Try direct ESC/POS first (best for thermal printers via QZ Tray on Web)
      try {
        final chars = paper == ReceiptPaper.mm58 ? 32 : 48;
        final escpos = EscPosBuilder.buildSaleReceipt(
          sale: sale,
          items: items,
          business: business,
          paperWidthChars: chars,
        );
        final handled = await ThermalPrinterService.printEscPosBytes(bytes: escpos);
        if (handled) return; // done
      } catch (_) {
        // Fallback to PDF below
      }

      // Fallback: Build the PDF document and show system print dialog
      final bytes = await _buildReceiptPdf(
        sale: sale,
        items: items,
        business: business,
        paper: paper,
      );

      final jobName = 'Receipt #${sale['sale_id'] ?? saleId}';
      await Printing.layoutPdf(
        name: jobName,
        onLayout: (PdfPageFormat format) async => bytes,
      );
    } catch (e) {
      // Surface a friendly error message in UI
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Printing failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Generate a compact, printer-friendly receipt PDF for 58mm/80mm rolls
  static Future<Uint8List> _buildReceiptPdf({
    required Map<String, dynamic> sale,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> business,
    required ReceiptPaper paper,
  }) async {
    // Choose thermal roll format
    final pageFormat = paper == ReceiptPaper.mm58
        ? PdfPageFormat.roll57
        : PdfPageFormat.roll80; // close to 58/80mm effective widths

    final doc = pw.Document();

    // Extract business and sale fields with safe fallbacks
    final businessName = (business['name'] ?? business['business_name'] ?? 'Business').toString();
    final address = (business['address'] ?? '').toString();
    final phone = (business['contact_phone'] ?? business['phone'] ?? '').toString();

    final saleId = sale['sale_id'] ?? sale['id'] ?? '';
    final cashier = (sale['cashierName'] ?? sale['cashier_name'] ?? sale['user']?['username'] ?? '').toString();
    final paymentMethod = (sale['payment_method'] ?? 'cash').toString();

    DateTime ts;
    final createdAt = sale['created_at'];
    if (createdAt is String) {
      ts = DateTime.tryParse(createdAt) ?? DateTime.now();
    } else if (createdAt is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(createdAt);
    } else if (createdAt is DateTime) {
      ts = createdAt;
    } else {
      ts = DateTime.now();
    }

    double totalAmount = 0.0;
    for (final it in items) {
      final q = _safeToDouble(it['quantity']);
      final unit = _safeToDouble(it['unit_price'] ?? it['sale_unit_price'] ?? it['price']);
      totalAmount += q * unit;
    }

    // Styles
    final regular = pw.TextStyle(fontSize: 8);
    final small = pw.TextStyle(fontSize: 7);
    final bold = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
    final mono = pw.TextStyle(fontSize: 8);
    final monoBold = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);

    pw.Widget header() => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(businessName, style: bold, textAlign: pw.TextAlign.center),
            if (address.isNotEmpty) pw.Text(address, style: small, textAlign: pw.TextAlign.center),
            if (phone.isNotEmpty) pw.Text('Tel: $phone', style: small, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1),
          ],
        );

    pw.Widget saleMeta() => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _kv('Receipt', '#$saleId', small),
            _kv('Date', _formatDate(ts), small),
            if (cashier.isNotEmpty) _kv('Cashier', cashier, small),
            _kv('Payment', paymentMethod.toUpperCase(), small),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1),
          ],
        );

    pw.Widget itemsTable() {
      final rows = <pw.Widget>[];

      // Header
      rows.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(flex: 6, child: pw.Text('Item', style: monoBold)),
            pw.SizedBox(width: 4),
            pw.Expanded(flex: 3, child: pw.Text('Qty', style: monoBold, textAlign: pw.TextAlign.right)),
            pw.SizedBox(width: 4),
            pw.Expanded(flex: 4, child: pw.Text('Price', style: monoBold, textAlign: pw.TextAlign.right)),
            pw.SizedBox(width: 4),
            pw.Expanded(flex: 4, child: pw.Text('Total', style: monoBold, textAlign: pw.TextAlign.right)),
          ],
        ),
      );

      rows.add(pw.SizedBox(height: 2));

      // Lines
      for (final it in items) {
        final name = (it['product_name'] ?? it['name'] ?? 'Product').toString();
        final qty = _safeToDouble(it['quantity']);
        final unit = _safeToDouble(it['unit_price'] ?? it['sale_unit_price'] ?? it['price']);
        final lineTotal = qty * unit;

        rows.add(
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 6, child: pw.Text(name, style: mono)),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 3, child: pw.Text(_fmtQty(qty), style: mono, textAlign: pw.TextAlign.right)),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 4, child: pw.Text(_fmt(unit), style: mono, textAlign: pw.TextAlign.right)),
              pw.SizedBox(width: 4),
              pw.Expanded(flex: 4, child: pw.Text(_fmt(lineTotal), style: mono, textAlign: pw.TextAlign.right)),
            ],
          ),
        );
      }

      rows.add(pw.Divider(thickness: 1));

      // Totals
      rows.add(
        pw.Row(
          children: [
            pw.Expanded(flex: 13, child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(flex: 4, child: pw.Text(_fmt(totalAmount), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
          ],
        ),
      );

      return pw.Column(children: rows);
    }

    pw.Widget footer() => pw.Column(
          children: [
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1),
            pw.Text('Thank you for your purchase!', style: small, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 2),
            pw.Text('No returns without receipt', style: small, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 2),
            pw.Text('developed by kismayoict solutions 0614112537', style: small, textAlign: pw.TextAlign.center),
            
          ],
        );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              header(),
              saleMeta(),
              itemsTable(),
              footer(),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _kv(String k, String v, pw.TextStyle style) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(k, style: style), pw.Text(v, style: style)],
      );

  static String _formatDate(DateTime dt) {
    // HH:mm on dd/MM/yyyy for compactness
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}  ${two(dt.day)}/${two(dt.month)}/${dt.year}';
  }

  static double _safeToDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static String _fmt(double n) => n.toStringAsFixed(2);
  static String _fmtQty(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
}
