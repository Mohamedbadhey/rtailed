import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/providers/auth_provider.dart';

class BrandingInitializer extends StatefulWidget {
  final Widget child;

  const BrandingInitializer({
    super.key,
    required this.child,
  });

  @override
  State<BrandingInitializer> createState() => _BrandingInitializerState();
}

class _BrandingInitializerState extends State<BrandingInitializer> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Use a microtask to ensure this runs after the build is complete
    Future.microtask(() {
      _initializeBranding();
    });
  }

  Future<void> _initializeBranding() async {
    try {
      final brandingProvider = context.read<BrandingProvider>();
      final authProvider = context.read<AuthProvider>();
      
      // Load system branding first
      await brandingProvider.loadSystemBranding();
      await brandingProvider.loadThemes();
      
      // If user is authenticated and has a business, load business branding
      if (authProvider.isAuthenticated && authProvider.user?.businessId != null) {
        await brandingProvider.loadBusinessBranding(authProvider.user!.businessId!);
      }
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing branding: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true; // Continue anyway
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading branding...'),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}

class BrandingListener extends StatefulWidget {
  final Widget child;

  const BrandingListener({
    super.key,
    required this.child,
  });

  @override
  State<BrandingListener> createState() => _BrandingListenerState();
}

class _BrandingListenerState extends State<BrandingListener> {
  @override
  void initState() {
    super.initState();
    // Use a microtask to ensure this runs after the build is complete
    Future.microtask(() {
      _listenToAuthChanges();
    });
  }

  void _listenToAuthChanges() {
    final authProvider = context.read<AuthProvider>();
    final brandingProvider = context.read<BrandingProvider>();
    
    // Listen to auth changes and reload business branding when needed
    authProvider.addListener(() {
      if (authProvider.isAuthenticated && authProvider.user?.businessId != null) {
        brandingProvider.loadBusinessBranding(authProvider.user!.businessId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
} 