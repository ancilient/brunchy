import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

class BrunchyVendorApp extends StatelessWidget {
  const BrunchyVendorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Brunchy Vendor',
      theme: AppTheme.light,
      routerConfig: buildRouter(),
      debugShowCheckedModeBanner: false,
    );
  }
}

