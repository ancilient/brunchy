import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/repositories/auth_repository.dart';
import '../../injection_container.dart';
import '../../services/local_storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_ctrl);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 1500), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final storage = sl<LocalStorageService>();

    // Validate stored state before routing
    if (storage.isStoredStateCorrupt()) {
      storage.clearAll();
      context.go('/login');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session reset due to data error')),
      );
      return;
    }

    // Not logged in, or a session the server never issued (e.g. left over from the offline demo): log in again.
    if (!storage.isLoggedIn || !sl<AuthRepository>().validateStoredState()) {
      await storage.clearSession();
      if (!mounted) return;
      context.go('/login');
      return;
    }

    final stallId = storage.getStallId(DateFormatter.todayKey());
    if (stallId != null && stallId.isNotEmpty) {
      context.go('/home/orders');
    } else {
      context.go('/choose-stall');
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.vendorTeal,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Image.asset('assets/branding/brunchy_vendor_badge_transparent.png', width: 220),
            ),
          ),
        ),
      ),
    );
  }
}

