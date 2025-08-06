class Api {
  static const String baseUrl = 'https://rtailed-production.up.railway.app';
  static const String apiBase = '$baseUrl/api';

  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String profile = '/auth/profile';

  // Product endpoints
  static const String products = '/products';
  static const String lowStockProducts = '/products/inventory/low-stock';

  // Customer endpoints
  static const String customers = '/customers';
  static const String customerLoyalty = '/customers/loyalty';

  // Sales endpoints
  static const String sales = '/sales';
  static const String salesReport = '/sales/report';
  static const String topProducts = '/sales/top-products';

  // Inventory endpoints
  static const String inventory = '/inventory';
  static const String inventoryTransactions = '/inventory/transactions';
  static const String inventoryValueReport = '/inventory/value-report';

  static String getFullImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      print('🖼️ getFullImageUrl: imageUrl is null or empty');
      return '';
    }
    if (imageUrl.startsWith('http')) {
      print('🖼️ getFullImageUrl: Already full URL: $imageUrl');
      return imageUrl;
    }
    final fullUrl = '$baseUrl$imageUrl';
    print('🖼️ getFullImageUrl: Generated URL: $fullUrl');
    print('🖼️ getFullImageUrl: Base URL: $baseUrl');
    print('🖼️ getFullImageUrl: Image URL: $imageUrl');
    return fullUrl;
  }
} 