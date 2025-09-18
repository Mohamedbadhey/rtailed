import 'package:flutter/material.dart';
import 'package:retail_management/services/api_service.dart';
import 'package:retail_management/utils/success_utils.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/utils/responsive_utils.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Responsive dimensions
    double dialogWidth;
    double dialogHeight;
    EdgeInsets dialogPadding;
    
    if (ResponsiveUtils.isMobile(context)) {
      dialogWidth = screenWidth * 0.95; // 95% of screen width on mobile
      dialogHeight = screenHeight * 0.85; // 85% of screen height on mobile
      dialogPadding = const EdgeInsets.all(16);
    } else if (ResponsiveUtils.isTablet(context)) {
      dialogWidth = screenWidth * 0.75; // 75% of screen width on tablet
      dialogHeight = screenHeight * 0.8; // 80% of screen height on tablet
      dialogPadding = const EdgeInsets.all(20);
    } else {
      dialogWidth = screenWidth * 0.6; // 60% of screen width on desktop
      dialogHeight = screenHeight * 0.7; // 70% of screen height on desktop
      dialogPadding = const EdgeInsets.all(24);
    }
    
    return Dialog(
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: dialogPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.warning, 
                  color: Colors.red, 
                  size: ResponsiveUtils.isMobile(context) ? 24 : 28,
                ),
                SizedBox(width: ResponsiveUtils.isMobile(context) ? 8 : 12),
                Expanded(
                  child: Text(
                    t(context, 'Reset Store'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 18,
                        tablet: 20,
                        desktop: 22,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    size: ResponsiveUtils.isMobile(context) ? 20 : 24,
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
            
            // Warning Message
            Container(
              padding: ResponsiveUtils.getResponsiveCardPadding(context).copyWith(
                left: ResponsiveUtils.isMobile(context) ? 12 : 16,
                right: ResponsiveUtils.isMobile(context) ? 12 : 16,
                top: ResponsiveUtils.isMobile(context) ? 12 : 16,
                bottom: ResponsiveUtils.isMobile(context) ? 12 : 16,
              ),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(ResponsiveUtils.isMobile(context) ? 6 : 8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber, 
                        color: Colors.red[700], 
                        size: ResponsiveUtils.isMobile(context) ? 18 : 20,
                      ),
                      SizedBox(width: ResponsiveUtils.isMobile(context) ? 6 : 8),
                      Expanded(
                        child: Text(
                          t(context, 'DANGER: This action cannot be undone!'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 13,
                              tablet: 14,
                              desktop: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveUtils.isMobile(context) ? 8 : 12),
                  Text(
                    t(context, 'Resetting a store will permanently remove:'),
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 13,
                        tablet: 14,
                        desktop: 15,
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.isMobile(context) ? 6 : 8),
                  ...[
                    t(context, '• All business assignments'),
                    t(context, '• All inventory data'),
                    t(context, '• All transfer history'),
                    t(context, '• All movement records'),
                    t(context, '• All pending transfers will be cancelled'),
                  ].map((item) => Padding(
                    padding: EdgeInsets.only(
                      left: ResponsiveUtils.isMobile(context) ? 12 : 16, 
                      bottom: ResponsiveUtils.isMobile(context) ? 3 : 4,
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        color: Colors.red[600],
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 12,
                          tablet: 13,
                          desktop: 14,
                        ),
                      ),
                    ),
                  )).toList(),
                ],
              ),
            ),
            
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
            
            // Store Selection
            Text(
              t(context, 'Select Store to Reset'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 16,
                  tablet: 17,
                  desktop: 18,
                ),
              ),
            ),
            SizedBox(height: ResponsiveUtils.isMobile(context) ? 8 : 12),
            
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedStore,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: t(context, 'Choose a store...'),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.isMobile(context) ? 12 : 16,
                  vertical: ResponsiveUtils.isMobile(context) ? 12 : 16,
                ),
              ),
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
              items: widget.stores.map((store) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: store,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        store['name'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 14,
                            tablet: 15,
                            desktop: 16,
                          ),
                        ),
                      ),
                      Text(
                        '${t(context, 'Code')}: ${store['store_code'] ?? ''}',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 11,
                            tablet: 12,
                            desktop: 12,
                          ),
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
            
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
            
            // Reason Input
            Text(
              t(context, 'Reason for Reset (Required)'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 16,
                  tablet: 17,
                  desktop: 18,
                ),
              ),
            ),
            SizedBox(height: ResponsiveUtils.isMobile(context) ? 8 : 12),
            
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: t(context, 'Enter reason for resetting this store...'),
                prefixIcon: Icon(
                  Icons.edit_note,
                  size: ResponsiveUtils.isMobile(context) ? 20 : 24,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.isMobile(context) ? 12 : 16,
                  vertical: ResponsiveUtils.isMobile(context) ? 12 : 16,
                ),
              ),
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
              maxLines: ResponsiveUtils.isMobile(context) ? 2 : 3,
            ),
            
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
            
            // Confirmation Checkbox
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _confirmReset,
                  onChanged: (value) {
                    setState(() {
                      _confirmReset = value ?? false;
                    });
                  },
                  materialTapTargetSize: ResponsiveUtils.isMobile(context) 
                      ? MaterialTapTargetSize.shrinkWrap 
                      : MaterialTapTargetSize.padded,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: ResponsiveUtils.isMobile(context) ? 8 : 12),
                    child: Text(
                      t(context, 'I understand this action will permanently delete all store data and cannot be undone'),
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 13,
                          tablet: 14,
                          desktop: 15,
                        ),
                      ),
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
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: ResponsiveUtils.getResponsiveButtonHeight(context) * 0.4,
                      ),
                    ),
                    child: Text(
                      t(context, 'Cancel'),
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 14,
                          tablet: 15,
                          desktop: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.isMobile(context) ? 8 : 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canReset() ? _resetStore : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: ResponsiveUtils.getResponsiveButtonHeight(context) * 0.4,
                      ),
                      minimumSize: Size(
                        0, 
                        ResponsiveUtils.getResponsiveButtonHeight(context),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: ResponsiveUtils.isMobile(context) ? 18 : 20,
                            height: ResponsiveUtils.isMobile(context) ? 18 : 20,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2, 
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            t(context, 'Reset Store'),
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getResponsiveFontSize(
                                context,
                                mobile: 14,
                                tablet: 15,
                                desktop: 16,
                              ),
                            ),
                          ),
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
            Icon(
              Icons.warning, 
              color: Colors.red,
              size: ResponsiveUtils.isMobile(context) ? 20 : 24,
            ),
            SizedBox(width: ResponsiveUtils.isMobile(context) ? 6 : 8),
            Expanded(
              child: Text(
                t(context, 'Final Confirmation'),
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 16,
                    tablet: 17,
                    desktop: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(context, 'Are you absolutely sure you want to reset this store?'),
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
            SizedBox(height: ResponsiveUtils.isMobile(context) ? 8 : 12),
            Container(
              padding: EdgeInsets.all(ResponsiveUtils.isMobile(context) ? 10 : 12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(ResponsiveUtils.isMobile(context) ? 6 : 8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t(context, 'Store')}: ${_selectedStore!['name']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 13,
                        tablet: 14,
                        desktop: 15,
                      ),
                    ),
                  ),
                  Text(
                    '${t(context, 'Code')}: ${_selectedStore!['store_code']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 13,
                        tablet: 14,
                        desktop: 15,
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.isMobile(context) ? 6 : 8),
                  Text(
                    '${t(context, 'Reason')}: ${_reasonController.text.trim()}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 12,
                        tablet: 13,
                        desktop: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: ResponsiveUtils.isMobile(context) ? 8 : 12),
            Text(
              t(context, 'This action cannot be undone!'),
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 13,
                  tablet: 14,
                  desktop: 15,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              t(context, 'Cancel'),
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.isMobile(context) ? 16 : 20,
                vertical: ResponsiveUtils.isMobile(context) ? 8 : 12,
              ),
            ),
            child: Text(
              t(context, 'Yes, Reset Store'),
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
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
