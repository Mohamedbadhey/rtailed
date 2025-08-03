import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/offline_data_service.dart';
import '../services/sync_service.dart';

class OfflineProvider with ChangeNotifier {
  final OfflineDataService _dataService = OfflineDataService();
  final SyncService _syncService = SyncService();
  
  bool _isOnline = true;
  bool _isSyncing = false;
  int _pendingSyncItems = 0;
  DateTime? _lastSyncTime;
  String _syncStatus = 'idle';
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingSyncItems => _pendingSyncItems;
  DateTime? get lastSyncTime => _lastSyncTime;
  String get syncStatus => _syncStatus;

  // Initialize the provider
  Future<void> initialize() async {
    await _dataService.initialize();
    await _setupConnectivityListener();
    await _updateSyncStatus();
  }

  // Setup connectivity listener
  Future<void> _setupConnectivityListener() async {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      _updateOnlineStatus(result != ConnectivityResult.none);
    });

    // Check initial connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    _updateOnlineStatus(connectivityResult != ConnectivityResult.none);
  }

  // Update online status
  void _updateOnlineStatus(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      notifyListeners();
      
      if (isOnline) {
        // Trigger sync when coming back online
        _triggerSync();
      }
    }
  }

  // Update sync status
  Future<void> _updateSyncStatus() async {
    try {
      final status = await _syncService.getSyncStatus();
      _isOnline = status['isOnline'] ?? false;
      _isSyncing = status['isSyncing'] ?? false;
      _pendingSyncItems = status['pendingItems'] ?? 0;
      _lastSyncTime = DateTime.tryParse(status['lastSync'] ?? '');
      
      if (_isSyncing) {
        _syncStatus = 'syncing';
      } else if (_pendingSyncItems > 0) {
        _syncStatus = 'pending';
      } else {
        _syncStatus = 'synced';
      }
      
      notifyListeners();
    } catch (e) {
      print('Error updating sync status: $e');
    }
  }

  // Trigger manual sync
  Future<void> triggerManualSync() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    _syncStatus = 'syncing';
    notifyListeners();

    try {
      await _syncService.manualSync();
      await _updateSyncStatus();
    } catch (e) {
      print('Manual sync failed: $e');
      _syncStatus = 'error';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Trigger automatic sync
  Future<void> _triggerSync() async {
    if (_isSyncing || !_isOnline) return;
    
    _isSyncing = true;
    _syncStatus = 'syncing';
    notifyListeners();

    try {
      await _syncService.syncData();
      await _updateSyncStatus();
    } catch (e) {
      print('Auto sync failed: $e');
      _syncStatus = 'error';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Get sync status message
  String getSyncStatusMessage() {
    if (!_isOnline) {
      return 'Offline - Working with local data';
    }
    
    switch (_syncStatus) {
      case 'syncing':
        return 'Syncing data...';
      case 'pending':
        return '$_pendingSyncItems items pending sync';
      case 'synced':
        return 'All data synced';
      case 'error':
        return 'Sync error occurred';
      default:
        return 'Checking sync status...';
    }
  }

  // Get connection status message
  String getConnectionStatusMessage() {
    if (_isOnline) {
      return 'Connected to server';
    } else {
      return 'Working offline';
    }
  }

  // Check if data is available offline
  Future<bool> isDataAvailableOffline() async {
    try {
      // Check if we have any local data
      final products = await _dataService.getProducts();
      final customers = await _dataService.getCustomers();
      final sales = await _dataService.getSales();
      
      return products.isNotEmpty || customers.isNotEmpty || sales.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get offline data summary
  Future<Map<String, int>> getOfflineDataSummary() async {
    try {
      final products = await _dataService.getProducts();
      final customers = await _dataService.getCustomers();
      final sales = await _dataService.getSales();
      
      return {
        'products': products.length,
        'customers': customers.length,
        'sales': sales.length,
      };
    } catch (e) {
      return {
        'products': 0,
        'customers': 0,
        'sales': 0,
      };
    }
  }

  // Clear offline data
  Future<void> clearOfflineData() async {
    try {
      await _dataService.clearLocalData();
      await _updateSyncStatus();
    } catch (e) {
      print('Error clearing offline data: $e');
    }
  }

  // Refresh sync status
  Future<void> refreshSyncStatus() async {
    await _updateSyncStatus();
  }

  // Dispose resources
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
} 