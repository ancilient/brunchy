// LoginScreen (Sign in with Google) and ChooseCanteenScreen.
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/google_auth.dart';
import '../state/app_scope.dart';
import '../state/models.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoginSuccess});
  final VoidCallback onLoginSuccess;
  @override
  State<LoginScreen> createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  bool _loadingOptions = true;
  String? _optionsError;
  ({bool google, String? googleClientId, bool devLogin})? _options;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOptions());
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _optionsError = null;
    });
    try {
      final o = await AppScope.read(context).loginOptions();
      if (mounted) setState(() => _options = o);
    } on ApiException catch (e) {
      if (mounted) setState(() => _optionsError = e.message);
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      widget.onLoginSuccess();
    } on GoogleAuthCancelled {
      // the student closed Google's account picker: nothing to say
    } on ApiException catch (e) {
      if (mounted) showAlert(context, e.message);
    } catch (e) {
      if (mounted) {
        showAlert(context, 'Google sign-in did not work on this phone. Check that the app is registered in Google Cloud Console (see README).');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _google() {
    final clientId = _options?.googleClientId;
    if (_options?.google != true || clientId == null) {
      showAlert(context, 'Google sign-in is not set up on the server yet. Use the development login for now.');
      return;
    }
    _run(() => AppScope.read(context).signInWithGoogle(clientId));
  }

  /// Android back: nothing to go back to on this screen.
  bool handleBack() => false;

  @override
  Widget build(BuildContext context) {
    final o = _options;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 384),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: card(border: C.amber100, shadow: [BoxShadow(color: C.a(const Color(0xFF451A03), 0.05), blurRadius: 25, offset: const Offset(0, 20))]),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: logoTile(64, 16, const LIcon('UtensilsCrossed', size: 32, color: Colors.white))),
              const SizedBox(height: 12),
              txt('Welcome to Brunchy', 24, w: w8, font: F.display, align: TextAlign.center),
              const SizedBox(height: 4),
              txt('Skip the canteen queue · Order in 30 seconds', 12, color: C.slate500, align: TextAlign.center),
              const SizedBox(height: 28),
              if (_loadingOptions)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: C.brand, strokeWidth: 3))),
                )
              else if (_optionsError != null) ...[
                txt(_optionsError!, 12, color: C.rose600, align: TextAlign.center),
                const SizedBox(height: 12),
                GradientButton(onTap: _loadOptions, child: txt('Try again', 12, w: w7, color: Colors.white)),
              ] else ...[
                // Sign in with Google (Google's button style: white, Google "G", dark text)
                Tap(
                  onTap: _busy ? null : _google,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.slate200)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const _GoogleG(),
                      const SizedBox(width: 12),
                      txt(_busy ? 'Signing in...' : 'Sign in with Google', 14, w: w7, color: C.slate800),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                txt('Use your college or personal Google account. Free, no SMS needed.', 11, color: C.slate500, align: TextAlign.center),
                if (o?.devLogin == true) ...[
                  const SizedBox(height: 20),
                  Tap(
                    onTap: _busy ? null : () => _run(() => AppScope.read(context).devLogin()),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: C.amber50, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.a(C.amber200, 0.8))),
                      child: Column(children: [
                        txt('Continue as Demo Student', 12, w: w7, color: C.amber800, align: TextAlign.center),
                        const SizedBox(height: 2),
                        txt('(Development server only)', 10, color: C.amber700, align: TextAlign.center),
                      ]),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.slate100))),
                child: txt('By signing in, you agree to Brunchy Canteen Terms & Privacy Notice', 10, color: C.slate400, align: TextAlign.center),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Google's four-colour "G" mark, drawn so no image asset is needed.
class _GoogleG extends StatelessWidget {
  const _GoogleG();
  @override
  Widget build(BuildContext context) => const SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GooglePainter()));
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const deg = 3.14159265 / 180;
    canvas.drawArc(rect, -40 * deg, -100 * deg, false, p(const Color(0xFFEA4335))); // red (top)
    canvas.drawArc(rect, -140 * deg, -90 * deg, false, p(const Color(0xFFFBBC05))); // yellow (left)
    canvas.drawArc(rect, 130 * deg, -95 * deg, false, p(const Color(0xFF34A853))); // green (bottom)
    canvas.drawArc(rect, 35 * deg, -75 * deg, false, p(const Color(0xFF4285F4))); // blue (right)
    canvas.drawLine(Offset(size.width / 2, size.height / 2), Offset(size.width - stroke / 2, size.height / 2), p(const Color(0xFF4285F4)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
            logoTile(56, 16, const LIcon('UtensilsCrossed', size: 28, color: Colors.white)),
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
