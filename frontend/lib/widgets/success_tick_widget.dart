import 'package:flutter/material.dart';

enum MessageType { success, error, warning, info }

class SweetAlertWidget extends StatelessWidget {
  final String message;
  final Duration duration;
  final VoidCallback? onDismiss;
  final MessageType messageType;
  final String? title;
  final bool showConfirmButton;
  final String confirmButtonText;
  final VoidCallback? onConfirm;

  const SweetAlertWidget({
    Key? key,
    required this.message,
    this.duration = const Duration(seconds: 3),
    this.onDismiss,
    this.messageType = MessageType.success,
    this.title,
    this.showConfirmButton = true,
    this.confirmButtonText = 'OK',
    this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();
    final icon = _getIcon();
    final defaultTitle = _getDefaultTitle();

    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Icon
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colors.first.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    // Icon Circle
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colors.first,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.first.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    Text(
                      title ?? defaultTitle,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colors.first,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              // Message Content
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    if (showConfirmButton)
                      Row(
                        children: [
                          if (onDismiss != null) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: onDismiss,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: BorderSide(color: colors.first),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: colors.first,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          Expanded(
                            child: ElevatedButton(
                              onPressed: onConfirm ?? onDismiss,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.first,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                confirmButtonText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (onDismiss != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onDismiss,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.first,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            confirmButtonText,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _getColors() {
    switch (messageType) {
      case MessageType.success:
        return [Colors.green.shade600, Colors.green.shade700];
      case MessageType.error:
        return [Colors.red.shade600, Colors.red.shade700];
      case MessageType.warning:
        return [Colors.orange.shade600, Colors.orange.shade700];
      case MessageType.info:
        return [Colors.blue.shade600, Colors.blue.shade700];
    }
  }

  IconData _getIcon() {
    switch (messageType) {
      case MessageType.success:
        return Icons.check_circle;
      case MessageType.error:
        return Icons.error;
      case MessageType.warning:
        return Icons.warning;
      case MessageType.info:
        return Icons.info;
    }
  }

  String _getDefaultTitle() {
    switch (messageType) {
      case MessageType.success:
        return 'Success!';
      case MessageType.error:
        return 'Error!';
      case MessageType.warning:
        return 'Warning!';
      case MessageType.info:
        return 'Information';
    }
  }
}

// SweetAlert-style overlay to show the modal
class SweetAlert {
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    MessageType messageType = MessageType.success,
    String? title,
    bool showConfirmButton = true,
    String confirmButtonText = 'OK',
    VoidCallback? onConfirm,
    VoidCallback? onDismiss,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => SweetAlertWidget(
        message: message,
        duration: duration,
        messageType: messageType,
        title: title,
        showConfirmButton: showConfirmButton,
        confirmButtonText: confirmButtonText,
        onConfirm: onConfirm,
        onDismiss: () {
          overlayEntry.remove();
          onDismiss?.call();
        },
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-dismiss after duration (only if no manual dismiss is needed)
    if (showConfirmButton) {
      Future.delayed(duration, () {
        if (overlayEntry.mounted) {
          overlayEntry.remove();
        }
      });
    }
  }

  // Convenience methods for different message types
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    bool showConfirmButton = true,
    String confirmButtonText = 'OK',
    VoidCallback? onConfirm,
    VoidCallback? onDismiss,
  }) {
    show(
      context,
      message,
      messageType: MessageType.success,
      title: title,
      duration: duration,
      showConfirmButton: showConfirmButton,
      confirmButtonText: confirmButtonText,
      onConfirm: onConfirm,
      onDismiss: onDismiss,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
    bool showConfirmButton = true,
    String confirmButtonText = 'OK',
    VoidCallback? onConfirm,
    VoidCallback? onDismiss,
  }) {
    show(
      context,
      message,
      messageType: MessageType.error,
      title: title,
      duration: duration,
      showConfirmButton: showConfirmButton,
      confirmButtonText: confirmButtonText,
      onConfirm: onConfirm,
      onDismiss: onDismiss,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
    bool showConfirmButton = true,
    String confirmButtonText = 'OK',
    VoidCallback? onConfirm,
    VoidCallback? onDismiss,
  }) {
    show(
      context,
      message,
      messageType: MessageType.warning,
      title: title,
      duration: duration,
      showConfirmButton: showConfirmButton,
      confirmButtonText: confirmButtonText,
      onConfirm: onConfirm,
      onDismiss: onDismiss,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    bool showConfirmButton = true,
    String confirmButtonText = 'OK',
    VoidCallback? onConfirm,
    VoidCallback? onDismiss,
  }) {
    show(
      context,
      message,
      messageType: MessageType.info,
      title: title,
      duration: duration,
      showConfirmButton: showConfirmButton,
      confirmButtonText: confirmButtonText,
      onConfirm: onConfirm,
      onDismiss: onDismiss,
    );
  }

  // Confirmation dialog with Yes/No buttons
  static void showConfirm(
    BuildContext context,
    String message, {
    String? title,
    String confirmText = 'Yes',
    String cancelText = 'No',
    MessageType messageType = MessageType.warning,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => SweetAlertWidget(
        message: message,
        messageType: messageType,
        title: title,
        showConfirmButton: true,
        confirmButtonText: confirmText,
        onConfirm: () {
          onConfirm?.call();
          overlayEntry.remove();
        },
        onDismiss: () {
          overlayEntry.remove();
          onCancel?.call();
        },
      ),
    );

    final overlay = Overlay.of(context);
    overlay.insert(overlayEntry);
  }
}
