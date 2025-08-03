import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:retail_management/utils/type_converter.dart';

class BusinessPaymentStatusWidget extends StatefulWidget {
  final String token;
  
  const BusinessPaymentStatusWidget({
    super.key,
    required this.token,
  });

  @override
  State<BusinessPaymentStatusWidget> createState() => _BusinessPaymentStatusWidgetState();
}

class _BusinessPaymentStatusWidgetState extends State<BusinessPaymentStatusWidget> {
  bool _isLoading = true;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _businesses = [];
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadPaymentStatus();
  }

  Future<void> _loadPaymentStatus() async {
    try {
      setState(() => _isLoading = true);

      // Load payment summary
      final summaryResponse = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/business-payments/summary'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (summaryResponse.statusCode == 200) {
        final summaryData = json.decode(summaryResponse.body);
        setState(() {
          _summary = TypeConverter.convertMySQLTypes(summaryData);
        });
      }

      // Load businesses with payment status
      final businessesResponse = await http.get(
        Uri.parse('https://rtailed-production.up.railway.app/api/business-payments/all-status?limit=10'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (businessesResponse.statusCode == 200) {
        final businessesData = json.decode(businessesResponse.body);
        setState(() {
          _businesses = TypeConverter.convertMySQLList(businessesData['businesses'] ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading payment status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _suspendBusiness(int businessId, String businessName) async {
    final reason = await _showReasonDialog('Suspend Business', 'Enter suspension reason:');
    if (reason == null || reason.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('https://rtailed-production.up.railway.app/api/business-payments/suspend/$businessId'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'reason': reason}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Business $businessName suspended successfully')),
          );
          _loadPaymentStatus();
        }
      } else {
        throw Exception('Failed to suspend business');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error suspending business: $e')),
        );
      }
    }
  }

  Future<void> _reactivateBusiness(int businessId, String businessName) async {
    final reason = await _showReasonDialog('Reactivate Business', 'Enter reactivation reason:');
    if (reason == null || reason.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('https://rtailed-production.up.railway.app/api/business-payments/reactivate/$businessId'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'reason': reason}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Business $businessName reactivated successfully')),
          );
          _loadPaymentStatus();
        }
      } else {
        throw Exception('Failed to reactivate business');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reactivating business: $e')),
        );
      }
    }
  }

  Future<String?> _showReasonDialog(String title, String message) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: message),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'overdue':
        return Colors.orange;
      case 'suspended':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Business Payment Status',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _loadPaymentStatus,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Active',
                    TypeConverter.safeToString(_summary['activeBusinesses'] ?? 0),
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    'Overdue',
                    TypeConverter.safeToString(_summary['overdueCount'] ?? 0),
                    Colors.orange,
                    Icons.warning,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    'Suspended',
                    TypeConverter.safeToString(_summary['suspendedCount'] ?? 0),
                    Colors.red,
                    Icons.block,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Revenue Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.attach_money, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Monthly Revenue: \$${TypeConverter.safeToString(_summary['totalMonthlyRevenue'] ?? 0)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Businesses List
            Text(
              'Businesses',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            if (_businesses.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No businesses found'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _businesses.length,
                itemBuilder: (context, index) {
                  final business = _businesses[index];
                  final status = TypeConverter.safeToString(business['payment_status'] ?? 'unknown');
                  final isActive = TypeConverter.safeToBool(business['is_active'] ?? true);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(status),
                        child: Icon(
                          status == 'active' ? Icons.check : 
                          status == 'overdue' ? Icons.warning : 
                          status == 'suspended' ? Icons.block : Icons.help,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        TypeConverter.safeToString(business['name'] ?? 'Unknown'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isActive ? null : Colors.grey,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status: $status'),
                          Text('Users: ${TypeConverter.safeToString(business['active_users'] ?? 0)}'),
                          if (business['suspension_reason'] != null)
                            Text(
                              'Reason: ${TypeConverter.safeToString(business['suspension_reason'])}',
                              style: const TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          final businessId = TypeConverter.safeToInt(business['id']);
                          final businessName = TypeConverter.safeToString(business['name']);
                          
                          if (value == 'suspend') {
                            _suspendBusiness(businessId, businessName);
                          } else if (value == 'reactivate') {
                            _reactivateBusiness(businessId, businessName);
                          }
                        },
                        itemBuilder: (context) => [
                          if (status != 'suspended')
                            const PopupMenuItem(
                              value: 'suspend',
                              child: Row(
                                children: [
                                  Icon(Icons.block, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Suspend'),
                                ],
                              ),
                            ),
                          if (status == 'suspended')
                            const PopupMenuItem(
                              value: 'reactivate',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Reactivate'),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
} 