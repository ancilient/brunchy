// PayModal.tsx, CheckoutShortageModal.tsx, CanteenSelectorModal.tsx, CustomerCareModal.tsx
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../payments/payment_mode.dart';
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

  /// Android back: never interrupt a payment check; otherwise cancel the hold.
  bool handleBack() {
    if (_verifying) return true;
    AppScope.read(context).cancelCheckoutHold();
    widget.onClose();
    return true;
  }

  Future<void> _payWithRazorpay() async {
    setState(() => _verifying = true);
    try {
      final id = await AppScope.read(context).completeRazorpayPayment();
      if (id != null) widget.onPaymentSuccess(id);
    } on ApiException catch (e) {
      if (mounted) showAlert(context, e.message);
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
    final mins = (s.holdSecondsLeft / 60).floor();
    final secs = (s.holdSecondsLeft % 60).toString().padLeft(2, '0');
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
                txt('Opening Razorpay…', 16, w: w7, align: TextAlign.center),
                const SizedBox(height: 4),
                txt('Complete payment in the Razorpay window. Never charged twice.', 12, color: C.slate500, align: TextAlign.center),
              ]),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: C.slate50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.slate100),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                txt('Pay securely with Razorpay', 14, w: w7),
                const SizedBox(height: 6),
                txt(paymentModeNote(s.pendingPayment), 12, color: C.slate500),
                const SizedBox(height: 10),
                txt('Hold expires in $mins:$secs', 11, w: w6, color: C.brand),
              ]),
            ),
            const SizedBox(height: 20),
            GradientButton(
              onTap: _payWithRazorpay,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: txt('Pay ₹${fmtNum(order.total)} with Razorpay', 14, w: w7, color: Colors.white, align: TextAlign.center),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const LIcon('ShieldCheck', size: 14, color: C.emerald600),
              const SizedBox(width: 6),
              Flexible(child: txt('Razorpay Checkout · Instant refund if stall rejects', 11, color: C.slate400, align: TextAlign.center)),
            ]),
          ],
        ]),
      ),
    );
  }
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
                                      Row(mainAxisSize: MainAxisSize.min, children: [const LIcon('Clock', size: 14, color: C.slate500), const SizedBox(width: 4), txt(c.hours, 12, color: C.slate500)]),
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
                                    txt('Hours ${c.hours}', 11, color: C.slate500),
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
  final _issue = TextEditingController();
  bool _submitted = false;

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

  /// The latest Order ID, so Customer Care can find the order quickly.
  String _orderRef(AppState s) => s.orders.isNotEmpty ? s.orders.first.orderCode : '';

  Future<void> _open(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      final what = uri.scheme == 'mailto' ? 'an email app' : uri.scheme == 'tel' ? 'the dialer' : 'WhatsApp';
      showAlert(context, 'Could not open $what on this phone.');
    }
  }

  /// mailto: with the subject and body filled in (Order ID and name), so the student only has to tap Send.
  Uri _mail(AppState s, String message) {
    final ref = _orderRef(s);
    final lines = [
      if (message.isNotEmpty) message,
      if (message.isNotEmpty) '',
      'Name: ${s.currentUser.name}',
      if (ref.isNotEmpty) 'Order ID: $ref',
    ];
    final subject = ref.isEmpty ? 'Brunchy help' : 'Brunchy help - $ref';
    // Uri.queryParameters would turn spaces into '+', which some mail apps show literally; encode by hand.
    return Uri.parse('mailto:${s.supportEmail}?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(lines.join('\n'))}');
  }

  Uri _whatsApp(AppState s) {
    final ref = _orderRef(s);
    final text = ref.isEmpty ? 'Hi, I need help with Brunchy.' : 'Hi, I need help with my Brunchy order $ref.';
    return Uri.parse('https://wa.me/${s.supportWhatsapp}?text=${Uri.encodeComponent(text)}');
  }

  Widget _contact(String icon, String label, String value, VoidCallback onTap) => Expanded(
        child: Tap(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(color: C.cream, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.a(C.amber200, 0.8))),
            child: Column(children: [
              LIcon(icon, size: 18, color: C.brand),
              const SizedBox(height: 4),
              txt(label, 12, w: w7, color: C.slate800),
              const SizedBox(height: 2),
              FittedBox(fit: BoxFit.scaleDown, child: txt(value, 10, color: C.slate500)),
            ]),
          ),
        ),
      );

  Widget _form(AppState s) {
    final email = s.supportEmail, phone = s.supportPhone, whatsapp = s.supportWhatsapp;
    final canSend = _issue.text.trim().isNotEmpty && email != null;
    final contacts = <Widget>[
      if (email != null) _contact('Mail', 'Email', email, () => _open(_mail(s, ''))),
      if (phone != null) _contact('Phone', 'Call', phone, () => _open(Uri(scheme: 'tel', path: phone))),
      if (whatsapp != null) _contact('MessageCircle', 'WhatsApp', '+$whatsapp', () => _open(_whatsApp(s))),
    ];
    final ref = _orderRef(s);
    return Column(key: const ValueKey('form'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (contacts.isEmpty)
        txt('Customer Care contacts are not set up yet. Please ask at the canteen counter.', 12, color: C.slate600)
      else ...[
        txt('CONTACT US', 10, w: w7, color: C.slate400, spacing: 0.6),
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 0; i < contacts.length; i++) ...[if (i > 0) const SizedBox(width: 8), contacts[i]],
        ]),
      ],
      if (email != null) ...[
        const SizedBox(height: 16),
        txt('OR DESCRIBE THE PROBLEM', 10, w: w7, color: C.slate400, spacing: 0.6),
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
                  hintText: 'Paid but order delayed…',
                  hintStyle: ts(12, color: C.slate400),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Tap(
              onTap: canSend
                  ? () async {
                      FocusScope.of(context).unfocus();
                      await _open(_mail(s, _issue.text.trim()));
                      if (mounted) setState(() => _submitted = true);
                    }
                  : null,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(gradient: canSend ? C.brandGradient : null, color: canSend ? null : C.slate200, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: LIcon('Send', size: 15, color: canSend ? Colors.white : C.slate400),
              ),
            ),
          ]),
        ),
      ],
      if (ref.isNotEmpty) ...[
        const SizedBox(height: 10),
        txt('Your latest Order ID: $ref', 10, color: C.slate400, align: TextAlign.center),
      ],
    ]);
  }

  Widget _done(VoidCallback close) => Container(
        key: const ValueKey('done'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.emerald50, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.emerald200)),
        child: Row(children: [
          Expanded(child: txt('Your email app opened with your message. Tap Send there to reach Customer Care.', 12, color: C.slate700)),
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
        _sheetHeader('HelpCircle', C.brand, 'Need help?', 'Email, call or WhatsApp Customer Care', close),
        const SizedBox(height: 16),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: _submitted ? _done(close) : _form(AppScope.of(context))),
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
