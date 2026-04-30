// Web implementation using QZ Tray (https://qz.io)
// This requires the QZ Tray desktop app installed on the client machine
// and the qz-tray.js injected into the page. We call it via JS interop.

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

Future<bool> isAvailable() async {
  try {
    // qz object injected by qz-tray.js
    final qz = (html.window as dynamic).qz;
    return qz != null;
  } catch (_) {
    return false;
  }
}

Future<bool> printEscPosBytes({
  required List<int> bytes,
  String? printer,
}) async {
  try {
    final qz = (html.window as dynamic).qz;
    if (qz == null) return false;

    // Ensure QZ is ready (handles certificate/signing via user prompts)
    await qz.websocket.connect();

    final config = await qz.configs.create(printer ?? null);

    // Chunk large ESC/POS payloads to avoid device buffer issues
    const int chunkSize = 16 * 1024; // 16KB
    final List<dynamic> data = [];
    for (int i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      final slice = bytes.sublist(i, end);
      data.add({ 'type': 'raw', 'format': 'base64', 'data': base64Encode(slice) });
    }

    await qz.print(config, data);
    return true;
  } catch (e) {
    // Best-effort cleanup
    try { await (html.window as dynamic).qz?.websocket?.disconnect(); } catch (_) {}
    return false;
  }
}
