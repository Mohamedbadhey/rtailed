import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/utils/theme.dart';
import 'package:retail_management/utils/responsive_utils.dart';
import 'package:retail_management/widgets/custom_text_field.dart';
import 'package:retail_management/widgets/local_logo.dart';
import 'package:retail_management/utils/success_utils.dart';

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
  late AnimationController _scaleController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 100.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _animationController.forward();
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
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
        SuccessUtils.showOperationError(context, 'login', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryGradientStart.withOpacity(0.1),
                  primaryGradientEnd.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryGradientStart.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.phone_in_talk,
                    size: 48,
                    color: primaryGradientStart,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Title
                Text(
                  'Forgot Password?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                // Message
                Text(
                  'Please contact our support team to reset your password.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Company Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryGradientStart.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.business,
                            color: primaryGradientStart,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Kismayo ICT Solutions',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            color: primaryGradientStart,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '0614112537',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: primaryGradientStart,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGradientStart,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;
    final isTablet = size.width >= 768 && size.width < 1200;
    final isDesktop = size.width >= 1200;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryGradientStart.withOpacity(0.08),
              primaryGradientEnd.withOpacity(0.04),
              backgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : (isTablet ? 40 : 60),
              vertical: isMobile ? 20 : (isTablet ? 40 : 60),
            ),
            child: Column(
              children: [
                                SizedBox(height: isMobile ? 20 : (isTablet ? 30 : 40)),
                
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
                          // Logo Container with enhanced shadow
                          Container(
                            padding: EdgeInsets.all(isMobile ? 12 : (isTablet ? 16 : 20)),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor, secondaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.3),
                                  blurRadius: isMobile ? 20 : 30,
                                  offset: const Offset(0, 8),
                                  spreadRadius: 2,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: isMobile ? 10 : 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: LocalLogo(
                              size: isMobile ? 60 : (isTablet ? 80 : 100),
                            ),
                          ),
                          SizedBox(height: isMobile ? 12 : (isTablet ? 16 : 20)),
                          
                          // App Name with enhanced gradient
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [primaryColor, secondaryColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              appName,
                              style: TextStyle(
                                fontSize: isMobile ? 24 : (isTablet ? 28 : 32),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: isMobile ? 6 : 8),
                          
                          // Subtitle
                          Text(
                            'Sign in to your account',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                
                SizedBox(height: isMobile ? 20 : (isTablet ? 30 : 40)),
                
                // Login Form with enhanced animations
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeOutBack,
                  )),
                                    child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: isMobile 
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: primaryGradientStart.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 5),
                                spreadRadius: 0,
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
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
                                  prefixIcon: Icon(
                                    Icons.person_outlined,
                                    color: primaryGradientStart.withOpacity(0.7),
                                  ),
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
                          
                                                                const SizedBox(height: 16),
                                
                                // Password Field
                                CustomTextField(
                                  controller: _passwordController,
                                  labelText: 'Password',
                                  hintText: 'Enter your password',
                                  prefixIcon: Icon(
                                    Icons.lock_outlined,
                                    color: primaryGradientStart.withOpacity(0.7),
                                  ),
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
                                
                                const SizedBox(height: 16),
                                
                                // Remember Me & Forgot Password - Mobile layout
                                Column(
                                  children: [
                                    Row(
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
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                        Text(
                                          'Remember me',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: _showForgotPasswordDialog,
                                      child: Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          color: primaryGradientStart,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Login Button with enhanced styling
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [primaryGradientStart, primaryGradientEnd],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryGradientStart.withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: const Offset(0, 6),
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : Text(
                                            'Sign In',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                              letterSpacing: 0.5,
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Center(
                      child: Container(
                        width: isTablet ? 500 : 600,
                                                 padding: EdgeInsets.all(isTablet ? 24 : 32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: primaryGradientStart.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 5),
                              spreadRadius: 0,
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
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
                                prefixIcon: Icon(
                                  Icons.person_outlined,
                                  color: primaryGradientStart.withOpacity(0.7),
                                ),
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
                                prefixIcon: Icon(
                                  Icons.lock_outlined,
                                  color: primaryGradientStart.withOpacity(0.7),
                                ),
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
                              
                              // Remember Me & Forgot Password - Horizontal layout
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
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                        Text(
                                          'Remember me',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _showForgotPasswordDialog,
                                    child: Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: primaryGradientStart,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 32),
                              
                              // Login Button with enhanced styling
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [primaryGradientStart, primaryGradientEnd],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryGradientStart.withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 6),
                                      spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 22),
                                shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                          height: 24,
                                          width: 24,
                                      child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      'Sign In',
                                          style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                            fontSize: 19,
                                            letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: isMobile ? 24 : 32),
                
                // Enhanced Footer
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Text(
                    '© 2024 Retail Management System',
                        style: TextStyle(
                      color: textSecondary.withOpacity(0.7),
                          fontSize: isMobile ? 12 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Powered by Kismayo ICT Solutions',
                        style: TextStyle(
                          color: primaryGradientStart.withOpacity(0.8),
                          fontSize: isMobile ? 11 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Contact: 0614112537',
                        style: TextStyle(
                          color: textSecondary.withOpacity(0.6),
                          fontSize: isMobile ? 10 : 12,
                          fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                      ),
                    ],
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