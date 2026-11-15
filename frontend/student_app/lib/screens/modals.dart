// PayModal.tsx, CheckoutShortageModal.tsx, CanteenSelectorModal.tsx, CustomerCareModal.tsx
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';

/// Dimmed backdrop (`fixed inset-0 bg-black/60`), content at the bottom (sheet) or centre.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.child, this.bottomSheet = false, this.onTapOutside});
  final Widget child;
  final bool bottomSheet;
  final VoidCallback? onTapOutside;
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: GestureDetector(onTap: onTapOutside, child: Container(color: C.a(Colors.black, 0.6)))),
      Align(
        alignment: bottomSheet ? Alignment.bottomCenter : Alignment.center,
        child: Padding(padding: bottomSheet ? EdgeInsets.zero : const EdgeInsets.all(16), child: child),
      ),
    ]);
  }
}

Widget _sheet(BuildContext context, Widget child) => Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: C.slate100),
        boxShadow: [BoxShadow(color: C.a(Colors.black, 0.25), blurRadius: 50, offset: const Offset(0, 25))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 48, height: 6, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: C.slate200, borderRadius: BorderRadius.circular(99)))),
        child,
      ]),
    );

Widget _closeBtn(VoidCallback? onTap, {double size = 36, double icon = 20}) => Tap(
      onTap: onTap,
      child: SizedBox(width: size, height: size, child: Center(child: LIcon('X', size: icon, color: C.slate400))),
    );

// ======================= Payment =======================
class PaySheet extends StatefulWidget {
  const PaySheet({super.key, required this.onClose, required this.onPaymentSuccess});
  final VoidCallback onClose;
  final void Function(int orderId) onPaymentSuccess;
  @override
  State<PaySheet> createState() => PaySheetState();
}

class PaySheetState extends State<PaySheet> {
  bool _verifying = false;
  bool _showQr = false;

  /// Android back: never interrupt a payment check; QR view goes back to app list; otherwise cancel the hold.
  bool handleBack() {
    if (_verifying) return true;
    if (_showQr) {
      setState(() => _showQr = false);
      return true;
    }
    AppScope.read(context).cancelCheckoutHold();
    widget.onClose();
    return true;
  }

  Future<void> _pay(String method) async {
    setState(() => _verifying = true);
    try {
      final id = await AppScope.read(context).completeUpiPayment(method);
      if (id != null) widget.onPaymentSuccess(id);
    } catch (_) {
      if (mounted) showAlert(context, 'Payment could not be verified. Please retry.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final order = s.activePendingOrder;
    if (order == null) return const SizedBox.shrink();
    const apps = [
      // Official marks from Wikimedia Commons (assets/payment). The names are what _pay() sends as the UPI app.
      ['Google Pay', 'assets/payment/gpay.png', 0xFFEFF6FF, 0xFFBFDBFE],
      ['PhonePe', 'assets/payment/phonepe.png', 0xFFFAF5FF, 0xFFE9D5FF],
      ['Paytm', 'assets/payment/paytm.png', 0xFFF0F9FF, 0xFFBAE6FD],
      ['BHIM UPI', 'assets/payment/bhim.png', 0xFFECFDF5, 0xFFA7F3D0],
    ];
    return Backdrop(
      bottomSheet: true,
      child: _sheet(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.slate100))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  txt('Payment', 20, w: w7, font: F.display),
                  Text.rich(TextSpan(style: ts(12, color: C.slate500), children: [
                    TextSpan(text: '${order.canteenName} · Total to Pay: '),
                    TextSpan(text: '₹${fmtNum(order.total)}', style: ts(12, w: w7, color: C.brand, font: F.mono)),
                  ])),
                ]),
              ),
              _closeBtn(_verifying ? null : () {
                s.cancelCheckoutHold();
                widget.onClose();
              }),
            ]),
          ),
          if (_verifying)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(children: [
                const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(color: C.brand, strokeWidth: 4)),
                const SizedBox(height: 16),
                txt('Checking payment with bank...', 16, w: w7, align: TextAlign.center),
                const SizedBox(height: 4),
                txt('Please do not hit back or close the app. Never charged twice.', 12, color: C.slate500, align: TextAlign.center),
              ]),
            )
          else if (_showQr)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: C.slate50, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.amber300, width: 2)),
                  child: const LIcon('QrCode', size: 192, color: C.slate900),
                ),
                const SizedBox(height: 16),
                txt('Scan with any UPI app to pay ₹${fmtNum(order.total)}', 12, w: w5, color: C.slate600),
                const SizedBox(height: 16),
                GradientButton(onTap: () => _pay('QR Code'), padding: const EdgeInsets.symmetric(vertical: 12),
                    child: txt('Simulate Successful QR Payment', 12, w: w7, color: Colors.white)),
                const SizedBox(height: 16),
                Tap(onTap: () => setState(() => _showQr = false), child: txt('← Back to UPI App Selection', 12, color: C.slate400)),
              ]),
            )
          else ...[
            Tap(
              onTap: () => setState(() => _showQr = true),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.a(C.orange50, 0.4), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.a(C.amber200, 0.8))),
                child: Row(children: [
                  Container(width: 40, height: 40,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.amber200)),
                      child: const Center(child: LIcon('QrCode', size: 20, color: C.brand))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      txt('Show Payment QR Code', 12, w: w7),
                      txt('Scan with any college or banking scanner', 10, color: C.slate500),
                    ]),
                  ),
                  const LIcon('ArrowRight', size: 16, color: C.brand),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            Center(child: txt('OR TAP YOUR UPI APP', 11, w: w6, color: C.slate400)),
            const SizedBox(height: 16),
            for (var r = 0; r < 2; r++) ...[
              if (r > 0) const SizedBox(height: 10),
              Row(children: [
                for (var c = 0; c < 2; c++) ...[
                  if (c > 0) const SizedBox(width: 10),
                  Expanded(child: _appButton(apps[r * 2 + c])),
                ],
              ]),
            ],
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const LIcon('ShieldCheck', size: 14, color: C.emerald600),
              const SizedBox(width: 6),
              Flexible(child: txt('100% Secure Campus Gateway · Instant refund if stall rejects', 11, color: C.slate400, align: TextAlign.center)),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _appButton(List<Object> a) => Tap(
        onTap: () => _pay(a[0] as String),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Color(a[2] as int), borderRadius: BorderRadius.circular(16), border: Border.all(color: Color(a[3] as int))),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: C.a(Colors.black, 0.06), blurRadius: 4, offset: const Offset(0, 1))]),
              child: Image.asset(a[1] as String, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                txt(a[0] as String, 12, w: w7, maxLines: 1),
                txt('Instant pay', 9, color: C.slate500),
              ]),
            ),
          ]),
        ),
      );
}

