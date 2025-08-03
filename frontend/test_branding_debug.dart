import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/widgets/branded_header.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Branding Debug Test',
      home: BrandingDebugScreen(),
    );
  }
}

class BrandingDebugScreen extends StatefulWidget {
  @override
  _BrandingDebugScreenState createState() => _BrandingDebugScreenState();
}

class _BrandingDebugScreenState extends State<BrandingDebugScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize branding after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBranding();
    });
  }

  Future<void> _initializeBranding() async {
    final brandingProvider = context.read<BrandingProvider>();
    print('🔍 Initializing branding...');
    
    try {
      await brandingProvider.loadSystemBranding();
      print('✅ System branding loaded');
      
      // Test the getters
      final logo = brandingProvider.getCurrentLogo(null);
      final appName = brandingProvider.getCurrentAppName(null);
      final primaryColor = brandingProvider.getPrimaryColor(null);
      
      print('📊 Branding Data:');
      print('  Logo: $logo');
      print('  App Name: $appName');
      print('  Primary Color: $primaryColor');
      
      setState(() {});
    } catch (e) {
      print('❌ Error loading branding: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Branding Debug Test'),
      ),
      body: Consumer<BrandingProvider>(
        builder: (context, brandingProvider, child) {
          return Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Branding Debug Information',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                
                // System branding info
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'System Branding:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10),
                        Text('Logo: ${brandingProvider.getCurrentLogo(null)}'),
                        Text('App Name: ${brandingProvider.getCurrentAppName(null)}'),
                        Text('Primary Color: ${brandingProvider.getPrimaryColor(null)}'),
                        Text('System Branding Loaded: ${brandingProvider._systemBrandingLoaded}'),
                        Text('System Branding Data: ${brandingProvider._systemBranding}'),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Test the BrandedLogo widget
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BrandedLogo Widget Test:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10),
                        Center(
                          child: BrandedLogo(
                            size: 80,
                            businessId: null,
                          ),
                        ),
                        SizedBox(height: 10),
                        Center(
                          child: Text(
                            brandingProvider.getCurrentAppName(null),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Manual refresh button
                ElevatedButton(
                  onPressed: () async {
                    print('🔄 Manually refreshing branding...');
                    await brandingProvider.loadSystemBranding();
                    setState(() {});
                  },
                  child: Text('Refresh Branding'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 