// CartScreen.tsx
import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../state/models.dart';
import '../ui/ad_slot.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';

/// The three pickup times as a wallet-style card stack: the other two show their title strip on top, the chosen
/// card sits in front, fully open. Tapping a strip slides that card to the front.
class _BreakSlotStack extends StatelessWidget {
  const _BreakSlotStack({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  static const _strip = 52.0; // visible part of a card behind
  static const _full = 116.0; // height of every card
  static const _slots = [
    // id, title, line, icon, gradient
    ('now', 'Now', 'Cook immediately', 'Flame', [C.brandLight, C.brand]),
    ('15_min_break', '15-min Break', 'Ready for short break', 'Clock', [C.amber500, C.amber700]),
    ('1_hour_break', '1-Hour Break', 'Ready for lunch time', 'UtensilsCrossed', [C.slate700, C.slate900]),
  ];

  @override
  Widget build(BuildContext context) {
    final front = _slots.indexWhere((x) => x.$1 == selected);
    // Back cards first (painted first), the chosen card last so it sits in front.
    final order = [for (var i = 0; i < _slots.length; i++) if (i != front) i, if (front >= 0) front];
    return SizedBox(
      height: _strip * (_slots.length - 1) + _full,
      child: Stack(children: [
        for (var pos = 0; pos < order.length; pos++)
          AnimatedPositioned(
            key: ValueKey(_slots[order[pos]].$1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            top: pos * _strip,
            // cards further back are a little narrower, which reads as depth
            left: (order.length - 1 - pos) * 7.0,
            right: (order.length - 1 - pos) * 7.0,
            height: _full,
            child: _card(_slots[order[pos]], order[pos] == front),
          ),
      ]),
    );
  }

  Widget _card((String, String, String, String, List<Color>) slot, bool isFront) {
    final (id, title, line, icon, colors) = slot;
    return Tap(
      scale: isFront ? 1 : 0.98,
      onTap: () => onSelect(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.fromLTRB(16, 13, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          border: Border.all(color: C.a(Colors.white, 0.14)),
          boxShadow: [BoxShadow(color: C.a(Colors.black, isFront ? 0.18 : 0.12), blurRadius: 18, offset: const Offset(0, -4), spreadRadius: -6)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(clipBehavior: Clip.none, children: [
          // large faint icon in the corner of the front card
          Positioned(right: -6, bottom: -18, child: Opacity(opacity: isFront ? 0.14 : 0, child: LIcon(icon, size: 84, color: Colors.white, strokeWidth: 1.6))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: C.a(Colors.white, 0.2), borderRadius: BorderRadius.circular(9)),
                alignment: Alignment.center,
                child: LIcon(icon, size: 15, color: Colors.white, strokeWidth: 2.3),
              ),
              const SizedBox(width: 10),
              Expanded(child: txt(title, 14, w: w7, color: Colors.white, font: F.display)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: isFront
                    ? Container(
                        key: const ValueKey('on'),
                        width: 22, height: 22,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: LIcon('Check', size: 13, color: colors.last, strokeWidth: 3),
                      )
                    : KeyedSubtree(key: const ValueKey('off'), child: txt(line, 10, w: w5, color: C.a(Colors.white, 0.8))),
              ),
            ]),
            const Spacer(),
            AnimatedOpacity(
              opacity: isFront ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    txt('PICKUP', 9, w: w7, color: C.a(Colors.white, 0.65), spacing: 1.4),
                    const SizedBox(height: 2),
                    txt(line, 15, w: w7, color: Colors.white),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: C.a(Colors.white, 0.18), borderRadius: BorderRadius.circular(99)),
                  child: txt('SELECTED', 9, w: w8, color: Colors.white, spacing: 0.8),
                ),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }
}

class CartScreen extends StatelessWidget {
  const CartScreen({super.key, required this.onBackToMenu, required this.onProceedToPay});
  final VoidCallback onBackToMenu;
  final VoidCallback onProceedToPay;

  /// White cards with no amber outline — depth comes from a soft shadow instead.
  BoxDecoration get _card => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: C.a(Colors.black, 0.08), blurRadius: 14, offset: const Offset(0, 4)),
          BoxShadow(color: C.a(C.orange500, 0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      );

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
    // Same as backend: only item total + platform fee % (no stall GST / convenience fee).
    final platformFee = subtotal * s.platformFeePercent / 100;
    final grandTotal = subtotal + platformFee;

    Future<void> checkout() async {
      final res = await s.startCheckout();
      if (!context.mounted) return;
      if (res.success) {
        onProceedToPay();
      } else if (!res.shortage && res.message != null) {
        showAlert(context, res.message!);
      }
    }

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
                decoration: _card,
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
              // Pre-order pickup time: a stack of cards, the chosen one in front
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Row(children: [
                  const LIcon('Clock', size: 15, color: C.brand, strokeWidth: 2.4),
                  const SizedBox(width: 6),
                  Expanded(child: txt('Pre-order for a break', 13, w: w7, font: F.display)),
                  txt('Tap a card', 10, w: w5, color: C.slate400),
                ]),
              ),
              _BreakSlotStack(selected: s.pickupSlot, onSelect: s.setPickupSlot),
              const SizedBox(height: 20),
              const AdShowcase(),
              const SizedBox(height: 20),
              _itemsCard(s, groups),
              const SizedBox(height: 16),
              // Bill breakdown
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _card,
                child: Column(children: [
                  _row(txt('Item Total', 12, color: C.slate600), txt('₹${fmtNum(subtotal)}', 12, w: w5, font: F.mono)),
                  if (platformFee > 0) ...[
                    const SizedBox(height: 8),
                    _row(
                      txt('Platform fee (${s.platformFeePercent}%)', 12, color: C.slate600),
                      txt('₹${platformFee.toStringAsFixed(2)}', 12, w: w5, font: F.mono),
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
      decoration: _card,
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
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [C.cream, C.amber50]),
          ),
          alignment: Alignment.center,
          child: Text(foodEmoji(p.name), style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 10),
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
          decoration: BoxDecoration(color: C.cream, borderRadius: BorderRadius.circular(99)),
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
