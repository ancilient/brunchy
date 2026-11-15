// LoginScreen.tsx and ChooseCanteenScreen.tsx
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../state/app_scope.dart';
import '../state/models.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';

InputDecoration _input({String? hint, Widget? prefix, BorderRadius? radius}) {
  final r = radius ?? BorderRadius.circular(16);
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: ts(12, color: C.slate400),
    prefixIcon: prefix,
    prefixIconConstraints: const BoxConstraints(minWidth: 36),
    filled: true,
    fillColor: C.slate50,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    counterText: '',
    enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: const BorderSide(color: C.slate200)),
    focusedBorder: OutlineInputBorder(borderRadius: r, borderSide: const BorderSide(color: C.brandLight, width: 2)),
    border: OutlineInputBorder(borderRadius: r, borderSide: const BorderSide(color: C.slate200)),
  );
}

/// Full-page "you're in" moment right after a successful login: a check pops in, a food quote, then it moves on
/// by itself after 10 s (or straight away on "Let's eat"). Fades in over the app and fades away when done.
class LoginSuccessScreen extends StatefulWidget {
  const LoginSuccessScreen({super.key, required this.name, required this.onContinue});
  final String name;
  final VoidCallback onContinue;
  @override
  State<LoginSuccessScreen> createState() => _LoginSuccessScreenState();
}

