import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/utils/theme.dart';
import 'package:retail_management/widgets/notification_badge.dart';
import 'package:retail_management/widgets/branded_app_bar.dart';

import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/type_converter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SuperadminDashboardSimple extends StatefulWidget {
  const SuperadminDashboardSimple({super.key});

  @override
  State<SuperadminDashboardSimple> createState() => _SuperadminDashboardSimpleState();
}

class _SuperadminDashboardSimpleState extends State<SuperadminDashboardSimple> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;
  
  // Data storage
  List<Map<String, dynamic>> _allBusinesses = [];
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allPayments = [];
  List<Map<String, dynamic>> _allMessages = [];
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
    
      _loadDashboardData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;
      
      if (token != null) {
        await Future.wait([
          _loadBusinesses(token),
          _loadUsers(token),
          _loadPayments(token),
          _loadMessages(token),
          _loadNotifications(token),
        ]);
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBusinesses(String token) async {
    try {
      final apiService = ApiService();
      apiService.setToken(token);
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/businesses'),
        headers: apiService.headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final businesses = data['businesses'] ?? [];
        setState(() {
          _allBusinesses = TypeConverter.convertMySQLList(businesses);
        });
      }
    } catch (e) {
      print('Error loading businesses: $e');
    }
  }

  Future<void> _loadUsers(String token) async {
    try {
      final apiService = ApiService();
      apiService.setToken(token);
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/users'),
        headers: apiService.headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final users = data['users'] ?? [];
        setState(() {
          _allUsers = TypeConverter.convertMySQLList(users);
        });
      }
    } catch (e) {
      print('Error loading users: $e');
    }
  }

  Future<void> _loadPayments(String token) async {
    try {
      final apiService = ApiService();
      apiService.setToken(token);
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/payments'),
        headers: apiService.headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final payments = data['payments'] ?? [];
        setState(() {
          _allPayments = TypeConverter.convertMySQLList(payments);
        });
      }
    } catch (e) {
      print('Error loading payments: $e');
    }
  }

  Future<void> _loadMessages(String token) async {
    try {
      final apiService = ApiService();
      apiService.setToken(token);
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/messages'),
        headers: apiService.headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final messages = data['messages'] ?? [];
        setState(() {
          _allMessages = TypeConverter.convertMySQLList(messages);
        });
      }
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  Future<void> _loadNotifications(String token) async {
    try {
      final apiService = ApiService();
      apiService.setToken(token);
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/notifications'),
        headers: apiService.headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final notifications = data['notifications'] ?? [];
        setState(() {
          _notifications = TypeConverter.convertMySQLList(notifications);
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildOverviewScreen(),
      _buildBusinessesScreen(),
      _buildUsersScreen(),
      _buildAnalyticsScreen(),
      _buildSettingsScreen(),
    ];

    final List<BottomNavigationBarItem> navItems = [
      BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_outlined),
        activeIcon: Icon(Icons.dashboard),
        label: 'Overview',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.business_outlined),
        activeIcon: Icon(Icons.business),
        label: 'Businesses',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.people_outlined),
        activeIcon: Icon(Icons.people),
        label: 'Users',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.analytics_outlined),
        activeIcon: Icon(Icons.analytics),
        label: 'Analytics',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.settings_outlined),
        activeIcon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];

    return Scaffold(
      body: Column(
        children: [

          // Main content
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : screens[_currentIndex],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
              _animationController.reset();
              _animationController.forward();
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: surfaceColor,
            selectedItemColor: primaryGradientStart,
            unselectedItemColor: textSecondary,
            elevation: 0,
            selectedLabelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            items: navItems,
          ),
        ),
      ),
      appBar: BrandedAppBar(
        title: _getAppBarTitle(),
        actions: [
          // Refresh button
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
          // Notification Bell with Badge
          NotificationBadge(
            onTap: () {
              // TODO: Navigate to notifications
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          // User Profile Menu
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutDialog();
              } else if (value == 'profile') {
                // TODO: Navigate to profile
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: textPrimary),
                    const SizedBox(width: 12),
                    Text('Profile', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: errorColor),
                    const SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: GoogleFonts.poppins(color: errorColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Overview';
      case 1:
        return 'Businesses';
      case 2:
        return 'Users';
      case 3:
        return 'Analytics';
      case 4:
        return 'Settings';
      default:
        return 'Superadmin Dashboard';
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
              Navigator.of(context).pushReplacementNamed('/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // Screen builders
  Widget _buildOverviewScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Businesses',
                  _allBusinesses.length.toString(),
                  Icons.business,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Users',
                  _allUsers.length.toString(),
                  Icons.people,
                  Colors.green,
                ),
          ),
        ],
      ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Revenue',
                  '\$${_calculateTotalRevenue()}',
                  Icons.attach_money,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Active Businesses',
                  _allBusinesses.where((b) => b['is_active'] == true || b['is_active'] == 1).length.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Recent Activity
          Text(
            'Recent Activity',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildRecentActivityCard(),
          
          const SizedBox(height: 24),
          
          // System Status
          Text(
            'System Status',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildSystemStatusCard(),
        ],
      ),
    );
  }

  Widget _buildBusinessesScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Add button
          Row(
            children: [
              Expanded(
                child: Text(
                  'All Businesses',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddBusinessDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Business'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Business Stats
          Row(
                      children: [
              Expanded(
                child: _buildStatCard(
                  'Total',
                  _allBusinesses.length.toString(),
                  Icons.business,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Active',
                  _allBusinesses.where((b) => b['is_active'] == true || b['is_active'] == 1).length.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Inactive',
                  _allBusinesses.where((b) => b['is_active'] == false || b['is_active'] == 0).length.toString(),
                  Icons.pause_circle,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Businesses List
          ..._allBusinesses.map((business) => _buildBusinessCard(business)).toList(),
          
          if (_allBusinesses.isEmpty)
            _buildEmptyStateCard(
              'No businesses',
              'No businesses have been registered yet',
              Icons.business,
              Colors.grey,
            ),
        ],
      ),
    );
  }

  Widget _buildUsersScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Add button
          Row(
            children: [
              Expanded(
                child: Text(
                  'All Users',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddUserDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add User'),
          ),
        ],
      ),
          const SizedBox(height: 16),
          
          // User Stats
          Row(
              children: [
              Expanded(
                child: _buildStatCard(
                  'Total Users',
                  _allUsers.length.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Active Users',
                  _allUsers.where((u) => u['is_active'] == true || u['is_active'] == 1).length.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Users List
          ..._allUsers.map((user) => _buildUserCard(user)).toList(),
          
          if (_allUsers.isEmpty)
            _buildEmptyStateCard(
              'No users',
              'No users have been registered yet',
              Icons.people,
              Colors.grey,
            ),
              ],
            ),
    );
  }

  Widget _buildAnalyticsScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analytics',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Revenue Analytics
          _buildAnalyticsCard(
            'Revenue Overview',
            Icons.attach_money,
            Colors.green,
            [
              _buildStatRow('Total Revenue', '\$${_calculateTotalRevenue()}'),
              _buildStatRow('This Month', '\$${_calculateMonthlyRevenue()}'),
              _buildStatRow('Last Month', '\$${_calculateLastMonthRevenue()}'),
            ],
          ),
          const SizedBox(height: 16),
          
          // Business Analytics
          _buildAnalyticsCard(
            'Business Analytics',
            Icons.business,
            Colors.blue,
            [
              _buildStatRow('Total Businesses', _allBusinesses.length.toString()),
              _buildStatRow('Active Businesses', _allBusinesses.where((b) => b['is_active'] == true || b['is_active'] == 1).length.toString()),
              _buildStatRow('Avg Revenue/Business', '\$${_calculateAverageRevenuePerBusiness()}'),
            ],
          ),
          const SizedBox(height: 16),
          
          // User Analytics
          _buildAnalyticsCard(
            'User Analytics',
            Icons.people,
            Colors.orange,
            [
              _buildStatRow('Total Users', _allUsers.length.toString()),
              _buildStatRow('Active Users', _allUsers.where((u) => u['is_active'] == true || u['is_active'] == 1).length.toString()),
              _buildStatRow('Users per Business', '${_calculateUsersPerBusiness()}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // System Settings
          _buildSettingsCard(
            'System Settings',
            Icons.settings,
            Colors.blue,
            [
              _buildSettingRow('Database Status', 'Online', Colors.green),
              _buildSettingRow('API Status', 'Online', Colors.green),
              _buildSettingRow('File Storage', 'Online', Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          
          // Admin Actions
          _buildSettingsCard(
            'Admin Actions',
            Icons.admin_panel_settings,
            Colors.orange,
            [
              _buildActionRow('Reset All Passwords', Icons.lock_reset, () => _showResetPasswordsDialog()),
              _buildActionRow('Send Announcement', Icons.announcement, () => _showAnnouncementDialog()),
              _buildActionRow('System Backup', Icons.backup, () => _showBackupDialog()),
            ],
          ),
          const SizedBox(height: 16),
          
          // Data Management
          _buildSettingsCard(
            'Data Management',
            Icons.storage,
            Colors.purple,
            [
              _buildActionRow('Export All Data', Icons.download, () => _showExportDialog()),
              _buildActionRow('Clean Old Data', Icons.cleaning_services, () => _showCleanDataDialog()),
              _buildActionRow('Optimize Database', Icons.tune, () => _showOptimizeDialog()),
            ],
          ),
        ],
      ),
    );
  }

  // Helper widgets
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessCard(Map<String, dynamic> business) {
    final name = business['name'] ?? 'Unknown Business';
    final email = business['email'] ?? '';
    final isActive = business['is_active'] ?? false;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.business,
              color: isActive ? Colors.green : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
              fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  email,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isActive ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final username = user['username'] ?? 'Unknown User';
    final email = user['email'] ?? '';
    final role = user['role'] ?? 'user';
    final isActive = user['is_active'] ?? false;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.person,
              color: isActive ? Colors.green : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
                  username,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
              fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  email,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  role.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isActive ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard(String title, String message, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 48),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
              Icon(Icons.history, color: Colors.blue),
              const SizedBox(width: 8),
          Text(
                'Recent Activity',
                style: GoogleFonts.poppins(
                  fontSize: 16,
              fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildActivityItem('New business registered', '2 hours ago', Icons.business),
          _buildActivityItem('Payment received', '4 hours ago', Icons.payment),
          _buildActivityItem('User login', '6 hours ago', Icons.login),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String activity, String time, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              activity,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
          Text(
            time,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
              Icon(Icons.monitor_heart, color: Colors.green),
              const SizedBox(width: 8),
          Text(
                'System Status',
                style: GoogleFonts.poppins(
                  fontSize: 16,
              fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatusItem('Database', 'Online', Colors.green),
          _buildStatusItem('API Server', 'Online', Colors.green),
          _buildStatusItem('File Storage', 'Online', Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String service, String status, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            service,
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                status,
                style: GoogleFonts.poppins(
                  fontSize: 14,
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

  Widget _buildAnalyticsCard(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
              Icon(icon, color: color),
              const SizedBox(width: 8),
          Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
              fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
              Icon(icon, color: color),
              const SizedBox(width: 8),
                  Text(
                    title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 14),
          ),
                  Text(
                    value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: valueColor,
              fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildActionRow(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // Utility methods
  double _calculateTotalRevenue() {
    return _allPayments.fold(0.0, (sum, payment) => sum + (payment['amount'] ?? 0.0));
  }

  double _calculateMonthlyRevenue() {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    return _allPayments
        .where((payment) {
          final paymentDate = _safeParseDate(payment['created_at']);
          return paymentDate != null && paymentDate.isAfter(thisMonth);
        })
        .fold(0.0, (sum, payment) => sum + (payment['amount'] ?? 0.0));
  }

  double _calculateLastMonthRevenue() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    final thisMonth = DateTime(now.year, now.month);
    return _allPayments
        .where((payment) {
          final paymentDate = _safeParseDate(payment['created_at']);
          return paymentDate != null && 
                 paymentDate.isAfter(lastMonth) && 
                 paymentDate.isBefore(thisMonth);
        })
        .fold(0.0, (sum, payment) => sum + (payment['amount'] ?? 0.0));
  }

  double _calculateAverageRevenuePerBusiness() {
    if (_allBusinesses.isEmpty) return 0.0;
    return _calculateTotalRevenue() / _allBusinesses.length;
  }

  double _calculateUsersPerBusiness() {
    if (_allBusinesses.isEmpty) return 0.0;
    return _allUsers.length / _allBusinesses.length;
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

  // Dialog stubs
  void _showAddBusinessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Business'),
        content: const Text('Add business functionality will be implemented here.'),
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

  void _showResetPasswordsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Passwords'),
        content: const Text('This will reset all user passwords. Continue?'),
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

  void _showAnnouncementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Announcement'),
        content: const Text('Send announcement functionality will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('System Backup'),
        content: const Text('Create system backup functionality will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Backup'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export All Data'),
        content: const Text('Export data functionality will be implemented here.'),
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

  void _showCleanDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clean Old Data'),
        content: const Text('Clean old data functionality will be implemented here.'),
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

  void _showOptimizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Optimize Database'),
        content: const Text('Optimize database functionality will be implemented here.'),
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
} 