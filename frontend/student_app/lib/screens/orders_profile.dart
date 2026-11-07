// OrdersPage.tsx and ProfilePage.tsx
import 'dart:ui' show ImageFilter;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../state/models.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key, required this.onBackToMenu, required this.onOpenCustomerCare});
  final VoidCallback onBackToMenu;
  final VoidCallback onOpenCustomerCare;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final bills = s.getStudentBills();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 416),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.a(C.amber200, 0.6)))),
              child: Row(children: [
                Tap(
                  onTap: onBackToMenu,
                  child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: C.amber200)),
                      child: const Center(child: LIcon('ArrowLeft', size: 16, color: C.slate700))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    txt('My Orders', 20, w: w7, font: F.display),
                    txt('Live tokens & bills', 11, color: C.slate500),
                  ]),
                ),
                Tap(
                  onTap: onOpenCustomerCare,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: C.orange50, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.orange200)),
                    child: Row(children: [const LIcon('HelpCircle', size: 16, color: C.brand), const SizedBox(width: 6), txt('Customer Care', 12, w: w7, color: C.brand)]),
                  ),
                ),
              ]),
            ),
            if (bills.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
                decoration: card(border: C.a(C.amber200, 0.6)),
                child: Column(children: [
                  Container(width: 64, height: 64, decoration: const BoxDecoration(color: C.cream, shape: BoxShape.circle),
                      child: const Center(child: LIcon('ShoppingBag', size: 32, color: C.brand))),
                  const SizedBox(height: 12),
                  txt('No Orders Yet', 16, w: w7, color: C.slate800),
                  const SizedBox(height: 4),
                  txt('Order from the canteen to receive your 3-digit pickup code!', 12, color: C.slate500, align: TextAlign.center),
                  const SizedBox(height: 20),
                  GradientButton(onTap: onBackToMenu, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: txt('Explore Menu', 12, w: w7, color: Colors.white)),
                ]),
              )
            else
              for (final b in bills) Padding(padding: const EdgeInsets.only(bottom: 16), child: _BillCard(bill: b)),
          ]),
        ),
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill});
  final StallBill bill;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    final b = bill;
    final isWaiting = b.status == 'waiting_for_acceptance';
    final isAccepted = const ['accepted', 'preparing', 'ready'].contains(b.status);
    final isCompleted = b.status == 'completed' || b.status == 'collected' || b.isBlurredSealed;
    final isRefunded = b.status == 'refunded' || b.status == 'rejected';
    final isExpired = b.status == 'expired';

    Widget badge;
    if (isWaiting) {
      badge = _Pulse(child: _statusPill('Waiting for Acceptance', C.amber100, C.amber800, const LIcon('Clock', size: 14, color: C.amber600)));
    } else if (isAccepted) {
      badge = _statusPill('Accepted & Cooking', C.emerald100, C.emerald800, const LIcon('Sparkles', size: 14, color: C.emerald600));
    } else if (isCompleted) {
      badge = _statusPill('Handed Over', C.slate200, C.slate700, const LIcon('Check', size: 14, color: C.slate700));
    } else if (isRefunded) {
      badge = _statusPill('Refunded', C.purple100, C.purple700, null);
    } else {
      badge = const SizedBox.shrink();
    }

    Widget codeBox;
    if (isRefunded || isExpired) {
      codeBox = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          txt(isExpired ? 'Pickup window expired' : b.status == 'rejected' ? 'The stall could not take this order' : 'Order cancelled', 12, w: w7, color: C.purple800, align: TextAlign.center),
          const SizedBox(height: 4),
          txt(
            (isExpired ? 'This bill can no longer be collected.' : '₹${fmtNum(b.total)} is being refunded to your original payment method.') +
                (b.cancelReason != null && !isExpired ? ' Reason: ${b.cancelReason}.' : ''),
            11, color: C.slate500, align: TextAlign.center),
        ]),
      );
    } else if (isWaiting) {
      codeBox = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          txt('Order sent; waiting for the stall to accept...', 12, w: w7, color: C.amber900, align: TextAlign.center),
          const SizedBox(height: 4),
          txt('Stall staff has been alerted. Your 3-digit pickup code will appear right here as soon as accepted.', 11, color: C.slate500, align: TextAlign.center),
        ]),
      );
    } else {
      codeBox = Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            txt('COUNTER PICKUP CODE:', 10, w: w7, color: C.slate500, spacing: 0.5),
            const SizedBox(height: 2),
            txt(b.pickupCode.isEmpty ? '---' : b.pickupCode, 36, w: w8, font: F.mono, color: C.brand, spacing: 3.6),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          txt('Estimated Time:', 10, w: w6, color: C.slate500),
          txt('~${b.estimatedTimeMins} mins (${b.estimatedReadyTime ?? 'Ready soon'})', 12, w: w7, font: F.mono),
          const SizedBox(height: 2),
          txt('Tell this code to counter staff', 10, w: w5, color: C.emerald700),
        ]),
      ]);
    }

    final content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Bill header
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.slate100))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              txt(b.stallName.toUpperCase(), 12, w: w6, color: C.slate500, spacing: 0.5),
              txt('Bill ${b.billNo.isEmpty ? '#ORDER' : b.billNo}', 16, w: w7, font: F.display),
            ]),
          ),
          badge,
        ]),
      ),
      // 3-digit pickup code box
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.a(C.orange50, 0.5), border: const Border(bottom: BorderSide(color: C.orange100))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          codeBox,
          if (isAccepted && !isCompleted)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: C.a(Colors.white, 0.8), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.a(C.amber200, 0.5))),
              child: txt('💡 Note: Works when the order is Ready. The vendor types it to hand over your food.', 10, color: C.slate500),
            ),
        ]),
      ),
      // Order details & items
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          txt('Ordered: ${formatTime2Digit(b.createdAt)}', 10, color: C.slate400),
          const SizedBox(height: 4),
          for (final it in b.items)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Expanded(
                  child: Text.rich(TextSpan(style: ts(12, w: w6, color: C.slate800), children: [
                    TextSpan(text: '${it.quantity}x ${it.productName}'),
                    if (it.itemStatus == 'unavailable_refunded') TextSpan(text: ' (Unavailable - Refunded)', style: ts(12, w: w7, color: C.rose600)),
                  ])),
                ),
                txt('₹${fmtNum(it.price * it.quantity)}', 12, font: F.mono),
              ]),
            ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.slate100))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              txt(isRefunded ? 'Refunded' : 'Total Paid', 12, w: w7),
              txt('₹${fmtNum(b.total)}', 12, w: w7, font: F.mono, color: C.brand),
            ]),
          ),
          if (isWaiting) ...[
            const SizedBox(height: 12),
            _action('Simulate Kitchen Acceptance', C.emerald50, C.emerald800, C.emerald200, const LIcon('Sparkles', size: 14, color: C.emerald600),
                () => s.vendorAcceptOrder(b.stallOrderId, 6)),
            const SizedBox(height: 8),
            _action('Cancel & Instant Refund (₹${fmtNum(b.total)})', C.rose50, C.rose700, C.rose200, null, () async {
              if (await showConfirm(context, 'Cancel this bill? You will receive an immediate full refund.')) s.cancelStudentBill(b.stallOrderId);
            }),
          ],
          if (isAccepted && !isCompleted) ...[
            const SizedBox(height: 12),
            GradientButton(
              onTap: () => s.handOverBill(b.stallOrderId),
              radius: 12,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const LIcon('Check', size: 14, color: Colors.white, strokeWidth: 3),
                const SizedBox(width: 6),
                Flexible(child: txt('Tell Code ${b.pickupCode} at Counter (Hand Over & Seal)', 12, w: w7, color: Colors.white, align: TextAlign.center)),
              ]),
            ),
          ],
        ]),
      ),
    ]);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isCompleted ? C.a(C.slate100, 0.7) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isCompleted ? C.slate300 : isWaiting ? C.amber300 : C.orange200),
        boxShadow: isCompleted ? null : [BoxShadow(color: C.a(Colors.black, isWaiting ? 0.05 : 0.08), blurRadius: isWaiting ? 3.0 : 8.0, offset: const Offset(0, 2))],
      ),
      child: Stack(children: [
        content,
        // Blurred / Sealed stamp overlay for completed orders
        if (isCompleted)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: Container(
                    color: C.a(C.slate200, 0.4),
                    alignment: Alignment.center,
                    child: Transform.rotate(
                      angle: -12 * math.pi / 180,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(color: C.a(Colors.white, 0.8), borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: C.a(C.slate600, 0.7), width: 4),
                            boxShadow: [BoxShadow(color: C.a(Colors.black, 0.1), blurRadius: 6, offset: const Offset(0, 4))]),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          txt('COMPLETED', 20, w: w8, font: F.display, color: C.slate700, spacing: 2),
                          txt('SEALED · CANNOT BE REUSED', 10, w: w7, color: C.slate500, spacing: 0.5),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _statusPill(String label, Color bg, Color fg, Widget? icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[icon, const SizedBox(width: 4)],
          txt(label, 11, w: w7, color: fg),
        ]),
      );

  Widget _action(String label, Color bg, Color fg, Color border, Widget? icon, VoidCallback onTap) => Tap(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[icon, const SizedBox(width: 6)],
            txt(label, 12, w: w7, color: fg),
          ]),
        ),
      );
}

