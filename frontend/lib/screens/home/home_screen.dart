import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/providers/notification_provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/screens/auth/login_screen.dart';
import 'package:retail_management/screens/home/dashboard_screen.dart';
import 'package:retail_management/screens/home/inventory_screen.dart';
import 'package:retail_management/screens/home/damaged_products_screen.dart';
import 'package:retail_management/screens/home/pos_screen.dart';
import 'package:retail_management/screens/home/reports_screen.dart';
import 'package:retail_management/screens/home/settings_screen.dart';
import 'package:retail_management/screens/home/admin_settings_screen.dart';
import 'package:retail_management/screens/home/profile_screen.dart';
import 'package:retail_management/screens/home/notifications_screen.dart';
import 'package:retail_management/screens/home/customer_invoice_screen.dart';
import 'package:retail_management/screens/accounting/accounting_dashboard_screen.dart';
import 'package:retail_management/screens/accounting/expenses_screen.dart';
import 'package:retail_management/screens/accounting/vendors_screen.dart';
import 'package:retail_management/screens/accounting/payables_screen.dart';
import 'package:retail_management/screens/accounting/cash_flow_screen.dart';
import 'package:retail_management/utils/theme.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/widgets/notification_badge.dart';
import 'package:retail_management/widgets/branded_app_bar.dart';

import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
    
    // Load notifications for the badge
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notificationProvider = context.read<NotificationProvider>();
      notificationProvider.fetchMyNotifications();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user != null && user.role == 'admin';
    final isCashier = user != null && user.role == 'cashier';

    final List<Widget> screens = isCashier
        ? [
            const DashboardScreen(),
            const POSScreen(),
            const ReportsScreen(),
            const AdminSettingsScreen(), // Settings with Damages included
          ]
        : isAdmin
        ? [
            const DashboardScreen(),
            const POSScreen(),
            const InventoryScreen(),
            const ReportsScreen(),
            const AdminSettingsScreen(), // Settings with Damages and Accounting included
          ]
        : [
            const DashboardScreen(),
            const POSScreen(),
            const InventoryScreen(),
            const DamagedProductsScreen(),
            const ReportsScreen(),
            const SettingsScreen(),
          ];

    final List<BottomNavigationBarItem> navItems = isCashier
        ? [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: t(context, 'Dashboard'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale_outlined),
              activeIcon: Icon(Icons.point_of_sale),
              label: t(context, 'POS'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics),
              label: t(context, 'Reports'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: t(context, 'Settings'),
            ),
          ]
        : isAdmin
        ? [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: t(context, 'Dashboard'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale_outlined),
              activeIcon: Icon(Icons.point_of_sale),
              label: t(context, 'POS'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: t(context, 'Inventory'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics),
              label: t(context, 'Reports'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: t(context, 'Settings'),
            ),
          ]
        : [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: t(context, 'Dashboard'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale_outlined),
              activeIcon: Icon(Icons.point_of_sale),
              label: t(context, 'POS'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: t(context, 'Inventory'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.warning_outlined),
              activeIcon: Icon(Icons.warning),
              label: t(context, 'Damaged'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics),
              label: t(context, 'Reports'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: t(context, 'Settings'),
            ),
          ];

    // Adjust _currentIndex if user is cashier and tries to access a non-existent tab
    int currentIndex = _currentIndex;
    if (isCashier && _currentIndex > 3) {
      currentIndex = 0;
    }
    if (isAdmin && _currentIndex > 4) {
      currentIndex = 0;
    }
    if (!isAdmin && !isCashier && _currentIndex > 5) {
      currentIndex = 0;
    }

    return Scaffold(
      body: Column(
        children: [

          // Main content
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: screens[currentIndex],
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
            currentIndex: currentIndex,
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
          // Notification Bell with Badge
          NotificationBadge(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3), // Increased opacity for better visibility
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: textPrimary),
                    const SizedBox(width: 12),
                    Text(t(context, 'Profile'), style: GoogleFonts.poppins()),
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
          const SizedBox(width: 16),
        ],
        leading: Container(
          margin: const EdgeInsets.only(left: 16),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.storefront,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    final user = context.read<AuthProvider>().user;
    final isCashier = user != null && user.role == 'cashier';
    final isAdmin = user != null && user.role == 'admin';
    
    if (isCashier) {
      switch (_currentIndex) {
        case 0:
          return 'Dashboard';
        case 1:
          return 'Point of Sale';
        case 2:
          return 'Reports & Analytics';
        case 3:
          return 'Settings';
        default:
          return 'Retail Management';
      }
    } else if (isAdmin) {
      switch (_currentIndex) {
        case 0:
          return 'Dashboard';
        case 1:
          return 'Point of Sale';
        case 2:
          return 'Inventory';
        case 3:
          return 'Reports & Analytics';
        case 4:
          return 'Settings';
        default:
          return 'Retail Management';
      }
    } else {
      switch (_currentIndex) {
        case 0:
          return 'Dashboard';
        case 1:
          return 'Point of Sale';
        case 2:
          return 'Inventory';
        case 3:
          return 'Damaged Products';
        case 4:
          return 'Reports & Analytics';
        case 5:
          return 'Settings';
        default:
          return 'Retail Management';
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
        children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.logout, color: errorColor),
            ),
            const SizedBox(width: 12),
            Text(
              'Logout',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
} 