// Same effect as the student app's counter (student_app/lib/ui/theme.dart, RollingNumber).
import 'package:flutter/material.dart';

/// A number whose digits roll like a suitcase lock: counting up, the new digit drops in from the top;
/// counting down, it rolls up from below. Only the digits that change move.
class RollingNumber extends StatefulWidget {
  const RollingNumber(this.value, {super.key, required this.style});
  final int value;
  final TextStyle? style;
  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber> {
  bool _up = true;

  @override
  void didUpdateWidget(RollingNumber old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) _up = widget.value > old.value;
  }

  @override
  Widget build(BuildContext context) {
    final digits = '${widget.value}'.split('');
    final dir = _up ? 1.0 : -1.0;
    return ClipRect(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // Keyed from the right, so the ones digit stays the same switcher when the number gains a digit.
        for (var i = 0; i < digits.length; i++)
          AnimatedSwitcher(
            key: ValueKey(digits.length - i),
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) {
              final incoming = child.key == ValueKey(digits[i]);
              // The outgoing digit plays this in reverse, so it leaves in the same direction the new one arrives.
              final from = Offset(0, incoming ? -dir : dir);
              return SlideTransition(position: Tween(begin: from, end: Offset.zero).animate(anim), child: child);
            },
            layoutBuilder: (current, previous) => Stack(alignment: Alignment.center, children: [...previous, if (current != null) current]),
            child: Text(digits[i], key: ValueKey(digits[i]), style: widget.style),
          ),
      ]),
    );
  }
}
