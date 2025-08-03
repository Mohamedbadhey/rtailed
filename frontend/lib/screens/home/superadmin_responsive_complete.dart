import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/utils/translate.dart';

class SuperadminDashboardResponsive extends StatefulWidget {
  const SuperadminDashboardResponsive({super.key});

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
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Responsive breakpoints
    final isExtraSmall = screenWidth < 360;  // Very small phones
    final isSmall = screenWidth < 480;       // Small phones
    final isMobile = screenWidth < 768;      // Phones and small tablets
    final isTablet = screenWidth >= 768 && screenWidth < 1024;  // Tablets
    final isDesktop = screenWidth >= 1024;   // Desktops
    final isLargeDesktop = screenWidth >= 1440; // Large desktops
    
    return Scaffold(
      appBar: _buildResponsiveAppBar(isMobile, isExtraSmall, isSmall),
      body: _buildResponsiveBody(screenHeight, isMobile, isExtraSmall),
    );
  }

  PreferredSizeWidget _buildResponsiveAppBar(bool isMobile, bool isExtraSmall, bool isSmall) {
    return AppBar(
      title: _buildResponsiveTitle(isExtraSmall, isSmall),
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      centerTitle: true,
      automaticallyImplyLeading: false,
      bottom: isMobile ? _buildMobileTabBar(isExtraSmall) : _buildDesktopTabBar(),
      actions: _buildResponsiveActions(isExtraSmall),
    );
  }

  Widget _buildResponsiveTitle(bool isExtraSmall, bool isSmall) {
    if (isExtraSmall) {
      return const Text('Admin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
    } else if (isSmall) {
      return const Text('Superadmin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
    } else {
      return const Text('Superadmin Dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
    }
  }

  PreferredSizeWidget _buildMobileTabBar(bool isExtraSmall) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: Container(
        height: 48,
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          labelPadding: EdgeInsets.symmetric(horizontal: isExtraSmall ? 4 : 8),
          labelStyle: TextStyle(
            fontSize: isExtraSmall ? 10 : 12, 
            fontWeight: FontWeight.w500
          ),
          unselectedLabelStyle: TextStyle(fontSize: isExtraSmall ? 10 : 12),
          tabs: [
            Tab(
              icon: Icon(Icons.dashboard, size: isExtraSmall ? 16 : 18), 
              text: isExtraSmall ? 'Overview' : 'Overview'
            ),
            Tab(
              icon: Icon(Icons.business, size: isExtraSmall ? 16 : 18), 
              text: isExtraSmall ? 'Businesses' : 'Businesses'
            ),
            Tab(
              icon: Icon(Icons.people, size: isExtraSmall ? 16 : 18), 
              text: isExtraSmall ? 'Users' : 'Users'
            ),
            Tab(
              icon: Icon(Icons.analytics, size: isExtraSmall ? 16 : 18), 
              text: isExtraSmall ? 'Analytics' : 'Analytics'
            ),
            Tab(
              icon: Icon(Icons.settings, size: isExtraSmall ? 16 : 18), 
              text: isExtraSmall ? 'Settings' : 'Settings'
            ),
            Tab(
              icon: Icon(Icons.storage, size: isExtraSmall ? 16 : 18), 
              text: isExtraSmall ? 'Data' : 'Data'
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildDesktopTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: Colors.white,
      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      unselectedLabelStyle: const TextStyle(fontSize: 14),
      tabs: const [
        Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
        Tab(icon: Icon(Icons.business), text: 'Businesses'),
        Tab(icon: Icon(Icons.people), text: 'Users & Security'),
        Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
        Tab(icon: Icon(Icons.settings), text: 'Settings'),
        Tab(icon: Icon(Icons.storage), text: 'Data Management'),
      ],
    );
  }

  List<Widget> _buildResponsiveActions(bool isExtraSmall) {
    return [
      // Refresh button - show on all screens except extra small
      if (!isExtraSmall) 
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadDashboardData,
          tooltip: 'Refresh',
        ),
      // Logout button - ALWAYS visible on ALL screen sizes
      PopupMenuButton<String>(
        icon: const Icon(Icons.account_circle),
        tooltip: 'Account',
        onSelected: (value) {
          if (value == 'logout') {
            _showLogoutDialog();
          } else if (value == 'profile') {
            _showProfileDialog();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'profile',
            child: Row(
              children: [
                Icon(Icons.person),
                SizedBox(width: 8),
                Text('Profile'),
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
    ];
  }

  Widget _buildResponsiveBody(double screenHeight, bool isMobile, bool isExtraSmall) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: Container(
        height: screenHeight - (isMobile ? (isExtraSmall ? 120 : 140) : 160),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewContent(isMobile, isExtraSmall),
            _buildBusinessesContent(isMobile, isExtraSmall),
            _buildUsersContent(isMobile, isExtraSmall),
            _buildAnalyticsContent(isMobile, isExtraSmall),
            _buildSettingsContent(isMobile, isExtraSmall),
            _buildDataContent(isMobile, isExtraSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewContent(bool isMobile, bool isExtraSmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isExtraSmall ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Overview',
            style: TextStyle(
              fontSize: isExtraSmall ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(height: isExtraSmall ? 8 : 12),
          _buildInfoCard('Total Businesses', '25', Icons.business, Colors.blue),
          SizedBox(height: isExtraSmall ? 8 : 12),
          _buildInfoCard('Active Users', '150', Icons.people, Colors.green),
          SizedBox(height: isExtraSmall ? 8 : 12),
          _buildInfoCard('System Status', 'Online', Icons.check_circle, Colors.green),
        ],
      ),
    );
  }

  Widget _buildBusinessesContent(bool isMobile, bool isExtraSmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isExtraSmall ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Businesses',
            style: TextStyle(
              fontSize: isExtraSmall ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(height: isExtraSmall ? 8 : 12),
          _buildInfoCard('Active Businesses', '20', Icons.business, Colors.blue),
          SizedBox(height: isExtraSmall ? 8 : 12),
          _buildInfoCard('Pending Approvals', '3', Icons.pending, Colors.orange),
          SizedBox(height: isExtraSmall ? 8 : 12),
          _buildInfoCard('Suspended', '2', Icons.block, Colors.red),
        ],
      ),
    );
  }

  Widget _buildUsersContent(bool isMobile, bool isExtraSmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isExtraSmall ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Users & Security',
            style: TextStyle(
              fontSize: isExtraSmall ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(height: isExtraSmall ? 8 : 12),
          _buildInfoCard('Total Users', '150', Icons.people, Colors.blue),
          SizedBox(height: isExtraSmall ? 8 : 12),
          _buildInfoCard('Admins', '5', Icons.admin_panel_settings, Colors.purple),
          SizedBox(height: isExtraSmall ? 8 : 12),
          _buildInfoCard('Security Alerts', '0', Icons.security, Colors.green),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent(bool isMobile, bool isExtraSmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isExtraSmall ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analytics',
            style: TextStyle(
              fontSize: isExtraSmall ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(height: isExtraSmall ? 8 : 12),
          _buildInfoCard('Total Revenue', '\$50,000', Icons.attach_money, Colors.green),
          SizedBox(height: isExtraSmall ? 8 : 12),
          _buildInfoCard('Active Sessions', '45', Icons.trending_up, Colors.blue),
          SizedBox(height: isExtraSmall ? 8 : 12),
          _buildInfoCard('System Load', '65%', Icons.speed, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildSettingsContent(bool isMobile, bool isExtraSmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isExtraSmall ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: isExtraSmall ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(height: isExtraSmall ? 8 : 12),
          _buildInfoCard('System Settings', 'Configured', Icons.settings, Colors.blue),
          SizedBox(height: isExtraSmall ? 8 : 12),
          _buildInfoCard('Backup Status', 'Last: 2h ago', Icons.backup, Colors.green),
          SizedBox(height: isExtraSmall ? 8 : 12),
          _buildInfoCard('Updates', 'Available', Icons.system_update, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildDataContent(bool isMobile, bool isExtraSmall) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isExtraSmall ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data Management',
            style: TextStyle(
              fontSize: isExtraSmall ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(height: isExtraSmall ? 8 : 12),
          _buildInfoCard('Database Size', '2.5 GB', Icons.storage, Colors.blue),
          SizedBox(height: isExtraSmall ? 8 : 12),
          _buildInfoCard('Backup Size', '1.8 GB', Icons.backup, Colors.green),
          SizedBox(height: isExtraSmall ? 8 : 12),
          _buildInfoCard('Cleanup Status', 'Scheduled', Icons.cleaning_services, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 