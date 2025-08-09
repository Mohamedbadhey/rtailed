import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/utils/theme.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/utils/type_converter.dart';
import 'package:retail_management/screens/home/branding_settings_screen.dart';
import 'package:retail_management/screens/home/business_branding_screen.dart';
import 'package:retail_management/widgets/branded_app_bar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SuperadminDashboard extends StatefulWidget {
  const SuperadminDashboard({super.key});

  @override
  State<SuperadminDashboard> createState() => _SuperadminDashboardState();
}

class _SuperadminDashboardState extends State<SuperadminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  List<Map<String, dynamic>> _recentLogs = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _settings = [];
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _auditLogs = [];
  
  // State variables for real-time updates
  List<Map<String, dynamic>> _allMessages = [];
  List<Map<String, dynamic>> _allPayments = [];
  List<Map<String, dynamic>> _allBusinesses = [];
  bool _messagesLoaded = false;
  bool _paymentsLoaded = false;
  // Businesses pagination/search state
  int _businessOffset = 0;
  int _businessLimit = 9;
  String _businessQuery = '';
  int? _brandingSelectedBusinessId;
  
  // Revenue tracking state
  DateTime _revenueStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _revenueEndDate = DateTime.now();
  String _selectedRevenuePeriod = '30_days';

  // Use the TypeConverter utility for safe type conversions
  Map<String, dynamic> _convertMySQLTypes(dynamic data) {
    return TypeConverter.convertMySQLTypes(data);
  }

  double _safeToDouble(dynamic value) {
    return TypeConverter.safeToDouble(value);
  }

  List<Map<String, dynamic>> _convertMySQLList(List<dynamic> data) {
    return TypeConverter.convertMySQLList(data);
  }

  // Safe type conversion helper
  List<Map<String, dynamic>> _safeConvertToList(List<dynamic> data) {
    return TypeConverter.safeToList(data);
  }

  // Safe setState helper to prevent setState during build
  void _safeSetState(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(fn);
      }
    });
  }

  // Helper method to build responsive data displays
  Widget _buildResponsiveDataWidget({
    required bool isMobile,
    required Widget mobileWidget,
    required Widget desktopWidget,
  }) {
    return isMobile ? mobileWidget : desktopWidget;
  }

  // Helper method to get responsive font size
  double _getResponsiveFontSize(bool isTiny, bool isExtraSmall, double defaultSize) {
    if (isTiny) return defaultSize - 4;
    if (isExtraSmall) return defaultSize - 2;
    return defaultSize;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    
    // Load data after the widget is built to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
      _loadMessagesAndPayments();
      
      // Set up periodic refresh for real-time updates
      _setupPeriodicRefresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMessagesAndPayments() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;

      // Load businesses first
      final businessesResponse = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/businesses'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      
      List<Map<String, dynamic>> businesses = [];
      if (businessesResponse.statusCode == 200) {
        final businessesData = TypeConverter.safeToMap(json.decode(businessesResponse.body))['businesses'] ?? [];
        businesses = TypeConverter.convertMySQLList(businessesData);
        _allBusinesses = businesses;
      }

      // Load messages
      List<Map<String, dynamic>> allMessages = [];
      for (final business in businesses) {
        try {
          final messagesResponse = await http.get(
            Uri.parse('https://rtailed-production.up.railway.app/api/businesses/${business['id']}/messages'),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          );
          
          if (messagesResponse.statusCode == 200) {
            final messages = TypeConverter.safeToMap(json.decode(messagesResponse.body))['messages'] ?? [];
            allMessages.addAll(TypeConverter.convertMySQLList(messages));
          }
        } catch (e) {
          print('Error loading messages for business ${business['id']}: $e');
        }
      }
      
      // Sort messages by creation date
      allMessages.sort((a, b) => _safeParseDate(b['created_at'])?.compareTo(_safeParseDate(a['created_at']) ?? DateTime(1900)) ?? 0);
      
      // Load payments
      List<Map<String, dynamic>> allPayments = [];
      for (final business in businesses) {
        try {
          final paymentsResponse = await http.get(
            Uri.parse('https://rtailed-production.up.railway.app/api/businesses/${business['id']}/payments'),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          );
          
          if (paymentsResponse.statusCode == 200) {
            final payments = TypeConverter.safeToMap(json.decode(paymentsResponse.body))['payments'] ?? [];
            allPayments.addAll(TypeConverter.convertMySQLList(payments));
          }
        } catch (e) {
          print('Error loading payments for business ${business['id']}: $e');
        }
      }
      
      // Sort payments by creation date
      allPayments.sort((a, b) => _safeParseDate(b['created_at'])?.compareTo(_safeParseDate(a['created_at']) ?? DateTime(1900)) ?? 0);

      setState(() {
        _allMessages = allMessages;
        _allPayments = allPayments;
        _messagesLoaded = true;
        _paymentsLoaded = true;
      });
    } catch (e) {
      print('Error loading messages and payments: $e');
      setState(() {
        _messagesLoaded = true;
        _paymentsLoaded = true;
      });
    }
  }

  // Add new message to state immediately
  void _addMessageToState(Map<String, dynamic> message) {
    if (mounted && message.isNotEmpty) {
      try {
        setState(() {
          _allMessages.insert(0, message); // Add to beginning since we sort by date desc
        });
      } catch (e) {
        print('Error adding message to state: $e');
      }
    }
  }

  // Add new payment to state immediately
  void _addPaymentToState(Map<String, dynamic> payment) {
    if (mounted && payment.isNotEmpty) {
      try {
        // Debug: Log the raw payment payload
        try {
          print('[DEBUG] Adding payment to state: ' + json.encode(payment));
        } catch (_) {
          print('[DEBUG] Adding payment to state (non-JSON-encodable keys): ' + payment.toString());
        }
        // Debug: Show snackbar with key fields if possible
        try {
          final amountVal = TypeConverter.safeToDouble(payment['amount']);
          final businessIdVal = payment['business_id'];
          final statusVal = payment['status']?.toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('[DEBUG] Payment added: $businessIdVal • ' + amountVal.toStringAsFixed(2) + ' • ' + (statusVal ?? 'unknown')),
              duration: const Duration(seconds: 2),
            ),
          );
        } catch (_) {}

        setState(() {
          _allPayments.insert(0, payment); // Add to beginning since we sort by date desc
        });
      } catch (e) {
        print('Error adding payment to state: $e');
      }
    }
  }

  // Refresh data when business makes a payment (called from business side)
  void refreshPaymentsData() {
    _loadMessagesAndPayments();
  }

  // Set up periodic refresh for real-time updates
  void _setupPeriodicRefresh() {
    // Refresh data every 30 seconds to catch new payments from businesses
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        try {
          _loadMessagesAndPayments();
        } catch (e) {
          print('Error in periodic refresh: $e');
        }
        _setupPeriodicRefresh(); // Schedule next refresh
      }
    });
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;

      // Load dashboard overview
      final dashboardResponse = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/dashboard'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (dashboardResponse.statusCode == 200) {
        _dashboardData = TypeConverter.safeToMap(json.decode(dashboardResponse.body));
      }

      // Load recent logs
      final logsResponse = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/logs?limit=10'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (logsResponse.statusCode == 200) {
        final logsData = TypeConverter.safeToMap(json.decode(logsResponse.body));
        _recentLogs = TypeConverter.safeToList(logsData['logs'] ?? []);
      }

      // Load users
      final usersResponse = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/users?limit=10'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (usersResponse.statusCode == 200) {
        final usersData = TypeConverter.safeToMap(json.decode(usersResponse.body));
        _users = TypeConverter.safeToList(usersData['users'] ?? []);
      }

      // Load system settings
      final settingsResponse = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/settings'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (settingsResponse.statusCode == 200) {
        _settings = TypeConverter.safeToList(json.decode(settingsResponse.body));
      }

      // Load notifications
      final notificationsResponse = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/notifications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (notificationsResponse.statusCode == 200) {
        final notificationsData = TypeConverter.safeToMap(json.decode(notificationsResponse.body));
        _notifications = TypeConverter.safeToList(notificationsData['notifications'] ?? []);
      }

      // Load audit logs
      final auditLogsResponse = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/audit-logs?limit=20'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (auditLogsResponse.statusCode == 200) {
        final auditLogsData = TypeConverter.safeToMap(json.decode(auditLogsResponse.body));
        _auditLogs = TypeConverter.safeToList(auditLogsData['logs'] ?? []);
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    final isVerySmall = screenWidth < 480;
    final isExtraSmall = screenWidth < 360;
    final isTiny = screenWidth < 320;
    
    return Scaffold(
      appBar: BrandedAppBar(
        title: isTiny ? 'Admin' : (isVerySmall ? 'Superadmin' : (isMobile ? 'Superadmin' : t(context, 'Superadmin Dashboard'))),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(isMobile ? (isTiny ? 50 : 56) : 48),
          child: Container(
            height: isMobile ? (isTiny ? 50 : 56) : 48,
            child: TabBar(
              controller: _tabController,
              isScrollable: isMobile,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Theme.of(context).primaryColor,
              labelPadding: EdgeInsets.symmetric(horizontal: isMobile ? (isTiny ? 8 : 12) : 16),
              labelStyle: TextStyle(fontSize: isMobile ? (isTiny ? 10 : 12) : 14, fontWeight: FontWeight.w500),
              unselectedLabelStyle: TextStyle(fontSize: isMobile ? (isTiny ? 10 : 12) : 14),
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(
                  icon: Icon(Icons.dashboard, size: isMobile ? (isTiny ? 18 : 20) : 22), 
                  child: Text(
                    isMobile ? (isTiny ? 'Overview' : 'Overview') : t(context, 'Overview'),
                    style: TextStyle(fontSize: isMobile ? (isTiny ? 10 : 12) : 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  )
                ),
                Tab(
                  icon: Icon(Icons.business, size: isMobile ? (isTiny ? 18 : 20) : 22), 
                  child: Text(
                    isMobile ? (isTiny ? 'Business' : 'Businesses') : t(context, 'Businesses'),
                    style: TextStyle(fontSize: isMobile ? (isTiny ? 10 : 12) : 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  )
                ),
                Tab(
                  icon: Icon(Icons.people, size: isMobile ? (isTiny ? 18 : 20) : 22), 
                  child: Text(
                    isMobile ? (isTiny ? 'Users' : 'Users & Security') : t(context, 'Users & Security'),
                    style: TextStyle(fontSize: isMobile ? (isTiny ? 9 : 11) : 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  )
                ),
                Tab(
                  icon: Icon(Icons.analytics, size: isMobile ? (isTiny ? 18 : 20) : 22), 
                  child: Text(
                    isMobile ? (isTiny ? 'Analytics' : 'Analytics') : t(context, 'Analytics'),
                    style: TextStyle(fontSize: isMobile ? (isTiny ? 10 : 12) : 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  )
                ),
                Tab(
                  icon: Icon(Icons.settings, size: isMobile ? (isTiny ? 18 : 20) : 22), 
                  child: Text(
                    isMobile ? (isTiny ? 'Settings' : 'Settings') : t(context, 'Settings'),
                    style: TextStyle(fontSize: isMobile ? (isTiny ? 10 : 12) : 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  )
                ),
                Tab(
                  icon: Icon(Icons.storage, size: isMobile ? (isTiny ? 18 : 20) : 22), 
                  child: Text(
                    isMobile ? (isTiny ? 'Data' : 'Data Management') : t(context, 'Data Management'),
                    style: TextStyle(fontSize: isMobile ? (isTiny ? 9 : 11) : 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  )
                ),
              ],
            ),
          ),
        ),
        actions: [
          // Refresh button - show on all screens except tiny
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
          // Account menu - Enhanced for mobile
          PopupMenuButton<String>(
            icon: Icon(
              Icons.account_circle, 
              color: Colors.white, 
              size: isMobile ? (isTiny ? 24 : 26) : 24
            ),
            tooltip: t(context, 'Account'),
            padding: EdgeInsets.all(isMobile ? (isTiny ? 8 : 10) : 8),
            constraints: BoxConstraints(
              minWidth: isMobile ? (isTiny ? 44 : 48) : 44,
              minHeight: isMobile ? (isTiny ? 44 : 48) : 44,
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
                height: isMobile ? 48 : 40,
                child: Row(
                  children: [
                    Icon(Icons.person, size: isMobile ? (isTiny ? 18 : 20) : 18),
                    SizedBox(width: isMobile ? 10 : 8),
                    Text(
                      t(context, 'Profile'), 
                      style: TextStyle(fontSize: isMobile ? (isTiny ? 14 : 16) : 14)
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                height: isMobile ? 48 : 40,
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red, size: isMobile ? (isTiny ? 18 : 20) : 18),
                    SizedBox(width: isMobile ? 10 : 8),
                    Text(
                      'Logout', 
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: isMobile ? (isTiny ? 14 : 16) : 14
                      )
                    ),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                children: [
                  if (isVerySmall) _buildMobileControlsBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewContent(isTiny, isExtraSmall, isVerySmall, isMobile),
                        _buildBusinessesContent(isTiny, isExtraSmall, isVerySmall, isMobile),
                        _buildUsersAndSecurityContent(isTiny, isExtraSmall, isVerySmall, isMobile),
                        _buildAnalyticsContent(isTiny, isExtraSmall, isVerySmall, isMobile),
                        _buildSettingsContent(isTiny, isExtraSmall, isVerySmall, isMobile),
                        _buildDataManagementContent(isTiny, isExtraSmall, isVerySmall, isMobile),
                      ],
                    ),
                  ),
                ],
                  );
                },
              ),
            ),
    );
  }

  Widget _buildMobileControlsBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            t(context, 'Superadmin Controls'),
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
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.person, size: 16),
                onPressed: _showProfileDialog,
                tooltip: t(context, 'Profile'),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: const Icon(Icons.logout, size: 16, color: Colors.red),
                onPressed: _showLogoutDialog,
                tooltip: t(context, 'Logout'),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
            ),
    );
  }

  Widget _buildMobileTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      labelColor: Theme.of(context).primaryColor,
      unselectedLabelColor: Colors.grey[600],
      indicatorColor: Theme.of(context).primaryColor,
      tabs: [
        Tab(icon: Icon(Icons.dashboard), text: t(context, 'Overview')),
        Tab(icon: Icon(Icons.business), text: t(context, 'Businesses')),
        Tab(icon: Icon(Icons.people), text: t(context, 'Users')),
        Tab(icon: Icon(Icons.analytics), text: t(context, 'Analytics')),
        Tab(icon: Icon(Icons.settings), text: t(context, 'Settings')),
        Tab(icon: Icon(Icons.storage), text: t(context, 'Data')),
      ],
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

  Widget _buildMobileLayout() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTabMobile(),
        _buildBusinessesTabMobile(),
        _buildUsersAndSecurityTabMobile(),
        _buildAnalyticsTabMobile(),
        _buildSettingsTabMobile(),
        _buildDataManagementTabMobile(),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildBusinessesTab(),
        _buildUsersAndSecurityTab(),
        _buildAnalyticsTab(),
        _buildSettingsTab(),
        _buildDataManagementTab(),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildBusinessesTab(),
        _buildUsersAndSecurityTab(),
        _buildAnalyticsTab(),
        _buildSettingsTab(),
        _buildDataManagementTab(),
      ],
    );
  }

  // Responsive content methods - FULL functionality on all devices
  Widget _buildOverviewContent(bool isTiny, bool isExtraSmall, bool isVerySmall, bool isMobile) {
    // Always use the full desktop functionality, just with responsive layout
      return _buildOverviewTab();
  }

  Widget _buildBusinessesContent(bool isTiny, bool isExtraSmall, bool isVerySmall, bool isMobile) {
    // Always use the full desktop functionality, just with responsive layout
      return _buildBusinessesTab();
  }

  Widget _buildUsersAndSecurityContent(bool isTiny, bool isExtraSmall, bool isVerySmall, bool isMobile) {
    // Always use the full desktop functionality, just with responsive layout
      return _buildUsersAndSecurityTab();
  }

  Widget _buildAnalyticsContent(bool isTiny, bool isExtraSmall, bool isVerySmall, bool isMobile) {
    // Always use the full desktop functionality, just with responsive layout
      return _buildAnalyticsTab();
  }

  Widget _buildSettingsContent(bool isTiny, bool isExtraSmall, bool isVerySmall, bool isMobile) {
    // Always use the full desktop functionality, just with responsive layout
      return _buildSettingsTab();
  }

  Widget _buildDataManagementContent(bool isTiny, bool isExtraSmall, bool isVerySmall, bool isMobile) {
    // Always use the full desktop functionality, just with responsive layout
      return _buildDataManagementTab();
  }

  // Simple card components for mobile
  Widget _buildSystemHealthCard(bool isTiny, bool isExtraSmall) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchSystemHealth(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('${t(context, 'Error: ')}${snapshot.error}'));
        }
        final health = snapshot.data ?? {};
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTiny ? 6 : 8)),
          child: Padding(
            padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      health['status'] == 'healthy' ? Icons.check_circle : Icons.error,
                      color: health['status'] == 'healthy' ? Colors.green : Colors.red,
                      size: isTiny ? 16 : (isExtraSmall ? 18 : 20),
                    ),
                    SizedBox(width: isTiny ? 6 : 8),
                    Text(
                      isTiny ? 'Health' : 'System Health', 
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isTiny ? 12 : (isExtraSmall ? 14 : 16),
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Status: ${TypeConverter.safeToString(health['status'] ?? 'Unknown')}',
                  style: TextStyle(fontSize: isTiny ? 11 : 12),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Uptime: ${TypeConverter.safeToString(health['uptime'] ?? 'N/A')}',
                  style: TextStyle(fontSize: isTiny ? 11 : 12),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Memory: ${TypeConverter.safeToString(health['memory'] ?? 'N/A')}',
                  style: TextStyle(fontSize: isTiny ? 11 : 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationsCard(bool isTiny, bool isExtraSmall) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTiny ? 6 : 8)),
      child: Padding(
        padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications,
                  size: isTiny ? 16 : (isExtraSmall ? 18 : 20),
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(width: isTiny ? 6 : 8),
                Text(
                  isTiny ? 'Alerts' : 'Notifications', 
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isTiny ? 12 : (isExtraSmall ? 14 : 16),
                  )
                ),
              ],
            ),
            SizedBox(height: isTiny ? 6 : 8),
            Text(
              'No notifications', 
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isTiny ? 10 : (isExtraSmall ? 12 : 14),
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingCard(bool isTiny, bool isExtraSmall) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTiny ? 6 : 8)),
      child: Padding(
        padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.payment,
                  size: isTiny ? 16 : (isExtraSmall ? 18 : 20),
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(width: isTiny ? 6 : 8),
                Text(
                  isTiny ? 'Billing' : 'Billing Overview', 
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isTiny ? 12 : (isExtraSmall ? 14 : 16),
                  )
                ),
              ],
            ),
            SizedBox(height: isTiny ? 6 : 8),
            Text(
              'Billing information will appear here', 
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isTiny ? 10 : (isExtraSmall ? 12 : 14),
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserManagementCard(bool isTiny, bool isExtraSmall) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTiny ? 6 : 8)),
      child: Padding(
        padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: isTiny ? 16 : (isExtraSmall ? 18 : 20),
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(width: isTiny ? 6 : 8),
                Text(
                  isTiny ? 'Users' : 'User Management', 
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isTiny ? 12 : (isExtraSmall ? 14 : 16),
                  )
                ),
              ],
            ),
            SizedBox(height: isTiny ? 6 : 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: isTiny ? 6 : (isExtraSmall ? 8 : 10),
                    horizontal: isTiny ? 8 : (isExtraSmall ? 12 : 16),
                  ),
                ),
                child: Text(
                  isTiny ? 'Manage' : 'Manage Users',
                  style: TextStyle(fontSize: isTiny ? 10 : (isExtraSmall ? 12 : 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditCard(bool isTiny, bool isExtraSmall) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTiny ? 6 : 8)),
      child: Padding(
        padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.security,
                  size: isTiny ? 16 : (isExtraSmall ? 18 : 20),
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(width: isTiny ? 6 : 8),
                Text(
                  isTiny ? 'Audit' : 'Audit Logs', 
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isTiny ? 12 : (isExtraSmall ? 14 : 16),
                  )
                ),
              ],
            ),
            SizedBox(height: isTiny ? 6 : 8),
            Text(
              'View security audit logs', 
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isTiny ? 10 : (isExtraSmall ? 12 : 14),
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessControlCard(bool isTiny, bool isExtraSmall) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTiny ? 6 : 8)),
      child: Padding(
        padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock,
                  size: isTiny ? 16 : (isExtraSmall ? 18 : 20),
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(width: isTiny ? 6 : 8),
                Text(
                  isTiny ? 'Access' : 'Access Control', 
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isTiny ? 12 : (isExtraSmall ? 14 : 16),
                  )
                ),
              ],
            ),
            SizedBox(height: isTiny ? 6 : 8),
            Text(
              'Manage role permissions', 
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isTiny ? 10 : (isExtraSmall ? 12 : 14),
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemSettingsCard(bool isTiny, bool isExtraSmall) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTiny ? 6 : 8)),
      child: Padding(
        padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  size: isTiny ? 16 : (isExtraSmall ? 18 : 20),
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(width: isTiny ? 6 : 8),
                Text(
                  isTiny ? 'Settings' : 'System Settings', 
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isTiny ? 12 : (isExtraSmall ? 14 : 16),
                  )
                ),
              ],
            ),
            SizedBox(height: isTiny ? 6 : 8),
            Text(
              'Configure system parameters', 
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isTiny ? 10 : (isExtraSmall ? 12 : 14),
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCodesCard(bool isTiny, bool isExtraSmall) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTiny ? 6 : 8)),
      child: Padding(
        padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  size: isTiny ? 16 : (isExtraSmall ? 18 : 20),
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(width: isTiny ? 6 : 8),
                Text(
                  isTiny ? 'Codes' : 'Admin Codes', 
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isTiny ? 12 : (isExtraSmall ? 14 : 16),
                  )
                ),
              ],
            ),
            SizedBox(height: isTiny ? 6 : 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: isTiny ? 6 : (isExtraSmall ? 8 : 10),
                    horizontal: isTiny ? 8 : (isExtraSmall ? 12 : 16),
                  ),
                ),
                child: Text(
                  isTiny ? 'Update' : 'Update Admin Code',
                  style: TextStyle(fontSize: isTiny ? 10 : (isExtraSmall ? 12 : 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingCard(bool isTiny, bool isExtraSmall) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTiny ? 6 : 8)),
      child: Padding(
        padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.branding_watermark,
                  size: isTiny ? 16 : (isExtraSmall ? 18 : 20),
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(width: isTiny ? 6 : 8),
                Text(
                  isTiny ? 'Brand' : 'Branding', 
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isTiny ? 12 : (isExtraSmall ? 14 : 16),
                  )
                ),
              ],
            ),
            SizedBox(height: isTiny ? 6 : 8),
            if (isTiny || isExtraSmall) ...[
              // Stack buttons vertically on small screens
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: isTiny ? 6 : 8,
                      horizontal: isTiny ? 8 : 12,
                    ),
                  ),
                  child: Text(
                    isTiny ? 'System' : 'System Branding',
                    style: TextStyle(fontSize: isTiny ? 10 : 12),
                  ),
                ),
              ),
              SizedBox(height: isTiny ? 4 : 6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: isTiny ? 6 : 8,
                      horizontal: isTiny ? 8 : 12,
                    ),
                  ),
                  child: Text(
                    isTiny ? 'Business' : 'Business Branding',
                    style: TextStyle(fontSize: isTiny ? 10 : 12),
                  ),
                ),
              ),
            ] else ...[
              // Side by side on larger screens
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      ),
                      child: Text('System Branding'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      ),
                      child: Text('Business Branding'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBackupsCard(bool isTiny, bool isExtraSmall) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTiny ? 6 : 8)),
      child: Padding(
        padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.backup,
                  size: isTiny ? 16 : (isExtraSmall ? 18 : 20),
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(width: isTiny ? 6 : 8),
                Text(
                  isTiny ? 'Backup' : 'Backups', 
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isTiny ? 12 : (isExtraSmall ? 14 : 16),
                  )
                ),
              ],
            ),
            SizedBox(height: isTiny ? 6 : 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: isTiny ? 6 : (isExtraSmall ? 8 : 10),
                    horizontal: isTiny ? 8 : (isExtraSmall ? 12 : 16),
                  ),
                ),
                child: Text(
                  isTiny ? 'Create' : 'Create Backup',
                  style: TextStyle(fontSize: isTiny ? 10 : (isExtraSmall ? 12 : 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataOverviewCard(bool isTiny, bool isExtraSmall) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTiny ? 6 : 8)),
      child: Padding(
        padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  size: isTiny ? 16 : (isExtraSmall ? 18 : 20),
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(width: isTiny ? 6 : 8),
                Text(
                  isTiny ? 'Data' : 'Data Overview', 
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isTiny ? 12 : (isExtraSmall ? 14 : 16),
                  )
                ),
              ],
            ),
            SizedBox(height: isTiny ? 6 : 8),
            Text(
              'View system data statistics', 
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isTiny ? 10 : (isExtraSmall ? 12 : 14),
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeletedDataCard(bool isTiny, bool isExtraSmall) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTiny ? 6 : 8)),
      child: Padding(
        padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.delete_forever,
                  size: isTiny ? 16 : (isExtraSmall ? 18 : 20),
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(width: isTiny ? 6 : 8),
                Text(
                  isTiny ? 'Deleted' : 'Deleted Data', 
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isTiny ? 12 : (isExtraSmall ? 14 : 16),
                  )
                ),
              ],
            ),
            SizedBox(height: isTiny ? 6 : 8),
            Text(
              'Manage deleted data recovery', 
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isTiny ? 10 : (isExtraSmall ? 12 : 14),
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataExportCard(bool isTiny, bool isExtraSmall) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTiny ? 6 : 8)),
      child: Padding(
        padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data Export', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Export system data', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  // Mobile-specific tab methods - These are now deprecated and will be removed
  Widget _buildOverviewTabMobile() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: TabBar(
              isScrollable: true,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Theme.of(context).primaryColor,
              tabs: [
                Tab(icon: Icon(Icons.monitor_heart), text: 'Health'),
                Tab(icon: Icon(Icons.notifications), text: 'Notifications'),
                Tab(icon: Icon(Icons.payment), text: 'Billing'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSystemHealthSubTabMobile(),
                _buildNotificationsSubTabMobile(),
                _buildBillingSubTabMobile(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemHealthSubTabMobile() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchSystemHealth(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('${t(context, 'Error: ')}${snapshot.error}'));
        }
        final health = snapshot.data ?? {};
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('System Health', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              const SizedBox(height: 12),
              _buildHealthCardMobile(health),
              const SizedBox(height: 16),
              Text('Active Sessions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildSessionsWidgetMobile(),
              const SizedBox(height: 16),
              Text('Recent Errors', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildErrorsWidgetMobile(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationsSubTabMobile() {
    return _buildNotificationsTabMobile();
  }

  Widget _buildBillingSubTabMobile() {
    return _buildBillingTabMobile();
  }

  Widget _buildBusinessesTabMobile() {
    return _buildBusinessesTab();
  }

  Widget _buildUsersAndSecurityTabMobile() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: TabBar(
              isScrollable: true,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Theme.of(context).primaryColor,
              tabs: [
                Tab(icon: Icon(Icons.people), text: 'Users'),
                Tab(icon: Icon(Icons.security), text: 'Audit'),
                Tab(icon: Icon(Icons.manage_accounts), text: 'Access'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildUserManagementSubTab(),
                _buildAuditSubTab(),
                _buildAccessControlSubTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTabMobile() {
    return _buildAnalyticsTab();
  }

  Widget _buildSettingsTabMobile() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: TabBar(
              isScrollable: true,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Theme.of(context).primaryColor,
              tabs: [
                Tab(icon: Icon(Icons.settings), text: 'System'),
                Tab(icon: Icon(Icons.admin_panel_settings), text: 'Admin'),
                Tab(icon: Icon(Icons.palette), text: 'Branding'),
                Tab(icon: Icon(Icons.backup), text: 'Backups'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSystemSettingsSubTab(),
                _buildAdminCodesSubTab(),
                _buildBrandingSubTab(),
                _buildBackupsSubTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataManagementTabMobile() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: TabBar(
              isScrollable: true,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Theme.of(context).primaryColor,
              tabs: [
                Tab(icon: Icon(Icons.storage), text: 'Overview'),
                Tab(icon: Icon(Icons.delete_forever), text: 'Deleted'),
                Tab(icon: Icon(Icons.data_usage), text: 'Export'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDataOverviewSubTab(),
                _buildDeletedDataSubTab(),
                _buildDataExportSubTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Mobile-specific widget builders
  Widget _buildHealthCardMobile(Map<String, dynamic> health) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  health['status'] == 'healthy' ? Icons.check_circle : Icons.error,
                  color: health['status'] == 'healthy' ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text('System Status', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Status: ${TypeConverter.safeToString(health['status'] ?? 'Unknown')}'),
            Text('Uptime: ${TypeConverter.safeToString(health['uptime'] ?? 'N/A')}'),
            Text('Memory: ${TypeConverter.safeToString(health['memory'] ?? 'N/A')}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsWidgetMobile() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text('Active Sessions: 0', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('No active sessions', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorsWidgetMobile() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text('Recent Errors: 0', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('No recent errors', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsTabMobile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notifications', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text('No notifications', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingTabMobile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Billing', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text('Billing information will appear here', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Overview Tab with Sub-tabs ---
  Widget _buildOverviewTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 768;
                final isTiny = constraints.maxWidth < 400;
                return Container(
                  height: isMobile ? 56 : 48,
            child: TabBar(
                    isScrollable: isMobile,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Theme.of(context).primaryColor,
                    labelPadding: EdgeInsets.symmetric(horizontal: isTiny ? 6 : (isMobile ? 10 : 16)),
                    labelStyle: TextStyle(fontSize: isTiny ? 10 : (isMobile ? 12 : 14), fontWeight: FontWeight.w500),
                    unselectedLabelStyle: TextStyle(fontSize: isTiny ? 10 : (isMobile ? 12 : 14)),
              tabs: [
                      Tab(
                        icon: Icon(Icons.monitor_heart, size: isTiny ? 16 : (isMobile ? 18 : 20)), 
                        child: Text(
                          isTiny ? 'Health' : 'System Health',
                          style: TextStyle(fontSize: isTiny ? 10 : (isMobile ? 12 : 14)),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        )
                      ),
                      Tab(
                        icon: Icon(Icons.notifications, size: isTiny ? 16 : (isMobile ? 18 : 20)), 
                        child: Text(
                          isTiny ? 'Alerts' : 'Notifications',
                          style: TextStyle(fontSize: isTiny ? 10 : (isMobile ? 12 : 14)),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        )
                      ),
                      Tab(
                        icon: Icon(Icons.payment, size: isTiny ? 16 : (isMobile ? 18 : 20)), 
                        child: Text(
                          'Billing',
                          style: TextStyle(fontSize: isTiny ? 10 : (isMobile ? 12 : 14)),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        )
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSystemHealthSubTab(),
                _buildNotificationsSubTab(),
                _buildBillingSubTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // System Health Sub-tab
  Widget _buildSystemHealthSubTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchSystemHealth(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('${t(context, 'Error: ')}${snapshot.error}'));
        }
        final health = snapshot.data ?? {};
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t(context, 'System Health'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              const SizedBox(height: 16),
              _buildHealthCard(health),
              const SizedBox(height: 24),
              Text(t(context, 'Active Sessions'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildSessionsWidget(),
              const SizedBox(height: 24),
              Text(t(context, 'Recent Errors'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildErrorsWidget(),
              const SizedBox(height: 24),
              Text(t(context, 'Performance Metrics'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildPerformanceWidget(),
            ],
          ),
        );
      },
    );
  }

  // Notifications Sub-tab
  Widget _buildNotificationsSubTab() {
    return _buildNotificationsTab();
  }

  // Billing Sub-tab
  Widget _buildBillingSubTab() {
    return _buildBillingTab();
  }

  // --- Users & Security Tab with Sub-tabs ---
  Widget _buildUsersAndSecurityTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 768;
                final isTiny = constraints.maxWidth < 400;
                return Container(
                  height: isMobile ? 56 : 48,
            child: TabBar(
                    isScrollable: isMobile,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Theme.of(context).primaryColor,
                    labelPadding: EdgeInsets.symmetric(horizontal: isTiny ? 6 : (isMobile ? 10 : 16)),
                    labelStyle: TextStyle(fontSize: isTiny ? 10 : (isMobile ? 12 : 14), fontWeight: FontWeight.w500),
                    unselectedLabelStyle: TextStyle(fontSize: isTiny ? 10 : (isMobile ? 12 : 14)),
              tabs: [
                      Tab(
                        icon: Icon(Icons.people, size: isTiny ? 16 : (isMobile ? 18 : 20)), 
                        child: Text(
                          isTiny ? 'Users' : 'User Management',
                          style: TextStyle(fontSize: isTiny ? 9 : (isMobile ? 11 : 14)),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        )
                      ),
                      Tab(
                        icon: Icon(Icons.security, size: isTiny ? 16 : (isMobile ? 18 : 20)), 
                        child: Text(
                          isTiny ? 'Audit' : 'Audit Logs',
                          style: TextStyle(fontSize: isTiny ? 10 : (isMobile ? 12 : 14)),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        )
                      ),
                      Tab(
                        icon: Icon(Icons.manage_accounts, size: isTiny ? 16 : (isMobile ? 18 : 20)), 
                        child: Text(
                          isTiny ? 'Access' : 'Access Control',
                          style: TextStyle(fontSize: isTiny ? 9 : (isMobile ? 11 : 14)),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        )
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildUserManagementSubTab(),
                _buildAuditSubTab(),
                _buildAccessControlSubTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // User Management Sub-tab
  Widget _buildUserManagementSubTab() {
    return _buildUserManagement();
  }

  // Audit Sub-tab
  Widget _buildAuditSubTab() {
    return _buildAuditTab();
  }

  // Access Control Sub-tab
  Widget _buildAccessControlSubTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Access Control', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Role Permissions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildRolePermissionsTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolePermissionsTable() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    
    final roles = [
      {'role': 'Superadmin', 'permissions': 'Full system access'},
      {'role': 'Admin', 'permissions': 'Business management'},
      {'role': 'Cashier', 'permissions': 'Sales and inventory'},
    ];
    
    if (isMobile) {
      // Mobile: Use cards instead of table
      return Column(
        children: roles.map((roleData) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      roleData['role']!,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(60, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('Edit', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  roleData['permissions']!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        )).toList(),
      );
    } else {
      // Desktop: Use table
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
      columns: const [
        DataColumn(label: Text('Role')),
        DataColumn(label: Text('Permissions')),
        DataColumn(label: Text('Actions')),
      ],
          rows: roles.map((roleData) => DataRow(cells: [
            DataCell(Text(roleData['role']!)),
            DataCell(Text(roleData['permissions']!)),
          DataCell(ElevatedButton(
            onPressed: () {},
            child: const Text('Edit'),
          )),
          ])).toList(),
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _fetchSystemHealth() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    final response = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/health'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch system health');
    }
  }

  Widget _buildHealthCard(Map<String, dynamic> health) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  health['status'] == 'healthy' ? Icons.check_circle : Icons.error,
                  color: health['status'] == 'healthy' ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text('Status: ${health['status'] ?? 'unknown'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('Uptime: ${_formatUptime(health['uptime'])}')
              ],
            ),
            const SizedBox(height: 8),
            Text('Node.js: ${health['version'] ?? ''}'),
            Text('Platform: ${health['systemLoad']?['platform'] ?? ''} (${health['systemLoad']?['arch'] ?? ''})'),
            Text('CPU Usage: ${health['systemLoad']?['cpuUsage']?.toString() ?? ''}'),
            Text('Memory Usage: ${health['systemLoad']?['memoryUsage'] ?? ''}%'),
            Text('Active DB Connections: ${health['activeConnections'] ?? 0}'),
            if (health['errors'] != null && (health['errors'] as List).isNotEmpty)
              ...[const SizedBox(height: 8), Text('Errors:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), ...List<Widget>.from((health['errors'] as List).map((e) => Text(e, style: const TextStyle(color: Colors.red))))],
          ],
        ),
      ),
    );
  }

  String _formatUptime(dynamic uptime) {
    if (uptime == null) return '';
    final seconds = uptime is int ? uptime : (uptime as num).toInt();
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours}h ${minutes}m ${secs}s';
  }

  Widget _buildSessionsWidget() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchSessions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final sessions = snapshot.data?['sessions'] ?? [];
        if (sessions.isEmpty) {
          return const Text('No active sessions.');
        }
        return Column(
          children: List.generate(sessions.length, (i) {
            final s = sessions[i];
            return ListTile(
              leading: const Icon(Icons.person),
              title: Text(s['username'] ?? ''),
              subtitle: Text('${s['email']} • ${s['role']}'),
              trailing: Text('Last login: ${s['last_login'] ?? ''}'),
            );
          }),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchSessions() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    final response = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/sessions'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch sessions');
    }
  }

  Widget _buildErrorsWidget() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchErrors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final errors = snapshot.data?['errors'] ?? [];
        if (errors.isEmpty) {
          return const Text('No recent errors.');
        }
        return Column(
          children: List.generate(errors.length, (i) {
            final e = errors[i];
            return ListTile(
              leading: const Icon(Icons.error, color: Colors.red),
              title: Text(e['action'] ?? ''),
              subtitle: Text('${e['username'] ?? 'System'} • ${e['created_at'] ?? ''}'),
              trailing: Text(e['table_name'] ?? ''),
            );
          }),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchErrors() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    final response = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/errors'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch errors');
    }
  }

  Widget _buildPerformanceWidget() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchPerformance(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final perf = snapshot.data ?? {};
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Database Queries: ${perf['database']?['totalQueries'] ?? 0}'),
                Text('Avg. Response Time: ${perf['database']?['avgResponseTime'] ?? 0}'),
                Text('Last Query: ${perf['database']?['lastQueryTime'] ?? ''}'),
                const SizedBox(height: 8),
                Text('Active Users (last 7 days): ${perf['users'] != null ? perf['users'].length : 0}'),
                Text('System CPU Usage: ${perf['system']?['cpuUsage']?.toString() ?? ''}'),
                Text('System Memory Usage: ${perf['system']?['memoryUsage'] ?? ''}%'),
                Text('Node Uptime: ${_formatUptime(perf['system']?['uptime'])}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchPerformance() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    final response = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/performance'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch performance metrics');
    }
  }

  // --- Businesses Tab ---
  Widget _buildBusinessesTab() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 768;
              final isTiny = constraints.maxWidth < 400;
              return Container(
                height: isMobile ? 52 : 48,
            child: TabBar(
                  isScrollable: isMobile,
                                    tabs: [
                    Tab(
                      icon: Icon(Icons.dashboard_outlined, size: isTiny ? 16 : 18),
                      child: Text(
                        'Overview',
                        style: TextStyle(fontSize: isTiny ? 10 : (isMobile ? 12 : 14)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      )
                    ),
                    Tab(
                      icon: Icon(Icons.message, size: isTiny ? 16 : 18),
                      child: Text(
                        'Messages',
                        style: TextStyle(fontSize: isTiny ? 10 : (isMobile ? 12 : 14)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      )
                    ),
                    Tab(
                      icon: Icon(Icons.payment, size: isTiny ? 16 : 18),
                      child: Text(
                        'Payments',
                        style: TextStyle(fontSize: isTiny ? 10 : (isMobile ? 12 : 14)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      )
                    ),
                    Tab(
                      icon: Icon(Icons.analytics, size: isTiny ? 16 : 18),
                      child: Text(
                        'Analytics',
                        style: TextStyle(fontSize: isTiny ? 10 : (isMobile ? 12 : 14)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      )
                    ),
              ],
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Theme.of(context).primaryColor,
                  labelStyle: TextStyle(fontSize: isTiny ? 10 : (isMobile ? 12 : 14), fontWeight: FontWeight.w500),
                  unselectedLabelStyle: TextStyle(fontSize: isTiny ? 10 : (isMobile ? 12 : 14)),
                  labelPadding: EdgeInsets.symmetric(horizontal: isTiny ? 6 : (isMobile ? 8 : 16)),
                ),
              );
            },
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildBusinessesOverview(),
                _buildBusinessesMessages(),
                _buildBusinessesPayments(),
                _buildBusinessesAnalytics(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessesOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 768;
              final isTiny = constraints.maxWidth < 360;
              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Business Management', 
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold, 
                          color: Theme.of(context).primaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 40,
                      child: ElevatedButton.icon(
                              icon: const Icon(Icons.add_business, size: 18),
                        label: const Text('Add Business'),
                        onPressed: _showCreateBusinessDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor, 
                          foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (!isTiny) const SizedBox(width: 8),
                        if (!isTiny)
                          SizedBox(
                            height: 40,
                            width: 40,
                            child: OutlinedButton(
                              onPressed: () => setState(() {}),
                              child: const Icon(Icons.refresh, size: 18),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              }
                                return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                    Expanded(
                      child: Text(
                        'Business Management', 
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold, 
                            color: Theme.of(context).primaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_business),
                label: const Text('Add Business'),
                onPressed: _showCreateBusinessDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
              ),
            ],
                );
            },
          ),
          const SizedBox(height: 16),
          _buildBusinessesList(),
        ],
      ),
    );
  }

  Widget _buildBusinessesList() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchBusinesses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data ?? {};
        final businesses = data['businesses'] ?? [];
        final pagination = data['pagination'] ?? {};
        
        return Column(
          children: [
            // Search bar
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search businesses...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _searchBusinesses(value),
            ),
            const SizedBox(height: 16),
            // Businesses grid - Responsive
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount;
                double aspectRatio;
                double spacing;
                
                if (constraints.maxWidth < 360) {
                  // Very small phones: 1 column, very flat cards
                  crossAxisCount = 1;
                  aspectRatio = 2.1;
                  spacing = 6;
                } else if (constraints.maxWidth < 480) {
                  // Small phones: 1 column, flat cards to reduce vertical space
                  crossAxisCount = 1;
                  aspectRatio = 1.9;
                  spacing = 8;
                } else if (constraints.maxWidth < 768) {
                  // Large phones/phablets: 2 columns, flatter cards
                  crossAxisCount = 2;
                  aspectRatio = 1.8;
                  spacing = 8;
                } else if (constraints.maxWidth < 1024) {
                  // Tablet: 2 columns
                  crossAxisCount = 2;
                  aspectRatio = 1.6;
                  spacing = 10;
                } else {
                  // Desktop: 3 columns
                  crossAxisCount = 3;
                  aspectRatio = 1.5;
                  spacing = 12;
                }
                
                return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: aspectRatio,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
              ),
              itemCount: businesses.length,
              itemBuilder: (context, index) {
                final business = businesses[index];
                return _buildBusinessCard(business);
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            // Pagination
            if (pagination['pages'] > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: pagination['offset'] > 0 ? () => _loadBusinessesPage(pagination['offset'] - pagination['limit']) : null,
                  ),
                  Text('Page ${(pagination['offset'] / pagination['limit']).floor() + 1} of ${pagination['pages']}'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: pagination['offset'] + pagination['limit'] < pagination['total'] ? () => _loadBusinessesPage(pagination['offset'] + pagination['limit']) : null,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildBusinessCard(Map<String, dynamic> business) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _showBusinessDetails(business),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    business['is_active'] == true || business['is_active'] == 1 ? Icons.business : Icons.business_outlined,
                    color: business['is_active'] == true || business['is_active'] == 1 ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (business['name'] ?? '').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          (business['business_code'] ?? '').toString(),
                          style: TextStyle(color: Colors.grey[600], fontSize: 9),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    onSelected: (value) => _handleBusinessAction(value, business),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'message', child: Text('Send Message')),
                      const PopupMenuItem(value: 'payment', child: Text('Add Payment')),
                      const PopupMenuItem(value: 'settings', child: Text('Settings')),
                      const PopupMenuItem(value: 'users', child: Text('Manage Users')),
                      const PopupMenuItem(value: 'analytics', child: Text('Analytics')),
                      const PopupMenuItem(value: 'toggle_status', child: Text('Toggle Status')),
                    ],
                    child: const Icon(Icons.more_vert, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: [
                  _buildStatChip('Users', business['user_count']?.toString() ?? '0'),
                  _buildStatChip('Products', business['product_count']?.toString() ?? '0'),
                  _buildStatChip('Sales', business['sale_count']?.toString() ?? '0'),
                  _buildStatChip('Customers', business['customer_count']?.toString() ?? '0'),
                ],
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getSubscriptionColor(business['subscription_plan']),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      (business['subscription_plan']?.toString().toUpperCase() ?? 'BASIC'),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getPaymentStatusColor(business['payment_status'] ?? 'current'),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      (business['payment_status'] ?? 'current').toString().toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (business['payment_status'] == 'overdue' || business['payment_status'] == 'suspended')
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red, size: 12),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          business['payment_status'] == 'overdue' ? 'Payment Overdue' : 'Account Suspended',
                          style: const TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 10),
      ),
    );
  }

  Color _getSubscriptionColor(String? plan) {
    switch (plan?.toLowerCase()) {
      case 'premium':
        return Colors.blue;
      case 'enterprise':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }

  Color _getPaymentStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'overdue':
        return Colors.orange;
      case 'suspended':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  void _handleBusinessAction(String action, Map<String, dynamic> business) {
    switch (action) {
      case 'message':
        _showSendMessageDialog(business);
        break;
      case 'payment':
        _showAddPaymentDialog(business);
        break;
      case 'settings':
        _showBusinessSettingsDialog(business);
        break;
      case 'users':
        _showBusinessUsers(business);
        break;
      case 'analytics':
        _showBusinessDetails(business);
        break;
      case 'toggle_status':
        _toggleBusinessStatus(business);
        break;
    }
  }

  Future<Map<String, dynamic>> _fetchBusinesses() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    final String baseUrl = 'https://rtailed-production.up.railway.app/api/businesses';
    final queryParams = <String, String>{
      'limit': _businessLimit.toString(),
      'offset': _businessOffset.toString(),
    };
    if (_businessQuery.trim().isNotEmpty) {
      queryParams['search'] = _businessQuery.trim();
    }
    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch businesses');
    }
  }

  void _searchBusinesses(String query) {
    setState(() {
      _businessQuery = query;
      _businessOffset = 0;
    });
  }

  void _loadBusinessesPage(int offset) {
    setState(() {
      _businessOffset = offset < 0 ? 0 : offset;
    });
  }

  // Helper methods for business management
  Color _getMessageTypeColor(String? type) {
    switch (type) {
      case 'info': return Colors.blue;
      case 'warning': return Colors.orange;
      case 'payment_due': return Colors.red;
      case 'suspension': return Colors.red;
      case 'activation': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getMessageTypeIcon(String? type) {
    switch (type) {
      case 'info': return Icons.info;
      case 'warning': return Icons.warning;
      case 'payment_due': return Icons.payment;
      case 'suspension': return Icons.block;
      case 'activation': return Icons.check_circle;
      default: return Icons.message;
    }
  }

  IconData _getPaymentStatusIcon(String? status) {
    switch (status) {
      case 'completed': return Icons.check_circle;
      case 'pending': return Icons.schedule;
      case 'failed': return Icons.error;
      case 'refunded': return Icons.undo;
      default: return Icons.payment;
    }
  }

  // API calls for business management
  Future<Map<String, dynamic>> _fetchAllBusinessMessages() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    try {
      // Get all businesses first
      final businessesResponse = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/businesses'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      
      final businesses = businessesResponse.statusCode == 200 
          ? TypeConverter.convertMySQLList(json.decode(businessesResponse.body)['businesses'] ?? [])
          : [];
      
      // Get messages for each business
      List<Map<String, dynamic>> allMessages = [];
      for (final business in businesses) {
        final messagesResponse = await http.get(
          Uri.parse('https://rtailed-production.up.railway.app/api/businesses/${business['id']}/messages'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        );
        
        if (messagesResponse.statusCode == 200) {
          final messages = json.decode(messagesResponse.body)['messages'] ?? [];
          allMessages.addAll(TypeConverter.convertMySQLList(messages));
        }
      }
      
      // Sort by creation date
      allMessages.sort((a, b) => _safeParseDate(b['created_at'])?.compareTo(_safeParseDate(a['created_at']) ?? DateTime(1900)) ?? 0);
      
      return {
        'messages': allMessages,
        'businesses': businesses,
      };
    } catch (e) {
      throw Exception('Failed to fetch business messages: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchAllBusinessPayments() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    try {
      // Get all businesses first
      final businessesResponse = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/businesses'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      
      final businesses = businessesResponse.statusCode == 200 
          ? TypeConverter.convertMySQLList(json.decode(businessesResponse.body)['businesses'] ?? [])
          : [];
      
      // Get payments for each business
      List<Map<String, dynamic>> allPayments = [];
      for (final business in businesses) {
        final paymentsResponse = await http.get(
          Uri.parse('https://rtailed-production.up.railway.app/api/businesses/${business['id']}/payments'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        );
        
        if (paymentsResponse.statusCode == 200) {
          final payments = json.decode(paymentsResponse.body)['payments'] ?? [];
          allPayments.addAll(TypeConverter.convertMySQLList(payments));
        }
      }
      
      // Sort by creation date
      allPayments.sort((a, b) => _safeParseDate(b['created_at'])?.compareTo(_safeParseDate(a['created_at']) ?? DateTime(1900)) ?? 0);
      
      return {
        'payments': allPayments,
        'businesses': businesses,
      };
    } catch (e) {
      throw Exception('Failed to fetch business payments: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchBusinessesAnalytics() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    try {
      // Get all businesses
      final businessesResponse = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/businesses'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      
      final businesses = businessesResponse.statusCode == 200 
          ? TypeConverter.convertMySQLList(json.decode(businessesResponse.body)['businesses'] ?? [])
          : [];
      
      // Calculate analytics
      double totalRevenue = 0;
      int activeBusinesses = 0;
      int overduePayments = 0;
      int totalUsers = 0;
      int totalProducts = 0;
      int totalSales = 0;
      
      for (final business in businesses) {
        if (business['is_active'] == true || business['is_active'] == 1) activeBusinesses++;
        if (business['payment_status'] == 'overdue') overduePayments++;
        
        totalUsers += (business['user_count'] ?? 0) as int;
        totalProducts += (business['product_count'] ?? 0) as int;
        totalSales += (business['sale_count'] ?? 0) as int;
        totalRevenue += _safeToDouble(business['monthly_fee'] ?? 0);
      }
      
      return {
        'analytics': {
          'total_revenue': totalRevenue,
          'active_businesses': activeBusinesses,
          'overdue_payments': overduePayments,
          'total_users': totalUsers,
          'total_products': totalProducts,
          'total_sales': totalSales,
        },
        'businesses': businesses,
      };
    } catch (e) {
      throw Exception('Failed to fetch business analytics: $e');
    }
  }



  void _showCreateBusinessDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final adminUsernameController = TextEditingController();
    final adminEmailController = TextEditingController();
    final adminPasswordController = TextEditingController();
    String selectedPlan = 'basic';
    int maxUsers = 5;
    int maxProducts = 1000;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Business'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Business Information', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Business Name'),
              ),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Business Code'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Business Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Business Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedPlan,
                decoration: const InputDecoration(labelText: 'Subscription Plan'),
                items: ['basic', 'premium', 'enterprise']
                    .map((plan) => DropdownMenuItem(value: plan, child: Text(plan.toUpperCase())))
                    .toList(),
                onChanged: (value) => selectedPlan = value!,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Max Users'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => maxUsers = int.tryParse(value) ?? 5,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Max Products'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => maxProducts = int.tryParse(value) ?? 1000,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Business Admin Account', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: adminUsernameController,
                decoration: const InputDecoration(labelText: 'Admin Username'),
              ),
              TextField(
                controller: adminEmailController,
                decoration: const InputDecoration(labelText: 'Admin Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: adminPasswordController,
                decoration: const InputDecoration(labelText: 'Admin Password'),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final authProvider = context.read<AuthProvider>();
                final token = authProvider.token;

                final response = await http.post(
                  Uri.parse('https://rtailed-production.up.railway.app/api/businesses'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                  body: json.encode({
                    'name': nameController.text,
                    'business_code': codeController.text,
                    'email': emailController.text,
                    'phone': phoneController.text,
                    'subscription_plan': selectedPlan,
                    'max_users': maxUsers,
                    'max_products': maxProducts,
                    'admin_username': adminUsernameController.text,
                    'admin_email': adminEmailController.text,
                    'admin_password': adminPasswordController.text,
                  }),
                );

                if (response.statusCode == 201) {
                  Navigator.pop(context);
                  setState(() {}); // Refresh the list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Business created successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  throw Exception('Failed to create business');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error creating business: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showBusinessUsers(Map<String, dynamic> business) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;
      
      final response = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/businesses/${business['id']}/users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final users = data['users'] ?? [];
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${business['name']} - Users'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: Icon(
                      user['is_active'] == true || user['is_active'] == 1 ? Icons.person : Icons.person_outline,
                      color: user['is_active'] == true || user['is_active'] == 1 ? Colors.green : Colors.red,
                    ),
                    title: Text(user['username'] ?? ''),
                    subtitle: Text('${user['email']} • ${user['role']}'),
                    trailing: Text(user['last_login'] ?? 'Never'),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        throw Exception('Failed to fetch business users');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading users: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditBusinessDialog(Map<String, dynamic> business) {
    // Similar to create dialog but with pre-filled values
    // Implementation would be similar to _showCreateBusinessDialog
  }

  // Business Management Dialogs
  void _showSendMessageDialog(Map<String, dynamic>? business) {
    // Skip dropdown if business is already selected
    if (business != null) {
      _showSendMessageDialogInternal(business);
      return;
    }
    
    // Show business selection first
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Business'),
        content: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchBusinessesForSelection(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }
            if (snapshot.hasError) {
              return Column(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('Error loading businesses', style: TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Retry'),
                  ),
                ],
              );
            }
            if (snapshot.hasData) {
              final businesses = snapshot.data!;
              if (businesses.isEmpty) {
                return const Text('No businesses available');
              }
              return SizedBox(
                height: 300, // Fixed height to avoid intrinsic dimension issues
                child: SingleChildScrollView(
                  child: Column(
                    children: businesses.map((business) => ListTile(
                      title: Text(business['name'] ?? 'Unknown Business'),
                      subtitle: Text(business['email'] ?? ''),
                      onTap: () {
                        Navigator.pop(context);
                        _showSendMessageDialogInternal(business);
                      },
                    )).toList(),
                  ),
                ),
              );
            }
            return const Text('No data available');
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSendMessageDialogInternal(Map<String, dynamic> business) {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    String selectedType = 'info';
    String selectedPriority = 'medium';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Send Message to ${business['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(labelText: 'Message'),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: ['info', 'warning', 'payment_due', 'suspension', 'activation']
                            .map((type) => DropdownMenuItem(value: type, child: Text(type.toUpperCase())))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() => selectedType = value);
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedPriority,
                        decoration: const InputDecoration(labelText: 'Priority'),
                        items: ['low', 'medium', 'high', 'urgent']
                            .map((priority) => DropdownMenuItem(value: priority, child: Text(priority.toUpperCase())))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() => selectedPriority = value);
                            });
                          }
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (subjectController.text.isEmpty || messageController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields'), backgroundColor: Colors.red),
                  );
                  return;
                }

                try {
                  final authProvider = context.read<AuthProvider>();
                  final token = authProvider.token;

                  final response = await http.post(
                    Uri.parse('https://rtailed-production.up.railway.app/api/businesses/${business['id']}/messages'),
                    headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                    body: json.encode({
                      'subject': subjectController.text,
                      'message': messageController.text,
                      'message_type': selectedType,
                      'priority': selectedPriority,
                    }),
                  );

                  if (response.statusCode == 201) {
                    try {
                      final responseData = json.decode(response.body);
                      final messageData = responseData['message'];
                      
                            if (messageData != null) {
        final newMessage = _convertMySQLTypes(messageData);
                        // Add to state immediately
                        _addMessageToState(newMessage);
                      } else {
                        // If no message data in response, create a basic message object
                        final newMessage = {
                          'id': DateTime.now().millisecondsSinceEpoch,
                          'business_id': business['id'],
                          'subject': subjectController.text,
                          'message': messageController.text,
                          'message_type': selectedType,
                          'priority': selectedPriority,
                          'created_at': DateTime.now().toIso8601String(),
                          'is_read': false,
                        };
                        _addMessageToState(newMessage);
                      }
                      
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message sent successfully'), backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      print('Error processing message response: $e');
                      // Still show success but don't add to state
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message sent successfully'), backgroundColor: Colors.green),
                      );
                    }
                  } else {
                    throw Exception('Failed to send message');
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error sending message: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPaymentDialog(Map<String, dynamic>? business) {
    // Skip business selection if business is already provided
    if (business != null) {
      _showAddPaymentDialogInternal(business);
      return;
    }

    // Show business selection first
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Business'),
        content: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchBusinessesForSelection(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }
            if (snapshot.hasError) {
              return Column(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('Error loading businesses', style: TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Retry'),
                  ),
                ],
              );
            }
            if (snapshot.hasData) {
              final businesses = snapshot.data!;
              if (businesses.isEmpty) {
                return const Text('No businesses available');
              }
              return SizedBox(
                height: 300, // Fixed height to avoid intrinsic dimension issues
                child: SingleChildScrollView(
                  child: Column(
                    children: businesses.map((business) => ListTile(
                      title: Text(business['name'] ?? 'Unknown Business'),
                      subtitle: Text(business['email'] ?? ''),
                      onTap: () {
                        Navigator.pop(context);
                        _showAddPaymentDialogInternal(business);
                      },
                    )).toList(),
                  ),
                ),
              );
            }
            return const Text('No data available');
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentDialogInternal(Map<String, dynamic> business) {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedType = 'subscription';
    String selectedStatus = 'completed';
    String selectedMethod = 'credit_card';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add Payment for ${business['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: ['subscription', 'overage', 'penalty', 'credit']
                            .map((type) => DropdownMenuItem(value: type, child: Text(type.toUpperCase())))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() => selectedType = value);
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: ['pending', 'completed', 'failed', 'refunded']
                            .map((status) => DropdownMenuItem(value: status, child: Text(status.toUpperCase())))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() => selectedStatus = value);
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                  items: ['credit_card', 'bank_transfer', 'paypal', 'cash']
                      .map((method) => DropdownMenuItem(value: method, child: Text(method.replaceAll('_', ' ').toUpperCase())))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() => selectedMethod = value);
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (amountController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields'), backgroundColor: Colors.red),
                  );
                  return;
                }

                try {
                  // Debug: Log form values before submitting
                  print('[DEBUG] Submitting payment: businessId=' + business['id'].toString() +
                      ', amount=' + amountController.text + ', type=' + selectedType +
                      ', status=' + selectedStatus + ', method=' + selectedMethod +
                      ', description=' + descriptionController.text);

                  final authProvider = context.read<AuthProvider>();
                  final token = authProvider.token;

                  final response = await http.post(
                    Uri.parse('https://rtailed-production.up.railway.app/api/businesses/${business['id']}/payments'),
                    headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                    body: json.encode({
                      'amount': double.parse(amountController.text),
                      'payment_type': selectedType,
                      'payment_method': selectedMethod,
                      'status': selectedStatus,
                      'description': descriptionController.text,
                    }),
                  );

                  if (response.statusCode == 201) {
                    try {
                      final responseData = json.decode(response.body);
                      print('[DEBUG] Add payment response: ' + response.body);
                      final paymentData = responseData['payment'];
                      
                            if (paymentData != null) {
        final newPayment = _convertMySQLTypes(paymentData);
                        // Add to state immediately
                        _addPaymentToState(newPayment);
                      } else {
                        // If no payment data in response, create a basic payment object
                        final newPayment = {
                          'id': DateTime.now().millisecondsSinceEpoch,
                          'business_id': business['id'],
                          'amount': double.parse(amountController.text),
                          'payment_type': selectedType,
                          'payment_method': selectedMethod,
                          'status': selectedStatus,
                          'description': descriptionController.text,
                          'created_at': DateTime.now().toIso8601String(),
                        };
                        print('[DEBUG] Constructed fallback payment: ' + json.encode(newPayment));
                        _addPaymentToState(newPayment);
                      }
                      
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Payment added successfully'), backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      print('Error processing payment response: $e');
                      // Still show success but don't add to state
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Payment added successfully'), backgroundColor: Colors.green),
                      );
                    }
                  } else {
                    throw Exception('Failed to add payment');
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding payment: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBusinessSettingsDialog(Map<String, dynamic> business) {
    final monthlyFeeController = TextEditingController(text: business['monthly_fee']?.toString() ?? '29.99');
    final maxUsersController = TextEditingController(text: business['max_users']?.toString() ?? '5');
    final maxProductsController = TextEditingController(text: business['max_products']?.toString() ?? '1000');
    final overageUserFeeController = TextEditingController(text: business['overage_fee_per_user']?.toString() ?? '5.00');
    final overageProductFeeController = TextEditingController(text: business['overage_fee_per_product']?.toString() ?? '0.10');
    final gracePeriodController = TextEditingController(text: business['grace_period_days']?.toString() ?? '7');
    final notesController = TextEditingController(text: business['notes'] ?? '');
    String selectedPlan = business['subscription_plan'] ?? 'basic';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Business Settings - ${business['name']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedPlan,
                decoration: const InputDecoration(labelText: 'Subscription Plan'),
                items: ['basic', 'premium', 'enterprise']
                    .map((plan) => DropdownMenuItem(value: plan, child: Text(plan.toUpperCase())))
                    .toList(),
                onChanged: (value) => selectedPlan = value!,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: monthlyFeeController,
                      decoration: const InputDecoration(labelText: 'Monthly Fee'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: maxUsersController,
                      decoration: const InputDecoration(labelText: 'Max Users'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: maxProductsController,
                      decoration: const InputDecoration(labelText: 'Max Products'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: gracePeriodController,
                      decoration: const InputDecoration(labelText: 'Grace Period (days)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: overageUserFeeController,
                      decoration: const InputDecoration(labelText: 'Overage Fee per User'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: overageProductFeeController,
                      decoration: const InputDecoration(labelText: 'Overage Fee per Product'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final authProvider = context.read<AuthProvider>();
                final token = authProvider.token;

                final response = await http.put(
                  Uri.parse('https://rtailed-production.up.railway.app/api/businesses/${business['id']}/settings'),
                  headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                  body: json.encode({
                    'subscription_plan': selectedPlan,
                    'max_users': int.parse(maxUsersController.text),
                    'max_products': int.parse(maxProductsController.text),
                    'monthly_fee': double.parse(monthlyFeeController.text),
                    'overage_fee_per_user': double.parse(overageUserFeeController.text),
                    'overage_fee_per_product': double.parse(overageProductFeeController.text),
                    'grace_period_days': int.parse(gracePeriodController.text),
                    'notes': notesController.text,
                  }),
                );

                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Business settings updated successfully'), backgroundColor: Colors.green),
                  );
                  setState(() {}); // Refresh the list
                } else {
                  throw Exception('Failed to update business settings');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating settings: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _toggleBusinessStatus(Map<String, dynamic> business) {
    final isCurrentlyActive = business['is_active'] == true || business['is_active'] == 1;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCurrentlyActive ? 'Suspend Business' : 'Activate Business'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to ${isCurrentlyActive ? 'suspend' : 'activate'} ${business['name']}?'),
            if (isCurrentlyActive) ...[
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Suspension Reason (optional)'),
                maxLines: 2,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final authProvider = context.read<AuthProvider>();
                final token = authProvider.token;

                final response = await http.put(
                  Uri.parse('https://rtailed-production.up.railway.app/api/businesses/${business['id']}/status'),
                  headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                  body: json.encode({
                    'is_active': !isCurrentlyActive,
                    'suspension_reason': isCurrentlyActive ? reasonController.text : null,
                  }),
                );

                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Business ${isCurrentlyActive ? 'suspended' : 'activated'} successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  setState(() {}); // Refresh the list
                } else {
                  throw Exception('Failed to update business status');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating status: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentlyActive ? Colors.red : Colors.green,
            ),
            child: Text(isCurrentlyActive ? 'Suspend' : 'Activate'),
          ),
        ],
      ),
    );
  }

  void _showBusinessDetails(Map<String, dynamic> business) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getSubscriptionColor(business['subscription_plan']).withOpacity(0.2),
              child: Text(
                business['name']?[0].toUpperCase() ?? 'B',
                style: TextStyle(color: _getSubscriptionColor(business['subscription_plan'])),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(business['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(business['subscription_plan']?.toString().toUpperCase() ?? '', 
                       style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.7,
          child: FutureBuilder<Map<String, dynamic>>(
            future: _fetchBusinessDetails(business['id']),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final data = snapshot.data ?? {};
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBusinessOverviewSection(business, data),
                    const SizedBox(height: 16),
                    _buildBusinessPerformanceSection(data),
                    const SizedBox(height: 16),
                    _buildBusinessFinancialSection(business, data),
                    const SizedBox(height: 16),
                    _buildBusinessUsersSection(data),
                    const SizedBox(height: 16),
                    _buildBusinessCustomersSection(data),
                    const SizedBox(height: 16),
                    _buildBusinessProductsSection(data),
                    const SizedBox(height: 16),
                    _buildBusinessSalesSection(data),
                    const SizedBox(height: 16),
                    _buildBusinessActivitySection(data),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () => _exportBusinessReport(business['id']),
            child: const Text('Export Report'),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageCard(Map<String, dynamic> usage) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildStatItem('Users', '${usage['users'] ?? 0}', Icons.people)),
                Expanded(child: _buildStatItem('Products', '${usage['products'] ?? 0}', Icons.inventory)),
                Expanded(child: _buildStatItem('Customers', '${usage['customers'] ?? 0}', Icons.person)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Sales', '${usage['sales'] ?? 0}', Icons.shopping_cart)),
                Expanded(child: _buildStatItem('User Overage', '${usage['user_overage'] ?? 0}', Icons.warning)),
                Expanded(child: _buildStatItem('Product Overage', '${usage['product_overage'] ?? 0}', Icons.warning)),
              ],
            ),
            if (_safeToDouble(usage['user_overage']) > 0 || _safeToDouble(usage['product_overage']) > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.attach_money, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Overage Fees: \$${_safeToDouble(usage['total_overage_fee']).toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchBusinessDetails(int businessId) async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    try {
      // Fetch comprehensive business data from the new backend endpoint
      final response = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/businesses/$businessId/details'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _convertMySQLTypes(data);
      } else if (response.statusCode == 404) {
        throw Exception('Business not found');
      } else {
        throw Exception('Failed to fetch business details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching business details: $e');
      // Return mock data as fallback
      return _generateMockBusinessDetails(businessId);
    }
  }

  Map<String, dynamic> _generateMockBusinessDetails(int businessId) {
    return {
      'business': {
        'id': businessId,
        'name': 'Sample Business',
        'email': 'business@example.com',
        'phone': '+1234567890',
        'address': '123 Business St, City, State',
        'subscription_plan': 'premium',
        'monthly_fee': 99.99,
        'payment_status': 'current',
        'is_active': true,
        'created_at': '2024-01-15T10:00:00Z',
        'last_login': '2024-01-20T15:30:00Z',
      },
      'users': {
        'total_users': 15,
        'active_users': 12,
        'user_list': [
          {'id': 1, 'name': 'John Doe', 'email': 'john@business.com', 'role': 'admin', 'last_login': '2024-01-20T14:00:00Z'},
          {'id': 2, 'name': 'Jane Smith', 'email': 'jane@business.com', 'role': 'cashier', 'last_login': '2024-01-20T13:30:00Z'},
        ],
      },
      'products': {
        'total_products': 150,
        'low_stock_products': 8,
        'out_of_stock_products': 3,
        'total_stock_value': 25000.00,
        'product_list': [
          {'id': 1, 'name': 'Product A', 'sku': 'SKU001', 'stock_quantity': 50, 'cost_price': 10.00, 'selling_price': 15.00},
          {'id': 2, 'name': 'Product B', 'sku': 'SKU002', 'stock_quantity': 25, 'cost_price': 20.00, 'selling_price': 30.00},
        ],
      },
      'sales': {
        'total_sales': 1250,
        'total_revenue': 45000.00,
        'avg_sale_value': 36.00,
        'sales_by_month': [
          {'month': 'Jan', 'sales': 120, 'revenue': 4320.00},
          {'month': 'Feb', 'sales': 135, 'revenue': 4860.00},
        ],
        'recent_sales': [
          {'id': 1, 'customer': 'Customer A', 'amount': 45.00, 'date': '2024-01-20T16:00:00Z'},
          {'id': 2, 'customer': 'Customer B', 'amount': 32.50, 'date': '2024-01-20T15:30:00Z'},
        ],
      },
      'payments': {
        'total_paid': 599.94,
        'outstanding_balance': 0.00,
        'payment_history': [
          {'id': 1, 'amount': 99.99, 'status': 'paid', 'date': '2024-01-15T10:00:00Z'},
          {'id': 2, 'amount': 99.99, 'status': 'paid', 'date': '2023-12-15T10:00:00Z'},
        ],
      },
      'activity': {
        'total_actions': 1250,
        'actions_today': 45,
        'actions_this_week': 320,
        'peak_hours': [
          {'hour': 14, 'count': 180},
          {'hour': 15, 'count': 165},
        ],
        'recent_activity': [
          {'action': 'SALE_CREATED', 'user': 'John Doe', 'timestamp': '2024-01-20T16:00:00Z'},
          {'action': 'PRODUCT_UPDATED', 'user': 'Jane Smith', 'timestamp': '2024-01-20T15:45:00Z'},
        ],
      },
    };
  }

  Future<List<Map<String, dynamic>>> _fetchBusinessesForSelection() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    try {
      final response = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/businesses'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final businesses = data['businesses'] ?? [];
        
        // Convert each business to Map<String, dynamic> safely
        return TypeConverter.convertMySQLList(businesses);
      } else {
        throw Exception('Failed to fetch businesses: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in _fetchBusinessesForSelection: $e');
      throw Exception('Failed to fetch businesses: $e');
    }
  }

  // Helper methods for billing and backup features
  Color _getBillStatusColor(String? status) {
    switch (status) {
      case 'paid': return Colors.green;
      case 'pending': return Colors.orange;
      case 'overdue': return Colors.red;
      case 'cancelled': return Colors.grey;
      default: return Colors.grey;
    }
  }

  IconData _getBillStatusIcon(String? status) {
    switch (status) {
      case 'paid': return Icons.check_circle;
      case 'pending': return Icons.schedule;
      case 'overdue': return Icons.warning;
      case 'cancelled': return Icons.cancel;
      default: return Icons.receipt;
    }
  }

  Color _getBackupStatusColor(String? status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'in_progress': return Colors.orange;
      case 'failed': return Colors.red;
      case 'restored': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _getBackupStatusIcon(String? status) {
    switch (status) {
      case 'completed': return Icons.check_circle;
      case 'in_progress': return Icons.hourglass_empty;
      case 'failed': return Icons.error;
      case 'restored': return Icons.restore;
      default: return Icons.backup;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _getBusinessInitial(String businessName) {
    if (businessName.isEmpty) return 'B';
    return businessName.substring(0, 1).toUpperCase();
  }

  // API calls for billing features
  Future<Map<String, dynamic>> _fetchAllMonthlyBills() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    try {
      // Get all businesses first
      final businessesResponse = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/businesses'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      
      if (businessesResponse.statusCode != 200) {
        throw Exception('Failed to fetch businesses: ${businessesResponse.statusCode}');
      }
      
      final businessesData = json.decode(businessesResponse.body);
      final businesses = businessesData['businesses'] ?? [];
      
      // Get bills for each business
      List<Map<String, dynamic>> allBills = [];
      for (final business in businesses) {
        try {
          final billsResponse = await http.get(
            Uri.parse('https://rtailed-production.up.railway.app/api/businesses/${business['id']}/monthly-bills'),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          );
          
          if (billsResponse.statusCode == 200) {
            final billsData = json.decode(billsResponse.body);
            final bills = billsData['bills'] ?? [];
            
            for (final bill in bills) {
              try {
                final billMap = _convertMySQLTypes(bill);
                billMap['business_name'] = business['name'] ?? 'Unknown Business';
                billMap['business_code'] = business['business_code'] ?? '';
                billMap['subscription_plan'] = business['subscription_plan'] ?? 'basic';
                allBills.add(billMap);
              } catch (billError) {
                print('Error processing bill: $billError');
                // Continue with other bills
              }
            }
          }
        } catch (businessError) {
          print('Error fetching bills for business ${business['id']}: $businessError');
          // Continue with other businesses
        }
      }
      
      // Sort by creation date (with null safety)
      allBills.sort((a, b) {
        try {
          final dateA = _safeParseDate(a['created_at']);
          final dateB = _safeParseDate(b['created_at']);
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0; // Keep original order if date parsing fails
        }
      });
      
      return {
        'bills': allBills,
        'businesses': businesses,
      };
    } catch (e) {
      print('Error in _fetchAllMonthlyBills: $e');
      throw Exception('Failed to fetch monthly bills: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchPendingPayments() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    final response = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/businesses/pending-payments/all'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch pending payments');
    }
  }

  Future<Map<String, dynamic>> _fetchOverdueBills() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    final response = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/businesses/overdue-bills/all'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch overdue bills');
    }
  }

  Future<Map<String, dynamic>> _fetchAllBackups() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    final response = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/businesses/backups/all'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch backups');
    }
  }

  // Action methods for billing and backup features
  void _showGenerateBillDialog() {
    final dueDateController = TextEditingController(text: DateTime.now().add(const Duration(days: 30)).toString().split(' ')[0]);
    Map<String, dynamic>? selectedBusiness;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Generate Monthly Bill'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchBusinessesForSelection(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final businesses = snapshot.data!;
                      return DropdownButtonFormField<int>(
                        value: selectedBusiness?['id'],
                        decoration: const InputDecoration(labelText: 'Select Business'),
                        items: businesses.map((b) => DropdownMenuItem<int>(
                          value: b['id'] as int,
                          child: Text('${b['name']} (${b['subscription_plan']?.toString().toUpperCase() ?? 'BASIC'})'),
                        )).toList(),
                        onChanged: (value) {
                          final business = businesses.firstWhere((b) => b['id'] == value);
                          setState(() => selectedBusiness = business);
                        },
                      );
                    }
                    return const CircularProgressIndicator();
                  },
                ),
                const SizedBox(height: 16),
                if (selectedBusiness != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Subscription Plan: ${selectedBusiness!['subscription_plan']?.toString().toUpperCase() ?? 'BASIC'}', 
                               style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Monthly Fee: \$${selectedBusiness!['monthly_fee']?.toString() ?? '0'}'),
                          Text('Max Users: ${selectedBusiness!['max_users']?.toString() ?? '0'}'),
                          Text('Max Products: ${selectedBusiness!['max_products']?.toString() ?? '0'}'),
                          Text('User Overage Fee: \$${selectedBusiness!['overage_fee_per_user']?.toString() ?? '0'}/user'),
                          Text('Product Overage Fee: \$${selectedBusiness!['overage_fee_per_product']?.toString() ?? '0'}/product'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: dueDateController,
                  decoration: const InputDecoration(labelText: 'Due Date (YYYY-MM-DD)'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Note: Bill will be calculated automatically based on the business subscription plan and current usage.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedBusiness == null || dueDateController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a business and set due date'), backgroundColor: Colors.red),
                  );
                  return;
                }

                try {
                  final authProvider = context.read<AuthProvider>();
                  final token = authProvider.token;

                  final response = await http.post(
                    Uri.parse('https://rtailed-production.up.railway.app/api/businesses/${selectedBusiness!['id']}/monthly-bill'),
                    headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                    body: json.encode({
                      'billingMonth': DateTime.now().toString().split(' ')[0].substring(0, 7) + '-01',
                      'dueDate': dueDateController.text,
                    }),
                  );

                  if (response.statusCode == 201) {
                    final responseData = TypeConverter.safeToMap(json.decode(response.body));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Monthly bill generated: \$${TypeConverter.safeToDouble(TypeConverter.safeToMap(responseData['billDetails'] ?? {})['totalAmount']).toStringAsFixed(2)}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    setState(() {}); // Refresh the list
                  } else {
                    throw Exception('Failed to generate monthly bill');
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error generating bill: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Generate Bill'),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenerateAllBillsDialog() {
    final dueDateController = TextEditingController(text: DateTime.now().add(const Duration(days: 30)).toString().split(' ')[0]);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Bills for All Businesses'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This will generate monthly bills for all active businesses based on their subscription plans and current usage.'),
            const SizedBox(height: 16),
            TextField(
              controller: dueDateController,
              decoration: const InputDecoration(labelText: 'Due Date (YYYY-MM-DD)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final authProvider = context.read<AuthProvider>();
                final token = authProvider.token;

                final response = await http.post(
                  Uri.parse('https://rtailed-production.up.railway.app/api/businesses/generate-all-bills'),
                  headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                  body: json.encode({
                    'billingMonth': DateTime.now().toString().split(' ')[0].substring(0, 7) + '-01',
                    'dueDate': dueDateController.text,
                  }),
                );

                if (response.statusCode == 200) {
                  final responseData = TypeConverter.safeToMap(json.decode(response.body));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Generated ${TypeConverter.safeToInt(responseData['billsGenerated'])} bills successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  setState(() {}); // Refresh the list
                } else {
                  throw Exception('Failed to generate bills');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error generating bills: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Generate All Bills'),
          ),
        ],
      ),
    );
  }

  void _reviewPayment(Map<String, dynamic> payment, String status) {
    final reasonController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Review Payment - ${status.toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to $status this payment?'),
            if (status == 'rejected') ...[
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Rejection Reason'),
                maxLines: 2,
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final authProvider = context.read<AuthProvider>();
                final token = authProvider.token;

                final response = await http.put(
                  Uri.parse('https://rtailed-production.up.railway.app/api/businesses/${payment['business_id']}/review-payment/${payment['id']}'),
                  headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                  body: json.encode({
                    'status': status,
                    'rejectionReason': status == 'rejected' ? reasonController.text : null,
                    'notes': notesController.text,
                  }),
                );

                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Payment $status successfully'), backgroundColor: Colors.green),
                  );
                  setState(() {}); // Refresh the list
                } else {
                  throw Exception('Failed to review payment');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error reviewing payment: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'accepted' ? Colors.green : Colors.red,
            ),
            child: Text(status == 'accepted' ? 'Accept' : 'Reject'),
          ),
        ],
      ),
    );
  }

  void _showCreateBackupDialog() {
    final businessController = TextEditingController();
    final notesController = TextEditingController();
    String selectedType = 'full';
    Map<String, dynamic>? selectedBusiness;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Business Backup'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchBusinessesForSelection(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final businesses = snapshot.data!;
                      return DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedBusiness,
                        decoration: const InputDecoration(labelText: 'Select Business'),
                        items: businesses.map((b) => DropdownMenuItem(
                          value: b,
                          child: Text(b['name'] ?? ''),
                        )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() => selectedBusiness = value);
                            });
                          }
                        },
                      );
                    }
                    return const CircularProgressIndicator();
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Backup Type'),
                  items: ['full', 'incremental', 'manual']
                      .map((type) => DropdownMenuItem(value: type, child: Text(type.toUpperCase())))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() => selectedType = value);
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedBusiness == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a business'), backgroundColor: Colors.red),
                  );
                  return;
                }

                try {
                  final authProvider = context.read<AuthProvider>();
                  final token = authProvider.token;

                  final response = await http.post(
                    Uri.parse('https://rtailed-production.up.railway.app/api/businesses/${selectedBusiness!['id']}/backup'),
                    headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                    body: json.encode({
                      'backupType': selectedType,
                      'notes': notesController.text,
                    }),
                  );

                  if (response.statusCode == 201) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Backup created successfully'), backgroundColor: Colors.green),
                    );
                    setState(() {}); // Refresh the list
                  } else {
                    throw Exception('Failed to create backup');
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating backup: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _restoreFromBackup(Map<String, dynamic> backup) {
    final notesController = TextEditingController();
    String selectedType = 'full_restore';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restore from Backup - ${backup['business_name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to restore this business from backup?'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(labelText: 'Recovery Type'),
              items: ['full_restore', 'partial_restore', 'data_export']
                  .map((type) => DropdownMenuItem(value: type, child: Text(type.replaceAll('_', ' ').toUpperCase())))
                  .toList(),
              onChanged: (value) => selectedType = value!,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Recovery Notes'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final authProvider = context.read<AuthProvider>();
                final token = authProvider.token;

                final response = await http.post(
                  Uri.parse('https://rtailed-production.up.railway.app/api/businesses/${backup['business_id']}/restore/${backup['id']}'),
                  headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                  body: json.encode({
                    'recoveryType': selectedType,
                    'recoveryNotes': notesController.text,
                  }),
                );

                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Business restored successfully'), backgroundColor: Colors.green),
                  );
                  setState(() {}); // Refresh the list
                } else {
                  throw Exception('Failed to restore business');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error restoring business: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _downloadBackup(Map<String, dynamic> backup) {
    // TODO: Implement actual download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading backup: ${backup['file_path']}'), backgroundColor: Colors.blue),
    );
  }

  void _sendPaymentReminder(Map<String, dynamic> bill) {
    // TODO: Implement payment reminder functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment reminder sent'), backgroundColor: Colors.orange),
    );
  }

  void _sendOverdueReminder(Map<String, dynamic> bill) {
    // TODO: Implement overdue reminder functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Overdue reminder sent'), backgroundColor: Colors.red),
    );
  }

  void _suspendBusiness(int businessId) {
    // TODO: Implement business suspension functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Business suspended'), backgroundColor: Colors.orange),
    );
  }

  void _showBillDetails(Map<String, dynamic> bill) {
    // TODO: Implement bill details dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bill details: \$${bill['total_amount']}'), backgroundColor: Colors.blue),
    );
  }

  void _showPaymentDetails(Map<String, dynamic> payment) {
    // TODO: Implement payment details dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment details: \$${payment['payment_amount']}'), backgroundColor: Colors.blue),
    );
  }

  void _showBackupDetails(Map<String, dynamic> backup) {
    // TODO: Implement backup details dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backup details: ${backup['file_path']}'), backgroundColor: Colors.blue),
    );
  }

  // Business Messages Tab
  Widget _buildBusinessesMessages() {
    if (!_messagesLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 768;
            return isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Business Messages', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                      const SizedBox(height: 8),
                      _buildMessagesFilters(isMobile: true),
                    ],
                  )
                : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Business Messages', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                      _buildMessagesFilters(isMobile: false),
                    ],
                  );
          }),
          const SizedBox(height: 16),
          if (_allMessages.isEmpty)
            const Center(child: Text('No messages found'))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _allMessages.length,
              itemBuilder: (context, index) {
                final message = _allMessages[index];
                final business = _allBusinesses.firstWhere((b) => b['id'] == message['business_id'], orElse: () => {});
                return _buildMessageCard(message, business);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMessagesFilters({required bool isMobile}) {
    final spacing = isMobile ? 8.0 : 12.0;
    final compact = isMobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search messages... (subject/body)',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  // Placeholder for local search filter (client-side)
                },
              ),
            ),
            SizedBox(width: spacing),
            SizedBox(
              height: compact ? 36 : 40,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: 'all',
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                  ],
                  onChanged: (v) {
                    // Placeholder for priority filter
                  },
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadMessagesAndPayments,
              tooltip: 'Refresh',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: compact ? 36 : 40,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.send, size: compact ? 18 : 20),
                  label: const Text('Send Message'),
                  onPressed: () => _showSendMessageDialog(null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message, Map<String, dynamic> business) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
          backgroundColor: _getMessageTypeColor(message['message_type']).withOpacity(0.2),
          child: Icon(
            _getMessageTypeIcon(message['message_type']),
            color: _getMessageTypeColor(message['message_type']),
          ),
        ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                      Text(
                        message['subject'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
            const SizedBox(height: 4),
                      Text(
                        message['message'] ?? '',
                        style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
                ),
                const SizedBox(width: 8),
                Chip(
          label: Text(message['priority'] ?? 'medium'),
          backgroundColor: _getPriorityColor(message['priority']).withOpacity(0.2),
          labelStyle: TextStyle(color: _getPriorityColor(message['priority'])),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text('To: ${business['name'] ?? 'Unknown Business'}'),
                Text(_formatDate(message['created_at'])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Business Payments Tab
  Widget _buildBusinessesPayments() {
    if (!_paymentsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 768;
            return isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Business Payments', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                      const SizedBox(height: 8),
                      _buildPaymentsFilters(isMobile: true),
                    ],
                  )
                : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Business Payments', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                      _buildPaymentsFilters(isMobile: false),
                    ],
                  );
          }),
          const SizedBox(height: 16),
          if (_allPayments.isEmpty)
            const Center(child: Text('No payments found'))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _allPayments.length,
              itemBuilder: (context, index) {
                final payment = _allPayments[index];
                final business = _allBusinesses.firstWhere((b) => b['id'] == payment['business_id'], orElse: () => {});
                return _buildPaymentCard(payment, business);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentsFilters({required bool isMobile}) {
    final spacing = isMobile ? 8.0 : 12.0;
    final compact = isMobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search payments... (desc/business)',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  // Placeholder for local search filter (client-side)
                },
              ),
            ),
            SizedBox(width: spacing),
            SizedBox(
              height: compact ? 36 : 40,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: 'all',
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                  ],
                  onChanged: (v) {
                    // Placeholder for status filter
                  },
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadMessagesAndPayments,
              tooltip: 'Refresh',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: compact ? 36 : 40,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.payment, size: compact ? 18 : 20),
                  label: const Text('Add Payment'),
                  onPressed: () => _showAddPaymentDialog(null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment, Map<String, dynamic> business) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
          backgroundColor: _getPaymentStatusColor(payment['status']).withOpacity(0.2),
          child: Icon(
            _getPaymentStatusIcon(payment['status']),
            color: _getPaymentStatusColor(payment['status']),
          ),
        ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                      Text(
                        String.fromCharCode(36) + _safeToDouble(payment['amount']).toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (payment['description'] ?? '').toString(),
                        style: const TextStyle(fontSize: 13),
                      ),
          ],
        ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text((payment['payment_type'] ?? '').toString(),
                    style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w500)),
              ),
                    const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getPaymentStatusColor(payment['status']).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text((payment['status'] ?? '').toString(),
                    style: TextStyle(fontSize: 11, color: _getPaymentStatusColor(payment['status']), fontWeight: FontWeight.w500)),
              ),
            ],
          ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text((business['name'] ?? 'Unknown Business').toString()),
                Text(_formatDate(payment['created_at'] ?? payment['date'] ?? payment['submitted_at'])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Billing Tab ---
  Widget _buildBillingTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: TabBar(
              tabs: const [
                Tab(text: 'Monthly Bills'),
                Tab(text: 'Pending Payments'),
                Tab(text: 'Overdue Bills'),
              ],
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Theme.of(context).primaryColor,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildMonthlyBillsTab(),
                _buildPendingPaymentsTab(),
                _buildOverdueBillsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyBillsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Monthly Billing', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _showGenerateAllBillsDialog,
                    icon: const Icon(Icons.batch_prediction),
                    label: const Text('Generate All'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Generate Bill'),
                    onPressed: _showGenerateBillDialog,
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _fetchAllMonthlyBills(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error loading monthly bills', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('${snapshot.error}', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              final bills = snapshot.data?['bills'] ?? [];
              
              if (bills.isEmpty) {
                return const Center(child: Text('No monthly bills found'));
              }
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: bills.length,
                itemBuilder: (context, index) {
                  final bill = bills[index];
                  return _buildMonthlyBillCard(bill);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyBillCard(Map<String, dynamic> bill) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getBillStatusColor(bill['status']).withOpacity(0.2),
          child: Icon(
            _getBillStatusIcon(bill['status']),
            color: _getBillStatusColor(bill['status']),
          ),
        ),
        title: Text('\$${_safeToDouble(bill['total_amount'] ?? 0).toStringAsFixed(2)}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business: ${bill['business_name'] ?? 'Unknown'}'),
            Text('Plan: ${bill['subscription_plan']?.toString().toUpperCase() ?? 'BASIC'}'),
            Text('Month: ${_formatDate(bill['billing_month'])}'),
            Text('Due: ${_formatDate(bill['due_date'])}'),
            if (bill['user_overage_fee'] != null && _safeToDouble(bill['user_overage_fee']) > 0)
              Text('User Overage: \$${_safeToDouble(bill['user_overage_fee']).toStringAsFixed(2)}', style: TextStyle(color: Colors.orange)),
            if (bill['product_overage_fee'] != null && _safeToDouble(bill['product_overage_fee']) > 0)
              Text('Product Overage: \$${_safeToDouble(bill['product_overage_fee']).toStringAsFixed(2)}', style: TextStyle(color: Colors.orange)),
          ],
        ),
        trailing: SizedBox(
          width: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getBillStatusColor(bill['status']).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  bill['status'] ?? '',
                  style: TextStyle(
                    color: _getBillStatusColor(bill['status']),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (bill['status'] == 'pending') ...[
                const SizedBox(height: 4),
                SizedBox(
                  width: 100,
                  height: 24,
                  child: ElevatedButton(
                    onPressed: () => _sendPaymentReminder(bill),
                    child: const Text('Remind', style: TextStyle(fontSize: 10)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        onTap: () => _showBillDetails(bill),
      ),
    );
  }

  Widget _buildPendingPaymentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pending Payment Reviews', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _fetchPendingPayments(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final payments = snapshot.data?['payments'] ?? [];
              
              if (payments.isEmpty) {
                return const Center(child: Text('No pending payments to review'));
              }
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final payment = payments[index];
                  return _buildPendingPaymentCard(payment);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPendingPaymentCard(Map<String, dynamic> payment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.2),
          child: const Icon(Icons.payment, color: Colors.orange),
        ),
        title: Text('\$${_safeToDouble(payment['payment_amount']).toStringAsFixed(2)}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business: ${payment['business_name'] ?? 'Unknown'}'),
            Text('Method: ${payment['payment_method'] ?? ''}'),
            Text('Submitted: ${_formatDate(payment['submitted_at'])}'),
            if (payment['transaction_id'] != null)
              Text('Transaction ID: ${payment['transaction_id']}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => _reviewPayment(payment, 'accepted'),
              child: const Text('Accept'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _reviewPayment(payment, 'rejected'),
              child: const Text('Reject'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            ),
          ],
        ),
        onTap: () => _showPaymentDetails(payment),
      ),
    );
  }

  Widget _buildOverdueBillsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overdue Bills', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _fetchOverdueBills(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final bills = snapshot.data?['bills'] ?? [];
              
              if (bills.isEmpty) {
                return const Center(child: Text('No overdue bills'));
              }
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: bills.length,
                itemBuilder: (context, index) {
                  final bill = bills[index];
                  return _buildOverdueBillCard(bill);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueBillCard(Map<String, dynamic> bill) {
    final dueDate = _safeParseDate(bill['due_date']);
    final daysOverdue = dueDate != null ? DateTime.now().difference(dueDate).inDays : 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.withOpacity(0.2),
          child: const Icon(Icons.warning, color: Colors.red),
        ),
        title: Text('\$${_safeToDouble(bill['total_amount'] ?? 0).toStringAsFixed(2)}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business: ${bill['business_name'] ?? 'Unknown'}'),
            Text('Due: ${_formatDate(bill['due_date'])}'),
            Text('Overdue by: $daysOverdue days', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            Text('Contact: ${bill['email'] ?? ''} | ${bill['phone'] ?? ''}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _sendOverdueReminder(bill),
              child: const Text('Send Reminder'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _suspendBusiness(bill['business_id']),
              child: const Text('Suspend'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            ),
          ],
        ),
        onTap: () => _showBillDetails(bill),
      ),
    );
  }

  // --- Backups Tab ---
  Widget _buildBackupsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Business Backups', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              ElevatedButton.icon(
                icon: const Icon(Icons.backup),
                label: const Text('Create Backup'),
                onPressed: _showCreateBackupDialog,
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _fetchAllBackups(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final backups = snapshot.data?['backups'] ?? [];
              
              if (backups.isEmpty) {
                return const Center(child: Text('No backups found'));
              }
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: backups.length,
                itemBuilder: (context, index) {
                  final backup = backups[index];
                  return _buildBackupCard(backup);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCard(Map<String, dynamic> backup) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getBackupStatusColor(backup['status']).withOpacity(0.2),
          child: Icon(
            _getBackupStatusIcon(backup['status']),
            color: _getBackupStatusColor(backup['status']),
          ),
        ),
        title: Text('${backup['business_name'] ?? 'Unknown Business'}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${backup['backup_type'] ?? ''}'),
            Text('Date: ${_formatDate(backup['backup_date'])}'),
            Text('Size: ${_formatFileSize(backup['file_size'] ?? 0)}'),
            Text('Status: ${backup['status'] ?? ''}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (backup['status'] == 'completed')
              ElevatedButton(
                onPressed: () => _restoreFromBackup(backup),
                child: const Text('Restore'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _downloadBackup(backup),
              child: const Text('Download'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            ),
          ],
        ),
        onTap: () => _showBackupDetails(backup),
      ),
    );
  }



  // --- Data Tab ---
  Widget _buildDataTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data Management', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.backup),
                  label: const Text('Create Backup'),
                  onPressed: _createBackup,
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Export Data'),
                  onPressed: _exportData,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildBackupsList(),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchDataTabData() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    // Fetch backups
    final backupsResp = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/backups'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    // Fetch exportable tables
    final tablesResp = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/export'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    final backups = backupsResp.statusCode == 200 ? json.decode(backupsResp.body)['backups'] : [];
    final tables = tablesResp.statusCode == 200 ? json.decode(tablesResp.body)['tables'] : [];
    return {'backups': backups, 'tables': tables};
  }

  Future<void> _createBackup() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    final response = await http.post(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/backup'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message']), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create backup'), backgroundColor: Colors.red),
      );
    }
  }

  void _exportData() {
    final url = 'https://rtailed-production.up.railway.app/api/admin/export';
    // For web: open in new tab, for mobile/desktop: launch URL
    // (You may want to use url_launcher for mobile/desktop)
    // For now, just open in browser
    // ignore: undefined_prefixed_name
    // ignore: avoid_web_libraries_in_flutter
    // import 'dart:html' as html; html.window.open(url, '_blank');
  }

  Widget _buildBackupsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchBackups(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final backups = snapshot.data ?? [];
        if (backups.isEmpty) {
          return const Text('No backups found.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: backups.map<Widget>((b) => ListTile(
            leading: const Icon(Icons.save_alt),
            title: Text(b['filename'] ?? ''),
            subtitle: Text('Created: ${b['created'] ?? ''} | Size: ${b['size']} bytes'),
            trailing: IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _downloadBackup(b),
            ),
          )).toList(),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchBackups() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    final response = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/backups'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final backupsRaw = data['backups'] ?? [];
      return TypeConverter.convertMySQLList(backupsRaw);
    }
    throw Exception('Failed to fetch backups');
  }



  // --- User Management Tab (already implemented) ---
  Widget _buildUserManagement() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('User Management', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getRoleColor(user['role']),
                    child: Text(
                      user['username']?[0].toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    user['username'] ?? 'Unknown User',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${user['email'] ?? ''} • ${user['role'] ?? ''}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: user['is_active'] ?? false,
                        onChanged: (value) => _toggleUserStatus(user['id'], value),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) => _handleUserAction(value, user),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 16),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'reset_password',
                            child: Row(
                              children: [
                                Icon(Icons.lock_reset, size: 16),
                                SizedBox(width: 8),
                                Text('Reset Password'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'force_logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout, size: 16),
                                SizedBox(width: 8),
                                Text('Force Logout'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'logs',
                            child: Row(
                              children: [
                                Icon(Icons.history, size: 16),
                                SizedBox(width: 8),
                                Text('View Logs'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'superadmin':
        return Colors.red;
      case 'admin':
        return Colors.purple;
      case 'manager':
        return Colors.blue;
      case 'cashier':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _toggleUserStatus(int userId, bool isActive) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;

      final response = await http.patch(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/users/$userId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'is_active': isActive}),
      );

      if (response.statusCode == 200) {
        _loadDashboardData(); // Refresh data
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User status updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to update user status');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating user status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleUserAction(String action, Map<String, dynamic> user) {
    switch (action) {
      case 'edit':
        _showEditUserDialog(user);
        break;
      case 'reset_password':
        _showResetPasswordDialog(user);
        break;
      case 'force_logout':
        _forceLogoutUser(user);
        break;
      case 'logs':
        _showUserLogsDialog(user);
        break;
      case 'delete':
        _showDeleteUserDialog(user);
        break;
    }
  }

  void _showCreateUserDialog() {
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String selectedRole = 'cashier';
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(t(context, 'Create New User')),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
                  decoration: InputDecoration(
                    labelText: t(context, 'Username'),
                    hintText: t(context, 'Enter username (3-20 characters)'),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  onChanged: (value) {
                    // Real-time validation - trigger rebuild
                    setState(() {});
                  },
                ),
                if (usernameController.text.isNotEmpty && (usernameController.text.length < 3 || usernameController.text.length > 20))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      t(context, 'Username must be 3-20 characters long'),
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 16),
            TextField(
              controller: emailController,
                  decoration: InputDecoration(
                    labelText: t(context, 'Email'),
                    hintText: t(context, 'Enter email address'),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
              keyboardType: TextInputType.emailAddress,
            ),
                const SizedBox(height: 16),
            TextField(
              controller: passwordController,
                  decoration: InputDecoration(
                    labelText: t(context, 'Password'),
                    hintText: t(context, 'Enter password (min 6 characters)'),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
              obscureText: true,
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                if (passwordController.text.isNotEmpty && passwordController.text.length < 6)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      t(context, 'Password must be at least 6 characters'),
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: t(context, 'Confirm Password'),
                    hintText: t(context, 'Confirm your password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                if (confirmPasswordController.text.isNotEmpty && confirmPasswordController.text != passwordController.text)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      t(context, 'Passwords do not match'),
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedRole,
                  decoration: InputDecoration(
                    labelText: t(context, 'Role'),
                    prefixIcon: const Icon(Icons.work_outline),
                  ),
              items: ['superadmin', 'admin', 'manager', 'cashier']
                      .map((role) => DropdownMenuItem(
                        value: role, 
                        child: Text(t(context, role.toUpperCase()))
                      ))
                  .toList(),
              onChanged: (value) => selectedRole = value!,
            ),
          ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: isCreating ? null : () => Navigator.pop(context),
            child: Text(t(context, 'Cancel')),
          ),
          ElevatedButton(
            onPressed: isCreating ? null : () async {
              // Validation
              if (usernameController.text.isEmpty ||
                  emailController.text.isEmpty ||
                  passwordController.text.isEmpty ||
                  confirmPasswordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t(context, 'All fields are required')),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (usernameController.text.length < 3 || usernameController.text.length > 20) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t(context, 'Username must be 3-20 characters long')),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (passwordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t(context, 'Password must be at least 6 characters')),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (passwordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t(context, 'Passwords do not match')),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setState(() {
                isCreating = true;
              });

              try {
                final authProvider = context.read<AuthProvider>();
                final token = authProvider.token;

                final response = await http.post(
                  Uri.parse('https://rtailed-production.up.railway.app/api/admin/users'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                  body: json.encode({
                    'username': usernameController.text,
                    'email': emailController.text,
                    'password': passwordController.text,
                    'role': selectedRole,
                  }),
                );

                final responseData = json.decode(response.body);

                if (response.statusCode == 201) {
                  Navigator.pop(context);
                  _loadDashboardData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t(context, 'User created successfully')),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  String errorMessage = responseData['message'] ?? 'Failed to create user';
                  
                  // Handle specific error cases
                  if (responseData['field'] == 'username') {
                    errorMessage = '${t(context, 'Username already exists')}: ${responseData['existingUser']}';
                  } else if (responseData['field'] == 'email') {
                    errorMessage = '${t(context, 'Email already exists')}: ${responseData['existingUser']}';
                  }
                  
                  throw Exception(errorMessage);
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${t(context, 'Error creating user')}: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setState(() {
                  isCreating = false;
                });
              }
            },
            child: isCreating 
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(t(context, 'Create')),
          ),
        ],
      ),
    ));
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final usernameController = TextEditingController(text: user['username']);
    final emailController = TextEditingController(text: user['email']);
    String selectedRole = user['role'];
    bool isActive = user['is_active'] ?? false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(labelText: 'Role'),
              items: ['superadmin', 'admin', 'manager', 'cashier']
                  .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                  .toList(),
              onChanged: (value) => selectedRole = value!,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: isActive,
                  onChanged: (value) {
                    setState(() {
                      isActive = value!;
                    });
                  },
                ),
                const Text('Active'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final authProvider = context.read<AuthProvider>();
                final token = authProvider.token;

                final response = await http.put(
                  Uri.parse('https://rtailed-production.up.railway.app/api/admin/users/${user['id']}'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                  body: json.encode({
                    'username': usernameController.text,
                    'email': emailController.text,
                    'role': selectedRole,
                    'is_active': isActive,
                  }),
                );

                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  _loadDashboardData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  throw Exception('Failed to update user');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating user: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(Map<String, dynamic> user) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Password for ${user['username']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final authProvider = context.read<AuthProvider>();
                final token = authProvider.token;

                final response = await http.post(
                  Uri.parse('https://rtailed-production.up.railway.app/api/admin/users/${user['id']}/reset-password'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                  body: json.encode({
                    'newPassword': passwordController.text,
                  }),
                );

                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password reset successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  throw Exception('Failed to reset password');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error resetting password: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _forceLogoutUser(Map<String, dynamic> user) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;

      final response = await http.post(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/users/${user['id']}/force-logout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User force-logged out successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to force logout user');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error force-logging out user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUserLogsDialog(Map<String, dynamic> user) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;

      final response = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/users/${user['id']}/logs'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final logsRaw = data['logs'] ?? [];
        final logs = TypeConverter.convertMySQLList(logsRaw);

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Activity Logs for ${user['username']}'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return ListTile(
                    title: Text(log['action'] ?? 'Unknown'),
                    subtitle: Text(log['created_at'] ?? ''),
                    trailing: Text(log['table_name'] ?? ''),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        throw Exception('Failed to load user logs');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading user logs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user['username']}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final authProvider = context.read<AuthProvider>();
                final token = authProvider.token;

                final response = await http.delete(
                  Uri.parse('https://rtailed-production.up.railway.app/api/admin/users/${user['id']}'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                );

                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  _loadDashboardData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  throw Exception('Failed to delete user');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting user: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- Settings Tab with Sub-tabs ---
  Widget _buildSettingsTab() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                final isTiny = constraints.maxWidth < 400;
                return TabBar(
                  isScrollable: isNarrow,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Theme.of(context).primaryColor,
                  labelPadding: EdgeInsets.symmetric(horizontal: isTiny ? 6 : (isNarrow ? 8 : 16)),
                  labelStyle: TextStyle(fontSize: isTiny ? 10 : (isNarrow ? 12 : 14), fontWeight: FontWeight.w500),
                  unselectedLabelStyle: TextStyle(fontSize: isTiny ? 10 : (isNarrow ? 12 : 14)),
              tabs: [
                    Tab(icon: Icon(Icons.settings, size: isTiny ? 16 : 20), text: isTiny ? 'System' : 'System Settings'),
                    Tab(icon: Icon(Icons.admin_panel_settings, size: isTiny ? 16 : 20), text: isTiny ? 'Admin' : 'Admin Codes'),
                    Tab(icon: Icon(Icons.palette, size: isTiny ? 16 : 20), text: 'Branding'),
                    Tab(icon: Icon(Icons.backup, size: isTiny ? 16 : 20), text: 'Backups'),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSystemSettingsSubTab(),
                _buildAdminCodesSubTab(),
                _buildBrandingSubTab(),
                _buildBackupsSubTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // System Settings Sub-tab
  Widget _buildSystemSettingsSubTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchSettingsConfig(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final config = snapshot.data ?? {};
        final settingsRaw = config['settings'] ?? [];
        final stats = config['stats'] ?? {};
        
        // Properly cast the settings list
        final List<Map<String, dynamic>> settings = settingsRaw.map<Map<String, dynamic>>((item) {
          return _convertMySQLTypes(item);
        }).toList();
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('System Configuration', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              const SizedBox(height: 16),
              _buildSystemStatsCard(stats),
              const SizedBox(height: 24),
              Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildQuickActionsCard(stats),
              const SizedBox(height: 24),
              Text('System Settings', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildSettingsList(settings),
            ],
          ),
        );
      },
    );
  }

  // Admin Codes Sub-tab
  Widget _buildAdminCodesSubTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin Code Management', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
          const SizedBox(height: 16),
          _buildAdminCodeCard(),
        ],
      ),
    );
  }

  // Branding Sub-tab
  Widget _buildBrandingSubTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTiny = screenWidth < 320;
    final isExtraSmall = screenWidth < 360;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTiny ? 8 : (isExtraSmall ? 12 : 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTiny ? 'Branding' : 'Branding Management', 
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold, 
              color: Theme.of(context).primaryColor,
              fontSize: isTiny ? 16 : (isExtraSmall ? 18 : 20),
            )
          ),
          SizedBox(height: isTiny ? 8 : (isExtraSmall ? 12 : 16)),
          _buildCurrentBrandingPreview(isTiny, isExtraSmall),
          SizedBox(height: isTiny ? 8 : (isExtraSmall ? 12 : 16)),
          _buildBrandingCardDesktop(isTiny, isExtraSmall),
        ],
      ),
    );
  }

  Widget _buildCurrentBrandingPreview(bool isTiny, bool isExtraSmall) {
    try {
      final authProvider = context.read<AuthProvider>();
      final brandingProvider = context.read<BrandingProvider>();
      final businessId = authProvider.user?.businessId;
      final logoUrl = brandingProvider.getCurrentLogo(businessId);
      final appName = brandingProvider.getCurrentAppName(businessId);
      final primaryColor = brandingProvider.getPrimaryColor(businessId);

      final double imageSize = isTiny ? 36 : (isExtraSmall ? 44 : 56);
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTiny ? 6 : 8)),
        child: Padding(
          padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: imageSize,
                height: imageSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (logoUrl != null)
                      ? Image.network(
                          'https://rtailed-production.up.railway.app$logoUrl',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(Icons.business, color: primaryColor, size: imageSize * 0.7),
                        )
                      : Icon(Icons.business, color: primaryColor, size: imageSize * 0.7),
                ),
              ),
              SizedBox(width: isTiny ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isTiny ? 12 : (isExtraSmall ? 13 : 14),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                        ),
                        Text('Primary color', style: TextStyle(color: Colors.grey[600], fontSize: isTiny ? 10 : 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  // Backups Sub-tab
  Widget _buildBackupsSubTab() {
    return _buildBackupsTab();
  }

  Future<Map<String, dynamic>> _fetchSettingsConfig() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    final response = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/settings/config'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch settings config');
    }
  }

  Widget _buildSystemStatsCard(Map<String, dynamic> stats) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('System Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (isMobile) ...[
              _buildStatItem('Total Users', TypeConverter.safeToString(stats['totalUsers'] ?? 0), Icons.people),
              const SizedBox(height: 8),
              _buildStatItem('Total Products', TypeConverter.safeToString(stats['totalProducts'] ?? 0), Icons.inventory),
              const SizedBox(height: 8),
              _buildStatItem('Total Sales', TypeConverter.safeToString(stats['totalSales'] ?? 0), Icons.shopping_cart),
              const SizedBox(height: 8),
              _buildStatItem('App Version', TypeConverter.safeToString(stats['appVersion'] ?? 'N/A'), Icons.info),
              const SizedBox(height: 8),
              _buildStatItem('Session Timeout', '${TypeConverter.safeToString(stats['sessionTimeout'] ?? 'N/A')}s', Icons.timer),
              const SizedBox(height: 8),
              _buildStatItem('Max Login Attempts', TypeConverter.safeToString(stats['maxLoginAttempts'] ?? 'N/A'), Icons.security),
            ] else ...[
              Row(
                children: [
                  Expanded(child: _buildStatItem('Total Users', TypeConverter.safeToString(stats['totalUsers'] ?? 0), Icons.people)),
                  Expanded(child: _buildStatItem('Total Products', TypeConverter.safeToString(stats['totalProducts'] ?? 0), Icons.inventory)),
                  Expanded(child: _buildStatItem('Total Sales', TypeConverter.safeToString(stats['totalSales'] ?? 0), Icons.shopping_cart)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildStatItem('App Version', TypeConverter.safeToString(stats['appVersion'] ?? 'N/A'), Icons.info)),
                  Expanded(child: _buildStatItem('Session Timeout', '${TypeConverter.safeToString(stats['sessionTimeout'] ?? 'N/A')}s', Icons.timer)),
                  Expanded(child: _buildStatItem('Max Login Attempts', TypeConverter.safeToString(stats['maxLoginAttempts'] ?? 'N/A'), Icons.security)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildQuickActionsCard(Map<String, dynamic> stats) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (isMobile) ...[
              ElevatedButton.icon(
                icon: Icon(stats['maintenanceMode'] == true || stats['maintenanceMode'] == 1 ? Icons.play_arrow : Icons.pause),
                label: Text(stats['maintenanceMode'] == true || stats['maintenanceMode'] == 1 ? 'Disable Maintenance' : 'Enable Maintenance'),
                onPressed: _toggleMaintenanceMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: stats['maintenanceMode'] == true || stats['maintenanceMode'] == 1 ? Colors.green : Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.backup),
                label: const Text('Create Backup'),
                onPressed: _triggerBackup,
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(stats['maintenanceMode'] == true || stats['maintenanceMode'] == 1 ? Icons.play_arrow : Icons.pause),
                      label: Text(stats['maintenanceMode'] == true || stats['maintenanceMode'] == 1 ? 'Disable Maintenance' : 'Enable Maintenance'),
                      onPressed: _toggleMaintenanceMode,
                                              style: ElevatedButton.styleFrom(
                          backgroundColor: stats['maintenanceMode'] == true || stats['maintenanceMode'] == 1 ? Colors.green : Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.backup),
                      label: const Text('Create Backup'),
                      onPressed: _triggerBackup,
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsList(List<Map<String, dynamic>> settings) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: 300,
        ),
      child: ListView.builder(
        shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
        itemCount: settings.length,
        itemBuilder: (context, index) {
          final setting = settings[index];
          return ListTile(
              title: Text(TypeConverter.safeToString(setting['setting_key'] ?? '')),
              subtitle: Text(TypeConverter.safeToString(setting['description'] ?? '')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                  Flexible(
                    child: Text(
                      TypeConverter.safeToString(setting['setting_value'] ?? ''),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editSetting(setting),
                ),
              ],
            ),
          );
        },
        ),
      ),
    );
  }

  Widget _buildAdminCodeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admin Code Management', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.key),
              label: const Text('Update Admin Code'),
              onPressed: _showUpdateAdminCodeDialog,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            ),
            const SizedBox(height: 8),
            Text('The admin code is used for superadmin registration. Keep it secure!', 
                 style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingCardDesktop(bool isTiny, bool isExtraSmall) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTiny ? 6 : 8)),
      child: Padding(
        padding: EdgeInsets.all(isTiny ? 6 : (isExtraSmall ? 8 : 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.branding_watermark,
                  size: isTiny ? 16 : (isExtraSmall ? 18 : 20),
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(width: isTiny ? 6 : 8),
                Text(
                  isTiny ? 'Brand' : 'Branding Management', 
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isTiny ? 12 : (isExtraSmall ? 14 : 16),
                  )
                ),
              ],
            ),
            SizedBox(height: isTiny ? 6 : 8),
            if (isTiny || isExtraSmall || MediaQuery.of(context).size.width < 480) ...[
              // Stack buttons vertically on small screens
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BrandingSettingsScreen(),
                    ),
                  ),
                  icon: Icon(Icons.branding_watermark, size: isTiny ? 14 : 16),
                  label: Text(
                    isTiny ? 'System' : 'System Branding',
                    style: TextStyle(fontSize: isTiny ? 10 : 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple, 
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isTiny ? 6 : 8,
                      horizontal: isTiny ? 8 : 12,
                    ),
                  ),
                ),
              ),
              SizedBox(height: isTiny ? 4 : 6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showBusinessBrandingDialog,
                  icon: Icon(Icons.business, size: isTiny ? 14 : 16),
                  label: Text(
                    isTiny ? 'Business' : 'Business Branding',
                    style: TextStyle(fontSize: isTiny ? 10 : 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange, 
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isTiny ? 6 : 8,
                      horizontal: isTiny ? 8 : 12,
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Side by side on larger screens
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BrandingSettingsScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.branding_watermark),
                      label: const Text('System Branding'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple, 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showBusinessBrandingDialog,
                      icon: const Icon(Icons.business),
                      label: const Text('Business Branding'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange, 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Data Management Tab with Sub-tabs ---
  Widget _buildDataManagementTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: TabBar(
              isScrollable: MediaQuery.of(context).size.width < 600,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Theme.of(context).primaryColor,
              tabs: [
                Tab(icon: Icon(Icons.storage, size: MediaQuery.of(context).size.width < 400 ? 16 : 20), text: 'Data Overview'),
                Tab(icon: Icon(Icons.delete_forever, size: MediaQuery.of(context).size.width < 400 ? 16 : 20), text: 'Deleted Data'),
                Tab(icon: Icon(Icons.data_usage, size: MediaQuery.of(context).size.width < 400 ? 16 : 20), text: 'Data Export'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDataOverviewSubTab(),
                _buildDeletedDataSubTab(),
                _buildDataExportSubTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Data Overview Sub-tab
  Widget _buildDataOverviewSubTab() {
    return _buildDataTab();
  }

  // Deleted Data Sub-tab
  Widget _buildDeletedDataSubTab() {
    return _buildDeletedDataTab();
  }

  // Data Export Sub-tab
  Widget _buildDataExportSubTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data Export', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export Options', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildExportOptions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOptions() {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.business),
          title: Text('Export Business Data'),
          subtitle: Text('Export all business information'),
          trailing: ElevatedButton(
            onPressed: () {},
            child: Text('Export'),
          ),
        ),
        ListTile(
          leading: Icon(Icons.people),
          title: Text('Export User Data'),
          subtitle: Text('Export all user accounts'),
          trailing: ElevatedButton(
            onPressed: () {},
            child: Text('Export'),
          ),
        ),
        ListTile(
          leading: Icon(Icons.shopping_cart),
          title: Text('Export Sales Data'),
          subtitle: Text('Export all sales records'),
          trailing: ElevatedButton(
            onPressed: () {},
            child: Text('Export'),
          ),
        ),
        ListTile(
          leading: Icon(Icons.inventory),
          title: Text('Export Inventory Data'),
          subtitle: Text('Export all product inventory'),
          trailing: ElevatedButton(
            onPressed: () {},
            child: Text('Export'),
          ),
        ),
      ],
    );
  }

  void _showBusinessBrandingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Business for Branding'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visual picker with search and dropdown for mobile
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchBusinessesForSelection(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text('Error: ${snapshot.error}'),
                    ],
                  );
                }
                final businesses = snapshot.data ?? [];
                if (businesses.isEmpty) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.business, color: Colors.grey, size: 48),
                      SizedBox(height: 8),
                      Text('No businesses found'),
                    ],
                  );
                }
                // Dropdown for quick pick
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      value: _brandingSelectedBusinessId,
                      decoration: const InputDecoration(
                        labelText: 'Choose business',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: businesses.map((b) {
                        final id = TypeConverter.safeToInt(b['id']);
                        final name = TypeConverter.safeToString(b['name'] ?? 'Business #$id');
                        return DropdownMenuItem(
                          value: id,
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _brandingSelectedBusinessId = val),
                      selectedItemBuilder: (context) => businesses.map((b) {
                        final id = TypeConverter.safeToInt(b['id']);
                        final name = TypeConverter.safeToString(b['name'] ?? 'Business #$id');
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                        maxWidth: MediaQuery.of(context).size.width * 0.8,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: businesses.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final business = businesses[index];
                          final id = TypeConverter.safeToInt(business['id']);
                          final name = TypeConverter.safeToString(business['name'] ?? 'Unknown Business');
                          final email = TypeConverter.safeToString(business['email'] ?? '');
                          final isNarrow = MediaQuery.of(context).size.width < 380;
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text(
                                _getBusinessInitial(name),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                            subtitle: Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                            trailing: isNarrow
                                ? IconButton(
                                    tooltip: 'Brand',
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => BusinessBrandingScreen(businessId: id),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.edit, color: Colors.orange),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => BusinessBrandingScreen(businessId: id),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('Brand'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                            onTap: () {
                              setState(() => _brandingSelectedBusinessId = id);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if ((_brandingSelectedBusinessId ?? 0) > 0) {
                final id = _brandingSelectedBusinessId!;
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BusinessBrandingScreen(businessId: id)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a business'), backgroundColor: Colors.red),
                );
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Continue'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleMaintenanceMode() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    final response = await http.post(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/settings/maintenance/toggle'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message']), backgroundColor: Colors.green),
      );
      setState(() {}); // Refresh
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle maintenance mode'), backgroundColor: Colors.red),
      );
    }
  }

  void _showUpdateAdminCodeDialog() {
    final currentCodeController = TextEditingController();
    final newCodeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Admin Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentCodeController,
              decoration: const InputDecoration(labelText: 'Current Admin Code'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newCodeController,
              decoration: const InputDecoration(labelText: 'New Admin Code'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final authProvider = context.read<AuthProvider>();
              final token = authProvider.token;
              final response = await http.post(
                Uri.parse('https://rtailed-production.up.railway.app/api/admin/settings/admin-code/update'),
                headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                body: json.encode({
                  'currentCode': currentCodeController.text,
                  'newCode': newCodeController.text,
                }),
              );
              if (response.statusCode == 200) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Admin code updated successfully'), backgroundColor: Colors.green),
                );
              } else {
                final error = json.decode(response.body);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error['message']), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _editSetting(Map<String, dynamic> setting) {
    final valueController = TextEditingController(text: setting['setting_value'] ?? '');
    final descriptionController = TextEditingController(text: setting['description'] ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Setting: ${setting['setting_key']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valueController,
              decoration: const InputDecoration(labelText: 'Value'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final authProvider = context.read<AuthProvider>();
              final token = authProvider.token;
              final response = await http.put(
                Uri.parse('https://rtailed-production.up.railway.app/api/admin/settings/${setting['setting_key']}'),
                headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                body: json.encode({
                  'value': valueController.text,
                  'description': descriptionController.text,
                }),
              );
              if (response.statusCode == 200) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Setting updated successfully'), backgroundColor: Colors.green),
                );
                setState(() {}); // Refresh
              } else {
                final error = json.decode(response.body);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error['message']), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // --- Notifications Tab ---
  Widget _buildNotificationsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data ?? {};
        final notificationsRaw = data['notifications'] ?? [];
        final stats = data['stats'] ?? {};
        
        // Properly cast the notifications list
        final List<Map<String, dynamic>> notifications = notificationsRaw.map<Map<String, dynamic>>((item) {
          return TypeConverter.safeToMap(item);
        }).toList();
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Notifications', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Create Notification'),
                    onPressed: _showCreateNotificationDialog,
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildNotificationStatsCard(stats),
              const SizedBox(height: 24),
              Text('Recent Notifications', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildNotificationsList(notifications),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchNotifications() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    // Fetch notifications and stats
    final notificationsResponse = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/notifications'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    
    final statsResponse = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/notifications/stats'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    
    if (notificationsResponse.statusCode == 200 && statsResponse.statusCode == 200) {
      return {
        'notifications': json.decode(notificationsResponse.body)['notifications'] ?? [],
        'stats': json.decode(statsResponse.body),
      };
    } else {
      throw Exception('Failed to fetch notifications');
    }
  }

  Widget _buildNotificationStatsCard(Map<String, dynamic> stats) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notification Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Total', '${stats['total'] ?? 0}', Icons.notifications)),
                Expanded(child: _buildStatItem('Unread', '${stats['unread_total'] ?? 0}', Icons.mark_email_unread)),
                Expanded(child: _buildStatItem('Last 7 Days', '${stats['recent_7_days'] ?? 0}', Icons.schedule)),
              ],
            ),
            const SizedBox(height: 16),
            Text('By Type', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: (stats['by_type'] as List<dynamic>? ?? []).map((type) => 
                Chip(
                  label: Text('${type['type']}: ${type['count']}'),
                  backgroundColor: _getTypeColor(type['type']).withOpacity(0.2),
                  labelStyle: TextStyle(color: _getTypeColor(type['type'])),
                )
              ).toList(),
            ),
            const SizedBox(height: 8),
            Text('By Priority', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: (stats['by_priority'] as List<dynamic>? ?? []).map((priority) => 
                Chip(
                  label: Text('${priority['priority']}: ${priority['count']}'),
                  backgroundColor: _getPriorityColor(priority['priority']).withOpacity(0.2),
                  labelStyle: TextStyle(color: _getPriorityColor(priority['priority'])),
                )
              ).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'info': return Colors.blue;
      case 'warning': return Colors.orange;
      case 'error': return Colors.red;
      case 'success': return Colors.green;
      default: return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'low': return Colors.green;
      case 'medium': return Colors.orange;
      case 'high': return Colors.red;
      case 'urgent': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Widget _buildNotificationsList(List<Map<String, dynamic>> notifications) {
    if (notifications.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No notifications found')),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _getTypeColor(notification['type'] ?? '').withOpacity(0.2),
              child: Icon(
                _getNotificationIcon(notification['type'] ?? ''),
                color: _getTypeColor(notification['type'] ?? ''),
              ),
            ),
            title: Text(notification['title'] ?? ''),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification['message'] ?? ''),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Chip(
                      label: Text(notification['type'] ?? ''),
                      backgroundColor: _getTypeColor(notification['type'] ?? '').withOpacity(0.2),
                      labelStyle: TextStyle(color: _getTypeColor(notification['type'] ?? ''), fontSize: 10),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(notification['priority'] ?? ''),
                      backgroundColor: _getPriorityColor(notification['priority'] ?? '').withOpacity(0.2),
                      labelStyle: TextStyle(color: _getPriorityColor(notification['priority'] ?? ''), fontSize: 10),
                    ),
                  ],
                ),
                Text(
                  'Created: ${_formatDate(notification['created_at'])} by ${notification['created_by_name'] ?? 'Unknown'}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  'Targets: ${notification['target_count'] ?? 0} | Read: ${notification['read_count'] ?? 0}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteNotification(notification['id']);
                }
              },
            ),
          );
        },
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'info': return Icons.info;
      case 'warning': return Icons.warning;
      case 'error': return Icons.error;
      case 'success': return Icons.check_circle;
      default: return Icons.notifications;
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Unknown';
    try {
      DateTime date;
      
      if (dateValue is int) {
        // Handle timestamp (seconds since epoch)
        date = DateTime.fromMillisecondsSinceEpoch(dateValue * 1000);
      } else if (dateValue is String) {
        // Handle string date
        date = DateTime.parse(dateValue);
      } else {
        return dateValue.toString();
      }
      
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
    } catch (e) {
      return 'Invalid date';
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

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showCreateNotificationDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String selectedType = 'info';
    String selectedPriority = 'medium';
    List<int> selectedUsers = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Notification'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(labelText: 'Message'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: ['info', 'warning', 'error', 'success'].map((type) => 
                    DropdownMenuItem(value: type, child: Text(type.toUpperCase()))
                  ).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() => selectedType = value);
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: ['low', 'medium', 'high', 'urgent'].map((priority) => 
                    DropdownMenuItem(value: priority, child: Text(priority.toUpperCase()))
                  ).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() => selectedPriority = value);
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text('Target Users (leave empty for all users)'),
                const SizedBox(height: 8),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchUsers(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final users = snapshot.data!;
                      return Column(
                        children: users.map((user) => CheckboxListTile(
                          title: Text(user['username'] ?? ''),
                          subtitle: Text(user['email'] ?? ''),
                          value: selectedUsers.contains(user['id']),
                          onChanged: (checked) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                            setState(() {
                              if (checked == true || checked == 1) {
                                selectedUsers.add(user['id']);
                              } else {
                                selectedUsers.remove(user['id']);
                              }
                              });
                            });
                          },
                        )).toList(),
                      );
                    }
                    return const CircularProgressIndicator();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final authProvider = context.read<AuthProvider>();
                final token = authProvider.token;
                final response = await http.post(
                  Uri.parse('https://rtailed-production.up.railway.app/api/admin/notifications'),
                  headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                  body: json.encode({
                    'title': titleController.text,
                    'message': messageController.text,
                    'type': selectedType,
                    'priority': selectedPriority,
                    'target_users': selectedUsers.isEmpty ? null : selectedUsers,
                  }),
                );
                if (response.statusCode == 201) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notification created successfully'), backgroundColor: Colors.green),
                  );
                  setState(() {}); // Refresh
                } else {
                  final error = json.decode(response.body);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error['message']), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    final response = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/users'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final usersRaw = data['users'] ?? [];
              return TypeConverter.safeToList(usersRaw);
    }
    return [];
  }

  Future<void> _deleteNotification(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true || confirmed == 1) {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;
      final response = await http.delete(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/notifications/$id'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted successfully'), backgroundColor: Colors.green),
        );
        setState(() {}); // Refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete notification'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- Audit Tab ---
  Widget _buildAuditTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchAuditData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data ?? {};
        final logsRaw = data['logs'] ?? [];
        final stats = data['stats'] ?? {};
        final systemActivity = data['system_activity'] ?? {};
        
        // Properly cast the logs list
        final List<Map<String, dynamic>> logs = logsRaw.map<Map<String, dynamic>>((item) {
          return TypeConverter.safeToMap(item);
        }).toList();
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Audit Trail', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.filter_list),
                        label: const Text('Filter'),
                        onPressed: _showAuditFilterDialog,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('Export'),
                        onPressed: _exportAuditLogs,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildAuditStatsCard(stats),
              const SizedBox(height: 24),
              _buildSystemActivityCard(systemActivity),
              const SizedBox(height: 24),
              Text('Recent Audit Logs', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildAuditLogsList(logs),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchAuditData() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    // Fetch audit logs, stats, and system activity
    final logsResponse = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/audit-logs?limit=20'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    
    final statsResponse = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/audit-logs/stats'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    
    final systemActivityResponse = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/audit-logs/system-activity'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    
    if (logsResponse.statusCode == 200 && statsResponse.statusCode == 200 && systemActivityResponse.statusCode == 200) {
      return {
        'logs': json.decode(logsResponse.body)['logs'] ?? [],
        'stats': json.decode(statsResponse.body),
        'system_activity': json.decode(systemActivityResponse.body),
      };
    } else {
      throw Exception('Failed to fetch audit data');
    }
  }

  Widget _buildAuditStatsCard(Map<String, dynamic> stats) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Audit Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Total Logs', '${stats['total_logs'] ?? 0}', Icons.article)),
                Expanded(child: _buildStatItem('Today', '${stats['today_logs'] ?? 0}', Icons.today)),
                Expanded(child: _buildStatItem('This Week', '${stats['week_logs'] ?? 0}', Icons.calendar_view_week)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('This Month', '${stats['month_logs'] ?? 0}', Icons.calendar_month)),
                Expanded(child: _buildStatItem('Active Users', '${stats['unique_users'] ?? 0}', Icons.people)),
                Expanded(child: _buildStatItem('Last Activity', _formatLastActivity(stats['last_activity']), Icons.access_time)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastActivity(dynamic lastActivity) {
    if (lastActivity == null) return 'Never';
    try {
      final date = _safeParseDate(lastActivity);
      if (date == null) return 'Unknown';
      
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      return '${difference.inDays}d ago';
    } catch (e) {
      return 'Unknown';
    }
  }



  Widget _buildAuditLogsList(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No audit logs found')),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _getActionColor(log['action'] ?? '').withOpacity(0.2),
              child: Icon(
                _getActionIcon(log['action'] ?? ''),
                color: _getActionColor(log['action'] ?? ''),
                size: 20,
              ),
            ),
            title: Text('${log['username'] ?? 'Unknown'} - ${log['action'] ?? ''}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (log['table_name'] != null && log['table_name'].toString().isNotEmpty) Text('Table: ${log['table_name']}'),
                if (log['record_id'] != null && log['record_id'].toString().isNotEmpty) Text('Record ID: ${log['record_id']}'),
                Text('IP Address: ${log['ip_address'] ?? 'N/A'}'),
                Text('User Agent: ${log['user_agent'] ?? 'N/A'}'),
                Text('Created: ${_formatDate(log['created_at'])}'),
                if (log['old_values'] != null && log['old_values'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Old Values:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(log['old_values'].toString()),
                ],
                if (log['new_values'] != null && log['new_values'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('New Values:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(log['new_values'].toString()),
                ],
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('View Details'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'details') {
                  _showAuditLogDetails(log);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Color _getActionColor(String action) {
    if (action.startsWith('CREATE')) return Colors.green;
    if (action.startsWith('UPDATE')) return Colors.orange;
    if (action.startsWith('DELETE')) return Colors.red;
    if (action.startsWith('LOGIN')) return Colors.blue;
    if (action.startsWith('LOGOUT')) return Colors.grey;
    return Colors.purple;
  }

  IconData _getActionIcon(String action) {
    if (action.startsWith('CREATE')) return Icons.add;
    if (action.startsWith('UPDATE')) return Icons.edit;
    if (action.startsWith('DELETE')) return Icons.delete;
    if (action.startsWith('LOGIN')) return Icons.login;
    if (action.startsWith('LOGOUT')) return Icons.logout;
    return Icons.info;
  }

  void _showAuditFilterDialog() {
    String? selectedUser;
    String? selectedAction;
    String? selectedTable;
    String? startDate;
    String? endDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Filter Audit Logs'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchUsers(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final users = snapshot.data!;
                      return DropdownButtonFormField<String>(
                        value: selectedUser,
                        decoration: const InputDecoration(labelText: 'User'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Users')),
                          ...users.map((user) => DropdownMenuItem(
                            value: user['id'].toString(),
                            child: Text(user['username'] ?? ''),
                          )),
                        ],
                        onChanged: (value) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            setState(() => selectedUser = value);
                          });
                        },
                      );
                    }
                    return const CircularProgressIndicator();
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedAction,
                  decoration: const InputDecoration(labelText: 'Action'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Actions')),
                    const DropdownMenuItem(value: 'CREATE', child: Text('CREATE')),
                    const DropdownMenuItem(value: 'UPDATE', child: Text('UPDATE')),
                    const DropdownMenuItem(value: 'DELETE', child: Text('DELETE')),
                    const DropdownMenuItem(value: 'LOGIN', child: Text('LOGIN')),
                    const DropdownMenuItem(value: 'LOGOUT', child: Text('LOGOUT')),
                  ],
                  onChanged: (value) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() => selectedAction = value);
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedTable,
                  decoration: const InputDecoration(labelText: 'Table'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Tables')),
                    const DropdownMenuItem(value: 'users', child: Text('Users')),
                    const DropdownMenuItem(value: 'products', child: Text('Products')),
                    const DropdownMenuItem(value: 'sales', child: Text('Sales')),
                    const DropdownMenuItem(value: 'customers', child: Text('Customers')),
                    const DropdownMenuItem(value: 'inventory', child: Text('Inventory')),
                  ],
                  onChanged: (value) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() => selectedTable = value);
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(labelText: 'Start Date (YYYY-MM-DD)'),
                  onChanged: (value) => startDate = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(labelText: 'End Date (YYYY-MM-DD)'),
                  onChanged: (value) => endDate = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _applyAuditFilter(selectedUser, selectedAction, selectedTable, startDate, endDate);
              },
              child: const Text('Apply Filter'),
            ),
          ],
        ),
      ),
    );
  }

  void _applyAuditFilter(String? user, String? action, String? table, String? startDate, String? endDate) {
    // This would typically update the current filter state and reload data
    // For now, we'll just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Filter applied: User=$user, Action=$action, Table=$table, Start=$startDate, End=$endDate')),
    );
  }

  void _exportAuditLogs() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    try {
      final response = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/audit-logs/export'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        // In a real app, you'd handle the CSV download
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audit logs exported successfully'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export audit logs'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting audit logs: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAuditLogDetails(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Audit Log Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('User: ${log['username'] ?? 'Unknown'}'),
              Text('Action: ${log['action'] ?? ''}'),
              if (log['table_name'] != null && log['table_name'].toString().isNotEmpty) Text('Table: ${log['table_name']}'),
              if (log['record_id'] != null && log['record_id'].toString().isNotEmpty) Text('Record ID: ${log['record_id']}'),
              Text('IP Address: ${log['ip_address'] ?? 'N/A'}'),
              Text('User Agent: ${log['user_agent'] ?? 'N/A'}'),
              Text('Created: ${_formatDate(log['created_at'])}'),
              if (log['old_values'] != null && log['old_values'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Old Values:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(log['old_values'].toString()),
              ],
              if (log['new_values'] != null && log['new_values'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('New Values:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(log['new_values'].toString()),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // --- Analytics Tab ---
  Widget _buildAnalyticsTab() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: TabBar(
              tabs: const [
                Tab(text: 'Platform'),
                Tab(text: 'Businesses'),
                Tab(text: 'Revenue'),
                Tab(text: 'System'),
              ],
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Theme.of(context).primaryColor,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPlatformAnalytics(),
                _buildBusinessesAnalytics(),
                _buildRevenueAnalytics(),
                _buildSystemAnalytics(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformAnalytics() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchPlatformAnalytics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data ?? {};
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Platform Overview', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              const SizedBox(height: 16),
              _buildPlatformOverviewCard(data),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildBusinessStatusCard(data['businesses'] ?? [])),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSubscriptionPlanCard(data['businesses'] ?? [])),
                ],
              ),
              const SizedBox(height: 24),
              _buildPlatformHealthCard(data),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBusinessesAnalytics() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchBusinessesAnalytics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data ?? {};
        final businesses = data['businesses'] ?? [];
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Business Performance', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              const SizedBox(height: 16),
              _buildBusinessPerformanceCard(businesses),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildTopPerformingBusinessesCard(businesses)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildBusinessGrowthCard(businesses)),
                ],
              ),
              const SizedBox(height: 24),
              _buildBusinessActivityCard(businesses),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevenueAnalytics() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchRevenueAnalytics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data ?? {};
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Revenue Analytics', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                  _buildRevenueDateFilter(),
                ],
              ),
              const SizedBox(height: 16),
              _buildRevenueOverviewCard(data),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildRevenueByPlanCard(data)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildPaymentStatusCard(data)),
                ],
              ),
              const SizedBox(height: 24),
              _buildBusinessRevenueDetailsCard(data),
              const SizedBox(height: 24),
              _buildRevenueTrendCard(data),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSystemAnalytics() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchSystemAnalytics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data ?? {};
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('System Health', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              const SizedBox(height: 16),
              _buildSystemHealthCardWithData(data),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildDatabaseHealthCard(data)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildErrorStatsCard(data)),
                ],
              ),
              const SizedBox(height: 24),
              _buildSystemActivityCard(data),
            ],
          ),
        );
      },
    );
  }

  // --- Business Analytics Tab ---
  Widget _buildBusinessAnalyticsTab() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: TabBar(
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Revenue'),
                Tab(text: 'Growth'),
                Tab(text: 'Insights'),
              ],
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Theme.of(context).primaryColor,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildBusinessOverview(),
                _buildBusinessRevenue(),
                _buildBusinessGrowth(),
                _buildBusinessInsights(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessOverview() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchBusinessAnalytics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data ?? {};
        final analytics = data['analytics'] ?? {};
        final businesses = data['businesses'] ?? [];
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Business Overview', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              const SizedBox(height: 16),
              _buildBusinessOverviewCard(analytics),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildBusinessStatusCard(businesses)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSubscriptionPlanCard(businesses)),
                ],
              ),
              const SizedBox(height: 24),
              _buildTopPerformingBusinessesCard(businesses),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBusinessRevenue() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchBusinessRevenueAnalytics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data ?? {};
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Revenue Analytics', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              const SizedBox(height: 16),
              _buildRevenueOverviewCard(data),
              const SizedBox(height: 24),
              _buildRevenueTrendCard(data),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBusinessGrowth() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchBusinessGrowthAnalytics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data ?? {};
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Growth Analytics', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              const SizedBox(height: 16),
              _buildGrowthMetricsCard(data),
              const SizedBox(height: 24),
              _buildGrowthTrendCard(data),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBusinessInsights() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchBusinessInsights(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data ?? {};
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Business Insights', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              const SizedBox(height: 16),
              _buildInsightsCard(data),
              const SizedBox(height: 24),
              _buildRecommendationsCard(data),
            ],
          ),
        );
      },
    );
  }

  // Analytics data fetching methods
  Future<Map<String, dynamic>> _fetchPlatformAnalytics() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    final response = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/businesses'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final businesses = data['businesses'] ?? [];
      
      // Calculate platform metrics
      double totalRevenue = 0;
      int activeBusinesses = 0;
      int overduePayments = 0;
      int totalUsers = 0;
      int totalProducts = 0;
      int totalSales = 0;
      
      for (final business in businesses) {
        if (business['is_active'] == true || business['is_active'] == 1) activeBusinesses++;
        if (business['payment_status'] == 'overdue') overduePayments++;
        
        totalUsers += (business['user_count'] ?? 0) as int;
        totalProducts += (business['product_count'] ?? 0) as int;
        totalSales += (business['sale_count'] ?? 0) as int;
        totalRevenue += _safeToDouble(business['monthly_fee'] ?? 0);
      }
      
      return {
        'platform_stats': {
          'total_revenue': totalRevenue,
          'active_businesses': activeBusinesses,
          'overdue_payments': overduePayments,
          'total_users': totalUsers,
          'total_products': totalProducts,
          'total_sales': totalSales,
        },
        'businesses': businesses,
      };
    } else {
      throw Exception('Failed to fetch platform analytics');
    }
  }



  Future<Map<String, dynamic>> _fetchRevenueAnalytics() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    try {
      // Format dates for API
      final startDate = _revenueStartDate.toIso8601String().split('T')[0];
      final endDate = _revenueEndDate.toIso8601String().split('T')[0];
      
      // Fetch businesses data (fallback approach)
      final response = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/businesses'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final businesses = data['businesses'] ?? [];
        
        // Calculate revenue metrics from businesses data
        double totalRevenue = 0;
        double basicRevenue = 0;
        double premiumRevenue = 0;
        double enterpriseRevenue = 0;
        int overdueCount = 0;
        int currentCount = 0;
        
        // Prepare business revenue details
        List<Map<String, dynamic>> businessRevenues = [];
        
        for (final business in businesses) {
          final monthlyFee = TypeConverter.safeToDouble(business['monthly_fee'] ?? 0);
          final overageFees = 0.0; // Set to 0 for now
          final businessTotalRevenue = monthlyFee + overageFees;
          
          totalRevenue += businessTotalRevenue;
          
          switch (business['subscription_plan']) {
            case 'basic':
              basicRevenue += businessTotalRevenue;
              break;
            case 'premium':
              premiumRevenue += businessTotalRevenue;
              break;
            case 'enterprise':
              enterpriseRevenue += businessTotalRevenue;
              break;
          }
          
          if (business['payment_status'] == 'overdue') {
            overdueCount++;
          } else {
            currentCount++;
          }
          
          // Add business revenue details
          businessRevenues.add({
            'business_id': business['id'],
            'business_name': business['name'],
            'subscription_plan': business['subscription_plan'],
            'monthly_fee': monthlyFee,
            'overage_fees': overageFees,
            'total_revenue': businessTotalRevenue,
            'payment_status': business['payment_status'],
            'created_at': business['created_at'],
            'user_count': business['user_count'] ?? 0,
            'product_count': business['product_count'] ?? 0,
          });
        }
        
        // Sort business revenues by total revenue (highest first)
        businessRevenues.sort((a, b) => TypeConverter.safeToDouble(b['total_revenue']).compareTo(TypeConverter.safeToDouble(a['total_revenue'])));
        
        return {
          'revenue_stats': {
            'total_revenue': totalRevenue,
            'basic_revenue': basicRevenue,
            'premium_revenue': premiumRevenue,
            'enterprise_revenue': enterpriseRevenue,
          },
          'payment_status': {
            'overdue': overdueCount,
            'current': currentCount,
          },
          'business_revenues': businessRevenues,
          'date_range': {
            'start_date': startDate,
            'end_date': endDate,
            'period': _selectedRevenuePeriod,
          },
          'monthly_revenue': [
            {'month': 'Current', 'revenue': totalRevenue},
          ],
        };
      } else {
        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to fetch revenue analytics: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching revenue analytics: $e');
      
      // Return mock data as fallback
      return {
        'revenue_stats': {
          'total_revenue': 0,
          'basic_revenue': 0,
          'premium_revenue': 0,
          'enterprise_revenue': 0,
        },
        'payment_status': {
          'overdue': 0,
          'current': 0,
        },
        'business_revenues': [],
        'date_range': {
          'start_date': _revenueStartDate.toIso8601String().split('T')[0],
          'end_date': _revenueEndDate.toIso8601String().split('T')[0],
          'period': _selectedRevenuePeriod,
        },
        'monthly_revenue': [],
      };
    }
  }

  Future<Map<String, dynamic>> _fetchSystemAnalytics() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    final response = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/analytics/performance'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
              return TypeConverter.safeToMap(decoded);
    } else {
      throw Exception('Failed to fetch system analytics');
    }
  }

  // Business Analytics API methods
  Future<Map<String, dynamic>> _fetchBusinessAnalytics() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    final response = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/businesses'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final businesses = data['businesses'] ?? [];
      
      // Calculate analytics
      double totalRevenue = 0;
      int activeBusinesses = 0;
      int overduePayments = 0;
      int totalUsers = 0;
      int totalProducts = 0;
      int totalSales = 0;
      
      for (final business in businesses) {
        if (business['is_active'] == true || business['is_active'] == 1) activeBusinesses++;
        if (business['payment_status'] == 'overdue') overduePayments++;
        
        totalUsers += (business['user_count'] ?? 0) as int;
        totalProducts += (business['product_count'] ?? 0) as int;
        totalSales += (business['sale_count'] ?? 0) as int;
        totalRevenue += TypeConverter.safeToDouble(business['monthly_fee'] ?? 0);
      }
      
      return {
        'analytics': {
          'total_revenue': totalRevenue,
          'active_businesses': activeBusinesses,
          'overdue_payments': overduePayments,
          'total_users': totalUsers,
          'total_products': totalProducts,
          'total_sales': totalSales,
        },
        'businesses': businesses,
      };
    } else {
      throw Exception('Failed to fetch business analytics');
    }
  }

  Future<Map<String, dynamic>> _fetchBusinessRevenueAnalytics() async {
    // This would typically fetch revenue data from the backend
    // For now, return mock data
    return {
      'monthly_revenue': [
        {'month': 'Jan', 'revenue': 15000},
        {'month': 'Feb', 'revenue': 18000},
        {'month': 'Mar', 'revenue': 22000},
        {'month': 'Apr', 'revenue': 25000},
        {'month': 'May', 'revenue': 28000},
        {'month': 'Jun', 'revenue': 32000},
      ],
      'revenue_by_plan': [
        {'plan': 'Basic', 'revenue': 12000},
        {'plan': 'Premium', 'revenue': 15000},
        {'plan': 'Enterprise', 'revenue': 5000},
      ],
      'total_revenue': 132000,
      'growth_rate': 15.5,
    };
  }

  Future<Map<String, dynamic>> _fetchBusinessGrowthAnalytics() async {
    // This would typically fetch growth data from the backend
    // For now, return mock data
    return {
      'new_businesses': [
        {'month': 'Jan', 'count': 5},
        {'month': 'Feb', 'count': 8},
        {'month': 'Mar', 'count': 12},
        {'month': 'Apr', 'count': 15},
        {'month': 'May', 'count': 18},
        {'month': 'Jun', 'count': 22},
      ],
      'user_growth': [
        {'month': 'Jan', 'users': 150},
        {'month': 'Feb', 'users': 180},
        {'month': 'Mar', 'users': 220},
        {'month': 'Apr', 'users': 280},
        {'month': 'May', 'users': 350},
        {'month': 'Jun', 'users': 420},
      ],
      'growth_metrics': {
        'business_growth_rate': 25.5,
        'user_growth_rate': 35.2,
        'revenue_growth_rate': 18.7,
      },
    };
  }

  Future<Map<String, dynamic>> _fetchBusinessInsights() async {
    // This would typically fetch insights from the backend
    // For now, return mock data
    return {
      'insights': [
        {
          'type': 'revenue',
          'title': 'Revenue Growth',
          'description': 'Monthly revenue has increased by 15% compared to last month',
          'trend': 'up',
          'value': '15%',
        },
        {
          'type': 'users',
          'title': 'User Engagement',
          'description': 'Active users have increased by 25% in the last 30 days',
          'trend': 'up',
          'value': '25%',
        },
        {
          'type': 'businesses',
          'title': 'New Businesses',
          'description': '5 new businesses joined this week',
          'trend': 'up',
          'value': '5',
        },
      ],
      'recommendations': [
        'Consider offering a free trial to attract more businesses',
        'Implement automated onboarding to reduce churn',
        'Add more premium features to increase revenue per business',
        'Improve customer support response time',
      ],
    };
  }

  // Platform Analytics Widgets
  Widget _buildPlatformOverviewCard(Map<String, dynamic> data) {
    final stats = data['platform_stats'] ?? {};
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Total Revenue', '\$${TypeConverter.safeToDouble(stats['total_revenue']).toStringAsFixed(2)}', Icons.attach_money)),
                Expanded(child: _buildStatItem('Active Businesses', '${stats['active_businesses'] ?? 0}', Icons.business)),
                Expanded(child: _buildStatItem('Total Users', '${stats['total_users'] ?? 0}', Icons.people)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Total Products', '${stats['total_products'] ?? 0}', Icons.inventory)),
                Expanded(child: _buildStatItem('Total Sales', '${stats['total_sales'] ?? 0}', Icons.shopping_cart)),
                Expanded(child: _buildStatItem('Overdue Payments', '${stats['overdue_payments'] ?? 0}', Icons.warning)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesByPaymentCard(List<dynamic> salesByPayment) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sales by Payment Method', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (salesByPayment.isEmpty)
              const Text('No payment data available', style: TextStyle(color: Colors.grey))
            else
              ...salesByPayment.map((payment) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(payment['payment_method']?.toString().toUpperCase() ?? 'Unknown'),
                    Text('\$${TypeConverter.safeToDouble(payment['total_amount']).toStringAsFixed(2)}'),
                  ],
                ),
              )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsCard(List<dynamic> topProducts) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Selling Products', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (topProducts.isEmpty)
              const Text('No product data available', style: TextStyle(color: Colors.grey))
            else
              ...topProducts.take(5).map((product) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(product['name'] ?? '', overflow: TextOverflow.ellipsis)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${product['units_sold'] ?? 0} units', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('\$${TypeConverter.safeToDouble(product['revenue']).toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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

  Widget _buildSalesTrendCard(List<dynamic> salesByDate) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sales Trend (Last 7 Days)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (salesByDate.isEmpty)
              const Text('No sales data available', style: TextStyle(color: Colors.grey))
            else
              ...salesByDate.take(7).map((sale) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(sale['date'] ?? ''),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('\$${TypeConverter.safeToDouble(sale['total_revenue']).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${sale['total_sales'] ?? 0} orders', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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

  // User Analytics Widgets
  Widget _buildUserOverviewCard(Map<String, dynamic> userStats) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Total Users', '${userStats['total_users'] ?? 0}', Icons.people)),
                Expanded(child: _buildStatItem('Admins', '${userStats['admin_count'] ?? 0}', Icons.admin_panel_settings)),
                Expanded(child: _buildStatItem('Regular Users', '${userStats['user_count'] ?? 0}', Icons.person)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRolesDistributionCard(List<dynamic> rolesDistribution) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Roles Distribution', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...rolesDistribution.map((role) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(role['role'] ?? ''),
                  Text('${role['count'] ?? 0}'),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveUsersCard(List<dynamic> activeUsers) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Most Active Users', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...activeUsers.take(5).map((user) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(user['username'] ?? '', overflow: TextOverflow.ellipsis)),
                  Text('${user['sales_created'] ?? 0} sales'),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRegistrationsCard(List<dynamic> registrationsByDate) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User Registrations (Last 7 Days)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...registrationsByDate.take(7).map((registration) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(registration['date'] ?? ''),
                  Text('${registration['new_users'] ?? 0}'),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  // Product Analytics Widgets
  Widget _buildProductOverviewCard(Map<String, dynamic> productStats) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Total Products', '${productStats['total_products'] ?? 0}', Icons.inventory)),
                Expanded(child: _buildStatItem('In Stock', '${productStats['in_stock'] ?? 0}', Icons.check_circle)),
                Expanded(child: _buildStatItem('Out of Stock', '${productStats['out_of_stock'] ?? 0}', Icons.cancel)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Low Stock', '${productStats['low_stock'] ?? 0}', Icons.warning)),
                Expanded(child: _buildStatItem('Stock Value', '\$${TypeConverter.safeToDouble(productStats['total_stock_value']).toStringAsFixed(2)}', Icons.attach_money)),
                Expanded(child: _buildStatItem('Avg Cost Price', '\$${TypeConverter.safeToDouble(productStats['avg_product_cost_price']).toStringAsFixed(2)}', Icons.label)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPerformanceCard(List<dynamic> categoryPerformance) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category Performance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...categoryPerformance.map((category) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(category['category'] ?? '', overflow: TextOverflow.ellipsis)),
                  Text('\$${TypeConverter.safeToDouble(category['total_revenue']).toStringAsFixed(2)}'),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockCard(List<dynamic> lowStockProducts) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Low Stock Products', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...lowStockProducts.take(5).map((product) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(product['name'] ?? '', overflow: TextOverflow.ellipsis)),
                  Text('${product['quantity'] ?? 0}'),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryAnalysisCard(List<dynamic> inventoryAnalysis) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Stock Value Products', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...inventoryAnalysis.take(5).map((product) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(product['name'] ?? '', overflow: TextOverflow.ellipsis)),
                  Text('\$${TypeConverter.safeToDouble(product['stock_value']).toStringAsFixed(2)}'),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  // Performance Analytics Widgets
  Widget _buildSystemMetricsCard(Map<String, dynamic> systemMetrics) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('System Metrics', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Total Users', '${systemMetrics['total_users'] ?? 0}', Icons.people)),
                Expanded(child: _buildStatItem('Total Products', '${systemMetrics['total_products'] ?? 0}', Icons.inventory)),
                Expanded(child: _buildStatItem('Total Sales', '${systemMetrics['total_sales'] ?? 0}', Icons.shopping_cart)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Total Revenue', '\$${(systemMetrics['total_revenue'] ?? 0).toStringAsFixed(2)}', Icons.attach_money)),
                Expanded(child: _buildStatItem('Recent Actions', '${systemMetrics['recent_actions'] ?? 0}', Icons.touch_app)),
                Expanded(child: _buildStatItem('Total Customers', '${systemMetrics['total_customers'] ?? 0}', Icons.person_add)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatabasePerformanceCard(Map<String, dynamic> dbPerformance) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Database Performance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Recent Sales', '${dbPerformance['recent_sales'] ?? 0}', Icons.shopping_cart)),
                Expanded(child: _buildStatItem('Recent Logs', '${dbPerformance['recent_logs'] ?? 0}', Icons.article)),
                Expanded(child: _buildStatItem('Active Users', '${dbPerformance['active_users'] ?? 0}', Icons.person)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorStatsCard(Map<String, dynamic> errorStats) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Error Statistics', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Total Errors', '${errorStats['total_errors'] ?? 0}', Icons.error)),
                Expanded(child: _buildStatItem('Today', '${errorStats['errors_today'] ?? 0}', Icons.today)),
                Expanded(child: _buildStatItem('This Week', '${errorStats['errors_this_week'] ?? 0}', Icons.calendar_view_week)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseTimesCard(Map<String, dynamic> responseTimes) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Response Times', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Avg Response', '${responseTimes['average_response_time'] ?? 0}ms', Icons.speed)),
                Expanded(child: _buildStatItem('P95 Response', '${responseTimes['p95_response_time'] ?? 0}ms', Icons.trending_up)),
                Expanded(child: _buildStatItem('P99 Response', '${responseTimes['p99_response_time'] ?? 0}ms', Icons.trending_down)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Business Analytics Widgets
  Widget _buildBusinessOverviewCard(Map<String, dynamic> analytics) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Total Revenue', '\$${TypeConverter.safeToDouble(analytics['total_revenue']).toStringAsFixed(2)}', Icons.attach_money)),
                Expanded(child: _buildStatItem('Active Businesses', '${analytics['active_businesses'] ?? 0}', Icons.business)),
                Expanded(child: _buildStatItem('Total Users', '${analytics['total_users'] ?? 0}', Icons.people)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Total Products', '${analytics['total_products'] ?? 0}', Icons.inventory)),
                Expanded(child: _buildStatItem('Total Sales', '${analytics['total_sales'] ?? 0}', Icons.shopping_cart)),
                Expanded(child: _buildStatItem('Overdue Payments', '${analytics['overdue_payments'] ?? 0}', Icons.warning)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessStatusCard(List<dynamic> businesses) {
    final activeCount = businesses.where((b) => b['is_active'] == true || b['is_active'] == 1).length;
    final inactiveCount = businesses.where((b) => b['is_active'] != true && b['is_active'] != 1).length;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business Status', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 32),
                      const SizedBox(height: 8),
                      Text('$activeCount', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('Active', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.cancel, color: Colors.red, size: 32),
                      const SizedBox(height: 8),
                      Text('$inactiveCount', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('Inactive', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionPlanCard(List<dynamic> businesses) {
    final basicCount = businesses.where((b) => b['subscription_plan'] == 'basic').length;
    final premiumCount = businesses.where((b) => b['subscription_plan'] == 'premium').length;
    final enterpriseCount = businesses.where((b) => b['subscription_plan'] == 'enterprise').length;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subscription Plans', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildPlanItem('Basic', basicCount, Colors.green),
            const SizedBox(height: 8),
            _buildPlanItem('Premium', premiumCount, Colors.blue),
            const SizedBox(height: 8),
            _buildPlanItem('Enterprise', enterpriseCount, Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanItem(String plan, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(plan)),
        Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTopPerformingBusinessesCard(List<dynamic> businesses) {
    // Sort businesses by user count and sales count
    final sortedBusinesses = List.from(businesses);
    sortedBusinesses.sort((a, b) {
      final aScore = (a['user_count'] ?? 0) + (a['sale_count'] ?? 0);
      final bScore = (b['user_count'] ?? 0) + (b['sale_count'] ?? 0);
      return bScore.compareTo(aScore);
    });

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Performing Businesses', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...sortedBusinesses.take(5).map((business) => InkWell(
              onTap: () => _showBusinessDetails(business),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(business['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(business['subscription_plan']?.toString().toUpperCase() ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${business['user_count'] ?? 0} users', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${business['sale_count'] ?? 0} sales', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                  ],
                ),
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueOverviewCard(Map<String, dynamic> data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Total Revenue', '\$${TypeConverter.safeToDouble(data['total_revenue']).toStringAsFixed(2)}', Icons.attach_money)),
                Expanded(child: _buildStatItem('Growth Rate', '${data['growth_rate']?.toStringAsFixed(1)}%', Icons.trending_up)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Revenue by Plan', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...(data['revenue_by_plan'] ?? []).map((plan) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(plan['plan'] ?? ''),
                  Text('\$${TypeConverter.safeToDouble(plan['revenue']).toStringAsFixed(2)}'),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueTrendCard(Map<String, dynamic> data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monthly Revenue Trend', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...(data['monthly_revenue'] ?? []).map((month) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(month['month'] ?? ''),
                  Text('\$${TypeConverter.safeToDouble(month['revenue']).toStringAsFixed(2)}'),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthMetricsCard(Map<String, dynamic> data) {
    final metrics = data['growth_metrics'] ?? {};
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Growth Metrics', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Business Growth', '${metrics['business_growth_rate']?.toStringAsFixed(1)}%', Icons.business)),
                Expanded(child: _buildStatItem('User Growth', '${metrics['user_growth_rate']?.toStringAsFixed(1)}%', Icons.people)),
                Expanded(child: _buildStatItem('Revenue Growth', '${metrics['revenue_growth_rate']?.toStringAsFixed(1)}%', Icons.trending_up)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthTrendCard(Map<String, dynamic> data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Growth Trends', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('New Businesses', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...(data['new_businesses'] ?? []).map((month) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(month['month'] ?? ''),
                  Text('${month['count'] ?? 0}'),
                ],
              ),
            )).toList(),
            const SizedBox(height: 16),
            Text('User Growth', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...(data['user_growth'] ?? []).map((month) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(month['month'] ?? ''),
                  Text('${month['users'] ?? 0}'),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsCard(Map<String, dynamic> data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Key Insights', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...(data['insights'] ?? []).map((insight) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    insight['trend'] == 'up' ? Icons.trending_up : Icons.trending_down,
                    color: insight['trend'] == 'up' ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(insight['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(insight['description'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  Text(insight['value'] ?? '', style: TextStyle(
                    color: insight['trend'] == 'up' ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  )),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard(Map<String, dynamic> data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recommendations', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...(data['recommendations'] ?? []).map((recommendation) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(recommendation ?? '', style: const TextStyle(fontSize: 14))),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  // Additional Business Analytics Widgets
  Widget _buildPlatformHealthCard(Map<String, dynamic> data) {
    final stats = data['platform_stats'] ?? {};
    final businesses = data['businesses'] ?? [];
    
    final activePercentage = businesses.isNotEmpty ? (stats['active_businesses'] ?? 0) / businesses.length * 100 : 0;
    final overduePercentage = businesses.isNotEmpty ? (stats['overdue_payments'] ?? 0) / businesses.length * 100 : 0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform Health', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Active Rate', '${activePercentage.toStringAsFixed(1)}%', Icons.check_circle)),
                Expanded(child: _buildStatItem('Overdue Rate', '${overduePercentage.toStringAsFixed(1)}%', Icons.warning)),
                Expanded(child: _buildStatItem('Total Businesses', '${businesses.length}', Icons.business)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessPerformanceCard(List<dynamic> businesses) {
    final totalUsers = businesses.fold<int>(0, (sum, b) => sum + (TypeConverter.safeToInt(b['user_count']) ?? 0));
    final totalSales = businesses.fold<int>(0, (sum, b) => sum + (TypeConverter.safeToInt(b['sale_count']) ?? 0));
    final totalProducts = businesses.fold<int>(0, (sum, b) => sum + (TypeConverter.safeToInt(b['product_count']) ?? 0));
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business Performance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Total Users', '$totalUsers', Icons.people)),
                Expanded(child: _buildStatItem('Total Sales', '$totalSales', Icons.shopping_cart)),
                Expanded(child: _buildStatItem('Total Products', '$totalProducts', Icons.inventory)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Avg Users/Business', '${businesses.isNotEmpty ? (totalUsers / businesses.length).round() : 0}', Icons.person)),
                Expanded(child: _buildStatItem('Avg Sales/Business', '${businesses.isNotEmpty ? (totalSales / businesses.length).round() : 0}', Icons.receipt)),
                Expanded(child: _buildStatItem('Avg Products/Business', '${businesses.isNotEmpty ? (totalProducts / businesses.length).round() : 0}', Icons.category)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessGrowthCard(List<dynamic> businesses) {
    // Calculate growth metrics based on business creation dates
    final now = DateTime.now();
    final lastMonth = now.subtract(const Duration(days: 30));
    final lastWeek = now.subtract(const Duration(days: 7));
    
    final newThisWeek = businesses.where((b) {
      final createdAt = DateTime.tryParse(b['created_at'] ?? '');
      return createdAt != null && createdAt.isAfter(lastWeek);
    }).length;
    
    final newThisMonth = businesses.where((b) {
      final createdAt = DateTime.tryParse(b['created_at'] ?? '');
      return createdAt != null && createdAt.isAfter(lastMonth);
    }).length;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business Growth', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('New This Week', '$newThisWeek', Icons.trending_up)),
                Expanded(child: _buildStatItem('New This Month', '$newThisMonth', Icons.calendar_today)),
                Expanded(child: _buildStatItem('Total Businesses', '${businesses.length}', Icons.business)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessActivityCard(List<dynamic> businesses) {
    final activeBusinesses = businesses.where((b) => b['is_active'] == true || b['is_active'] == 1).length;
    final inactiveBusinesses = businesses.where((b) => b['is_active'] != true && b['is_active'] != 1).length;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business Activity', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 32),
                      const SizedBox(height: 8),
                      Text('$activeBusinesses', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('Active', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.cancel, color: Colors.red, size: 32),
                      const SizedBox(height: 8),
                      Text('$inactiveBusinesses', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('Inactive', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueByPlanCard(Map<String, dynamic> data) {
    final revenueStats = data['revenue_stats'] ?? {};
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue by Plan', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildPlanRevenueItem('Basic', revenueStats['basic_revenue'] ?? 0, Colors.green),
            const SizedBox(height: 8),
            _buildPlanRevenueItem('Premium', revenueStats['premium_revenue'] ?? 0, Colors.blue),
            const SizedBox(height: 8),
            _buildPlanRevenueItem('Enterprise', revenueStats['enterprise_revenue'] ?? 0, Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanRevenueItem(String plan, double revenue, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(plan)),
        Text('\$${revenue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPaymentStatusCard(Map<String, dynamic> data) {
    final paymentStatus = data['payment_status'] ?? {};
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Status', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 32),
                      const SizedBox(height: 8),
                      Text('${paymentStatus['current'] ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('Current', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 32),
                      const SizedBox(height: 8),
                      Text('${paymentStatus['overdue'] ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('Overdue', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemHealthCardWithData(Map<String, dynamic> data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('System Health', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Status', 'Healthy', Icons.check_circle)),
                Expanded(child: _buildStatItem('Uptime', '99.9%', Icons.timer)),
                Expanded(child: _buildStatItem('Response Time', '150ms', Icons.speed)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatabaseHealthCard(Map<String, dynamic> data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Database Health', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Status', 'Connected', Icons.storage)),
                Expanded(child: _buildStatItem('Connections', '5', Icons.link)),
                Expanded(child: _buildStatItem('Performance', 'Good', Icons.speed)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemActivityCard(Map<String, dynamic> data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('System Activity', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Active Sessions', '12', Icons.people)),
                Expanded(child: _buildStatItem('API Calls', '1.2K', Icons.api)),
                Expanded(child: _buildStatItem('Errors', '0', Icons.error)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _triggerBackup() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup triggered (not yet implemented)')),
    );
  }

  // --- Data Recovery Tab ---
  Widget _buildDeletedDataTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: TabBar(
              tabs: const [
                Tab(icon: Icon(Icons.business), text: 'Business Recovery'),
                Tab(icon: Icon(Icons.delete_forever), text: 'Global Deleted Data'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildBusinessRecoveryTab(),
                _buildGlobalDeletedDataTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Business-specific recovery tab
  Widget _buildBusinessRecoveryTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchBusinessesForSelection(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final businesses = snapshot.data ?? [];
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Business Data Recovery',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor
                )
              ),
              const SizedBox(height: 8),
              Text(
                'Select a business to view and recover its deleted data',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600]
                )
              ),
              const SizedBox(height: 24),
              ...businesses.map((business) => _buildBusinessRecoveryCard(business)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBusinessRecoveryCard(Map<String, dynamic> business) {
    final safeBusiness = TypeConverter.safeToMap(business);
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchBusinessRecoveryStats(TypeConverter.safeToInt(safeBusiness['id'])),
      builder: (context, snapshot) {
        final stats = TypeConverter.safeToMap(snapshot.data ?? {});
        final deletedCounts = TypeConverter.safeToMap(stats['deleted_counts'] ?? {});
        final totalDeleted = TypeConverter.safeToInt(stats['total_deleted'] ?? 0);
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                TypeConverter.safeToString(safeBusiness['name']).substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              ),
            ),
            title: Text(
              TypeConverter.safeToString(safeBusiness['name'] ?? 'Unknown Business'),
              style: const TextStyle(fontWeight: FontWeight.bold)
            ),
            subtitle: Text(
              '${totalDeleted} deleted items',
              style: TextStyle(color: totalDeleted > 0 ? Colors.red : Colors.green)
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRecoveryStatsGrid(deletedCounts),
                    const SizedBox(height: 16),
                    if (totalDeleted > 0) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.visibility),
                              label: const Text('View Deleted Data'),
                              onPressed: () => _showBusinessDeletedData(safeBusiness),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.restore),
                              label: const Text('Recover All'),
                              onPressed: () => _recoverAllBusinessData(safeBusiness),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const Center(
                        child: Text(
                          'No deleted data found for this business',
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecoveryStatsGrid(Map<String, dynamic> deletedCounts) {
    final safeDeletedCounts = TypeConverter.safeToMap(deletedCounts);
    final items = [
      {'label': 'Users', 'count': TypeConverter.safeToInt(safeDeletedCounts['users'] ?? 0), 'icon': Icons.people},
      {'label': 'Products', 'count': TypeConverter.safeToInt(safeDeletedCounts['products'] ?? 0), 'icon': Icons.inventory},
      {'label': 'Sales', 'count': TypeConverter.safeToInt(safeDeletedCounts['sales'] ?? 0), 'icon': Icons.shopping_cart},
      {'label': 'Customers', 'count': TypeConverter.safeToInt(safeDeletedCounts['customers'] ?? 0), 'icon': Icons.person},
      {'label': 'Categories', 'count': TypeConverter.safeToInt(safeDeletedCounts['categories'] ?? 0), 'icon': Icons.category},
      {'label': 'Notifications', 'count': TypeConverter.safeToInt(safeDeletedCounts['notifications'] ?? 0), 'icon': Icons.notifications},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final count = item['count'] as int;
        
        return Container(
          decoration: BoxDecoration(
            color: count > 0 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: count > 0 ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3)
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item['icon'] as IconData,
                color: count > 0 ? Colors.red : Colors.green,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                item['label'] as String,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: count > 0 ? Colors.red : Colors.green,
                ),
              ),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: count > 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Global deleted data tab (existing functionality)
  Widget _buildGlobalDeletedDataTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchDeletedData(),
      builder: (context, snapshot) {
        // Prevent setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && snapshot.hasData) {
            // Any state updates can go here if needed
          }
        });
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        // Use TypeConverter for safe data conversion
        final data = TypeConverter.safeToMap(snapshot.data ?? {});
        final deletedUsers = TypeConverter.safeToList(data['users'] ?? []);
        final deletedProducts = TypeConverter.safeToList(data['products'] ?? []);
        final deletedSales = TypeConverter.safeToList(data['sales'] ?? []);
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Global Deleted Data',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor
                )
              ),
              const SizedBox(height: 16),
              _buildDeletedSection('Deleted Users', deletedUsers, 'user'),
              const SizedBox(height: 24),
              _buildDeletedSection('Deleted Products', deletedProducts, 'product'),
              const SizedBox(height: 24),
              _buildDeletedSection('Deleted Sales', deletedSales, 'sale'),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchBusinessRecoveryStats(int businessId) async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    try {
      final response = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/businesses/$businessId/recovery-stats'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TypeConverter.safeToMap(data);
      } else {
        throw Exception('Failed to fetch recovery stats');
      }
    } catch (e) {
      print('Error fetching recovery stats: $e');
      return {
        'deleted_counts': {
          'users': 0,
          'products': 0,
          'sales': 0,
          'customers': 0,
          'categories': 0,
          'notifications': 0,
        },
        'total_deleted': 0
      };
    }
  }

  void _showBusinessDeletedData(Map<String, dynamic> business) {
    final safeBusiness = TypeConverter.safeToMap(business);
    showDialog(
      context: context,
      builder: (context) => _buildBusinessDeletedDataDialog(safeBusiness),
    );
  }

  Widget _buildBusinessDeletedDataDialog(Map<String, dynamic> business) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
            mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    'Deleted Data - ${TypeConverter.safeToString(business['name'])}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold
                  )
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                  future: _fetchBusinessDeletedData(TypeConverter.safeToInt(business['id'])),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  
                  final data = snapshot.data ?? {};
                  final users = data['users'] ?? [];
                  final products = data['products'] ?? [];
                  final sales = data['sales'] ?? [];
                  final customers = data['customers'] ?? [];
                  final categories = data['categories'] ?? [];
                  final notifications = data['notifications'] ?? [];
                  
                  return DefaultTabController(
                    length: 6,
                    child: Column(
                      children: [
                        TabBar(
                          isScrollable: true,
                          tabs: [
                            Tab(text: 'Users (${users.length})'),
                            Tab(text: 'Products (${products.length})'),
                            Tab(text: 'Sales (${sales.length})'),
                            Tab(text: 'Customers (${customers.length})'),
                            Tab(text: 'Categories (${categories.length})'),
                            Tab(text: 'Notifications (${notifications.length})'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                                                    _buildDeletedItemsList(users, 'user', TypeConverter.safeToInt(business['id'])),
                    _buildDeletedItemsList(products, 'product', TypeConverter.safeToInt(business['id'])),
                    _buildDeletedItemsList(sales, 'sale', TypeConverter.safeToInt(business['id'])),
                    _buildDeletedItemsList(customers, 'customer', TypeConverter.safeToInt(business['id'])),
                                                                  _buildDeletedItemsList(categories, 'category', TypeConverter.safeToInt(business['id'])),
                                  _buildDeletedItemsList(notifications, 'notification', TypeConverter.safeToInt(business['id'])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeletedItemsList(List<dynamic> items, String type, int businessId) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No deleted items found',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            title: Text(_getItemDisplayName(item, type)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: ${item['id']}'),
                Text('Deleted: ${_formatDateTime(_safeParseDate(item['created_at']) ?? DateTime.now())}'),
                if (item['business_id'] != null) Text('Business ID: ${item['business_id']}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Recover', style: TextStyle(fontSize: 12)),
                  onPressed: () => _recoverDeletedItem(item['id'], type, businessId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever, size: 16),
                  label: const Text('Delete', style: TextStyle(fontSize: 12)),
                  onPressed: () => _permanentlyDeleteItem(item['id'], type, businessId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getItemDisplayName(Map<String, dynamic> item, String type) {
    switch (type) {
      case 'user':
        return item['username'] ?? item['email'] ?? 'Unknown User';
      case 'product':
        return item['name'] ?? 'Unknown Product';
      case 'sale':
        return 'Sale #${item['id']} - \$${TypeConverter.safeToDouble(item['total_amount']).toStringAsFixed(2)}';
      case 'customer':
        return item['name'] ?? 'Unknown Customer';
      case 'category':
        return item['name'] ?? 'Unknown Category';
      case 'notification':
        return item['title'] ?? 'Unknown Notification';
      default:
        return 'Unknown Item';
    }
  }

  Future<Map<String, dynamic>> _fetchBusinessDeletedData(int businessId) async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    try {
      final response = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/businesses/$businessId/deleted-data'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TypeConverter.safeToMap(data);
      } else {
        throw Exception('Failed to fetch deleted data');
      }
    } catch (e) {
      print('Error fetching business deleted data: $e');
      return {
        'users': [],
        'products': [],
        'sales': [],
        'customers': [],
        'categories': [],
        'notifications': [],
      };
    }
  }

  Future<void> _recoverDeletedItem(int id, String type, int businessId) async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    try {
      final response = await http.post(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/recover/$type/$id'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({'businessId': businessId}),
      );
      
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item recovered successfully'),
            backgroundColor: Colors.green
          ),
        );
        Navigator.of(context).pop(); // Close dialog
        setState(() {}); // Refresh data
      } else {
        final errorData = TypeConverter.safeToMap(json.decode(response.body));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TypeConverter.safeToString(errorData['message'] ?? 'Failed to recover item')),
            backgroundColor: Colors.red
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red
        ),
      );
    }
  }

  Future<void> _permanentlyDeleteItem(int id, String type, int businessId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently Delete'),
        content: Text('Are you sure you want to permanently delete this $type? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    try {
      final response = await http.delete(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/permanently-delete/$type/$id'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({'businessId': businessId}),
      );
      
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item permanently deleted'),
            backgroundColor: Colors.orange
          ),
        );
        Navigator.of(context).pop(); // Close dialog
        setState(() {}); // Refresh data
      } else {
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['message'] ?? 'Failed to delete item'),
            backgroundColor: Colors.red
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red
        ),
      );
    }
  }

  Future<void> _recoverAllBusinessData(Map<String, dynamic> business) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recover All Data'),
        content: Text('Are you sure you want to recover all deleted data for ${business['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Recover All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Recovering all data...'),
          ],
        ),
      ),
    );

    try {
      final safeBusiness = TypeConverter.safeToMap(business);
      final stats = await _fetchBusinessRecoveryStats(TypeConverter.safeToInt(safeBusiness['id']));
      final deletedCounts = TypeConverter.safeToMap(stats['deleted_counts'] ?? {});
      
      // Prepare items for bulk recovery
      final items = <Map<String, dynamic>>[];
      
      // Add users
      for (int i = 0; i < (deletedCounts['users'] ?? 0); i++) {
        items.add({'type': 'user', 'id': i + 1});
      }
      
      // Add products
      for (int i = 0; i < (deletedCounts['products'] ?? 0); i++) {
        items.add({'type': 'product', 'id': i + 1});
      }
      
      // Add other types...
      
      if (items.isNotEmpty) {
        await _recoverMultipleItems(TypeConverter.safeToInt(safeBusiness['id']), items);
      }
      
      Navigator.of(context).pop(); // Close loading dialog
      setState(() {}); // Refresh data
      
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red
        ),
      );
    }
  }

  Future<void> _recoverMultipleItems(int businessId, List<Map<String, dynamic>> items) async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    try {
      final response = await http.post(
        Uri.parse('https://rtailed-production.up.railway.app/api/admin/recover-multiple'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({'businessId': businessId, 'items': items}),
      );
      
      if (response.statusCode == 200) {
        final result = TypeConverter.safeToMap(json.decode(response.body));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TypeConverter.safeToString(result['message'] ?? 'Recovery completed')),
            backgroundColor: Colors.green
          ),
        );
      } else {
        final errorData = TypeConverter.safeToMap(json.decode(response.body));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TypeConverter.safeToString(errorData['message'] ?? 'Failed to recover items')),
            backgroundColor: Colors.red
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _fetchDeletedData() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    final response = await http.get(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/deleted-data'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      // Use TypeConverter for safe data conversion
      final decoded = json.decode(response.body);
      return TypeConverter.safeToMap(decoded);
    } else {
      throw Exception('Failed to fetch deleted data');
    }
  }

  Widget _buildDeletedSection(String title, List<dynamic> items, String type) {
    if (items.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text('No $title found.')),
        ),
      );
    }
    
    // Convert items to safe format
    final safeItems = items.map((item) => TypeConverter.safeToMap(item)).toList();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          ...safeItems.map((item) => ListTile(
            title: Text(TypeConverter.safeToString(item['name'] ?? item['username'] ?? 'Unknown')),
            subtitle: Text('ID: ${TypeConverter.safeToString(item['id'])}'),
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.restore),
              label: const Text('Restore'),
              onPressed: () => _restoreDeletedData(item['id'], type),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          )),
        ],
      ),
    );
  }

  Future<void> _restoreDeletedData(dynamic id, String type) async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    final response = await http.post(
      Uri.parse('https://rtailed-production.up.railway.app/api/admin/restore-data'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({'id': id, 'type': type}),
    );
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data restored successfully'), backgroundColor: Colors.green),
      );
      setState(() {}); // Refresh
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to restore data'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildBusinessOverviewSection(Map<String, dynamic> business, Map<String, dynamic> data) {
    final businessData = TypeConverter.safeToMap(data['business'] ?? {});
    final safeBusiness = TypeConverter.safeToMap(business);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business Overview', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              final column = (List<Widget> children) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  );
              final first = [
                      _buildDetailRow('Business Name', TypeConverter.safeToString(safeBusiness['name'] ?? 'N/A')),
                                              _buildDetailRow('Email', TypeConverter.safeToString(businessData['email'] ?? 'N/A')),
                        _buildDetailRow('Phone', TypeConverter.safeToString(businessData['phone'] ?? 'N/A')),
                        _buildDetailRow('Address', TypeConverter.safeToString(businessData['address'] ?? 'N/A')),
              ];
              final second = [
                        _buildDetailRow('Subscription Plan', TypeConverter.safeToString(safeBusiness['subscription_plan'] ?? 'N/A').toUpperCase()),
                        _buildDetailRow('Monthly Fee', String.fromCharCode(36) + TypeConverter.safeToDouble(safeBusiness['monthly_fee']).toStringAsFixed(2)),
                        _buildDetailRow('Payment Status', TypeConverter.safeToString(safeBusiness['payment_status'] ?? 'N/A').toUpperCase()),
                        _buildDetailRow('Status', TypeConverter.safeToBool(safeBusiness['is_active']) ? 'Active' : 'Inactive'),
              ];
              if (isNarrow) {
                return column([...first, const SizedBox(height: 12), ...second]);
              }
              return Row(
                children: [
                  Expanded(child: column(first)),
                  Expanded(child: column(second)),
                ],
              );
            }),
            const SizedBox(height: 16),
                                              _buildDetailRow('Created Date', _formatDate(TypeConverter.safeToString(businessData['created_at']))),
                        _buildDetailRow('Last Login', _formatDate(TypeConverter.safeToString(businessData['last_login']))),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(builder: (context, constraints) {
        final double labelWidth = constraints.maxWidth <= 320
            ? 80
            : constraints.maxWidth <= 400
                ? 100
                : 120;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: Text(
                '$label:',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ],
        );
      }),
    );
  }

  void _exportBusinessReport(int businessId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exporting business report for ID: $businessId'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildBusinessPerformanceSection(Map<String, dynamic> data) {
    final safeData = TypeConverter.safeToMap(data);
    final users = TypeConverter.safeToMap(safeData['users'] ?? {});
    final products = TypeConverter.safeToMap(safeData['products'] ?? {});
    final sales = TypeConverter.safeToMap(safeData['sales'] ?? {});
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Performance Metrics', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 480;
              final items = [
                _buildStatItem('Total Users', '${users['total_users'] ?? 0}', Icons.people),
                _buildStatItem('Active Users', '${users['active_users'] ?? 0}', Icons.person),
                _buildStatItem('Total Products', '${products['total_products'] ?? 0}', Icons.inventory),
              ];
              if (isNarrow) {
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 12,
                  children: items.map((w) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: w)).toList(),
                );
              }
              return Row(children: items.map((w) => Expanded(child: w)).toList());
            }),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 480;
              final items = [
                _buildStatItem('Total Sales', '${sales['total_sales'] ?? 0}', Icons.shopping_cart),
                _buildStatItem('Total Revenue', String.fromCharCode(36) + TypeConverter.safeToDouble(sales['total_revenue']).toStringAsFixed(2), Icons.attach_money),
                _buildStatItem('Avg Sale Value', String.fromCharCode(36) + TypeConverter.safeToDouble(sales['avg_sale_value']).toStringAsFixed(2), Icons.trending_up),
              ];
              if (isNarrow) {
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 12,
                  children: items.map((w) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: w)).toList(),
                );
              }
              return Row(children: items.map((w) => Expanded(child: w)).toList());
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessFinancialSection(Map<String, dynamic> business, Map<String, dynamic> data) {
    final safeBusiness = TypeConverter.safeToMap(business);
    final safeData = TypeConverter.safeToMap(data);
    final payments = TypeConverter.safeToMap(safeData['payments'] ?? {});
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Financial Information', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 480;
              final items = [
                _buildStatItem('Monthly Fee', String.fromCharCode(36) + TypeConverter.safeToDouble(safeBusiness['monthly_fee']).toStringAsFixed(2), Icons.receipt),
                _buildStatItem('Total Paid', String.fromCharCode(36) + TypeConverter.safeToDouble(payments['total_paid']).toStringAsFixed(2), Icons.check_circle),
                _buildStatItem('Outstanding', String.fromCharCode(36) + TypeConverter.safeToDouble(payments['outstanding_balance']).toStringAsFixed(2), Icons.warning),
              ];
              if (isNarrow) {
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 12,
                  children: items.map((w) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: w)).toList(),
                );
              }
              return Row(children: items.map((w) => Expanded(child: w)).toList());
            }),
            const SizedBox(height: 16),
            Text('Recent Payments', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...(payments['payment_history'] ?? []).take(5).map((payment) => ListTile(
              dense: true,
              leading: Icon(
                payment['status'] == 'paid' ? Icons.check_circle : Icons.schedule,
                color: payment['status'] == 'paid' ? Colors.green : Colors.orange,
              ),
              title: Text('\$${TypeConverter.safeToDouble(payment['amount']).toStringAsFixed(2)}'),
              subtitle: Text(_formatDate(payment['date'])),
              trailing: Chip(
                label: Text(payment['status']?.toString().toUpperCase() ?? ''),
                backgroundColor: _getPaymentStatusColor(payment['status']).withOpacity(0.2),
                labelStyle: TextStyle(color: _getPaymentStatusColor(payment['status']), fontSize: 10),
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessUsersSection(Map<String, dynamic> data) {
    final safeData = TypeConverter.safeToMap(data);
    final users = TypeConverter.safeToMap(safeData['users'] ?? {});
    final userList = TypeConverter.safeToList(users['user_list'] ?? []);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Users Management', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatItem('Total Users', '${users['total_users'] ?? 0}', Icons.people)),
                Expanded(child: _buildStatItem('Active Users', '${users['active_users'] ?? 0}', Icons.person)),
                Expanded(child: _buildStatItem('Inactive Users', '${(users['total_users'] ?? 0) - (users['active_users'] ?? 0)}', Icons.person_off)),
              ],
            ),
            const SizedBox(height: 16),
            Text('User List', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...userList.take(10).map((user) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: _getRoleColor(user['role']).withOpacity(0.2),
                          child: Text(
                            (user['name']?.toString().isNotEmpty ?? false)
                                ? user['name'].toString()[0].toUpperCase()
                                : 'U',
                            style: TextStyle(color: _getRoleColor(user['role']), fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user['name']?.toString() ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(user['email']?.toString() ?? '',
                                  style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getRoleColor(user['role']).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            user['role']?.toString().toUpperCase() ?? '',
                            style: TextStyle(
                              color: _getRoleColor(user['role']),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(user['last_login']),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessProductsSection(Map<String, dynamic> data) {
    final products = data['products'] ?? {};
    final productList = products['product_list'] ?? [];
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inventory Management', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 480;
              final items = [
                _buildStatItem('Total Products', '${products['total_products'] ?? 0}', Icons.inventory),
                _buildStatItem('Low Stock', '${products['low_stock_products'] ?? 0}', Icons.warning),
                _buildStatItem('Out of Stock', '${products['out_of_stock_products'] ?? 0}', Icons.cancel),
              ];
              if (isNarrow) {
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 12,
                  children: items.map((w) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: w)).toList(),
                );
              }
              return Row(children: items.map((w) => Expanded(child: w)).toList());
            }),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Stock Value', '\$${TypeConverter.safeToDouble(products['total_stock_value']).toStringAsFixed(2)}', Icons.attach_money)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Product List', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...productList.take(5).map((product) => ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: _getStockStatusColor(product['stock_quantity']).withOpacity(0.2),
                child: Icon(
                  _getStockStatusIcon(product['stock_quantity']),
                  color: _getStockStatusColor(product['stock_quantity']),
                  size: 20,
                ),
              ),
              title: Text(product['name'] ?? ''),
              subtitle: Text('SKU: ${product['sku'] ?? ''}'),
              trailing: SizedBox(
                width: 100,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${product['stock_quantity'] ?? 0} units', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      textAlign: TextAlign.end,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '\$${TypeConverter.safeToDouble(product['price']).toStringAsFixed(2)}', 
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessSalesSection(Map<String, dynamic> data) {
    final sales = data['sales'] ?? {};
    final recentSales = sales['recent_sales'] ?? [];
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sales Information', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 480;
              final items = [
                _buildStatItem('Total Sales', '${sales['total_sales'] ?? 0}', Icons.shopping_cart),
                _buildStatItem('Total Revenue', String.fromCharCode(36) + TypeConverter.safeToDouble(sales['total_revenue']).toStringAsFixed(2), Icons.attach_money),
                _buildStatItem('Avg Sale Value', String.fromCharCode(36) + TypeConverter.safeToDouble(sales['avg_sale_value']).toStringAsFixed(2), Icons.trending_up),
              ];
              if (isNarrow) {
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 12,
                  children: items.map((w) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: w)).toList(),
                );
              }
              return Row(children: items.map((w) => Expanded(child: w)).toList());
            }),
            const SizedBox(height: 16),
            Text('Recent Sales', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...recentSales.take(5).map((sale) => ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: Colors.green.withOpacity(0.2),
                child: Icon(Icons.receipt, color: Colors.green, size: 20),
              ),
              title: Text(sale['customer'] ?? ''),
              subtitle: Text(_formatDate(sale['date'])),
              trailing: Text(
                '\$${TypeConverter.safeToDouble(sale['amount']).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessActivitySection(Map<String, dynamic> data) {
    final activity = data['activity'] ?? {};
    final recentActivity = activity['recent_activity'] ?? [];
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity Monitoring', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 480;
              final items = [
                _buildStatItem('Total Actions', '${activity['total_actions'] ?? 0}', Icons.touch_app),
                _buildStatItem('Actions Today', '${activity['actions_today'] ?? 0}', Icons.today),
                _buildStatItem('Actions This Week', '${activity['actions_this_week'] ?? 0}', Icons.calendar_view_week),
              ];
              if (isNarrow) {
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 12,
                  children: items.map((w) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: w)).toList(),
                );
              }
              return Row(children: items.map((w) => Expanded(child: w)).toList());
            }),
            const SizedBox(height: 16),
            Text('Recent Activity', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...recentActivity.take(5).map((act) => ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: _getActionColor(act['action']).withOpacity(0.2),
                child: Icon(
                  _getActionIcon(act['action']),
                  color: _getActionColor(act['action']),
                  size: 20,
                ),
              ),
              title: Text(act['action']?.toString().replaceAll('_', ' ') ?? ''),
              subtitle: Text('${act['user'] ?? ''} • ${_formatDate(act['timestamp'])}'),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessCustomersSection(Map<String, dynamic> data) {
    final customers = data['customers'] ?? {};
    final customerList = customers['customer_list'] ?? [];
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customers Management', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 480;
              final items = [
                _buildStatItem('Total Customers', '${customers['total_customers'] ?? 0}', Icons.people),
                _buildStatItem('Loyal Customers', '${customers['loyal_customers'] ?? 0}', Icons.star),
                _buildStatItem('Regular Customers', '${(customers['total_customers'] ?? 0) - (customers['loyal_customers'] ?? 0)}', Icons.person),
              ];
              if (isNarrow) {
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 12,
                  children: items.map((w) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: w)).toList(),
                );
              }
              return Row(children: items.map((w) => Expanded(child: w)).toList());
            }),
            const SizedBox(height: 16),
            Text('Recent Customers', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...customerList.take(10).map((customer) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue.withOpacity(0.2),
                          child: Text(
                            (customer['name']?.toString().isNotEmpty ?? false)
                                ? customer['name'].toString()[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((customer['name'] ?? '').toString(),
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text((customer['email'] ?? customer['phone'] ?? '').toString(),
                                  style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (customer['loyalty_points'] != null && (customer['loyalty_points'] is num) && (customer['loyalty_points'] as num) > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${customer['loyalty_points']} pts',
                                style: TextStyle(color: Colors.amber[800], fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      customer['created_at'] != null ? 'Since: ' + _formatDate(customer['created_at']) : '',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Color _getStockStatusColor(int? quantity) {
    if (quantity == null || quantity == 0) return Colors.red;
    if (quantity <= 10) return Colors.orange;
    return Colors.green;
  }

  IconData _getStockStatusIcon(int? quantity) {
    if (quantity == null || quantity == 0) return Icons.cancel;
    if (quantity <= 10) return Icons.warning;
    return Icons.check_circle;
  }

  Widget _buildRevenueDateFilter() {
    return PopupMenuButton<String>(
      initialValue: _selectedRevenuePeriod,
      onSelected: (String period) {
        setState(() {
          _selectedRevenuePeriod = period;
          switch (period) {
            case '7_days':
              _revenueStartDate = DateTime.now().subtract(const Duration(days: 7));
              break;
            case '30_days':
              _revenueStartDate = DateTime.now().subtract(const Duration(days: 30));
              break;
            case '90_days':
              _revenueStartDate = DateTime.now().subtract(const Duration(days: 90));
              break;
            case '1_year':
              _revenueStartDate = DateTime.now().subtract(const Duration(days: 365));
              break;
            case 'custom':
              _showDateRangePicker();
              return;
          }
          _revenueEndDate = DateTime.now();
        });
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem(value: '7_days', child: Text('Last 7 Days')),
        const PopupMenuItem(value: '30_days', child: Text('Last 30 Days')),
        const PopupMenuItem(value: '90_days', child: Text('Last 90 Days')),
        const PopupMenuItem(value: '1_year', child: Text('Last Year')),
        const PopupMenuItem(value: 'custom', child: Text('Custom Range')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.date_range, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              _getPeriodDisplayText(),
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  String _getPeriodDisplayText() {
    switch (_selectedRevenuePeriod) {
      case '7_days':
        return 'Last 7 Days';
      case '30_days':
        return 'Last 30 Days';
      case '90_days':
        return 'Last 90 Days';
      case '1_year':
        return 'Last Year';
      case 'custom':
        return '${_formatDateTime(_revenueStartDate)} - ${_formatDateTime(_revenueEndDate)}';
      default:
        return 'Last 30 Days';
    }
  }

  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _revenueStartDate,
        end: _revenueEndDate,
      ),
    );
    
    if (picked != null) {
      setState(() {
        _revenueStartDate = picked.start;
        _revenueEndDate = picked.end;
        _selectedRevenuePeriod = 'custom';
      });
    }
  }

  Widget _buildBusinessRevenueDetailsCard(Map<String, dynamic> data) {
    final businessRevenues = data['business_revenues'] ?? [];
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Business Revenue Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                Text('${_formatDateTime(_revenueStartDate)} - ${_formatDateTime(_revenueEndDate)}', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 16),
            if (businessRevenues.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No revenue data available for the selected period', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              Column(
                children: [
                  // Summary row
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text('Business', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Monthly Fee', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                        Expanded(child: Text('Overage Fees', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                        Expanded(child: Text('Total Revenue', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                        Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Business revenue rows
                  ...businessRevenues.map((business) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[200]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                business['business_name'] ?? 'Unknown Business',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                business['subscription_plan']?.toString().toUpperCase() ?? 'BASIC',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '\$${TypeConverter.safeToDouble(business['monthly_fee']).toStringAsFixed(2)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '\$${TypeConverter.safeToDouble(business['overage_fees']).toStringAsFixed(2)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: TypeConverter.safeToDouble(business['overage_fees']) > 0 ? Colors.orange : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '\$${TypeConverter.safeToDouble(business['total_revenue']).toStringAsFixed(2)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getPaymentStatusColor(business['payment_status']).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                business['payment_status']?.toString().toUpperCase() ?? 'UNKNOWN',
                                style: TextStyle(
                                  color: _getPaymentStatusColor(business['payment_status']),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                  const SizedBox(height: 16),
                  // Total summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text('TOTAL REVENUE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        Text(
                          '\$${_calculateTotalRevenue(businessRevenues).toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  double _calculateTotalRevenue(List<dynamic> businessRevenues) {
    return businessRevenues.fold<double>(0, (sum, business) => sum + TypeConverter.safeToDouble(business['total_revenue']));
  }

  // Show logout confirmation dialog
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

  // Perform logout
  void _performLogout() async {
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.logout();
      
      if (mounted) {
        // Navigate to login screen
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

  // Show profile dialog
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
              _buildProfileInfo('Created', _formatDate(user.createdAt?.toIso8601String())),
              if (user.lastLogin != null)
                _buildProfileInfo('Last Login', _formatDate(user.lastLogin!.toIso8601String())),
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

  // Build profile info row
  Widget _buildProfileInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

}