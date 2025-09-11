import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/utils/success_utils.dart';
import 'package:retail_management/widgets/branded_app_bar.dart';
import 'package:retail_management/models/product.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:retail_management/utils/api.dart';
import 'package:retail_management/utils/responsive_utils.dart';
import 'package:retail_management/utils/theme.dart';

class StoreInventoryScreen extends StatefulWidget {
  final int storeId;
  final String storeName;
  
  const StoreInventoryScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<StoreInventoryScreen> createState() => _StoreInventoryScreenState();
}

class _StoreInventoryScreenState extends State<StoreInventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  
  // Data variables
  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _movements = [];
  Map<String, dynamic> _reports = {};
  bool _loading = true; // Start with loading true to prevent showing "No inventory found" initially
  String? _error;
  
  // Filter variables
  String _searchQuery = '';
  String _selectedMovementType = '';
  String _selectedProductId = '';
  String _selectedStockStatus = '';
  String _selectedCategory = '';
  double? _minPrice;
  double? _maxPrice;
  
  // Stock Summary Report fields (matching inventory_screen.dart)
  bool _showInventoryReport = false;
  String? _selectedReportCategory;
  String? _selectedReportProduct;
  String? _reportSku;
  DateTime? _reportStartDate;
  DateTime? _reportEndDate;
  List<Map<String, dynamic>> _reportTransactions = [];
  bool _reportLoading = false;
  // Inventory Value Report fields
  List<Map<String, dynamic>> _valueReportRows = [];
  bool _valueReportLoading = false;
  String? _valueReportError;
  // Add separate state for stock summary date filters
  DateTime? _stockSummaryStartDate;
  DateTime? _stockSummaryEndDate;
  // Add state for stock summary filter type
  String _stockSummaryFilterType = 'Today';
  final List<String> _stockSummaryFilterOptions = ['Today', 'This Week', 'This Month', 'Custom'];
  // Pagination state variables
  static const int _itemsPerPage = 10;
  int _stockSummaryCurrentPage = 0;
  
  // Inventory pagination
  int _inventoryCurrentPage = 0;
  bool _inventoryHasMore = true;
  bool _inventoryLoadingMore = false;
  final ScrollController _inventoryScrollController = ScrollController();
  
  // Cache for API responses
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  
  // Business selection for superadmin
  List<Map<String, dynamic>> _businesses = [];
  int? _selectedBusinessId;
  
  // Detailed Reports state variables
  Map<String, dynamic> _detailedMovementsData = {};
  Map<String, dynamic> _purchasesData = {};
  Map<String, dynamic> _incrementsData = {};
  bool _detailedMovementsLoading = false;
  bool _purchasesLoading = false;
  bool _incrementsLoading = false;
  
  // Purchases filters state variables
  DateTime? _purchasesStartDate;
  DateTime? _purchasesEndDate;
  String _purchasesTimeFilter = 'all_time';
  String? _selectedCategoryForPurchases;
  int? _selectedProductForPurchases;
  
  // Purchases time filter options
  final List<String> _purchasesTimeFilterOptions = [
    'today',
    'this_week', 
    'this_month',
    'all_time',
    'custom'
  ];
  
  // Increments filters state variables
  DateTime? _incrementsStartDate;
  DateTime? _incrementsEndDate;
  String _incrementsTimeFilter = 'all_time';
  String? _selectedCategoryForIncrements;
  int? _selectedProductForIncrements;
  
  // Increments time filter options
  final List<String> _incrementsTimeFilterOptions = [
    'today',
    'this_week', 
    'this_month',
    'all_time',
    'custom'
  ];
  
  // Detailed Reports filter variables
  DateTime? _detailedMovementsStartDate;
  DateTime? _detailedMovementsEndDate;
  String? _selectedDetailedMovementType;
  String? _selectedReferenceType;
  int? _selectedProductForDetailed;
  String? _selectedCategoryForDetailed;
  int? _selectedBusinessForDetailed;
  String? _selectedMovementTypeForDetailed;
  String _detailedMovementsTimeFilter = 'all_time';
  final List<String> _detailedMovementsTimeFilterOptions = ['today', 'this_week', 'this_month', 'all_time', 'custom'];
  int _detailedMovementsPage = 1;
  
  // Data for dropdowns
  List<Map<String, dynamic>> _productsForDetailed = [];
  List<Map<String, dynamic>> _categoriesForDetailed = [];
  List<Map<String, dynamic>> _categories = [];
  
  static const int _detailedReportsPageSize = 50;
  
  // Business Transfers filter variables
  DateTime? _businessTransfersStartDate;
  DateTime? _businessTransfersEndDate;
  String _businessTransfersTimePeriod = 'all';
  int? _selectedProductForTransfers;
  int? _selectedBusinessForTransfers;
  Map<String, dynamic> _businessTransfersData = {};
  
  // Transfer Reports variables
  bool _transferReportsLoading = false;
  Map<String, dynamic> _transferReportsData = {};
  String _transferReportsTimePeriod = 'all';
  DateTime? _transferReportsStartDate;
  DateTime? _transferReportsEndDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _inventoryScrollController.addListener(_onInventoryScroll);
    _initializeDateFilters();
    // Load data after the widget is built to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  void _initializeDateFilters() {
    _stockSummaryFilterType = 'Today';
    _applyStockSummaryPreset('Today');
    _detailedMovementsTimeFilter = 'all_time';
    _applyDetailedMovementsTimePreset('all_time');
    
    // Initialize purchases filters
    _purchasesTimeFilter = 'all_time';
    _applyPurchasesTimePreset('all_time');
    
    // Initialize increments filters
    _incrementsTimeFilter = 'all_time';
    _applyIncrementsTimePreset('all_time');
  }
  
  void _applyDetailedMovementsTimePreset(String filterType) {
    final now = DateTime.now();
    setState(() {
      _detailedMovementsTimeFilter = filterType;
      
      switch (filterType) {
        case 'today':
          _detailedMovementsStartDate = DateTime(now.year, now.month, now.day);
          _detailedMovementsEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'this_week':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          _detailedMovementsStartDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
          _detailedMovementsEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'this_month':
          _detailedMovementsStartDate = DateTime(now.year, now.month, 1);
          _detailedMovementsEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'all_time':
          _detailedMovementsStartDate = null;
          _detailedMovementsEndDate = null;
          break;
        case 'custom':
          // Keep existing dates or set defaults
          _detailedMovementsStartDate ??= now.subtract(const Duration(days: 30));
          _detailedMovementsEndDate ??= now;
          break;
      }
    });
    
    _loadDetailedMovements();
  }

  void _applyPurchasesTimePreset(String filterType) {
    final now = DateTime.now();
    setState(() {
      _purchasesTimeFilter = filterType;
      
      switch (filterType) {
        case 'today':
          _purchasesStartDate = DateTime(now.year, now.month, now.day);
          _purchasesEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'this_week':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          _purchasesStartDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
          _purchasesEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'this_month':
          _purchasesStartDate = DateTime(now.year, now.month, 1);
          _purchasesEndDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        case 'all_time':
          _purchasesStartDate = null;
          _purchasesEndDate = null;
          break;
        case 'custom':
          // Keep existing dates, user will set them manually
          break;
      }
    });
    
    _loadPurchases();
  }

  void _applyIncrementsTimePreset(String filterType) {
    final now = DateTime.now();
    setState(() {
      _incrementsTimeFilter = filterType;
      
      switch (filterType) {
        case 'today':
          _incrementsStartDate = DateTime(now.year, now.month, now.day);
          _incrementsEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'this_week':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          _incrementsStartDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
          _incrementsEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'this_month':
          _incrementsStartDate = DateTime(now.year, now.month, 1);
          _incrementsEndDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        case 'all_time':
          _incrementsStartDate = null;
          _incrementsEndDate = null;
          break;
        case 'custom':
          // Keep existing dates, user will set them manually
          break;
      }
    });
    
    _loadIncrements();
  }

  void _clearDetailedMovementsFilters() {
    setState(() {
      _detailedMovementsTimeFilter = 'all_time';
      _detailedMovementsStartDate = null;
      _detailedMovementsEndDate = null;
      _selectedCategoryForDetailed = null;
      _selectedProductForDetailed = null;
      _selectedBusinessForDetailed = null;
      _selectedMovementTypeForDetailed = null;
    });
    
    _loadDetailedMovements();
  }

  void _clearPurchasesFilters() {
    setState(() {
      _purchasesTimeFilter = 'all_time';
      _purchasesStartDate = null;
      _purchasesEndDate = null;
      _selectedCategoryForPurchases = null;
      _selectedProductForPurchases = null;
    });
    
    _loadPurchases();
  }

  void _clearIncrementsFilters() {
    setState(() {
      _incrementsTimeFilter = 'all_time';
      _incrementsStartDate = null;
      _incrementsEndDate = null;
      _selectedCategoryForIncrements = null;
      _selectedProductForIncrements = null;
    });
    
    _loadIncrements();
  }
  
  Future<void> _initializeData() async {
    final user = context.read<AuthProvider>().user;
    
    // Load businesses for all users (needed for transfer dialog)
    await _loadBusinesses();
    
    // Load products and categories for detailed reports
    await _loadProductsForDetailed();
    await _loadCategoriesForDetailed();
    await _loadCategories();
    
    // If superadmin, wait for business selection
    if (user?.role == 'superadmin') {
      // Don't load data yet, wait for business selection
    } else {
      _loadData();
    }
  }
  
  Future<void> _loadBusinesses() async {
    try {
      // Get businesses assigned to this store
      final businesses = await _apiService.getBusinessesAssignedToStore(widget.storeId);
      setState(() {
        _businesses = businesses;
      });
    } catch (e) {
      print('Error loading businesses for store: $e');
      setState(() {
        _error = 'Failed to load businesses for this store: $e';
      });
    }
  }
  
  Future<void> _loadProductsForDetailed() async {
    try {
      final user = context.read<AuthProvider>().user;
      int? businessId;
      
      if (user?.role == 'superadmin') {
        businessId = _selectedBusinessId;
      } else {
        businessId = user?.businessId;
      }
      
      if (businessId != null) {
        final products = await _apiService.getProducts();
        setState(() {
          _productsForDetailed = products.map((product) => {
            'id': product.id,
            'name': product.name,
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading products for detailed reports: $e');
    }
  }
  
  Future<void> _loadCategoriesForDetailed() async {
    try {
      final user = context.read<AuthProvider>().user;
      int? businessId;
      
      if (user?.role == 'superadmin') {
        businessId = _selectedBusinessId;
      } else {
        businessId = user?.businessId;
      }
      
      if (businessId != null) {
        final categories = await _apiService.getCategories();
        setState(() {
          _categoriesForDetailed = categories;
        });
      }
    } catch (e) {
      print('Error loading categories for detailed reports: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _apiService.getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inventoryScrollController.dispose();
    super.dispose();
  }

  void _onInventoryScroll() {
    // Disabled: No pagination needed since API returns all data at once
    // This was causing data duplication issues
    return;
  }

  Future<void> _loadMoreInventory() async {
    // Disabled: The getStoreInventory API returns all data at once, not paginated
    // This method was causing data duplication by adding all inventory data again
    print('🔍 DEBUG: _loadMoreInventory called but disabled - API returns all data at once');
    return;
  }

  // Cache helper methods
  bool _isCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  T? _getFromCache<T>(String key) {
    if (_isCacheValid(key)) {
      return _cache[key] as T?;
    }
    _cache.remove(key);
    _cacheTimestamps.remove(key);
    return null;
  }

  void _setCache(String key, dynamic value) {
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();
  }

  void _clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = context.read<AuthProvider>().user;
      int? businessId;
      
      if (user?.role == 'superadmin') {
        businessId = _selectedBusinessId;
        if (businessId == null) {
          setState(() {
            _error = 'Please select a business to view inventory.';
            _loading = false;
          });
          return;
        }
      } else {
        businessId = user?.businessId;
        if (businessId == null) {
          throw Exception('Business ID not found');
        }
      }
      
      // Clear cache to prevent duplicate data issues
      _clearCache();
      
      print('🔍 DEBUG: Loading inventory for store: ${widget.storeId}, business: $businessId');
      
        // Load inventory
        print('🔍 DEBUG: Fetching inventory from API...');
        final inventory = await _apiService.getStoreInventory(widget.storeId, businessId);
        print('🔍 DEBUG: API response received. Inventory count: ${inventory.length}');
        if (inventory.isNotEmpty) {
          print('🔍 DEBUG: First inventory item: ${inventory[0]}');
          print('🔍 DEBUG: First item store_quantity: ${inventory[0]['store_quantity']} (type: ${inventory[0]['store_quantity'].runtimeType})');
          print('🔍 DEBUG: First item quantity: ${inventory[0]['quantity']} (type: ${inventory[0]['quantity'].runtimeType})');
          print('🔍 DEBUG: First item min_stock_level: ${inventory[0]['min_stock_level']} (type: ${inventory[0]['min_stock_level'].runtimeType})');
        }
        setState(() {
          _inventory = inventory;
        });
      print('🔍 DEBUG: Inventory loaded successfully');
      
      // Load movements
        final movements = await _apiService.getStoreInventoryMovements(
          widget.storeId, 
          businessId,
          // Don't filter at API level, we'll do client-side filtering
          movementType: '',
          productId: '',
        );
        setState(() {
          _movements = movements;
        });
      
      // Load reports
        print('🔍 Loading reports for storeId: ${widget.storeId}, businessId: $businessId');
        final reports = await _apiService.getStoreInventoryReports(widget.storeId, businessId);
        print('📊 Reports loaded: ${reports.keys}');
        print('📊 Current stock data: ${reports['current_stock']}');
        print('📊 Current stock summary: ${reports['current_stock']?['summary']}');
        print('📊 Current stock products: ${reports['current_stock']?['products']?.length ?? 0} products');
        setState(() {
          _reports = reports;
        });
      
    } catch (e) {
      print('Store Inventory Error: $e');
      if (mounted) {
        SuccessUtils.showOperationError(context, 'load store inventory', e.toString());
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Load detailed movements data
  Future<void> _loadDetailedMovements() async {
    if (_detailedMovementsLoading) return;
    
    setState(() {
      _detailedMovementsLoading = true;
    });

    try {
      final user = context.read<AuthProvider>().user;
      int? businessId;
      
      if (user?.role == 'superadmin') {
        businessId = _selectedBusinessId;
        if (businessId == null) {
          throw Exception('Please select a business to view detailed movements.');
        }
      } else {
        businessId = user?.businessId;
        if (businessId == null) {
          throw Exception('Business ID not found');
        }
      }

      final data = await _apiService.getDetailedMovementsReport(
        widget.storeId,
        businessId,
        startDate: _detailedMovementsStartDate?.toIso8601String(),
        endDate: _detailedMovementsEndDate?.toIso8601String(),
        productId: _selectedProductForDetailed,
        categoryId: _selectedCategoryForDetailed != null ? int.tryParse(_selectedCategoryForDetailed!) : null,
        movementType: _selectedMovementTypeForDetailed,
        referenceType: _selectedReferenceType,
        targetBusinessId: _selectedBusinessForDetailed,
        page: _detailedMovementsPage,
        limit: _detailedReportsPageSize,
      );

      setState(() {
        _detailedMovementsData = data;
      });
      
    } catch (e) {
      print('Detailed Movements Error: $e');
      if (mounted) {
        SuccessUtils.showOperationError(context, 'load detailed movements', e.toString());
      }
    } finally {
      setState(() {
        _detailedMovementsLoading = false;
      });
    }
  }

  // Load purchases data
  Future<void> _loadPurchases() async {
    if (_purchasesLoading) return;
    
    setState(() {
      _purchasesLoading = true;
    });

    try {
      final user = context.read<AuthProvider>().user;
      int? businessId;
      
      if (user?.role == 'superadmin') {
        businessId = _selectedBusinessId;
        if (businessId == null) {
          throw Exception('Please select a business to view purchases.');
        }
      } else {
        businessId = user?.businessId;
        if (businessId == null) {
          throw Exception('Business ID not found');
        }
      }

      final data = await _apiService.getPurchasesReport(
        widget.storeId,
        businessId,
        startDate: _purchasesStartDate?.toIso8601String(),
        endDate: _purchasesEndDate?.toIso8601String(),
        productId: _selectedProductForPurchases,
        categoryId: _selectedCategoryForPurchases != null ? int.tryParse(_selectedCategoryForPurchases!) : null,
        page: 1,
        limit: _detailedReportsPageSize,
      );

      setState(() {
        _purchasesData = data;
      });
      
    } catch (e) {
      print('Purchases Error: $e');
      if (mounted) {
        SuccessUtils.showOperationError(context, 'load purchases', e.toString());
      }
    } finally {
      setState(() {
        _purchasesLoading = false;
      });
    }
  }

  // Load increments data
  Future<void> _loadIncrements() async {
    if (_incrementsLoading) return;
    
    setState(() {
      _incrementsLoading = true;
    });

    try {
      final user = context.read<AuthProvider>().user;
      int? businessId;
      
      if (user?.role == 'superadmin') {
        businessId = _selectedBusinessId;
        if (businessId == null) {
          throw Exception('Please select a business to view increments.');
        }
      } else {
        businessId = user?.businessId;
        if (businessId == null) {
          throw Exception('Business ID not found');
        }
      }

      final data = await _apiService.getIncrementsReport(
        widget.storeId,
        businessId,
        startDate: _incrementsStartDate?.toIso8601String(),
        endDate: _incrementsEndDate?.toIso8601String(),
        productId: _selectedProductForIncrements,
        categoryId: _selectedCategoryForIncrements != null ? int.tryParse(_selectedCategoryForIncrements!) : null,
        page: 1,
        limit: _detailedReportsPageSize,
      );

      setState(() {
        _incrementsData = data;
      });
      
    } catch (e) {
      print('Increments Error: $e');
      if (mounted) {
        SuccessUtils.showOperationError(context, 'load increments', e.toString());
      }
    } finally {
      setState(() {
        _incrementsLoading = false;
      });
    }
  }

  // Load business transfers data
  Future<void> _loadBusinessTransfers() async {
    try {
      final user = context.read<AuthProvider>().user;
      int? businessId;
      
      if (user?.role == 'superadmin') {
        businessId = _selectedBusinessId;
        if (businessId == null) {
          throw Exception('Please select a business to view business transfers.');
        }
      } else {
        businessId = user?.businessId;
        if (businessId == null) {
          throw Exception('Business ID not found');
        }
      }
      
      final data = await _apiService.getTransferReports(
        widget.storeId,
        businessId,
        timePeriod: _businessTransfersTimePeriod,
        startDate: _businessTransfersStartDate?.toIso8601String(),
        endDate: _businessTransfersEndDate?.toIso8601String(),
        page: 1,
        limit: _detailedReportsPageSize,
      );
      
      setState(() {
        _businessTransfersData = data;
      });
      
    } catch (e) {
      print('❌ Business Transfers Error: $e');
      if (mounted) {
        SuccessUtils.showOperationError(context, 'load business transfers', e.toString());
      }
    }
  }

  // Load transfer reports data
  Future<void> _loadTransferReports() async {
    if (_transferReportsLoading) return;
    
    print('🔍 FRONTEND: Starting to load transfer reports...');
    print('🔍 FRONTEND: Store ID: ${widget.storeId}');
    print('🔍 FRONTEND: Time Period: $_transferReportsTimePeriod');
    print('🔍 FRONTEND: Start Date: $_transferReportsStartDate');
    print('🔍 FRONTEND: End Date: $_transferReportsEndDate');
    
    setState(() {
      _transferReportsLoading = true;
    });

    try {
      final user = context.read<AuthProvider>().user;
      int? businessId;
      
      if (user?.role == 'superadmin') {
        businessId = _selectedBusinessId;
        if (businessId == null) {
          throw Exception('Please select a business to view transfer reports.');
        }
      } else {
        businessId = user?.businessId;
        if (businessId == null) {
          throw Exception('Business ID not found');
        }
      }
      
      print('🔍 FRONTEND: Business ID determined: $businessId');
      print('🔍 FRONTEND: User role: ${user?.role}');

      print('🔍 FRONTEND: Calling API service...');
      final data = await _apiService.getTransferReports(
        widget.storeId,
        businessId,
        timePeriod: _transferReportsTimePeriod,
        startDate: _transferReportsStartDate?.toIso8601String(),
        endDate: _transferReportsEndDate?.toIso8601String(),
        page: 1,
        limit: _detailedReportsPageSize,
      );
      
      print('🔍 FRONTEND: API call completed successfully');

      setState(() {
        _transferReportsData = data;
      });
      
      print('✅ Transfer Reports Data Loaded:');
      print('  - Transfers count: ${(data['transfers'] as List?)?.length ?? 0}');
      print('  - Summary: ${data['summary']}');
      print('  - Pagination: ${data['pagination']}');
      
    } catch (e) {
      print('❌ FRONTEND: Transfer Reports Error: $e');
      print('❌ FRONTEND: Error type: ${e.runtimeType}');
      if (mounted) {
        String errorMessage = 'Failed to load transfer reports';
        
        if (e is ArgumentError) {
          errorMessage = 'Invalid parameters: ${e.message}';
        } else if (e.toString().contains('Validation Error')) {
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        } else if (e.toString().contains('Access denied')) {
          errorMessage = 'Access denied: You do not have permission to view this data';
        } else if (e.toString().contains('not found')) {
          errorMessage = 'Store or business not found';
        } else if (e.toString().contains('Network error')) {
          errorMessage = 'Network error: Please check your connection';
        } else if (e.toString().contains('Server Error')) {
          errorMessage = 'Server error: Please try again later';
        }
        
        SuccessUtils.showOperationError(context, 'load transfer reports', errorMessage);
      }
    } finally {
      setState(() {
        _transferReportsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final isSuperAdmin = user?.role == 'superadmin';
    final screenSize = MediaQuery.of(context).size;
        final isMobile = ResponsiveUtils.isMobile(context);
        final isTablet = ResponsiveUtils.isTablet(context);
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: BrandedAppBar(
        title: '${t(context,'Store Inventory')} - ${widget.storeName}',
        actions: [
          // Business selection for superadmin
          if (isSuperAdmin && _businesses.isNotEmpty)
            Container(
              width: isMobile ? 150 : 200,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButtonFormField<int>(
                value: _selectedBusinessId,
                decoration: InputDecoration(
                  labelText: t(context, 'Select Business'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _businesses.map((business) {
                  return DropdownMenuItem<int>(
                    value: business['id'],
                    child: Text(
                      business['name'] ?? 'Business ${business['id']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBusinessId = value;
                  });
                  _loadData();
                  // Reload products and categories for the selected business
                  _loadProductsForDetailed();
                  _loadCategoriesForDetailed();
                },
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddProductsDialog,
            tooltip: t(context,'Add Products'),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _showTransferDialog,
            tooltip: t(context,'Transfer to Business'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: t(context,'Refresh'),
          ),
        ],
      ),
      body: _buildResponsiveBody(context, isSuperAdmin, isMobile, isTablet),
    );
  }

  Widget _buildResponsiveBody(BuildContext context, bool isSuperAdmin, bool isMobile, bool isTablet) {
    if (isMobile) {
      return _buildMobileLayout(context, isSuperAdmin);
    } else if (isTablet) {
      return _buildTabletLayout(context, isSuperAdmin);
    } else {
      return _buildDesktopLayout(context, isSuperAdmin);
    }
  }

  Widget _buildMobileLayout(BuildContext context, bool isSuperAdmin) {
    return Column(
      children: [
        // Mobile Tab Bar
        Container(
          color: Theme.of(context).primaryColor,
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                icon: const Icon(Icons.inventory_2, size: 20),
                text: t(context,'Inventory'),
              ),
              Tab(
                icon: const Icon(Icons.trending_up, size: 20),
                text: t(context,'Movements'),
              ),
              Tab(
                icon: const Icon(Icons.analytics, size: 20),
                text: t(context,'Reports'),
              ),
              Tab(
                icon: const Icon(Icons.list_alt, size: 20),
                text: t(context,'Details'),
              ),
              Tab(
                icon: const Icon(Icons.shopping_cart, size: 20),
                text: t(context,'Purchases'),
              ),
              Tab(
                icon: const Icon(Icons.add_box, size: 20),
                text: t(context,'Increments'),
              ),
              Tab(
                icon: const Icon(Icons.swap_horiz, size: 20),
                text: 'Transfers',
              ),
            ],
          ),
        ),
        
        // Mobile Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMobileInventoryTab(),
              _buildMobileMovementsTab(),
              _buildMobileReportsTab(),
              _buildMobileDetailedMovementsTab(),
              _buildMobilePurchasesTab(),
              _buildMobileIncrementsTab(),
              _buildMobileTransferReportsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context, bool isSuperAdmin) {
    return Column(
      children: [
        // Tablet Tab Bar
        Container(
          color: Theme.of(context).primaryColor,
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            isScrollable: true,
            tabs: [
              Tab(
                icon: const Icon(Icons.inventory_2),
                text: t(context,'Inventory'),
              ),
              Tab(
                icon: const Icon(Icons.trending_up),
                text: t(context,'Movements'),
              ),
              Tab(
                icon: const Icon(Icons.analytics),
                text: t(context,'Reports'),
              ),
              Tab(
                icon: const Icon(Icons.list_alt),
                text: t(context,'Detailed Movements'),
              ),
              Tab(
                icon: const Icon(Icons.shopping_cart),
                text: t(context,'Purchases'),
              ),
              Tab(
                icon: const Icon(Icons.add_box),
                text: t(context,'Increments'),
              ),
            ],
          ),
        ),
        
        // Tablet Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTabletInventoryTab(),
              _buildTabletMovementsTab(),
              _buildTabletReportsTab(),
              _buildTabletDetailedMovementsTab(),
              _buildTabletPurchasesTab(),
              _buildTabletIncrementsTab(),
              _buildTabletTransferReportsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, bool isSuperAdmin) {
    return Column(
      children: [
        // Desktop Tab Bar
        Container(
          color: Theme.of(context).primaryColor,
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                icon: const Icon(Icons.inventory_2),
                text: t(context,'Inventory'),
              ),
              Tab(
                icon: const Icon(Icons.trending_up),
                text: t(context,'Movements'),
              ),
              Tab(
                icon: const Icon(Icons.analytics),
                text: t(context,'Reports'),
              ),
              Tab(
                icon: const Icon(Icons.list_alt),
                text: t(context,'Detailed Movements'),
              ),
              Tab(
                icon: const Icon(Icons.shopping_cart),
                text: t(context,'Purchases'),
              ),
              Tab(
                icon: const Icon(Icons.add_box),
                text: t(context,'Increments'),
              ),
              Tab(
                icon: const Icon(Icons.swap_horiz),
                text: 'Transfers',
              ),
            ],
          ),
        ),
        
        // Desktop Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDesktopInventoryTab(),
              _buildDesktopMovementsTab(),
              _buildDesktopReportsTab(),
              _buildDesktopDetailedMovementsTab(),
              _buildDesktopPurchasesTab(),
              _buildDesktopIncrementsTab(),
              _buildDesktopTransferReportsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryTab() {
    if (_loading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: t(context,'Search products...'),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        
        // Inventory List
        Expanded(
          child: _buildInventoryList(),
        ),
      ],
    );
  }

  Widget _buildInventoryList() {
    print('🔍 DEBUG: Building inventory list. Total inventory items: ${_inventory.length}');
    
    // Check loading state first - show loading if data is being fetched
    if (_loading) {
      return _buildLoadingState();
    }
    
    final filteredInventory = _inventory.where((item) {
      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          item['product_name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item['sku'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (item['category_name'] ?? item['category'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      
      // Stock status filter
      final matchesStockStatus = _selectedStockStatus.isEmpty ||
          (item['stock_status'] ?? '').toString() == _selectedStockStatus;
      
      // Category filter
      final matchesCategory = _selectedCategory.isEmpty ||
          (item['category_name'] ?? item['category'] ?? '').toString() == _selectedCategory;
      
      // Price range filter
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
      final matchesPriceRange = (_minPrice == null || price >= _minPrice!) &&
          (_maxPrice == null || price <= _maxPrice!);
      
      return matchesSearch && matchesStockStatus && matchesCategory && matchesPriceRange;
    }).toList();

    if (filteredInventory.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inventory_2_outlined,
        title: t(context,'No inventory found'),
        subtitle: t(context,'Add products to this store to get started'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        controller: _inventoryScrollController,
        padding: const EdgeInsets.all(16),
        itemCount: filteredInventory.length,
        itemBuilder: (context, index) {
          final item = filteredInventory[index];
          print('🔍 DEBUG: Building card for item at index $index: ${item['product_name']}');
          return _buildProfessionalInventoryCard(item);
        },
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final stockStatus = item['stock_status'] as String?;
    Color statusColor;
    IconData statusIcon;
    
    switch (stockStatus) {
      case 'LOW_STOCK':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      case 'OUT_OF_STOCK':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (item['image_url'] != null && item['image_url'].toString().isNotEmpty) ...[
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        'https://rtailed-production.up.railway.app${item['image_url']}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.image, color: Colors.grey[400]),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['product_name'] ?? '',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item['description'],
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${item['sku'] ?? ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _getStockStatusLabel(stockStatus),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuantityInfo(
                    t(context,'Store Quantity'),
                    _safeToInt(item['store_quantity'] ?? item['quantity']),
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildQuantityInfo(
                    t(context,'Min Level'),
                    item['min_stock_level'] ?? 0,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildQuantityInfo(
                    t(context,'Inventory ID'),
                    item['inventory_id'] ?? 0,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.inventory, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${t(context,'Store Quantity')}: ${_safeToInt(item['store_quantity'] ?? item['quantity'])}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.warning, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${t(context,'Min Level')}: ${item['min_stock_level'] ?? 0}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${t(context,'Cost Price')}: ₦${(double.tryParse(item['cost_price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.sell, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${t(context,'Selling Price')}: ₦${(double.tryParse(item['price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.update, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${t(context,'Last Updated')}: ${_formatDate(item['last_updated'])}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${t(context,'Updated By')}: ${item['updated_by'] ?? 'N/A'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showIncrementDialog(item),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(t(context,'Add Stock'), style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditCostPriceDialog(item),
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text(t(context,'Edit Cost'), style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showTransferDialog(),
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: Text(t(context,'Transfer'), style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityInfo(String label, int quantity, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            quantity.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionalInventoryCard(Map<String, dynamic> item) {
    print('🔍 DEBUG: Building professional inventory card for item: ${item['product_name']}');
    print('🔍 DEBUG: Raw item data: $item');
    
    final stockStatus = item['stock_status'] as String?;
    print('🔍 DEBUG: stock_status: $stockStatus (type: ${stockStatus.runtimeType})');
    
    final rawQuantity = item['store_quantity'] ?? item['quantity'];
    print('🔍 DEBUG: Raw quantity: $rawQuantity (type: ${rawQuantity.runtimeType})');
    final quantity = _safeToInt(rawQuantity);
    print('🔍 DEBUG: Converted quantity: $quantity (type: ${quantity.runtimeType})');
    
    final rawMinStock = item['min_stock_level'];
    print('🔍 DEBUG: Raw min_stock_level: $rawMinStock (type: ${rawMinStock.runtimeType})');
    final minStock = _safeToInt(rawMinStock);
    print('🔍 DEBUG: Converted minStock: $minStock (type: ${minStock.runtimeType})');
    
    final rawCostPrice = item['cost_price'];
    print('🔍 DEBUG: Raw cost_price: $rawCostPrice (type: ${rawCostPrice.runtimeType})');
    final costPrice = double.tryParse(rawCostPrice?.toString() ?? '0') ?? 0.0;
    print('🔍 DEBUG: Converted costPrice: $costPrice (type: ${costPrice.runtimeType})');
    
    final rawSellingPrice = item['price'];
    print('🔍 DEBUG: Raw price: $rawSellingPrice (type: ${rawSellingPrice.runtimeType})');
    final sellingPrice = double.tryParse(rawSellingPrice?.toString() ?? '0') ?? 0.0;
    print('🔍 DEBUG: Converted sellingPrice: $sellingPrice (type: ${sellingPrice.runtimeType})');
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (stockStatus) {
      case 'LOW_STOCK':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        statusText = 'Low Stock';
        break;
      case 'OUT_OF_STOCK':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Out of Stock';
        break;
      default:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'In Stock';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withOpacity(0.8),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Product Image
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.grey[100],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: item['image_url'] != null && item['image_url'].toString().isNotEmpty
                          ? Image.network(
                              'https://rtailed-production.up.railway.app${item['image_url']}',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: Icon(Icons.image, color: Colors.grey[400], size: 32),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: Icon(Icons.image, color: Colors.grey[400], size: 32),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Product Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['product_name'] ?? 'Unknown Product',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'SKU: ${item['sku'] ?? 'N/A'}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Stock Quantity Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Stock',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          quantity.toString(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Price Information
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildPriceInfo(
                        'Cost Price',
                        '₦${costPrice.toStringAsFixed(2)}',
                        Icons.monetization_on,
                        Colors.green,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[300],
                    ),
                    Expanded(
                      child: _buildPriceInfo(
                        'Selling Price',
                        '₦${sellingPrice.toStringAsFixed(2)}',
                        Icons.sell,
                        Colors.blue,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[300],
                    ),
                    Expanded(
                      child: _buildPriceInfo(
                        'Profit Margin',
                        '₦${(sellingPrice - costPrice).clamp(0.0, double.infinity).toStringAsFixed(2)}',
                        Icons.trending_up,
                        sellingPrice > costPrice ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              if (minStock > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Minimum Stock Level: $minStock',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddStockDialog(item),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Stock'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditCostDialog(item),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Cost'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceInfo(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getStockStatusLabel(String? status) {
    switch (status) {
      case 'LOW_STOCK':
        return t(context,'Low Stock');
      case 'OUT_OF_STOCK':
        return t(context,'Out of Stock');
      case 'IN_STOCK':
        return t(context,'In Stock');
      default:
        return t(context,'Unknown');
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildMovementsTab() {
    return Column(
      children: [
        // Enhanced Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Filter Row
              Row(
                children: [
                  // Movement Type Filter
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedMovementType.isEmpty ? null : _selectedMovementType,
                      decoration: InputDecoration(
                        labelText: t(context,'Movement Type'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem(value: '', child: Text(t(context,'All Types'))),
                        DropdownMenuItem(value: 'in', child: Text(t(context,'Stock In'))),
                        DropdownMenuItem(value: 'out', child: Text(t(context,'Stock Out'))),
                        DropdownMenuItem(value: 'transfer_out', child: Text(t(context,'Transfer Out'))),
                        DropdownMenuItem(value: 'adjustment', child: Text(t(context,'Adjustment'))),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedMovementType = value ?? '';
                        });
                        // No need to reload data, filtering is done client-side
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Product Filter
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedProductId.isEmpty ? null : _selectedProductId,
                      decoration: InputDecoration(
                        labelText: t(context,'Product'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem(value: '', child: Text(t(context,'All Products'))),
                        ..._inventory.map((item) => DropdownMenuItem(
                          value: item['product_id']?.toString() ?? '',
                          child: Text(item['product_name'] ?? 'Unknown'),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedProductId = value ?? '';
                        });
                        // No need to reload data, filtering is done client-side
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Clear Filters Button
                  if (_selectedMovementType.isNotEmpty || _selectedProductId.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedMovementType = '';
                          _selectedProductId = '';
                        });
                      },
                      icon: const Icon(Icons.clear, size: 18),
                      label: Text(t(context,'Clear')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  if (_selectedMovementType.isNotEmpty || _selectedProductId.isNotEmpty)
                    const SizedBox(width: 8),
                  // Refresh Button
                  ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(t(context,'Refresh')),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Quick Stats
              _buildMovementsQuickStats(),
            ],
          ),
        ),
        
        // Movements List
        Expanded(
          child: _buildMovementsList(),
        ),
      ],
    );
  }

  Widget _buildMovementsQuickStats() {
    // Apply same filtering logic as the list
    final filteredMovements = _movements.where((movement) {
      if (_selectedMovementType.isNotEmpty && movement['movement_type'] != _selectedMovementType) {
        return false;
      }
      if (_selectedProductId.isNotEmpty && movement['product_id']?.toString() != _selectedProductId) {
        return false;
      }
      return true;
    }).toList();

    final totalMovements = filteredMovements.length;
    final stockInCount = filteredMovements.where((m) => m['movement_type'] == 'in').length;
    final stockOutCount = filteredMovements.where((m) => m['movement_type'] == 'out').length;
    final transferCount = filteredMovements.where((m) => m['movement_type'] == 'transfer_out').length;
    final adjustmentCount = filteredMovements.where((m) => m['movement_type'] == 'adjustment').length;

    return Row(
      children: [
        Expanded(
          child: _buildMovementStatCard(
            'Total',
            totalMovements.toString(),
            Icons.history,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMovementStatCard(
            'Stock In',
            stockInCount.toString(),
            Icons.arrow_downward,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMovementStatCard(
            'Stock Out',
            stockOutCount.toString(),
            Icons.arrow_upward,
            Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMovementStatCard(
            'Transfers',
            transferCount.toString(),
            Icons.send,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMovementStatCard(
            'Adjustments',
            adjustmentCount.toString(),
            Icons.edit,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildMovementStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMovementsList() {
    // Check loading state first - show loading if data is being fetched
    if (_loading) {
      return _buildLoadingState();
    }
    
    // Apply client-side filtering
    final filteredMovements = _movements.where((movement) {
      // Filter by movement type
      if (_selectedMovementType.isNotEmpty && movement['movement_type'] != _selectedMovementType) {
        return false;
      }
      
      // Filter by product ID
      if (_selectedProductId.isNotEmpty && movement['product_id']?.toString() != _selectedProductId) {
        return false;
      }
      
      return true;
    }).toList();

    if (filteredMovements.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: t(context, 'No movements found'),
        subtitle: _selectedMovementType.isNotEmpty || _selectedProductId.isNotEmpty
            ? t(context, 'No movements match the selected filters')
            : t(context, 'Inventory movements will appear here when products are added or transferred'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: filteredMovements.map((movement) => _buildMovementCard(movement)).toList(),
      ),
    );
  }

  Widget _buildMovementCard(Map<String, dynamic> movement) {
    final movementType = movement['movement_type'] as String?;
    final quantity = _safeToInt(movement['quantity'] ?? 0);
    final previousQuantity = _safeToInt(movement['previous_quantity'] ?? 0);
    final newQuantity = _safeToInt(movement['new_quantity'] ?? 0);
    final referenceType = movement['reference_type'] as String?;
    final notes = movement['notes'] as String?;
    
    Color typeColor;
    IconData typeIcon;
    String typeLabel;
    
    switch (movementType) {
      case 'in':
        typeColor = Colors.green;
        typeIcon = Icons.arrow_downward;
        typeLabel = t(context,'Stock In');
        break;
      case 'out':
        typeColor = Colors.red;
        typeIcon = Icons.arrow_upward;
        typeLabel = t(context,'Stock Out');
        break;
      case 'transfer_out':
        typeColor = Colors.blue;
        typeIcon = Icons.send;
        typeLabel = t(context,'Transfer Out');
        break;
      case 'adjustment':
        typeColor = Colors.orange;
        typeIcon = Icons.edit;
        typeLabel = t(context,'Adjustment');
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.help;
        typeLabel = t(context,'Unknown');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Movement Type Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 20),
                ),
                const SizedBox(width: 12),
                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movement['product_name'] ?? 'Unknown Product',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${movement['sku'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeAwareColors.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                // Movement Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Quantity Information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quantity',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${quantity > 0 ? '+' : ''}$quantity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: typeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Previous',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '$previousQuantity',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '$newQuantity',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Additional Information
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reference',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        referenceType ?? 'Manual',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'By',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        movement['created_by_username'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        _formatDate(movement['created_at']),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Business Information (for transfers)
            if (movementType == 'transfer_out' && movement['business_name'] != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transferred to Business',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            movement['business_name'] ?? 'Unknown Business',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Notes (if available)
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  'Note: $notes',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[800],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    print('🔍 Building reports tab - _reports: ${_reports.keys}');
    print('🔍 _reports isEmpty: ${_reports.isEmpty}');
    print('🔍 _reports current_stock: ${_reports['current_stock']}');
    
    if (_loading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isSmallScreen = screenWidth < 768;
        final isMediumScreen = screenWidth >= 768 && screenWidth < 1024;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              // Responsive Report Header
          Container(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
                  borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 16),
                  ),
                      child: Icon(
                        Icons.analytics, 
                        color: Colors.white, 
                        size: isSmallScreen ? 20 : 28,
                ),
                    ),
                    SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(context, 'Store Inventory Analytics'),
                            style: TextStyle(
                          color: Colors.white,
                              fontSize: isSmallScreen ? 18 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.storeName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                              fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                    if (_reports.isNotEmpty && _reports['report_metadata'] != null && !isSmallScreen)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Last updated: ${_formatDate(DateTime.parse(_reports['report_metadata']['generated_at']))}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
              SizedBox(height: isSmallScreen ? 16 : 24),
              
              // Use responsive content based on screen size
              if (isSmallScreen)
                _buildUnifiedReportsContent() // Use mobile-optimized content
              else
                _buildResponsiveReportsContent(isMediumScreen), // Use responsive desktop content
            ],
          ),
        );
      },
    );
  }

  // =====================================================
  // RESPONSIVE REPORTS CONTENT
  // =====================================================

  Widget _buildResponsiveReportsContent(bool isMediumScreen) {
    final currentStock = _reports['current_stock']?['summary'] ?? {};
    final financialSummary = _reports['financial_summary'] ?? {};
    final movementSummary = _reports['movement_summary'] ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Responsive Key Metrics Dashboard
        _buildResponsiveKeyMetricsDashboard(isMediumScreen),
          
          const SizedBox(height: 24),
          
        // Responsive Charts and Analytics Grid
        _buildResponsiveAnalyticsGrid(isMediumScreen),
          
          const SizedBox(height: 24),
          
          // Detailed Reports Section
          _buildDetailedReportsSection(),
        ],
    );
  }

  Widget _buildResponsiveKeyMetricsDashboard(bool isMediumScreen) {
    final currentStock = _reports['current_stock']?['summary'] ?? {};
    final financialSummary = _reports['financial_summary'] ?? {};
    final movementSummary = _reports['movement_summary'] ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Performance Indicators',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(), // Enable scrolling
          crossAxisCount: isMediumScreen ? 1 : 2, // Single column on medium, two columns on large for horizontal cards
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isMediumScreen ? 3.5 : 3.0, // Wider aspect ratio for horizontal cards
          children: [
            _buildHorizontalMetricCardWithSubtitle(
              'Total Products',
              (currentStock['total_products'] ?? 0).toString(),
              Icons.inventory_2,
              Colors.blue,
              'Active inventory items',
            ),
            _buildHorizontalMetricCardWithSubtitle(
              'Total Units',
              (currentStock['total_units'] ?? 0).toString(),
              Icons.shopping_cart,
              Colors.green,
              'Units in stock',
            ),
            _buildHorizontalMetricCardWithSubtitle(
              'Total Value',
              '₦${(double.tryParse(financialSummary['total_selling_value']?.toString() ?? '0') ?? 0.0).toStringAsFixed(0)}',
              Icons.attach_money,
              Colors.purple,
              'Inventory value',
            ),
            _buildHorizontalMetricCardWithSubtitle(
              'Low Stock Items',
              (currentStock['low_stock'] ?? 0).toString(),
              Icons.warning,
              Colors.orange,
              'Need restocking',
            ),
            if (!isMediumScreen) ...[ // Only show additional metrics on large screens
              _buildHorizontalMetricCardWithSubtitle(
                'Out of Stock',
                (currentStock['out_of_stock'] ?? 0).toString(),
                Icons.error,
                Colors.red,
                'Critical items',
              ),
              _buildHorizontalMetricCardWithSubtitle(
                'Total Movements',
                (movementSummary['total_products_with_movements'] ?? 0).toString(),
                Icons.trending_up,
                Colors.teal,
                'Active products',
              ),
              _buildHorizontalMetricCardWithSubtitle(
                'Stock Added',
                (movementSummary['total_stock_in'] ?? 0).toString(),
                Icons.add_box,
                Colors.indigo,
                'Units added',
              ),
              _buildHorizontalMetricCardWithSubtitle(
                'Transferred Out',
                (movementSummary['total_transferred_out'] ?? 0).toString(),
                Icons.send,
                Colors.cyan,
                'Units transferred',
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildResponsiveAnalyticsGrid(bool isMediumScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics Overview',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(), // Enable scrolling
          crossAxisCount: isMediumScreen ? 1 : 2, // Single column on medium, two columns on large
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isMediumScreen ? 2.5 : 1.8,
          children: [
            // Current Stock Summary
            if (_reports['current_stock'] != null) ...[
              _buildCurrentStockSection(),
            ],
            
            // Financial Overview
            if (_reports['financial_summary'] != null && _reports['financial_summary'].isNotEmpty) ...[
              _buildFinancialOverviewSection(_reports['financial_summary']),
            ],
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Recent Movements (always full width)
        if (_reports['recent_movements'] != null) ...[
          _buildRecentMovementsSection(),
        ],
      ],
    );
  }

  // =====================================================
  // MODERN ANALYTICS DASHBOARD METHODS
  // =====================================================

  Widget _buildKeyMetricsDashboard() {
    final currentStock = _reports['current_stock']?['summary'] ?? {};
    final financialSummary = _reports['financial_summary'] ?? {};
    final movementSummary = _reports['movement_summary'] ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Performance Indicators',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(), // Enable scrolling
          crossAxisCount: 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildMetricCard(
              'Total Products',
              (currentStock['total_products'] ?? 0).toString(),
              Icons.inventory_2,
              Colors.blue,
              'Active inventory items',
            ),
            _buildMetricCard(
              'Total Units',
              (currentStock['total_units'] ?? 0).toString(),
              Icons.shopping_cart,
              Colors.green,
              'Units in stock',
            ),
            _buildMetricCard(
              'Total Value',
              '₦${(double.tryParse(financialSummary['total_selling_value']?.toString() ?? '0') ?? 0.0).toStringAsFixed(0)}',
              Icons.attach_money,
              Colors.purple,
              'Inventory value',
            ),
            _buildMetricCard(
              'Low Stock Items',
              (currentStock['low_stock'] ?? 0).toString(),
              Icons.warning,
              Colors.orange,
              'Need restocking',
            ),
            _buildMetricCard(
              'Out of Stock',
              (currentStock['out_of_stock'] ?? 0).toString(),
              Icons.error,
              Colors.red,
              'Critical items',
            ),
            _buildMetricCard(
              'Total Movements',
              (movementSummary['total_products_with_movements'] ?? 0).toString(),
              Icons.trending_up,
              Colors.teal,
              'Active products',
            ),
            _buildMetricCard(
              'Stock Added',
              (movementSummary['total_stock_in'] ?? 0).toString(),
              Icons.add_box,
              Colors.indigo,
              'Units added',
            ),
            _buildMetricCard(
              'Transferred Out',
              (movementSummary['total_transferred_out'] ?? 0).toString(),
              Icons.send,
              Colors.cyan,
              'Units transferred',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ThemeAwareColors.getSecondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalMetricCardWithSubtitle(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          // Content section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ThemeAwareColors.getSecondaryTextColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics & Insights',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(), // Enable scrolling
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.8,
          children: [
            _buildAnalyticsCard(
              'Stock Status Distribution',
              Icons.pie_chart,
              Colors.blue,
              _buildStockStatusChart(),
            ),
            _buildAnalyticsCard(
              'Financial Overview',
              Icons.account_balance_wallet,
              Colors.green,
              _buildFinancialOverview(),
            ),
            _buildAnalyticsCard(
              'Movement Trends',
              Icons.trending_up,
              Colors.orange,
              _buildMovementTrends(),
            ),
            _buildAnalyticsCard(
              'Top Products',
              Icons.star,
              Colors.purple,
              _buildTopProductsPreview(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(String title, IconData icon, Color color, Widget content) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildStockStatusChart() {
    final currentStock = _reports['current_stock']?['summary'] ?? {};
    final inStock = currentStock['in_stock'] ?? 0;
    final lowStock = currentStock['low_stock'] ?? 0;
    final outOfStock = currentStock['out_of_stock'] ?? 0;
    final total = inStock + lowStock + outOfStock;
    
    if (total == 0) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: ThemeAwareColors.getSecondaryTextColor(context)),
        ),
      );
    }
    
    return Column(
      children: [
        // Simple bar chart representation
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: (inStock / total) * 100,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'In Stock',
                      style: TextStyle(fontSize: 10, color: ThemeAwareColors.getSecondaryTextColor(context)),
                    ),
                    Text(
                      inStock.toString(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: (lowStock / total) * 100,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Low Stock',
                      style: TextStyle(fontSize: 10, color: ThemeAwareColors.getSecondaryTextColor(context)),
                    ),
                    Text(
                      lowStock.toString(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: (outOfStock / total) * 100,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Out of Stock',
                      style: TextStyle(fontSize: 10, color: ThemeAwareColors.getSecondaryTextColor(context)),
                    ),
                    Text(
                      outOfStock.toString(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialOverview() {
    final financialSummary = _reports['financial_summary'] ?? {};
    final totalCost = double.tryParse(financialSummary['total_cost_value']?.toString() ?? '0') ?? 0.0;
    final totalSelling = double.tryParse(financialSummary['total_selling_value']?.toString() ?? '0') ?? 0.0;
    final profitPotential = (totalSelling - totalCost).clamp(0.0, double.infinity);
    
    return Column(
      children: [
        _buildFinancialRow('Total Cost Value', '₦${totalCost.toStringAsFixed(0)}', Colors.red),
        const SizedBox(height: 8),
        _buildFinancialRow('Total Selling Value', '₦${totalSelling.toStringAsFixed(0)}', Colors.green),
        const SizedBox(height: 8),
        _buildFinancialRow('Profit Potential', '₦${profitPotential.toStringAsFixed(0)}', Colors.blue),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ThemeAwareColors.getInputFillColor(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profit Margin',
                style: TextStyle(fontSize: 12, color: ThemeAwareColors.getSecondaryTextColor(context)),
              ),
              Text(
                totalSelling > 0 ? '${((profitPotential / totalSelling) * 100).toStringAsFixed(1)}%' : '0%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: ThemeAwareColors.getSecondaryTextColor(context)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMovementTrends() {
    final movementSummary = _reports['movement_summary'] ?? {};
    final stockIn = (movementSummary['total_stock_in'] ?? 0) as int;
    final transferredOut = (movementSummary['total_transferred_out'] ?? 0) as int;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTrendItem('Stock Added', stockIn.toString(), Icons.add_box, Colors.green),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTrendItem('Transferred', transferredOut.toString(), Icons.send, Colors.blue),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ThemeAwareColors.getInputFillColor(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Net Movement',
                style: TextStyle(fontSize: 12, color: ThemeAwareColors.getSecondaryTextColor(context)),
              ),
              Text(
                (stockIn - transferredOut).toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: (stockIn - transferredOut) >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrendItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: ThemeAwareColors.getSecondaryTextColor(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsPreview() {
    final topProducts = _reports['top_products'] ?? [];
    
    if (topProducts.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: ThemeAwareColors.getSecondaryTextColor(context)),
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      itemCount: topProducts.length > 3 ? 3 : topProducts.length,
      itemBuilder: (context, index) {
        final product = topProducts[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.purple,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  product['product_name'] ?? 'Unknown',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${product['movement_count'] ?? 0}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailedReportsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detailed Reports',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        // Keep existing detailed report methods
        _buildCurrentStockSummary(),
        const SizedBox(height: 16),
        _buildFinancialSummary(),
        const SizedBox(height: 16),
        _buildMovementSummary(),
        const SizedBox(height: 16),
        _buildLowStockAlerts(),
        const SizedBox(height: 16),
        _buildTopProducts(),
      ],
    );
  }

  // =====================================================
  // NEW DETAILED REPORT TABS
  // =====================================================

  Widget _buildDetailedMovementsTab() {
    if (_detailedMovementsLoading) {
      return _buildLoadingState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isSmallScreen = screenWidth < 768;
        final isMediumScreen = screenWidth >= 768 && screenWidth < 1024;
        final isLargeScreen = screenWidth >= 1024;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12 : isMediumScreen ? 16 : 20),
      child: Column(
      children: [
        // Enhanced Header with filters - Responsive
        Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : isMediumScreen ? 16 : 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header Row - Responsive
              isSmallScreen 
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detailed Movements Report',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Quick Actions - Stacked on mobile
                      Row(
                        children: [
                            // Refresh icon for whole screen
                            IconButton(
                              onPressed: _loadDetailedMovements,
                              icon: const Icon(Icons.refresh, size: 18),
                              tooltip: 'Refresh Data',
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                foregroundColor: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _clearDetailedMovementsFilters,
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('Clear'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _loadDetailedMovements,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Refresh'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Detailed Movements Report',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Quick Actions - Side by side on desktop
                      Row(
                        children: [
                            // Refresh icon for whole screen
                            IconButton(
                              onPressed: _loadDetailedMovements,
                              icon: const Icon(Icons.refresh, size: 20),
                              tooltip: 'Refresh Data',
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                foregroundColor: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _clearDetailedMovementsFilters,
                            icon: const Icon(Icons.clear, size: 18),
                            label: const Text('Clear Filters'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _loadDetailedMovements,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Refresh'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                SizedBox(height: isSmallScreen ? 12 : 16),
              
                // Enhanced Filters - Responsive (No longer scrollable separately)
              _buildResponsiveDetailedMovementsFilters(),
            ],
          ),
        ),
        
          const SizedBox(height: 16),
          
          // Data Display - Now part of the main scroll
          _detailedMovementsLoading
              ? const Center(child: CircularProgressIndicator())
              : _detailedMovementsData.isEmpty
                  ? _buildEmptyDetailedMovements()
                  : _buildResponsiveDetailedMovementsTable(),
      ],
      ),
    );
      },
    );
  }

  Widget _buildPurchasesTab() {
    if (_purchasesLoading) {
      return _buildLoadingState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with filters
          Row(
            children: [
              Expanded(
                child: Text(
                  'Purchases Report',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadPurchases,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Data',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Filters Row
          _buildPurchasesFilters(),
          const SizedBox(height: 16),
          
          // Data Display
          _purchasesLoading
              ? const Center(child: CircularProgressIndicator())
              : _purchasesData.isEmpty
                  ? _buildEmptyPurchases()
                  : _buildPurchasesTable(),
        ],
      ),
    );
  }

  Widget _buildIncrementsTab() {
    if (_incrementsLoading) {
      return _buildLoadingState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with filters
          Row(
            children: [
              Expanded(
                child: Text(
                  'Increments Report',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadIncrements,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Data',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Filters Row
          _buildIncrementsFilters(),
          const SizedBox(height: 16),
          
          // Data Display
          _incrementsLoading
              ? const Center(child: CircularProgressIndicator())
              : _incrementsData.isEmpty
                  ? _buildEmptyIncrements()
                  : _buildIncrementsTable(),
        ],
      ),
    );
  }

  // =====================================================
  // MOBILE-SPECIFIC TAB METHODS
  // =====================================================

  Widget _buildMobileInventoryTab() {
    if (_loading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return Column(
      children: [
        // Mobile Search and Filters
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: t(context,'Search products...'),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              // Quick Stats
              _buildMobileQuickStats(),
            ],
          ),
        ),
        
        // Mobile Inventory List
        Expanded(
          child: _buildMobileInventoryList(),
        ),
      ],
    );
  }

  Widget _buildMobileMovementsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Mobile Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.trending_up, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventory Movements',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Track all stock movements',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Mobile Filters
          _buildMobileMovementFilters(),
          const SizedBox(height: 16),
          
          // Mobile Movements List
          _buildMobileMovementsList(_movements),
        ],
      ),
    );
  }

  Widget _buildMobileReportsTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isSmallMobile = screenWidth < 480;
        
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
              // Responsive Mobile Header
          Container(
                padding: EdgeInsets.all(isSmallMobile ? 12 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
                  borderRadius: BorderRadius.circular(isSmallMobile ? 12 : 16),
            ),
            child: Row(
              children: [
                Container(
                      padding: EdgeInsets.all(isSmallMobile ? 6 : 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(isSmallMobile ? 6 : 8),
                  ),
                      child: Icon(
                        Icons.analytics, 
                        color: Colors.white,
                        size: isSmallMobile ? 16 : 20,
                ),
                    ),
                    SizedBox(width: isSmallMobile ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventory Reports',
                            style: TextStyle(
                          color: Colors.white,
                              fontSize: isSmallMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Comprehensive analytics',
                            style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                              fontSize: isSmallMobile ? 12 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
              SizedBox(height: isSmallMobile ? 12 : 16),
          
          // Reports Content
          if (_reports.isEmpty)
            _buildEmptyState(
              icon: Icons.analytics_outlined,
              title: 'No Reports Available',
              subtitle: 'Reports will appear here when data is loaded',
            )
          else
                _buildResponsiveUnifiedReportsContent(isSmallMobile),
        ],
      ),
        );
      },
    );
  }

  Widget _buildMobileDetailedMovementsTab() {
    return _buildDetailedMovementsTab(); // Use the same implementation as desktop
  }

  Widget _buildMobilePurchasesTab() {
    return _buildPurchasesTab(); // Use the same implementation as desktop
  }

  Widget _buildMobileIncrementsTab() {
    return _buildIncrementsTab(); // Use the same implementation as desktop
  }

  // =====================================================
  // TABLET-SPECIFIC TAB METHODS
  // =====================================================

  Widget _buildTabletInventoryTab() {
    return _buildDesktopInventoryTab(); // Reuse desktop for now
  }

  Widget _buildTabletMovementsTab() {
    return _buildDesktopMovementsTab(); // Reuse desktop for now
  }

  Widget _buildTabletReportsTab() {
    return _buildDesktopReportsTab(); // Reuse desktop for now
  }

  Widget _buildTabletDetailedMovementsTab() {
    return _buildDesktopDetailedMovementsTab(); // Reuse desktop for now
  }

  Widget _buildTabletPurchasesTab() {
    return _buildDesktopPurchasesTab(); // Reuse desktop for now
  }

  Widget _buildTabletIncrementsTab() {
    return _buildDesktopIncrementsTab(); // Reuse desktop for now
  }

  // =====================================================
  // DESKTOP-SPECIFIC TAB METHODS
  // =====================================================

  Widget _buildDesktopInventoryTab() {
    if (_loading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return Column(
      children: [
        // Desktop Search and Filters Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Search and Filter Row
              Row(
                children: [
                  // Search Bar
                  Expanded(
                    flex: 2,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: t(context,'Search products...'),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceVariant,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Quick Actions
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showAddProductsDialog,
                        icon: const Icon(Icons.add),
                        label: Text(t(context,'Add Products')),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _showTransferDialog,
                        icon: const Icon(Icons.swap_horiz),
                        label: Text(t(context,'Transfer')),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Quick Stats
              _buildDesktopQuickStats(),
            ],
          ),
        ),
        
        // Desktop Inventory Grid - Responsive and Scrollable
        Expanded(
          child: _buildDesktopInventoryGrid(),
        ),
      ],
    );
  }

  Widget _buildDesktopQuickStats() {
    // Use the same data source as mobile for consistency
    final currentStock = _reports['current_stock']?['summary'] ?? {};

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Products',
            (currentStock['total_products'] ?? 0).toString(),
            Icons.inventory_2,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Total Units',
            (currentStock['total_units'] ?? 0).toString(),
            Icons.shopping_cart,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Low Stock',
            (currentStock['low_stock'] ?? 0).toString(),
            Icons.warning,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Out of Stock',
            (currentStock['out_of_stock'] ?? 0).toString(),
            Icons.error,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopInventoryGrid() {
    // Check loading state first - show loading if data is being fetched
    if (_loading) {
      return _buildLoadingState();
    }
    
    final filteredInventory = _inventory.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          item['product_name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item['sku'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (item['category_name'] ?? item['category'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesStockStatus = _selectedStockStatus.isEmpty ||
          (item['stock_status'] ?? '').toString() == _selectedStockStatus;
      
      final matchesCategory = _selectedCategory.isEmpty ||
          (item['category_name'] ?? item['category'] ?? '').toString() == _selectedCategory;
      
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
      final matchesMinPrice = _minPrice == null || price >= _minPrice!;
      final matchesMaxPrice = _maxPrice == null || price <= _maxPrice!;
      
      return matchesSearch && matchesStockStatus && matchesCategory && matchesMinPrice && matchesMaxPrice;
    }).toList();

    if (filteredInventory.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inventory_2_outlined,
        title: t(context, 'No inventory found'),
        subtitle: t(context, 'Add products to this store to get started'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate responsive grid columns based on screen width
          int crossAxisCount;
          double childAspectRatio;
          
          if (constraints.maxWidth > 1600) {
            crossAxisCount = 5;
            childAspectRatio = 1.2;
          } else if (constraints.maxWidth > 1200) {
            crossAxisCount = 4;
            childAspectRatio = 1.1;
          } else if (constraints.maxWidth > 900) {
            crossAxisCount = 3;
            childAspectRatio = 1.0;
          } else if (constraints.maxWidth > 600) {
            crossAxisCount = 2;
            childAspectRatio = 0.9;
          } else {
            crossAxisCount = 1;
            childAspectRatio = 0.8;
          }

          return GridView.builder(
            controller: _inventoryScrollController,
            padding: const EdgeInsets.all(20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: filteredInventory.length,
            itemBuilder: (context, index) {
              final item = filteredInventory[index];
              return _buildDesktopInventoryCard(item);
            },
          );
        },
      ),
    );
  }

  Widget _buildDesktopInventoryCard(Map<String, dynamic> item) {
    final stockStatus = item['stock_status'] as String?;
    Color statusColor;
    IconData statusIcon;
    
    switch (stockStatus) {
      case 'LOW_STOCK':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      case 'OUT_OF_STOCK':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _showEditCostPriceDialog(item),
        borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with image and status
            Row(
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item['image_url'] != null
                      ? Image.network(
                          item['image_url'],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image, color: Colors.grey),
                            );
                          },
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['product_name'] ?? 'Unknown Product',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${item['sku'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: ThemeAwareColors.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 10),
                      const SizedBox(width: 2),
                      Text(
                        stockStatus == 'LOW_STOCK' ? 'Low Stock' :
                        stockStatus == 'OUT_OF_STOCK' ? 'Out of Stock' : 'In Stock',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Stock Information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current Stock',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${_safeToInt(item['store_quantity'] ?? item['quantity'])}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Min Level',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${_safeToInt(item['min_stock_level'])}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Price Information
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selling Price',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '₦${(double.tryParse(item['price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Cost Price',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '₦${(double.tryParse(item['cost_price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showIncrementDialog(item),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add Stock', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditCostPriceDialog(item),
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Edit Cost', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildDesktopMovementsTab() {
    return _buildMovementsTab(); // Use existing method
  }

  Widget _buildDesktopReportsTab() {
    return _buildMobileReportsTab(); // Use unified implementation
  }

  Widget _buildUnifiedReportsContent() {
    final currentStock = _reports['current_stock']?['summary'] ?? {};
    final financialSummary = _reports['financial_summary'] ?? {};
    final movementSummary = _reports['movement_summary'] ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Key Metrics Cards
        _buildKeyMetricsGrid(currentStock, financialSummary, movementSummary),
        
        const SizedBox(height: 24),
        
        // Current Stock Summary
        if (_reports['current_stock'] != null) ...[
          _buildCurrentStockSection(),
          const SizedBox(height: 24),
        ],
        
        // Recent Movements
        if (_reports['recent_movements'] != null) ...[
          _buildRecentMovementsSection(),
          const SizedBox(height: 24),
        ],
        
        // Financial Overview
        if (financialSummary.isNotEmpty) ...[
          _buildFinancialOverviewSection(financialSummary),
        ],
      ],
    );
  }

  Widget _buildResponsiveUnifiedReportsContent(bool isSmallMobile) {
    final currentStock = _reports['current_stock']?['summary'] ?? {};
    final financialSummary = _reports['financial_summary'] ?? {};
    final movementSummary = _reports['movement_summary'] ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Responsive Key Metrics Cards
        _buildResponsiveKeyMetricsGrid(currentStock, financialSummary, movementSummary, isSmallMobile),
        
        SizedBox(height: isSmallMobile ? 16 : 24),
        
        // Current Stock Summary
        if (_reports['current_stock'] != null) ...[
          _buildCurrentStockSection(),
          SizedBox(height: isSmallMobile ? 16 : 24),
        ],
        
        // Recent Movements
        if (_reports['recent_movements'] != null) ...[
          _buildRecentMovementsSection(),
          SizedBox(height: isSmallMobile ? 16 : 24),
        ],
        
        // Financial Overview
        if (financialSummary.isNotEmpty) ...[
          _buildFinancialOverviewSection(financialSummary),
        ],
      ],
    );
  }

  Widget _buildKeyMetricsGrid(Map<String, dynamic> currentStock, Map<String, dynamic> financialSummary, Map<String, dynamic> movementSummary) {
    return GridView.count(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(), // Enable scrolling
      crossAxisCount: 1, // Single column for horizontal cards
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 3.5, // Wide aspect ratio for horizontal cards
      children: [
        _buildHorizontalMetricCard(
          'Total Products',
          _safeToInt(currentStock['total_products']).toString(),
          Icons.inventory_2,
          Colors.blue,
        ),
        _buildHorizontalMetricCard(
          'Total Units',
          _safeToInt(currentStock['total_units']).toString(),
          Icons.shopping_cart,
          Colors.green,
        ),
        _buildHorizontalMetricCard(
          'Low Stock',
          _safeToInt(currentStock['low_stock']).toString(),
          Icons.warning,
          Colors.orange,
        ),
        _buildHorizontalMetricCard(
          'Out of Stock',
          _safeToInt(currentStock['out_of_stock']).toString(),
          Icons.error,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildResponsiveKeyMetricsGrid(Map<String, dynamic> currentStock, Map<String, dynamic> financialSummary, Map<String, dynamic> movementSummary, bool isSmallMobile) {
    return GridView.count(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(), // Enable scrolling
      crossAxisCount: 1, // Always single column for horizontal cards on mobile
      crossAxisSpacing: isSmallMobile ? 12 : 16,
      mainAxisSpacing: isSmallMobile ? 12 : 16,
      childAspectRatio: isSmallMobile ? 3.0 : 3.5, // Wide aspect ratio for horizontal cards
      children: [
        _buildHorizontalMetricCard(
          'Total Products',
          _safeToInt(currentStock['total_products']).toString(),
          Icons.inventory_2,
          Colors.blue,
        ),
        _buildHorizontalMetricCard(
          'Total Units',
          _safeToInt(currentStock['total_units']).toString(),
          Icons.shopping_cart,
          Colors.green,
        ),
        _buildHorizontalMetricCard(
          'Low Stock',
          _safeToInt(currentStock['low_stock']).toString(),
          Icons.warning,
          Colors.orange,
        ),
        _buildHorizontalMetricCard(
          'Out of Stock',
          _safeToInt(currentStock['out_of_stock']).toString(),
          Icons.error,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildSimpleMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: ThemeAwareColors.getSecondaryTextColor(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          // Content section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ThemeAwareColors.getSecondaryTextColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStockSection() {
    final products = _reports['current_stock']?['products'] as List<dynamic>? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current Stock',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (products.isEmpty)
          _buildEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No Stock Data',
            subtitle: 'Stock information will appear here',
          )
        else
          ...products.take(5).map((product) => _buildStockItemCard(product)),
      ],
    );
  }

  Widget _buildStockItemCard(Map<String, dynamic> product) {
    final stockStatus = product['stock_status'] as String?;
    Color statusColor;
    switch (stockStatus) {
      case 'LOW_STOCK':
        statusColor = Colors.orange;
        break;
      case 'OUT_OF_STOCK':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(Icons.inventory_2, color: statusColor),
        ),
        title: Text(product['product_name'] ?? 'Unknown Product'),
        subtitle: Text('SKU: ${product['sku'] ?? 'N/A'}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${_safeToInt(product['current_quantity'])} units',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            Text(
              'Min: ${_safeToInt(product['min_stock_level'])}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentMovementsSection() {
    final movements = _reports['recent_movements'] as List<dynamic>? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Movements',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (movements.isEmpty)
          _buildEmptyState(
            icon: Icons.trending_up_outlined,
            title: 'No Recent Movements',
            subtitle: 'Movement history will appear here',
          )
        else
          ...movements.take(5).map((movement) => _buildMovementItemCard(movement)),
      ],
    );
  }

  Widget _buildMovementItemCard(Map<String, dynamic> movement) {
    final movementType = movement['movement_type'] as String?;
    final quantity = _safeToInt(movement['quantity']);
    
    Color typeColor;
    IconData typeIcon;
    String typeLabel;
    
    switch (movementType) {
      case 'in':
        typeColor = Colors.green;
        typeIcon = Icons.add_circle;
        typeLabel = 'Stock In';
        break;
      case 'out':
        typeColor = Colors.red;
        typeIcon = Icons.remove_circle;
        typeLabel = 'Stock Out';
        break;
      case 'transfer_out':
        typeColor = Colors.blue;
        typeIcon = Icons.swap_horiz;
        typeLabel = 'Transfer Out';
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.help;
        typeLabel = 'Unknown';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: typeColor.withOpacity(0.1),
          child: Icon(typeIcon, color: typeColor),
        ),
        title: Text(movement['product_name'] ?? 'Unknown Product'),
        subtitle: Text(typeLabel),
        trailing: Text(
          '${quantity > 0 ? '+' : ''}$quantity',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: typeColor,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialOverviewSection(Map<String, dynamic> financialSummary) {
    final totalCost = _safeToDouble(financialSummary['total_cost_value']);
    final totalSelling = _safeToDouble(financialSummary['total_selling_value']);
    final profit = totalSelling - totalCost;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Financial Overview',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildFinancialCard(
                'Total Cost',
                '₦${totalCost.toStringAsFixed(0)}',
                Icons.money_off,
                Colors.red,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildFinancialCard(
                'Total Value',
                '₦${totalSelling.toStringAsFixed(0)}',
                Icons.attach_money,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildFinancialCard(
          'Potential Profit',
          '₦${profit.toStringAsFixed(0)}',
          Icons.trending_up,
          profit >= 0 ? Colors.green : Colors.red,
        ),
      ],
    );
  }

  Widget _buildFinancialCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDetailedMovementsTab() {
    return _buildDetailedMovementsTab(); // Use existing method
  }

  Widget _buildDesktopPurchasesTab() {
    return _buildPurchasesTab(); // Use existing method
  }

  Widget _buildDesktopIncrementsTab() {
    return _buildIncrementsTab(); // Use existing method
  }

  Widget _buildDesktopTransferReportsTab() {
    return _buildTransferReportsTab(); // Use existing method
  }

  Widget _buildTabletTransferReportsTab() {
    return _buildDesktopTransferReportsTab(); // Reuse desktop for now
  }

  Widget _buildMobileTransferReportsTab() {
    return _buildTransferReportsTab(); // Use existing method
  }

  Widget _buildTransferReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with filters
          Row(
            children: [
              Expanded(
                child: Text(
                  'Transfer Reports',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadTransferReports,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Data',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Filters Row
          _buildTransferReportsFilters(),
          const SizedBox(height: 16),
          
          // Data Display
          _transferReportsLoading
              ? const Center(child: CircularProgressIndicator())
              : (_transferReportsData['transfers'] as List?)?.isEmpty ?? true
                  ? _buildEmptyTransferReports()
                  : _buildTransferReportsTable(),
        ],
      ),
    );
  }

  Widget _buildTransferReportsFilters() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            isSmallScreen ? _buildMobileTransferReportsFilters() : _buildDesktopTransferReportsFilters(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTransferReportsFilters() {
    return Column(
      children: [
        // Time Period
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Time Period:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _transferReportsTimePeriod,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Time')),
                DropdownMenuItem(value: 'today', child: Text('Today')),
                DropdownMenuItem(value: 'week', child: Text('This Week')),
                DropdownMenuItem(value: 'month', child: Text('This Month')),
                DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
              ],
              onChanged: (value) {
                setState(() {
                  _transferReportsTimePeriod = value ?? 'all';
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Custom Date Range (if selected)
        if (_transferReportsTimePeriod == 'custom') ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Date Range:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showTransferReportsStartDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _transferReportsStartDate != null
                              ? '${_transferReportsStartDate!.day}/${_transferReportsStartDate!.month}/${_transferReportsStartDate!.year}'
                              : 'Start Date',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showTransferReportsEndDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _transferReportsEndDate != null
                              ? '${_transferReportsEndDate!.day}/${_transferReportsEndDate!.month}/${_transferReportsEndDate!.year}'
                              : 'End Date',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        // Apply Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loadTransferReports,
            child: const Text('Apply Filters'),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTransferReportsFilters() {
    return Row(
      children: [
        // Time Period
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Time Period:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _transferReportsTimePeriod,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Time')),
                  DropdownMenuItem(value: 'today', child: Text('Today')),
                  DropdownMenuItem(value: 'week', child: Text('This Week')),
                  DropdownMenuItem(value: 'month', child: Text('This Month')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
                ],
                onChanged: (value) {
                  setState(() {
                    _transferReportsTimePeriod = value ?? 'all';
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        
        // Custom Date Range (if selected)
        if (_transferReportsTimePeriod == 'custom') ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Start Date:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _showTransferReportsStartDatePicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _transferReportsStartDate != null
                          ? '${_transferReportsStartDate!.day}/${_transferReportsStartDate!.month}/${_transferReportsStartDate!.year}'
                          : 'Select Start Date',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('End Date:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _showTransferReportsEndDatePicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _transferReportsEndDate != null
                          ? '${_transferReportsEndDate!.day}/${_transferReportsEndDate!.month}/${_transferReportsEndDate!.year}'
                          : 'Select End Date',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
        
        // Apply Button
        ElevatedButton(
          onPressed: _loadTransferReports,
          child: const Text('Apply Filters'),
        ),
      ],
    );
  }

  Widget _buildEmptyTransferReports() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swap_horiz, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No transfer reports found',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or check if there are any transfers',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadTransferReports,
            child: const Text('Load Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferReportsTable() {
    final transfers = _transferReportsData['transfers'] as List<dynamic>? ?? [];
    final summary = _transferReportsData['summary'] as Map<String, dynamic>? ?? {};
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;

    return Column(
      children: [
        // Summary Cards
        if (summary.isNotEmpty) _buildTransferReportsSummary(summary),
        const SizedBox(height: 16),
        
        // Data Table
        Card(
          child: isSmallScreen 
              ? _buildMobileTransferReportsList(transfers)
              : _buildDesktopTransferReportsTable(transfers),
        ),
      ],
    );
  }

  Widget _buildDesktopTransferReportsTable(List<dynamic> transfers) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('To Business', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        
        // Table Body
        ListView.builder(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(), // Enable scrolling
          itemCount: transfers.length,
          itemBuilder: (context, index) {
            final transfer = transfers[index] as Map<String, dynamic>;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transfer['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'SKU: ${transfer['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${transfer['quantity'] ?? 0}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      transfer['target_business_name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      transfer['transfer_date'] != null
                          ? DateTime.parse(transfer['transfer_date']).toString().split(' ')[0]
                          : 'N/A',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Completed',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileTransferReportsList(List<dynamic> transfers) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(), // Enable scrolling
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final transfer = transfers[index] as Map<String, dynamic>;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        transfer['product_name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Completed',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('SKU: ${transfer['sku'] ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text('Quantity: ${transfer['quantity'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('To: ${transfer['target_business_name'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  'Date: ${transfer['transfer_date'] != null ? DateTime.parse(transfer['transfer_date']).toString().split(' ')[0] : 'N/A'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransferReportsSummary(Map<String, dynamic> summary) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    if (isSmallScreen) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.swap_horiz, color: Colors.blue[600]),
                        const SizedBox(height: 8),
                        Text(
                          '${summary['total_transfers'] ?? 0}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Transfers'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.inventory, color: Colors.green[600]),
                        const SizedBox(height: 8),
                        Text(
                          '${summary['total_quantity_transferred'] ?? 0}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const Text('Items Transferred'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.business, color: Colors.orange[600]),
                        const SizedBox(height: 8),
                        Text(
                          '${summary['unique_businesses'] ?? 0}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const Text('Businesses Served'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.category, color: Colors.purple[600]),
                        const SizedBox(height: 8),
                        Text(
                          '${summary['unique_products'] ?? 0}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const Text('Products Transferred'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.swap_horiz, color: Colors.blue[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_transfers'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Total Transfers'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.inventory, color: Colors.green[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_quantity_transferred'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Items Transferred'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.business, color: Colors.orange[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['unique_businesses'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Businesses Served'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.category, color: Colors.purple[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['unique_products'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Products Transferred'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showTransferReportsStartDatePicker(BuildContext context) {
    showDatePicker(
      context: context,
      initialDate: _transferReportsStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    ).then((date) {
      if (date != null) {
        setState(() {
          _transferReportsStartDate = date;
        });
      }
    });
  }

  void _showTransferReportsEndDatePicker(BuildContext context) {
    showDatePicker(
      context: context,
      initialDate: _transferReportsEndDate ?? DateTime.now(),
      firstDate: _transferReportsStartDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    ).then((date) {
      if (date != null) {
        setState(() {
          _transferReportsEndDate = date;
        });
      }
    });
  }

  // =====================================================
  // DETAILED MOVEMENTS HELPER METHODS
  // =====================================================

  Widget _buildMobileFilterSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title:',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildTabletFilterSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title:',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildResponsiveDetailedMovementsFilters() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    final isMediumScreen = screenSize.width >= 768 && screenSize.width < 1024;
    
    if (isSmallScreen) {
      // Mobile layout - Stack all filters vertically (no separate scrolling)
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
        children: [
              // Collapsible Filter Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                    Text(
                      'Filters (Scrollable)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.swipe_up,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.filter_list,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Time Period Filter
              _buildMobileFilterSection(
                'Time Period',
              DropdownButtonFormField<String>(
                value: _detailedMovementsTimeFilter,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                ),
                items: const [
                  DropdownMenuItem(value: 'today', child: Text('Today')),
                  DropdownMenuItem(value: 'this_week', child: Text('This Week')),
                  DropdownMenuItem(value: 'this_month', child: Text('This Month')),
                  DropdownMenuItem(value: 'all_time', child: Text('All Time')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _applyDetailedMovementsTimePreset(value);
                  }
                },
              ),
          ),
          
          // Custom Date Range (only show if custom is selected)
          if (_detailedMovementsTimeFilter == 'custom') ...[
                _buildMobileFilterSection(
                  'Custom Date Range',
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _showDetailedMovementsStartDatePicker(context),
                        child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                              color: Theme.of(context).colorScheme.surface,
                          ),
                          child: Text(
                            _detailedMovementsStartDate != null
                                ? '${_detailedMovementsStartDate!.day}/${_detailedMovementsStartDate!.month}/${_detailedMovementsStartDate!.year}'
                                : 'Start Date',
                            style: TextStyle(
                                color: _detailedMovementsStartDate != null 
                                    ? Theme.of(context).colorScheme.onSurface 
                                    : Colors.grey.shade600,
                                fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                      Text(
                        'to',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _showDetailedMovementsEndDatePicker(context),
                        child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                              color: Theme.of(context).colorScheme.surface,
                          ),
                          child: Text(
                            _detailedMovementsEndDate != null
                                ? '${_detailedMovementsEndDate!.day}/${_detailedMovementsEndDate!.month}/${_detailedMovementsEndDate!.year}'
                                : 'End Date',
                            style: TextStyle(
                                color: _detailedMovementsEndDate != null 
                                    ? Theme.of(context).colorScheme.onSurface 
                                    : Colors.grey.shade600,
                                fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ),
          ],
          
          // Category Filter
              _buildMobileFilterSection(
                'Category',
              DropdownButtonFormField<String>(
                value: _selectedCategoryForDetailed,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  hintText: 'All Categories',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Categories')),
                  ..._categories.map((category) => 
                    DropdownMenuItem(value: category['id']?.toString(), child: Text(category['name'] ?? 'Unknown'))
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryForDetailed = value;
                  });
                  _loadDetailedMovements();
                },
              ),
          ),
          
          // Product Filter
              _buildMobileFilterSection(
                'Product',
              DropdownButtonFormField<int?>(
                value: _selectedProductForDetailed,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  hintText: 'All Products',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Products')),
                  ..._inventory.map((item) => DropdownMenuItem(
                    value: item['product_id'],
                    child: Text(item['product_name'] ?? 'Unknown'),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedProductForDetailed = value;
                  });
                  _loadDetailedMovements();
                },
              ),
          ),
          
          // Business Filter
              _buildMobileFilterSection(
                'Business',
              DropdownButtonFormField<int?>(
                value: _selectedBusinessForDetailed,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  hintText: 'All Businesses',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Businesses')),
                  ..._businesses.map((business) => DropdownMenuItem(
                    value: business['id'],
                    child: Text(business['name'] ?? 'Unknown'),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedBusinessForDetailed = value;
                  });
                  _loadDetailedMovements();
                },
              ),
          ),
          
          // Movement Type Filter
              _buildMobileFilterSection(
                'Movement Type',
              DropdownButtonFormField<String>(
                value: _selectedMovementTypeForDetailed,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  hintText: 'All Types',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Types')),
                  DropdownMenuItem(value: 'in', child: Text('Stock In')),
                  DropdownMenuItem(value: 'out', child: Text('Stock Out')),
                  DropdownMenuItem(value: 'transfer_out', child: Text('Transfer Out')),
                  DropdownMenuItem(value: 'adjustment', child: Text('Adjustment')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedMovementTypeForDetailed = value;
                  });
                  _loadDetailedMovements();
                },
                ),
              ),
              
              // Mobile Action Buttons
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearDetailedMovementsFilters,
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Clear'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _detailedMovementsPage = 1;
                        _loadDetailedMovements();
                      },
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Apply'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
              ),
            ],
          ),
        ],
          ),
        ),
      );
    } else if (isMediumScreen) {
      // Tablet layout - 2 columns (no separate scrolling)
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
        children: [
              // Filter Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filters',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.filter_list,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
          // First Row - Date and Category
          Row(
            children: [
              Expanded(
                    child: _buildTabletFilterSection(
                      'Time Period',
                    DropdownButtonFormField<String>(
                      value: _detailedMovementsTimeFilter,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'today', child: Text('Today')),
                        DropdownMenuItem(value: 'this_week', child: Text('This Week')),
                        DropdownMenuItem(value: 'this_month', child: Text('This Month')),
                        DropdownMenuItem(value: 'all_time', child: Text('All Time')),
                        DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _applyDetailedMovementsTimePreset(value);
                        }
                      },
                    ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                    child: _buildTabletFilterSection(
                      'Category',
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryForDetailed,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        hintText: 'All Categories',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Categories')),
                        ..._categories.map((category) => 
                          DropdownMenuItem(value: category['id']?.toString(), child: Text(category['name'] ?? 'Unknown'))
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryForDetailed = value;
                        });
                        _loadDetailedMovements();
                      },
                    ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Second Row - Product and Business
          Row(
            children: [
              Expanded(
                    child: _buildTabletFilterSection(
                      'Product',
                    DropdownButtonFormField<int?>(
                      value: _selectedProductForDetailed,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        hintText: 'All Products',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Products')),
                        ..._inventory.map((item) => DropdownMenuItem(
                          value: item['product_id'],
                          child: Text(item['product_name'] ?? 'Unknown'),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedProductForDetailed = value;
                        });
                        _loadDetailedMovements();
                      },
                    ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                    child: _buildTabletFilterSection(
                      'Business',
                    DropdownButtonFormField<int?>(
                      value: _selectedBusinessForDetailed,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        hintText: 'All Businesses',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Businesses')),
                        ..._businesses.map((business) => DropdownMenuItem(
                          value: business['id'],
                          child: Text(business['name'] ?? 'Unknown'),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedBusinessForDetailed = value;
                        });
                        _loadDetailedMovements();
                      },
                    ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Third Row - Movement Type and Custom Date Range
          Row(
            children: [
              Expanded(
                    child: _buildTabletFilterSection(
                      'Movement Type',
                    DropdownButtonFormField<String>(
                      value: _selectedMovementTypeForDetailed,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        hintText: 'All Types',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Types')),
                        DropdownMenuItem(value: 'in', child: Text('Stock In')),
                        DropdownMenuItem(value: 'out', child: Text('Stock Out')),
                        DropdownMenuItem(value: 'transfer_out', child: Text('Transfer Out')),
                        DropdownMenuItem(value: 'adjustment', child: Text('Adjustment')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedMovementTypeForDetailed = value;
                        });
                        _loadDetailedMovements();
                      },
                    ),
                ),
              ),
              const SizedBox(width: 16),
              if (_detailedMovementsTimeFilter == 'custom')
                Expanded(
                      child: _buildTabletFilterSection(
                        'Custom Date Range',
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _showDetailedMovementsStartDatePicker(context),
                              child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(8),
                                    color: Theme.of(context).colorScheme.surface,
                                ),
                                child: Text(
                                  _detailedMovementsStartDate != null
                                      ? '${_detailedMovementsStartDate!.day}/${_detailedMovementsStartDate!.month}/${_detailedMovementsStartDate!.year}'
                                      : 'Start Date',
                                  style: TextStyle(
                                      color: _detailedMovementsStartDate != null 
                                          ? Theme.of(context).colorScheme.onSurface 
                                          : Colors.grey.shade600,
                                      fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                            Text(
                              'to',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => _showDetailedMovementsEndDatePicker(context),
                              child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(8),
                                    color: Theme.of(context).colorScheme.surface,
                                ),
                                child: Text(
                                  _detailedMovementsEndDate != null
                                      ? '${_detailedMovementsEndDate!.day}/${_detailedMovementsEndDate!.month}/${_detailedMovementsEndDate!.year}'
                                      : 'End Date',
                                  style: TextStyle(
                                      color: _detailedMovementsEndDate != null 
                                          ? Theme.of(context).colorScheme.onSurface 
                                          : Colors.grey.shade600,
                                      fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        ),
                      ),
                    ),
                ],
              ),
              
              // Tablet Action Buttons
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearDetailedMovementsFilters,
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Clear Filters'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _detailedMovementsPage = 1;
                        _loadDetailedMovements();
                      },
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Apply Filters'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ),
                ),
            ],
          ),
        ],
          ),
        ),
      );
    } else {
      // Desktop layout - No separate scrolling (part of main scroll)
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _buildEnhancedDetailedMovementsFilters(),
        ),
      );
    }
  }

  Widget _buildEnhancedDetailedMovementsFilters() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    return Column(
      children: [
        // First Row - Date Filters
        Row(
          children: [
            // Time Period Filter
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Time Period:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _detailedMovementsTimeFilter,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'today', child: Text('Today')),
                      DropdownMenuItem(value: 'this_week', child: Text('This Week')),
                      DropdownMenuItem(value: 'this_month', child: Text('This Month')),
                      DropdownMenuItem(value: 'all_time', child: Text('All Time')),
                      DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _applyDetailedMovementsTimePreset(value);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // Custom Date Range (only show if custom is selected)
            if (_detailedMovementsTimeFilter == 'custom') ...[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Custom Date Range:', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _showDetailedMovementsStartDatePicker(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _detailedMovementsStartDate != null
                                    ? '${_detailedMovementsStartDate!.day}/${_detailedMovementsStartDate!.month}/${_detailedMovementsStartDate!.year}'
                                    : 'Start Date',
                                style: TextStyle(
                                  color: _detailedMovementsStartDate != null ? Colors.black : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('to'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _showDetailedMovementsEndDatePicker(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _detailedMovementsEndDate != null
                                    ? '${_detailedMovementsEndDate!.day}/${_detailedMovementsEndDate!.month}/${_detailedMovementsEndDate!.year}'
                                    : 'End Date',
                                style: TextStyle(
                                  color: _detailedMovementsEndDate != null ? Colors.black : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        
        // Second Row - Category, Product, Business, Movement Type Filters
        Row(
          children: [
            // Category Filter
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryForDetailed,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      hintText: 'All Categories',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Categories')),
                      ..._categories.map((category) => 
                        DropdownMenuItem(value: category['id']?.toString(), child: Text(category['name'] ?? 'Unknown'))
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryForDetailed = value;
                      });
                      _loadDetailedMovements();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // Product Filter
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Product:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    value: _selectedProductForDetailed,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      hintText: 'All Products',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Products')),
                      ..._inventory.map((item) => DropdownMenuItem(
                        value: item['product_id'],
                        child: Text(item['product_name'] ?? 'Unknown'),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedProductForDetailed = value;
                      });
                      _loadDetailedMovements();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // Business Filter
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Business:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    value: _selectedBusinessForDetailed,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      hintText: 'All Businesses',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Businesses')),
                      ..._businesses.map((business) => DropdownMenuItem(
                        value: business['id'],
                        child: Text(business['name'] ?? 'Unknown'),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedBusinessForDetailed = value;
                      });
                      _loadDetailedMovements();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // Movement Type Filter
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Movement Type:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedMovementTypeForDetailed,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      hintText: 'All Types',
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Types')),
                      DropdownMenuItem(value: 'in', child: Text('Stock In')),
                      DropdownMenuItem(value: 'out', child: Text('Stock Out')),
                      DropdownMenuItem(value: 'transfer_out', child: Text('Transfer Out')),
                      DropdownMenuItem(value: 'adjustment', child: Text('Adjustment')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedMovementTypeForDetailed = value;
                      });
                      _loadDetailedMovements();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailedMovementsFilters() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            isSmallScreen ? _buildMobileFilters() : _buildDesktopFilters(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFilters() {
    return Column(
      children: [
        // Time Filter
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Time Period:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _detailedMovementsTimeFilter,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: _detailedMovementsTimeFilterOptions.map((option) {
                return DropdownMenuItem(value: option, child: Text(option));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _applyDetailedMovementsTimePreset(value);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Custom Date Range (only show if Custom Range is selected)
        if (_detailedMovementsTimeFilter == 'Custom Range') ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Custom Date Range:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showDetailedMovementsStartDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _detailedMovementsStartDate != null
                              ? '${_detailedMovementsStartDate!.day}/${_detailedMovementsStartDate!.month}/${_detailedMovementsStartDate!.year}'
                              : 'Start Date',
                          style: TextStyle(
                            color: _detailedMovementsStartDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('to'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showDetailedMovementsEndDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _detailedMovementsEndDate != null
                              ? '${_detailedMovementsEndDate!.day}/${_detailedMovementsEndDate!.month}/${_detailedMovementsEndDate!.year}'
                              : 'End Date',
                          style: TextStyle(
                            color: _detailedMovementsEndDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        // Category Filter
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Category:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _selectedCategoryForDetailed,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Categories')),
                ..._categories.map((category) => 
                  DropdownMenuItem(value: category['id']?.toString(), child: Text(category['name'] ?? 'Unknown'))
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategoryForDetailed = value;
                });
                _loadDetailedMovements();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Product Filter
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Product:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              value: _selectedProductForDetailed,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Products')),
                ..._productsForDetailed.map((product) {
                  return DropdownMenuItem<int?>(
                    value: product['id'] as int?,
                    child: Text(product['name'] ?? 'Unknown Product'),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedProductForDetailed = value;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Movement Type Filter
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Movement Type:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedDetailedMovementType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Types')),
                const DropdownMenuItem(value: 'in', child: Text('Stock In')),
                const DropdownMenuItem(value: 'transfer_out', child: Text('Transfer Out')),
                const DropdownMenuItem(value: 'adjustment', child: Text('Adjustment')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedDetailedMovementType = value;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Apply Filters Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              _detailedMovementsPage = 1;
              _loadDetailedMovements();
            },
            child: const Text('Apply Filters'),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopFilters() {
    return Row(
      children: [
        // Date Range
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Date Range:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showDetailedMovementsStartDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _detailedMovementsStartDate != null
                              ? '${_detailedMovementsStartDate!.day}/${_detailedMovementsStartDate!.month}/${_detailedMovementsStartDate!.year}'
                              : 'Start Date',
                          style: TextStyle(
                            color: _detailedMovementsStartDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('to'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showDetailedMovementsEndDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _detailedMovementsEndDate != null
                              ? '${_detailedMovementsEndDate!.day}/${_detailedMovementsEndDate!.month}/${_detailedMovementsEndDate!.year}'
                              : 'End Date',
                          style: TextStyle(
                            color: _detailedMovementsEndDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Movement Type Filter
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Movement Type:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _selectedDetailedMovementType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Types')),
                  const DropdownMenuItem(value: 'in', child: Text('Stock In')),
                  const DropdownMenuItem(value: 'transfer_out', child: Text('Transfer Out')),
                  const DropdownMenuItem(value: 'adjustment', child: Text('Adjustment')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedDetailedMovementType = value;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Apply Filters Button
        ElevatedButton(
          onPressed: () {
            _detailedMovementsPage = 1;
            _loadDetailedMovements();
          },
          child: const Text('Apply Filters'),
        ),
      ],
    );
  }

  Widget _buildEmptyDetailedMovements() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No detailed movements found',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or add some inventory movements',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDetailedMovements,
            child: const Text('Load Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveDetailedMovementsTable() {
    final movements = _detailedMovementsData['movements'] as List<dynamic>? ?? [];
    final summary = _detailedMovementsData['summary'] as Map<String, dynamic>? ?? {};
    final pagination = _detailedMovementsData['report_metadata']?['pagination'] as Map<String, dynamic>? ?? {};

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isSmallScreen = screenWidth < 768;
        final isMediumScreen = screenWidth >= 768 && screenWidth < 1024;
        final isLargeScreen = screenWidth >= 1024;

     return Column(
        children: [
          // Summary Cards - Responsive
          if (summary.isNotEmpty) _buildResponsiveDetailedMovementsSummary(summary),
         if (summary.isNotEmpty) SizedBox(height: isSmallScreen ? 12 : 16),
          
          // Data Table - Responsive
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
            ),
            child: isSmallScreen 
                ? _buildMobileMovementsList(movements)
                : isMediumScreen
                    ? _buildTabletMovementsTable(movements)
                    : _buildDesktopMovementsTable(movements),
          ),
          
          // Pagination - Responsive
          if (pagination.isNotEmpty) ...[
                SizedBox(height: isSmallScreen ? 12 : 16),
            _buildResponsivePagination(pagination),
          ],
        ],
     );
      },
    );
  }

  Widget _buildDetailedMovementsTable() {
    final movements = _detailedMovementsData['movements'] as List<dynamic>? ?? [];
    final summary = _detailedMovementsData['summary'] as Map<String, dynamic>? ?? {};
    final pagination = _detailedMovementsData['report_metadata']?['pagination'] as Map<String, dynamic>? ?? {};
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;

    return Column(
      children: [
        // Summary Cards
        if (summary.isNotEmpty) _buildDetailedMovementsSummary(summary),
        const SizedBox(height: 16),
        
        // Data Table
        Card(
          child: isSmallScreen 
              ? _buildMobileMovementsList(movements)
              : _buildDesktopMovementsTable(movements),
        ),
      ],
    );
  }

  Widget _buildResponsiveDetailedMovementsSummary(Map<String, dynamic> summary) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    final isMediumScreen = screenSize.width >= 768 && screenSize.width < 1024;
    
    if (isSmallScreen) {
      // Mobile - 2x2 grid
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.inventory, color: Colors.blue[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_movements'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Movements', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.trending_up, color: Colors.green[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_quantity'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Quantity', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.business, color: Colors.orange[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['unique_businesses'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Businesses', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2, color: Colors.purple[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['unique_products'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Products', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (isMediumScreen) {
      // Tablet - 2x2 grid with larger cards
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.inventory, color: Colors.blue[600], size: 24),
                        const SizedBox(height: 8),
                        Text(
                          '${summary['total_movements'] ?? 0}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Movements', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.trending_up, color: Colors.green[600], size: 24),
                        const SizedBox(height: 8),
                        Text(
                          '${summary['total_quantity'] ?? 0}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Quantity', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.business, color: Colors.orange[600], size: 24),
                        const SizedBox(height: 8),
                        Text(
                          '${summary['unique_businesses'] ?? 0}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Text('Businesses Served', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2, color: Colors.purple[600], size: 24),
                        const SizedBox(height: 8),
                        Text(
                          '${summary['unique_products'] ?? 0}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Text('Products Moved', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // Desktop - 4 columns
      return Row(
        children: [
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.inventory, color: Colors.blue[600], size: 24),
                    const SizedBox(height: 8),
                    Text(
                      '${summary['total_movements'] ?? 0}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Text('Total Movements'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.trending_up, color: Colors.green[600], size: 24),
                    const SizedBox(height: 8),
                    Text(
                      '${summary['total_quantity'] ?? 0}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Text('Total Quantity'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.business, color: Colors.orange[600], size: 24),
                    const SizedBox(height: 8),
                    Text(
                      '${summary['unique_businesses'] ?? 0}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Text('Businesses Served'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2, color: Colors.purple[600], size: 24),
                    const SizedBox(height: 8),
                    Text(
                      '${summary['unique_products'] ?? 0}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Text('Products Moved'),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildTabletMovementsTable(List<dynamic> movements) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Business', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        
        // Table Body
        ListView.builder(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(), // Enable scrolling
          itemCount: movements.length,
          itemBuilder: (context, index) {
            final movement = movements[index] as Map<String, dynamic>;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movement['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'SKU: ${movement['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Text(
                        movement['category_name'] ?? 'No Category',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getMovementTypeColor(movement['movement_type']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getMovementTypeLabel(movement['movement_type']),
                        style: TextStyle(
                          color: _getMovementTypeColor(movement['movement_type']),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${movement['quantity'] ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: movement['movement_type'] == 'transfer_out' 
                            ? Colors.blue[50] 
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(4),
                        border: movement['movement_type'] == 'transfer_out' 
                            ? Border.all(color: Colors.blue[200]!)
                            : null,
                      ),
                      child: Text(
                        movement['movement_type'] == 'transfer_out' 
                            ? (movement['business_name'] ?? 'Unknown Business')
                            : (movement['business_name'] ?? 'N/A'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: movement['movement_type'] == 'transfer_out' 
                              ? Colors.blue[700]
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatDate(movement['created_at']),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildResponsivePagination(Map<String, dynamic> pagination) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    
    if (isSmallScreen) {
      // Mobile pagination - simplified
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Page ${pagination['current_page'] ?? 1} of ${pagination['total_pages'] ?? 1}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          Row(
            children: [
              if ((pagination['current_page'] ?? 1) > 1)
                IconButton(
                  onPressed: () {
                    _detailedMovementsPage = (pagination['current_page'] ?? 1) - 1;
                    _loadDetailedMovements();
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
              if ((pagination['current_page'] ?? 1) < (pagination['total_pages'] ?? 1))
                IconButton(
                  onPressed: () {
                    _detailedMovementsPage = (pagination['current_page'] ?? 1) + 1;
                    _loadDetailedMovements();
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
            ],
          ),
        ],
      );
    } else {
      // Desktop pagination - full controls
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if ((pagination['current_page'] ?? 1) > 1)
            ElevatedButton(
              onPressed: () {
                _detailedMovementsPage = (pagination['current_page'] ?? 1) - 1;
                _loadDetailedMovements();
              },
              child: const Text('Previous'),
            ),
          const SizedBox(width: 16),
          Text(
            'Page ${pagination['current_page'] ?? 1} of ${pagination['total_pages'] ?? 1}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 16),
          if ((pagination['current_page'] ?? 1) < (pagination['total_pages'] ?? 1))
            ElevatedButton(
              onPressed: () {
                _detailedMovementsPage = (pagination['current_page'] ?? 1) + 1;
                _loadDetailedMovements();
              },
              child: const Text('Next'),
            ),
        ],
      );
    }
  }

  Widget _buildDesktopMovementsTable(List<dynamic> movements) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Business', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('User', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        
        // Table Body
        ListView.builder(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(), // Enable scrolling
          itemCount: movements.length,
          itemBuilder: (context, index) {
            final movement = movements[index] as Map<String, dynamic>;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movement['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'SKU: ${movement['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Text(
                        movement['category_name'] ?? 'No Category',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getMovementTypeColor(movement['movement_type']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getMovementTypeLabel(movement['movement_type']),
                        style: TextStyle(
                          color: _getMovementTypeColor(movement['movement_type']),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${movement['quantity'] ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: movement['movement_type'] == 'transfer_out' 
                            ? Colors.blue[50] 
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(4),
                        border: movement['movement_type'] == 'transfer_out' 
                            ? Border.all(color: Colors.blue[200]!)
                            : null,
                      ),
                      child: Text(
                        movement['movement_type'] == 'transfer_out' 
                            ? (movement['business_name'] ?? 'Unknown Business')
                            : (movement['business_name'] ?? 'N/A'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: movement['movement_type'] == 'transfer_out' 
                              ? Colors.blue[700]
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatDate(movement['created_at']),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      movement['created_by_name'] ?? 'Unknown',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileMovementsList(List<dynamic> movements) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(), // Enable scrolling
      itemCount: movements.length,
      itemBuilder: (context, index) {
        final movement = movements[index] as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movement['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        Text(
                          'SKU: ${movement['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getMovementTypeColor(movement['movement_type']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getMovementTypeLabel(movement['movement_type']),
                      style: TextStyle(
                        color: _getMovementTypeColor(movement['movement_type']),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Category Info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category, color: Colors.green[700], size: 14),
                    const SizedBox(width: 4),
                    Text(
                      movement['category_name'] ?? 'No Category',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Details Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quantity', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          '${movement['quantity'] ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          _formatDate(movement['created_at']),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Business Info (for transfers)
              if (movement['movement_type'] == 'transfer_out' && movement['business_name'] != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.business, color: Colors.blue[700], size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transferred to Business',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              movement['business_name'] ?? 'Unknown Business',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // User Info
              Text('User', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(
                movement['created_by_name'] ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailedMovementsSummary(Map<String, dynamic> summary) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    if (isSmallScreen) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.inventory, color: Colors.blue[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_movements'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Transfers', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.category, color: Colors.green[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['unique_products'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Products', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.arrow_downward, color: Colors.orange[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_stock_in'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Stock In', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.arrow_upward, color: Colors.red[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_transferred_out'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Transferred Out', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.inventory, color: Colors.blue[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_movements'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Total Transfers'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.category, color: Colors.green[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['unique_products'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Products'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.arrow_downward, color: Colors.orange[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_stock_in'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Stock In'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.arrow_upward, color: Colors.red[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_transferred_out'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Transferred Out'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getMovementTypeColor(String? type) {
    switch (type) {
      case 'in':
        return Colors.green;
      case 'transfer_out':
        return Colors.orange;
      case 'adjustment':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getMovementTypeLabel(String? type) {
    switch (type) {
      case 'in':
        return 'Stock In';
      case 'transfer_out':
        return 'Transfer Out';
      case 'adjustment':
        return 'Adjustment';
      default:
        return 'Unknown';
    }
  }

  Future<void> _showDetailedMovementsStartDatePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _detailedMovementsStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _detailedMovementsStartDate = date;
      });
    }
  }

  Future<void> _showDetailedMovementsEndDatePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _detailedMovementsEndDate ?? DateTime.now(),
      firstDate: _detailedMovementsStartDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _detailedMovementsEndDate = date;
      });
    }
  }

  Future<void> _showPurchasesStartDatePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _purchasesStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _purchasesStartDate = date;
        _purchasesTimeFilter = 'custom';
      });
      _loadPurchases();
    }
  }

  Future<void> _showPurchasesEndDatePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _purchasesEndDate ?? DateTime.now(),
      firstDate: _purchasesStartDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _purchasesEndDate = date;
        _purchasesTimeFilter = 'custom';
      });
      _loadPurchases();
    }
  }

  Future<void> _showIncrementsStartDatePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _incrementsStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _incrementsStartDate = date;
        _incrementsTimeFilter = 'custom';
      });
      _loadIncrements();
    }
  }

  Future<void> _showIncrementsEndDatePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _incrementsEndDate ?? DateTime.now(),
      firstDate: _incrementsStartDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _incrementsEndDate = date;
        _incrementsTimeFilter = 'custom';
      });
      _loadIncrements();
    }
  }

  // =====================================================
  // PURCHASES REPORT HELPER METHODS
  // =====================================================

  Widget _buildPurchasesFilters() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            isSmallScreen ? _buildMobilePurchasesFilters() : _buildDesktopPurchasesFilters(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobilePurchasesFilters() {
    return Column(
      children: [
        // Time Period Filter
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Time Period:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _purchasesTimeFilter,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'today', child: Text('Today')),
                DropdownMenuItem(value: 'this_week', child: Text('This Week')),
                DropdownMenuItem(value: 'this_month', child: Text('This Month')),
                DropdownMenuItem(value: 'all_time', child: Text('All Time')),
                DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _applyPurchasesTimePreset(value);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Custom Date Range (only show if custom is selected)
        if (_purchasesTimeFilter == 'custom') ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Custom Date Range:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showPurchasesStartDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _purchasesStartDate != null
                              ? '${_purchasesStartDate!.day}/${_purchasesStartDate!.month}/${_purchasesStartDate!.year}'
                              : 'Start Date',
                          style: TextStyle(
                            color: _purchasesStartDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('to'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showPurchasesEndDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _purchasesEndDate != null
                              ? '${_purchasesEndDate!.day}/${_purchasesEndDate!.month}/${_purchasesEndDate!.year}'
                              : 'End Date',
                          style: TextStyle(
                            color: _purchasesEndDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        // Category Filter
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Category:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategoryForPurchases,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                hintText: 'All Categories',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Categories')),
                ..._categories.map((category) => 
                  DropdownMenuItem(value: category['id']?.toString(), child: Text(category['name'] ?? 'Unknown'))
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategoryForPurchases = value;
                });
                _loadPurchases();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Product Filter
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Product:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              value: _selectedProductForPurchases,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                hintText: 'All Products',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Products')),
                ..._inventory.map((item) => DropdownMenuItem(
                  value: item['product_id'],
                  child: Text(item['product_name'] ?? 'Unknown'),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedProductForPurchases = value;
                });
                _loadPurchases();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _clearPurchasesFilters,
                child: const Text('Clear Filters'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: _loadPurchases,
                child: const Text('Apply Filters'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopPurchasesFilters() {
    return Column(
      children: [
        // First Row - Time Period and Category
        Row(
          children: [
            // Time Period Filter
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Time Period:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: _purchasesTimeFilter,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'today', child: Text('Today')),
                      DropdownMenuItem(value: 'this_week', child: Text('This Week')),
                      DropdownMenuItem(value: 'this_month', child: Text('This Month')),
                      DropdownMenuItem(value: 'all_time', child: Text('All Time')),
                      DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _applyPurchasesTimePreset(value);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Category Filter
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryForPurchases,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      hintText: 'All Categories',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Categories')),
                      ..._categories.map((category) => 
                        DropdownMenuItem(value: category['id']?.toString(), child: Text(category['name'] ?? 'Unknown'))
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryForPurchases = value;
                      });
                      _loadPurchases();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Product Filter
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Product:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int?>(
                    value: _selectedProductForPurchases,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      hintText: 'All Products',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Products')),
                      ..._inventory.map((item) => DropdownMenuItem(
                        value: item['product_id'],
                        child: Text(item['product_name'] ?? 'Unknown'),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedProductForPurchases = value;
                      });
                      _loadPurchases();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // Custom Date Range (only show if custom is selected)
        if (_purchasesTimeFilter == 'custom') ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Start Date:', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _showPurchasesStartDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _purchasesStartDate != null
                              ? '${_purchasesStartDate!.day}/${_purchasesStartDate!.month}/${_purchasesStartDate!.year}'
                              : 'Start Date',
                          style: TextStyle(
                            color: _purchasesStartDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('End Date:', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _showPurchasesEndDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _purchasesEndDate != null
                              ? '${_purchasesEndDate!.day}/${_purchasesEndDate!.month}/${_purchasesEndDate!.year}'
                              : 'End Date',
                          style: TextStyle(
                            color: _purchasesEndDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        
        const SizedBox(height: 16),
        // Action Buttons
        Row(
          children: [
            OutlinedButton(
              onPressed: _clearPurchasesFilters,
              child: const Text('Clear Filters'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _loadPurchases,
              child: const Text('Apply Filters'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyPurchases() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No purchases found',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or add some inventory purchases',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPurchases,
            child: const Text('Load Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchasesTable() {
    final purchases = _purchasesData['purchases'] as List<dynamic>? ?? [];
    final summary = _purchasesData['summary'] as Map<String, dynamic>? ?? {};
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;

    return Column(
      children: [
        // Summary Cards
        if (summary.isNotEmpty) _buildPurchasesSummary(summary),
        const SizedBox(height: 16),
        
        // Data Table
        Card(
          child: isSmallScreen 
              ? _buildMobilePurchasesList(purchases)
              : _buildDesktopPurchasesTable(purchases),
        ),
      ],
    );
  }

  Widget _buildDesktopPurchasesTable(List<dynamic> purchases) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Units', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Cost Price', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Total Cost', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        
        // Table Body
        ListView.builder(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(), // Enable scrolling
          itemCount: purchases.length,
          itemBuilder: (context, index) {
            final purchase = purchases[index] as Map<String, dynamic>;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          purchase['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'SKU: ${purchase['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${purchase['units_purchased'] ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '\$${_formatNumber(purchase['cost_price'] ?? 0)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '\$${_formatNumber(purchase['total_cost'] ?? 0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatDate(purchase['purchase_date']),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobilePurchasesList(List<dynamic> purchases) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(), // Enable scrolling
      itemCount: purchases.length,
      itemBuilder: (context, index) {
        final purchase = purchases[index] as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          purchase['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        Text(
                          'SKU: ${purchase['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '\$${_formatNumber(purchase['total_cost'] ?? 0)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Details Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Units', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          '${purchase['units_purchased'] ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cost/Unit', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          '\$${_formatNumber(purchase['cost_price'] ?? 0)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Date Info
              Text('Date', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(
                _formatDate(purchase['purchase_date']),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPurchasesSummary(Map<String, dynamic> summary) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    if (isSmallScreen) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.shopping_cart, color: Colors.green[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_purchases'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Purchases', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.inventory, color: Colors.blue[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_units_purchased'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Units Purchased', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.attach_money, color: Colors.orange[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_formatNumber(summary['total_purchase_cost'] ?? 0)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Cost', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.trending_up, color: Colors.purple[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_formatNumber(summary['total_purchase_value'] ?? 0)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Value', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.shopping_cart, color: Colors.green[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_purchases'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Total Purchases'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.inventory, color: Colors.blue[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_units_purchased'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Units Purchased'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.attach_money, color: Colors.orange[600]),
                  const SizedBox(height: 8),
                  Text(
                    '\$${_formatNumber(summary['total_purchase_cost'] ?? 0)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Total Cost'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.trending_up, color: Colors.purple[600]),
                  const SizedBox(height: 8),
                  Text(
                    '\$${_formatNumber(summary['total_purchase_value'] ?? 0)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Total Value'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // INCREMENTS REPORT HELPER METHODS
  // =====================================================

  Widget _buildIncrementsFilters() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            isSmallScreen ? _buildMobileIncrementsFilters() : _buildDesktopIncrementsFilters(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileIncrementsFilters() {
    return Column(
      children: [
        // Time Period Filter
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Time Period:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _incrementsTimeFilter,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'today', child: Text('Today')),
                DropdownMenuItem(value: 'this_week', child: Text('This Week')),
                DropdownMenuItem(value: 'this_month', child: Text('This Month')),
                DropdownMenuItem(value: 'all_time', child: Text('All Time')),
                DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _applyIncrementsTimePreset(value);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Custom Date Range (only show if custom is selected)
        if (_incrementsTimeFilter == 'custom') ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Custom Date Range:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showIncrementsStartDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _incrementsStartDate != null
                              ? '${_incrementsStartDate!.day}/${_incrementsStartDate!.month}/${_incrementsStartDate!.year}'
                              : 'Start Date',
                          style: TextStyle(
                            color: _incrementsStartDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('to'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showIncrementsEndDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _incrementsEndDate != null
                              ? '${_incrementsEndDate!.day}/${_incrementsEndDate!.month}/${_incrementsEndDate!.year}'
                              : 'End Date',
                          style: TextStyle(
                            color: _incrementsEndDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        // Category Filter
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Category:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategoryForIncrements,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                hintText: 'All Categories',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Categories')),
                ..._categories.map((category) => 
                  DropdownMenuItem(value: category['id']?.toString(), child: Text(category['name'] ?? 'Unknown'))
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategoryForIncrements = value;
                });
                _loadIncrements();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Product Filter
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Product:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              value: _selectedProductForIncrements,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                hintText: 'All Products',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Products')),
                ..._inventory.map((item) => DropdownMenuItem(
                  value: item['product_id'],
                  child: Text(item['product_name'] ?? 'Unknown'),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedProductForIncrements = value;
                });
                _loadIncrements();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _clearIncrementsFilters,
                child: const Text('Clear Filters'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: _loadIncrements,
                child: const Text('Apply Filters'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopIncrementsFilters() {
    return Column(
      children: [
        // First Row - Time Period and Category
        Row(
          children: [
            // Time Period Filter
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Time Period:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: _incrementsTimeFilter,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'today', child: Text('Today')),
                      DropdownMenuItem(value: 'this_week', child: Text('This Week')),
                      DropdownMenuItem(value: 'this_month', child: Text('This Month')),
                      DropdownMenuItem(value: 'all_time', child: Text('All Time')),
                      DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _applyIncrementsTimePreset(value);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Category Filter
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryForIncrements,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      hintText: 'All Categories',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Categories')),
                      ..._categories.map((category) => 
                        DropdownMenuItem(value: category['id']?.toString(), child: Text(category['name'] ?? 'Unknown'))
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryForIncrements = value;
                      });
                      _loadIncrements();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Product Filter
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Product:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int?>(
                    value: _selectedProductForIncrements,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      hintText: 'All Products',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Products')),
                      ..._inventory.map((item) => DropdownMenuItem(
                        value: item['product_id'],
                        child: Text(item['product_name'] ?? 'Unknown'),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedProductForIncrements = value;
                      });
                      _loadIncrements();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // Custom Date Range (only show if custom is selected)
        if (_incrementsTimeFilter == 'custom') ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Start Date:', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _showIncrementsStartDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _incrementsStartDate != null
                              ? '${_incrementsStartDate!.day}/${_incrementsStartDate!.month}/${_incrementsStartDate!.year}'
                              : 'Start Date',
                          style: TextStyle(
                            color: _incrementsStartDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('End Date:', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _showIncrementsEndDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _incrementsEndDate != null
                              ? '${_incrementsEndDate!.day}/${_incrementsEndDate!.month}/${_incrementsEndDate!.year}'
                              : 'End Date',
                          style: TextStyle(
                            color: _incrementsEndDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        
        const SizedBox(height: 16),
        // Action Buttons
        Row(
          children: [
            OutlinedButton(
              onPressed: _clearIncrementsFilters,
              child: const Text('Clear Filters'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _loadIncrements,
              child: const Text('Apply Filters'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyIncrements() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_up_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No increments found',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or add some inventory increments',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadIncrements,
            child: const Text('Load Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildIncrementsTable() {
    final increments = _incrementsData['increments'] as List<dynamic>? ?? [];
    final summary = _incrementsData['summary'] as Map<String, dynamic>? ?? {};
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;

    return Column(
      children: [
        // Summary Cards
        if (summary.isNotEmpty) _buildIncrementsSummary(summary),
        const SizedBox(height: 16),
        
        // Data Table
        Card(
          child: isSmallScreen 
              ? _buildMobileIncrementsList(increments)
              : _buildDesktopIncrementsTable(increments),
        ),
      ],
    );
  }

  Widget _buildDesktopIncrementsTable(List<dynamic> increments) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Units Added', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Stock Before', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Stock After', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        
        // Table Body
        ListView.builder(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(), // Enable scrolling
          itemCount: increments.length,
          itemBuilder: (context, index) {
            final increment = increments[index] as Map<String, dynamic>;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          increment['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'SKU: ${increment['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '+${increment['units_added'] ?? 0}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${increment['stock_before'] ?? 0}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${increment['stock_after'] ?? 0}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatDate(increment['increment_date']),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileIncrementsList(List<dynamic> increments) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(), // Enable scrolling
      itemCount: increments.length,
      itemBuilder: (context, index) {
        final increment = increments[index] as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          increment['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        Text(
                          'SKU: ${increment['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '+${increment['units_added'] ?? 0}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Details Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stock Before', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          '${increment['stock_before'] ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stock After', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          '${increment['stock_after'] ?? 0}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Date Info
              Text('Date', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(
                _formatDate(increment['increment_date']),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIncrementsSummary(Map<String, dynamic> summary) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    if (isSmallScreen) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.trending_up, color: Colors.blue[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_increments'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Increments', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.inventory, color: Colors.green[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_units_added'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Units Added', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.attach_money, color: Colors.orange[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_formatNumber(summary['total_cost_added'] ?? 0)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Cost Added', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.trending_up, color: Colors.purple[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_formatNumber(summary['total_value_added'] ?? 0)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Value Added', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.trending_up, color: Colors.blue[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_increments'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Total Increments'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.inventory, color: Colors.green[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_units_added'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Units Added'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.attach_money, color: Colors.orange[600]),
                  const SizedBox(height: 8),
                  Text(
                    '\$${_formatNumber(summary['total_cost_added'] ?? 0)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Cost Added'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.trending_up, color: Colors.purple[600]),
                  const SizedBox(height: 8),
                  Text(
                    '\$${_formatNumber(summary['total_value_added'] ?? 0)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Value Added'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // BUSINESS TRANSFERS REPORT HELPER METHODS
  // =====================================================

  Widget _buildBusinessTransfersFilters() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            isSmallScreen ? _buildMobileBusinessTransfersFilters() : _buildDesktopBusinessTransfersFilters(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBusinessTransfersFilters() {
    return Column(
      children: [
        // Time Period
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Time Period:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _businessTransfersTimePeriod,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Time')),
                DropdownMenuItem(value: 'today', child: Text('Today')),
                DropdownMenuItem(value: 'week', child: Text('This Week')),
                DropdownMenuItem(value: 'month', child: Text('This Month')),
                DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
              ],
              onChanged: (value) {
                setState(() {
                  _businessTransfersTimePeriod = value ?? 'all';
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Custom Date Range (only show if custom is selected)
        if (_businessTransfersTimePeriod == 'custom') ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Custom Date Range:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showBusinessTransfersStartDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _businessTransfersStartDate != null
                              ? 'From: ${_businessTransfersStartDate!.day}/${_businessTransfersStartDate!.month}/${_businessTransfersStartDate!.year}'
                              : 'Start Date',
                          style: TextStyle(
                            color: _businessTransfersStartDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('to'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showBusinessTransfersEndDatePicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _businessTransfersEndDate != null
                              ? 'To: ${_businessTransfersEndDate!.day}/${_businessTransfersEndDate!.month}/${_businessTransfersEndDate!.year}'
                              : 'End Date',
                          style: TextStyle(
                            color: _businessTransfersEndDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 16),
        // Product Filter
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Product:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedProductForTransfers,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                hintText: 'All Products',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Products')),
                ..._inventory.map((item) => DropdownMenuItem(
                  value: item['product_id'],
                  child: Text('${item['product_name']} (${item['sku']})'),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedProductForTransfers = value;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Business Filter (for superadmin)
        if (context.read<AuthProvider>().user?.role == 'superadmin')
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Target Business:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedBusinessForTransfers,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  hintText: 'All Businesses',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Businesses')),
                  ..._businesses.map((business) => DropdownMenuItem(
                    value: business['id'],
                    child: Text(business['name']),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedBusinessForTransfers = value;
                  });
                },
              ),
            ],
          ),
        const SizedBox(height: 16),
        // Apply Filters Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loadBusinessTransfers,
            child: const Text('Apply Filters'),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopBusinessTransfersFilters() {
    return Row(
      children: [
        // Time Period
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Time Period:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _businessTransfersTimePeriod,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Time')),
                  DropdownMenuItem(value: 'today', child: Text('Today')),
                  DropdownMenuItem(value: 'week', child: Text('This Week')),
                  DropdownMenuItem(value: 'month', child: Text('This Month')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
                ],
                onChanged: (value) {
                  setState(() {
                    _businessTransfersTimePeriod = value ?? 'all';
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Custom Date Range (only show if custom is selected)
        if (_businessTransfersTimePeriod == 'custom')
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Custom Date Range:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _showBusinessTransfersStartDatePicker(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _businessTransfersStartDate != null
                                ? 'From: ${_businessTransfersStartDate!.day}/${_businessTransfersStartDate!.month}/${_businessTransfersStartDate!.year}'
                                : 'Start Date',
                            style: TextStyle(
                              color: _businessTransfersStartDate != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('to'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _showBusinessTransfersEndDatePicker(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _businessTransfersEndDate != null
                                ? 'To: ${_businessTransfersEndDate!.day}/${_businessTransfersEndDate!.month}/${_businessTransfersEndDate!.year}'
                                : 'End Date',
                            style: TextStyle(
                              color: _businessTransfersEndDate != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (_businessTransfersTimePeriod == 'custom') const SizedBox(width: 16),
        // Product Filter
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Product:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              DropdownButtonFormField<int>(
                value: _selectedProductForTransfers,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  hintText: 'All Products',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Products')),
                  ..._inventory.map((item) => DropdownMenuItem(
                    value: item['product_id'],
                    child: Text('${item['product_name']} (${item['sku']})'),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedProductForTransfers = value;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Business Filter (for superadmin)
        if (context.read<AuthProvider>().user?.role == 'superadmin')
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Target Business:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  value: _selectedBusinessForTransfers,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    hintText: 'All Businesses',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Businesses')),
                    ..._businesses.map((business) => DropdownMenuItem(
                      value: business['id'],
                      child: Text(business['name']),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedBusinessForTransfers = value;
                    });
                  },
                ),
              ],
            ),
          ),
        const SizedBox(width: 16),
        // Apply Filters Button
        ElevatedButton(
          onPressed: _loadBusinessTransfers,
          child: const Text('Apply Filters'),
        ),
      ],
    );
  }

  Widget _buildEmptyBusinessTransfers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_center_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No business transfers found',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or check if there are any transfers to businesses',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadBusinessTransfers,
            child: const Text('Load Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessTransfersTable() {
    final transfers = _businessTransfersData['transfers'] as List<dynamic>? ?? [];
    final summary = _businessTransfersData['summary'] as Map<String, dynamic>? ?? {};
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;

    return Column(
      children: [
        // Summary Cards
        if (summary.isNotEmpty) _buildBusinessTransfersSummary(summary),
        const SizedBox(height: 16),
        
        // Data Table
        Card(
          child: isSmallScreen 
              ? _buildMobileBusinessTransfersList(transfers)
              : _buildDesktopBusinessTransfersTable(transfers),
        ),
      ],
    );
  }

  Widget _buildDesktopBusinessTransfersTable(List<dynamic> transfers) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('To Business', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        
        // Table Body
        ListView.builder(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(), // Enable scrolling
          itemCount: transfers.length,
          itemBuilder: (context, index) {
            final transfer = transfers[index] as Map<String, dynamic>;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transfer['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'SKU: ${transfer['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${transfer['quantity'] ?? 0}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      transfer['target_business_name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatDate(transfer['transfer_date']),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getTransferStatusColor(transfer['status']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getTransferStatusLabel(transfer['status']),
                        style: TextStyle(
                          color: _getTransferStatusColor(transfer['status']),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileBusinessTransfersList(List<dynamic> transfers) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(), // Enable scrolling
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final transfer = transfers[index] as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transfer['product_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        Text(
                          'SKU: ${transfer['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${transfer['quantity'] ?? 0}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Details Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('To Business', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          transfer['target_business_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getTransferStatusColor(transfer['status']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getTransferStatusLabel(transfer['status']),
                            style: TextStyle(
                              color: _getTransferStatusColor(transfer['status']),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Date Info
              Text('Date', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(
                _formatDate(transfer['transfer_date']),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBusinessTransfersSummary(Map<String, dynamic> summary) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 768;
    
    if (isSmallScreen) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.business_center, color: Colors.blue[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_transfers'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Transfers', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.inventory, color: Colors.green[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['total_quantity_transferred'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Units Transferred', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.business, color: Colors.orange[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['unique_businesses'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Businesses Served', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(Icons.category, color: Colors.purple[600], size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${summary['unique_products'] ?? 0}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text('Products Transferred', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.business_center, color: Colors.blue[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_transfers'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Total Transfers'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.inventory, color: Colors.green[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['total_quantity_transferred'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Units Transferred'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.business, color: Colors.orange[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['unique_businesses'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Businesses Served'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.category, color: Colors.purple[600]),
                  const SizedBox(height: 8),
                  Text(
                    '${summary['unique_products'] ?? 0}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Products Transferred'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getTransferStatusColor(String? status) {
    switch (status) {
      case 'transfer':
        return Colors.green;
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTransferStatusLabel(String? status) {
    switch (status) {
      case 'transfer':
        return 'Transfer';
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  void _showBusinessTransfersStartDatePicker(BuildContext context) {
    showDatePicker(
      context: context,
      initialDate: _businessTransfersStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    ).then((date) {
      if (date != null) {
        setState(() {
          _businessTransfersStartDate = date;
        });
      }
    });
  }

  void _showBusinessTransfersEndDatePicker(BuildContext context) {
    showDatePicker(
      context: context,
      initialDate: _businessTransfersEndDate ?? DateTime.now(),
      firstDate: _businessTransfersStartDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    ).then((date) {
      if (date != null) {
        setState(() {
          _businessTransfersEndDate = date;
        });
      }
    });
  }

  Widget _buildTopProductCard(Map<String, dynamic> product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(product['product_name'] ?? ''),
        subtitle: Text('SKU: ${product['sku'] ?? ''}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${product['movement_count'] ?? 0} ${t(context,'movements')}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${product['total_in'] ?? 0} in, ${product['total_transferred'] ?? 0} out',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }



  void _showAddProductsDialog() {
    // Use the exact same add product dialog from inventory screen
    _showAddProductDialog();
  }

  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (context) => _ProductDialog(
        apiService: _apiService,
                  onSave: (productData, imageFile, {webImageBytes, webImageName}) async {
                    try {
                      // Add storeId to productData so it gets added to store inventory immediately
                      productData['storeId'] = widget.storeId;
                      
                      // Create the product (it will automatically be added to store inventory)
                      final product = await _apiService.createProduct(productData, imageFile: imageFile, webImageBytes: webImageBytes, webImageName: webImageName);
                      
                      _loadData();
                      if (mounted) {
                        Navigator.of(context).pop();
                        SuccessUtils.showProductSuccess(context, 'added to ${widget.storeName} warehouse');
                      }
                    } catch (e, stack) {
                      print('Error adding product to store: $e');
                      print('Stack trace: $stack');
                      if (mounted) {
                        SuccessUtils.showOperationError(context, 'add product to store', e.toString());
                      }
                    }
                  },
      ),
    );
  }

  void _showTransferDialog() {
    showDialog(
      context: context,
      builder: (context) => _TransferDialog(
        storeId: widget.storeId,
        storeName: widget.storeName,
        inventory: _inventory,
        businesses: _businesses,
        apiService: _apiService,
        onTransfer: () {
          _loadData(); // Refresh inventory after transfer
        },
      ),
    );
  }

  void _showIncrementDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => _IncrementDialog(
        item: item,
        onIncrement: (quantity, costPrice, notes) async {
          try {
            await _apiService.incrementProductQuantity(
              widget.storeId,
              item['product_id'],
              quantity,
              costPrice: costPrice,
              notes: notes,
            );
            
            _loadData();
            if (mounted) {
              Navigator.of(context).pop();
              SuccessUtils.showProductSuccess(context, 'stock incremented');
            }
          } catch (e) {
            print('Error incrementing product: $e');
            if (mounted) {
              SuccessUtils.showOperationError(context, 'increment stock', e.toString());
            }
          }
        },
      ),
    );
  }

  void _showEditCostPriceDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => _EditCostPriceDialog(
        item: item,
        onUpdate: (newCostPrice) async {
          try {
            await _apiService.updateProductCostPrice(
              item['product_id'],
              newCostPrice,
            );
            
            _loadData();
            if (mounted) {
              Navigator.of(context).pop();
              SuccessUtils.showProductSuccess(context, 'cost price updated');
            }
          } catch (e) {
            print('Error updating cost price: $e');
            if (mounted) {
              SuccessUtils.showOperationError(context, 'update cost price', e.toString());
            }
          }
        },
      ),
    );
  }


  // Stock Summary methods (copied from inventory_screen.dart)
  Widget _buildStoreReportFilters() {
    return Row(
      children: [
        // Category Filter
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedReportCategory,
                isExpanded: true,
                hint: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('All Categories'),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.grey[600],
                  size: 18,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('All Categories'),
                    ),
                  ),
                  ...['Electronics', 'Clothing', 'Food', 'Books'].map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(category),
                      ),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedReportCategory = value;
                    _stockSummaryCurrentPage = 0;
                  });
                  _fetchInventoryValueReport();
                },
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Product Filter
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedReportProduct,
                isExpanded: true,
                hint: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('All Products'),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.grey[600],
                  size: 18,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('All Products'),
                    ),
                  ),
                  ..._inventory.map((item) {
                    return DropdownMenuItem(
                      value: item['product_name']?.toString(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(item['product_name']?.toString() ?? ''),
                      ),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedReportProduct = value;
                    _stockSummaryCurrentPage = 0;
                  });
                  _fetchInventoryValueReport();
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStockSummaryFilters(bool isSmallMobile) {
    return Column(
      children: [
        // Horizontal Filter Row
        Row(
          children: [
            // Filter Type Dropdown
            Expanded(
              flex: 2,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _stockSummaryFilterType,
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey[600],
                      size: 18,
                    ),
                    items: _stockSummaryFilterOptions.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _stockSummaryFilterType = value!;
                      });
                      if (value != 'Custom') {
                        _applyStockSummaryPreset(value!);
                      } else {
                        // For custom, just refresh with current dates
                        _fetchInventoryValueReport();
                      }
                    },
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Custom Date Range (only show when Custom is selected)
            if (_stockSummaryFilterType == 'Custom') ...[
              Expanded(
                flex: 1,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showStockSummaryStartDatePicker(context),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _stockSummaryStartDate != null 
                                ? '${_stockSummaryStartDate!.day}/${_stockSummaryStartDate!.month}/${_stockSummaryStartDate!.year}'
                                : 'Start',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                flex: 1,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showStockSummaryEndDatePicker(context),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _stockSummaryEndDate != null 
                                ? '${_stockSummaryEndDate!.day}/${_stockSummaryEndDate!.month}/${_stockSummaryEndDate!.year}'
                                : 'End',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
            ],
            
            // Refresh Button
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _fetchInventoryValueReport,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.refresh,
                          color: Theme.of(context).primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Refresh',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ),
          ),
        ],
        ),
      ],
    );
  }

  // Custom date picker methods for stock summary
  Future<void> _showStockSummaryStartDatePicker(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _stockSummaryStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _stockSummaryStartDate) {
      setState(() {
        _stockSummaryStartDate = picked;
      });
      _fetchInventoryValueReport();
    }
  }

  Future<void> _showStockSummaryEndDatePicker(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _stockSummaryEndDate ?? DateTime.now(),
      firstDate: _stockSummaryStartDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _stockSummaryEndDate) {
      setState(() {
        _stockSummaryEndDate = picked;
      });
      _fetchInventoryValueReport();
    }
  }

  void _applyStockSummaryPreset(String filterType) {
    final now = DateTime.now();
    
    switch (filterType) {
      case 'Today':
        _stockSummaryStartDate = DateTime(now.year, now.month, now.day);
        _stockSummaryEndDate = _stockSummaryStartDate!.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
        break;
      case 'This Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        _stockSummaryStartDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        _stockSummaryEndDate = _stockSummaryStartDate!.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
        break;
      case 'This Month':
        _stockSummaryStartDate = DateTime(now.year, now.month, 1);
        _stockSummaryEndDate = DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1));
        break;
      case 'Custom':
        // Keep existing dates
        break;
    }
    
    _fetchInventoryValueReport();
  }

  Future<void> _fetchInventoryValueReport() async {
    setState(() {
      _valueReportLoading = true;
      _valueReportError = null;
    });
    try {
      // Apply filter logic based on selected filter type
      DateTime? startDate;
      DateTime? endDate;

      final now = DateTime.now();
      
      switch (_stockSummaryFilterType) {
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          endDate = startDate.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
          break;
        case 'This Week':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
          endDate = startDate.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1));
          break;
        case 'Custom':
          // Use existing custom date range
          startDate = _stockSummaryStartDate;
          endDate = _stockSummaryEndDate;
          break;
        default:
          // Default to Today if no filter selected
          startDate = DateTime(now.year, now.month, now.day);
          endDate = startDate.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
      }
      
      print('🔍 Stock Summary Filter: $_stockSummaryFilterType');
      print('🔍 Start Date: $startDate');
      print('🔍 End Date: $endDate');
      print('🔍 Store ID: ${widget.storeId}');
      print('🔍 Selected Business ID: $_selectedBusinessId');
      
      // Prepare filter parameters
      final Map<String, dynamic> filterParams = {};
      if (startDate != null) filterParams['start_date'] = startDate.toIso8601String();
      if (endDate != null) filterParams['end_date'] = endDate.toIso8601String();
      
      // Add category filter
      if (_selectedReportCategory != null && _selectedReportCategory != 'All') {
        filterParams['category'] = _selectedReportCategory;
      }
      
      // Add product filter
      if (_selectedReportProduct != null && _selectedReportProduct != 'All') {
        filterParams['product_name'] = _selectedReportProduct;
      }
      
      print('🔍 Stock Summary Filters: $filterParams');
      
      // Get store inventory report data
      final businessId = _selectedBusinessId ?? context.read<AuthProvider>().user?.businessId;
      if (businessId == null) {
        throw Exception('Business ID not found');
      }

      final data = await _apiService.getStoreInventoryReport(
        widget.storeId,
        businessId,
        startDate ?? DateTime.now().subtract(const Duration(days: 1)),
        endDate ?? DateTime.now(),
      );
      
      print('🔍 API Response Data: $data');
      print('🔍 Top Products: ${data['top_products']}');
      print('🔍 Summary: ${data['summary']}');
      
      // Convert the report data to match the expected format
      final List<Map<String, dynamic>> reportRows = [];
      
      // Add top products data (products with movements)
      if (data['top_products'] != null && data['top_products'].isNotEmpty) {
        for (var product in data['top_products']) {
          reportRows.add({
            'product_id': product['product_id'],
            'product_name': product['product_name'],
            'sku': product['sku'],
            'category_name': 'Store Product',
            'quantity_sold': _safeToInt(product['total_out']),
            'quantity_remaining': _safeToInt(product['current_stock']),
            'revenue': _safeToInt(product['total_out']) * _safeToDouble(product['price']),
            'profit': _calculateProfit(product),
            'sale_mode': 'retail',
          });
        }
      } else {
        // If no movements, show current inventory data
        print('🔍 No top products found, showing current inventory data');
        
        // Get current inventory data from the main inventory
        try {
          final businessId = _selectedBusinessId ?? context.read<AuthProvider>().user?.businessId;
          if (businessId != null) {
            final inventoryData = await _apiService.getStoreInventory(widget.storeId, businessId);
            print('🔍 Current inventory data: $inventoryData');
            
            // getStoreInventory returns List<Map<String, dynamic>> directly
            if (inventoryData is List) {
              // Direct list of inventory items
              for (var item in inventoryData) {
                if (item is Map<String, dynamic>) {
                  reportRows.add({
                    'product_id': item['product_id'],
                    'product_name': item['product_name'],
                    'sku': item['sku'] ?? '',
                    'category_name': item['category_name'] ?? 'Store Product',
                    'quantity_sold': 0, // No movements in this period
                    'quantity_remaining': _safeToInt(item['store_quantity']),
                    'revenue': 0.0, // No sales in this period
                    'profit': 0.0, // No profit in this period
                    'sale_mode': 'retail',
                  });
                }
              }
            }
          }
        } catch (e) {
          print('🔍 Error getting current inventory: $e');
        }
      }
      
      print('🔍 Final Report Rows: ${reportRows.length} items');
      print('🔍 Report Rows Data: $reportRows');
      
      setState(() {
        _valueReportRows = reportRows;
        _resetStockSummaryPagination();
      });
    } catch (e) {
      setState(() {
        _valueReportError = 'Failed to load value report: $e';
      });
    } finally {
      setState(() {
        _valueReportLoading = false;
      });
    }
  }

  void _resetStockSummaryPagination() {
    _stockSummaryCurrentPage = 0;
  }

  String _buildFilterStatusText() {
    List<String> filters = [];
    if (_selectedReportCategory != null && _selectedReportCategory != 'All') {
      filters.add('Category: $_selectedReportCategory');
    }
    if (_selectedReportProduct != null && _selectedReportProduct != 'All') {
      filters.add('Product: $_selectedReportProduct');
    }
    return filters.isNotEmpty ? 'Filters: ${filters.join(', ')}' : 'No filters applied';
  }

  List<Map<String, dynamic>> get _filteredStockSummaryData {
    return _valueReportRows;
  }

  List<Map<String, dynamic>> _getPaginatedData(List<Map<String, dynamic>> data, int page) {
    final startIndex = page * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, data.length);
    return data.sublist(startIndex, endIndex);
  }

  int _getTotalPages(int totalItems) {
    return (totalItems / _itemsPerPage).ceil();
  }

  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void _exportStockSummaryToPdf() {
    // TODO: Implement PDF export
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context, 'PDF export functionality coming soon'))),
    );
  }

  Widget _buildValueReportTable(bool isSmallMobile) {
    if (_valueReportLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_valueReportError != null) {
      return Text(
        _valueReportError!,
        style: TextStyle(color: Colors.red, fontSize: isSmallMobile ? 12 : 14),
      );
    }
    
    if (_valueReportRows.isEmpty) {
      return Text(
        t(context, 'No stock summary data'),
        style: TextStyle(fontSize: isSmallMobile ? 12 : 14),
      );
    }

    // Check if filtered data is empty
    if (_filteredStockSummaryData.isEmpty) {
      return Column(
        children: [
          Icon(
            Icons.filter_list,
            size: isSmallMobile ? 32 : 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'No data matches the selected filters',
            style: TextStyle(
              fontSize: isSmallMobile ? 12 : 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your category or product filters',
            style: TextStyle(
              fontSize: isSmallMobile ? 10 : 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      );
    }

    if (isSmallMobile) {
      // Mobile layout - cards with pagination
      final paginatedData = _getPaginatedData(_filteredStockSummaryData, _stockSummaryCurrentPage);
      final totalPages = _getTotalPages(_filteredStockSummaryData.length);
      
      return Column(
        children: [
          ...paginatedData.map((row) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row['product_name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SKU: ${row['sku'] ?? ''}', style: const TextStyle(fontSize: 12)),
                            Text('Category: ${row['category_name'] ?? ''}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Sold: ${_filteredStockSummaryData.fold<double>(0, (sum, r) => sum + _safeToDouble(r['quantity_sold'])).toInt().toString()}', 
                                 style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Remaining: ${row['quantity_remaining']?.toString() ?? ''}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Revenue: ₦${_safeToDouble(row['revenue']).toStringAsFixed(2)}'),
                      ),
                      Expanded(
                        child: Text('Profit: ₦${_safeToDouble(row['profit']).toStringAsFixed(2)}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )).toList(),
          
          // Mobile Pagination Controls
          if (totalPages > 1) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Text(
                    'Page ${_stockSummaryCurrentPage + 1} of $totalPages',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        onPressed: _stockSummaryCurrentPage > 0
                          ? () => setState(() => _stockSummaryCurrentPage--)
                          : null,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      Text(
                        '${(_stockSummaryCurrentPage * _itemsPerPage) + 1}-${(_stockSummaryCurrentPage + 1) * _itemsPerPage} of ${_filteredStockSummaryData.length.toString()}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        onPressed: _stockSummaryCurrentPage < totalPages - 1
                          ? () => setState(() => _stockSummaryCurrentPage++)
                          : null,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    // Desktop layout - table with pagination
    final paginatedData = _getPaginatedData(_filteredStockSummaryData, _stockSummaryCurrentPage);
    final totalPages = _getTotalPages(_filteredStockSummaryData.length);
    
    return Column(
      children: [
        // Table
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text(t(context, 'Product'))),
              DataColumn(label: Text(t(context, 'SKU'))),
              DataColumn(label: Text(t(context, 'Category'))),
              DataColumn(label: Text(t(context, 'Sold Qty'))),
              DataColumn(label: Text(t(context, 'Qty Remaining'))),
              DataColumn(label: Text(t(context, 'Revenue'))),
              DataColumn(label: Text(t(context, 'Profit'))),
              DataColumn(label: Text(t(context, 'Mode'))),
            ],
            rows: [
              ...paginatedData.map((row) => DataRow(
                cells: [
                  DataCell(
                    InkWell(
                      child: Text(row['product_name'] ?? '', style: TextStyle(color: Theme.of(context).primaryColor, decoration: TextDecoration.underline)),
                      onTap: () => _showProductTransactionsDialog(row['product_id'], row['product_name'] ?? ''),
                    ),
                  ),
                  DataCell(Text(row['sku'] ?? '')),
                  DataCell(Text(row['category_name'] ?? '')),
                  DataCell(Text(_valueReportRows.fold<double>(0, (sum, r) => sum + _safeToDouble(r['quantity_sold'])).toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(row['quantity_remaining']?.toString() ?? '')),
                  DataCell(Text('₦${_safeToDouble(row['revenue']).toStringAsFixed(2)}')),
                  DataCell(Text('₦${_safeToDouble(row['profit']).toStringAsFixed(2)}')),
                  DataCell(Text((row['sale_mode'] ?? '').toString().isNotEmpty ? (row['sale_mode'] == 'wholesale' ? 'Wholesale' : 'Retail') : '')),
                ],
              )),
              // Totals row
              DataRow(
                color: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                  return Colors.grey[200];
                }),
                cells: [
                  DataCell(Text(t(context, 'TOTAL'), style: const TextStyle(fontWeight: FontWeight.bold))),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  DataCell(Text(_filteredStockSummaryData.fold<double>(0, (sum, r) => sum + _safeToDouble(r['quantity_sold'])).toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                  const DataCell(Text('')),
                  DataCell(Text('₦${_filteredStockSummaryData.fold<double>(0, (sum, r) => sum + _safeToDouble(r['revenue'])).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text('₦${_filteredStockSummaryData.fold<double>(0, (sum, r) => sum + _safeToDouble(r['profit'])).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                  const DataCell(Text('')),
                ],
              ),
            ],
          ),
        ),
        
        // Desktop Pagination Controls
        if (totalPages > 1)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${(_stockSummaryCurrentPage * _itemsPerPage) + 1} to ${(_stockSummaryCurrentPage + 1) * _itemsPerPage} of ${_filteredStockSummaryData.length.toString()} entries',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      onPressed: _stockSummaryCurrentPage > 0
                        ? () => setState(() => _stockSummaryCurrentPage--)
                        : null,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Page ${_stockSummaryCurrentPage + 1} of $totalPages',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      onPressed: _stockSummaryCurrentPage < totalPages - 1
                        ? () => setState(() => _stockSummaryCurrentPage++)
                        : null,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showProductTransactionsDialog(int productId, String productName) {
    // TODO: Implement product transactions dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Product transactions for $productName (ID: $productId)')),
    );
  }

  // =====================================================
  // COMPREHENSIVE REPORTS - NEW METHODS
  // =====================================================

  double _calculateProfit(Map<String, dynamic> product) {
    try {
      final totalOut = _safeToInt(product['total_out']);
      final price = _safeToDouble(product['price']);
      final costPrice = _safeToDouble(product['cost_price']);
      
      final revenue = totalOut * price;
      final cost = totalOut * costPrice;
      final profit = revenue - cost;
      
      return profit.clamp(0.0, double.infinity);
    } catch (e) {
      print('Error calculating profit: $e');
      return 0.0;
    }
  }

  Widget _buildCurrentStockSummary() {
    if (_reports.isEmpty || _reports['current_stock'] == null) {
      return _buildEmptyCard('Current Stock Summary', Icons.inventory_2);
    }

    final currentStock = _reports['current_stock'];
    final summary = currentStock['summary'] ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  t(context, 'Current Stock Summary'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Products',
                    '${summary['total_products'] ?? 0}',
                    Icons.category,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Total Units',
                    '${summary['total_units'] ?? 0}',
                    Icons.inventory,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'In Stock',
                    '${summary['in_stock'] ?? 0}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Low Stock',
                    '${summary['low_stock'] ?? 0}',
                    Icons.warning,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Out of Stock',
                    '${summary['out_of_stock'] ?? 0}',
                    Icons.error,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String title, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'No data available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummary() {
    if (_reports.isEmpty || _reports['financial_summary'] == null) {
      return _buildEmptyCard('Financial Summary', Icons.attach_money);
    }

    final financial = _reports['financial_summary'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  t(context, 'Financial Summary'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Cost Value',
                    '\$${_formatNumber(financial['total_cost_value'] ?? 0)}',
                    Icons.shopping_cart,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Total Selling Value',
                    '\$${_formatNumber(financial['total_selling_value'] ?? 0)}',
                    Icons.sell,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Profit Potential',
                    '\$${_formatNumber(financial['total_profit_potential'] ?? 0)}',
                    Icons.trending_up,
                    Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Avg Cost Price',
                    '\$${_formatNumber(financial['average_cost_price'] ?? 0)}',
                    Icons.price_check,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final num = double.tryParse(value.toString()) ?? 0;
    return num.toStringAsFixed(2);
  }

  Widget _buildMovementSummary() {
    if (_reports.isEmpty || _reports['movement_summary'] == null) {
      return _buildEmptyCard('Movement Summary', Icons.trending_up);
    }

    final movement = _reports['movement_summary'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Text(
                  t(context, 'Movement Summary'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Stock In',
                    '${movement['total_stock_in'] ?? 0}',
                    Icons.arrow_downward,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Transferred Out',
                    '${movement['total_transferred_out'] ?? 0}',
                    Icons.arrow_upward,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockAlerts() {
    if (_reports.isEmpty || _reports['low_stock_alerts'] == null) {
      return _buildEmptyCard('Low Stock Alerts', Icons.warning);
    }

    final alerts = _reports['low_stock_alerts'] as List;
    if (alerts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.check_circle, size: 48, color: Colors.green[400]),
              const SizedBox(height: 8),
              Text(
                'Low Stock Alerts',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'All products are well stocked!',
                style: TextStyle(color: Colors.green[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[600]),
                const SizedBox(width: 8),
                Text(
                  t(context, 'Low Stock Alerts'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${alerts.length}',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...alerts.take(3).map((alert) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: alert['alert_level']?.contains('CRITICAL') == true 
                    ? Colors.red[50] 
                    : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: alert['alert_level']?.contains('CRITICAL') == true 
                      ? Colors.red[200]! 
                      : Colors.orange[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    alert['alert_level']?.contains('CRITICAL') == true 
                        ? Icons.error 
                        : Icons.warning,
                    color: alert['alert_level']?.contains('CRITICAL') == true 
                        ? Colors.red[600] 
                        : Colors.orange[600],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert['product_name'] ?? 'Unknown Product',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Stock: ${alert['current_quantity'] ?? 0} / Min: ${alert['min_stock_level'] ?? 0}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProducts() {
    if (_reports.isEmpty || _reports['top_products'] == null) {
      return _buildEmptyCard('Top Products', Icons.star);
    }

    final topProducts = _reports['top_products'] as List;
    if (topProducts.isEmpty) {
      return _buildEmptyCard('Top Products', Icons.star);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber[600]),
                const SizedBox(width: 8),
                Text(
                  t(context, 'Top Products'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Top ${topProducts.length}',
                    style: TextStyle(
                      color: Colors.amber[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...topProducts.take(3).map((product) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.amber[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.inventory,
                      color: Colors.amber[600],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['product_name'] ?? 'Unknown Product',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'SKU: ${product['sku'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${product['current_stock'] ?? 0}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Stock',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // LOADING, ERROR, AND EMPTY STATE METHODS
  // =====================================================

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t(context, 'Loading inventory...'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t(context, 'Please wait while we fetch your data'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ThemeAwareColors.getSecondaryTextColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Colors.red.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t(context, 'Something went wrong'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? t(context, 'An unexpected error occurred'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ThemeAwareColors.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: Text(t(context, 'Retry')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).primaryColor,
                    side: BorderSide(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                    });
                  },
                  icon: const Icon(Icons.close),
                  label: Text(t(context, 'Dismiss')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 64,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ThemeAwareColors.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionText),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =====================================================
  // MOBILE HELPER METHODS
  // =====================================================

  Widget _buildMobileQuickStats() {
    final currentStock = _reports['current_stock']?['summary'] ?? {};
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Products',
            (currentStock['total_products'] ?? 0).toString(),
            Icons.inventory_2,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Total Units',
            (currentStock['total_units'] ?? 0).toString(),
            Icons.shopping_cart,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Low Stock',
            (currentStock['low_stock'] ?? 0).toString(),
            Icons.warning,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Out of Stock',
            (currentStock['out_of_stock'] ?? 0).toString(),
            Icons.error,
            Colors.red,
          ),
        ),
      ],
    );
  }


  Widget _buildMobileInventoryList() {
    // Check loading state first - show loading if data is being fetched
    if (_loading) {
      return _buildLoadingState();
    }
    
    final filteredInventory = _inventory.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          item['product_name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item['sku'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (item['category_name'] ?? item['category'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesStockStatus = _selectedStockStatus.isEmpty ||
          (item['stock_status'] ?? '').toString() == _selectedStockStatus;
      
      final matchesCategory = _selectedCategory.isEmpty ||
          (item['category_name'] ?? item['category'] ?? '').toString() == _selectedCategory;
      
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
      final matchesMinPrice = _minPrice == null || price >= _minPrice!;
      final matchesMaxPrice = _maxPrice == null || price <= _maxPrice!;
      
      return matchesSearch && matchesStockStatus && matchesCategory && matchesMinPrice && matchesMaxPrice;
    }).toList();

    if (filteredInventory.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inventory_2_outlined,
        title: t(context, 'No inventory found'),
        subtitle: t(context, 'Add products to this store to get started'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        controller: _inventoryScrollController,
        padding: const EdgeInsets.all(16),
      itemCount: filteredInventory.length,
      itemBuilder: (context, index) {
        final item = filteredInventory[index];
        return _buildMobileInventoryCard(item);
      },
      ),
    );
  }

  Widget _buildMobileInventoryCard(Map<String, dynamic> item) {
    final stockStatus = item['stock_status'] as String?;
    Color statusColor;
    IconData statusIcon;
    
    switch (stockStatus) {
      case 'LOW_STOCK':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      case 'OUT_OF_STOCK':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showEditCostPriceDialog(item),
        borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item['image_url'] != null
                      ? Image.network(
                          item['image_url'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image, color: Colors.grey),
                            );
                          },
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['product_name'] ?? 'Unknown Product',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${item['sku'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeAwareColors.getSecondaryTextColor(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              stockStatus == 'LOW_STOCK' ? 'Low Stock' :
                              stockStatus == 'OUT_OF_STOCK' ? 'Out of Stock' : 'In Stock',
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    'Current Stock',
                    '${_safeToInt(item['store_quantity'] ?? item['quantity'])}',
                    Icons.inventory,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    'Selling Price',
                    '₦${(double.tryParse(item['price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(0)}',
                    Icons.attach_money,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    'Cost',
                    '₦${(double.tryParse(item['cost_price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(0)}',
                    Icons.money_off,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddStockDialog(item),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Stock'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditCostDialog(item),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Cost'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ThemeAwareColors.getSecondaryTextColor(context)),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 10,
              color: ThemeAwareColors.getSecondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddStockDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => _IncrementDialog(
        item: item,
        onIncrement: (quantity, cost, notes) {
          // Handle stock increment
          print('Adding $quantity units to ${item['product_name']}');
        },
      ),
    );
  }

  void _showEditCostDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => _EditCostPriceDialog(
        item: item,
        onUpdate: (newCostPrice) {
          // Handle cost price update
          print('Updating cost price to $newCostPrice for ${item['product_name']}');
        },
      ),
    );
  }

  Widget _buildMobileMovementFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedMovementType.isEmpty ? null : _selectedMovementType,
              decoration: InputDecoration(
                labelText: t(context, 'Movement Type'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: [
                DropdownMenuItem(value: '', child: Text(t(context, 'All Types'))),
                DropdownMenuItem(value: 'in', child: Text(t(context, 'In'))),
                DropdownMenuItem(value: 'out', child: Text(t(context, 'Out'))),
                DropdownMenuItem(value: 'transfer_out', child: Text(t(context, 'Transfer Out'))),
                DropdownMenuItem(value: 'adjustment', child: Text(t(context, 'Adjustment'))),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedMovementType = value ?? '';
                });
                _loadData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileReportCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildMobileQuickStats(),
          const SizedBox(height: 16),
          // Add more report cards as needed
        ],
      ),
    );
  }


}


class _ProductDialog extends StatefulWidget {
  final ApiService apiService;
  final Product? product;
  final Function(Map<String, dynamic>, File?, {Uint8List? webImageBytes, String? webImageName}) onSave;

  const _ProductDialog({
    required this.apiService,
    this.product,
    required this.onSave,
  });

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController();
  final _skuController = TextEditingController();
  
  File? _imageFile;
  String? _imageUrl;
  String? _webImageDataUrl;
  String? _webImageName;
  bool _isLoading = false;
  int? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _descriptionController.text = widget.product!.description ?? '';
      _priceController.text = widget.product!.price.toString();
      _costController.text = widget.product!.costPrice.toString();
      _stockController.text = widget.product!.stockQuantity.toString();
      _skuController.text = widget.product!.sku ?? '';
      _imageUrl = widget.product!.imageUrl;
      _selectedCategoryId = widget.product!.categoryId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ApiService().getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      // Show dialog to choose between camera and gallery
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.add_a_photo, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(t(context, 'Select Image Source')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.blue),
                        ),
                        title: Text(
                          t(context, 'Camera'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(t(context, 'Take a new photo')),
                        onTap: () => Navigator.of(context).pop(ImageSource.camera),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                      Divider(height: 1, color: Colors.grey[300]),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.photo_library, color: Colors.green),
                        ),
                        title: Text(
                          t(context, 'Gallery'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(t(context, 'Choose from gallery')),
                        onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t(context, 'Cancel')),
              ),
            ],
          );
        },
      );

      if (source != null) {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        
        if (image != null) {
          setState(() {
            _imageFile = File(image.path);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _pickImageWeb() async {
    try {
      // Show dialog to choose between camera and file picker
      final bool? useCamera = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.add_a_photo, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(t(context, 'Select Image Source')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.blue),
                        ),
                        title: Text(
                          t(context, 'Camera'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(t(context, 'Take a new photo')),
                        onTap: () => Navigator.of(context).pop(true),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                      Divider(height: 1, color: Colors.grey[300]),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.photo_library, color: Colors.green),
                        ),
                        title: Text(
                          t(context, 'File Picker'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(t(context, 'Choose from files')),
                        onTap: () => Navigator.of(context).pop(false),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t(context, 'Cancel')),
              ),
            ],
          );
        },
      );

      if (useCamera == null) return;

      if (useCamera) {
        // Use camera for web
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        
        if (image != null) {
          final bytes = await image.readAsBytes();
          final base64String = base64Encode(bytes);
          final mimeType = 'image/jpeg'; // Camera typically returns JPEG
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          
          setState(() {
            _webImageDataUrl = 'data:$mimeType;base64,$base64String';
            _webImageName = 'camera_$timestamp.jpg';
          });
        }
      } else {
        // Use file picker
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['png', 'jpg', 'jpeg'],
          allowMultiple: false,
          withData: true,
        );

        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          if (file.bytes != null) {
            // Determine MIME type and force lowercase extension
            String? ext = file.extension?.toLowerCase();
            String mimeType =
                ext == 'png' ? 'image/png' :
                (ext == 'jpg' || ext == 'jpeg') ? 'image/jpeg' : 'image/jpeg';
            String forcedExt = (ext == 'png' || ext == 'jpg' || ext == 'jpeg') ? ext! : 'jpg';
            String baseName = file.name.contains('.') ? file.name.substring(0, file.name.lastIndexOf('.')) : file.name;
            setState(() {
              _webImageDataUrl = 'data:$mimeType;base64,${base64Encode(file.bytes!)}';
              _webImageName = baseName + '.' + forcedExt;
            });
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final productData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'cost_price': double.parse(_costController.text),
        'stock_quantity': int.parse(_stockController.text),
        'category_id': _selectedCategoryId,
        'sku': _skuController.text.trim(),
        'low_stock_threshold': 10, // Default value
      };

      widget.onSave(productData, _imageFile, webImageBytes: kIsWeb && _webImageDataUrl != null ? base64Decode(_webImageDataUrl!.split(',').last) : null, webImageName: kIsWeb ? _webImageName : null);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'Error: ')}$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth <= 480;
          
          return Container(
            width: MediaQuery.of(context).size.width * (isMobile ? 0.95 : 0.9),
            constraints: BoxConstraints(
              maxWidth: isMobile ? 400 : 600,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).primaryColor.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(isMobile ? 6 : 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              widget.product == null ? Icons.add_box : Icons.edit,
                              color: Colors.white,
                              size: isMobile ? 20 : 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.product == null ? t(context, 'Add New Product') : t(context, 'Edit Product'),
                                  style: TextStyle(
                                    fontSize: isMobile ? 16 : 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.product == null 
                                      ? t(context, 'Create a new product in your inventory')
                                      : t(context, 'Update product information'),
                                  style: TextStyle(
                                    fontSize: isMobile ? 11 : 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                            padding: EdgeInsets.all(isMobile ? 4 : 8),
                            constraints: BoxConstraints(
                              minWidth: isMobile ? 32 : 40,
                              minHeight: isMobile ? 32 : 40,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Image Section
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          if (kIsWeb) {
                            _pickImageWeb();
                          } else {
                            _pickImage();
                          }
                        },
                        child: Container(
                          width: isMobile ? 100 : 120,
                          height: isMobile ? 100 : 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: kIsWeb
                              ? (_webImageDataUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.network(
                                        _webImageDataUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            _buildImagePlaceholder(isMobile),
                                      ),
                                    )
                                  : (_imageUrl != null && _imageUrl!.isNotEmpty)
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Image.network(
                                            Api.getFullImageUrl(_imageUrl),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                _buildImagePlaceholder(isMobile),
                                          ),
                                        )
                                      : _buildImagePlaceholder(isMobile))
                              : _imageFile != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.file(
                                        _imageFile!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : (_imageUrl != null && _imageUrl!.isNotEmpty)
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Image.network(
                                            Api.getFullImageUrl(_imageUrl),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                _buildImagePlaceholder(isMobile),
                                          ),
                                        )
                                      : _buildImagePlaceholder(isMobile),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Form Fields
                    if (isMobile) ...[
                      // Mobile layout - stacked vertically
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: t(context, 'Product Name *'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.inventory_2),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return t(context, 'Product name is required');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _skuController,
                        decoration: InputDecoration(
                          labelText: t(context, 'SKU *'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.qr_code),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return t(context, 'SKU is required');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: t(context, 'Description'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.description),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: t(context, 'Price *'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.attach_money),
                          filled: true,
                          fillColor: Colors.green[50],
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return t(context, 'Price is required');
                          }
                          if (double.tryParse(value) == null) {
                            return t(context, 'Please enter a valid number');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _costController,
                        decoration: InputDecoration(
                          labelText: t(context, 'Cost *'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.account_balance_wallet),
                          filled: true,
                          fillColor: Colors.orange[50],
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return t(context, 'Cost is required');
                          }
                          if (double.tryParse(value) == null) {
                            return t(context, 'Please enter a valid number');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _stockController,
                        decoration: InputDecoration(
                          labelText: t(context, 'Stock Quantity'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.inventory),
                          filled: true,
                          fillColor: Colors.blue[50],
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return t(context, 'Stock quantity is required');
                          }
                          if (int.tryParse(value) == null) {
                            return t(context, 'Please enter a valid number');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: _categories.any((cat) => cat['id'] == _selectedCategoryId) ? _selectedCategoryId : null,
                        decoration: InputDecoration(
                          labelText: t(context, 'Category'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.category),
                          filled: true,
                          fillColor: Colors.purple[50],
                          helperText: t(context, 'Select a category for this product (optional)'),
                        ),
                        items: [
                          DropdownMenuItem<int>(
                            value: null,
                            child: Text(t(context, 'Select Category')),
                          ),
                          ..._categories.map((category) {
                            return DropdownMenuItem<int>(
                              value: category['id'] as int,
                              child: Text(category['name'] as String),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCategoryId = value;
                          });
                        },

                      ),
                    ] else ...[
                      // Desktop/Tablet layout - horizontal rows
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: t(context, 'Product Name *'),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.inventory_2),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return t(context, 'Product name is required');
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _skuController,
                              decoration: InputDecoration(
                                labelText: t(context, 'SKU *'),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.qr_code),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return t(context, 'SKU is required');
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: t(context, 'Description'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.description),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              decoration: InputDecoration(
                                labelText: t(context, 'Price *'),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.attach_money),
                                filled: true,
                                fillColor: Colors.green[50],
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return t(context, 'Price is required');
                                }
                                if (double.tryParse(value) == null) {
                                  return t(context, 'Please enter a valid number');
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _costController,
                              decoration: InputDecoration(
                                labelText: t(context, 'Cost *'),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.account_balance_wallet),
                                filled: true,
                                fillColor: Colors.orange[50],
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return t(context, 'Cost is required');
                                }
                                if (double.tryParse(value) == null) {
                                  return t(context, 'Please enter a valid number');
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _stockController,
                              decoration: InputDecoration(
                                labelText: t(context, 'Stock Quantity'),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.inventory),
                                filled: true,
                                fillColor: Colors.blue[50],
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return t(context, 'Stock quantity is required');
                                }
                                if (int.tryParse(value) == null) {
                                  return t(context, 'Please enter a valid number');
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _categories.any((cat) => cat['id'] == _selectedCategoryId) ? _selectedCategoryId : null,
                              decoration: InputDecoration(
                                labelText: t(context, 'Category'),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.category),
                                filled: true,
                                fillColor: Colors.purple[50],
                              ),
                              items: [
                                DropdownMenuItem<int>(
                                  value: null,
                                  child: Text(t(context, 'Select Category')),
                                ),
                                ..._categories.map((category) {
                                  return DropdownMenuItem<int>(
                                    value: category['id'] as int,
                                    child: Text(category['name'] as String),
                                  );
                                }).toList(),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategoryId = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              t(context, 'Cancel'),
                              style: TextStyle(fontSize: isMobile ? 14 : 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: isMobile ? 16 : 20,
                                    width: isMobile ? 16 : 20,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    widget.product == null ? 'Add Product' : 'Update Product',
                                    style: TextStyle(
                                      fontSize: isMobile ? 14 : 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImagePlaceholder(bool isMobile) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: isMobile ? 16 : 20,
              color: Colors.blue[600],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.add,
              size: isMobile ? 12 : 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.photo_library,
              size: isMobile ? 16 : 20,
              color: Colors.green[600],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          t(context, 'Add Image'),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: isMobile ? 10 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t(context, 'Camera or Gallery'),
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: isMobile ? 8 : 10,
          ),
        ),
      ],
    );
  }
}

class _IncrementDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final Function(int quantity, double costPrice, String? notes) onIncrement;

  const _IncrementDialog({
    required this.item,
    required this.onIncrement,
  });

  @override
  State<_IncrementDialog> createState() => _IncrementDialogState();
}

class _IncrementDialogState extends State<_IncrementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill with current cost price if available
    final currentCostPrice = widget.item['cost_price'];
    if (currentCostPrice != null) {
      _costPriceController.text = currentCostPrice.toString();
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _costPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final quantity = int.parse(_quantityController.text.trim());
      final costPrice = double.tryParse(_costPriceController.text.trim()) ?? 0.0;
      final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
      
      await widget.onIncrement(quantity, costPrice, notes);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        SuccessUtils.showOperationError(context, 'increment stock', e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_circle, color: Colors.green[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t(context, 'Add Stock'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item['product_name'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SKU: ${widget.item['sku'] ?? ''}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current Stock: ${_safeToInt(widget.item['store_quantity'] ?? widget.item['quantity'])}',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Quantity input
            TextFormField(
              controller: _quantityController,
              decoration: InputDecoration(
                labelText: t(context, 'Quantity to Add'),
                hintText: t(context, 'Enter quantity'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.inventory),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t(context, 'Please enter quantity');
                }
                final quantity = int.tryParse(value.trim());
                if (quantity == null || quantity <= 0) {
                  return t(context, 'Please enter a valid quantity');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Cost price input
            TextFormField(
              controller: _costPriceController,
              decoration: InputDecoration(
                labelText: t(context, 'Cost Price'),
                hintText: t(context, 'Enter cost price per unit'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.attach_money),
                prefixText: '₦ ',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t(context, 'Please enter cost price');
                }
                final costPrice = double.tryParse(value.trim());
                if (costPrice == null || costPrice < 0) {
                  return t(context, 'Please enter a valid cost price');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Notes input
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: t(context, 'Notes (Optional)'),
                hintText: t(context, 'e.g., New purchase, Restock'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.note),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(t(context, 'Cancel')),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(t(context, 'Add Stock')),
        ),
      ],
    );
  }
}

class _EditCostPriceDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final Function(double costPrice) onUpdate;

  const _EditCostPriceDialog({
    required this.item,
    required this.onUpdate,
  });

  @override
  State<_EditCostPriceDialog> createState() => _EditCostPriceDialogState();
}

class _EditCostPriceDialogState extends State<_EditCostPriceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _costPriceController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with current cost price
    final currentCostPrice = widget.item['cost_price'];
    if (currentCostPrice != null) {
      _costPriceController.text = currentCostPrice.toString();
    }
  }

  @override
  void dispose() {
    _costPriceController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final costPrice = double.parse(_costPriceController.text.trim());
      await widget.onUpdate(costPrice);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        SuccessUtils.showOperationError(context, 'update cost price', e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit, color: Colors.blue[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t(context, 'Edit Cost Price'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item['product_name'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SKU: ${widget.item['sku'] ?? ''}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current Cost: ₦${(double.tryParse(widget.item['cost_price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Cost price input
            TextFormField(
              controller: _costPriceController,
              decoration: InputDecoration(
                labelText: t(context, 'New Cost Price'),
                hintText: t(context, 'Enter new cost price per unit'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.attach_money),
                prefixText: '₦ ',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t(context, 'Please enter cost price');
                }
                final costPrice = double.tryParse(value.trim());
                if (costPrice == null || costPrice < 0) {
                  return t(context, 'Please enter a valid cost price');
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(t(context, 'Cancel')),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(t(context, 'Update Cost Price')),
        ),
      ],
    );
  }
}

class _TransferDialog extends StatefulWidget {
  final int storeId;
  final String storeName;
  final List<Map<String, dynamic>> inventory;
  final List<Map<String, dynamic>> businesses;
  final ApiService apiService;
  final VoidCallback onTransfer;

  const _TransferDialog({
    required this.storeId,
    required this.storeName,
    required this.inventory,
    required this.businesses,
    required this.apiService,
    required this.onTransfer,
  });

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  int? _selectedBusinessId;
  final Map<int, int> _selectedQuantities = {};
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  
  // Filter variables for transfer dialog
  String _selectedStockStatus = '';
  String _selectedCategory = '';
  double? _minPrice;
  double? _maxPrice;

  int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  Map<String, dynamic> _reports = {};

  @override
  void initState() {
    super.initState();
    // Initialize quantities to 0 for all products
    for (var item in widget.inventory) {
      _selectedQuantities[item['product_id']] = 0;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Dialog(
      child: Container(
        width: isSmallScreen ? screenSize.width * 0.95 : screenSize.width * 0.8,
        height: isSmallScreen ? screenSize.height * 0.9 : screenSize.height * 0.8,
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.send,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Transfer Products to Business',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'From: ${widget.storeName}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Business Selection
            Text(
              'Select Business:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedBusinessId,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: widget.businesses.map((business) {
                return DropdownMenuItem<int>(
                  value: business['id'],
                  child: Text(business['name'] ?? 'Business ${business['id']}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBusinessId = value;
                });
              },
            ),
            const SizedBox(height: 24),

            // Products Selection
            Text(
              'Select Products and Quantities:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Products List
            Expanded(
              child: widget.inventory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No products available for transfer',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: widget.inventory.length,
                      itemBuilder: (context, index) {
                        final item = widget.inventory[index];
                        final productId = item['product_id'];
                        final currentQuantity = _selectedQuantities[productId] ?? 0;
                        final availableQuantity = _safeToInt(item['store_quantity']);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: isSmallScreen
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Mobile layout
                                      Row(
                                        children: [
                                          // Product Image
                                          _buildProductImage(item, isSmallScreen),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['product_name'] ?? 'Unknown Product',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'SKU: ${item['sku'] ?? 'N/A'}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Text(
                                                  'Available: $availableQuantity',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Quantity Input (full width on mobile)
                                      TextFormField(
                                        initialValue: currentQuantity.toString(),
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Quantity to Transfer',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          suffixText: 'Max: $availableQuantity',
                                        ),
                                        onChanged: (value) {
                                          final quantity = int.tryParse(value) ?? 0;
                                          if (quantity <= availableQuantity) {
                                            setState(() {
                                              _selectedQuantities[productId] = quantity;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      // Desktop layout
                                      _buildProductImage(item, isSmallScreen),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['product_name'] ?? 'Unknown Product',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'SKU: ${item['sku'] ?? 'N/A'}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              'Available: $availableQuantity',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Quantity Input
                                      SizedBox(
                                        width: 120,
                                        child: TextFormField(
                                          initialValue: currentQuantity.toString(),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'Qty',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            suffixText: 'Max: $availableQuantity',
                                          ),
                                          onChanged: (value) {
                                            final quantity = int.tryParse(value) ?? 0;
                                            if (quantity <= availableQuantity) {
                                              setState(() {
                                                _selectedQuantities[productId] = quantity;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: Text(t(context, 'Cancel')),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading || _selectedBusinessId == null || _getTotalSelectedQuantity() == 0
                      ? null
                      : _performTransfer,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(t(context, 'Transfer')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _getTotalSelectedQuantity() {
    return _selectedQuantities.values.fold(0, (sum, quantity) => sum + quantity);
  }

  Widget _buildProductImage(Map<String, dynamic> item, bool isSmallScreen) {
    final imageSize = isSmallScreen ? 60.0 : 50.0;
    
    if (item['image_url'] != null && item['image_url'].toString().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          'https://rtailed-production.up.railway.app${item['image_url']}',
          width: imageSize,
          height: imageSize,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: imageSize,
              height: imageSize,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image, color: Colors.grey),
            );
          },
        ),
      );
    } else {
      return Container(
        width: imageSize,
        height: imageSize,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image, color: Colors.grey),
      );
    }
  }

  Future<void> _performTransfer() async {
    if (_selectedBusinessId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare products for transfer
      final products = <Map<String, dynamic>>[];
      for (var entry in _selectedQuantities.entries) {
        if (entry.value > 0) {
          products.add({
            'product_id': entry.key,
            'quantity': entry.value,
          });
        }
      }

      if (products.isEmpty) {
        throw Exception('No products selected for transfer');
      }

      // Perform the transfer
      await widget.apiService.transferStoreToBusiness(
        widget.storeId,
        _selectedBusinessId!,
        products,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        SuccessUtils.showBusinessSuccess(context, 'Products transferred successfully');
        widget.onTransfer();
      }
    } catch (e) {
      if (mounted) {
        SuccessUtils.showOperationError(context, 'transfer products', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =====================================================
  // ENHANCED SEARCH AND FILTER METHODS
  // =====================================================

  Widget _buildQuickStatsRow() {
    final currentStock = _reports['current_stock']?['summary'] ?? {};
    final totalProducts = currentStock['total_products'] ?? 0;
    final totalUnits = currentStock['total_units'] ?? 0;
    final lowStock = currentStock['low_stock'] ?? 0;
    final outOfStock = currentStock['out_of_stock'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            'Total Products',
            totalProducts.toString(),
            Icons.inventory_2,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickStatCard(
            'Total Units',
            totalUnits.toString(),
            Icons.shopping_cart,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickStatCard(
            'Low Stock',
            lowStock.toString(),
            Icons.warning,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickStatCard(
            'Out of Stock',
            outOfStock.toString(),
            Icons.error,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.filter_list, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text('Filter Inventory'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stock Status Filter
              DropdownButtonFormField<String>(
                value: _selectedStockStatus,
                decoration: const InputDecoration(
                  labelText: 'Stock Status',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All Statuses')),
                  const DropdownMenuItem(value: 'IN_STOCK', child: Text('In Stock')),
                  const DropdownMenuItem(value: 'LOW_STOCK', child: Text('Low Stock')),
                  const DropdownMenuItem(value: 'OUT_OF_STOCK', child: Text('Out of Stock')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStockStatus = value ?? '';
                  });
                },
              ),
              const SizedBox(height: 16),
              // Category Filter
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All Categories')),
                  ..._getUniqueCategories().map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value ?? '';
                  });
                },
              ),
              const SizedBox(height: 16),
              // Price Range Filter
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Min Price',
                        border: OutlineInputBorder(),
                        prefixText: '₦',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _minPrice = double.tryParse(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Max Price',
                        border: OutlineInputBorder(),
                        prefixText: '₦',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _maxPrice = double.tryParse(value);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedStockStatus = '';
                _selectedCategory = '';
                _minPrice = null;
                _maxPrice = null;
              });
              Navigator.of(context).pop();
            },
            child: const Text('Clear All'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Apply filters - the filtering logic will be handled in _buildInventoryList
            },
            child: const Text('Apply Filters'),
          ),
        ],
      ),
    );
  }

  List<String> _getUniqueCategories() {
    final categories = <String>{};
    for (final item in widget.inventory) {
      final category = item['category_name'] ?? item['category'] ?? '';
      if (category.isNotEmpty) {
        categories.add(category.toString());
      }
    }
    return categories.toList()..sort();
  }
} 
