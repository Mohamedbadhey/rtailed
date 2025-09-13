import 'package:flutter/material.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/success_utils.dart';
import 'package:retail_management/utils/translate.dart';

// =====================================================
// BULK ASSIGNMENT DIALOG (SUPERADMIN ONLY)
// =====================================================

class BulkAssignmentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> stores;
  final List<Map<String, dynamic>> businesses;
  final VoidCallback onAssignmentsCreated;

  const BulkAssignmentDialog({
    super.key,
    required this.stores,
    required this.businesses,
    required this.onAssignmentsCreated,
  });

  @override
  State<BulkAssignmentDialog> createState() => _BulkAssignmentDialogState();
}

class _BulkAssignmentDialogState extends State<BulkAssignmentDialog> {
  final ApiService _apiService = ApiService();
  final TextEditingController _notesController = TextEditingController();
  
  List<int> _selectedStores = [];
  List<int> _selectedBusinesses = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.assignment_ind, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  t(context, 'Bulk Store-Business Assignment'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t(context, 'Select multiple stores and businesses to create bulk assignments. Each selected store will be assigned to each selected business.'),
                      style: TextStyle(color: Colors.blue[700], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Content
            Expanded(
              child: Row(
                children: [
                  // Stores Selection
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t(context, 'Select Stores'),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: widget.stores.length,
                            itemBuilder: (context, index) {
                              final store = widget.stores[index];
                              final isSelected = _selectedStores.contains(store['id']);
                              
                              return CheckboxListTile(
                                title: Text(store['name'] ?? ''),
                                subtitle: Text('Code: ${store['store_code'] ?? ''}'),
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedStores.add(store['id']);
                                    } else {
                                      _selectedStores.remove(store['id']);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 20),
                  
                  // Businesses Selection
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t(context, 'Select Businesses'),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: widget.businesses.length,
                            itemBuilder: (context, index) {
                              final business = widget.businesses[index];
                              final isSelected = _selectedBusinesses.contains(business['id']);
                              
                              return CheckboxListTile(
                                title: Text(business['name'] ?? ''),
                                subtitle: Text('Code: ${business['business_code'] ?? ''}'),
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedBusinesses.add(business['id']);
                                    } else {
                                      _selectedBusinesses.remove(business['id']);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Notes
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: t(context, 'Notes (Optional)'),
                border: const OutlineInputBorder(),
                hintText: t(context, 'Add notes for these assignments...'),
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 20),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: Text(t(context, 'Cancel')),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading || _selectedStores.isEmpty || _selectedBusinesses.isEmpty
                      ? null
                      : _createBulkAssignments,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(t(context, 'Create Assignments')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createBulkAssignments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      int successCount = 0;
      int totalAssignments = _selectedStores.length * _selectedBusinesses.length;
      
      for (int storeId in _selectedStores) {
        for (int businessId in _selectedBusinesses) {
          try {
            await _apiService.assignBusinessToStore(storeId, businessId, notes: _notesController.text);
            successCount++;
          } catch (e) {
            print('Failed to assign store $storeId to business $businessId: $e');
          }
        }
      }
      
      Navigator.of(context).pop();
      widget.onAssignmentsCreated();
      
      if (successCount == totalAssignments) {
        SuccessUtils.showBusinessSuccess(context, 'All $successCount assignments created successfully!');
      } else {
        SuccessUtils.showBusinessSuccess(context, '$successCount out of $totalAssignments assignments created successfully.');
      }
    } catch (e) {
      SuccessUtils.showOperationError(context, 'create bulk assignments', e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}


// =====================================================
// ASSIGNMENT HISTORY DIALOG (SUPERADMIN ONLY)
// =====================================================

class AssignmentHistoryDialog extends StatefulWidget {
  const AssignmentHistoryDialog({super.key});

  @override
  State<AssignmentHistoryDialog> createState() => _AssignmentHistoryDialogState();
}

class _AssignmentHistoryDialogState extends State<AssignmentHistoryDialog> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAssignmentHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.history, color: Colors.purple, size: 24),
                const SizedBox(width: 8),
                Text(
                  t(context, 'Assignment History'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                              const SizedBox(height: 16),
                              Text(
                                t(context, 'Error loading assignment history'),
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadAssignmentHistory,
                                child: Text(t(context, 'Retry')),
                              ),
                            ],
                          ),
                        )
                      : _assignments.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    t(context, 'No assignment history found'),
                                    style: Theme.of(context).textTheme.headlineSmall,
                                  ),
                                ],
                              ),
                            )
                          : _buildAssignmentsTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(t(context, 'Store'))),
          DataColumn(label: Text(t(context, 'Business'))),
          DataColumn(label: Text(t(context, 'Status'))),
          DataColumn(label: Text(t(context, 'Assigned By'))),
          DataColumn(label: Text(t(context, 'Assigned At'))),
          DataColumn(label: Text(t(context, 'Removed At'))),
          DataColumn(label: Text(t(context, 'Notes'))),
        ],
        rows: _assignments.map((assignment) {
          final isActive = assignment['is_active'] == 1;
          final assignedAt = assignment['assigned_at'] != null
              ? DateTime.tryParse(assignment['assigned_at'])
              : null;
          final removedAt = assignment['removed_at'] != null
              ? DateTime.tryParse(assignment['removed_at'])
              : null;
          
          return DataRow(
            cells: [
              DataCell(Text('${assignment['store_name']} (${assignment['store_code']})')),
              DataCell(Text('${assignment['business_name']} (${assignment['business_code']})')),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? t(context, 'Active') : t(context, 'Inactive'),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              DataCell(Text(assignment['assigned_by_username'] ?? 'Unknown')),
              DataCell(Text(_formatDateTime(assignedAt))),
              DataCell(Text(_formatDateTime(removedAt))),
              DataCell(Text(assignment['notes'] ?? '')),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadAssignmentHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final assignments = await _apiService.getAllStoreBusinessAssignments();
      setState(() {
        _assignments = assignments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
}

// =====================================================
// ASSIGNMENT DETAILS DIALOG (SUPERADMIN ONLY)
// =====================================================

class AssignmentDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> store;
  final Map<String, dynamic> business;
  final VoidCallback onAssignmentUpdated;

  const AssignmentDetailsDialog({
    super.key,
    required this.store,
    required this.business,
    required this.onAssignmentUpdated,
  });

  @override
  State<AssignmentDetailsDialog> createState() => _AssignmentDetailsDialogState();
}

class _AssignmentDetailsDialogState extends State<AssignmentDetailsDialog> {
  final ApiService _apiService = ApiService();
  final TextEditingController _notesController = TextEditingController();
  
  Map<String, dynamic>? _assignmentDetails;
  bool _isLoading = true;
  bool _isEditing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAssignmentDetails();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  t(context, 'Assignment Details'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_assignmentDetails != null && !_isLoading)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = !_isEditing;
                        if (!_isEditing) {
                          _notesController.text = _assignmentDetails?['notes'] ?? '';
                        }
                      });
                    },
                    icon: Icon(_isEditing ? Icons.close : Icons.edit),
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                              const SizedBox(height: 16),
                              Text(
                                t(context, 'Error loading assignment details'),
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadAssignmentDetails,
                                child: Text(t(context, 'Retry')),
                              ),
                            ],
                          ),
                        )
                      : _buildAssignmentDetails(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentDetails() {
    if (_assignmentDetails == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              t(context, 'No assignment found'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Information
          _buildInfoCard(
            title: t(context, 'Store Information'),
            icon: Icons.store,
            color: Colors.blue,
            children: [
              _buildInfoRow(t(context, 'Name'), widget.store['name'] ?? ''),
              _buildInfoRow(t(context, 'Code'), widget.store['store_code'] ?? ''),
              _buildInfoRow(t(context, 'Address'), widget.store['address'] ?? ''),
              _buildInfoRow(t(context, 'Phone'), widget.store['phone'] ?? ''),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Business Information
          _buildInfoCard(
            title: t(context, 'Business Information'),
            icon: Icons.business,
            color: Colors.green,
            children: [
              _buildInfoRow(t(context, 'Name'), widget.business['name'] ?? ''),
              _buildInfoRow(t(context, 'Code'), widget.business['business_code'] ?? ''),
              _buildInfoRow(t(context, 'Address'), widget.business['address'] ?? ''),
              _buildInfoRow(t(context, 'Phone'), widget.business['phone'] ?? ''),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Assignment Information
          _buildInfoCard(
            title: t(context, 'Assignment Information'),
            icon: Icons.assignment,
            color: Colors.orange,
            children: [
              _buildInfoRow(t(context, 'Status'), _assignmentDetails!['is_active'] == 1 ? t(context, 'Active') : t(context, 'Inactive')),
              _buildInfoRow(t(context, 'Assigned By'), _assignmentDetails!['assigned_by_username'] ?? 'Unknown'),
              _buildInfoRow(t(context, 'Assigned At'), _formatDateTime(DateTime.tryParse(_assignmentDetails!['assigned_at'] ?? ''))),
              if (_assignmentDetails!['removed_at'] != null)
                _buildInfoRow(t(context, 'Removed At'), _formatDateTime(DateTime.tryParse(_assignmentDetails!['removed_at']))),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Notes Section
          _buildInfoCard(
            title: t(context, 'Notes'),
            icon: Icons.note,
            color: Colors.purple,
            children: [
              if (_isEditing) ...[
                TextField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: t(context, 'Add or edit notes...'),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                          _notesController.text = _assignmentDetails?['notes'] ?? '';
                        });
                      },
                      child: Text(t(context, 'Cancel')),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _updateNotes,
                      child: Text(t(context, 'Save')),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  _assignmentDetails!['notes'] ?? t(context, 'No notes available'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadAssignmentDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // For now, we'll create a mock assignment details
      // In a real implementation, you'd fetch this from the API
      setState(() {
        _assignmentDetails = {
          'is_active': 1,
          'assigned_by_username': 'SuperAdmin',
          'assigned_at': DateTime.now().toIso8601String(),
          'removed_at': null,
          'notes': 'Initial assignment',
        };
        _notesController.text = _assignmentDetails!['notes'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateNotes() async {
    try {
      // Here you would call an API to update the notes
      // For now, we'll just update the local state
      setState(() {
        _assignmentDetails!['notes'] = _notesController.text;
        _isEditing = false;
      });
      
      SuccessUtils.showBusinessSuccess(context, 'Notes updated successfully');
      widget.onAssignmentUpdated();
    } catch (e) {
      SuccessUtils.showOperationError(context, 'update notes', e.toString());
    }
  }
}

// =====================================================
// QUICK ASSIGN DIALOG (SUPERADMIN ONLY)
// =====================================================

class QuickAssignDialog extends StatefulWidget {
  final Map<String, dynamic> store;
  final Map<String, dynamic> business;
  final VoidCallback onAssignmentCreated;

  const QuickAssignDialog({
    super.key,
    required this.store,
    required this.business,
    required this.onAssignmentCreated,
  });

  @override
  State<QuickAssignDialog> createState() => _QuickAssignDialogState();
}

class _QuickAssignDialogState extends State<QuickAssignDialog> {
  final ApiService _apiService = ApiService();
  final TextEditingController _notesController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.5,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.quick_contacts_dialer, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                Text(
                  t(context, 'Quick Assignment'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Store and Business Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.store, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        t(context, 'Store'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.store['name']} (${widget.store['store_code']})',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.business, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        t(context, 'Business'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.business['name']} (${widget.business['business_code']})',
                    style: TextStyle(color: Colors.green[700]),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Notes
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: t(context, 'Notes (Optional)'),
                border: const OutlineInputBorder(),
                hintText: t(context, 'Add notes for this assignment...'),
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 20),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: Text(t(context, 'Cancel')),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createAssignment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(t(context, 'Create Assignment')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAssignment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.assignBusinessToStore(
        widget.store['id'],
        widget.business['id'],
        notes: _notesController.text.trim(),
      );
      
      Navigator.of(context).pop();
      widget.onAssignmentCreated();
      
      SuccessUtils.showBusinessSuccess(
        context,
        'Store "${widget.store['name']}" assigned to business "${widget.business['name']}" successfully!',
      );
    } catch (e) {
      SuccessUtils.showOperationError(context, 'create assignment', e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
