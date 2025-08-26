import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/notification_provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/models/notification.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/utils/theme.dart';
import 'package:retail_management/utils/success_utils.dart';
import 'package:retail_management/widgets/branded_app_bar.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _replyController = TextEditingController();
  String _selectedType = 'info';
  String _selectedPriority = 'medium';
  String _filterType = '';
  String _filterPriority = '';
  String _filterSenderRole = '';
  String _filterDateFrom = '';
  String _filterDateTo = '';
  List<int> _selectedCashiers = [];
  List<Map<String, dynamic>> _cashiers = [];
  bool _isLoadingCashiers = false;
  bool _showFilters = false;
  AppNotification? _selectedNotification;
  List<AppNotification> _threadNotifications = [];
  bool _isLoadingThread = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = authProvider.user?.role == 'admin' || authProvider.user?.role == 'superadmin';
    final isCashier = authProvider.user?.role == 'cashier';
    _tabController = TabController(length: isAdmin || isCashier ? 2 : 1, vsync: this);
    if (isAdmin) {
      _loadCashiers();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchMyNotifications();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadCashiers() async {
    setState(() {
      _isLoadingCashiers = true;
    });

    try {
      final notificationProvider = context.read<NotificationProvider>();
      _cashiers = await notificationProvider.getCashiers();
    } catch (e) {
      SuccessUtils.showOperationError(context, 'load cashiers', e.toString());
    } finally {
      setState(() {
        _isLoadingCashiers = false;
      });
    }
  }

  Future<void> _searchNotifications() async {
    final notificationProvider = context.read<NotificationProvider>();
    await notificationProvider.fetchMyNotifications(
      search: _searchController.text,
      type: _filterType,
      priority: _filterPriority,
      senderRole: _filterSenderRole,
      dateFrom: _filterDateFrom,
      dateTo: _filterDateTo,
    );
  }

  Future<void> _loadThread(int notificationId) async {
    setState(() {
      _isLoadingThread = true;
    });

    try {
      final notificationProvider = context.read<NotificationProvider>();
      _threadNotifications = await notificationProvider.getThread(notificationId);
    } catch (e) {
      SuccessUtils.showOperationError(context, 'load thread', e.toString());
    } finally {
      setState(() {
        _isLoadingThread = false;
      });
    }
  }

  Future<void> _sendReply(int parentId) async {
    if (_replyController.text.trim().isEmpty) return;

    try {
      final notificationProvider = context.read<NotificationProvider>();
      await notificationProvider.sendNotification(
        title: '', // Empty title for replies - backend will auto-generate "Re: [original title]"
        message: _replyController.text.trim(),
        type: 'info',
        priority: 'medium',
        parentId: parentId, // Make sure parentId is passed correctly
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(context, 'Reply sent successfully')),
          backgroundColor: Colors.green,
        ),
      );

      _replyController.clear();
      await _loadThread(parentId);
    } catch (e) {
      SuccessUtils.showOperationError(context, 'send reply', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final notificationProvider = context.watch<NotificationProvider>();
    final isAdmin = authProvider.user?.role == 'admin' || authProvider.user?.role == 'superadmin';
    final isCashier = authProvider.user?.role == 'cashier';

    return Scaffold(
      appBar: BrandedAppBar(
        title: t(context, 'Notifications'),
        actions: [
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_list : Icons.filter_list_outlined,
            ),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: [
            Tab(
              icon: Icon(Icons.notifications),
              text: t(context, 'My Notifications'),
            ),
            if (isAdmin)
              Tab(
                icon: Icon(Icons.send),
                text: t(context, 'Send Message'),
              ),
            if (isCashier)
              Tab(
                icon: Icon(Icons.send),
                text: t(context, 'Send to Admin'),
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyNotificationsTab(notificationProvider),
          if (isAdmin) _buildSendMessageTab(notificationProvider),
          if (isCashier) _buildSendToAdminTab(notificationProvider),
        ],
      ),
    );
  }

  Widget _buildMyNotificationsTab(NotificationProvider notificationProvider) {
    if (_selectedNotification != null) {
      return _buildThreadView(notificationProvider);
    }

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: t(context, 'Search notifications...'),
              prefixIcon: Icon(Icons.search),
              suffixIcon: IconButton(
                icon: Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _searchNotifications();
                },
              ),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _searchNotifications(),
          ),
        ),
        // Filters
        if (_showFilters) _buildFilterSection(),
        // Notifications List
        Expanded(
          child: _buildNotificationsList(notificationProvider),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(context, 'Filters'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterType.isEmpty ? null : _filterType,
                    decoration: InputDecoration(
                      labelText: t(context, 'Type'),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text(t(context, 'All'))),
                      DropdownMenuItem(value: 'info', child: Text(t(context, 'Info'))),
                      DropdownMenuItem(value: 'warning', child: Text(t(context, 'Warning'))),
                      DropdownMenuItem(value: 'error', child: Text(t(context, 'Error'))),
                      DropdownMenuItem(value: 'success', child: Text(t(context, 'Success'))),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterType = value ?? '';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterPriority.isEmpty ? null : _filterPriority,
                    decoration: InputDecoration(
                      labelText: t(context, 'Priority'),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text(t(context, 'All'))),
                      DropdownMenuItem(value: 'low', child: Text(t(context, 'Low'))),
                      DropdownMenuItem(value: 'medium', child: Text(t(context, 'Medium'))),
                      DropdownMenuItem(value: 'high', child: Text(t(context, 'High'))),
                      DropdownMenuItem(value: 'urgent', child: Text(t(context, 'Urgent'))),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterPriority = value ?? '';
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterSenderRole.isEmpty ? null : _filterSenderRole,
                    decoration: InputDecoration(
                      labelText: t(context, 'Sender Role'),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text(t(context, 'All'))),
                      DropdownMenuItem(value: 'admin', child: Text(t(context, 'Admin'))),
                      DropdownMenuItem(value: 'superadmin', child: Text(t(context, 'Superadmin'))),
                      DropdownMenuItem(value: 'cashier', child: Text(t(context, 'Cashier'))),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterSenderRole = value ?? '';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _searchNotifications,
                    child: Text(t(context, 'Apply Filters')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList(NotificationProvider notificationProvider) {
    if (notificationProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notificationProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${t(context, 'Error: ')}${notificationProvider.error}'),
            ElevatedButton(
              onPressed: () => notificationProvider.fetchMyNotifications(),
              child: Text(t(context, 'Retry')),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => notificationProvider.fetchMyNotifications(),
      child: Column(
        children: [
          if (notificationProvider.unreadCount > 0)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    '${notificationProvider.unreadCount} ${t(context, 'unread notifications')}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => notificationProvider.markAllAsRead(),
                    child: Text(t(context, 'Mark all as read')),
                  ),
                ],
              ),
            ),
          Expanded(
            child: notificationProvider.notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t(context, 'No notifications'),
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: notificationProvider.notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notificationProvider.notifications[index];
                      return _buildNotificationTile(notification, notificationProvider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadView(NotificationProvider notificationProvider) {
    return Column(
      children: [
        // Thread Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedNotification = null;
                    _threadNotifications.clear();
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedNotification?.title ?? '',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Thread with ${_selectedNotification?.createdByName ?? 'Unknown'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Thread Messages
        Expanded(
          child: _isLoadingThread
              ? Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _threadNotifications.length,
                  itemBuilder: (context, index) {
                    final notification = _threadNotifications[index];
                    return _buildThreadMessage(notification, notificationProvider);
                  },
                ),
        ),
        // Reply Input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  decoration: InputDecoration(
                    hintText: t(context, 'Type your reply...'),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.send),
                onPressed: () => _sendReply(_selectedNotification!.id),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThreadMessage(AppNotification notification, NotificationProvider provider) {
    final isSent = notification.direction == 'sent';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isSent) ...[
            CircleAvatar(
              backgroundColor: _getTypeColor(notification.type).withOpacity(0.2),
              child: Icon(
                _getTypeIcon(notification.type),
                color: _getTypeColor(notification.type),
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSent ? Colors.blue.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${notification.createdByName} • ${_formatDate(notification.createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          if (isSent) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blue.shade200,
              child: Icon(
                Icons.person,
                color: Colors.blue,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationTile(AppNotification notification, NotificationProvider provider) {
    final isSent = notification.direction == 'sent';
    final senderRole = notification.createdByRole ?? '';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(notification.type).withOpacity(0.2),
          child: Icon(
            _getTypeIcon(notification.type),
            color: _getTypeColor(notification.type),
          ),
        ),
        title: Text(
          notification.title + (isSent ? ' (You)' : ''),
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(
                    notification.type.toUpperCase(),
                    style: TextStyle(fontSize: 10),
                  ),
                  backgroundColor: _getTypeColor(notification.type).withOpacity(0.2),
                  labelStyle: TextStyle(color: _getTypeColor(notification.type)),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    notification.priority.toUpperCase(),
                    style: TextStyle(fontSize: 10),
                  ),
                  backgroundColor: _getPriorityColor(notification.priority).withOpacity(0.2),
                  labelStyle: TextStyle(color: _getPriorityColor(notification.priority)),
                ),
                const SizedBox(width: 8),
                if (!isSent)
                  Chip(
                    label: Text(senderRole.isNotEmpty ? senderRole : 'Sender'),
                    backgroundColor: Colors.grey.shade200,
                    labelStyle: TextStyle(color: Colors.black54, fontSize: 10),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              (isSent ? 'To: ' : 'From: ') + (notification.createdByName ?? 'Unknown') + ' • ' + _formatDate(notification.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!notification.isRead)
              IconButton(
                icon: Icon(Icons.check_circle_outline),
                onPressed: () => provider.markAsRead(notification.id),
                tooltip: t(context, 'Mark as read'),
              ),
            IconButton(
              icon: Icon(Icons.reply),
              onPressed: () {
                setState(() {
                  _selectedNotification = notification;
                });
                _loadThread(notification.id);
              },
              tooltip: t(context, 'Reply'),
            ),
          ],
        ),
        onTap: () {
          if (!notification.isRead) {
            provider.markAsRead(notification.id);
          }
        },
      ),
    );
  }

  Widget _buildSendMessageTab(NotificationProvider notificationProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(context, 'Send Message to Cashiers'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: t(context, 'Title'),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return t(context, 'Title is required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        labelText: t(context, 'Message'),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return t(context, 'Message is required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedType,
                            decoration: InputDecoration(
                              labelText: t(context, 'Type'),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(value: 'info', child: Text(t(context, 'Info'))),
                              DropdownMenuItem(value: 'warning', child: Text(t(context, 'Warning'))),
                              DropdownMenuItem(value: 'error', child: Text(t(context, 'Error'))),
                              DropdownMenuItem(value: 'success', child: Text(t(context, 'Success'))),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedType = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedPriority,
                            decoration: InputDecoration(
                              labelText: t(context, 'Priority'),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(value: 'low', child: Text(t(context, 'Low'))),
                              DropdownMenuItem(value: 'medium', child: Text(t(context, 'Medium'))),
                              DropdownMenuItem(value: 'high', child: Text(t(context, 'High'))),
                              DropdownMenuItem(value: 'urgent', child: Text(t(context, 'Urgent'))),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedPriority = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(context, 'Select Cashiers'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingCashiers)
                      Center(child: CircularProgressIndicator())
                    else if (_cashiers.isEmpty)
                      Center(
                        child: Text(
                          t(context, 'No cashiers found'),
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      Column(
                        children: [
                          CheckboxListTile(
                            title: Text(t(context, 'Send to all cashiers')),
                            value: _selectedCashiers.isEmpty,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedCashiers.clear();
                                } else {
                                  _selectedCashiers = _cashiers.map((c) => c['id'] as int).toList();
                                }
                              });
                            },
                          ),
                          const Divider(),
                          ...(_cashiers.map((cashier) {
                            return CheckboxListTile(
                              title: Text(cashier['username'] ?? ''),
                              subtitle: Text(cashier['email'] ?? ''),
                              value: _selectedCashiers.isEmpty || _selectedCashiers.contains(cashier['id']),
                              onChanged: (value) {
                                setState(() {
                                  if (_selectedCashiers.isEmpty) {
                                    // If "all" was selected, now select specific ones
                                    _selectedCashiers = _cashiers
                                        .where((c) => c['id'] != cashier['id'])
                                        .map((c) => c['id'] as int)
                                        .toList();
                                  } else {
                                    if (value == true) {
                                      _selectedCashiers.add(cashier['id']);
                                    } else {
                                      _selectedCashiers.remove(cashier['id']);
                                    }
                                  }
                                });
                              },
                            );
                          })),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _sendNotification,
              icon: Icon(Icons.send),
              label: Text(t(context, 'Send Notification')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final notificationProvider = context.read<NotificationProvider>();
      
      await notificationProvider.sendNotification(
        title: _titleController.text,
        message: _messageController.text,
        type: _selectedType,
        priority: _selectedPriority,
        targetCashiers: _selectedCashiers.isEmpty ? null : _selectedCashiers,
      );

      SuccessUtils.showNotificationSuccess(context, 'sent');

      // Clear form
      _titleController.clear();
      _messageController.clear();
      setState(() {
        _selectedCashiers.clear();
      });

      // Switch to notifications tab
      _tabController.animateTo(0);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSendToAdminTab(NotificationProvider notificationProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(context, 'Send Message to Admin'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: t(context, 'Title'),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return t(context, 'Title is required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        labelText: t(context, 'Message'),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return t(context, 'Message is required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedType,
                            decoration: InputDecoration(
                              labelText: t(context, 'Type'),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(value: 'info', child: Text(t(context, 'Info'))),
                              DropdownMenuItem(value: 'warning', child: Text(t(context, 'Warning'))),
                              DropdownMenuItem(value: 'error', child: Text(t(context, 'Error'))),
                              DropdownMenuItem(value: 'success', child: Text(t(context, 'Success'))),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedType = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedPriority,
                            decoration: InputDecoration(
                              labelText: t(context, 'Priority'),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(value: 'low', child: Text(t(context, 'Low'))),
                              DropdownMenuItem(value: 'medium', child: Text(t(context, 'Medium'))),
                              DropdownMenuItem(value: 'high', child: Text(t(context, 'High'))),
                              DropdownMenuItem(value: 'urgent', child: Text(t(context, 'Urgent'))),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedPriority = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _sendNotificationToAdmin,
              icon: Icon(Icons.send),
              label: Text(t(context, 'Send Notification')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendNotificationToAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final notificationProvider = context.read<NotificationProvider>();
      await notificationProvider.sendNotification(
        title: _titleController.text,
        message: _messageController.text,
        type: _selectedType,
        priority: _selectedPriority,
      );

      SuccessUtils.showNotificationSuccess(context, 'sent');

      // Clear form
      _titleController.clear();
      _messageController.clear();

      // Switch to notifications tab
      _tabController.animateTo(0);
    } catch (e) {
      SuccessUtils.showNotificationError(context, e.toString());
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'info':
        return Colors.blue;
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      case 'success':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'info':
        return Icons.info;
      case 'warning':
        return Icons.warning;
      case 'error':
        return Icons.error;
      case 'success':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      case 'urgent':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
} 