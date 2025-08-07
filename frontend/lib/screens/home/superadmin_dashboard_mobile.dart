import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/utils/type_converter.dart';
import 'package:retail_management/widgets/branded_app_bar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SuperadminDashboardMobile extends StatefulWidget {
  const SuperadminDashboardMobile({super.key});

  @override
  State<SuperadminDashboardMobile> createState() => _SuperadminDashboardMobileState();
}

class _SuperadminDashboardMobileState extends State<SuperadminDashboardMobile> 
    with TickerProviderStateMixin {
  late TabController _mainTabController;
  late TabController _overviewTabController;
  late TabController _businessesTabController;
  late TabController _usersTabController;
  late TabController _analyticsTabController;
  late TabController _settingsTabController;
  late TabController _dataTabController;
  
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  List<Map<String, dynamic>> _allBusinesses = [];
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allPayments = [];
  List<Map<String, dynamic>> _allMessages = [];
  List<Map<String, dynamic>> _recentLogs = [];
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _auditLogs = [];

  // Revenue tracking
  DateTime _revenueStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _revenueEndDate = DateTime.now();
  String _selectedRevenuePeriod = '30_days';

  @override
  void initState() {
    super.initState();
    
    // Initialize main tab controller with 6 tabs
    _mainTabController = TabController(length: 6, vsync: this);
    
    // Initialize sub-tab controllers
    _overviewTabController = TabController(length: 3, vsync: this);
    _businessesTabController = TabController(length: 4, vsync: this);
    _usersTabController = TabController(length: 3, vsync: this);
    _analyticsTabController = TabController(length: 3, vsync: this);
    _settingsTabController = TabController(length: 4, vsync: this);
    _dataTabController = TabController(length: 3, vsync: this);
    
    // Load data after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
      _setupPeriodicRefresh();
    });
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _overviewTabController.dispose();
    _businessesTabController.dispose();
    _usersTabController.dispose();
    _analyticsTabController.dispose();
    _settingsTabController.dispose();
    _dataTabController.dispose();
    super.dispose();
  }

  void _setupPeriodicRefresh() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadDashboardData();
        _setupPeriodicRefresh();
      }
    });
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;

      // Load all data in parallel
      if (token != null) {
        await Future.wait([
          _loadBusinesses(token),
          _loadUsers(token),
          _loadPayments(token),
          _loadMessages(token),
          _loadNotifications(token),
          _loadAuditLogs(token),
        ]);
      }

    } catch (e) {
      print('Error loading dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBusinesses(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/businesses'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = TypeConverter.safeToMap(json.decode(response.body));
        final businesses = data['businesses'] ?? [];
        _allBusinesses = TypeConverter.convertMySQLList(businesses);
      }
    } catch (e) {
      print('Error loading businesses: $e');
    }
  }

  Future<void> _loadUsers(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/users'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = TypeConverter.safeToMap(json.decode(response.body));
        final users = data['users'] ?? [];
        _allUsers = TypeConverter.convertMySQLList(users);
      }
    } catch (e) {
      print('Error loading users: $e');
    }
  }

  Future<void> _loadPayments(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/payments'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = TypeConverter.safeToMap(json.decode(response.body));
        final payments = data['payments'] ?? [];
        _allPayments = TypeConverter.convertMySQLList(payments);
      }
    } catch (e) {
      print('Error loading payments: $e');
    }
  }

  Future<void> _loadMessages(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/messages'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = TypeConverter.safeToMap(json.decode(response.body));
        final messages = data['messages'] ?? [];
        _allMessages = TypeConverter.convertMySQLList(messages);
      }
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  Future<void> _loadNotifications(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/notifications'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = TypeConverter.safeToMap(json.decode(response.body));
        final notifications = data['notifications'] ?? [];
        _notifications = TypeConverter.convertMySQLList(notifications);
      }
    } catch (e) {
      print('Error loading notifications: $e');
    }
  }

  Future<void> _loadAuditLogs(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/audit-logs'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = TypeConverter.safeToMap(json.decode(response.body));
        final logs = data['logs'] ?? [];
        _auditLogs = TypeConverter.convertMySQLList(logs);
      }
    } catch (e) {
      print('Error loading audit logs: $e');
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthProvider>().logout();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile'),
        content: const Text('Profile settings will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTiny = screenWidth < 320;
    final isExtraSmall = screenWidth < 360;
    final isVerySmall = screenWidth < 480;
    
    return Scaffold(
      appBar: BrandedAppBar(
        title: isTiny ? 'Admin' : (isVerySmall ? 'Superadmin' : t(context, 'Superadmin Dashboard')),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(isTiny ? 44 : 52),
          child: Container(
            height: isTiny ? 44 : 52,
            child: TabBar(
              controller: _mainTabController,
              isScrollable: true,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Theme.of(context).primaryColor,
              labelPadding: EdgeInsets.symmetric(horizontal: isTiny ? 6 : (isExtraSmall ? 8 : 10)),
              labelStyle: TextStyle(
                fontSize: isTiny ? 9 : (isExtraSmall ? 11 : 13), 
                fontWeight: FontWeight.w500
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: isTiny ? 9 : (isExtraSmall ? 11 : 13)
              ),
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(
                  icon: Icon(Icons.dashboard, size: isTiny ? 16 : (isExtraSmall ? 18 : 20)), 
                  text: isTiny ? 'Overview' : 'Overview'
                ),
                Tab(
                  icon: Icon(Icons.business, size: isTiny ? 16 : (isExtraSmall ? 18 : 20)), 
                  text: isTiny ? 'Biz' : 'Businesses'
                ),
                Tab(
                  icon: Icon(Icons.people, size: isTiny ? 16 : (isExtraSmall ? 18 : 20)), 
                  text: isTiny ? 'Users' : 'Users'
                ),
                Tab(
                  icon: Icon(Icons.analytics, size: isTiny ? 16 : (isExtraSmall ? 18 : 20)), 
                  text: isTiny ? 'Analytics' : 'Analytics'
                ),
                Tab(
                  icon: Icon(Icons.settings, size: isTiny ? 16 : (isExtraSmall ? 18 : 20)), 
                  text: isTiny ? 'Settings' : 'Settings'
                ),
                Tab(
                  icon: Icon(Icons.storage, size: isTiny ? 16 : (isExtraSmall ? 18 : 20)), 
                  text: isTiny ? 'Data' : 'Data'
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (!isTiny) IconButton(
            icon: Icon(Icons.refresh, size: isTiny ? 18 : 24),
            onPressed: _loadDashboardData,
            tooltip: t(context, 'Refresh'),
            padding: EdgeInsets.all(isTiny ? 6 : 8),
            constraints: BoxConstraints(
              minWidth: isTiny ? 36 : 44,
              minHeight: isTiny ? 36 : 44,
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.account_circle, color: Colors.white, size: isTiny ? 22 : 24),
            tooltip: t(context, 'Account'),
            padding: EdgeInsets.all(isTiny ? 6 : 8),
            constraints: BoxConstraints(
              minWidth: isTiny ? 36 : 44,
              minHeight: isTiny ? 36 : 44,
            ),
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
                    Icon(Icons.person, size: isTiny ? 16 : 20),
                    SizedBox(width: isTiny ? 6 : 8),
                    Text(t(context, 'Profile'), style: TextStyle(fontSize: isTiny ? 12 : 14)),
                  ],
                ),
              ),
              PopupMenuItem(
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
              child: TabBarView(
                controller: _mainTabController,
                children: [
                  _buildOverviewTab(isTiny, isExtraSmall, isVerySmall),
                  _buildBusinessesTab(isTiny, isExtraSmall, isVerySmall),
                  _buildUsersTab(isTiny, isExtraSmall, isVerySmall),
                  _buildAnalyticsTab(isTiny, isExtraSmall, isVerySmall),
                  _buildSettingsTab(isTiny, isExtraSmall, isVerySmall),
                  _buildDataTab(isTiny, isExtraSmall, isVerySmall),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return Column(
      children: [
        // Sub-tab bar for Overview
        Container(
          height: isTiny ? 40 : 48,
          child: TabBar(
            controller: _overviewTabController,
            isScrollable: true,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Theme.of(context).primaryColor,
            labelPadding: EdgeInsets.symmetric(horizontal: isTiny ? 8 : 12),
            labelStyle: TextStyle(
              fontSize: isTiny ? 10 : (isExtraSmall ? 12 : 14),
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              Tab(
                icon: Icon(Icons.monitor_heart, size: isTiny ? 16 : 18),
                text: isTiny ? 'Health' : 'System Health',
              ),
              Tab(
                icon: Icon(Icons.notifications, size: isTiny ? 16 : 18),
                text: isTiny ? 'Alerts' : 'Notifications',
              ),
              Tab(
                icon: Icon(Icons.payment, size: isTiny ? 16 : 18),
                text: isTiny ? 'Billing' : 'Billing',
              ),
            ],
          ),
        ),
        // Sub-tab content
        Expanded(
          child: TabBarView(
            controller: _overviewTabController,
            children: [
              _buildSystemHealthSubTab(isTiny, isExtraSmall, isVerySmall),
              _buildNotificationsSubTab(isTiny, isExtraSmall, isVerySmall),
              _buildBillingSubTab(isTiny, isExtraSmall, isVerySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSystemHealthSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System Status Card
          _buildMobileCard(
            title: 'System Status',
            icon: Icons.check_circle,
            color: Colors.green,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusRow('Database', 'Online', Colors.green, isTiny),
                _buildStatusRow('API Server', 'Online', Colors.green, isTiny),
                _buildStatusRow('File Storage', 'Online', Colors.green, isTiny),
                _buildStatusRow('Email Service', 'Online', Colors.green, isTiny),
              ],
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          
          // Quick Stats Card
          _buildMobileCard(
            title: 'Quick Stats',
            icon: Icons.analytics,
            color: Colors.blue,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildStatRow('Total Businesses', _allBusinesses.length.toString(), isTiny),
                _buildStatRow('Active Users', _allUsers.length.toString(), isTiny),
                _buildStatRow('Total Revenue', '\$${_calculateTotalRevenue()}', isTiny),
                _buildStatRow('Pending Payments', _allPayments.where((p) => p['status'] == 'pending').length.toString(), isTiny),
              ],
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          
          // Recent Activity Card
          _buildMobileCard(
            title: 'Recent Activity',
            icon: Icons.history,
            color: Colors.orange,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: _buildRecentActivityItems(isTiny),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notifications Header
          Row(
            children: [
              Icon(Icons.notifications, color: Theme.of(context).primaryColor),
              SizedBox(width: isTiny ? 4 : 8),
              Text(
                'System Notifications',
                style: TextStyle(
                  fontSize: isTiny ? 14 : (isExtraSmall ? 16 : 18),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          
          // Notifications List
          ..._notifications.map((notification) => _buildNotificationCard(
            notification,
            isTiny,
            isExtraSmall,
          )).toList(),
          
          if (_notifications.isEmpty)
            _buildEmptyStateCard(
              'No notifications',
              'All systems are running smoothly',
              Icons.check_circle,
              Colors.green,
              isTiny,
              isExtraSmall,
            ),
        ],
      ),
    );
  }

  Widget _buildBillingSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenue Summary Card
          _buildMobileCard(
            title: 'Revenue Summary',
            icon: Icons.attach_money,
            color: Colors.green,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildStatRow('This Month', '\$${_calculateMonthlyRevenue()}', isTiny),
                _buildStatRow('Last Month', '\$${_calculateLastMonthRevenue()}', isTiny),
                _buildStatRow('Total Revenue', '\$${_calculateTotalRevenue()}', isTiny),
              ],
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          
          // Recent Payments Card
          _buildMobileCard(
            title: 'Recent Payments',
            icon: Icons.payment,
            color: Colors.blue,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: _buildRecentPaymentsList(isTiny, isExtraSmall),
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          
          // Pending Payments Card
          _buildMobileCard(
            title: 'Pending Payments',
            icon: Icons.schedule,
            color: Colors.orange,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: _buildPendingPaymentsList(isTiny, isExtraSmall),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessesTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return Column(
      children: [
        // Sub-tab bar for Businesses
        Container(
          height: isTiny ? 40 : 48,
          child: TabBar(
            controller: _businessesTabController,
            isScrollable: true,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Theme.of(context).primaryColor,
            labelPadding: EdgeInsets.symmetric(horizontal: isTiny ? 8 : 12),
            labelStyle: TextStyle(
              fontSize: isTiny ? 10 : (isExtraSmall ? 12 : 14),
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              Tab(
                icon: Icon(Icons.business, size: isTiny ? 16 : 18),
                text: isTiny ? 'All' : 'All Businesses',
              ),
              Tab(
                icon: Icon(Icons.message, size: isTiny ? 16 : 18),
                text: isTiny ? 'Messages' : 'Messages',
              ),
              Tab(
                icon: Icon(Icons.payment, size: isTiny ? 16 : 18),
                text: isTiny ? 'Payments' : 'Payments',
              ),
              Tab(
                icon: Icon(Icons.analytics, size: isTiny ? 16 : 18),
                text: isTiny ? 'Analytics' : 'Analytics',
              ),
            ],
          ),
        ),
        // Sub-tab content
        Expanded(
          child: TabBarView(
            controller: _businessesTabController,
            children: [
              _buildAllBusinessesSubTab(isTiny, isExtraSmall, isVerySmall),
              _buildBusinessMessagesSubTab(isTiny, isExtraSmall, isVerySmall),
              _buildBusinessPaymentsSubTab(isTiny, isExtraSmall, isVerySmall),
              _buildBusinessAnalyticsSubTab(isTiny, isExtraSmall, isVerySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAllBusinessesSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Add Business button
          Row(
            children: [
              Expanded(
                child: Text(
                  'All Businesses',
                  style: TextStyle(
                    fontSize: isTiny ? 16 : (isExtraSmall ? 18 : 20),
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddBusinessDialog(),
                icon: Icon(Icons.add, size: isTiny ? 16 : 18),
                label: Text(isTiny ? 'Add' : 'Add Business'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTiny ? 8 : 12,
                    vertical: isTiny ? 6 : 8,
                  ),
                  textStyle: TextStyle(fontSize: isTiny ? 12 : 14),
                ),
              ),
            ],
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          
          // Business Stats Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total',
                  _allBusinesses.length.toString(),
                  Icons.business,
                  Colors.blue,
                  isTiny,
                ),
              ),
              SizedBox(width: isTiny ? 4 : 8),
              Expanded(
                child: _buildStatCard(
                  'Active',
                  _allBusinesses.where((b) => b['is_active'] == true || b['is_active'] == 1).length.toString(),
                  Icons.check_circle,
                  Colors.green,
                  isTiny,
                ),
              ),
              SizedBox(width: isTiny ? 4 : 8),
              Expanded(
                child: _buildStatCard(
                  'Inactive',
                  _allBusinesses.where((b) => b['is_active'] == false || b['is_active'] == 0).length.toString(),
                  Icons.pause_circle,
                  Colors.orange,
                  isTiny,
                ),
              ),
            ],
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          
          // Businesses List
          ..._allBusinesses.map((business) => _buildBusinessCard(
            business,
            isTiny,
            isExtraSmall,
          )).toList(),
          
          if (_allBusinesses.isEmpty)
            _buildEmptyStateCard(
              'No businesses',
              'No businesses have been registered yet',
              Icons.business,
              Colors.grey,
              isTiny,
              isExtraSmall,
            ),
        ],
      ),
    );
  }

  Widget _buildBusinessMessagesSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Messages Header
          Row(
            children: [
              Icon(Icons.message, color: Theme.of(context).primaryColor),
              SizedBox(width: isTiny ? 4 : 8),
              Text(
                'Business Messages',
                style: TextStyle(
                  fontSize: isTiny ? 16 : (isExtraSmall ? 18 : 20),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          
          // Messages List
          ..._allMessages.map((message) => _buildMessageCard(
            message,
            isTiny,
            isExtraSmall,
          )).toList(),
          
          if (_allMessages.isEmpty)
            _buildEmptyStateCard(
              'No messages',
              'No messages from businesses',
              Icons.message,
              Colors.grey,
              isTiny,
              isExtraSmall,
            ),
        ],
      ),
    );
  }

  Widget _buildBusinessPaymentsSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payments Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total',
                  '\$${_calculateTotalRevenue()}',
                  Icons.attach_money,
                  Colors.green,
                  isTiny,
                ),
              ),
              SizedBox(width: isTiny ? 4 : 8),
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  _allPayments.where((p) => p['status'] == 'pending').length.toString(),
                  Icons.schedule,
                  Colors.orange,
                  isTiny,
                ),
              ),
              SizedBox(width: isTiny ? 4 : 8),
              Expanded(
                child: _buildStatCard(
                  'Completed',
                  _allPayments.where((p) => p['status'] == 'completed').length.toString(),
                  Icons.check_circle,
                  Colors.blue,
                  isTiny,
                ),
              ),
            ],
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          
          // Recent Payments
          Text(
            'Recent Payments',
            style: TextStyle(
              fontSize: isTiny ? 14 : (isExtraSmall ? 16 : 18),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isTiny ? 4 : 6),
          
          ..._allPayments.take(10).map((payment) => _buildPaymentCard(
            payment,
            isTiny,
            isExtraSmall,
          )).toList(),
          
          if (_allPayments.isEmpty)
            _buildEmptyStateCard(
              'No payments',
              'No payment records found',
              Icons.payment,
              Colors.grey,
              isTiny,
              isExtraSmall,
            ),
        ],
      ),
    );
  }

  Widget _buildBusinessAnalyticsSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Analytics Overview
          _buildMobileCard(
            title: 'Business Analytics',
            icon: Icons.analytics,
            color: Colors.purple,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildStatRow('Total Revenue', '\$${_calculateTotalRevenue()}', isTiny),
                _buildStatRow('Avg Revenue/Business', '\$${_calculateAverageRevenuePerBusiness()}', isTiny),
                _buildStatRow('Active Businesses', _allBusinesses.where((b) => b['is_active'] == true || b['is_active'] == 1).length.toString(), isTiny),
                _buildStatRow('Payment Success Rate', '${_calculatePaymentSuccessRate()}%', isTiny),
              ],
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          
          // Top Performing Businesses
          _buildMobileCard(
            title: 'Top Performing Businesses',
            icon: Icons.star,
            color: Colors.amber,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: _buildTopBusinessesList(isTiny, isExtraSmall),
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          
          // Revenue Trends
          _buildMobileCard(
            title: 'Revenue Trends',
            icon: Icons.trending_up,
            color: Colors.green,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildStatRow('This Month', '\$${_calculateMonthlyRevenue()}', isTiny),
                _buildStatRow('Last Month', '\$${_calculateLastMonthRevenue()}', isTiny),
                _buildStatRow('Growth Rate', '${_calculateGrowthRate()}%', isTiny),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return Column(
      children: [
        // Sub-tab bar for Users
        Container(
          height: isTiny ? 40 : 48,
          child: TabBar(
            controller: _usersTabController,
            isScrollable: true,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Theme.of(context).primaryColor,
            labelPadding: EdgeInsets.symmetric(horizontal: isTiny ? 8 : 12),
            labelStyle: TextStyle(
              fontSize: isTiny ? 10 : (isExtraSmall ? 12 : 14),
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              Tab(
                icon: Icon(Icons.people, size: isTiny ? 16 : 18),
                text: isTiny ? 'All Users' : 'All Users',
              ),
              Tab(
                icon: Icon(Icons.security, size: isTiny ? 16 : 18),
                text: isTiny ? 'Security' : 'Security',
              ),
              Tab(
                icon: Icon(Icons.admin_panel_settings, size: isTiny ? 16 : 18),
                text: isTiny ? 'Access' : 'Access Control',
              ),
            ],
          ),
        ),
        // Sub-tab content
        Expanded(
          child: TabBarView(
            controller: _usersTabController,
            children: [
              _buildAllUsersSubTab(isTiny, isExtraSmall, isVerySmall),
              _buildSecuritySubTab(isTiny, isExtraSmall, isVerySmall),
              _buildAccessControlSubTab(isTiny, isExtraSmall, isVerySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAllUsersSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Add User button
          Row(
            children: [
              Expanded(
                child: Text(
                  'All Users',
                  style: TextStyle(
                    fontSize: isTiny ? 16 : (isExtraSmall ? 18 : 20),
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddUserDialog(),
                icon: Icon(Icons.person_add, size: isTiny ? 16 : 18),
                label: Text(isTiny ? 'Add' : 'Add User'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTiny ? 8 : 12,
                    vertical: isTiny ? 6 : 8,
                  ),
                  textStyle: TextStyle(fontSize: isTiny ? 12 : 14),
                ),
              ),
            ],
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          
          // User Stats Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total',
                  _allUsers.length.toString(),
                  Icons.people,
                  Colors.blue,
                  isTiny,
                ),
              ),
              SizedBox(width: isTiny ? 4 : 8),
              Expanded(
                child: _buildStatCard(
                  'Active',
                  _allUsers.where((u) => u['is_active'] == true || u['is_active'] == 1).length.toString(),
                  Icons.check_circle,
                  Colors.green,
                  isTiny,
                ),
              ),
              SizedBox(width: isTiny ? 4 : 8),
              Expanded(
                child: _buildStatCard(
                  'Admins',
                  _allUsers.where((u) => u['role'] == 'admin' || u['role'] == 'superadmin').length.toString(),
                  Icons.admin_panel_settings,
                  Colors.purple,
                  isTiny,
                ),
              ),
            ],
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          
          // Users List
          ..._allUsers.map((user) => _buildUserCard(
            user,
            isTiny,
            isExtraSmall,
          )).toList(),
          
          if (_allUsers.isEmpty)
            _buildEmptyStateCard(
              'No users',
              'No users have been registered yet',
              Icons.people,
              Colors.grey,
              isTiny,
              isExtraSmall,
            ),
        ],
      ),
    );
  }

  Widget _buildSecuritySubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Security Overview
          _buildMobileCard(
            title: 'Security Overview',
            icon: Icons.security,
            color: Colors.red,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildStatRow('Failed Logins (24h)', _getFailedLoginsCount().toString(), isTiny),
                _buildStatRow('Suspicious Activities', _getSuspiciousActivitiesCount().toString(), isTiny),
                _buildStatRow('Password Resets', _getPasswordResetsCount().toString(), isTiny),
                _buildStatRow('Account Lockouts', _getAccountLockoutsCount().toString(), isTiny),
              ],
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          
          // Recent Security Events
          _buildMobileCard(
            title: 'Recent Security Events',
            icon: Icons.warning,
            color: Colors.orange,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: _buildSecurityEventsList(isTiny),
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          
          // Security Settings
          _buildMobileCard(
            title: 'Security Settings',
            icon: Icons.settings,
            color: Colors.blue,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildSecuritySettingRow('Two-Factor Auth', 'Enabled', true, isTiny),
                _buildSecuritySettingRow('Password Policy', 'Strong', true, isTiny),
                _buildSecuritySettingRow('Session Timeout', '30 minutes', true, isTiny),
                _buildSecuritySettingRow('IP Whitelist', 'Disabled', false, isTiny),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessControlSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Role Management
          _buildMobileCard(
            title: 'Role Management',
            icon: Icons.admin_panel_settings,
            color: Colors.purple,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildRoleRow('Superadmin', _getUsersByRole('superadmin').length, Colors.red, isTiny),
                _buildRoleRow('Admin', _getUsersByRole('admin').length, Colors.orange, isTiny),
                _buildRoleRow('Manager', _getUsersByRole('manager').length, Colors.blue, isTiny),
                _buildRoleRow('Cashier', _getUsersByRole('cashier').length, Colors.green, isTiny),
              ],
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          
          // Permission Matrix
          _buildMobileCard(
            title: 'Permission Matrix',
            icon: Icons.lock,
            color: Colors.indigo,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: _buildPermissionMatrix(isTiny),
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          
          // Access Logs
          _buildMobileCard(
            title: 'Recent Access Logs',
            icon: Icons.history,
            color: Colors.grey,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: _buildAccessLogsList(isTiny),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return Column(
      children: [
        // Sub-tab bar for Analytics
        Container(
          height: isTiny ? 40 : 48,
          child: TabBar(
            controller: _analyticsTabController,
            isScrollable: true,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Theme.of(context).primaryColor,
            labelPadding: EdgeInsets.symmetric(horizontal: isTiny ? 8 : 12),
            labelStyle: TextStyle(
              fontSize: isTiny ? 10 : (isExtraSmall ? 12 : 14),
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              Tab(
                icon: Icon(Icons.analytics, size: isTiny ? 16 : 18),
                text: isTiny ? 'Overview' : 'Overview',
              ),
              Tab(
                icon: Icon(Icons.attach_money, size: isTiny ? 16 : 18),
                text: isTiny ? 'Revenue' : 'Revenue',
              ),
              Tab(
                icon: Icon(Icons.bar_chart, size: isTiny ? 16 : 18),
                text: isTiny ? 'Usage' : 'Usage',
              ),
            ],
          ),
        ),
        // Sub-tab content
        Expanded(
          child: TabBarView(
            controller: _analyticsTabController,
            children: [
              _buildAnalyticsOverviewSubTab(isTiny, isExtraSmall, isVerySmall),
              _buildAnalyticsRevenueSubTab(isTiny, isExtraSmall, isVerySmall),
              _buildAnalyticsUsageSubTab(isTiny, isExtraSmall, isVerySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsOverviewSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMobileCard(
            title: 'Key Metrics',
            icon: Icons.analytics,
            color: Colors.blue,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildStatRow('Total Revenue', '\$${_calculateTotalRevenue()}', isTiny),
                _buildStatRow('Active Businesses', _allBusinesses.where((b) => b['is_active'] == true || b['is_active'] == 1).length.toString(), isTiny),
                _buildStatRow('Active Users', _allUsers.where((u) => u['is_active'] == true || u['is_active'] == 1).length.toString(), isTiny),
                _buildStatRow('Payments (30d)', _allPayments.where((p) => _isWithinLast30Days(p['created_at'])).length.toString(), isTiny),
              ],
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          _buildMobileCard(
            title: 'Growth Chart',
            icon: Icons.trending_up,
            color: Colors.green,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: _buildPlaceholderChart('Growth (Last 6 Months)', isTiny),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsRevenueSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMobileCard(
            title: 'Revenue Breakdown',
            icon: Icons.pie_chart,
            color: Colors.purple,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildStatRow('This Month', '\$${_calculateMonthlyRevenue()}', isTiny),
                _buildStatRow('Last Month', '\$${_calculateLastMonthRevenue()}', isTiny),
                _buildStatRow('Growth Rate', '${_calculateGrowthRate()}%', isTiny),
                _buildStatRow('Avg Revenue/Business', '\$${_calculateAverageRevenuePerBusiness()}', isTiny),
              ],
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          _buildMobileCard(
            title: 'Revenue Trend',
            icon: Icons.show_chart,
            color: Colors.green,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: _buildPlaceholderChart('Revenue Trend (12 Months)', isTiny),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          _buildMobileCard(
            title: 'Top Businesses by Revenue',
            icon: Icons.star,
            color: Colors.amber,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: _buildTopBusinessesList(isTiny, isExtraSmall),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsUsageSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMobileCard(
            title: 'Usage Overview',
            icon: Icons.bar_chart,
            color: Colors.indigo,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildStatRow('Total Logins (30d)', _getTotalLogins30d().toString(), isTiny),
                _buildStatRow('Active Users (30d)', _getActiveUsers30d().toString(), isTiny),
                _buildStatRow('Most Active Business', _getMostActiveBusinessName(), isTiny),
                _buildStatRow('Most Used Feature', _getMostUsedFeature(), isTiny),
              ],
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          _buildMobileCard(
            title: 'Feature Usage',
            icon: Icons.apps,
            color: Colors.blue,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: _buildPlaceholderChart('Feature Usage (Top 5)', isTiny),
          ),
        ],
      ),
    );
  }

  // Analytics helper methods
  bool _isWithinLast30Days(dynamic dateValue) {
    if (dateValue == null) return false;
    try {
      DateTime date;
      
      if (dateValue is int) {
        // Handle timestamp (seconds since epoch)
        date = DateTime.fromMillisecondsSinceEpoch(dateValue * 1000);
      } else if (dateValue is String) {
        // Handle string date
        date = DateTime.parse(dateValue);
      } else {
        return false;
      }
      
      return date.isAfter(DateTime.now().subtract(const Duration(days: 30)));
    } catch (e) {
      return false;
    }
  }

  Widget _buildPlaceholderChart(String label, bool isTiny) {
    return Container(
      height: isTiny ? 80 : 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(isTiny ? 8 : 12),
      ),
      child: Center(
        child: Text(
          label + '\n[Chart Placeholder]',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isTiny ? 10 : 12,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  int _getTotalLogins30d() {
    // TODO: Replace with real data
    return 120;
  }

  int _getActiveUsers30d() {
    // TODO: Replace with real data
    return 45;
  }

  String _getMostActiveBusinessName() {
    // TODO: Replace with real data
    if (_allBusinesses.isEmpty) return 'N/A';
    return _allBusinesses.first['name'] ?? 'N/A';
  }

  String _getMostUsedFeature() {
    // TODO: Replace with real data
    return 'Sales';
  }

  Widget _buildSettingsTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return Column(
      children: [
        // Sub-tab bar for Settings
        Container(
          height: isTiny ? 40 : 48,
          child: TabBar(
            controller: _settingsTabController,
            isScrollable: true,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Theme.of(context).primaryColor,
            labelPadding: EdgeInsets.symmetric(horizontal: isTiny ? 8 : 12),
            labelStyle: TextStyle(
              fontSize: isTiny ? 10 : (isExtraSmall ? 12 : 14),
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              Tab(
                icon: Icon(Icons.settings, size: isTiny ? 16 : 18),
                text: isTiny ? 'System' : 'System',
              ),
              Tab(
                icon: Icon(Icons.admin_panel_settings, size: isTiny ? 16 : 18),
                text: isTiny ? 'Admin' : 'Admin',
              ),
              Tab(
                icon: Icon(Icons.palette, size: isTiny ? 16 : 18),
                text: isTiny ? 'Branding' : 'Branding',
              ),
              Tab(
                icon: Icon(Icons.backup, size: isTiny ? 16 : 18),
                text: isTiny ? 'Backups' : 'Backups',
              ),
            ],
          ),
        ),
        // Sub-tab content
        Expanded(
          child: TabBarView(
            controller: _settingsTabController,
            children: [
              _buildSystemSettingsSubTab(isTiny, isExtraSmall, isVerySmall),
              _buildAdminSettingsSubTab(isTiny, isExtraSmall, isVerySmall),
              _buildBrandingSettingsSubTab(isTiny, isExtraSmall, isVerySmall),
              _buildBackupsSettingsSubTab(isTiny, isExtraSmall, isVerySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSystemSettingsSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMobileCard(
            title: 'General Settings',
            icon: Icons.settings,
            color: Colors.blue,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildSettingRow('System Language', 'English', isTiny),
                _buildSettingRow('Timezone', 'UTC', isTiny),
                _buildSettingRow('Currency', 'USD', isTiny),
                _buildSettingRow('Maintenance Mode', 'Off', isTiny),
              ],
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          _buildMobileCard(
            title: 'Notifications',
            icon: Icons.notifications,
            color: Colors.orange,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildSettingRow('Email Alerts', 'Enabled', isTiny),
                _buildSettingRow('SMS Alerts', 'Disabled', isTiny),
                _buildSettingRow('Push Notifications', 'Enabled', isTiny),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSettingsSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMobileCard(
            title: 'Admin Codes',
            icon: Icons.admin_panel_settings,
            color: Colors.purple,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildSettingRow('Superadmin Code', '****-****', isTiny),
                _buildSettingRow('Admin Code', '****-****', isTiny),
                _buildSettingRow('Manager Code', '****-****', isTiny),
              ],
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          _buildMobileCard(
            title: 'Admin Actions',
            icon: Icons.build,
            color: Colors.blueGrey,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildActionButton('Reset All Passwords', Icons.lock_reset, Colors.red, isTiny, () => _showResetAllPasswordsDialog()),
                _buildActionButton('Send System Announcement', Icons.campaign, Colors.orange, isTiny, () => _showSendAnnouncementDialog()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingSettingsSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMobileCard(
            title: 'Branding',
            icon: Icons.palette,
            color: Colors.teal,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildSettingRow('App Logo', 'Current', isTiny),
                _buildSettingRow('Primary Color', '#1976D2', isTiny),
                _buildSettingRow('Accent Color', '#FF9800', isTiny),
                _buildSettingRow('Font', 'Roboto', isTiny),
              ],
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          _buildMobileCard(
            title: 'Branding Actions',
            icon: Icons.edit,
            color: Colors.purple,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildActionButton('Change Logo', Icons.image, Colors.blue, isTiny, () => _showChangeLogoDialog()),
                _buildActionButton('Edit Colors', Icons.color_lens, Colors.orange, isTiny, () => _showEditColorsDialog()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupsSettingsSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMobileCard(
            title: 'Backups',
            icon: Icons.backup,
            color: Colors.indigo,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildSettingRow('Last Backup', '2024-06-01', isTiny),
                _buildSettingRow('Backup Frequency', 'Daily', isTiny),
                _buildSettingRow('Storage Used', '1.2 GB', isTiny),
              ],
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          _buildMobileCard(
            title: 'Backup Actions',
            icon: Icons.settings_backup_restore,
            color: Colors.green,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildActionButton('Create Backup Now', Icons.add_box, Colors.green, isTiny, () => _showCreateBackupDialog()),
                _buildActionButton('Restore Backup', Icons.restore, Colors.blue, isTiny, () => _showRestoreBackupDialog()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Settings helper methods
  Widget _buildSettingRow(String label, String value, bool isTiny) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTiny ? 2 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTiny ? 12 : 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTiny ? 12 : 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, bool isTiny, VoidCallback onPressed) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: isTiny ? 2 : 4),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: isTiny ? 14 : 16),
        label: Text(label, style: TextStyle(fontSize: isTiny ? 12 : 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.symmetric(vertical: isTiny ? 8 : 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTiny ? 8 : 12)),
        ),
      ),
    );
  }

  // Settings dialog stubs
  void _showResetAllPasswordsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Passwords'),
        content: const Text('Are you sure you want to reset all user passwords?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showSendAnnouncementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send System Announcement'),
        content: const Text('Announcement functionality will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showChangeLogoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Logo'),
        content: const Text('Logo change functionality will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEditColorsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Colors'),
        content: const Text('Color editing functionality will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCreateBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Backup'),
        content: const Text('Backup creation functionality will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRestoreBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text('Backup restore functionality will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return Column(
      children: [
        // Sub-tab bar for Data
        Container(
          height: isTiny ? 40 : 48,
          child: TabBar(
            controller: _dataTabController,
            isScrollable: true,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Theme.of(context).primaryColor,
            labelPadding: EdgeInsets.symmetric(horizontal: isTiny ? 8 : 12),
            labelStyle: TextStyle(
              fontSize: isTiny ? 10 : (isExtraSmall ? 12 : 14),
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              Tab(
                icon: Icon(Icons.storage, size: isTiny ? 16 : 18),
                text: isTiny ? 'Overview' : 'Overview',
              ),
              Tab(
                icon: Icon(Icons.delete_forever, size: isTiny ? 16 : 18),
                text: isTiny ? 'Deleted' : 'Deleted Data',
              ),
              Tab(
                icon: Icon(Icons.data_usage, size: isTiny ? 16 : 18),
                text: isTiny ? 'Export' : 'Export',
              ),
            ],
          ),
        ),
        // Sub-tab content
        Expanded(
          child: TabBarView(
            controller: _dataTabController,
            children: [
              _buildDataOverviewSubTab(isTiny, isExtraSmall, isVerySmall),
              _buildDeletedDataSubTab(isTiny, isExtraSmall, isVerySmall),
              _buildDataExportSubTab(isTiny, isExtraSmall, isVerySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataOverviewSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMobileCard(
            title: 'Data Overview',
            icon: Icons.storage,
            color: Colors.blue,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildStatRow('Total Businesses', _allBusinesses.length.toString(), isTiny),
                _buildStatRow('Total Users', _allUsers.length.toString(), isTiny),
                _buildStatRow('Total Payments', _allPayments.length.toString(), isTiny),
                _buildStatRow('Total Messages', _allMessages.length.toString(), isTiny),
              ],
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          _buildMobileCard(
            title: 'Storage Usage',
            icon: Icons.data_usage,
            color: Colors.green,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildStatRow('Database Size', '2.5 GB', isTiny),
                _buildStatRow('File Storage', '1.8 GB', isTiny),
                _buildStatRow('Backups', '500 MB', isTiny),
                _buildStatRow('Total Used', '4.8 GB', isTiny),
              ],
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          _buildMobileCard(
            title: 'Data Actions',
            icon: Icons.build,
            color: Colors.orange,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildActionButton('Optimize Database', Icons.speed, Colors.blue, isTiny, () => _showOptimizeDatabaseDialog()),
                _buildActionButton('Clean Old Data', Icons.cleaning_services, Colors.orange, isTiny, () => _showCleanOldDataDialog()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletedDataSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMobileCard(
            title: 'Deleted Data Summary',
            icon: Icons.delete_forever,
            color: Colors.red,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildStatRow('Deleted Businesses', '5', isTiny),
                _buildStatRow('Deleted Users', '12', isTiny),
                _buildStatRow('Deleted Products', '45', isTiny),
                _buildStatRow('Deleted Sales', '23', isTiny),
              ],
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          _buildMobileCard(
            title: 'Recently Deleted',
            icon: Icons.history,
            color: Colors.grey,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: _buildRecentlyDeletedList(isTiny),
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          _buildMobileCard(
            title: 'Recovery Actions',
            icon: Icons.restore,
            color: Colors.green,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildActionButton('Restore All Deleted', Icons.restore_page, Colors.green, isTiny, () => _showRestoreAllDeletedDialog()),
                _buildActionButton('Permanently Delete All', Icons.delete_forever, Colors.red, isTiny, () => _showPermanentlyDeleteAllDialog()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataExportSubTab(bool isTiny, bool isExtraSmall, bool isVerySmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMobileCard(
            title: 'Export Options',
            icon: Icons.data_usage,
            color: Colors.purple,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildStatRow('Last Export', '2024-06-01', isTiny),
                _buildStatRow('Export Format', 'CSV', isTiny),
                _buildStatRow('Export Size', '15 MB', isTiny),
                _buildStatRow('Auto Export', 'Weekly', isTiny),
              ],
            ),
          ),
          SizedBox(height: isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          _buildMobileCard(
            title: 'Export Actions',
            icon: Icons.download,
            color: Colors.blue,
            isTiny: isTiny,
            isExtraSmall: isExtraSmall,
            child: Column(
              children: [
                _buildActionButton('Export All Data', Icons.download, Colors.blue, isTiny, () => _showExportAllDataDialog()),
                _buildActionButton('Export Businesses Only', Icons.business, Colors.green, isTiny, () => _showExportBusinessesDialog()),
                _buildActionButton('Export Users Only', Icons.people, Colors.orange, isTiny, () => _showExportUsersDialog()),
                _buildActionButton('Export Payments Only', Icons.payment, Colors.purple, isTiny, () => _showExportPaymentsDialog()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Data helper methods
  List<Widget> _buildRecentlyDeletedList(bool isTiny) {
    final recentlyDeleted = [
      {'type': 'Business', 'name': 'ABC Store', 'deleted': '2 hours ago', 'icon': Icons.business},
      {'type': 'User', 'name': 'john.doe', 'deleted': '4 hours ago', 'icon': Icons.person},
      {'type': 'Product', 'name': 'Product XYZ', 'deleted': '6 hours ago', 'icon': Icons.inventory},
      {'type': 'Sale', 'name': 'Sale #1234', 'deleted': '1 day ago', 'icon': Icons.receipt},
    ];

    return recentlyDeleted.map((item) => Padding(
      padding: EdgeInsets.symmetric(vertical: isTiny ? 2 : 4),
      child: Row(
        children: [
          Icon(
            item['icon'] as IconData,
            size: isTiny ? 14 : 16,
            color: Colors.grey[600],
          ),
          SizedBox(width: isTiny ? 6 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['type']}: ${item['name']}',
                  style: TextStyle(
                    fontSize: isTiny ? 12 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Deleted ${item['deleted']}',
                  style: TextStyle(
                    fontSize: isTiny ? 10 : 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showRestoreItemDialog(item),
            child: Text(
              'Restore',
              style: TextStyle(fontSize: isTiny ? 10 : 12),
            ),
          ),
        ],
      ),
    )).toList();
  }

  // Data dialog stubs
  void _showOptimizeDatabaseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Optimize Database'),
        content: const Text('This will optimize the database for better performance. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Optimize'),
          ),
        ],
      ),
    );
  }

  void _showCleanOldDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clean Old Data'),
        content: const Text('This will remove data older than 1 year. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Clean'),
          ),
        ],
      ),
    );
  }

  void _showRestoreAllDeletedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore All Deleted'),
        content: const Text('This will restore all recently deleted items. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _showPermanentlyDeleteAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently Delete All'),
        content: const Text('This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRestoreItemDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restore ${item['type']}'),
        content: Text('Restore ${item['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _showExportAllDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export All Data'),
        content: const Text('Export all data as CSV file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _showExportBusinessesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Businesses'),
        content: const Text('Export all businesses data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _showExportUsersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Users'),
        content: const Text('Export all users data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _showExportPaymentsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Payments'),
        content: const Text('Export all payments data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  // Helper methods for Overview tab
  Widget _buildMobileCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    required bool isTiny,
    required bool isExtraSmall,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTiny ? 8 : (isExtraSmall ? 12 : 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTiny ? 8 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTiny ? 4 : 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isTiny ? 4 : 6),
                ),
                child: Icon(icon, color: color, size: isTiny ? 16 : 20),
              ),
              SizedBox(width: isTiny ? 6 : 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isTiny ? 14 : (isExtraSmall ? 16 : 18),
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isTiny ? 8 : 12),
          child,
        ],
      ),
    );
  }

  Widget _buildStatusRow(String service, String status, Color statusColor, bool isTiny) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTiny ? 2 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            service,
            style: TextStyle(
              fontSize: isTiny ? 12 : 14,
              color: Colors.grey[700],
            ),
          ),
          Row(
            children: [
              Container(
                width: isTiny ? 6 : 8,
                height: isTiny ? 6 : 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: isTiny ? 4 : 6),
              Text(
                status,
                style: TextStyle(
                  fontSize: isTiny ? 12 : 14,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, bool isTiny) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTiny ? 2 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTiny ? 12 : 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTiny ? 12 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRecentActivityItems(bool isTiny) {
    final recentActivities = [
      {'action': 'New business registered', 'time': '2 hours ago', 'icon': Icons.business},
      {'action': 'Payment received', 'time': '4 hours ago', 'icon': Icons.payment},
      {'action': 'User login', 'time': '6 hours ago', 'icon': Icons.login},
      {'action': 'System backup', 'time': '1 day ago', 'icon': Icons.backup},
    ];

    return recentActivities.map((activity) => Padding(
      padding: EdgeInsets.symmetric(vertical: isTiny ? 2 : 4),
      child: Row(
        children: [
          Icon(
            activity['icon'] as IconData,
            size: isTiny ? 14 : 16,
            color: Colors.grey[600],
          ),
          SizedBox(width: isTiny ? 6 : 8),
          Expanded(
            child: Text(
              activity['action'] as String,
              style: TextStyle(
                fontSize: isTiny ? 12 : 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          Text(
            activity['time'] as String,
            style: TextStyle(
              fontSize: isTiny ? 10 : 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    )).toList();
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, bool isTiny, bool isExtraSmall) {
    final type = notification['type'] ?? 'info';
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';
    final time = notification['created_at'] ?? '';

    Color cardColor;
    IconData icon;
    
    switch (type) {
      case 'error':
        cardColor = Colors.red;
        icon = Icons.error;
        break;
      case 'warning':
        cardColor = Colors.orange;
        icon = Icons.warning;
        break;
      case 'success':
        cardColor = Colors.green;
        icon = Icons.check_circle;
        break;
      default:
        cardColor = Colors.blue;
        icon = Icons.info;
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: isTiny ? 6 : 8),
      padding: EdgeInsets.all(isTiny ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTiny ? 8 : 12),
        border: Border.all(color: cardColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: cardColor, size: isTiny ? 16 : 20),
              SizedBox(width: isTiny ? 6 : 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isTiny ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  fontSize: isTiny ? 10 : 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          if (message.isNotEmpty) ...[
            SizedBox(height: isTiny ? 4 : 6),
            Text(
              message,
              style: TextStyle(
                fontSize: isTiny ? 12 : 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard(String title, String message, IconData icon, Color color, bool isTiny, bool isExtraSmall) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTiny ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTiny ? 8 : 12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isTiny ? 32 : 48),
          SizedBox(height: isTiny ? 8 : 12),
          Text(
            title,
            style: TextStyle(
              fontSize: isTiny ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: isTiny ? 4 : 6),
          Text(
            message,
            style: TextStyle(
              fontSize: isTiny ? 12 : 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRecentPaymentsList(bool isTiny, bool isExtraSmall) {
    final recentPayments = _allPayments.take(5).toList();
    
    if (recentPayments.isEmpty) {
      return [
        _buildEmptyStateCard(
          'No recent payments',
          'No payments have been made recently',
          Icons.payment,
          Colors.grey,
          isTiny,
          isExtraSmall,
        ),
      ];
    }

    return recentPayments.map((payment) => Padding(
      padding: EdgeInsets.symmetric(vertical: isTiny ? 2 : 4),
      child: Row(
        children: [
          Icon(Icons.payment, size: isTiny ? 14 : 16, color: Colors.green),
          SizedBox(width: isTiny ? 6 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment['business_name'] ?? 'Unknown Business',
                  style: TextStyle(
                    fontSize: isTiny ? 12 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '\$${TypeConverter.safeToDouble(payment['amount'] ?? 0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: isTiny ? 10 : 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatDate(payment['created_at']),
            style: TextStyle(
              fontSize: isTiny ? 10 : 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    )).toList();
  }

  List<Widget> _buildPendingPaymentsList(bool isTiny, bool isExtraSmall) {
    final pendingPayments = _allPayments.where((p) => p['status'] == 'pending').take(5).toList();
    
    if (pendingPayments.isEmpty) {
      return [
        _buildEmptyStateCard(
          'No pending payments',
          'All payments have been processed',
          Icons.check_circle,
          Colors.green,
          isTiny,
          isExtraSmall,
        ),
      ];
    }

    return pendingPayments.map((payment) => Padding(
      padding: EdgeInsets.symmetric(vertical: isTiny ? 2 : 4),
      child: Row(
        children: [
          Icon(Icons.schedule, size: isTiny ? 14 : 16, color: Colors.orange),
          SizedBox(width: isTiny ? 6 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment['business_name'] ?? 'Unknown Business',
                  style: TextStyle(
                    fontSize: isTiny ? 12 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '\$${TypeConverter.safeToDouble(payment['amount'] ?? 0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: isTiny ? 10 : 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatDate(payment['due_date']),
            style: TextStyle(
              fontSize: isTiny ? 10 : 12,
              color: Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    )).toList();
  }

  // Revenue calculation methods
  String _calculateTotalRevenue() {
    double total = 0;
    for (var payment in _allPayments) {
      if (payment['status'] == 'completed') {
        total += TypeConverter.safeToDouble(payment['amount'] ?? 0);
      }
    }
    return total.toStringAsFixed(2);
  }

  String _calculateMonthlyRevenue() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    double total = 0;
    for (var payment in _allPayments) {
      if (payment['status'] == 'completed') {
        final paymentDate = _safeParseDate(payment['created_at']);
        if (paymentDate != null && paymentDate.isAfter(startOfMonth)) {
          total += TypeConverter.safeToDouble(payment['amount'] ?? 0);
        }
      }
    }
    return total.toStringAsFixed(2);
  }

  String _calculateLastMonthRevenue() {
    final now = DateTime.now();
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
    final endOfLastMonth = DateTime(now.year, now.month, 1);
    
    double total = 0;
    for (var payment in _allPayments) {
      if (payment['status'] == 'completed') {
        final paymentDate = _safeParseDate(payment['created_at']);
        if (paymentDate != null && 
            paymentDate.isAfter(startOfLastMonth) && 
            paymentDate.isBefore(endOfLastMonth)) {
          total += TypeConverter.safeToDouble(payment['amount'] ?? 0);
        }
      }
    }
    return total.toStringAsFixed(2);
  }

  // Helper methods for Businesses tab
  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isTiny) {
    return Container(
      padding: EdgeInsets.all(isTiny ? 6 : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTiny ? 6 : 8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isTiny ? 16 : 20),
          SizedBox(height: isTiny ? 2 : 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isTiny ? 12 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: isTiny ? 10 : 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessCard(Map<String, dynamic> business, bool isTiny, bool isExtraSmall) {
    final name = business['name'] ?? 'Unknown Business';
    final email = business['email'] ?? '';
    final isActive = business['is_active'] ?? false;
    final plan = business['plan'] ?? 'basic';
    final createdAt = business['created_at'] ?? '';

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: isTiny ? 6 : 8),
      padding: EdgeInsets.all(isTiny ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTiny ? 8 : 12),
        border: Border.all(
          color: isActive ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTiny ? 4 : 6),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isTiny ? 4 : 6),
                ),
                child: Icon(
                  Icons.business,
                  color: isActive ? Colors.green : Colors.grey,
                  size: isTiny ? 16 : 20,
                ),
              ),
              SizedBox(width: isTiny ? 6 : 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: isTiny ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: isTiny ? 12 : 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTiny ? 6 : 8,
                  vertical: isTiny ? 2 : 4,
                ),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isTiny ? 8 : 12),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: isTiny ? 10 : 12,
                    color: isActive ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isTiny ? 6 : 8),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTiny ? 6 : 8,
                  vertical: isTiny ? 2 : 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isTiny ? 8 : 12),
                ),
                child: Text(
                  plan.toUpperCase(),
                  style: TextStyle(
                    fontSize: isTiny ? 10 : 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Created: ${_formatDate(createdAt)}',
                style: TextStyle(
                  fontSize: isTiny ? 10 : 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          SizedBox(height: isTiny ? 6 : 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showBusinessDetailsDialog(business),
                  icon: Icon(Icons.visibility, size: isTiny ? 14 : 16),
                  label: Text('View', style: TextStyle(fontSize: isTiny ? 12 : 14)),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: isTiny ? 4 : 6),
                  ),
                ),
              ),
              SizedBox(width: isTiny ? 4 : 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEditBusinessDialog(business),
                  icon: Icon(Icons.edit, size: isTiny ? 14 : 16),
                  label: Text('Edit', style: TextStyle(fontSize: isTiny ? 12 : 14)),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: isTiny ? 4 : 6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message, bool isTiny, bool isExtraSmall) {
    final businessName = message['business_name'] ?? 'Unknown Business';
    final subject = message['subject'] ?? 'No Subject';
    final content = message['content'] ?? '';
    final createdAt = message['created_at'] ?? '';
    final isRead = message['is_read'] ?? false;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: isTiny ? 6 : 8),
      padding: EdgeInsets.all(isTiny ? 8 : 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(isTiny ? 8 : 12),
        border: Border.all(
          color: isRead ? Colors.grey.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRead ? Icons.mail : Icons.mail_outline,
                color: isRead ? Colors.grey : Colors.blue,
                size: isTiny ? 16 : 20,
              ),
              SizedBox(width: isTiny ? 6 : 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      businessName,
                      style: TextStyle(
                        fontSize: isTiny ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      subject,
                      style: TextStyle(
                        fontSize: isTiny ? 12 : 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: isTiny ? 6 : 8,
                  height: isTiny ? 6 : 8,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          if (content.isNotEmpty) ...[
            SizedBox(height: isTiny ? 4 : 6),
            Text(
              content.length > 100 ? '${content.substring(0, 100)}...' : content,
              style: TextStyle(
                fontSize: isTiny ? 12 : 14,
                color: Colors.grey[600],
              ),
            ),
          ],
          SizedBox(height: isTiny ? 4 : 6),
          Row(
            children: [
              Text(
                _formatDate(createdAt),
                style: TextStyle(
                  fontSize: isTiny ? 10 : 12,
                  color: Colors.grey[500],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showMessageDetailsDialog(message),
                child: Text(
                  'View Details',
                  style: TextStyle(fontSize: isTiny ? 12 : 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment, bool isTiny, bool isExtraSmall) {
    final businessName = payment['business_name'] ?? 'Unknown Business';
    final amount = TypeConverter.safeToDouble(payment['amount'] ?? 0);
    final status = payment['status'] ?? 'pending';
    final createdAt = payment['created_at'] ?? '';

    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: isTiny ? 6 : 8),
      padding: EdgeInsets.all(isTiny ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTiny ? 8 : 12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTiny ? 4 : 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isTiny ? 4 : 6),
            ),
            child: Icon(statusIcon, color: statusColor, size: isTiny ? 16 : 20),
          ),
          SizedBox(width: isTiny ? 6 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  style: TextStyle(
                    fontSize: isTiny ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: isTiny ? 12 : 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTiny ? 6 : 8,
                  vertical: isTiny ? 2 : 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isTiny ? 8 : 12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: isTiny ? 10 : 12,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: isTiny ? 2 : 4),
              Text(
                _formatDate(createdAt),
                style: TextStyle(
                  fontSize: isTiny ? 10 : 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTopBusinessesList(bool isTiny, bool isExtraSmall) {
    // Sort businesses by revenue and take top 5
    final sortedBusinesses = List<Map<String, dynamic>>.from(_allBusinesses);
    sortedBusinesses.sort((a, b) {
      final aRevenue = _getBusinessRevenue(a['id']);
      final bRevenue = _getBusinessRevenue(b['id']);
      return bRevenue.compareTo(aRevenue);
    });

    final topBusinesses = sortedBusinesses.take(5).toList();

    if (topBusinesses.isEmpty) {
      return [
        _buildEmptyStateCard(
          'No businesses',
          'No business data available',
          Icons.business,
          Colors.grey,
          isTiny,
          isExtraSmall,
        ),
      ];
    }

    return topBusinesses.asMap().entries.map((entry) {
      final index = entry.key;
      final business = entry.value;
      final name = business['name'] ?? 'Unknown Business';
      final revenue = _getBusinessRevenue(business['id']);

      return Padding(
        padding: EdgeInsets.symmetric(vertical: isTiny ? 2 : 4),
        child: Row(
          children: [
            Container(
              width: isTiny ? 20 : 24,
              height: isTiny ? 20 : 24,
              decoration: BoxDecoration(
                color: _getRankColor(index),
                borderRadius: BorderRadius.circular(isTiny ? 10 : 12),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: isTiny ? 10 : 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(width: isTiny ? 6 : 8),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: isTiny ? 12 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '\$${revenue.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: isTiny ? 12 : 14,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // Utility methods for Businesses tab
  void _showAddBusinessDialog() {
    // TODO: Implement add business dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Business'),
        content: const Text('Add business functionality will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showBusinessDetailsDialog(Map<String, dynamic> business) {
    // TODO: Implement business details dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(business['name'] ?? 'Business Details'),
        content: const Text('Business details will be shown here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEditBusinessDialog(Map<String, dynamic> business) {
    // TODO: Implement edit business dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${business['name'] ?? 'Business'}'),
        content: const Text('Edit business functionality will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMessageDetailsDialog(Map<String, dynamic> message) {
    // TODO: Implement message details dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(message['subject'] ?? 'Message Details'),
        content: Text(message['content'] ?? 'No content'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateValue) {
    try {
      DateTime date;
      
      if (dateValue is int) {
        // Handle timestamp (seconds since epoch)
        date = DateTime.fromMillisecondsSinceEpoch(dateValue * 1000);
      } else if (dateValue is String) {
        // Handle string date
        date = DateTime.parse(dateValue);
      } else {
        return TypeConverter.safeToString(dateValue);
      }
      
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return TypeConverter.safeToString(dateValue);
    }
  }

  DateTime? _safeParseDate(dynamic dateValue) {
    if (dateValue == null) return null;
    try {
      if (dateValue is int) {
        // Handle timestamp (seconds since epoch)
        return DateTime.fromMillisecondsSinceEpoch(dateValue * 1000);
      } else if (dateValue is String) {
        // Handle string date
        return DateTime.parse(dateValue);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  double _getBusinessRevenue(int? businessId) {
    if (businessId == null) return 0;
    
    double total = 0;
    for (var payment in _allPayments) {
      if (payment['business_id'] == businessId && payment['status'] == 'completed') {
        total += TypeConverter.safeToDouble(payment['amount'] ?? 0);
      }
    }
    return total;
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber; // Gold
      case 1:
        return Colors.grey[400]!; // Silver
      case 2:
        return Colors.brown; // Bronze
      default:
        return Colors.blue;
    }
  }

  String _calculateAverageRevenuePerBusiness() {
    if (_allBusinesses.isEmpty) return '0.00';
    
    final totalRevenue = double.parse(_calculateTotalRevenue());
    final average = totalRevenue / _allBusinesses.length;
    return average.toStringAsFixed(2);
  }

  String _calculatePaymentSuccessRate() {
    if (_allPayments.isEmpty) return '0';
    
    final completedPayments = _allPayments.where((p) => p['status'] == 'completed').length;
    final successRate = (completedPayments / _allPayments.length) * 100;
    return successRate.toStringAsFixed(1);
  }

  String _calculateGrowthRate() {
    final thisMonth = double.parse(_calculateMonthlyRevenue());
    final lastMonth = double.parse(_calculateLastMonthRevenue());
    
    if (lastMonth == 0) return '0.0';
    
    final growthRate = ((thisMonth - lastMonth) / lastMonth) * 100;
    return growthRate.toStringAsFixed(1);
  }

  // Helper methods for Users tab
  Widget _buildUserCard(Map<String, dynamic> user, bool isTiny, bool isExtraSmall) {
    final username = user['username'] ?? 'Unknown User';
    final email = user['email'] ?? '';
    final role = user['role'] ?? 'user';
    final isActive = user['is_active'] ?? false;
    final lastLogin = user['last_login'] ?? '';
    final businessName = user['business_name'] ?? '';

    Color roleColor;
    IconData roleIcon;
    
    switch (role) {
      case 'superadmin':
        roleColor = Colors.red;
        roleIcon = Icons.admin_panel_settings;
        break;
      case 'admin':
        roleColor = Colors.orange;
        roleIcon = Icons.admin_panel_settings;
        break;
      case 'manager':
        roleColor = Colors.blue;
        roleIcon = Icons.manage_accounts;
        break;
      case 'cashier':
        roleColor = Colors.green;
        roleIcon = Icons.point_of_sale;
        break;
      default:
        roleColor = Colors.grey;
        roleIcon = Icons.person;
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: isTiny ? 6 : 8),
      padding: EdgeInsets.all(isTiny ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTiny ? 8 : 12),
        border: Border.all(
          color: isActive ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTiny ? 4 : 6),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isTiny ? 4 : 6),
                ),
                child: Icon(roleIcon, color: roleColor, size: isTiny ? 16 : 20),
              ),
              SizedBox(width: isTiny ? 6 : 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        fontSize: isTiny ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: isTiny ? 12 : 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (businessName.isNotEmpty)
                      Text(
                        businessName,
                        style: TextStyle(
                          fontSize: isTiny ? 10 : 12,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTiny ? 6 : 8,
                      vertical: isTiny ? 2 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(isTiny ? 8 : 12),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: TextStyle(
                        fontSize: isTiny ? 10 : 12,
                        color: roleColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: isTiny ? 2 : 4),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTiny ? 6 : 8,
                      vertical: isTiny ? 2 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(isTiny ? 8 : 12),
                    ),
                    child: Text(
                      isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: isTiny ? 10 : 12,
                        color: isActive ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (lastLogin.isNotEmpty) ...[
            SizedBox(height: isTiny ? 4 : 6),
            Text(
              'Last login: ${_formatDate(lastLogin)}',
              style: TextStyle(
                fontSize: isTiny ? 10 : 12,
                color: Colors.grey[500],
              ),
            ),
          ],
          SizedBox(height: isTiny ? 6 : 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showUserDetailsDialog(user),
                  icon: Icon(Icons.visibility, size: isTiny ? 14 : 16),
                  label: Text('View', style: TextStyle(fontSize: isTiny ? 12 : 14)),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: isTiny ? 4 : 6),
                  ),
                ),
              ),
              SizedBox(width: isTiny ? 4 : 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEditUserDialog(user),
                  icon: Icon(Icons.edit, size: isTiny ? 14 : 16),
                  label: Text('Edit', style: TextStyle(fontSize: isTiny ? 12 : 14)),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: isTiny ? 4 : 6),
                  ),
                ),
              ),
              SizedBox(width: isTiny ? 4 : 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showResetPasswordDialog(user),
                  icon: Icon(Icons.lock_reset, size: isTiny ? 14 : 16),
                  label: Text('Reset', style: TextStyle(fontSize: isTiny ? 12 : 14)),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: isTiny ? 4 : 6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySettingRow(String setting, String value, bool isEnabled, bool isTiny) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTiny ? 2 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            setting,
            style: TextStyle(
              fontSize: isTiny ? 12 : 14,
              color: Colors.grey[700],
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: isTiny ? 12 : 14,
                  fontWeight: FontWeight.w500,
                  color: isEnabled ? Colors.green : Colors.grey,
                ),
              ),
              SizedBox(width: isTiny ? 4 : 6),
              Icon(
                isEnabled ? Icons.check_circle : Icons.cancel,
                color: isEnabled ? Colors.green : Colors.grey,
                size: isTiny ? 14 : 16,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleRow(String role, int count, Color color, bool isTiny) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTiny ? 2 : 4),
      child: Row(
        children: [
          Container(
            width: isTiny ? 12 : 16,
            height: isTiny ? 12 : 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(isTiny ? 6 : 8),
            ),
          ),
          SizedBox(width: isTiny ? 6 : 8),
          Expanded(
            child: Text(
              role,
              style: TextStyle(
                fontSize: isTiny ? 12 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: isTiny ? 12 : 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSecurityEventsList(bool isTiny) {
    final securityEvents = [
      {'event': 'Failed login attempt', 'user': 'john.doe', 'time': '2 hours ago', 'severity': 'medium'},
      {'event': 'Password reset requested', 'user': 'jane.smith', 'time': '4 hours ago', 'severity': 'low'},
      {'event': 'Suspicious IP detected', 'user': 'admin', 'time': '6 hours ago', 'severity': 'high'},
      {'event': 'Account locked', 'user': 'user123', 'time': '1 day ago', 'severity': 'high'},
    ];

    return securityEvents.map((event) {
      final severity = event['severity'] as String;
      Color severityColor;
      
      switch (severity) {
        case 'high':
          severityColor = Colors.red;
          break;
        case 'medium':
          severityColor = Colors.orange;
          break;
        default:
          severityColor = Colors.green;
      }

      return Padding(
        padding: EdgeInsets.symmetric(vertical: isTiny ? 2 : 4),
        child: Row(
          children: [
            Container(
              width: isTiny ? 6 : 8,
              height: isTiny ? 6 : 8,
              decoration: BoxDecoration(
                color: severityColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: isTiny ? 6 : 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['event'] as String,
                    style: TextStyle(
                      fontSize: isTiny ? 12 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${event['user']} • ${event['time']}',
                    style: TextStyle(
                      fontSize: isTiny ? 10 : 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildPermissionMatrix(bool isTiny) {
    final permissions = [
      {'permission': 'View Dashboard', 'superadmin': true, 'admin': true, 'manager': true, 'cashier': false},
      {'permission': 'Manage Users', 'superadmin': true, 'admin': true, 'manager': false, 'cashier': false},
      {'permission': 'Manage Businesses', 'superadmin': true, 'admin': true, 'manager': false, 'cashier': false},
      {'permission': 'View Reports', 'superadmin': true, 'admin': true, 'manager': true, 'cashier': false},
      {'permission': 'Process Sales', 'superadmin': true, 'admin': true, 'manager': true, 'cashier': true},
    ];

    return permissions.map((permission) => Padding(
      padding: EdgeInsets.symmetric(vertical: isTiny ? 2 : 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              permission['permission'] as String,
              style: TextStyle(
                fontSize: isTiny ? 10 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: _buildPermissionIndicator(permission['superadmin'] as bool, isTiny),
          ),
          Expanded(
            child: _buildPermissionIndicator(permission['admin'] as bool, isTiny),
          ),
          Expanded(
            child: _buildPermissionIndicator(permission['manager'] as bool, isTiny),
          ),
          Expanded(
            child: _buildPermissionIndicator(permission['cashier'] as bool, isTiny),
          ),
        ],
      ),
    )).toList();
  }

  Widget _buildPermissionIndicator(bool hasPermission, bool isTiny) {
    return Container(
      width: isTiny ? 12 : 16,
      height: isTiny ? 12 : 16,
      decoration: BoxDecoration(
        color: hasPermission ? Colors.green : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: hasPermission
          ? Icon(Icons.check, color: Colors.white, size: isTiny ? 8 : 12)
          : null,
    );
  }

  List<Widget> _buildAccessLogsList(bool isTiny) {
    final accessLogs = [
      {'user': 'admin', 'action': 'Login', 'time': '2 hours ago', 'ip': '192.168.1.100'},
      {'user': 'john.doe', 'action': 'View Reports', 'time': '4 hours ago', 'ip': '192.168.1.101'},
      {'user': 'jane.smith', 'action': 'Edit User', 'time': '6 hours ago', 'ip': '192.168.1.102'},
      {'user': 'manager1', 'action': 'Process Sale', 'time': '1 day ago', 'ip': '192.168.1.103'},
    ];

    return accessLogs.map((log) => Padding(
      padding: EdgeInsets.symmetric(vertical: isTiny ? 2 : 4),
      child: Row(
        children: [
          Icon(Icons.access_time, size: isTiny ? 14 : 16, color: Colors.grey[600]),
          SizedBox(width: isTiny ? 6 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${log['user']} - ${log['action']}',
                  style: TextStyle(
                    fontSize: isTiny ? 12 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${log['time']} • ${log['ip']}',
                  style: TextStyle(
                    fontSize: isTiny ? 10 : 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )).toList();
  }

  // Utility methods for Users tab
  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add User'),
        content: const Text('Add user functionality will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showUserDetailsDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Details - ${user['username']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${user['email']}'),
            Text('Role: ${user['role']}'),
            Text('Status: ${user['is_active'] ? 'Active' : 'Inactive'}'),
            if (user['business_name'] != null)
              Text('Business: ${user['business_name']}'),
            if (user['last_login'] != null)
              Text('Last Login: ${_formatDate(user['last_login'])}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit User - ${user['username']}'),
        content: const Text('Edit user functionality will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Password - ${user['username']}'),
        content: const Text('Are you sure you want to reset this user\'s password?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  // Security and access control utility methods
  int _getFailedLoginsCount() {
    // TODO: Implement actual failed login count
    return 3;
  }

  int _getSuspiciousActivitiesCount() {
    // TODO: Implement actual suspicious activities count
    return 1;
  }

  int _getPasswordResetsCount() {
    // TODO: Implement actual password resets count
    return 5;
  }

  int _getAccountLockoutsCount() {
    // TODO: Implement actual account lockouts count
    return 2;
  }

  List<Map<String, dynamic>> _getUsersByRole(String role) {
    return _allUsers.where((user) => user['role'] == role).toList();
  }
}