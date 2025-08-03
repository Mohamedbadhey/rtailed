import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/translate.dart';
import 'package:provider/provider.dart';

class ManageCashiersScreen extends StatefulWidget {
  const ManageCashiersScreen({Key? key}) : super(key: key);

  @override
  State<ManageCashiersScreen> createState() => _ManageCashiersScreenState();
}

class _ManageCashiersScreenState extends State<ManageCashiersScreen> {
  List<dynamic> cashiers = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchCashiers();
  }

  Future<void> fetchCashiers() async {
    setState(() { loading = true; error = null; });
    try {
      final user = context.read<AuthProvider>().user;
      String endpoint = '/api/admin/users?limit=100';
      
      // Debug information
      print('Fetching cashiers for user: ${user?.username}');
      print('User role: ${user?.role}');
      print('User businessId: ${user?.businessId}');
      
      // If user is not superadmin, filter by business_id
      if (user?.role != 'superadmin' && user?.businessId != null) {
        endpoint = '/api/businesses/${user!.businessId}/users?limit=100';
        print('Using business-specific endpoint: $endpoint');
      } else {
        print('Using admin endpoint: $endpoint');
      }
      
      final response = await ApiService.getStatic(endpoint);
      setState(() {
        cashiers = (response['users'] as List).where((u) =>
          u['role'] == 'cashier' &&
          (u['is_deleted'] == false || u['is_deleted'] == 0 || u['is_deleted'] == null)
        ).toList();
        loading = false;
      });
    } catch (e) {
      print('Error fetching cashiers: $e');
      setState(() { error = 'Failed to load cashiers: $e'; loading = false; });
    }
  }

  void showAddEditDialog({Map<String, dynamic>? cashier}) {
    final _formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController(text: cashier?['username'] ?? '');
    final emailController = TextEditingController(text: cashier?['email'] ?? '');
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isEdit = cashier != null;
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEdit ? t(context, 'Edit Cashier') : t(context, 'Add Cashier')),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Form(
          key: _formKey,
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
                  if (!isEdit) ...[
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
            ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: isCreating ? null : () => Navigator.pop(context), 
            child: Text(t(context, 'Cancel'))
          ),
          ElevatedButton(
            onPressed: isCreating ? null : () async {
              // Validation
              if (usernameController.text.isEmpty || emailController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t(context, 'Username and email are required')),
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

              if (!isEdit) {
                if (passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t(context, 'Password is required')),
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
              }

              setState(() {
                isCreating = true;
              });

              try {
                final user = context.read<AuthProvider>().user;
                String endpoint;
                Map<String, dynamic> data = {
                  'username': usernameController.text,
                  'email': emailController.text,
                  'role': 'cashier',
                };
                
                if (isEdit) {
                  endpoint = '/api/admin/users/${cashier!['id']}';
                  data['is_active'] = true;
                } else {
                  data['password'] = passwordController.text;
                  if (user?.role == 'superadmin') {
                    endpoint = '/api/admin/users';
                  } else {
                    endpoint = '/api/businesses/${user!.businessId}/users';
                  }
                }
                
                if (isEdit) {
                  await ApiService.putStatic(endpoint, data);
                } else {
                  await ApiService.postStatic(endpoint, data);
                }
                Navigator.pop(context);
                fetchCashiers();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEdit ? t(context, 'Cashier updated successfully') : t(context, 'Cashier created successfully')),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                String errorMessage = 'Failed to save cashier';
                if (e.toString().contains('Username already exists')) {
                  errorMessage = t(context, 'Username already exists');
                } else if (e.toString().contains('Email already exists')) {
                  errorMessage = t(context, 'Email already exists');
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$errorMessage: $e'),
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
              : Text(isEdit ? t(context, 'Save') : t(context, 'Add')),
          ),
        ],
      ),
    ));
  }

  void showResetPasswordDialog(Map<String, dynamic> cashier) {
    final _formKey = GlobalKey<FormState>();
    String password = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${t(context, 'Reset Password for ')}${cashier['username']}'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            decoration: InputDecoration(labelText: 'New Password'),
            obscureText: true,
            validator: (v) => v == null || v.length < 6 ? 'Min 6 chars' : null,
            onChanged: (v) => password = v,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t(context, 'Cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              try {
                await ApiService.postStatic('/api/admin/users/${cashier['id']}/reset-password', {
                  'newPassword': password,
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(context, 'Password reset'))));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t(context, 'Failed to reset password: ')}$e')));
              }
            },
            child: Text(t(context, 'Reset')),
          ),
        ],
      ),
    );
  }

  void deactivateCashier(Map<String, dynamic> cashier) async {
    try {
      await ApiService.putStatic('/api/admin/users/${cashier['id']}/status', {'is_active': false});
      fetchCashiers();
    } catch (e) {
      print('Deactivate cashier error: ' + e.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t(context, 'Failed to deactivate cashier: ')}$e')));
    }
  }

  void activateCashier(Map<String, dynamic> cashier) async {
    try {
      await ApiService.putStatic('/api/admin/users/${cashier['id']}/status', {'is_active': true});
      fetchCashiers();
    } catch (e) {
      print('Activate cashier error: ' + e.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t(context, 'Failed to activate cashier: ')}$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final canManageCashiers = user?.role == 'superadmin' || user?.role == 'admin' || user?.role == 'manager';
    
    // Debug information
    print('Current user: ${user?.username}');
    print('User role: ${user?.role}');
    print('User businessId: ${user?.businessId}');
    print('Can manage cashiers: $canManageCashiers');
    
    if (!canManageCashiers) {
      return Scaffold(
        appBar: AppBar(title: Text(t(context, 'Manage Cashiers'))),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(t(context, 'You do not have permission to manage cashiers')),
              SizedBox(height: 16),
              Text('${t(context, 'Current role: ')}${user?.role ?? t(context, 'Unknown')}'),
              Text('${t(context, 'Business ID: ')}${user?.businessId ?? 'None'}'),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(title: Text(t(context, 'Manage Cashiers'))),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : RefreshIndicator(
                  onRefresh: fetchCashiers,
                  child: cashiers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(t(context, 'No cashiers found')),
                              SizedBox(height: 8),
                              Text(t(context, 'Add your first cashier to get started')),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: cashiers.length,
                          itemBuilder: (context, i) {
                            final cashier = cashiers[i];
                            return ListTile(
                              title: Text(cashier['username'] ?? ''),
                              subtitle: Text(cashier['email'] ?? ''),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') showAddEditDialog(cashier: cashier);
                                  if (value == 'deactivate') deactivateCashier(cashier);
                                  if (value == 'activate') activateCashier(cashier);
                                  if (value == 'reset') showResetPasswordDialog(cashier);
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(value: 'edit', child: Text(t(context, 'Edit'))),
                                  PopupMenuItem(value: 'reset', child: Text(t(context, 'Reset Password'))),
                                  if (cashier['is_active'] == true || cashier['is_active'] == 1)
                                    PopupMenuItem(value: 'deactivate', child: Text(t(context, 'Deactivate')))
                                  else
                                    PopupMenuItem(value: 'activate', child: Text(t(context, 'Activate'))),
                                ],
                              ),
                            );
                          },
                        ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddEditDialog(),
        child: Icon(Icons.add),
        tooltip: 'Add Cashier',
      ),
    );
  }
} 