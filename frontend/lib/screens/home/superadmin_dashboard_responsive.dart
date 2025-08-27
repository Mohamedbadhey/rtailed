import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/widgets/branded_app_bar.dart';

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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage Businesses',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Create, edit, and manage business accounts.'),
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