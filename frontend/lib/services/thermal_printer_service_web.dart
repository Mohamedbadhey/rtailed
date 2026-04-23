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
    final data = [
      { 'type': 'raw', 'format': 'base64', 'data': base64Encode(bytes) }
    ];

    await qz.print(config, data);
    return true;
  } catch (e) {
    // Best-effort cleanup
    try { await (html.window as dynamic).qz?.websocket?.disconnect(); } catch (_) {}
    return false;
  }
}
