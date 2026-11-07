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
    double subtotal = 0, tax = 0;
    groups.forEach((stallId, lines) {
      final sub = lines.fold<double>(0, (a, l) => a + s.productById(l.productId)!.price * l.quantity);
      subtotal += sub;
      tax += sub * (s.stallById(stallId)?.gstRate ?? 0) / 100;
    });
    final grandTotal = subtotal + tax + s.convenienceFee;

    void checkout() {
      final res = s.startCheckout();
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
              // Stall item blocks
              for (final entry in groups.entries) ...[
                const SizedBox(height: 16),
                _stallBlock(s, entry.key, entry.value),
              ],
              const SizedBox(height: 16),
              // Bill breakdown
              Container(
                padding: const EdgeInsets.all(16),
                decoration: card(),
                child: Column(children: [
                  _row(txt('Item Total', 12, color: C.slate600), txt('₹${fmtNum(subtotal)}', 12, w: w5, font: F.mono)),
                  if (tax > 0) ...[const SizedBox(height: 8), _row(txt('GST Tax', 12, color: C.slate600), txt('₹${tax.toStringAsFixed(2)}', 12, w: w5, font: F.mono))],
                  const SizedBox(height: 8),
                  _row(Row(children: [txt('Convenience Fee', 12, w: w5, color: C.brand), const SizedBox(width: 4), const LIcon('Info', size: 12, color: C.slate400)]),
                      txt('₹${fmtNum(s.convenienceFee)}', 12, w: w5, font: F.mono, color: C.brand)),
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

  Widget _stallBlock(AppState s, int stallId, List<CartLine> lines) {
    final stall = s.stallById(stallId)!;
    final stallSub = lines.fold<double>(0, (a, l) => a + s.productById(l.productId)!.price * l.quantity);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: card(),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.slate100))),
          child: Row(children: [
            Expanded(child: txt(stall.name, 12, w: w7, font: F.display)),
            pill('Separate Bill & 3-Digit Code', bg: C.orange100, fg: C.brand, radius: 99),
          ]),
        ),
        for (final l in lines) ...[
          const SizedBox(height: 10),
          Builder(builder: (context) {
            final p = s.productById(l.productId)!;
            return Row(children: [
              Expanded(child: txt(p.name, 12, w: w5, maxLines: 1)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: C.cream, borderRadius: BorderRadius.circular(99), border: Border.all(color: C.amber200)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _round(const LIcon('Minus', size: 12, color: C.slate700), Colors.white, () => s.updateCartQuantity(p.id, -1)),
                  SizedBox(width: 26, child: txt('${l.quantity}', 12, w: w7, font: F.mono, align: TextAlign.center)),
                  _round(const LIcon('Plus', size: 12, color: Colors.white), C.brand, () => s.updateCartQuantity(p.id, 1)),
                ]),
              ),
              SizedBox(width: 58, child: txt('₹${fmtNum(p.price * l.quantity)}', 12, w: w7, font: F.mono, align: TextAlign.right)),
            ]);
          }),
        ],
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.only(top: 8),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.slate100))),
          child: _row(txt('Stall Subtotal:', 11, color: C.slate500), txt('₹${fmtNum(stallSub)}', 11, w: w7, font: F.mono, color: C.slate800)),
        ),
      ]),
    );
  }

  Widget _round(Widget icon, Color bg, VoidCallback onTap) => Tap(
        onTap: onTap,
        child: Container(width: 20, height: 20, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Center(child: icon)),
      );
}
