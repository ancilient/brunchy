// The Brunchy Vendor logo (the real burger logo on the teal disc, assets/brand/logo.png) and a small lockup.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Round logo with a soft teal shadow.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 64, this.shadow = true});
  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: shadow
            ? [BoxShadow(color: AppColors.brandTeal.withValues(alpha: 0.35), blurRadius: size * 0.28, offset: Offset(0, size * 0.1))]
            : null,
      ),
      child: Image.asset('assets/brand/logo.png', width: size, height: size, filterQuality: FilterQuality.medium),
    );
  }
}

/// Logo + "Brunchy / VENDOR" side by side, for app bars and footers.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.height = 32});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      BrandLogo(size: height, shadow: false),
      SizedBox(width: height * 0.3),
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Brunchy', style: GoogleFonts.nunito(fontSize: height * 0.5, height: 1.05, fontWeight: FontWeight.w800, color: AppColors.ink)),
        Text('VENDOR',
            style: GoogleFonts.nunito(fontSize: height * 0.28, height: 1.1, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: AppColors.primary)),
      ]),
    ]);
  }
}
