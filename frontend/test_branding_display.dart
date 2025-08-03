import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lib/providers/branding_provider.dart';
import 'lib/providers/auth_provider.dart';
import 'lib/widgets/branded_app_bar.dart';
import 'lib/widgets/branded_header.dart';

class BrandingDisplayTest extends StatefulWidget {
  const BrandingDisplayTest({Key? key}) : super(key: key);

  @override
  State<BrandingDisplayTest> createState() => _BrandingDisplayTestState();
}

class _BrandingDisplayTestState extends State<BrandingDisplayTest> {
  bool _isLoading = false;
  Map<String, dynamic> _systemBranding = {};
  Map<String, dynamic> _businessBranding = {};
  List<Map<String, dynamic>> _businesses = [];

  @override
  void initState() {
    super.initState();
    _loadBrandingData();
  }

  Future<void> _loadBrandingData() async {
    setState(() => _isLoading = true);
    
    try {
      final brandingProvider = context.read<BrandingProvider>();
      
      // Load system branding
      await brandingProvider.loadSystemBranding();
      _systemBranding = brandingProvider.systemBranding;
      
      // Load business branding for business ID 1
      await brandingProvider.loadBusinessBranding(1);
      _businessBranding = brandingProvider.businessBranding;
      
      // Load businesses
      final response = await Future.delayed(Duration(seconds: 1), () {
        return [
          {'id': 1, 'name': 'Business 1', 'logo': '/uploads/branding/file-1754047808502-889792832.png'},
          {'id': 2, 'name': 'Business 2', 'logo': '/uploads/branding/file-1754047811346-749514891.png'},
          {'id': 3, 'name': 'Business 3', 'logo': '/uploads/branding/file-1754049436337-160209782.png'},
        ];
      });
      _businesses = List<Map<String, dynamic>>.from(response);
      
    } catch (e) {
      print('Error loading branding data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar(
        title: 'Branding Display Test',
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // System Branding Section
                  _buildSection('System Branding', [
                    _buildBrandingCard('System', null, _systemBranding),
                  ]),
                  
                  const SizedBox(height: 24),
                  
                  // Business Branding Section
                  _buildSection('Business Branding', [
                    _buildBrandingCard('Business 1', 1, _businessBranding),
                  ]),
                  
                  const SizedBox(height: 24),
                  
                  // All Businesses Section
                  _buildSection('All Businesses', _businesses.map((business) {
                    return _buildBusinessCard(business);
                  }).toList()),
                  
                  const SizedBox(height: 24),
                  
                  // Test Different Logo Sizes
                  _buildSection('Logo Size Tests', [
                    _buildLogoSizeTest('Small', 40),
                    _buildLogoSizeTest('Medium', 80),
                    _buildLogoSizeTest('Large', 120),
                  ]),
                  
                  const SizedBox(height: 24),
                  
                  // Image URL Tests
                  _buildSection('Image URL Tests', [
                    _buildImageUrlTest('System Logo', _systemBranding['logo_url']),
                    _buildImageUrlTest('Business Logo', _businessBranding['logo']),
                    _buildImageUrlTest('Business 1 Logo', '/uploads/branding/file-1754047808502-889792832.png'),
                    _buildImageUrlTest('Business 2 Logo', '/uploads/branding/file-1754047811346-749514891.png'),
                    _buildImageUrlTest('Business 3 Logo', '/uploads/branding/file-1754049436337-160209782.png'),
                  ]),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildBrandingCard(String title, int? businessId, Map<String, dynamic> branding) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Logo
                BrandedLogo(
                  size: 60,
                  businessId: businessId,
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('App Name: ${branding['app_name'] ?? branding['name'] ?? 'N/A'}'),
                      Text('Logo URL: ${branding['logo_url'] ?? branding['logo'] ?? 'N/A'}'),
                      Text('Primary Color: ${branding['primary_color'] ?? 'N/A'}'),
                      Text('Secondary Color: ${branding['secondary_color'] ?? 'N/A'}'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessCard(Map<String, dynamic> business) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              business['name'],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Logo
                if (business['logo'] != null)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        'https://rtailed-production.up.railway.app${business['logo']}',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            child: const Icon(Icons.business, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  )
                else
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade200,
                    ),
                    child: const Icon(Icons.business, color: Colors.grey),
                  ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ID: ${business['id']}'),
                      Text('Logo URL: ${business['logo'] ?? 'N/A'}'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSizeTest(String sizeName, double size) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$sizeName Logo ($size x $size)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            BrandedLogo(
              size: size,
              businessId: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUrlTest(String title, String? imageUrl) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text('URL: ${imageUrl ?? 'N/A'}'),
            const SizedBox(height: 8),
            if (imageUrl != null)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    'https://rtailed-production.up.railway.app$imageUrl',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error, color: Colors.red, size: 24),
                            const SizedBox(height: 4),
                            Text(
                              'Error',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red[700],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Loading...',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade200,
                ),
                child: const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

// Test runner
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(ApiService(), null)),
        ChangeNotifierProvider(create: (_) => BrandingProvider()),
      ],
      child: const MaterialApp(
        home: BrandingDisplayTest(),
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
} 