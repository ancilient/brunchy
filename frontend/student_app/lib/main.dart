// Brunchy: Flutter version of the React app (App.tsx). Same screens, flow, colours and demo behaviour.
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/cart.dart';
import 'screens/home.dart';
import 'screens/login_choose.dart';
import 'screens/modals.dart';
import 'screens/orders_profile.dart';
import 'screens/splash_header.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';
import 'ui/icons.dart';
import 'ui/responsive_frame.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  runApp(AppScope(state: state, child: const BrunchyApp()));
}

class BrunchyApp extends StatelessWidget {
  const BrunchyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brunchy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: C.page,
        colorScheme: ColorScheme.fromSeed(seedColor: C.brand, primary: C.brand, surface: Colors.white),
        textSelectionTheme: const TextSelectionThemeData(cursorColor: C.brand),
      ),
      // Fits every page to the device: text size for the phone's width, centred column on tablets / desktop.
      builder: (context, child) => ResponsiveFrame(child: child ?? const SizedBox.shrink()),
      home: const AnnotatedRegion<SystemUiOverlayStyle>(
        // dark status-bar icons on the light cream background
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: StudentAppShell(),
      ),
    );
  }
}

enum AppTab { home, cart, orders, profile }

class StudentAppShell extends StatefulWidget {
  const StudentAppShell({super.key});
  @override
  State<StudentAppShell> createState() => _StudentAppShellState();
}

