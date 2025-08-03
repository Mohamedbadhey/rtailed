# Offline Functionality Guide

## Overview

Your retail management app now supports full offline functionality, allowing businesses to operate without internet connectivity and automatically sync data when the connection is restored.

## 🚀 Key Features

### ✅ Offline-First Architecture
- **Local SQLite Database**: All data is stored locally on the device
- **Automatic Sync**: Data syncs automatically when internet connection is restored
- **Queue System**: Pending operations are queued and processed when online
- **Conflict Resolution**: Handles data conflicts during synchronization

### ✅ Business Isolation
- Each business's data is isolated in the local database
- Multi-tenant support with business-specific sync queues
- Secure data separation between different businesses

### ✅ Real-time Status
- Visual indicators for connection status
- Sync progress tracking
- Pending operations counter
- Last sync timestamp

## 📱 How It Works

### 1. **Offline Mode**
When there's no internet connection:
- App continues to work normally
- All CRUD operations are performed on local SQLite database
- Changes are queued for sync when connection is restored
- Users see "Working offline" status

### 2. **Online Mode**
When internet connection is available:
- App attempts to sync with server first
- Falls back to local data if server is unavailable
- Automatic sync every 30 seconds
- Manual sync option available

### 3. **Sync Process**
- **Bidirectional Sync**: Local → Server and Server → Local
- **Conflict Resolution**: Uses timestamps and data hashing
- **Retry Logic**: Failed syncs are retried up to 3 times
- **Queue Management**: Pending operations are processed in order

## 🛠️ Technical Implementation

### Database Schema

The local SQLite database includes these tables:

```sql
-- Core business tables
products (id, server_id, name, description, price, cost, quantity, category_id, business_id, sync_status, last_sync)
customers (id, server_id, name, email, phone, address, business_id, sync_status, last_sync)
sales (id, server_id, customer_id, total_amount, payment_method, business_id, sync_status, last_sync)
categories (id, server_id, name, description, business_id, sync_status, last_sync)

-- Sync management
sync_queue (id, table_name, operation, local_id, server_id, data, business_id, status, retry_count)

-- Business management
businesses (id, server_id, name, description, owner_id, is_active, sync_status, last_sync)
```

### Key Components

#### 1. **OfflineDatabase** (`lib/services/offline_database.dart`)
- Manages local SQLite database
- Handles CRUD operations
- Manages sync queue
- Provides data integrity functions

#### 2. **SyncService** (`lib/services/sync_service.dart`)
- Handles data synchronization
- Manages connectivity monitoring
- Processes sync queue
- Handles conflict resolution

#### 3. **OfflineDataService** (`lib/services/offline_data_service.dart`)
- Provides offline-first data operations
- Combines online and offline functionality
- Handles automatic fallback

#### 4. **OfflineProvider** (`lib/providers/offline_provider.dart`)
- Manages offline state
- Provides UI with sync status
- Handles connectivity changes

## 🎯 Usage Examples

### Creating a Product (Offline)
```dart
final product = Product(
  name: 'New Product',
  price: 29.99,
  cost: 15.00,
  quantity: 50,
  businessId: 1,
);

final createdProduct = await offlineDataService.createProduct(product);
// Product is saved locally and queued for sync
```

### Getting Products (Works Online/Offline)
```dart
final products = await offlineDataService.getProducts(businessId: 1);
// Returns products from local database if offline, or from server if online
```

### Manual Sync
```dart
await offlineProvider.triggerManualSync();
// Immediately syncs all pending changes
```

## 📊 UI Components

### 1. **OfflineStatusBar**
- Shows at the top of the app
- Displays connection status
- Shows sync progress
- Provides manual sync button

### 2. **OfflineStatusWidget**
- Detailed status card
- Shows pending items count
- Displays last sync time
- Connection quality indicator

### 3. **OfflineSettingsScreen**
- Complete offline management
- Sync controls
- Data summary
- Clear offline data option

