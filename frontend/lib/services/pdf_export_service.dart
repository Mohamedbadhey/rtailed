import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

// Conditional imports for different platforms
import 'pdf_export_io.dart' if (dart.library.html) 'pdf_export_web.dart';

class PdfExportService {
  static Future<dynamic> exportTransactionsToPdf({
    required List<Map<String, dynamic>> transactions,
    required String reportTitle,
    required String fileName,
  }) async {
    // Use fallback business branding for consistency
    Map<String, dynamic> businessInfo = {
      'name': 'XXX',
      'tagline': 'XXX',
      'contact_email': 'XXX',
      'contact_phone': 'XXX',
      'address': 'XXX',
      'primary_color': '#1976D2',
    };
    
    print('🔍 PDF: Using fallback business branding for consistency');
    
    // Create PDF document
    final pdf = pw.Document();
    
    // Add page with compact invoice layout
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Compact Header
              _buildCompactHeader(businessInfo, reportTitle),
              
              pw.SizedBox(height: 15),
              
              // Compact Invoice Details
              _buildCompactInvoiceDetails(businessInfo),
              
              pw.SizedBox(height: 15),
              
              // Compact Transactions Table
              if (transactions.isNotEmpty) ...[
                _buildCompactInvoiceTable(transactions),
                
                pw.SizedBox(height: 15),
                
                // Compact Invoice Summary
                _buildCompactInvoiceSummary(transactions),
              ] else ...[
                _buildEmptyState(),
              ],
            ],
          );
        },
      ),
    );
    
    // Save PDF using platform-specific implementation
    final pdfBytes = await pdf.save();
    return await PdfExportPlatform.savePdf(pdfBytes, fileName);
  }

  static Future<dynamic> exportStockSummaryToPdf({
    required List<Map<String, dynamic>> stockData,
    required String reportTitle,
    required String fileName,
  }) async {
    // Use fallback business branding for consistency
    Map<String, dynamic> businessInfo = {
      'name': 'XXX',
      'tagline': 'XXX',
      'contact_email': 'XXX',
      'contact_phone': 'XXX',
      'address': 'XXX',
      'primary_color': '#1976D2',
    };
    
    print('🔍 PDF: Using fallback business branding for stock summary');
    
    // Create PDF document
    final pdf = pw.Document();
    
    // Add page with stock summary layout
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Compact Header
              _buildCompactHeader(businessInfo, reportTitle),
              
              pw.SizedBox(height: 15),
              
              // Compact Invoice Details
              _buildCompactInvoiceDetails(businessInfo),
              
              pw.SizedBox(height: 15),
              
              // Stock Summary Table
              if (stockData.isNotEmpty) ...[
                _buildStockSummaryTable(stockData),
                
                pw.SizedBox(height: 15),
                
                // Stock Summary Summary
                _buildStockSummarySummary(stockData),
              ] else ...[
                _buildEmptyState(),
              ],
            ],
          );
        },
      ),
    );
    
    // Save PDF using platform-specific implementation
    final pdfBytes = await pdf.save();
    return await PdfExportPlatform.savePdf(pdfBytes, fileName);
  }
  

  
  // Build compact header
  static pw.Widget _buildCompactHeader(Map<String, dynamic> businessInfo, String reportTitle) {
    final businessName = businessInfo['name'] ?? 'XXX';
    final primaryColor = _parseColor(businessInfo['primary_color'] ?? '#1976D2');
    final tagline = businessInfo['tagline'] ?? 'XXX';
    
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: primaryColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        children: [
          // Business Logo Placeholder
          pw.Container(
            width: 40,
            height: 40,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Center(
                           child: pw.Text(
               businessName.isNotEmpty && businessName != 'XXX' 
                 ? businessName.substring(0, 1).toUpperCase()
                 : 'X',
               style: pw.TextStyle(
                 fontSize: 16,
                 fontWeight: pw.FontWeight.bold,
                 color: primaryColor,
               ),
             ),
            ),
          ),
          
          pw.SizedBox(width: 12),
          
          // Business Info
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  businessName,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  tagline,
                  style: pw.TextStyle(
                    color: PdfColors.grey300,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          
          // Report Title
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey300,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Text(
              reportTitle,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Build compact invoice details
  static pw.Widget _buildCompactInvoiceDetails(Map<String, dynamic> businessInfo) {
    final contactEmail = businessInfo['contact_email'] ?? 'XXX';
    final contactPhone = businessInfo['contact_phone'] ?? 'XXX';
    final address = businessInfo['address'] ?? 'XXX';
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        children: [
          // Contact Information
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Contact Info',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text('Email: $contactEmail', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Phone: $contactPhone', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
          
          // Address
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Address',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  address,
                  style: const pw.TextStyle(fontSize: 9),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          
          // Invoice Details
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Invoice Details',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Date: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Text(
                  'Time: ${DateFormat('HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Build stock summary table
  static pw.Widget _buildStockSummaryTable(List<Map<String, dynamic>> stockData) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
        columnWidths: const {
          0: pw.FlexColumnWidth(2), // Product
          1: pw.FlexColumnWidth(1), // SKU
          2: pw.FlexColumnWidth(1), // Category
          3: pw.FlexColumnWidth(0.8), // Sold Qty
          4: pw.FlexColumnWidth(0.8), // Qty Remaining
          5: pw.FlexColumnWidth(1), // Revenue
          6: pw.FlexColumnWidth(1), // Profit
        },
        children: [
          // Table Header
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'Product',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'SKU',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'Category',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'Sold',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'Remaining',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'Revenue',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'Profit',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ),
          
          // Table Rows
          ...stockData.map((row) => pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  row['product_name'] ?? '',
                  style: const pw.TextStyle(fontSize: 8),
                  maxLines: 2,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  row['sku'] ?? '',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  row['category_name'] ?? '',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  _safeToInt(row['quantity_sold']).toString(),
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  _safeToInt(row['quantity_remaining']).toString(),
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  '\$${_safeToDouble(row['revenue']).toStringAsFixed(2)}',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  '\$${_safeToDouble(row['profit']).toStringAsFixed(2)}',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          )).toList(),
        ],
      ),
    );
  }

  // Build compact invoice table
  static pw.Widget _buildCompactInvoiceTable(List<Map<String, dynamic>> transactions) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
        columnWidths: const {
          0: pw.FlexColumnWidth(1), // Date
          1: pw.FlexColumnWidth(2.5), // Product
          2: pw.FlexColumnWidth(0.6), // Qty
          3: pw.FlexColumnWidth(1), // Cost Price
          4: pw.FlexColumnWidth(1), // Sale Price
          5: pw.FlexColumnWidth(1.2), // Total
        },
        children: [
          // Table Header
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'Date',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'Product',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'Qty',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'Cost',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'Price',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'Total',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ),
          
          // Table Rows
          ...transactions.map((tx) => pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  _formatDate(tx['created_at'] ?? ''),
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  tx['product_name'] ?? '',
                  style: const pw.TextStyle(fontSize: 8),
                  maxLines: 2,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  tx['quantity']?.toString() ?? '',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  '\$${_getCostPrice(tx).toStringAsFixed(2)}',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  '\$${_getSalePrice(tx).toStringAsFixed(2)}',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  '\$${_calculateRowTotal(tx).toStringAsFixed(2)}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          )).toList(),
        ],
      ),
    );
  }
  
  // Build stock summary summary
  static pw.Widget _buildStockSummarySummary(List<Map<String, dynamic>> stockData) {
    final totalSold = stockData.fold(0, (sum, row) => sum + _safeToInt(row['quantity_sold']));
    final totalRemaining = stockData.fold(0, (sum, row) => sum + _safeToInt(row['quantity_remaining']));
    final totalRevenue = stockData.fold(0.0, (sum, row) => sum + _safeToDouble(row['revenue']));
    final totalProfit = stockData.fold(0.0, (sum, row) => sum + _safeToDouble(row['profit']));
    final totalProducts = stockData.length;
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // Summary rows
          _buildSummaryRow('Total Products:', totalProducts, isCurrency: false),
          pw.SizedBox(height: 4),
          _buildSummaryRow('Total Sold Quantity:', totalSold, isCurrency: false),
          pw.SizedBox(height: 4),
          _buildSummaryRow('Total Remaining Quantity:', totalRemaining, isCurrency: false),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.SizedBox(height: 6),
          
          // Financial Summary
          _buildSummaryRow('Total Revenue:', totalRevenue),
          pw.SizedBox(height: 4),
          _buildSummaryRow('Total Profit:', totalProfit),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.SizedBox(height: 6),
          
          // Footer
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Text(
              'Stock Summary Report Generated',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.normal,
                color: PdfColors.grey700,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // Build compact invoice summary
  static pw.Widget _buildCompactInvoiceSummary(List<Map<String, dynamic>> transactions) {
    final subtotal = _calculateSubtotal(transactions);
    final totalCost = _calculateTotalCost(transactions);
    final totalProfit = _calculateTotalProfit(transactions);
    final totalQuantity = _calculateTotalQuantity(transactions);
    final totalTransactions = transactions.length;
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // Summary rows
          _buildSummaryRow('Subtotal:', subtotal),
          pw.SizedBox(height: 4),
          _buildSummaryRow('Total Cost:', totalCost),
          pw.SizedBox(height: 4),
          _buildSummaryRow('Total Profit:', totalProfit),
          pw.SizedBox(height: 4),
          _buildSummaryRow('Total Items:', totalQuantity, isCurrency: false),
          pw.SizedBox(height: 4),
          _buildSummaryRow('Transactions:', totalTransactions, isCurrency: false),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.SizedBox(height: 6),
          
          // Grand Total
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'GRAND TOTAL:',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900,
                ),
              ),
              pw.Text(
                '\$${subtotal.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900,
                ),
              ),
            ],
          ),
          
          pw.SizedBox(height: 12),
          
          // Footer
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Text(
              'Thank you for your business!',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.normal,
                color: PdfColors.grey700,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  
  // Build summary row helper
  static pw.Widget _buildSummaryRow(String label, dynamic value, {bool isCurrency = true}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.Text(
          isCurrency ? '\$${value.toStringAsFixed(2)}' : value.toString(),
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    );
  }
  
  // Build empty state
  static pw.Widget _buildEmptyState() {
    return pw.Center(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(30),
        child: pw.Column(
          children: [
            pw.Text(
              'No transactions found',
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'There are no transactions to display in this report.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper methods
  static String _formatDate(String timestamp) {
    try {
      if (timestamp.isEmpty) return '';
      final dateTime = DateTime.parse(timestamp);
      final localDateTime = dateTime.toLocal();
      return '${localDateTime.day.toString().padLeft(2, '0')}/${localDateTime.month.toString().padLeft(2, '0')}/${localDateTime.year}';
    } catch (e) {
      return timestamp;
    }
  }
  
  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  // Get cost price from transaction data
  static double _getCostPrice(Map<String, dynamic> transaction) {
    // Try to get cost price from various possible fields
    final costPrice = transaction['product_cost_price'] ?? 
                     transaction['cost_price'] ?? 
                     transaction['unit_cost'] ?? 0.0;
    return _safeToDouble(costPrice);
  }
  
  // Get sale price from transaction data
  static double _getSalePrice(Map<String, dynamic> transaction) {
    // Try to get sale price from various possible fields
    final salePrice = transaction['sale_unit_price'] ?? 
                     transaction['unit_price'] ?? 
                     transaction['product_price'] ?? 
                     transaction['price'] ?? 0.0;
    return _safeToDouble(salePrice);
  }
  
  // Calculate row total
  static double _calculateRowTotal(Map<String, dynamic> transaction) {
    final quantity = _safeToInt(transaction['quantity']);
    final salePrice = _getSalePrice(transaction);
    return quantity * salePrice;
  }
  
  // Calculate subtotal
  static double _calculateSubtotal(List<Map<String, dynamic>> transactions) {
    return transactions.fold(0.0, (sum, tx) => sum + _calculateRowTotal(tx));
  }
  
  // Calculate total cost
  static double _calculateTotalCost(List<Map<String, dynamic>> transactions) {
    return transactions.fold(0.0, (sum, tx) {
      final quantity = _safeToInt(tx['quantity']);
      final costPrice = _getCostPrice(tx);
      return sum + (quantity * costPrice);
    });
  }
  
  // Calculate total profit
  static double _calculateTotalProfit(List<Map<String, dynamic>> transactions) {
    return transactions.fold(0.0, (sum, tx) => sum + _safeToDouble(tx['profit'] ?? 0));
  }
  
  // Calculate total quantity
  static int _calculateTotalQuantity(List<Map<String, dynamic>> transactions) {
    return transactions.fold(0, (sum, tx) => sum + (_safeToInt(tx['quantity'])));
  }
  
  static int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  
  static PdfColor _parseColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return PdfColor.fromInt(int.parse(hex, radix: 16));
    } catch (e) {
      return PdfColors.blue;
    }
  }
  

}