// ======================= Stock shortage =======================
class ShortageSheet extends StatelessWidget {
  const ShortageSheet({super.key, required this.onSuccessProceed});
  final VoidCallback onSuccessProceed;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (s.stockShortages.isEmpty) return const SizedBox.shrink();
    final cur = s.stockShortages.first;
    void choose(bool take) {
      final last = s.stockShortages.length <= 1;
      s.handleShortageChoice(cur.product.id, take);
      if (last) {
        s.clearShortages();
        onSuccessProceed();
      }
    }

    return Backdrop(
      bottomSheet: true,
      child: _sheet(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(width: 40, height: 40, decoration: const BoxDecoration(color: C.amber50, shape: BoxShape.circle),
                child: const Center(child: LIcon('AlertCircle', size: 24, color: C.amber600))),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              txt('Limited Stock Alert', 18, w: w7, font: F.display),
              txt('High rush at the canteen counter', 12, color: C.slate500),
            ]),
          ]),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: C.a(C.amber50, 0.7), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.a(C.amber200, 0.7))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              txt('Only ${cur.available} ${cur.product.name} left', 16, w: w6),
              const SizedBox(height: 4),
              txt('You asked for ${cur.requested}. Would you like to order ${cur.available} instead?', 12, color: C.slate600),
              const SizedBox(height: 8),
              txt('Nothing has been charged yet. Your payment amount will adjust automatically.', 11, w: w5, color: C.slate500),
            ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Tap(
                onTap: () => choose(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: C.slate300)),
                  child: Center(child: txt('Remove Item', 12, w: w6, color: C.slate700)),
                ),
              ),
            ),
            if (cur.available > 0) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Tap(
                  onTap: () => choose(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: C.indigoBrand, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: txt('Order ${cur.available}', 12, w: w6, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ======================= Canteen picker =======================
class CanteenPicker extends StatelessWidget {
  const CanteenPicker({super.key, required this.onClose});
  final VoidCallback onClose;

  Future<void> _select(BuildContext context, AppState s, int id, bool closed) async {
    if (closed) return;
    if (s.cart.isNotEmpty && s.selectedCanteenId != id) {
      if (!await showConfirm(context, 'One cart equals one canteen. Switching canteens will clear your current cart. Switch now?')) return;
      s.clearCart();
    }
    s.setSelectedCanteenId(id);
    onClose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Backdrop(
      onTapOutside: null,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 448, maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: C.slate100),
              boxShadow: [BoxShadow(color: C.a(Colors.black, 0.25), blurRadius: 50, offset: const Offset(0, 25))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.slate100))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    txt('Choose your canteen', 20, w: w7, font: F.display),
                    const SizedBox(height: 2),
                    txt('Switch any time · One cart = one canteen', 12, color: C.slate500),
                  ]),
                ),
                _closeBtn(onClose),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: C.slate50, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.a(C.slate200, 0.7))),
                    child: Row(children: [
                      const _Spin(child: LIcon('Compass', size: 16, color: C.indigo600)),
                      const SizedBox(width: 8),
                      Expanded(child: txt('Main campus GPS active', 12, color: C.slate600)),
                      txt('Sorted nearest', 12, w: w6, color: C.indigo600),
                    ]),
                  ),
                  for (final c in s.canteens) ...[
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      final selected = s.selectedCanteenId == c.id;
                      final closed = c.status == 'closed';
                      final busy = s.getLiveBusyLevel(c.id);
                      final stallCount = s.stalls.where((x) => x.canteenId == c.id).length;
                      final busyColor = busy == 'High' ? C.rose600 : busy == 'Medium' ? C.amber600 : C.emerald600;
                      return Opacity(
                        opacity: closed ? 0.6 : 1.0,
                        child: Tap(
                          onTap: () => _select(context, s, c.id, closed),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: closed ? C.a(C.slate50, 0.8) : selected ? C.a(C.indigo50, 0.5) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: selected && !closed ? C.indigoBrand : C.slate200, width: 2),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                      txt(c.name, 16, w: w7, font: F.display),
                                      if (selected) pill('CURRENT', bg: C.indigo100, fg: C.indigoBrand, w: w6),
                                      if (c.id == 1 && !selected) pill('LAST USED', bg: C.slate100, fg: C.slate600, w: w6),
                                    ]),
                                    const SizedBox(height: 8),
                                    Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                      Row(mainAxisSize: MainAxisSize.min, children: [const LIcon('Clock', size: 14, color: C.slate500), const SizedBox(width: 4), txt('${c.openingTime} - ${c.closingTime}', 12, color: C.slate500)]),
                                      txt('·', 12, color: C.slate500),
                                      Row(mainAxisSize: MainAxisSize.min, children: [const LIcon('Store', size: 14, color: C.slate500), const SizedBox(width: 4), txt('$stallCount stalls', 12, color: C.slate500)]),
                                    ]),
                                    const SizedBox(height: 10),
                                    Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                      Row(mainAxisSize: MainAxisSize.min, children: [const LIcon('MapPin', size: 14, color: C.slate400), const SizedBox(width: 4), txt('${c.distanceMeters} m away', 12, w: w5, color: C.slate600)]),
                                      txt('·', 12, color: C.slate500),
                                      Row(mainAxisSize: MainAxisSize.min, children: [LIcon('Flame', size: 14, color: busyColor), const SizedBox(width: 4), txt('Busy: $busy', 12, w: w5, color: busyColor)]),
                                    ]),
                                  ]),
                                ),
                                if (closed)
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    pill('CLOSED', bg: C.slate200, fg: C.slate500, size: 12, radius: 8, pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                                    const SizedBox(height: 4),
                                    txt('Opens at 6:00 PM', 11, color: C.slate500),
                                  ])
                                else
                                  pill('OPEN', bg: C.emerald100, fg: C.emerald700, size: 12, radius: 8, pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                              ]),
                              if (closed)
                                Container(
                                  margin: const EdgeInsets.only(top: 12),
                                  padding: const EdgeInsets.only(top: 10),
                                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.slate200))),
                                  child: txt('Ordering not available now · Opens at 6:00 PM for night snacks', 12, color: C.slate500),
                                ),
                            ]),
                          ),
                        ),
                      );
                    }),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// `animate-spin`
