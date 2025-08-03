import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/utils/theme.dart';
import 'package:retail_management/widgets/custom_text_field.dart';
import 'package:retail_management/widgets/branded_header.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  
  late AnimationController _animationController;
  late AnimationController _fadeController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 100.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fadeController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await context.read<AuthProvider>().loginWithIdentifier(
        _identifierController.text,
        _passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryGradientStart.withOpacity(0.1),
              primaryGradientEnd.withOpacity(0.05),
              backgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 60),
                
                // Branded Header Section
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Consumer<BrandingProvider>(
                    builder: (context, brandingProvider, child) {
                      final appName = brandingProvider.getCurrentAppName(null);
                      final primaryColor = brandingProvider.getPrimaryColor(null);
                      final secondaryColor = brandingProvider.getSecondaryColor(null);
                      
                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor, secondaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: BrandedLogo(
                              size: 60,
                              businessId: null,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            appName,
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              background: Paint()
                                ..shader = LinearGradient(
                                  colors: [primaryColor, secondaryColor],
                                ).createShader(
                                  const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                                ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to your account',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: textSecondary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 60),
                
                // Login Form
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeOutBack,
                  )),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: AppStyles.cardDecoration,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Username or Email Field
                          CustomTextField(
                            controller: _identifierController,
                            labelText: 'Username or Email',
                            hintText: 'Enter your username or email',
                            prefixIcon: const Icon(Icons.person_outlined),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your username or email';
                              }
                              if (value.length < 3) {
                                return 'Username or email must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Password Field
                          CustomTextField(
                            controller: _passwordController,
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            obscureText: !_isPasswordVisible,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                color: textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Remember Me & Forgot Password
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      onChanged: (value) {
                                        setState(() {
                                          _rememberMe = value ?? false;
                                        });
                                      },
                                      activeColor: primaryGradientStart,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    Text(
                                      'Remember me',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  // TODO: Implement forgot password
                                },
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: primaryGradientStart,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Login Button
                          Container(
                            decoration: AppStyles.gradientDecoration,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      'Sign In',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          

                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Footer
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    '© 2024 Retail Management System',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: textSecondary.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 