class _StudentAppShellState extends State<StudentAppShell> {
  AppTab _tab = AppTab.home;
  bool _showSplash = true; // splash -> login -> choose canteen -> app
  bool _replaySplash = false;
  bool _hasChosenCanteen = false;
  bool _initialised = false;
  bool _payOpen = false;
  bool _pickerOpen = false;
  bool _customerCareOpen = false;
  bool _welcome = false; // full-page "logged in" message right after a successful login
  String? _policy; // 'refund' | 'terms' | 'privacy'
  int _seenHoldExpired = 0;
  final _payKey = GlobalKey<PaySheetState>();
  final _loginKey = GlobalKey<LoginScreenState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AppScope.of(context);
    if (!_initialised) {
      _initialised = true;
      // If student has an active order, open straight to Orders (per flow specification)
      _tab = s.hasActiveOrder ? AppTab.orders : AppTab.home;
      _hasChosenCanteen = s.hasActiveOrder;
      _seenHoldExpired = s.holdExpiredCount;
    }
    // The 5-minute payment hold ran out: close the payment sheet and say why.
    if (s.holdExpiredCount != _seenHoldExpired) {
      _seenHoldExpired = s.holdExpiredCount;
      if (_payOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _payOpen = false);
          showAlert(context, 'Payment time ran out, so your items were released. Please tap Pay again.');
        });
      }
    }
  }

  bool get _inMainApp {
    final s = AppScope.read(context);
    return !_showSplash && s.currentUser.isLoggedIn && (_hasChosenCanteen || s.hasActiveOrder);
  }

  /// Android back button: popups first, then other tabs go to Home; returns false to leave the app.
  bool _handleBack() {
    final s = AppScope.read(context);
    if (_showSplash || _replaySplash) return true;
    if (!s.currentUser.isLoggedIn) return _loginKey.currentState?.handleBack() ?? false;
    if (_welcome) {
      setState(() => _welcome = false);
      return true;
    }
    if (!_inMainApp) return false;
    if (_payOpen && s.activePendingOrder != null) return _payKey.currentState?.handleBack() ?? true;
    if (s.stockShortages.isNotEmpty) {
      s.clearShortages();
      return true;
    }
    if (_policy != null) {
      setState(() => _policy = null);
      return true;
    }
    if (_customerCareOpen) {
      setState(() => _customerCareOpen = false);
      return true;
    }
    if (_pickerOpen) {
      setState(() => _pickerOpen = false);
      return true;
    }
    if (_tab != AppTab.home) {
      setState(() => _tab = AppTab.home);
      return true;
    }
    return false;
  }

  void _afterShortageResolved() {
    // Run checkout again with the corrected cart.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final s = AppScope.read(context);
      if (s.cart.isEmpty) return;
      final res = await s.startCheckout();
      if (!mounted) return;
      if (res.success) {
        setState(() => _payOpen = true);
      } else if (!res.shortage && res.message != null) {
        showAlert(context, res.message!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final inMain = _inMainApp;

    Widget body;
    if (_showSplash) {
      body = const SizedBox.shrink();
    } else if (!s.currentUser.isLoggedIn) {
      body = LoginScreen(key: _loginKey, onLoginSuccess: () => setState(() {
            _hasChosenCanteen = false;
            _welcome = true;
          }));
    } else if (!_hasChosenCanteen && !s.hasActiveOrder) {
      body = ChooseCanteenScreen(onCanteenChosen: () => setState(() {
            _hasChosenCanteen = true;
            _tab = AppTab.home;
          }));
    } else {
      switch (_tab) {
        case AppTab.home:
          body = StudentHome(
            onOpenCanteenPicker: () => setState(() => _pickerOpen = true),
            onOpenCart: () => setState(() => _tab = AppTab.cart),
            onOpenOrders: () => setState(() => _tab = AppTab.orders),
          );
        case AppTab.cart:
          body = CartScreen(onBackToMenu: () => setState(() => _tab = AppTab.home), onProceedToPay: () => setState(() => _payOpen = true));
        case AppTab.orders:
          body = OrdersPage(onBackToMenu: () => setState(() => _tab = AppTab.home), onOpenCustomerCare: () => setState(() => _customerCareOpen = true));
        case AppTab.profile:
          body = ProfilePage(
            onSwitchCanteen: () => setState(() => _pickerOpen = true),
            onReorder: () => setState(() => _tab = AppTab.cart),
            onOpenCustomerCare: () => setState(() => _customerCareOpen = true),
            onOpenPolicy: (k) => setState(() => _policy = k),
          );
      }
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;
    return PopScope(
      // Back is always handled here: close the open popup, else go to Home, else leave the app.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!_handleBack()) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: C.page,
        resizeToAvoidBottomInset: true,
        body: Stack(children: [
          Column(children: [
            Header(
              onReplaySplash: () => setState(() => _replaySplash = true),
              initials: inMain ? initialsOf(s.currentUser.name) : null,
              onOpenProfile: () => setState(() => _tab = AppTab.profile),
            ),
            Expanded(child: _PageTransition(pageKey: _pageKey(s), order: _pageOrder(s), child: body)),
          ]),
          if (inMain && _tab == AppTab.home)
            Positioned(left: 16, right: 16, bottom: 98 + bottomInset, child: FloatingCartBar(onOpenCart: () => setState(() => _tab = AppTab.cart))),
          if (inMain) Positioned(left: 0, right: 0, bottom: 0, child: _bottomNav(s, bottomInset)),
          // Popups
          if (inMain && _payOpen && s.activePendingOrder != null)
            Positioned.fill(
              child: PaySheet(
                key: _payKey,
                onClose: () => setState(() => _payOpen = false),
                onPaymentSuccess: (_) => setState(() {
                  _payOpen = false;
                  _tab = AppTab.orders;
                }),
              ),
            ),
          if (inMain && _pickerOpen) Positioned.fill(child: CanteenPicker(onClose: () => setState(() => _pickerOpen = false))),
          if (inMain && s.stockShortages.isNotEmpty) Positioned.fill(child: ShortageSheet(onSuccessProceed: _afterShortageResolved)),
          if (_customerCareOpen) Positioned.fill(child: CustomerCareModal(onClose: () => setState(() => _customerCareOpen = false))),
          if (_policy != null) Positioned.fill(child: PolicyModal(kind: _policy!, onClose: () => setState(() => _policy = null))),
          if (_welcome && s.currentUser.isLoggedIn)
            Positioned.fill(child: LoginSuccessScreen(name: s.currentUser.name, onContinue: () => setState(() => _welcome = false))),
          if (_showSplash) Positioned.fill(child: SplashLogo(onFinish: () => setState(() => _showSplash = false))),
          if (_replaySplash) Positioned.fill(child: SplashLogo(onFinish: () => setState(() => _replaySplash = false))),
        ]),
      ),
    );
  }

  /// Which page the body shows; a new key plays the page transition.
  String _pageKey(AppState s) {
    if (_showSplash) return 'splash';
    if (!s.currentUser.isLoggedIn) return 'login';
    if (!_hasChosenCanteen && !s.hasActiveOrder) return 'choose';
    return _tab.name;
  }

  /// Splash -> login -> choose canteen -> Home, Cart, Orders, Profile.
  int _pageOrder(AppState s) => switch (_pageKey(s)) {
        'splash' => 0,
        'login' => 1,
        'choose' => 2,
        _ => 3 + _tab.index,
      };

  Widget _bottomNav(AppState s, double bottomInset) {
    final cartCount = s.cartItemCount;
    final activeCount = s.getStudentBills().where((b) => const ['waiting_for_acceptance', 'accepted', 'ready'].contains(b.status)).length;
    const fade = Duration(milliseconds: 280);
    Widget item(AppTab t, String icon, String label, {int badge = 0, Color badgeColor = C.brand, double badgeRight = 24}) {
      final active = _tab == t;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _tab = t),
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
            // Active tab: a fixed-size pill grows in behind the icon, and the icon plays its own little action.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 60,
                  height: 32,
                  // No pill behind the active tab: the icon's colour and its little action mark it.
                  child: Center(child: _DockIcon(icon: icon, active: active)),
                ),
                const SizedBox(height: 3),
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: active ? C.brand : C.slate500),
                  duration: fade,
                  builder: (_, color, __) => Text(label, style: ts(10, w: active ? w7 : w5, color: color ?? C.slate500)),
                ),
              ]),
            ),
            if (badge > 0)
              Positioned(
                top: 2,
                right: badgeRight,
                child: Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: txt('$badge', 9, w: w7, font: F.mono, color: Colors.white),
                ),
              ),
          ]),
        ),
      );
    }

    // Floating frosted dock (One UI style): lifted off the screen edges, blurred glass with a soft shadow.
    final radius = BorderRadius.circular(28);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(color: C.a(Colors.black, 0.12), blurRadius: 24, offset: const Offset(0, 10)),
                BoxShadow(color: C.a(Colors.black, 0.05), blurRadius: 4, offset: const Offset(0, 1)),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: C.a(Colors.white, 0.62),
                    borderRadius: radius,
                    border: Border.all(color: C.a(Colors.white, 0.75)),
                  ),
                  child: Row(children: [
                    item(AppTab.home, 'Home', 'Home'),
                    item(AppTab.cart, 'ShoppingBag', 'Cart', badge: cartCount),
                    item(AppTab.orders, 'FileText', 'Orders', badge: activeCount, badgeColor: C.emerald600, badgeRight: 20),
                    item(AppTab.profile, 'User', 'Profile'),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dock icon that plays its own one-off action when its tab becomes active:
/// Home hops, the Cart bag swings from its handle, Orders flips like a page, Profile pulses like a heartbeat.
class _DockIcon extends StatefulWidget {
  const _DockIcon({required this.icon, required this.active});
  final String icon;
  final bool active;
  @override
  State<_DockIcon> createState() => _DockIconState();
}

class _DockIconState extends State<_DockIcon> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650), value: 1);

  @override
  void didUpdateWidget(_DockIcon old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _action(double t, Widget child) {
    final fade = 1 - t; // every action settles back to rest
    switch (widget.icon) {
      case 'Home': // hop: up and stretched, then a little squash on landing
        final up = math.sin(math.pi * Curves.easeOut.transform(t));
        final squash = t > 0.8 ? math.sin((t - 0.8) / 0.2 * math.pi) * 0.12 : 0.0;
        return Transform.translate(
          offset: Offset(0, -7 * up),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(1 - 0.08 * up + squash, 1 + 0.12 * up - squash, 1),
            child: child,
          ),
        );
      case 'ShoppingBag': // swing from the handle
        return Transform.rotate(alignment: Alignment.topCenter, angle: math.sin(t * 3 * 2 * math.pi) * 0.4 * fade, child: child);
      case 'FileText': // page flip
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateY(2 * math.pi * Curves.easeInOutCubic.transform(t)),
          child: child,
        );
      case 'User': // double heartbeat
        final beat = math.sin(t * 2 * 2 * math.pi).abs() * 0.22 * fade;
        return Transform.scale(scale: 1 + beat, child: child);
      default:
        return child;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: widget.active ? C.brand : C.slate500),
      duration: const Duration(milliseconds: 280),
      builder: (_, color, __) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => _action(_c.value, child!),
        child: LIcon(widget.icon, size: 20, color: color ?? C.slate500),
      ),
    );
  }
}