class _Spin extends StatefulWidget {
  const _Spin({required this.child});
  final Widget child;
  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(turns: _c, child: widget.child);
}


/// Compact floating sheet: slides up from the bottom, sits above the screen edges (like the dock),
/// and slides away when closed or tapped outside. [builder] gets the animated close for its own buttons.
class SheetShell extends StatefulWidget {
  const SheetShell({super.key, required this.onClose, required this.builder});
  final VoidCallback onClose;
  final Widget Function(VoidCallback close) builder;
  @override
  State<SheetShell> createState() => _SheetShellState();
}

class _SheetShellState extends State<SheetShell> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320))..forward();

  Future<void> _close() async {
    await _c.reverse();
    if (mounted) widget.onClose();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(onTap: _close, child: FadeTransition(opacity: _c, child: Container(color: C.a(Colors.black, 0.45)))),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(slide),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: EdgeInsets.fromLTRB(12, 0, 12, 12 + MediaQuery.of(context).padding.bottom),
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: C.a(Colors.black, 0.18), blurRadius: 30, offset: const Offset(0, 12))],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Center(
                    child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(color: C.slate200, borderRadius: BorderRadius.circular(99))),
                  ),
                  widget.builder(_close),
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Icon tile + title + subtitle + small close button, shared by the help and policy sheets.
Widget _sheetHeader(String icon, Color color, String title, String subtitle, VoidCallback close) => Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: C.a(color, 0.12), borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.center,
        child: LIcon(icon, size: 20, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          txt(title, 15, w: w7, font: F.display, maxLines: 1),
          txt(subtitle, 11, color: C.slate500, maxLines: 1),
        ]),
      ),
      Tap(
        onTap: close,
        child: Container(
          width: 30, height: 30,
          decoration: const BoxDecoration(color: C.slate100, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const LIcon('X', size: 14, color: C.slate500),
        ),
      ),
    ]);

