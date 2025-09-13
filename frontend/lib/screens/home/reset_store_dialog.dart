import 'package:flutter/material.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/success_utils.dart';
import 'package:retail_management/utils/translate.dart';

// =====================================================
// RESET STORE DIALOG (SUPERADMIN ONLY)
// =====================================================

class ResetStoreDialog extends StatefulWidget {
  final List<Map<String, dynamic>> stores;
  final VoidCallback onStoreReset;

  const ResetStoreDialog({
    super.key,
    required this.stores,
    required this.onStoreReset,
  });

  @override
  State<ResetStoreDialog> createState() => _ResetStoreDialogState();
}

class _ResetStoreDialogState extends State<ResetStoreDialog> {
  final ApiService _apiService = ApiService();
  final TextEditingController _reasonController = TextEditingController();
  
  Map<String, dynamic>? _selectedStore;
  bool _isLoading = false;
  bool _confirmReset = false;

  @override
  void dispose() {
    _reasonController.dispose();
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
                Icon(Icons.warning, color: Colors.red, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t(context, 'Reset Store'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Warning Message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        t(context, 'DANGER: This action cannot be undone!'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t(context, 'Resetting a store will permanently remove:'),
                    style: TextStyle(color: Colors.red[700]),
                  ),
                  const SizedBox(height: 8),
                  ...[
                    t(context, '• All business assignments'),
                    t(context, '• All inventory data'),
                    t(context, '• All transfer history'),
                    t(context, '• All movement records'),
                    t(context, '• All pending transfers will be cancelled'),
                  ].map((item) => Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Text(
                      item,
                      style: TextStyle(color: Colors.red[600]),
                    ),
                  )).toList(),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Store Selection
            Text(
              t(context, 'Select Store to Reset'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedStore,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: t(context, 'Choose a store...'),
              ),
              items: widget.stores.map((store) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: store,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${t(context, 'Code')}: ${store['store_code'] ?? ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStore = value;
                });
              },
            ),
            
            const SizedBox(height: 20),
            
            // Reason Input
            Text(
              t(context, 'Reason for Reset (Required)'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: t(context, 'Enter reason for resetting this store...'),
                prefixIcon: const Icon(Icons.edit_note),
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 20),
            
            // Confirmation Checkbox
            Row(
              children: [
                Checkbox(
                  value: _confirmReset,
                  onChanged: (value) {
                    setState(() {
                      _confirmReset = value ?? false;
                    });
                  },
                ),
                Expanded(
                  child: Text(
                    t(context, 'I understand this action will permanently delete all store data and cannot be undone'),
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text(t(context, 'Cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canReset() ? _resetStore : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(t(context, 'Reset Store')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _canReset() {
    return _selectedStore != null &&
           _reasonController.text.trim().isNotEmpty &&
           _confirmReset &&
           !_isLoading;
  }

  Future<void> _resetStore() async {
    if (_selectedStore == null) return;

    // Final confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            Text(t(context, 'Final Confirmation')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(context, 'Are you absolutely sure you want to reset this store?')),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t(context, 'Store')}: ${_selectedStore!['name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${t(context, 'Code')}: ${_selectedStore!['store_code']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${t(context, 'Reason')}: ${_reasonController.text.trim()}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t(context, 'This action cannot be undone!'),
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
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
            child: Text(t(context, 'Yes, Reset Store')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.resetStore(
        _selectedStore!['id'],
        reason: _reasonController.text.trim(),
      );
      
      Navigator.of(context).pop();
      widget.onStoreReset();
      
      // Show success message with details
      SuccessUtils.showBusinessSuccess(
        context,
        'Store "${_selectedStore!['name']}" has been reset successfully!\n\nData removed:\n• ${result['data_removed']['assignments']} assignments\n• ${result['data_removed']['inventory_records']} inventory records\n• ${result['data_removed']['transfers_cancelled']} transfers cancelled\n• ${result['data_removed']['movements']} movements',
      );
    } catch (e) {
      SuccessUtils.showOperationError(context, 'reset store', e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
