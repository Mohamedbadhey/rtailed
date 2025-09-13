import 'package:flutter/material.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/success_utils.dart';
import 'package:retail_management/utils/translate.dart';

// =====================================================
// STORE BUSINESS DIALOG (SUPERADMIN ONLY)
// =====================================================

class StoreBusinessDialog extends StatefulWidget {
  final Map<String, dynamic> store;
  final List<Map<String, dynamic>> businesses;
  final List<Map<String, dynamic>> assignments;
  final VoidCallback onAssignmentChanged;

  const StoreBusinessDialog({
    super.key,
    required this.store,
    required this.businesses,
    required this.assignments,
    required this.onAssignmentChanged,
  });

  @override
  State<StoreBusinessDialog> createState() => _StoreBusinessDialogState();
}

class _StoreBusinessDialogState extends State<StoreBusinessDialog> {
  final ApiService _apiService = ApiService();
  final TextEditingController _notesController = TextEditingController();
  
  bool _isLoading = false;
  Map<String, dynamic>? _selectedBusiness;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get assigned businesses for this store
    final assignedBusinessIds = widget.assignments
        .where((assignment) => 
          assignment['store_id'] == widget.store['id'] && 
          assignment['is_active'] == true)
        .map((assignment) => assignment['business_id'])
        .toList();

    final assignedBusinesses = widget.businesses
        .where((business) => assignedBusinessIds.contains(business['id']))
        .toList();

    final unassignedBusinesses = widget.businesses
        .where((business) => !assignedBusinessIds.contains(business['id']))
        .toList();

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.store, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.store['name'] ?? '',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${t(context, 'Code')}: ${widget.store['store_code'] ?? ''}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Assigned Businesses Section
            Text(
              t(context, 'Assigned Businesses (${assignedBusinesses.length})'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 12),
            
            // Assigned Businesses List
            Expanded(
              flex: 2,
              child: assignedBusinesses.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.business_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              t(context, 'No businesses assigned'),
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: assignedBusinesses.length,
                      itemBuilder: (context, index) {
                        final business = assignedBusinesses[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green,
                              child: Icon(Icons.business, color: Colors.white, size: 20),
                            ),
                            title: Text(
                              business['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text('${t(context, 'Code')}: ${business['business_code'] ?? ''}'),
                            trailing: ElevatedButton(
                              onPressed: () => _removeBusinessFromStore(business),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: Text(t(context, 'Remove')),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            
            const SizedBox(height: 20),
            
            // Assign New Business Section
            Text(
              t(context, 'Assign New Business'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 12),
            
            // Business Selection and Assignment
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Map<String, dynamic>>(
                    value: _selectedBusiness,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: t(context, 'Select a business...'),
                    ),
                    items: unassignedBusinesses.map((business) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: business,
                        child: Text('${business['name']} (${business['business_code']})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedBusiness = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _selectedBusiness == null || _isLoading ? null : _assignBusinessToStore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(t(context, 'Assign')),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Notes
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: t(context, 'Notes (Optional)'),
                border: const OutlineInputBorder(),
                hintText: t(context, 'Add notes for this assignment...'),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignBusinessToStore() async {
    if (_selectedBusiness == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.assignBusinessToStore(
        widget.store['id'],
        _selectedBusiness!['id'],
        notes: _notesController.text.trim(),
      );
      
      _notesController.clear();
      setState(() {
        _selectedBusiness = null;
      });
      
      widget.onAssignmentChanged();
      
      SuccessUtils.showBusinessSuccess(
        context,
        'Business "${_selectedBusiness!['name']}" assigned to store "${widget.store['name']}" successfully!',
      );
    } catch (e) {
      SuccessUtils.showOperationError(context, 'assign business to store', e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeBusinessFromStore(Map<String, dynamic> business) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'Confirm Removal')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(context, 'Are you sure you want to remove this business from the store?')),
            const SizedBox(height: 8),
            Text(
              '${business['name']} from ${widget.store['name']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t(context, 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t(context, 'Remove')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.removeBusinessFromStore(widget.store['id'], business['id']);
        widget.onAssignmentChanged();
        
        SuccessUtils.showBusinessSuccess(
          context,
          'Business "${business['name']}" removed from store "${widget.store['name']}" successfully!',
        );
      } catch (e) {
        SuccessUtils.showOperationError(context, 'remove business from store', e.toString());
      }
    }
  }
}
