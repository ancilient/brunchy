// Reserved advertisement spaces. Until a real ad is supplied (`child`), each slot shows a clearly labelled template
// with its shape, so the layout can be reviewed and partners know what size to design for.
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme.dart';

enum AdSize { large, medium }

class AdSlot extends StatelessWidget {
  const AdSlot({super.key, required this.size, this.child});
  final AdSize size;
  final Widget? child; // the real ad, when there is one

  @override
  Widget build(BuildContext context) {
    final large = size == AdSize.large;
    return AspectRatio(
      aspectRatio: large ? 16 / 7 : 1,
      child: child != null
          ? ClipRRect(borderRadius: BorderRadius.circular(20), child: child)
          : CustomPaint(
              foregroundPainter: _DashedBorder(radius: 20, color: C.a(C.amber500, 0.45)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFFFF8EE)]),
                ),
                child: Stack(children: [
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: C.a(C.amber100, 0.8), borderRadius: BorderRadius.circular(6)),
                      child: txt(large ? 'AD · 16:7' : 'AD · 1:1', 8, w: w8, color: C.amber800, spacing: 0.6),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: large ? 40 : 34, height: large ? 40 : 34,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [C.orange100, C.amber100]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: LIcon('Sparkles', size: large ? 18 : 16, color: C.brand, strokeWidth: 2.2),
                        ),
                        SizedBox(height: large ? 10 : 8),
                        txt(large ? 'Featured ad space' : 'Ad space', large ? 13 : 12, w: w7, color: C.slate700, align: TextAlign.center),
                        const SizedBox(height: 2),
                        txt(large ? 'Large banner · reaches students at checkout' : 'Medium square', 10, color: C.slate400, align: TextAlign.center, maxLines: 2),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }
}

/// A large rectangle on top and two medium squares under it, under a small "Sponsored" label.
class AdShowcase extends StatelessWidget {
  const AdShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Row(children: [
          txt('SPONSORED', 10, w: w8, color: C.slate400, spacing: 1.4),
          const SizedBox(width: 6),
          Expanded(child: Divider(height: 1, thickness: 1, color: C.a(C.amber200, 0.6))),
        ]),
      ),
      const AdSlot(size: AdSize.large),
      const SizedBox(height: 10),
      const Row(children: [
        Expanded(child: AdSlot(size: AdSize.medium)),
        SizedBox(width: 10),
        Expanded(child: AdSlot(size: AdSize.medium)),
      ]),
    ]);
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.radius, required this.color});
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(0.75), Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final PathMetric m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius;
}
