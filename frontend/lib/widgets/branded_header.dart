import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/providers/auth_provider.dart';
import 'package:retail_management/widgets/local_logo.dart';

class BrandedHeader extends StatelessWidget {
  final String? subtitle;
  final List<Widget>? actions;
  final bool showLogo;
  final bool showAppName;
  final double logoSize;
  final EdgeInsets? padding;

  const BrandedHeader({
    super.key,
    this.subtitle,
    this.actions,
    this.showLogo = true,
    this.showAppName = true,
    this.logoSize = 60,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<BrandingProvider, AuthProvider>(
      builder: (context, brandingProvider, authProvider, child) {
        final businessId = authProvider.user?.businessId;
        final logoUrl = brandingProvider.getCurrentLogo(businessId);
        final appName = brandingProvider.getCurrentAppName(businessId);
        final primaryColor = brandingProvider.getPrimaryColor(businessId);
        final secondaryColor = brandingProvider.getSecondaryColor(businessId);

        return Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor,
                secondaryColor,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              
              if (isMobile) {
                // Mobile layout - stacked vertically
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (showLogo) ...[
                          // Logo
                          Container(
                            width: logoSize,
                            height: logoSize,
                            margin: const EdgeInsets.only(right: 16),
                            child: logoUrl != null
                                ? Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        'https://rtailed-production.up.railway.app$logoUrl',
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) => LocalLogo(
                                          size: logoSize,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            color: Colors.white,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            color: Colors.white,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress.expectedTotalBytes != null
                                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                    : null,
                                                color: primaryColor,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  )
                                : LocalLogo(
                                    size: logoSize,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                        
                        // App Name
                        if (showAppName) ...[
                          Expanded(
                            child: Text(
                              appName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    // Subtitle and Actions in mobile
                    if (subtitle != null || actions != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (subtitle != null) ...[
                            Expanded(
                              child: Text(
                                subtitle!,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                          if (actions != null) ...[
                            ...actions!,
                          ],
                        ],
                      ),
                    ],
                  ],
                );
              } else {
                // Desktop layout - horizontal
                return Row(
                  children: [
                    if (showLogo) ...[
                      // Logo
                      Container(
                        width: logoSize,
                        height: logoSize,
                        margin: const EdgeInsets.only(right: 16),
                        child: logoUrl != null
                            ? Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    'https://rtailed-production.up.railway.app$logoUrl',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => LocalLogo(
                                      size: logoSize,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: Colors.white,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                : null,
                                            color: primaryColor,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              )
                            : LocalLogo(
                                size: logoSize,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                    
                    // App Name and Subtitle
                    if (showAppName) ...[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle!,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 16,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    
                    // Actions
                    if (actions != null) ...[
                      ...actions!,
                    ],
                  ],
                );
              }
            },
          ),
        );
      },
    );
  }
}

class BrandedLogo extends StatelessWidget {
  final double size;
  final int? businessId;
  final BoxDecoration? decoration;

  const BrandedLogo({
    super.key,
    this.size = 40,
    this.businessId,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<BrandingProvider>(
      builder: (context, brandingProvider, child) {
        final logoUrl = brandingProvider.getCurrentLogo(businessId);
        final primaryColor = brandingProvider.getPrimaryColor(businessId);

        print('BrandedLogo - businessId: $businessId, logoUrl: $logoUrl');

        // If we have a logo URL, try to load it, otherwise use local logo
        if (logoUrl != null) {
          return Container(
            width: size,
            height: size,
            decoration: decoration ?? BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
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
              child: Image.network(
                'https://rtailed-production.up.railway.app$logoUrl',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => LocalLogo(
                  size: size,
                  decoration: decoration,
                ),
              ),
            ),
          );
        } else {
          // Use local logo as fallback
          return LocalLogo(
            size: size,
            decoration: decoration,
          );
        }
      },
    );
  }
}

class BrandedAppName extends StatelessWidget {
  final TextStyle? style;
  final int? businessId;

  const BrandedAppName({
    super.key,
    this.style,
    this.businessId,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<BrandingProvider>(
      builder: (context, brandingProvider, child) {
        final appName = brandingProvider.getCurrentAppName(businessId);

        return Text(
          appName,
          style: style ?? const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }
} 