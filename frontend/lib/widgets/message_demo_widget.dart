import 'package:flutter/material.dart';
import 'package:quickalert/quickalert.dart';
import '../utils/success_utils.dart';

class MessageDemoWidget extends StatelessWidget {
  const MessageDemoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QuickAlert Message Demo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Success Messages',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Success Messages
            _buildDemoButton(
              context,
              'Show Sale Success',
              Colors.green,
              () => SuccessUtils.showSaleSuccess(context, '12345'),
            ),
            
            _buildDemoButton(
              context,
              'Show Product Success',
              Colors.green,
              () => SuccessUtils.showProductSuccess(context, 'added'),
            ),
            
            _buildDemoButton(
              context,
              'Show Custom Success',
              Colors.green,
              () => SuccessUtils.showSuccessTick(
                context,
                'This is a custom success message with detailed information about what was accomplished successfully.',
                title: 'Custom Success!',
              ),
            ),
            
            const SizedBox(height: 40),
            const Text(
              'Error Messages',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Error Messages
            _buildDemoButton(
              context,
              'Show Sale Error',
              Colors.red,
              () => SuccessUtils.showSaleError(
                context,
                'Payment gateway timeout. Please try again or contact support.',
              ),
            ),
            
            _buildDemoButton(
              context,
              'Show Product Error',
              Colors.red,
              () => SuccessUtils.showProductError(
                context,
                'add',
                'Database connection failed. Product data could not be saved.',
              ),
            ),
            
            _buildDemoButton(
              context,
              'Show Operation Error',
              Colors.red,
              () => SuccessUtils.showOperationError(
                context,
                'process payment',
                'Insufficient funds in account. Please check your balance.',
              ),
            ),
            
            const SizedBox(height: 40),
            const Text(
              'Warning Messages',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Warning Messages
            _buildDemoButton(
              context,
              'Show Warning',
              Colors.orange,
              () => SuccessUtils.showWarningTick(
                context,
                'Low stock alert: Product "Premium Widget" is running low. Current stock: 5 units.',
              ),
            ),
            
            _buildDemoButton(
              context,
              'Show Operation Warning',
              Colors.orange,
              () => SuccessUtils.showOperationWarning(
                context,
                'delete product',
                'This action cannot be undone. All associated data will be permanently removed.',
              ),
            ),
            
            const SizedBox(height: 40),
            const Text(
              'Info Messages',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Info Messages
            _buildDemoButton(
              context,
              'Show Info',
              Colors.blue,
              () => SuccessUtils.showInfoTick(
                context,
                'System maintenance scheduled for tonight at 2:00 AM. Expected downtime: 30 minutes.',
              ),
            ),
            
            _buildDemoButton(
              context,
              'Show Operation Info',
              Colors.blue,
              () => SuccessUtils.showOperationInfo(
                context,
                'Data Export',
                'Your report has been queued for generation. You will receive a notification when it\'s ready for download.',
              ),
            ),
            
            const SizedBox(height: 40),
            const Text(
              'Confirmation Dialogs',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Confirmation Dialogs
            _buildDemoButton(
              context,
              'Show Confirmation Dialog',
              Colors.purple,
              () => SuccessUtils.showConfirm(
                context,
                'Are you sure you want to delete this product? This action cannot be undone.',
                title: 'Confirm Deletion',
                confirmText: 'Delete',
                cancelText: 'Cancel',
                onConfirm: () {
                  // Simulate deletion
                  SuccessUtils.showSuccessTick(
                    context,
                    'Product deleted successfully!',
                    title: 'Deleted!',
                  );
                },
                onCancel: () {
                  SuccessUtils.showInfoTick(
                    context,
                    'Deletion cancelled.',
                    title: 'Cancelled',
                  );
                },
              ),
            ),
            
            _buildDemoButton(
              context,
              'Show Payment Confirmation',
              Colors.blue,
              () => SuccessUtils.showConfirm(
                context,
                'Do you want to proceed with this payment of \$150.00?',
                title: 'Payment Confirmation',
                confirmText: 'Pay Now',
                cancelText: 'Review',
                messageType: QuickAlertType.info,
                onConfirm: () {
                  SuccessUtils.showSuccessTick(
                    context,
                    'Payment processed successfully!\nTransaction ID: TXN-2024-001',
                    title: 'Payment Complete!',
                  );
                },
              ),
            ),
            
            const SizedBox(height: 40),
            const Text(
              'Loading Alerts',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Loading Alerts
            _buildDemoButton(
              context,
              'Show Loading Alert',
              Colors.blue,
              () {
                SuccessUtils.showLoading(
                  context,
                  message: 'Processing your request...',
                  title: 'Please Wait',
                );
                // Auto-hide after 3 seconds for demo
                Future.delayed(const Duration(seconds: 3), () {
                  if (context.mounted) {
                    SuccessUtils.hideLoading(context);
                    SuccessUtils.showSuccessTick(
                      context,
                      'Request processed successfully!',
                      title: 'Complete!',
                    );
                  }
                });
              },
            ),
            
            _buildDemoButton(
              context,
              'Show Loading with Custom Message',
              Colors.blue,
              () {
                SuccessUtils.showLoading(
                  context,
                  message: 'Uploading files to server...\nPlease do not close this window.',
                  title: 'Uploading',
                );
                // Auto-hide after 4 seconds for demo
                Future.delayed(const Duration(seconds: 4), () {
                  if (context.mounted) {
                    SuccessUtils.hideLoading(context);
                    SuccessUtils.showSuccessTick(
                      context,
                      'Files uploaded successfully!\nTotal files: 15\nSize: 45.2 MB',
                      title: 'Upload Complete!',
                    );
                  }
                });
              },
            ),
            
            const SizedBox(height: 40),
            const Text(
              'Direct QuickAlert Usage',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Direct QuickAlert Usage
            _buildDemoButton(
              context,
              'Custom Success Alert',
              Colors.green,
              () => QuickAlert.show(
                context: context,
                type: QuickAlertType.success,
                title: 'Profile Updated!',
                text: 'Your profile has been updated successfully!\n\nChanges saved:\n• Email address updated\n• Phone number updated\n• Profile picture changed',
                confirmBtnText: 'Great!',
                confirmBtnColor: Colors.green,
                showConfirmBtn: true,
                showCancelBtn: false,
                autoCloseDuration: const Duration(seconds: 6),
              ),
            ),
            
            _buildDemoButton(
              context,
              'Custom Error Alert',
              Colors.red,
              () => QuickAlert.show(
                context: context,
                type: QuickAlertType.error,
                title: 'Connection Error',
                text: 'Network connection failed.\n\nPlease check your internet connection and try again. If the problem persists, contact technical support.',
                confirmBtnText: 'Try Again',
                confirmBtnColor: Colors.red,
                showConfirmBtn: true,
                showCancelBtn: false,
                autoCloseDuration: const Duration(seconds: 8),
              ),
            ),
            
            _buildDemoButton(
              context,
              'Custom Warning Alert',
              Colors.orange,
              () => QuickAlert.show(
                context: context,
                type: QuickAlertType.warning,
                title: 'Unsaved Changes',
                text: 'You have unsaved changes.\n\nIf you leave now, all your changes will be lost. Are you sure you want to continue?',
                confirmBtnText: 'Leave Anyway',
                cancelBtnText: 'Stay Here',
                confirmBtnColor: Colors.orange,
                showConfirmBtn: true,
                showCancelBtn: true,
                onConfirmBtnTap: () {
                  Navigator.pop(context);
                  SuccessUtils.showInfoTick(
                    context,
                    'You left without saving. Changes were lost.',
                    title: 'Changes Lost',
                  );
                },
                onCancelBtnTap: () {
                  Navigator.pop(context);
                  SuccessUtils.showSuccessTick(
                    context,
                    'You stayed on the page. Your changes are preserved.',
                    title: 'Changes Preserved',
                  );
                },
              ),
            ),
            
            _buildDemoButton(
              context,
              'Custom Info Alert',
              Colors.blue,
              () => QuickAlert.show(
                context: context,
                type: QuickAlertType.info,
                title: 'What\'s New',
                text: 'New features available!\n\n• Dark mode support\n• Enhanced search functionality\n• Improved performance\n• Bug fixes and updates',
                confirmBtnText: 'Got It!',
                confirmBtnColor: Colors.blue,
                showConfirmBtn: true,
                showCancelBtn: false,
                autoCloseDuration: const Duration(seconds: 7),
              ),
            ),
            
            const SizedBox(height: 40),
            const Text(
              'Real-world Examples',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Real-world Examples
            _buildDemoButton(
              context,
              'POS Sale Complete',
              Colors.green,
              () => SuccessUtils.showSaleSuccess(context, 'SALE-2024-001'),
            ),
            
            _buildDemoButton(
              context,
              'Inventory Low Stock',
              Colors.orange,
              () => SuccessUtils.showWarningTick(
                context,
                'Low Stock Alert\n\n'
                'Product: Premium Coffee Beans\n'
                'Current Stock: 3 units\n'
                'Reorder Level: 10 units\n'
                'Last Restocked: 2 days ago',
              ),
            ),
            
            _buildDemoButton(
              context,
              'Payment Failed',
              Colors.red,
              () => SuccessUtils.showPaymentError(
                context,
                'Card declined. Reason: Insufficient funds.\n'
                'Please try a different payment method or contact your bank.',
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoButton(
    BuildContext context,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
