import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/widgets/responsive_frame.dart';

class BrunchyVendorApp extends StatelessWidget {
  const BrunchyVendorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Brunchy Vendor',
      theme: AppTheme.light,
      routerConfig: buildRouter(),
      debugShowCheckedModeBanner: false,
      // Fits every page to the device (text size, centred column on wide screens) and keeps mint behind
      // every page, so the cross-fade between pages never shows black.
      builder: (context, child) => ResponsiveFrame(child: child ?? const SizedBox.shrink()),
    );
  }
}

