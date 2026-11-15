// Page transitions, the same feel as the student app: a shared-axis slide. The new page slides in and fades in
// while the old one slides away and fades out; going back (or to an earlier tab) runs the other way.
// Only opacity and a translation change, on layers that are already painted, so it stays smooth.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _shift = 0.14; // fraction of the width a page travels
const _duration = Duration(milliseconds: 380);

/// For full-screen routes: `pageBuilder: (_, state) => sharedAxisPage(state, const LoginScreen())`.
CustomTransitionPage<void> sharedAxisPage(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: _duration,
      reverseTransitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (context, animation, secondary, child) {
        final enter = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        final cover = CurvedAnimation(parent: secondary, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return SlideTransition(
          position: Tween(begin: const Offset(_shift, 0), end: Offset.zero).animate(enter),
          child: FadeTransition(
            opacity: enter,
            // When another page comes in on top, this one slides away to the left and fades.
            child: SlideTransition(
              position: Tween(begin: Offset.zero, end: const Offset(-_shift, 0)).animate(cover),
              child: FadeTransition(opacity: Tween(begin: 1.0, end: 0.0).animate(cover), child: child),
            ),
          ),
        );
      },
    );

/// For the bottom-tab shell (`StatefulShellRoute.navigatorContainerBuilder`): every tab stays alive (keeps its
/// scroll position and state) and switching slides in the direction of the tab order.
class AnimatedBranchContainer extends StatefulWidget {
  const AnimatedBranchContainer({super.key, required this.currentIndex, required this.children});
  final int currentIndex;
  final List<Widget> children;
  @override
  State<AnimatedBranchContainer> createState() => _AnimatedBranchContainerState();
}

class _AnimatedBranchContainerState extends State<AnimatedBranchContainer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: _duration, value: 1);
  int _leaving = -1;

  @override
  void didUpdateWidget(AnimatedBranchContainer old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _leaving = old.currentIndex;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_c.value);
        final animating = _c.isAnimating;
        final dir = widget.currentIndex > _leaving ? 1.0 : -1.0;
        return Stack(fit: StackFit.expand, children: [
          for (var i = 0; i < widget.children.length; i++)
            () {
              final current = i == widget.currentIndex;
              final leaving = animating && i == _leaving;
              // The wrappers are always present (identity when idle) so a tab's state is never rebuilt.
              final dx = current ? (animating ? dir * _shift * (1 - t) : 0.0) : (leaving ? -dir * _shift * t : 0.0);
              final opacity = current ? (animating ? t : 1.0) : (leaving ? 1 - t : 0.0);
              return Offstage(
                offstage: !current && !leaving,
                child: TickerMode(
                  enabled: current || leaving,
                  child: IgnorePointer(
                    ignoring: !current,
                    child: FractionalTranslation(
                      translation: Offset(dx, 0),
                      child: Opacity(opacity: opacity, child: RepaintBoundary(child: widget.children[i])),
                    ),
                  ),
                ),
              );
            }(),
        ]);
      },
    );
  }
}