## 🔧 Configuration

### Sync Settings
- **Auto-sync interval**: 30 seconds (configurable)
- **Max retry attempts**: 3 (configurable)
- **Sync timeout**: 30 seconds (configurable)

### Business Isolation
- Each business has its own sync queue
- Data is filtered by `business_id`
- Separate offline databases per business

## 🧪 Testing

### Test File
Run the offline functionality test:
```bash
flutter run test_offline_functionality.dart
```

### Test Coverage
- Database initialization
- Offline CRUD operations
- Sync queue functionality
- Data integrity checks
- Conflict resolution

## 📈 Performance Considerations

### Storage
- SQLite database is lightweight
- Automatic cleanup of completed sync items
- Indexed queries for fast performance

### Memory
- Efficient data caching
- Minimal memory footprint
- Automatic garbage collection

### Battery
- Smart sync intervals
- Background sync optimization
- Connectivity-aware operations

## 🔒 Security Features

### Data Protection
- Local data encryption (if enabled)
- Secure token storage
- Business data isolation

### Sync Security
- JWT token authentication
- HTTPS communication
- Data validation

## 🚨 Troubleshooting

### Common Issues

#### 1. **Sync Not Working**
- Check internet connection
- Verify server is running
- Check authentication token
- Review sync queue status

#### 2. **Data Not Appearing**
- Check if data is in local database
- Verify business ID filtering
- Check sync status
- Review error logs

#### 3. **Performance Issues**
- Clear old sync queue items
- Check database size
- Review sync frequency
- Monitor memory usage

### Debug Information
- Sync status is displayed in UI
- Error messages are logged
- Test screen provides detailed diagnostics
- Connection status is monitored

## 🔄 Migration Guide

### From Online-Only to Offline-First

1. **Install Dependencies**
   ```yaml
   dependencies:
     sqflite: ^2.3.0
     path: ^1.8.3
     uuid: ^4.0.0
     crypto: ^3.0.3
   ```

2. **Initialize Offline Provider**
   ```dart
   // In main.dart
   ChangeNotifierProvider(create: (_) => OfflineProvider()),
   ```

3. **Update Data Services**
   - Replace direct API calls with OfflineDataService
   - Add offline fallback logic
   - Implement sync queue management

4. **Add UI Components**
   - Include OfflineStatusBar in main screens
   - Add offline settings to settings screen
   - Display sync status indicators

## 📱 Platform Support

### Web
- Uses IndexedDB for local storage
- Full offline functionality
- Automatic sync when online

### Mobile (iOS/Android)
- Uses SQLite database
- Native performance
- Background sync support

### Desktop
- Cross-platform compatibility
- File-based storage
- Enhanced sync capabilities

## 🎉 Benefits

### For Businesses
- **Uninterrupted Operations**: Work without internet
- **Data Safety**: Local backup of all data
- **Fast Performance**: No network delays
- **Cost Savings**: Reduced data usage

### For Users
- **Seamless Experience**: Works online and offline
- **Real-time Status**: Know when data is syncing
- **Manual Control**: Trigger sync when needed
- **Data Visibility**: See what's stored locally

## 🔮 Future Enhancements

### Planned Features
- **Selective Sync**: Choose what data to sync
- **Sync Scheduling**: Custom sync intervals
- **Data Compression**: Reduce storage usage
- **Advanced Conflict Resolution**: Better merge strategies
- **Offline Analytics**: Local reporting capabilities

### Performance Improvements
- **Incremental Sync**: Only sync changed data
- **Background Processing**: Non-blocking sync
- **Smart Caching**: Predictive data loading
- **Optimized Queries**: Better database performance

---

## 📞 Support

For questions or issues with offline functionality:
1. Check the test screen for diagnostics
2. Review sync status in settings
3. Check connection logs
4. Verify database integrity

The offline functionality is designed to be robust and user-friendly, providing a seamless experience regardless of internet connectivity. 