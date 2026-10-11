import 'package:flutter/material.dart';

import '../theme/colors.dart';

enum LogoVariant { mark, horizontal, vertical, dark }

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.variant = LogoVariant.mark,
    this.height = AppSpacing.logoAppBar,
    this.hero = true,
  });

  final LogoVariant variant;
  final double height;
  final bool hero;

  static const String heroTag = 'skytrace-logo';

  String get _asset {
    switch (variant) {
      case LogoVariant.mark:
        return 'assets/logo/logomark.png';
      case LogoVariant.horizontal:
        return 'assets/logo/logo_horizontal.png';
      case LogoVariant.vertical:
        return 'assets/logo/logo_vertical.png';
      case LogoVariant.dark:
        return 'assets/logo/logo_dark.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      _asset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'SkyTrace',
    );
    if (!hero) return image;
    return Hero(tag: heroTag, child: image);
  }
}
