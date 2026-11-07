// Brunchy: Flutter version of the React app (App.tsx). Same screens, flow, colours and demo behaviour.
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
        scaffoldBackgroundColor: C.cream,
        colorScheme: ColorScheme.fromSeed(seedColor: C.brand, primary: C.brand, surface: Colors.white),
        textSelectionTheme: const TextSelectionThemeData(cursorColor: C.brand),
      ),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = AppScope.read(context);
      if (s.cart.isEmpty) return;
      final res = s.startCheckout();
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
      body = LoginScreen(key: _loginKey, onLoginSuccess: () => setState(() => _hasChosenCanteen = false));
    } else if (!_hasChosenCanteen && !s.hasActiveOrder) {
      body = ChooseCanteenScreen(onCanteenChosen: () => setState(() {
            _hasChosenCanteen = true;
            _tab = AppTab.home;
          }));
    } else {
      switch (_tab) {
        case AppTab.home:
          body = StudentHome(onOpenCanteenPicker: () => setState(() => _pickerOpen = true));
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
        backgroundColor: C.cream,
        resizeToAvoidBottomInset: true,
        body: Stack(children: [
          Column(children: [
            Header(onReplaySplash: () => setState(() => _replaySplash = true)),
            Expanded(child: body),
          ]),
          if (inMain && _tab == AppTab.home)
            Positioned(left: 16, right: 16, bottom: 80 + bottomInset, child: FloatingCartBar(onOpenCart: () => setState(() => _tab = AppTab.cart))),
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
          if (_showSplash) Positioned.fill(child: SplashLogo(onFinish: () => setState(() => _showSplash = false))),
          if (_replaySplash) Positioned.fill(child: SplashLogo(onFinish: () => setState(() => _replaySplash = false))),
        ]),
      ),
    );
  }

  Widget _bottomNav(AppState s, double bottomInset) {
    final cartCount = s.cartItemCount;
    final activeCount = s.getStudentBills().where((b) => const ['waiting_for_acceptance', 'accepted', 'ready'].contains(b.status)).length;
    Widget item(AppTab t, String icon, String label, {int badge = 0, Color badgeColor = C.brand, double badgeRight = 24}) {
      final active = _tab == t;
      return Expanded(
        child: Tap(
          scale: 1,
          onTap: () => setState(() => _tab = t),
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: active ? C.orange100 : null, borderRadius: BorderRadius.circular(12)),
                  child: LIcon(icon, size: 20, color: active ? C.brand : C.slate500),
                ),
                const SizedBox(height: 2),
                txt(label, 10, w: active ? w7 : w4, color: active ? C.brand : C.slate500),
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

    return Container(
      padding: EdgeInsets.only(top: 8, bottom: 8 + bottomInset),
      decoration: BoxDecoration(
        color: C.a(Colors.white, 0.95),
        border: Border(top: BorderSide(color: C.a(C.amber200, 0.6))),
        boxShadow: [BoxShadow(color: C.a(Colors.black, 0.1), blurRadius: 15, offset: const Offset(0, -2))],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              item(AppTab.home, 'Home', 'Home'),
              item(AppTab.cart, 'ShoppingBag', 'Cart', badge: cartCount),
              item(AppTab.orders, 'FileText', 'Orders', badge: activeCount, badgeColor: C.emerald600, badgeRight: 20),
              item(AppTab.profile, 'User', 'Profile'),
            ]),
          ),
        ),
      ),
    );
  }
}