class _LoginSuccessScreenState extends State<LoginSuccessScreen> with TickerProviderStateMixin {
  static const _quotes = [
    ('Order the foods and snacks you wish for', 'Skip the queue. Just say your code at the counter.'),
    ('Hungry? Your canteen is one tap away', 'Fresh burgers, juices and hot meals, ready when you are.'),
    ('Good food, zero waiting', 'Order now and pick it up on your break.'),
    ('Craving something tasty?', "Browse today's menu and grab it while it's hot."),
  ];
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  late final _countdown = AnimationController(vsync: this, duration: const Duration(seconds: 10))..forward();
  late final _quote = _quotes[math.Random().nextInt(_quotes.length)];
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    // The OTP keyboard may still be up: close it so the page gets the whole screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => FocusManager.instance.primaryFocus?.unfocus());
    _countdown.addStatusListener((st) {
      if (st == AnimationStatus.completed) _leave();
    });
  }

  void _leave() {
    if (_leaving) return;
    _countdown.stop();
    setState(() => _leaving = true);
    Future.delayed(const Duration(milliseconds: 320), () { if (mounted) widget.onContinue(); });
  }

  @override
  void dispose() {
    _intro.dispose();
    _countdown.dispose();
    super.dispose();
  }

  /// A slice of the intro, so each element arrives a little after the previous one.
  Animation<double> _step(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _intro, curve: Interval(a, b, curve: curve));

  Widget _rise(Animation<double> a, Widget child) => AnimatedBuilder(
        animation: a,
        builder: (_, c) => Opacity(opacity: a.value.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, 18 * (1 - a.value)), child: c)),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final first = widget.name.trim().split(' ').first;
    final pad = MediaQuery.of(context).padding;
    return IgnorePointer(
      ignoring: _leaving,
      child: AnimatedOpacity(
        opacity: _leaving ? 0 : 1,
        duration: const Duration(milliseconds: 300),
        child: Material(
          color: C.cream,
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(28, pad.top + 32, 28, pad.bottom + 28),
                  child: Column(children: [
                    SizedBox(height: box.maxHeight * 0.12),
                    ScaleTransition(
                      scale: _step(0.0, 0.45, Curves.easeOutBack),
                      child: Container(
                        width: 92, height: 92,
                        decoration: BoxDecoration(
                          gradient: C.brandGradientDiag,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: C.a(C.orange500, 0.3), blurRadius: 28, offset: const Offset(0, 12))],
                        ),
                        alignment: Alignment.center,
                        child: const LIcon('Check', size: 44, color: Colors.white, strokeWidth: 3),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _rise(_step(0.2, 0.6), txt(first.isEmpty ? 'Welcome!' : 'Welcome, $first!', 26, w: w8, font: F.display, align: TextAlign.center)),
                    const SizedBox(height: 8),
                    _rise(
                      _step(0.3, 0.7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(color: C.emerald50, borderRadius: BorderRadius.circular(99), border: Border.all(color: C.emerald200)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const LIcon('ShieldCheck', size: 13, color: C.emerald600),
                          const SizedBox(width: 6),
                          txt("You've logged in successfully", 12, w: w6, color: C.emerald700),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _rise(
                      _step(0.45, 0.9),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: C.a(C.amber200, 0.7)),
                          boxShadow: [BoxShadow(color: C.a(const Color(0xFFD7BE96), 0.22), blurRadius: 18, offset: const Offset(0, 8))],
                        ),
                        child: Column(children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: C.orange50, shape: BoxShape.circle, border: Border.all(color: C.orange200)),
                            alignment: Alignment.center,
                            child: const LIcon('Sparkles', size: 16, color: C.brand),
                          ),
                          const SizedBox(height: 12),
                          txt(_quote.$1, 16, w: w7, font: F.display, align: TextAlign.center, color: C.slate800),
                          const SizedBox(height: 6),
                          txt(_quote.$2, 12, color: C.slate500, align: TextAlign.center, height: 1.45),
                        ]),
                      ),
                    ),
                    SizedBox(height: box.maxHeight * 0.1),
                    _rise(
                      _step(0.6, 1.0),
                      Column(children: [
                        GradientButton(
                          onTap: _leave,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            txt("Let's eat", 14, w: w7, color: Colors.white),
                            const SizedBox(width: 8),
                            const LIcon('ArrowRight', size: 16, color: Colors.white),
                          ]),
                        ),
                        const SizedBox(height: 16),
                        // Countdown to moving on by itself.
                        SizedBox(
                          width: 96,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: AnimatedBuilder(
                              animation: _countdown,
                              builder: (_, __) => LinearProgressIndicator(
                                value: _countdown.value,
                                minHeight: 4,
                                backgroundColor: C.a(C.amber200, 0.6),
                                color: C.brand,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedBuilder(
                          animation: _countdown,
                          builder: (_, __) => txt('Continuing in ${(10 - _countdown.value * 10).ceil()}s', 10, color: C.slate400),
                        ),
                      ]),
                    ),
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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoginSuccess});
  final VoidCallback onLoginSuccess;
  @override
  State<LoginScreen> createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  // Pre-filled with the backend's seeded demo student so development is quick.
  final _name = TextEditingController(text: 'Demo Student');
  final _phone = TextEditingController(text: '9876543210');
  final _reg = TextEditingController(text: '41110001');
  final _otp = TextEditingController();
  String _step = 'details';
  bool _busy = false;
  bool _devFilled = false;

  Future<void> _sendCode() async {
    if (_busy) return;
    if (_name.text.trim().isEmpty || _phone.text.trim().length != 10) {
      showAlert(context, 'Enter your name and a 10-digit mobile number.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final devCode = await AppScope.read(context).requestOtp(_phone.text.trim());
      _otp.text = devCode ?? '';
      _devFilled = devCode != null;
      if (mounted) setState(() => _step = 'otp');
    } on ApiException catch (e) {
      if (mounted) showAlert(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await AppScope.read(context).verifyOtp(
        phone: _phone.text.trim(),
        code: _otp.text.trim(),
        name: _name.text.trim(),
        registerNo: _reg.text.trim(),
      );
      widget.onLoginSuccess();
    } on ApiException catch (e) {
      if (mounted) showAlert(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Android back: OTP step goes back to the details step.
  bool handleBack() {
    if (_step != 'otp') return false;
    setState(() => _step = 'details');
    return true;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _reg, _otp]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _label(String text, [String? optional]) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: text, style: ts(12, w: w6, color: C.slate700)),
          if (optional != null) TextSpan(text: ' $optional', style: ts(12, color: C.slate400)),
        ])),
      );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 384),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: card(border: C.amber100, shadow: [BoxShadow(color: C.a(const Color(0xFF451A03), 0.05), blurRadius: 25, offset: const Offset(0, 20))]),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: brandLogo(84)),
              const SizedBox(height: 12),
              txt('Welcome to Brunchy', 24, w: w8, font: F.display, align: TextAlign.center),
              const SizedBox(height: 4),
              txt('Skip the canteen queue · Order in 30 seconds', 12, color: C.slate500, align: TextAlign.center),
              const SizedBox(height: 24),
              if (_step == 'details') ...[
                _label('Your Full Name'),
                TextField(controller: _name, style: ts(12, w: w5, color: C.slate800),
                    decoration: _input(hint: 'e.g. Priya Sharma', prefix: const Padding(padding: EdgeInsets.only(left: 12, right: 8), child: LIcon('User', size: 16, color: C.slate400)))),
                const SizedBox(height: 16),
                _label('Mobile Number (for Order SMS)'),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                    decoration: const BoxDecoration(color: C.slate100,
                        border: Border(left: BorderSide(color: C.slate200), top: BorderSide(color: C.slate200), bottom: BorderSide(color: C.slate200)),
                        borderRadius: BorderRadius.horizontal(left: Radius.circular(16))),
                    child: txt('+91', 12, w: w5, color: C.slate500),
                  ),
                  Expanded(
                    child: TextField(controller: _phone, keyboardType: TextInputType.phone, maxLength: 10,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly], style: ts(12, w: w5, color: C.slate800, font: F.mono),
                        decoration: _input(hint: '98765 43210', radius: const BorderRadius.horizontal(right: Radius.circular(16)))),
                  ),
                ]),
                const SizedBox(height: 16),
                _label('Campus Reg Number', '(Optional)'),
                TextField(controller: _reg, style: ts(12, w: w5, color: C.slate800, font: F.mono),
                    decoration: _input(hint: 'e.g. ENG2024-8842', prefix: const Padding(padding: EdgeInsets.only(left: 12, right: 8), child: LIcon('Award', size: 16, color: C.slate400)))),
                const SizedBox(height: 24),
                GradientButton(
                  onTap: _sendCode,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    txt(_busy ? 'Sending code...' : 'Continue with SMS OTP', 12, w: w7, color: Colors.white),
                    const SizedBox(width: 8),
                    const LIcon('ArrowRight', size: 16, color: Colors.white),
                  ]),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: C.amber50, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.a(C.amber200, 0.8))),
                  child: Column(children: [
                    txt('Enter the 6-digit code sent to +91 ${_phone.text}', 11, color: C.slate600, align: TextAlign.center),
                    if (_devFilled) ...[
                      const SizedBox(height: 2),
                      txt('(Development server: code filled in for you)', 10, w: w6, color: C.amber700),
                    ],
                  ]),
                ),
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: 200,
                    child: TextField(controller: _otp, maxLength: 6, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: ts(18, w: w7, font: F.mono, spacing: 10), decoration: _input()),
                  ),
                ),
                const SizedBox(height: 16),
                GradientButton(
                  onTap: _verify,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const LIcon('ShieldCheck', size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    txt(_busy ? 'Checking...' : 'Verify & Remember Me', 12, w: w7, color: Colors.white),
                  ]),
                ),
                const SizedBox(height: 16),
                Tap(onTap: () => setState(() => _step = 'details'), child: txt('Change Phone Number', 11, color: C.slate500, align: TextAlign.center)),
              ],
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.slate100))),
                child: txt('By signing up, you agree to Brunchy Canteen Terms & Privacy Notice', 10, color: C.slate400, align: TextAlign.center),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class ChooseCanteenScreen extends StatelessWidget {
  const ChooseCanteenScreen({super.key, required this.onCanteenChosen});
  final VoidCallback onCanteenChosen;

  Future<void> _select(BuildContext context, int canteenId) async {
    final s = AppScope.read(context);
    if (s.cart.isNotEmpty && s.productById(s.cart.first.productId)?.canteenId != canteenId) {
      if (!await showConfirm(context, 'Switching canteens will clear your current cart. Proceed?')) return;
      s.clearCart();
    }
    s.setSelectedCanteenId(canteenId);
    onCanteenChosen();
  }

  Widget _bigButton(BuildContext context, Canteen c, {required String tag, required Color tagBg, required Color tagFg, required String stalls, required String distance}) {
    final s = AppScope.of(context);
    return Tap(
      onTap: () => _select(context, c.id),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: card(border: C.a(C.amber200, 0.8), borderWidth: 2, shadow: [BoxShadow(color: C.a(const Color(0xFF451A03), 0.05), blurRadius: 15, offset: const Offset(0, 10))]),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                pill(tag, bg: tagBg, fg: tagFg, spacing: 0.5),
                const SizedBox(width: 8),
                dot(C.emerald500),
                const SizedBox(width: 4),
                txt('OPEN', 12, w: w6, color: C.emerald600),
              ]),
              const SizedBox(height: 4),
              txt(c.name, 18, w: w8, font: F.display),
              const SizedBox(height: 8),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [const LIcon('Clock', size: 14, color: C.slate500), const SizedBox(width: 4), txt('${c.openingTime} - ${c.closingTime}', 12, color: C.slate500)]),
                txt('·', 12, color: C.slate500),
                Row(mainAxisSize: MainAxisSize.min, children: [const LIcon('Store', size: 14, color: C.slate500), const SizedBox(width: 4), txt(stalls, 12, color: C.slate500)]),
              ]),
              const SizedBox(height: 4),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [const LIcon('MapPin', size: 14, color: C.slate400), const SizedBox(width: 4), txt(distance, 12, color: C.slate500)]),
                txt('·', 12, color: C.slate500),
                Row(mainAxisSize: MainAxisSize.min, children: [const LIcon('Flame', size: 14, color: C.amber500), const SizedBox(width: 4), txt('Busy: ${s.getLiveBusyLevel(c.id)}', 12, w: w5, color: C.amber700)]),
              ]),
            ]),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: C.orange100, borderRadius: BorderRadius.circular(16)),
            child: const Center(child: LIcon('ArrowRight', size: 20, color: C.brand)),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final main = s.canteenById(1) ?? s.canteens.first;
    final advance = s.canteenById(2) ?? s.canteens[1];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 384),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            brandLogo(72),
            const SizedBox(height: 12),
            txt('Choose Your Canteen', 24, w: w8, font: F.display),
            const SizedBox(height: 4),
            txt('Where would you like to pick up your food?', 12, color: C.slate600),
            const SizedBox(height: 32),
            _bigButton(context, main, tag: 'PRIMARY HUB', tagBg: C.orange100, tagFg: C.brand, stalls: '4 Stalls', distance: '250m away'),
            const SizedBox(height: 16),
            _bigButton(context, advance, tag: 'BLOCK 3', tagBg: C.slate100, tagFg: C.slate600, stalls: '2 Stalls', distance: '550m away'),
            const SizedBox(height: 24),
            txt('You can switch canteen at any time from your Profile', 11, color: C.slate400, align: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
