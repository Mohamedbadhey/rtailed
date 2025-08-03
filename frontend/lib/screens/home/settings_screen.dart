import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/providers/settings_provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/connection_test.dart';
import 'package:retail_management/widgets/custom_text_field.dart';
import 'package:retail_management/widgets/branded_header.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/screens/home/offline_settings_screen.dart';
import 'manage_cashiers_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';
  String _selectedCurrency = 'USD';
  bool _isLoading = false;
  Map<String, dynamic> _systemInfo = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSystemInfo();
  }

  Future<void> _loadUserData() async {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _usernameController.text = user.username;
      _emailController.text = user.email;
      _selectedLanguage = user.language;
    }
  }

  Future<void> _loadSystemInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final connectionStatus = await ConnectionTest.getConnectionStatus();
      final products = await _apiService.getProducts();
      final customers = await _apiService.getCustomers();
      final sales = await _apiService.getSales();

      setState(() {
        _systemInfo = {
          'connectionStatus': connectionStatus,
          'totalProducts': products.length,
          'totalCustomers': customers.length,
          'totalSales': sales.length,
          'databaseSize': '${products.length + customers.length + sales.length} records',
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branded Header
          Consumer<BrandingProvider>(
            builder: (context, brandingProvider, child) {
              return BrandedHeader(
                subtitle: 'Manage your account and preferences',
                logoSize: 60,
              );
            },
          ),
          const SizedBox(height: 24),
          _buildProfileSection(),
          const SizedBox(height: 24),
          _buildPreferencesSection(),
          const SizedBox(height: 24),
          _buildSystemSection(),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    final user = context.read<AuthProvider>().user;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  t(context, 'Profile Settings'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (user != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getRoleColor(user.role).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.role.toUpperCase(),
                      style: TextStyle(
                        color: _getRoleColor(user.role),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  CustomTextField(
                    controller: _usernameController,
                    labelText: t(context, 'Username'),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _emailController,
                    labelText: t(context, 'Email'),
                    prefixIcon: const Icon(Icons.email),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    t(context, 'Change Password'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _currentPasswordController,
                    labelText: t(context, 'Current Password'),
                    prefixIcon: const Icon(Icons.lock),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _newPasswordController,
                    labelText: t(context, 'New Password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _confirmPasswordController,
                    labelText: t(context, 'Confirm Password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _updateProfile();
                        }
                      },
                      child: Text(t(context, 'Update Profile')),
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

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.orange;
      case 'cashier':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPreferencesSection() {
    final settings = Provider.of<SettingsProvider>(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(context, 'Preferences'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(t(context, 'Dark Mode')),
              subtitle: Text(t(context, 'Enable dark theme')),
              value: settings.themeMode == ThemeMode.dark,
              onChanged: (value) {
                settings.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
              },
            ),
            SwitchListTile(
              title: Text(t(context, 'Notifications')),
              subtitle: Text(t(context, 'Enable push notifications')),
              value: settings.notificationsEnabled,
              onChanged: (value) {
                settings.setNotificationsEnabled(value);
              },
            ),
            ListTile(
              title: Text(t(context, 'Language')),
              subtitle: Text(settings.language),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                _showLanguageDialog(settings);
              },
            ),
            ListTile(
              title: Text(t(context, 'Currency')),
              subtitle: Text(settings.currency),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                _showCurrencyDialog(settings);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemSection() {
    final user = context.read<AuthProvider>().user;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(context, 'System Information'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  _buildSystemInfoTile(
                    t(context, 'Backend Status'),
                    _systemInfo['connectionStatus']?['overall'] == true ? 'Connected' : 'Disconnected',
                    Icons.cloud,
                    _systemInfo['connectionStatus']?['overall'] == true ? Colors.green : Colors.red,
                  ),
                  _buildSystemInfoTile(
                    t(context, 'Database Status'),
                    _systemInfo['connectionStatus']?['database']?['success'] == true ? 'Connected' : 'Disconnected',
                    Icons.storage,
                    _systemInfo['connectionStatus']?['database']?['success'] == true ? Colors.green : Colors.red,
                  ),
                  _buildSystemInfoTile(
                    t(context, 'Total Products'),
                    '${_systemInfo['totalProducts'] ?? 0}',
                    Icons.inventory,
                    Colors.blue,
                  ),
                  _buildSystemInfoTile(
                    t(context, 'Total Customers'),
                    '${_systemInfo['totalCustomers'] ?? 0}',
                    Icons.people,
                    Colors.orange,
                  ),
                  _buildSystemInfoTile(
                    t(context, 'Total Sales'),
                    '${_systemInfo['totalSales'] ?? 0}',
                    Icons.point_of_sale,
                    Colors.green,
                  ),
                  _buildSystemInfoTile(
                    t(context, 'Database Size'),
                    _systemInfo['databaseSize'] ?? 'Unknown',
                    Icons.data_usage,
                    Colors.purple,
                  ),
                  const SizedBox(height: 16),
                  if (user != null && (user.role == 'admin' || user.role == 'superadmin' || user.role == 'manager')) ...[
                    ListTile(
                      leading: Icon(Icons.people, color: Colors.indigo),
                      title: Text(t(context, 'Manage Cashiers')),
                      subtitle: Text(t(context, 'Create and manage cashier accounts for your business')),
                      trailing: Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ManageCashiersScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  ListTile(
                    leading: Icon(Icons.offline_bolt, color: Colors.orange),
                    title: Text('Offline Settings'),
                    subtitle: Text('Manage offline functionality and sync settings'),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OfflineSettingsScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    t(context, 'Connection Details'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_systemInfo['connectionStatus'] != null) ...[
                    Text('${t(context, 'Backend: ')}${_systemInfo['connectionStatus']['backend']?['message'] ?? t(context, 'Unknown')}'),
                    Text('${t(context, 'Database: ')}${_systemInfo['connectionStatus']['database']?['message'] ?? t(context, 'Unknown')}'),
                    Text('${t(context, 'Last Check: ')}${_systemInfo['connectionStatus']['timestamp'] ?? t(context, 'Unknown')}'),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemInfoTile(String title, String value, IconData icon, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(value),
      trailing: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  void _showLanguageDialog([SettingsProvider? settings]) {
    final currentUser = context.read<AuthProvider>().user;
    final currentLanguage = currentUser?.language ?? 'English';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'Select Language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['English', 'Somali'].map((language) {
            return ListTile(
              title: Text(language),
              trailing: currentLanguage == language ? const Icon(Icons.check) : null,
              onTap: () {
                settings?.setLanguage(language);
                setState(() {
                  _selectedLanguage = language;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showCurrencyDialog([SettingsProvider? settings]) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'Select Currency')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['USD', 'EUR', 'GBP', 'JPY'].map((currency) {
            return ListTile(
              title: Text(currency),
              trailing: (settings?.currency ?? _selectedCurrency) == currency ? const Icon(Icons.check) : null,
              onTap: () {
                if (settings != null) settings.setCurrency(currency);
                setState(() { _selectedCurrency = currency; });
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _updateProfile() async {
    setState(() { _isLoading = true; });
    final auth = context.read<AuthProvider>();
    try {
      final updatedUser = await _apiService.updateProfile(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        currentPassword: _currentPasswordController.text.isNotEmpty ? _currentPasswordController.text : null,
        newPassword: _newPasswordController.text.isNotEmpty ? _newPasswordController.text : null,
      );
      auth.setUser(updatedUser);
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'Profile updated successfully!'))),
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } catch (e) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'Failed to update profile: $e'))),
      );
    }
  }
} 