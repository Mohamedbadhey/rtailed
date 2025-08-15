import 'package:flutter/material.dart';
import 'package:retail_management/utils/responsive_utils.dart';

class LocalLogo extends StatelessWidget {
  final double size;
  final BoxDecoration? decoration;
  final BoxFit fit;

  const LocalLogo({
    super.key,
    this.size = 40,
    this.decoration,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final responsiveSize = ResponsiveUtils.getResponsiveLogoSize(context);
    final finalSize = size > 0 ? size : responsiveSize;

    return Container(
      width: finalSize,
      height: finalSize,
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
        child: Image.asset(
          'assets/images/logo.png', // This will be the local logo
          fit: fit,
          errorBuilder: (context, error, stackTrace) => Container(
            padding: EdgeInsets.all(finalSize * 0.2),
            child: Icon(
              Icons.business,
              color: Theme.of(context).primaryColor,
              size: finalSize * 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

class LocalLogoWithFallback extends StatelessWidget {
  final double size;
  final BoxDecoration? decoration;
  final BoxFit fit;
  final String? fallbackUrl;
  final Color? fallbackColor;

  const LocalLogoWithFallback({
    super.key,
    this.size = 40,
    this.decoration,
    this.fit = BoxFit.contain,
    this.fallbackUrl,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final responsiveSize = ResponsiveUtils.getResponsiveLogoSize(context);
    final finalSize = size > 0 ? size : responsiveSize;

    return Container(
      width: finalSize,
      height: finalSize,
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
        child: _buildLogo(finalSize, context),
      ),
    );
  }

  Widget _buildLogo(double size, BuildContext context) {
    // Try local asset first
    try {
      return Image.asset(
        'assets/images/logo.png',
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          // If local asset fails, try fallback URL
          if (fallbackUrl != null) {
            return Image.network(
              fallbackUrl!,
              fit: fit,
              errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(size, context),
            );
          }
          return _buildFallbackIcon(size, context);
        },
      );
    } catch (e) {
      // If local asset fails, try fallback URL
      if (fallbackUrl != null) {
        return Image.network(
          fallbackUrl!,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(size, context),
        );
      }
      return _buildFallbackIcon(size, context);
    }
  }

  Widget _buildFallbackIcon(double size, BuildContext context) {
    return Container(
      padding: EdgeInsets.all(size * 0.2),
      child: Icon(
        Icons.business,
        color: fallbackColor ?? Theme.of(context).primaryColor,
        size: size * 0.6,
      ),
    );
  }
}