// ======================= Customer care =======================
class CustomerCareModal extends StatefulWidget {
  const CustomerCareModal({super.key, required this.onClose});
  final VoidCallback onClose;
  @override
  State<CustomerCareModal> createState() => _CustomerCareModalState();
}

class _CustomerCareModalState extends State<CustomerCareModal> {
  static const _desks = [('Main Canteen', '+91 98450 00111'), ('Advance Block', '+91 98450 00222')];

  bool _submitted = false;
  int? _copied; // which desk number was just copied
  final _issue = TextEditingController();

  @override
  void initState() {
    super.initState();
    _issue.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _issue.dispose();
    super.dispose();
  }

  void _copy(int i) {
    Clipboard.setData(ClipboardData(text: _desks[i].$2.replaceAll(' ', '')));
    setState(() => _copied = i);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _copied == i) setState(() => _copied = null);
    });
  }

  Widget _desk(int i) {
    final copied = _copied == i;
    return Expanded(
      child: Tap(
        onTap: () => _copy(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: copied ? C.emerald50 : C.cream,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: copied ? C.emerald200 : C.a(C.amber200, 0.8)),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                txt(copied ? 'Copied!' : _desks[i].$1, 10, w: w6, color: copied ? C.emerald700 : C.slate500),
                const SizedBox(height: 2),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: txt(_desks[i].$2, 12, w: w7, font: F.mono, color: C.slate800)),
              ]),
            ),
            LIcon(copied ? 'Check' : 'Copy', size: 14, color: copied ? C.emerald600 : C.slate400),
          ]),
        ),
      ),
    );
  }

  Widget _form() {
    final canSend = _issue.text.trim().isNotEmpty;
    return Column(key: const ValueKey('form'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      txt('CALL A DESK', 10, w: w7, color: C.slate400, spacing: 0.6),
      const SizedBox(height: 8),
      Row(children: [_desk(0), const SizedBox(width: 10), _desk(1)]),
      const SizedBox(height: 16),
      txt('OR MESSAGE US', 10, w: w7, color: C.slate400, spacing: 0.6),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.fromLTRB(14, 4, 5, 4),
        decoration: BoxDecoration(color: C.slate50, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.slate200)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _issue,
              minLines: 1,
              maxLines: 3,
              style: ts(12, color: C.slate800),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                hintText: 'UPI deducted but order delayed…',
                hintStyle: ts(12, color: C.slate400),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Tap(
            onTap: canSend
                ? () {
                    FocusScope.of(context).unfocus();
                    setState(() => _submitted = true);
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36, height: 36,
              decoration: BoxDecoration(gradient: canSend ? C.brandGradient : null, color: canSend ? null : C.slate200, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: LIcon('Send', size: 15, color: canSend ? Colors.white : C.slate400),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const LIcon('ShieldCheck', size: 12, color: C.emerald600),
        const SizedBox(width: 4),
        Flexible(child: txt('Refunds are credited automatically to your UPI ID', 10, color: C.slate400)),
      ]),
    ]);
  }

  Widget _done(VoidCallback close) => Container(
        key: const ValueKey('done'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.emerald50, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.emerald200)),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(color: C.emerald500, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const LIcon('Check', size: 18, color: Colors.white, strokeWidth: 3),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              txt('Ticket #CC-8821 created', 13, w: w7, color: C.emerald800),
              txt('The canteen manager has been notified. Expect a reply within 3 minutes.', 11, color: C.slate600),
            ]),
          ),
          const SizedBox(width: 8),
          Tap(
            onTap: close,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: C.emerald600, borderRadius: BorderRadius.circular(99)),
              child: txt('Done', 12, w: w7, color: Colors.white),
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return SheetShell(
      onClose: widget.onClose,
      builder: (close) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sheetHeader('HelpCircle', C.brand, 'Need help?', 'Campus help desk · replies in minutes', close),
        const SizedBox(height: 16),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: _submitted ? _done(close) : _form()),
        ),
      ]),
    );
  }
}

