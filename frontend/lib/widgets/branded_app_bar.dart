import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retail_management/providers/branding_provider.dart';
import 'package:retail_management/providers/auth_provider.dart';

class BrandedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final Widget? leading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  final bool centerTitle;
  final bool showBackButton;
  final PreferredSizeWidget? bottom;

  const BrandedAppBar({
    super.key,
    this.title = '',
    this.actions,
    this.automaticallyImplyLeading = true,
    this.leading,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 4,
    this.centerTitle = true,
    this.showBackButton = false,
    this.bottom,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Consumer2<BrandingProvider, AuthProvider>(
      builder: (context, brandingProvider, authProvider, child) {
        final businessId = authProvider.user?.businessId;
        final currentBranding = brandingProvider.getCurrentBranding(businessId);
        final logoUrl = brandingProvider.getCurrentLogo(businessId);
        final appName = brandingProvider.getCurrentAppName(businessId);
        final primaryColor = brandingProvider.getPrimaryColor(businessId);

        return AppBar(
          title: Row(
            children: [
              // Logo
              if (logoUrl != null)
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      'http://localhost:3000$logoUrl',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.business,
                          color: primaryColor,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              
              // App Name and Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      appName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: backgroundColor ?? primaryColor,
          foregroundColor: foregroundColor ?? Colors.white,
          elevation: elevation,
          centerTitle: centerTitle,
          automaticallyImplyLeading: showBackButton ? true : automaticallyImplyLeading,
          leading: showBackButton ? IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ) : leading,
          actions: actions,
          bottom: bottom,
        );
      },
    );
  }
}

// Branded App Bar with Logo Only
class BrandedLogoAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final Widget? leading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  final double logoSize;

  const BrandedLogoAppBar({
    super.key,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.leading,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 4,
    this.logoSize = 40,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Consumer2<BrandingProvider, AuthProvider>(
      builder: (context, brandingProvider, authProvider, child) {
        final businessId = authProvider.user?.businessId;
        final logoUrl = brandingProvider.getCurrentLogo(businessId);
        final primaryColor = brandingProvider.getPrimaryColor(businessId);

        return AppBar(
          title: logoUrl != null
              ? Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      'http://localhost:3000$logoUrl',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.business,
                          color: primaryColor,
                          size: logoSize * 0.6,
                        ),
                      ),
                    ),
                  ),
                )
              : Icon(
                  Icons.business,
                  color: Colors.white,
                  size: logoSize * 0.6,
                ),
          backgroundColor: backgroundColor ?? primaryColor,
          foregroundColor: foregroundColor ?? Colors.white,
          elevation: elevation,
          centerTitle: true,
          automaticallyImplyLeading: automaticallyImplyLeading,
          leading: leading,
          actions: actions,
        );
      },
    );
  }
}

// Branded App Bar with Custom Title
class BrandedTitleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final Widget? leading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  final bool showLogo;
  final double logoSize;

  const BrandedTitleAppBar({
    super.key,
    required this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.leading,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 4,
    this.showLogo = true,
    this.logoSize = 32,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Consumer2<BrandingProvider, AuthProvider>(
      builder: (context, brandingProvider, authProvider, child) {
        final businessId = authProvider.user?.businessId;
        final logoUrl = brandingProvider.getCurrentLogo(businessId);
        final primaryColor = brandingProvider.getPrimaryColor(businessId);

        return AppBar(
          title: Row(
            children: [
              if (showLogo && logoUrl != null) ...[
                Container(
                  width: logoSize,
                  height: logoSize,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      'http://localhost:3000$logoUrl',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.business,
                          color: primaryColor,
                          size: logoSize * 0.6,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: backgroundColor ?? primaryColor,
          foregroundColor: foregroundColor ?? Colors.white,
          elevation: elevation,
          centerTitle: false,
          automaticallyImplyLeading: automaticallyImplyLeading,
          leading: leading,
          actions: actions,
        );
      },
    );
  }
} 