/// Page transition: shared-axis slide. The old page slides away and fades out while the new one slides in and
/// fades in; going to a later tab slides left, going back slides right. Only opacity and a translation change on
/// layers that are already painted, so it stays smooth (a size/accordion transition would re-layout every frame).
class _PageTransition extends StatefulWidget {
  const _PageTransition({required this.pageKey, required this.order, required this.child});
  final String pageKey;
  final int order; // position of the page in the app's flow, for the slide direction
  final Widget child;
  @override
  State<_PageTransition> createState() => _PageTransitionState();
}

class _PageTransitionState extends State<_PageTransition> {
  bool _forward = true;

  @override
  void didUpdateWidget(_PageTransition old) {
    super.didUpdateWidget(old);
    if (old.pageKey != widget.pageKey) _forward = widget.order >= old.order;
  }

  @override
  Widget build(BuildContext context) {
    final dir = _forward ? 1.0 : -1.0;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, if (current != null) current]),
      transitionBuilder: (child, anim) {
        final incoming = child.key == ValueKey(widget.pageKey);
        // The outgoing page plays this in reverse, so it leaves towards the opposite side.
        final slide = Tween(begin: Offset((incoming ? dir : -dir) * 0.14, 0), end: Offset.zero).animate(anim);
        return FadeTransition(opacity: anim, child: SlideTransition(position: slide, child: child));
      },
      child: KeyedSubtree(key: ValueKey(widget.pageKey), child: RepaintBoundary(child: widget.child)),
    );
  }
}
