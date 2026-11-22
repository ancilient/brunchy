// CartScreen.tsx
import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../state/models.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key, required this.onBackToMenu, required this.onProceedToPay});
  final VoidCallback onBackToMenu;
  final VoidCallback onProceedToPay;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // Group cart items by stall
    final groups = <int, List<CartLine>>{};
    for (final l in s.cart) {
      final p = s.productById(l.productId);
      if (p != null) groups.putIfAbsent(p.stallId, () => []).add(l);
    }
    double subtotal = 0;
    groups.forEach((stallId, lines) {
      final sub = lines.fold<double>(0, (a, l) => a + s.productById(l.productId)!.price * l.quantity);
      subtotal += sub;
    });
    // Same rule as the server (which decides the real amounts): items + platform fee % + convenience fee %,
    // or items only while the student still has free first orders.
    final free = s.nextOrderFree;
    double fee(double pct) => free ? 0 : (subtotal * pct).round() / 100;
    final platformFee = fee(s.platformFeePercent);
    final convenienceFee = fee(s.convenienceFeePercent);
    final grandTotal = subtotal + platformFee + convenienceFee;

    Future<void> checkout() async {
      final res = await s.startCheckout();
      if (!context.mounted) return;
      if (res.success) {
        onProceedToPay();
      } else if (!res.shortage && res.message != null) {
        showAlert(context, res.message!);
      }
    }

    const slots = [
      ['now', 'Now', 'Cook immediately'],
      ['15_min_break', '15-min Break', 'Ready for short break'],
      ['1_hour_break', '1-Hour Break', 'Ready for lunch time'],
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 416),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Header
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.a(C.amber200, 0.6)))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    txt('My Cart', 20, w: w7, font: F.display),
                    const SizedBox(height: 2),
                    txt('${s.cartCanteen?.name ?? 'Canteen'} · ${s.cart.length} item${s.cart.length > 1 ? 's' : ''}', 12, color: C.slate500),
                  ]),
                ),
                if (s.cart.isNotEmpty)
                  Tap(
                    onTap: s.clearCart,
                    child: Row(children: [const LIcon('Trash2', size: 14, color: C.slate400), const SizedBox(width: 4), txt('Clear', 12, color: C.slate400)]),
                  ),
              ]),
            ),
            if (s.cart.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
                decoration: card(border: C.a(C.amber200, 0.6)),
                child: Column(children: [
                  Container(width: 64, height: 64, decoration: const BoxDecoration(color: C.cream, shape: BoxShape.circle),
                      child: const Center(child: LIcon('Store', size: 32, color: C.brand))),
                  const SizedBox(height: 12),
                  txt('Your Cart is Empty', 16, w: w7, color: C.slate800),
                  const SizedBox(height: 4),
                  txt('Choose freshly prepared burgers, juices and hot meals from your canteen!', 12, color: C.slate500, align: TextAlign.center),
                  const SizedBox(height: 20),
                  GradientButton(onTap: onBackToMenu, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: txt('Browse Menu', 12, w: w7, color: Colors.white)),
                ]),
              )
            else ...[
              // Pre-order pickup time
              Container(
                padding: const EdgeInsets.all(16),
                decoration: card(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [const LIcon('Clock', size: 16, color: C.brand), const SizedBox(width: 8), txt('Pre-order for a break:', 12, w: w7)]),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (var i = 0; i < slots.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: Tap(
                          onTap: () => s.setPickupSlot(slots[i][0]),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                            decoration: BoxDecoration(
                              color: s.pickupSlot == slots[i][0] ? C.orange50 : C.slate50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: s.pickupSlot == slots[i][0] ? C.brand : C.slate200),
                            ),
                            child: Column(children: [
                              txt(slots[i][1], 12, w: s.pickupSlot == slots[i][0] ? w7 : w4, color: s.pickupSlot == slots[i][0] ? C.brand : C.slate700, align: TextAlign.center),
                              const SizedBox(height: 2),
                              txt(slots[i][2], 9, color: C.slate400, align: TextAlign.center),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              _itemsCard(s, groups),
              const SizedBox(height: 16),
              // Bill breakdown
              Container(
                padding: const EdgeInsets.all(16),
                decoration: card(),
                child: Column(children: [
                  _row(txt('Item Total', 12, color: C.slate600), txt('₹${fmtNum(subtotal)}', 12, w: w5, font: F.mono)),
                  const SizedBox(height: 8),
                  _row(
                    txt('Platform fee (${fmtPct(s.platformFeePercent)}%)', 12, color: C.slate600),
                    txt(free ? 'FREE' : '₹${platformFee.toStringAsFixed(2)}', 12, w: w5, font: F.mono, color: free ? C.emerald600 : C.slate800),
                  ),
                  const SizedBox(height: 8),
                  _row(
                    txt('Convenience fee (${fmtPct(s.convenienceFeePercent)}%)', 12, color: C.slate600),
                    txt(free ? 'FREE' : '₹${convenienceFee.toStringAsFixed(2)}', 12, w: w5, font: F.mono, color: free ? C.emerald600 : C.slate800),
                  ),
                  if (free) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: C.emerald50, borderRadius: BorderRadius.circular(8)),
                      child: txt(
                        s.freeOrdersLeft == 1
                            ? 'Welcome offer: no fees on this order (your last free order).'
                            : 'Welcome offer: no fees on your first ${s.freeOrdersPerStudent} orders (${s.freeOrdersLeft} left).',
                        11, w: w6, color: C.emerald700),
                    ),
                  ],
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.only(top: 8),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.slate100))),
                    child: _row(txt('To Pay', 14, w: w7), txt('₹${fmtNum(grandTotal)}', 18, w: w7, font: F.mono, color: C.brand)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              GradientButton(
                onTap: checkout,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  txt('Pay ₹${fmtNum(grandTotal)}', 14, w: w7, color: Colors.white),
                  const SizedBox(width: 8),
                  const LIcon('ArrowRight', size: 16, color: Colors.white),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _row(Widget a, Widget b) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [a, b]);

  /// Every item in one card, a divider under each. Items stay grouped by stall, and each row names its stall,
  /// because every stall still gives its own bill and 3-digit code.
  Widget _itemsCard(AppState s, Map<int, List<CartLine>> groups) {
    final rows = [for (final e in groups.entries) for (final l in e.value) (s.stallById(e.key)!, l)];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: txt('Items', 13, w: w7, font: F.display)),
          pill('Separate bill & code per stall', bg: C.orange100, fg: C.brand, radius: 99),
        ]),
        const SizedBox(height: 4),
        for (var i = 0; i < rows.length; i++) _itemRow(s, rows[i].$1, rows[i].$2, divider: i < rows.length - 1),
      ]),
    );
  }

  Widget _itemRow(AppState s, Stall stall, CartLine l, {required bool divider}) {
    final p = s.productById(l.productId)!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: divider ? const Border(bottom: BorderSide(color: C.slate100)) : null),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            txt(p.name, 12, w: w6, maxLines: 1),
            const SizedBox(height: 2),
            Row(children: [
              dot(C.hex(stall.accentColor), 6),
              const SizedBox(width: 4),
              Flexible(child: txt(stall.name, 10, color: C.slate500, maxLines: 1)),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: C.cream, borderRadius: BorderRadius.circular(99), border: Border.all(color: C.amber200)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _round(const LIcon('Minus', size: 12, color: C.slate700), Colors.white, () => s.updateCartQuantity(p.id, -1)),
            SizedBox(width: 26, child: Center(child: RollingNumber(l.quantity, style: ts(12, w: w7, font: F.mono)))),
            _round(const LIcon('Plus', size: 12, color: Colors.white), C.brand, () => s.updateCartQuantity(p.id, 1)),
          ]),
        ),
        SizedBox(width: 54, child: txt('₹${fmtNum(p.price * l.quantity)}', 12, w: w7, font: F.mono, align: TextAlign.right)),
        // Remove the item completely in one tap.
        Tap(
          onTap: () => s.removeFromCart(p.id),
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(color: C.rose50, shape: BoxShape.circle, border: Border.all(color: C.rose200)),
              alignment: Alignment.center,
              child: const LIcon('X', size: 12, color: C.rose600, strokeWidth: 2.5),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _round(Widget icon, Color bg, VoidCallback onTap) => Tap(
        onTap: onTap,
        child: Container(width: 20, height: 20, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Center(child: icon)),
      );
}

/// 3.0 -> "3", 2.5 -> "2.5" for the fee labels.
String fmtPct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