// ======================= Policies =======================
class _Policy {
  const _Policy(this.tab, this.title, this.subtitle, this.icon, this.color, this.points);
  final String tab, title, subtitle, icon;
  final Color color;
  final List<(String, String)> points; // (heading, text); heading may be empty
}

const _policies = {
  'refund': _Policy('Refund', 'Refund & Cancellation', 'When and how you get money back', 'RefreshCw', C.emerald600, [
    ('Full refund before cooking', "Cancel while a bill is 'Waiting for Acceptance' or 'Accepted' and 100% goes back to the UPI handle you paid from."),
    ('Out-of-stock items', 'If one item runs out, it is refunded right away while the rest of the bill continues.'),
    ('Stall emergencies', 'All unfulfilled orders are refunded automatically within 24 hours through the payment gateway.'),
  ]),
  'terms': _Policy('Terms', 'Terms of Service', 'Using Brunchy on campus', 'FileText', C.blue600, [
    ('', 'Brunchy is the campus food ordering platform for real-time menus and queue-free counter pickup.'),
    ('', 'Collect your food within the preparation window by saying your 3-digit pickup code at the counter.'),
  ]),
  'privacy': _Policy('Privacy', 'Privacy Policy', 'DPDP Act 2023 compliant', 'Shield', C.purple600, [
    ('', 'We collect your name, mobile number and optional registration number only for pickup verification and SMS alerts.'),
    ('', 'We never store GPS coordinates or payment credentials on our servers.'),
  ]),
};

/// Refund, Terms and Privacy in one compact sheet, with a switcher to hop between them without closing.
class PolicyModal extends StatefulWidget {
  const PolicyModal({super.key, required this.kind, required this.onClose});
  final String kind; // 'refund' | 'terms' | 'privacy'
  final VoidCallback onClose;
  @override
  State<PolicyModal> createState() => _PolicyModalState();
}

class _PolicyModalState extends State<PolicyModal> {
  late String _kind = _policies.containsKey(widget.kind) ? widget.kind : 'refund';

  Widget _switcher() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: C.slate100, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          for (final e in _policies.entries)
            Expanded(
              child: Tap(
                onTap: () => setState(() => _kind = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: _kind == e.key ? Colors.white : C.a(Colors.white, 0),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _kind == e.key ? [BoxShadow(color: C.a(Colors.black, 0.06), blurRadius: 6, offset: const Offset(0, 2))] : null,
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    LIcon(e.value.icon, size: 13, color: _kind == e.key ? e.value.color : C.slate400),
                    const SizedBox(width: 5),
                    txt(e.value.tab, 12, w: w7, color: _kind == e.key ? C.slate800 : C.slate500),
                  ]),
                ),
              ),
            ),
        ]),
      );

  Widget _points(_Policy p) => Column(key: ValueKey(_kind), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < p.points.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == p.points.length - 1 ? 0 : 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(color: C.a(p.color, 0.12), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: txt('${i + 1}', 11, w: w7, font: F.mono, color: p.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (p.points[i].$1.isNotEmpty) ...[txt(p.points[i].$1, 12, w: w7, color: C.slate800), const SizedBox(height: 2)],
                    txt(p.points[i].$2, 12, color: C.slate600, height: 1.45),
                  ]),
                ),
              ),
            ]),
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    final p = _policies[_kind]!;
    return SheetShell(
      onClose: widget.onClose,
      builder: (close) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(key: ValueKey(_kind), child: _sheetHeader(p.icon, p.color, p.title, p.subtitle, close)),
        ),
        const SizedBox(height: 14),
        _switcher(),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
          child: SingleChildScrollView(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: _points(p)),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Tap(
          onTap: close,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: C.slate900, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: txt('Got it', 13, w: w7, color: Colors.white),
          ),
        ),
      ]),
    );
  }
}
