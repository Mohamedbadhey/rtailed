import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/widgets/branded_app_bar.dart';
import 'package:retail_management/services/api_service.dart';

class SuperadminDashboardResponsive extends StatefulWidget {
  const SuperadminDashboardResponsive({Key? key}) : super(key: key);

  @override
  State<SuperadminDashboardResponsive> createState() => _SuperadminDashboardResponsiveState();
}

class _SuperadminDashboardResponsiveState extends State<SuperadminDashboardResponsive>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadDashboardData() {
    setState(() {
      _isLoading = true;
    });
    
    // Simulate loading
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            const SizedBox(width: 8),
            Text(t(context, 'Logout')),
          ],
        ),
        content: Text(t(context, 'Are you sure you want to logout?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t(context, 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(t(context, 'Logout')),
          ),
        ],
      ),
    );
  }

  void _performLogout() async {
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.logout();
      
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(context, 'Logged out successfully')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t(context, 'Logout error: ')}$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showProfileDialog() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person),
            const SizedBox(width: 8),
            Text(t(context, 'Profile')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileInfo('Username', user.username),
              _buildProfileInfo('Email', user.email),
              _buildProfileInfo('Role', user.role.toUpperCase()),
              _buildProfileInfo('Business ID', user.businessId?.toString() ?? 'System Admin'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t(context, 'Close')),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLogoutButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Superadmin Controls',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                onPressed: _loadDashboardData,
                tooltip: t(context, 'Refresh'),
              ),
              IconButton(
                icon: const Icon(Icons.person, size: 16),
                onPressed: _showProfileDialog,
                tooltip: t(context, 'Profile'),
              ),
              IconButton(
                icon: const Icon(Icons.logout, size: 16, color: Colors.red),
                onPressed: _showLogoutDialog,
                tooltip: t(context, 'Logout'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTabBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(32),
      child: Container(
        height: 32,
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Theme.of(context).primaryColor,
          labelPadding: const EdgeInsets.symmetric(horizontal: 2),
          labelStyle: const TextStyle(fontSize: 8),
          unselectedLabelStyle: const TextStyle(fontSize: 8),
          tabs: [
            Tab(icon: Icon(Icons.dashboard, size: 12), text: 'Overview'),
            Tab(icon: Icon(Icons.business, size: 12), text: 'Businesses'),
            Tab(icon: Icon(Icons.people, size: 12), text: 'Users'),
            Tab(icon: Icon(Icons.analytics, size: 12), text: 'Analytics'),
            Tab(icon: Icon(Icons.settings, size: 12), text: 'Settings'),
            Tab(icon: Icon(Icons.storage, size: 12), text: 'Data'),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: Theme.of(context).primaryColor,
      unselectedLabelColor: Colors.grey[600],
      indicatorColor: Theme.of(context).primaryColor,
      tabs: [
        Tab(icon: Icon(Icons.dashboard), text: t(context, 'Overview')),
        Tab(icon: Icon(Icons.business), text: t(context, 'Businesses')),
        Tab(icon: Icon(Icons.people), text: t(context, 'Users & Security')),
        Tab(icon: Icon(Icons.analytics), text: t(context, 'Analytics')),
        Tab(icon: Icon(Icons.settings), text: t(context, 'Settings')),
        Tab(icon: Icon(Icons.storage), text: t(context, 'Data Management')),
      ],
    );
  }

  Widget _buildOverviewContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Overview',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to Superadmin Dashboard',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Manage your entire system from here.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessesContent() {
    print('🔄 DEBUG: _buildBusinessesContent called');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business Management',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          
          // Business List Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.business, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Manage Businesses',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: _loadBusinesses,
                        icon: Icon(Icons.refresh),
                        tooltip: 'Refresh Business List',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Create, edit, and manage business accounts.'),
                  const SizedBox(height: 16),
                  
                  // Business List
                  print('🔄 DEBUG: About to render _BusinessListWidget'),
                  Text('🔄 DEBUG: Business List Widget should appear below this text', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _BusinessListWidget(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersAndSecurityContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Users & Security',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Management',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Manage user accounts and security settings.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analytics',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Analytics',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('View system-wide analytics and reports.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Configure system-wide settings and preferences.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataManagementContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data Management',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Operations',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Manage data backup, recovery, and export operations.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isVerySmall = screenWidth < 400;
    
    return Scaffold(
      appBar: BrandedAppBar(
        title: t(context, 'Superadmin Dashboard'),
        bottom: isMobile ? _buildMobileTabBar() : _buildDesktopTabBar(),
        actions: isVerySmall ? null : [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: t(context, 'Refresh'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            tooltip: t(context, 'Account'),
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutDialog();
              } else if (value == 'profile') {
                _showProfileDialog();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person),
                    const SizedBox(width: 8),
                    Text(t(context, 'Profile')),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Mobile logout button for very small screens
                  if (isVerySmall) _buildMobileLogoutButton(),
                  // Main content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewContent(),
                        _buildBusinessesContent(),
                        _buildUsersAndSecurityContent(),
                        _buildAnalyticsContent(),
                        _buildSettingsContent(),
                        _buildDataManagementContent(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Business List Widget
class _BusinessListWidget extends StatefulWidget {
  @override
  State<_BusinessListWidget> createState() => _BusinessListWidgetState();
}

class _BusinessListWidgetState extends State<_BusinessListWidget> {
  List<Map<String, dynamic>> _businesses = [];
  bool _isLoading = true;
  String? _error;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    print('🔄 DEBUG: _BusinessListWidget initState called');
    print('🔄 DEBUG: About to call _loadBusinesses()');
    _loadBusinesses();
  }

  Future<void> _loadBusinesses() async {
    try {
      print('🔄 DEBUG: Starting to load businesses...');
      setState(() {
        _isLoading = true;
        _error = null;
      });

      print('🔄 DEBUG: Calling _apiService.getBusinesses()...');
      final result = await _apiService.getBusinesses();
      print('🔄 DEBUG: API response received: ${result.toString()}');
      
      final businesses = List<Map<String, dynamic>>.from(result['businesses'] ?? []);
      print('🔄 DEBUG: Parsed businesses list: ${businesses.length} businesses found');
      
      if (businesses.isNotEmpty) {
        print('🔄 DEBUG: First business data: ${businesses.first}');
      }
      
      // Load backup information for each business
      print('🔄 DEBUG: Starting to load backup information for ${businesses.length} businesses...');
      for (int i = 0; i < businesses.length; i++) {
        try {
          print('🔄 DEBUG: Loading backups for business ${i + 1}/${businesses.length}: ID=${businesses[i]['id']}, Name=${businesses[i]['name']}');
          final backups = await _apiService.getBusinessBackups(businesses[i]['id']);
          print('🔄 DEBUG: Business ${businesses[i]['id']} has ${backups.length} backups');
          
          if (backups.isNotEmpty) {
            // Get the most recent backup
            final recentBackup = backups.first;
            businesses[i]['recent_backup_id'] = recentBackup['id'];
            businesses[i]['recent_backup_name'] = `Backup ${recentBackup['id']} (${recentBackup['backup_type']})`;
            businesses[i]['recent_backup_date'] = recentBackup['backup_date'];
            businesses[i]['backup_count'] = backups.length;
            print('🔄 DEBUG: Added backup info to business ${businesses[i]['id']}: backup_id=${recentBackup['id']}, backup_type=${recentBackup['backup_type']}');
          } else {
            print('🔄 DEBUG: No backups found for business ${businesses[i]['id']}');
          }
        } catch (e) {
          print('❌ DEBUG: Error loading backups for business ${businesses[i]['id']}: $e');
        }
      }
      
      print('🔄 DEBUG: Final businesses data with backups: ${businesses.map((b) => {'id': b['id'], 'name': b['name'], 'backup_count': b['backup_count'], 'recent_backup_id': b['recent_backup_id']}).toList()}');
      
      setState(() {
        _businesses = businesses;
        _isLoading = false;
      });
      print('🔄 DEBUG: State updated with ${_businesses.length} businesses');
    } catch (e) {
      print('❌ DEBUG: Error in _loadBusinesses: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _resetBusinessData(int businessId, String businessName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Reset Business Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reset all data for business:'),
            const SizedBox(height: 8),
            Text(
              businessName,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 16),
            Text(
              'This will DELETE:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('• All products and inventory'),
            Text('• All sales and transactions'),
            Text('• All customers and categories'),
            Text('• All reports and analytics'),
            Text('• All notifications and messages'),
            const SizedBox(height: 8),
            Text(
              'This will KEEP:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 8),
            Text('• All user accounts'),
            Text('• Business settings and configuration'),
            const SizedBox(height: 16),
            Text(
              '🛡️ AUTOMATIC BACKUP: A complete backup will be created before deletion',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '🔄 ROLLBACK AVAILABLE: You can restore all data from the backup if needed',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              '⚠️ This action cannot be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Reset Business Data'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final result = await _apiService.resetBusinessData(businessId);
      
      if (mounted) {
        // Show success message with backup info
        final backupInfo = result['backup'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Business data reset successfully!'),
                if (backupInfo != null)
                  Text(
                    'Backup created: ${backupInfo['name']}',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        
        // Reload businesses to show updated stats
        await _loadBusinesses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset business data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restoreBusinessData(int businessId, String businessName, int backupId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.restore, color: Colors.green),
            const SizedBox(width: 8),
            Text('Restore Business Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to restore all data for business:'),
            const SizedBox(height: 8),
            Text(
              businessName,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 8),
            Text('from backup ID: $backupId?'),
            const SizedBox(height: 16),
            Text(
              'This will RESTORE:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('• All products and inventory'),
            Text('• All sales and transactions'),
            Text('• All customers and categories'),
            Text('• All reports and analytics'),
            Text('• All notifications and messages'),
            const SizedBox(height: 16),
            Text(
              '⚠️ This will overwrite any current data!',
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Restore Business Data'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final result = await _apiService.restoreBusinessData(businessId, backupId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Business data restored successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload businesses to show updated stats
        await _loadBusinesses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore business data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔄 DEBUG: Building _BusinessListWidget with ${_businesses.length} businesses');
    print('🔄 DEBUG: _isLoading: $_isLoading, _error: $_error');
    
    if (_isLoading) {
      print('🔄 DEBUG: Showing loading indicator');
      return Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      print('❌ DEBUG: Showing error: $_error');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Error loading businesses: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBusinesses,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_businesses.isEmpty) {
      print('🔄 DEBUG: No businesses found, showing empty state');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, color: Colors.grey, size: 48),
            const SizedBox(height: 16),
            Text('No businesses found'),
          ],
        ),
      );
    }

    print('🔄 DEBUG: Rendering business list with ${_businesses.length} businesses');
    return Column(
      children: [
        // Debug text to show widget is rendering
        Container(
          padding: EdgeInsets.all(8),
          color: Colors.yellow,
          child: Text(
            '🔄 DEBUG: _BusinessListWidget is rendering! Businesses: ${_businesses.length}',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ),
        const SizedBox(height: 8),
        // Business List
        ..._businesses.map((business) {
          print('🔄 DEBUG: Rendering business card: ID=${business['id']}, Name=${business['name']}, backup_count=${business['backup_count']}, recent_backup_id=${business['recent_backup_id']}');
          return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            business['name'] ?? 'Unknown Business',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Code: ${business['business_code'] ?? 'N/A'}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          Text(
                            'Email: ${business['email'] ?? 'N/A'}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: business['is_active'] == 1 ? Colors.green[100] : Colors.red[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            business['is_active'] == 1 ? 'Active' : 'Inactive',
                            style: TextStyle(
                              color: business['is_active'] == 1 ? Colors.green[700] : Colors.red[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Business Statistics
                Row(
                  children: [
                    _buildStatCard('Users', business['user_count']?.toString() ?? '0', Icons.people, Colors.blue),
                    const SizedBox(width: 12),
                    _buildStatCard('Products', business['product_count']?.toString() ?? '0', Icons.inventory, Colors.green),
                    const SizedBox(width: 12),
                    _buildStatCard('Customers', business['customer_count']?.toString() ?? '0', Icons.person, Colors.orange),
                    const SizedBox(width: 12),
                    _buildStatCard('Sales', business['sale_count']?.toString() ?? '0', Icons.shopping_cart, Colors.purple),
                  ],
                ),
                
                // Backup Information (if available)
                if (business['backup_count'] != null && business['backup_count'] > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.backup, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Backup Available',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                              Text(
                                '${business['backup_count']} backup(s) available',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[600],
                                ),
                              ),
                              if (business['recent_backup_name'] != null)
                                Text(
                                  'Latest: ${business['recent_backup_name']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[600],
                                  ),
                                ),
                            ],
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
                        onPressed: () => _resetBusinessData(
                          business['id'],
                          business['name'] ?? 'Unknown Business',
                        ),
                        icon: Icon(Icons.refresh, size: 16),
                        label: Text('Reset Data'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Implement edit business functionality
                        },
                        icon: Icon(Icons.edit, size: 16),
                        label: Text('Edit'),
                      ),
                    ),
                  ],
                ),
                
                // Show restore option if business has recent backups
                if (business['recent_backup_id'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _restoreBusinessData(
                        business['id'],
                        business['name'] ?? 'Unknown Business',
                        business['recent_backup_id'],
                      ),
                      icon: Icon(Icons.restore, size: 16),
                      label: Text('🔄 Restore from Backup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 