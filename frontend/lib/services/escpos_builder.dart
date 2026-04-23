import 'dart:typed_data';

/// Very small ESC/POS builder focused on receipt text for 58mm/80mm printers.
/// This generates generic ESC/POS bytes that work with most thermal printers.
/// It avoids vendor-specific commands and non-ASCII glyphs for broad compatibility.
class EscPosBuilder {
  /// Build a simple receipt for a sale using basic ESC/POS commands.
  /// - [paperWidthChars]: typical values: 32 for 58mm, 48 for 80mm
  static Uint8List buildSaleReceipt({
    required Map<String, dynamic> sale,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> business,
    int paperWidthChars = 32,
  }) {
    final bytes = BytesBuilder();

    void write(List<int> data) => bytes.add(data);
    void textRaw(String s) => write(_latin1(s));
    void ln([int n = 1]) { for (int i = 0; i < n; i++) write([0x0A]); }

    // ESC/POS helpers
    void init() => write([0x1B, 0x40]); // ESC @
    void alignLeft() => write([0x1B, 0x61, 0x00]);
    void alignCenter() => write([0x1B, 0x61, 0x01]);
    void alignRight() => write([0x1B, 0x61, 0x02]);
    void boldOn() => write([0x1B, 0x45, 0x01]);
    void boldOff() => write([0x1B, 0x45, 0x00]);
    void doubleOn() => write([0x1D, 0x21, 0x11]); // double width + height
    void doubleOff() => write([0x1D, 0x21, 0x00]);
    void cut() => write([0x1D, 0x56, 0x42, 0x00]); // GS V B m (partial cut)
    void pulse() => write([0x1B, 0x70, 0x00, 0x3C, 0xFF]); // cash drawer (optional)

    String _safeStr(dynamic v) => (v ?? '').toString();
    String _fmtAmt(num n) => n.toStringAsFixed(2);

    String _formatLineKV(String k, String v) {
      final key = k.trim();
      final value = v.trim();
      final space = paperWidthChars - key.length - value.length;
      if (space <= 0) return (key + ' ' + value).substring(0, paperWidthChars);
      return key + ' ' * space + value;
    }

    List<String> _wrap(String s) {
      final out = <String>[];
      var text = s.trim();
      while (text.isNotEmpty) {
        if (text.length <= paperWidthChars) {
          out.add(text);
          break;
        } else {
          out.add(text.substring(0, paperWidthChars));
          text = text.substring(paperWidthChars);
        }
      }
      if (out.isEmpty) out.add('');
      return out;
    }

    void header() {
      final name = _safeStr(business['name'] ?? business['business_name'] ?? 'Business');
      final addr = _safeStr(business['address']);
      final tel = _safeStr(business['contact_phone'] ?? business['phone']);

      init();
      alignCenter();
      boldOn();
      doubleOn();
      textRaw(name);
      doubleOff();
      boldOff();
      ln();
      if (addr.isNotEmpty) { textRaw(addr); ln(); }
      if (tel.isNotEmpty) { textRaw('Tel: ' + tel); ln(); }
      ln();
      alignLeft();
      _hr();
    }

    void saleMeta() {
      final id = _safeStr(sale['sale_id'] ?? sale['id']);
      final cashier = _safeStr(sale['cashierName'] ?? sale['cashier_name'] ?? sale['user']?['username']);
      final payment = _safeStr(sale['payment_method'] ?? 'cash').toUpperCase();
      final date = _formatDate(sale['created_at']);
      textRaw(_formatLineKV('Receipt', '#' + id)); ln();
      textRaw(_formatLineKV('Date', date)); ln();
      if (cashier.isNotEmpty) { textRaw(_formatLineKV('Cashier', cashier)); ln(); }
      textRaw(_formatLineKV('Payment', payment)); ln();
      _hr();
    }

    void itemsTable() {
      // Header
      textRaw(_formatLineKV('Item', 'Total')); ln();
      _hr(thin: true);

      num grand = 0;
      for (final it in items) {
        final name = _safeStr(it['product_name'] ?? it['name'] ?? 'Product');
        final qty = _safeNum(it['quantity']);
        final unit = _safeNum(it['unit_price'] ?? it['sale_unit_price'] ?? it['price']);
        final total = qty * unit;
        grand += total;

        // First line: name (wrap if needed)
        final wrapped = _wrap(name);
        for (int i = 0; i < wrapped.length; i++) {
          final line = wrapped[i];
          if (i == 0) {
            final right = _fmtAmt(total);
            final avail = paperWidthChars - right.length - 1;
            final left = line.length > avail ? line.substring(0, avail) : line;
            final spaces = paperWidthChars - left.length - right.length;
            textRaw(left + ' ' * spaces + right);
          } else {
            textRaw(line);
          }
          ln();
        }

        // Second line: qty x price
        final qtyPrice = '${_fmtQty(qty)} x ${_fmtAmt(unit)}';
        textRaw(qtyPrice);
        ln();
      }
      _hr();
      boldOn();
      textRaw(_formatLineKV('TOTAL', _fmtAmt(grand)));
      boldOff();
      ln();
    }

    void footer() {
      alignCenter();
      textRaw('Thank you for your purchase!'); ln();
      textRaw('No returns without receipt'); ln();
      // Custom footer line kept from existing PDF template
      textRaw('developed by kismayoict solutions 0614112537'); ln();
      ln(3);
      cut();
      // pulse(); // enable if you have a cash drawer connected
    }

    void _hr({bool thin = false}) {
      final ch = thin ? '-' : '=';
      textRaw(List.filled(paperWidthChars, ch).join()); ln();
    }

    header();
    saleMeta();
    itemsTable();
    footer();

    return bytes.toBytes();
  }

  static List<int> _latin1(String s) {
    // Map basic unicode to latin1 fallback (strip non-latin)
    final codeUnits = <int>[];
    for (final rune in s.runes) {
      if (rune >= 0x20 && rune <= 0xFF) {
        codeUnits.add(rune);
      } else if (rune == 0x0A || rune == 0x0D) {
        codeUnits.add(rune);
      } else {
        codeUnits.add(0x3F); // '?'
      }
    }
    return codeUnits;
  }

  static double _safeNum(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static String _fmtQty(double n) =>
      (n == n.roundToDouble()) ? n.toInt().toString() : n.toStringAsFixed(2);

  static String _formatDate(dynamic createdAt) {
    DateTime ts;
    if (createdAt is String) {
      ts = DateTime.tryParse(createdAt) ?? DateTime.now();
    } else if (createdAt is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(createdAt);
    } else if (createdAt is DateTime) {
      ts = createdAt;
    } else {
      ts = DateTime.now();
    }
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(ts.hour)}:${two(ts.minute)}  ${two(ts.day)}/${two(ts.month)}/${ts.year}';
  }
}
