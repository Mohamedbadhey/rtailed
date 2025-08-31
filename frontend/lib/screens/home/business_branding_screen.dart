import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/utils/translate.dart';
import 'package:retail_management/utils/theme.dart';
import 'package:retail_management/utils/type_converter.dart';
import 'package:retail_management/widgets/branded_app_bar.dart';

class BusinessBrandingScreen extends StatefulWidget {
  final int businessId;

  const BusinessBrandingScreen({
    super.key,
    required this.businessId,
  });

  @override
  State<BusinessBrandingScreen> createState() => _BusinessBrandingScreenState();
}

class _BusinessBrandingScreenState extends State<BusinessBrandingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressController = TextEditingController();
  final _socialMediaController = TextEditingController();
  final _businessHoursController = TextEditingController();
  final _currencyController = TextEditingController();
  final _timezoneController = TextEditingController();
  final _languageController = TextEditingController();
  
  String _selectedTheme = 'default';
  String _primaryColor = '#1976D2';
  String _secondaryColor = '#424242';
  String _accentColor = '#FFC107';
  
  File? _logoFile;
  File? _faviconFile;
  Uint8List? _logoBytes;
  Uint8List? _faviconBytes;
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isInitialized = false;
  bool _brandingEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBrandingData();
    });
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _taglineController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _socialMediaController.dispose();
    _businessHoursController.dispose();
    _currencyController.dispose();
    _timezoneController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  Future<void> _loadBrandingData() async {
    if (_isInitialized) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final brandingProvider = context.read<BrandingProvider>();
      
      await brandingProvider.loadBusinessBranding(widget.businessId);
      await brandingProvider.loadThemes();
      
      if (mounted) {
        _populateForm();
        
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading business branding: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _populateForm() {
    final brandingProvider = context.read<BrandingProvider>();
    final branding = brandingProvider.getBusinessBranding(widget.businessId);
    
    _businessNameController.text = TypeConverter.safeToString(branding['name'] ?? '');
    _taglineController.text = TypeConverter.safeToString(branding['tagline'] ?? '');
    _contactEmailController.text = TypeConverter.safeToString(branding['contact_email'] ?? '');
    _contactPhoneController.text = TypeConverter.safeToString(branding['contact_phone'] ?? '');
    _websiteController.text = TypeConverter.safeToString(branding['website'] ?? '');
    _addressController.text = TypeConverter.safeToString(branding['address'] ?? '');
    _socialMediaController.text = TypeConverter.safeToString(branding['social_media'] ?? '');
    _businessHoursController.text = TypeConverter.safeToString(branding['business_hours'] ?? '');
    _currencyController.text = TypeConverter.safeToString(branding['currency'] ?? 'USD');
    _timezoneController.text = TypeConverter.safeToString(branding['timezone'] ?? 'UTC');
    _languageController.text = TypeConverter.safeToString(branding['language'] ?? 'en');
    
    _selectedTheme = TypeConverter.safeToString(branding['theme'] ?? 'default');
    _primaryColor = TypeConverter.safeToString(branding['primary_color'] ?? '#1976D2');
    _secondaryColor = TypeConverter.safeToString(branding['secondary_color'] ?? '#424242');
    _accentColor = TypeConverter.safeToString(branding['accent_color'] ?? '#FFC107');
    _brandingEnabled = TypeConverter.safeToBool(branding['branding_enabled'] ?? true);
  }

  Future<void> _pickImage(String type) async {
    try {
      print('🎨 Picking image for type: $type');
      
      if (kIsWeb) {
        // For web, use the same logic as product images
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: type == 'favicon' ? 256 : 512,
          maxHeight: type == 'favicon' ? 256 : 512,
          imageQuality: 85,
        );
        
        if (image != null && mounted) {
          final bytes = await image.readAsBytes();
          final base64String = base64Encode(bytes);
          final mimeType = 'image/jpeg'; // Default to JPEG
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          
          setState(() {
            if (type == 'logo') {
              _logoBytes = bytes;
              _logoFile = null;
            } else {
              _faviconBytes = bytes;
              _faviconFile = null;
            }
          });
          
          print('🎨 Web image picked: ${bytes.length} bytes for type: $type');
        }
      } else {
        // For mobile, use file picker like products
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: type == 'favicon' ? 256 : 512,
          maxHeight: type == 'favicon' ? 256 : 512,
          imageQuality: 85,
        );
        
        if (image != null && mounted) {
          setState(() {
            if (type == 'logo') {
              _logoFile = File(image.path);
              _logoBytes = null;
            } else {
              _faviconFile = File(image.path);
              _faviconBytes = null;
            }
          });
          
          print('🎨 Mobile image picked: ${image.path} for type: $type');
        }
      }
    } catch (e) {
      print('🎨 Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadFile(String type) async {
    final brandingProvider = context.read<BrandingProvider>();
    final file = type == 'logo' ? _logoFile : _faviconFile;
    final bytes = type == 'logo' ? _logoBytes : _faviconBytes;
    
    if (file == null && bytes == null) return;
    
    setState(() {
      _isUploading = true;
    });
    
    try {
      final result = kIsWeb 
          ? await brandingProvider.uploadBusinessFileBytes(bytes!, type, widget.businessId)
          : await brandingProvider.uploadBusinessFile(file!, type, widget.businessId);
      
      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${type.toUpperCase()} uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear the file after successful upload
        setState(() {
          if (type == 'logo') {
            _logoFile = null;
            _logoBytes = null;
          } else {
            _faviconFile = null;
            _faviconBytes = null;
          }
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _saveBranding() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final brandingProvider = context.read<BrandingProvider>();
      
      final brandingData = {
        'name': _businessNameController.text.trim(),
        'tagline': _taglineController.text.trim(),
        'contact_email': _contactEmailController.text.trim(),
        'contact_phone': _contactPhoneController.text.trim(),
        'website': _websiteController.text.trim(),
        'address': _addressController.text.trim(),
        'social_media': _socialMediaController.text.trim(),
        'business_hours': _businessHoursController.text.trim(),
        'currency': _currencyController.text.trim(),
        'timezone': _timezoneController.text.trim(),
        'language': _languageController.text.trim(),
        'theme': _selectedTheme,
        'primary_color': _primaryColor,
        'secondary_color': _secondaryColor,
        'accent_color': _accentColor,
        'branding_enabled': _brandingEnabled,
      };
      
      final success = await brandingProvider.updateBusinessBranding(widget.businessId, brandingData);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business branding saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save business branding'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.blue;
    }
  }

  Widget _buildColorPicker(String label, String currentColor, Function(String) onColorChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showColorPickerDialog(currentColor, onColorChanged),
          child: Container(
            width: 60,
            height: 40,
            decoration: BoxDecoration(
              color: _hexToColor(currentColor),
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.color_lens, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  void _showColorPickerDialog(String currentColor, Function(String) onColorChanged) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Color'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: _buildColorPickerContent(currentColor, onColorChanged),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPickerContent(String currentColor, Function(String) onColorChanged) {
    final predefinedColors = [
      '#1976D2', '#2196F3', '#03A9F4', '#00BCD4', '#009688',
      '#4CAF50', '#8BC34A', '#CDDC39', '#FFEB3B', '#FFC107',
      '#FF9800', '#FF5722', '#795548', '#9E9E9E', '#607D8B',
      '#E91E63', '#9C27B0', '#673AB7', '#3F51B5', '#303F9F',
    ];

    return Column(
      children: [
        // Current color display
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: _hexToColor(currentColor),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: Text(
              currentColor.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Predefined colors
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: predefinedColors.length,
            itemBuilder: (context, index) {
              final color = predefinedColors[index];
              final isSelected = color == currentColor;
              
              return GestureDetector(
                onTap: () {
                  onColorChanged(color);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: _hexToColor(color),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImageUpload(String type, String label, String? currentImageUrl) {
    final hasFile = type == 'logo' ? (_logoFile != null || _logoBytes != null) : (_faviconFile != null || _faviconBytes != null);
    final size = type == 'logo' ? 80.0 : 40.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            // Image preview
            if (currentImageUrl != null || hasFile)
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: hasFile
                      ? kIsWeb
                          ? Image.memory(
                              type == 'logo' ? _logoBytes! : _faviconBytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading memory image: $error');
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(Icons.image, size: size * 0.5, color: Colors.grey),
                                );
                              },
                            )
                          : Image.file(
                              type == 'logo' ? _logoFile! : _faviconFile!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading file image: $error');
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(Icons.image, size: size * 0.5, color: Colors.grey),
                                );
                              },
                            )
                      : currentImageUrl != null && currentImageUrl.isNotEmpty
                          ? Image.network(
                              'https://rtailed-production.up.railway.app$currentImageUrl',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading network image: $error');
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(Icons.image, size: size * 0.5, color: Colors.grey),
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: Icon(Icons.image, size: size * 0.5, color: Colors.grey),
                            ),
                ),
              ),
            
            const SizedBox(width: 16),
            
            // Upload buttons
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : () => _pickImage(type),
                    icon: const Icon(Icons.upload, size: 18),
                    label: Text('Upload ${type.toUpperCase()}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  
                  if (hasFile) ...[
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isUploading ? null : () => _uploadFile(type),
                      icon: _isUploading 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save, size: 18),
                      label: Text(_isUploading ? 'Uploading...' : 'Save ${type.toUpperCase()}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BrandedAppBar(
        title: 'Business Branding',
        showBackButton: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<BrandingProvider>(
              builder: (context, brandingProvider, child) {
                if (!_isInitialized) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _hexToColor(_primaryColor),
                                _hexToColor(_secondaryColor),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.business,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Business Branding',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Customize the branding for this specific business',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Branding Toggle
                        _buildSection(
                          title: 'Branding Status',
                          icon: Icons.toggle_on,
                          children: [
                            SwitchListTile(
                              title: const Text('Enable Business Branding'),
                              subtitle: const Text('Show custom branding for this business'),
                              value: _brandingEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _brandingEnabled = value;
                                });
                              },
                              activeColor: _hexToColor(_primaryColor),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Business Identity Section
                        _buildSection(
                          title: 'Business Identity',
                          icon: Icons.business,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildImageUpload(
                                    'logo',
                                    'Business Logo',
                                    brandingProvider.getCurrentBusinessLogo(widget.businessId),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _buildImageUpload(
                                    'favicon',
                                    'Favicon',
                                    brandingProvider.getCurrentBusinessFavicon(widget.businessId),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Business Information Section
                        _buildSection(
                          title: 'Business Information',
                          icon: Icons.info,
                          children: [
                            TextFormField(
                              controller: _businessNameController,
                              decoration: const InputDecoration(
                                labelText: 'Business Name *',
                                hintText: 'Enter business name',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.business),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Business name is required';
                                }
                                return null;
                              },
                            ),
                            
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _taglineController,
                              decoration: const InputDecoration(
                                labelText: 'Tagline',
                                hintText: 'Enter business tagline',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.tag),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _contactEmailController,
                                    decoration: const InputDecoration(
                                      labelText: 'Contact Email',
                                      hintText: 'contact@business.com',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.email),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _contactPhoneController,
                                    decoration: const InputDecoration(
                                      labelText: 'Contact Phone',
                                      hintText: '+1 234 567 8900',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.phone),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _websiteController,
                              decoration: const InputDecoration(
                                labelText: 'Website',
                                hintText: 'https://business.com',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.language),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'Address',
                                hintText: 'Business address',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.location_on),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Additional Settings Section
                        _buildSection(
                          title: 'Additional Settings',
                          icon: Icons.settings,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _currencyController,
                                    decoration: const InputDecoration(
                                      labelText: 'Currency',
                                      hintText: 'USD',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.attach_money),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _timezoneController,
                                    decoration: const InputDecoration(
                                      labelText: 'Timezone',
                                      hintText: 'UTC',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.access_time),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _languageController,
                                    decoration: const InputDecoration(
                                      labelText: 'Language',
                                      hintText: 'en',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.language),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _socialMediaController,
                                    decoration: const InputDecoration(
                                      labelText: 'Social Media',
                                      hintText: '@business',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.share),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _businessHoursController,
                              decoration: const InputDecoration(
                                labelText: 'Business Hours',
                                hintText: 'Mon-Fri 9AM-6PM',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.schedule),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Theme & Colors Section
                        _buildSection(
                          title: 'Theme & Colors',
                          icon: Icons.palette,
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedTheme,
                              decoration: const InputDecoration(
                                labelText: 'Theme',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.style),
                              ),
                              items: brandingProvider.themes.map<DropdownMenuItem<String>>((theme) {
                                return DropdownMenuItem<String>(
                                  value: theme['theme_name'] as String,
                                  child: Text(theme['theme_display_name'] as String),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedTheme = value;
                                  });
                                }
                              },
                            ),
                            
                            const SizedBox(height: 24),
                            
                            Text(
                              'Color Scheme',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: _buildColorPicker('Primary Color', _primaryColor, (color) {
                                    setState(() {
                                      _primaryColor = color;
                                    });
                                  }),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _buildColorPicker('Secondary Color', _secondaryColor, (color) {
                                    setState(() {
                                      _secondaryColor = color;
                                    });
                                  }),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _buildColorPicker('Accent Color', _accentColor, (color) {
                                    setState(() {
                                      _accentColor = color;
                                    });
                                  }),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _saveBranding,
                            icon: _isLoading 
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.save),
                            label: Text(_isLoading ? 'Saving...' : 'Save Business Branding'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _hexToColor(_primaryColor),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _hexToColor(_primaryColor), size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
} 