/// `animate-pulse`
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: Tween<double>(begin: 1, end: 0.5).animate(_c), child: widget.child);
}

// ======================= Profile =======================
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.onSwitchCanteen, required this.onReorder, required this.onOpenCustomerCare, required this.onOpenPolicy});
  final VoidCallback onSwitchCanteen;
  final VoidCallback onReorder;
  final VoidCallback onOpenCustomerCare;
  final void Function(String kind) onOpenPolicy;

  Future<void> _reorder(BuildContext context, AppState s, Order order) async {
    if (s.cart.isNotEmpty && s.productById(s.cart.first.productId)?.canteenId != order.canteenId) {
      await showAlert(context, 'Your cart has items from another canteen. Clear it first to reorder from ${order.canteenName}.');
      return;
    }
    if (order.canteenId != s.selectedCanteenId) s.setSelectedCanteenId(order.canteenId);
    var added = 0;
    String problem = '';
    for (final it in order.bills.expand((b) => b.items)) {
      if (it.itemStatus == 'unavailable_refunded') continue;
      final p = s.productById(it.productId);
      if (p == null || !p.isActive || p.approvalStatus != 'published') {
        if (problem.isEmpty) problem = '${it.productName} is no longer on the menu.';
        continue;
      }
      final qty = math.min(it.quantity, p.stock);
      if (qty <= 0) {
        if (problem.isEmpty) problem = '${it.productName} is sold out.';
        continue;
      }
      final reason = s.addToCart(p, qty);
      if (reason == null) {
        added++;
      } else if (problem.isEmpty) {
        problem = reason;
      }
    }
    if (!context.mounted) return;
    if (added > 0) {
      await showAlert(context, problem.isNotEmpty ? 'Items added to your cart. Note: $problem' : 'Items added to your cart!');
      onReorder();
    } else {
      await showAlert(context, problem.isNotEmpty ? problem : 'Items from this order are currently out of stock.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final u = s.currentUser;
    final current = s.canteenById(s.selectedCanteenId) ?? s.canteens.first;
    final past = s.orders.where((o) => o.status == 'paid' && o.userId == u.userId).take(5).toList();

    Widget linkRow(String icon, Color iconColor, String label, VoidCallback onTap, {bool divider = true}) => Tap(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(border: divider ? const Border(bottom: BorderSide(color: C.slate100)) : null),
            child: Row(children: [
              LIcon(icon, size: 16, color: iconColor),
              const SizedBox(width: 10),
              Expanded(child: txt(label, 12, color: C.slate700)),
              const LIcon('ChevronRight', size: 16, color: C.slate400),
            ]),
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 416),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Profile header card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: card(),
              child: Row(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(gradient: C.brandGradientDiag, borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: C.a(C.orange500, 0.2), blurRadius: 6, offset: const Offset(0, 4))]),
                  alignment: Alignment.center,
                  child: txt(u.name.isEmpty ? '' : u.name.substring(0, 1), 18, w: w7, font: F.display, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    txt(u.name, 16, w: w7, font: F.display),
                    const SizedBox(height: 2),
                    txt('+91 ${u.phone}', 11, color: C.slate500, font: F.mono),
                    if (u.registerNo.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      pill('Reg: ${u.registerNo}', bg: C.amber50, fg: C.amber800, w: w6),
                    ],
                  ]),
                ),
                Tap(onTap: s.logoutStudent, child: const Padding(padding: EdgeInsets.all(8), child: LIcon('LogOut', size: 16, color: C.slate400))),
              ]),
            ),
            const SizedBox(height: 20),
            // Switch canteen
            Container(
              padding: const EdgeInsets.all(16),
              decoration: card(),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    txt('CURRENT ACTIVE CANTEEN:', 10, w: w7, color: C.slate400, spacing: 0.5),
                    txt(current.name, 14, w: w7, font: F.display),
                  ]),
                ),
                Tap(
                  onTap: onSwitchCanteen,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: C.orange50, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.a(C.orange200, 0.8))),
                    child: txt('Switch Canteen', 12, w: w7, color: C.brand),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            // Past orders & fast reorder
            Container(
              padding: const EdgeInsets.all(20),
              decoration: card(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 8),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.slate100))),
                  child: Row(children: [
                    Expanded(child: txt('Past Orders & Fast Reorder', 14, w: w7, font: F.display)),
                    txt('${past.length} previous', 11, color: C.slate400),
                  ]),
                ),
                if (past.isEmpty)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: txt('No past orders yet.', 12, color: C.slate400, align: TextAlign.center))
                else
                  for (final o in past)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: C.a(C.slate50, 0.7), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.a(C.slate200, 0.6))),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            txt(o.bills.expand((b) => b.items.map((i) => '${i.quantity}x ${i.productName}')).join(', '), 12, w: w7),
                            txt('${formatShortDate(o.createdAt)} · ₹${fmtNum(o.total)}', 10, color: C.slate400),
                          ]),
                        ),
                        const SizedBox(width: 12),
                        Tap(
                          onTap: () => _reorder(context, s, o),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.orange200)),
                            child: Row(children: [const LIcon('RotateCcw', size: 12, color: C.brand), const SizedBox(width: 4), txt('Reorder', 12, w: w7, color: C.brand)]),
                          ),
                        ),
                      ]),
                    ),
              ]),
            ),
            const SizedBox(height: 20),
            // Help & legal
            Container(
              padding: const EdgeInsets.all(20),
              decoration: card(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                txt('Help & Legal Policies', 14, w: w7, font: F.display),
                const SizedBox(height: 12),
                linkRow('HelpCircle', C.orange500, 'Campus Help Desk & Customer Care', onOpenCustomerCare),
                linkRow('RefreshCw', C.emerald500, 'Refund & Cancellation Policy', () => onOpenPolicy('refund')),
                linkRow('FileText', C.blue500, 'Terms of Service', () => onOpenPolicy('terms')),
                linkRow('Shield', C.purple500, 'Privacy Policy (DPDP Act 2023 Compliant)', () => onOpenPolicy('privacy'), divider: false),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The policy popup opened from Profile.
class PolicyModal extends StatelessWidget {
  const PolicyModal({super.key, required this.kind, required this.onClose});
  final String kind;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    Widget para(String bold, String rest) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text.rich(TextSpan(style: ts(12, color: C.slate600), children: [
            if (bold.isNotEmpty) TextSpan(text: bold, style: ts(12, w: w7, color: C.slate600)),
            TextSpan(text: rest),
          ])),
        );
    final List<Widget> body;
    if (kind == 'refund') {
      body = [
        para('1. Full Refund Before Cooking:', " Orders cancelled while in 'Waiting for Acceptance' or 'Accepted' before kitchen cooking begins are credited 100% to your original payment UPI handle."),
        para('2. Out-of-Stock Items:', ' If a specific item runs out, it is refunded immediately while the remaining bill items continue.'),
        para('3. Stall Emergencies:', ' All unfulfilled orders are automatically refunded within 24 hours via gateway route.'),
      ];
    } else if (kind == 'terms') {
      body = [
        para('', 'Brunchy is the campus food ordering technology platform providing real-time menu browsing and queue-free counter collections.'),
        para('', 'Students are expected to collect food within the designated preparation window by presenting their 3-digit pickup code.'),
      ];
    } else {
      body = [
        para('', 'We collect student name, mobile number, and optional registration number strictly for token verification and SMS pickup notifications.'),
        para('', 'We never store GPS coordinates or payment credentials on our servers.'),
      ];
    }
    return Stack(children: [
      Positioned.fill(child: Container(color: C.a(Colors.black, 0.6))),
      Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 384),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: C.slate100)),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                txt('${kind[0].toUpperCase()}${kind.substring(1)} Policy', 16, w: w7, font: F.display),
                const SizedBox(height: 8),
                ConstrainedBox(constraints: const BoxConstraints(maxHeight: 240), child: SingleChildScrollView(child: Column(children: body))),
                const SizedBox(height: 16),
                Tap(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: C.brand, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: txt('Close', 12, w: w7, color: Colors.white)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}
