// SplashLogo.tsx and Header.tsx
import 'dart:async';

import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';

class SplashLogo extends StatefulWidget {
  const SplashLogo({super.key, required this.onFinish});
  final VoidCallback onFinish;
  @override
  State<SplashLogo> createState() => _SplashLogoState();
}

class _SplashLogoState extends State<SplashLogo> {
  bool _fading = false;
  bool _shown = false;
  Timer? _fade, _close;

  @override
  void initState() {
    super.initState();
    // 1-second animation per PDF
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _shown = true); });
    _fade = Timer(const Duration(milliseconds: 1100), () { if (mounted) setState(() => _fading = true); });
    _close = Timer(const Duration(milliseconds: 1400), () => widget.onFinish());
  }

  @override
  void dispose() {
    _fade?.cancel();
    _close?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: _fading,
      child: AnimatedOpacity(
        opacity: _fading ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          color: C.cream,
          alignment: Alignment.center,
          child: AnimatedScale(
            scale: _shown ? 1.0 : 0.95,
            duration: const Duration(milliseconds: 500),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 96 + 6,
                height: 96 + 6,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(
                    left: 0, bottom: 0,
                    child: Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        gradient: C.brandGradientDiag,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: C.a(C.orange500, 0.4), blurRadius: 50, offset: const Offset(0, 25), spreadRadius: -12)],
                      ),
                      child: const Center(child: LIcon('UtensilsCrossed', size: 48, color: Colors.white, strokeWidth: 2.5)),
                    ),
                  ),
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(color: C.amber300, shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: C.a(Colors.black, 0.1), blurRadius: 6, offset: const Offset(0, 4))]),
                      child: const Center(child: LIcon('Sparkles', size: 14, color: C.amber900)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              txt('Brunchy', 36, w: w8, font: F.display, spacing: -0.9),
              const SizedBox(height: 4),
              txt('CAMPUS FOOD ORDERING', 12, w: w6, color: C.brand, spacing: 1.2),
              const SizedBox(height: 24),
              Container(width: 40, height: 4, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFB923C), Color(0xFFFBBF24)]), borderRadius: BorderRadius.circular(4))),
            ]),
          ),
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
              logoTile(36, 16, const LIcon('UtensilsCrossed', size: 20, color: Colors.white, strokeWidth: 2.5)),
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
