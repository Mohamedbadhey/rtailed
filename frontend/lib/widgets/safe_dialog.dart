import 'package:flutter/material.dart';

/// A safe dialog widget that prevents RenderFlex overflow issues
class SafeDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final bool scrollable;
  final double? maxHeight;
  final double? maxWidth;

  const SafeDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.scrollable = true,
    this.maxHeight = 600,
    this.maxWidth = 500,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: scrollable
          ? SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxHeight ?? 600,
                  maxWidth: maxWidth ?? 500,
                ),
                child: content,
              ),
            )
          : ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxHeight ?? 600,
                maxWidth: maxWidth ?? 500,
              ),
              child: content,
            ),
      actions: actions,
    );
  }
}

/// A safe dialog with form content
class SafeFormDialog extends StatelessWidget {
  final String title;
  final Widget formContent;
  final List<Widget>? actions;
  final double? maxHeight;
  final double? maxWidth;

  const SafeFormDialog({
    super.key,
    required this.title,
    required this.formContent,
    this.actions,
    this.maxHeight = 600,
    this.maxWidth = 500,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxHeight ?? 600,
            maxWidth: maxWidth ?? 500,
          ),
          child: Form(
            child: formContent,
          ),
        ),
      ),
      actions: actions,
    );
  }
} 