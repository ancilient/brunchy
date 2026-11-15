import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
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
  // Same animation as the student app, on the vendor's teal disc (assets/splash, built by
  // student_app/tool/splash): the disc pops, the burger builds itself, takes a bite, "Brunchy" rises in.
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  late final _tags = CurvedAnimation(parent: _ctrl, curve: const Interval(0.6, 0.82, curve: Curves.easeOutCubic));
  bool _done = false;
  Timer? _fallback;

  @override
  void initState() {
    super.initState();
    _ctrl.addStatusListener((st) {
      if (st == AnimationStatus.completed) _finish(const Duration(milliseconds: 300));
    });
    // If the animation cannot load for any reason, never block the app.
    _fallback = Timer(const Duration(seconds: 8), () => _finish(Duration.zero));
  }

  /// Starts the animation only once its first frame is on screen and the app has finished starting up,
  /// so the opening (disc pop, burger build) is not played while nothing is being drawn yet.
  Future<void> _play(Duration duration) async {
    _ctrl.duration = duration;
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    _fallback?.cancel();
    _fallback = Timer(duration + const Duration(seconds: 3), () => _finish(Duration.zero));
    _ctrl.forward();
  }

  void _finish(Duration hold) {
    _fallback?.cancel();
    Future.delayed(hold, () {
      if (!mounted || _done) return;
      _done = true;
      _navigate();
    });
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
  void dispose() {
    _fallback?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Widget _rise(Widget child) => AnimatedBuilder(
        animation: _tags,
        builder: (_, c) => Opacity(opacity: _tags.value, child: Transform.translate(offset: Offset(0, 14 * (1 - _tags.value)), child: c)),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logo = (size.shortestSide * 0.9).clamp(240.0, 460.0);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Lottie.asset(
              'assets/splash/brunchy_vendor_splash.json',
              controller: _ctrl,
              width: logo,
              height: logo,
              onLoaded: (comp) => _play(comp.duration),
              errorBuilder: (_, __, ___) {
                _finish(const Duration(milliseconds: 600));
                return const SizedBox.shrink();
              },
            ),
            // "VENDOR" tag just under the disc (the canvas has empty space below the disc).
            Transform.translate(
              offset: Offset(0, -logo * 0.1),
              child: _rise(Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(99)),
                child: Text('VENDOR',
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 3, color: Colors.white)),
              )),
            ),
          ]),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.of(context).padding.bottom + 28,
          child: _rise(Text.rich(
            TextSpan(children: [
              TextSpan(text: 'A product of ', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              TextSpan(
                  text: 'ANCILIENT',
                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.4, color: AppColors.ink)),
            ]),
            textAlign: TextAlign.center,
          )),
        ),
      ]),
    );
  }
}
