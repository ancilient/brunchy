// Fits every page to the device, for the whole app at once (used in MaterialApp.builder):
//  * Text scales with the phone's width: a little smaller on small/regular phones, full size from large phones up.
//    The user's own font-size setting still applies, but is capped so it cannot break layouts.
//  * On tablets and desktop browsers the app is shown as a centred phone-width column, so nothing stretches
//    across a wide window. Dialogs and sheets open inside that column too.
import 'package:flutter/material.dart';
import 'theme.dart';

class ResponsiveFrame extends StatelessWidget {
  const ResponsiveFrame({super.key, required this.child});
  final Widget child;

  static const double maxAppWidth = 480;   // widest the app column gets on tablets / desktop
  static const double _referenceWidth = 440; // phones this wide (and wider) get full-size text

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final deviceScale = (mq.size.shortestSide / _referenceWidth).clamp(0.86, 1.0);
    final userScale = mq.textScaler.scale(1).clamp(0.9, 1.25);
    final textScaler = TextScaler.linear(deviceScale * userScale);

    if (mq.size.width <= maxAppWidth + 48) {
      return ColoredBox(
        color: C.page,
        child: MediaQuery(data: mq.copyWith(textScaler: textScaler), child: child),
      );
    }

    // Wide screen: a centred column. Pages see the column's width as the screen width.
    return ColoredBox(
      color: C.slate100,
      child: Center(
        child: Container(
          width: maxAppWidth,
          decoration: BoxDecoration(
            color: C.page,
            boxShadow: [BoxShadow(color: C.a(Colors.black, 0.12), blurRadius: 40)],
          ),
          child: ClipRect(
            child: MediaQuery(
              data: mq.copyWith(textScaler: textScaler, size: Size(maxAppWidth, mq.size.height)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
