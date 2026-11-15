// SplashLogo.tsx and Header.tsx
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../state/app_scope.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';

class SplashLogo extends StatefulWidget {
  const SplashLogo({super.key, required this.onFinish});
  final VoidCallback onFinish;
  @override
  State<SplashLogo> createState() => _SplashLogoState();
}

class _SplashLogoState extends State<SplashLogo> with SingleTickerProviderStateMixin {
  // Brunchy logo animation (assets/splash, built from the real logo): disc pops, the burger builds itself,
  // takes a bite, then "Brunchy" rises in. The quote at the bottom fades in with the letters.
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  late final _quote = CurvedAnimation(parent: _c, curve: const Interval(0.6, 0.82, curve: Curves.easeOutCubic));
  bool _fading = false;
  Timer? _fallback;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((st) {
      if (st == AnimationStatus.completed) _finish(const Duration(milliseconds: 250));
    });
    // If the animation cannot load for any reason, never block the app.
    _fallback = Timer(const Duration(seconds: 5), () => _finish(Duration.zero));
  }

  void _finish(Duration hold) {
    _fallback?.cancel();
    Future.delayed(hold, () {
      if (!mounted || _fading) return;
      setState(() => _fading = true);
      Future.delayed(const Duration(milliseconds: 380), () { if (mounted) widget.onFinish(); });
    });
  }

  @override
  void dispose() {
    _fallback?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logo = (size.shortestSide * 0.9).clamp(240.0, 460.0);
    return IgnorePointer(
      ignoring: _fading,
      child: AnimatedOpacity(
        opacity: _fading ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 350),
        child: Container(
          color: C.cream,
          child: Stack(children: [
            Center(
              child: Lottie.asset(
                'assets/splash/brunchy_splash.json',
                controller: _c,
                width: logo,
                height: logo,
                onLoaded: (comp) => _c
                  ..duration = comp.duration
                  ..forward(),
                errorBuilder: (_, __, ___) {
                  _finish(const Duration(milliseconds: 600));
                  return const SizedBox.shrink();
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 28,
              child: AnimatedBuilder(
                animation: _quote,
                builder: (_, child) => Opacity(
                  opacity: _quote.value,
                  child: Transform.translate(offset: Offset(0, 14 * (1 - _quote.value)), child: child),
                ),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'A product of ', style: ts(12, w: w5, color: C.slate500, spacing: 0.3)),
                    TextSpan(text: 'ANCILIENT', style: ts(12, w: w8, color: C.slate800, spacing: 2.4)),
                  ]),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class Header extends StatelessWidget {
  const Header({super.key, required this.onReplaySplash});
  final VoidCallback onReplaySplash;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: C.cream,
        border: Border(bottom: BorderSide(color: C.a(C.amber200, 0.6))),
        boxShadow: [BoxShadow(color: C.a(Colors.black, 0.05), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              // Brand & Subtitle
              brandLogo(40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  txt('Brunchy', 20, w: w8, font: F.display, spacing: -0.5, height: 1),
                  const SizedBox(height: 2),
                  txt('Campus Canteen Ordering', 10, w: w5, color: C.slate500),
                ]),
              ),
              // DEMO CLOCK Speed Multipliers: 1x, 10x, 30x
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: C.a(C.amber200, 0.8))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const LIcon('Clock', size: 12, color: C.brand),
                  const SizedBox(width: 6),
                  for (final m in const [1, 10, 30])
                    Tap(
                      onTap: () => s.setDemoClockMultiplier(m),
                      child: AnimatedScale(
                        scale: s.demoClockMultiplier == m ? 1.05 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          width: 24, height: 24,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(gradient: s.demoClockMultiplier == m ? C.brandGradient : null, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: txt('${m}x', m == 30 || m == 10 ? 10.0 : 11.0, w: w7, font: F.mono, color: s.demoClockMultiplier == m ? Colors.white : C.slate600),
                        ),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 8),
              // Replay Logo Splash button
              Tap(
                onTap: onReplaySplash,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: C.a(C.amber200, 0.8))),
                  child: const LIcon('RotateCcw', size: 14, color: C.slate500),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
