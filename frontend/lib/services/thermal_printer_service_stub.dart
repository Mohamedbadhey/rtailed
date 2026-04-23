// Stub fallback when no direct printing implementation is available

Future<bool> isAvailable() async => false;

Future<bool> printEscPosBytes({
  required List<int> bytes,
  String? printer,
}) async {
  // No direct printing on this platform
  return false;
}
