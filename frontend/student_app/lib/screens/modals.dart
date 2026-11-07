// PayModal.tsx, CheckoutShortageModal.tsx, CanteenSelectorModal.tsx, CustomerCareModal.tsx
import 'package:flutter/material.dart';

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
      ['Google Pay', '⚡', 0xFFEFF6FF, 0xFFBFDBFE],
      ['PhonePe', '🟣', 0xFFFAF5FF, 0xFFE9D5FF],
      ['Paytm', '🔷', 0xFFF0F9FF, 0xFFBAE6FD],
      ['BHIM UPI', '🇮🇳', 0xFFECFDF5, 0xFFA7F3D0],
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
            Text(a[1] as String, style: const TextStyle(fontSize: 20)),
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

// ======================= Customer care =======================
class CustomerCareModal extends StatefulWidget {
  const CustomerCareModal({super.key, required this.onClose});
  final VoidCallback onClose;
  @override
  State<CustomerCareModal> createState() => _CustomerCareModalState();
}

class _CustomerCareModalState extends State<CustomerCareModal> {
  bool _submitted = false;
  final _issue = TextEditingController();

  @override
  void dispose() {
    _issue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Backdrop(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 384),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: C.slate100),
                boxShadow: [BoxShadow(color: C.a(Colors.black, 0.25), blurRadius: 50, offset: const Offset(0, 25))]),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.slate100))),
                  child: Row(children: [
                    Container(width: 32, height: 32, decoration: BoxDecoration(color: C.orange100, borderRadius: BorderRadius.circular(12)),
                        child: const Center(child: LIcon('Phone', size: 16, color: C.brand))),
                    const SizedBox(width: 8),
                    Expanded(child: txt('Brunchy Customer Care', 16, w: w7, font: F.display)),
                    _closeBtn(widget.onClose, size: 32, icon: 16),
                  ]),
                ),
                if (_submitted)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(children: [
                      Container(width: 48, height: 48, decoration: const BoxDecoration(color: C.emerald100, shape: BoxShape.circle),
                          child: const Center(child: LIcon('Check', size: 24, color: C.emerald700, strokeWidth: 3))),
                      const SizedBox(height: 12),
                      txt('Ticket #CC-8821 Created', 16, w: w7),
                      const SizedBox(height: 12),
                      txt('Our campus canteen manager has been notified. We will resolve your query within 3 minutes!', 12, color: C.slate500, align: TextAlign.center),
                      const SizedBox(height: 16),
                      Tap(
                        onTap: widget.onClose,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          decoration: BoxDecoration(color: C.brand, borderRadius: BorderRadius.circular(12)),
                          child: txt('Done', 12, w: w7, color: Colors.white),
                        ),
                      ),
                    ]),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: C.orange50, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.a(C.orange200, 0.6))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      txt('Emergency Canteen Helplines', 12, w: w7, color: C.brand),
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [txt('Main Canteen Desk:', 12, color: C.slate700), txt('+91 98450 00111', 12, w: w7, font: F.mono, color: C.slate700)]),
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [txt('Advance Block Desk:', 12, color: C.slate700), txt('+91 98450 00222', 12, w: w7, font: F.mono, color: C.slate700)]),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  txt('Have an issue with your order or payment?', 12, w: w6, color: C.slate700),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _issue,
                    minLines: 3,
                    maxLines: 3,
                    style: ts(12, color: C.slate800),
                    decoration: InputDecoration(
                      hintText: "e.g. UPI deducted but order delayed, or stall didn't have cheese...",
                      hintStyle: ts(12, color: C.slate400),
                      contentPadding: const EdgeInsets.all(12),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.slate200)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.brandLight, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Tap(
                    onTap: () {
                      if (_issue.text.trim().isEmpty) return;
                      FocusScope.of(context).unfocus();
                      setState(() => _submitted = true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: C.brand, borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: C.a(C.orange500, 0.2), blurRadius: 6, offset: const Offset(0, 4))]),
                      child: Center(child: txt('Send Message to Help Desk', 12, w: w7, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const LIcon('ShieldCheck', size: 14, color: C.emerald600),
                    const SizedBox(width: 4),
                    Flexible(child: txt('Refund queries are automatically credited to your UPI ID', 10, color: C.slate400)),
                  ]),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
