// StudentHome.tsx
import 'dart:async';

import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../state/models.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key, required this.onOpenCanteenPicker});
  final VoidCallback onOpenCanteenPicker;
  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  Object _tab = 'all'; // 'all' or a stall id
  final _search = TextEditingController();
  DateTime _now = DateTime.now();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) => setState(() => _now = DateTime.now()));
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _clock?.cancel();
    _search.dispose();
    super.dispose();
  }

  String _emoji(Product p) {
    final n = p.name.toLowerCase();
    if (n.contains('burger')) return '🍔';
    if (n.contains('fries')) return '🍟';
    if (n.contains('juice') || n.contains('shake') || n.contains('coffee')) return '🧃';
    if (n.contains('parotta') || n.contains('dosa') || n.contains('thali')) return '🫓';
    if (n.contains('tea') || n.contains('chai')) return '☕';
    return '🥪';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final current = s.canteenById(s.selectedCanteenId) ?? s.canteens.first;
    final stalls = s.stalls.where((st) => st.canteenId == s.selectedCanteenId).toList();
    final q = _search.text.trim().toLowerCase();
    final display = s.products.where((p) {
      if (p.canteenId != s.selectedCanteenId) return false;
      if (p.approvalStatus != 'published' || !p.isActive) return false;
      if (_tab != 'all' && p.stallId != _tab) return false;
      if (q.isNotEmpty) return p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q);
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 170), // clears the cart bar and the dock
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 416),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Top status row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                txt(formatClock(_now), 12, w: w6, color: C.slate800, font: F.mono),
                Tap(
                  onTap: widget.onOpenCanteenPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: C.orange50, borderRadius: BorderRadius.circular(99), border: Border.all(color: C.a(C.orange200, 0.6))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      txt(current.name, 12, w: w7, color: C.brand),
                      const SizedBox(width: 4),
                      const LIcon('ChevronDown', size: 12, color: C.brand),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            // Search
            SizedBox(
              height: 44,
              child: TextField(
                controller: _search,
                style: ts(12, color: C.slate800),
                decoration: InputDecoration(
                  hintText: 'Search burger, juice, fries, snacks...',
                  hintStyle: ts(12, color: C.slate400),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.zero,
                  prefixIcon: const Padding(padding: EdgeInsets.only(left: 14, right: 10), child: LIcon('Search', size: 16, color: C.slate400)),
                  prefixIconConstraints: const BoxConstraints(minWidth: 40),
                  suffixIcon: q.isEmpty && _search.text.isEmpty ? null : Tap(onTap: () => _search.clear(), child: Padding(padding: const EdgeInsets.only(right: 12, top: 14), child: txt('Clear', 10, w: w7, color: C.slate400))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: C.a(C.amber200, 0.8))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.brandLight, width: 2)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Stall tabs
            if (_search.text.isEmpty) ...[
              _CategoryPills(
                labels: ['All Items', for (final st in stalls) st.name],
                selected: _tab == 'all' ? 0 : stalls.indexWhere((st) => st.id == _tab) + 1,
                onSelect: (i) => setState(() => _tab = i == 0 ? 'all' : stalls[i - 1].id),
              ),
              const SizedBox(height: 28),
            ],
            // Food cards grouped by stall; switching category cross-fades the list.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(anim), child: child),
              ),
              layoutBuilder: (current, previous) =>
                  Stack(alignment: Alignment.topCenter, fit: StackFit.passthrough, children: [...previous, if (current != null) current]),
              child: Column(key: ValueKey(_tab), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final stall in stalls.where((st) => _tab == 'all' || st.id == _tab))
                  if (display.any((p) => p.stallId == stall.id))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(children: [
                            dot(C.hex(stall.accentColor), 10),
                            const SizedBox(width: 8),
                            Expanded(child: txt(stall.name, 14, w: w7, font: F.display)),
                            dot(C.emerald500, 6),
                            const SizedBox(width: 4),
                            txt('OPEN', 11, w: w6, color: C.emerald600),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        _grid([for (final p in display.where((p) => p.stallId == stall.id)) _productCard(context, s, p)]),
                      ]),
                    ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  /// 2-column grid with equal-height rows (grid-cols-2 gap-3.5)
  Widget _grid(List<Widget> cards) {
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: i + 2 < cards.length ? 14.0 : 0.0),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: cards[i]),
            const SizedBox(width: 14),
            Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox()),
          ]),
        ),
      ));
    }
    return Column(children: rows);
  }

  Widget _productCard(BuildContext context, AppState s, Product p) {
    CartLine? line;
    for (final l in s.cart) {
      if (l.productId == p.id) line = l;
    }
    final soldOut = p.stock <= 0;
    final low = p.stock > 0 && p.stock <= 3;
    return Opacity(
      opacity: soldOut ? 0.75 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: soldOut ? const Color(0xFFFAF6EE) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: C.a(C.amber100, 0.8)),
          boxShadow: soldOut
              ? null
              : [
                  BoxShadow(color: C.a(const Color(0xFFD7BE96), 0.2), blurRadius: 16, offset: const Offset(6, 6)),
                  BoxShadow(color: C.a(Colors.white, 0.9), blurRadius: 16, offset: const Offset(-6, -6)),
                ],
        ),
        child: Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: [
          Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: C.cream, shape: BoxShape.circle, border: Border.all(color: C.amber100)),
            alignment: Alignment.center,
            child: Text(_emoji(p), style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(height: 10),
          txt(p.name, 14, w: w7, maxLines: 1, align: TextAlign.center),
          const SizedBox(height: 2),
          txt('₹${fmtNum(p.price)}', 14, w: w8, font: F.mono),
          const SizedBox(height: 8),
          if (soldOut)
            _stockTag('SOLD OUT', C.a(C.amber100, 0.6), C.amber800, C.amber600)
          else if (low)
            _stockTag('ONLY ${p.stock} LEFT', C.amber100, C.amber900, C.amber600)
          else
            _stockTag('IN STOCK', C.emerald50, C.emerald800, C.emerald500),
          // At least 12 px, but able to give up a pixel when IntrinsicHeight measures the text slightly short.
          const Expanded(child: SizedBox(height: 12)),
          if (line != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: C.cream, borderRadius: BorderRadius.circular(99), border: Border.all(color: C.amber200)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _round(const LIcon('Minus', size: 12, color: C.slate700), Colors.white, () => s.updateCartQuantity(p.id, -1)),
                SizedBox(width: 30, child: Center(child: RollingNumber(line.quantity, style: ts(12, w: w7, font: F.mono)))),
                _round(const LIcon('Plus', size: 12, color: Colors.white), C.brand, () => s.updateCartQuantity(p.id, 1)),
              ]),
            )
          else
            Tap(
              scale: 0.95,
              onTap: soldOut
                  ? null
                  : () {
                      final reason = s.addToCart(p);
                      if (reason != null) showAlert(context, reason);
                    },
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: soldOut ? null : C.brandGradientDiag,
                  color: soldOut ? C.slate200 : null,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: soldOut ? C.a(Colors.black, 0.08) : C.a(C.orange500, 0.3), blurRadius: 6, offset: const Offset(0, 4))],
                ),
                child: Center(child: LIcon('Plus', size: 20, strokeWidth: 2.5, color: soldOut ? C.slate400 : Colors.white)),
              ),
            ),
          ]),
          // Small remove button inside the card's top-right corner, shown while the item is in the cart.
          Positioned(
            top: -6,
            right: -6,
            child: AnimatedScale(
              scale: line != null ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              curve: line != null ? Curves.easeOutBack : Curves.easeIn,
              child: Tap(
                onTap: line == null ? null : () => s.removeFromCart(p.id),
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(color: C.slate100, shape: BoxShape.circle, border: Border.all(color: C.slate200)),
                  alignment: Alignment.center,
                  child: const LIcon('X', size: 11, color: C.slate500, strokeWidth: 2.5),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _round(Widget icon, Color bg, VoidCallback onTap) => Tap(
        onTap: onTap,
        child: Container(width: 24, height: 24, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Center(child: icon)),
      );

  Widget _stockTag(String label, Color bg, Color fg, Color dotColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          dot(dotColor, 6),
          const SizedBox(width: 6),
          txt(label, 10, w: w7, color: fg, spacing: 0.5),
        ]),
      );
}

/// Category pills with one orange highlight that slides from the old pill to the tapped one.
/// Three layers of the same pills: white backgrounds, the moving highlight, then the labels on top.
class _CategoryPills extends StatefulWidget {
  const _CategoryPills({required this.labels, required this.selected, required this.onSelect});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  State<_CategoryPills> createState() => _CategoryPillsState();
}

class _CategoryPillsState extends State<_CategoryPills> {
  static const _duration = Duration(milliseconds: 320);
  static const _curve = Curves.easeOutCubic;

  final _scroll = ScrollController();
  final _stackKey = GlobalKey();
  List<GlobalKey> _keys = [];
  Rect? _highlight;
  bool _scrollPending = false;

  @override
  void didUpdateWidget(_CategoryPills old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _scrollPending = true;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Finds where the selected pill sits, moves the highlight there and scrolls it into the middle.
  void _measure() {
    if (!mounted) return;
    final i = widget.selected;
    if (i < 0 || i >= _keys.length) return;
    final pill = _keys[i].currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (pill == null || stack == null || !pill.hasSize) return;
    final rect = pill.localToGlobal(Offset.zero, ancestor: stack) & pill.size;
    if (rect != _highlight) setState(() => _highlight = rect);
    if (_scrollPending && _scroll.hasClients) {
      _scrollPending = false;
      final p = _scroll.position;
      final target = (rect.center.dx - p.viewportDimension / 2).clamp(p.minScrollExtent, p.maxScrollExtent);
      _scroll.animateTo(target, duration: _duration, curve: _curve);
    }
  }

  Widget _pill(int i, {required bool front}) {
    final selected = i == widget.selected;
    final weight = i == 0 ? w7 : w6;
    final box = Container(
      key: front ? _keys[i] : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        // Until the highlight has been measured, the back layer paints the selected pill itself.
        gradient: !front && selected && _highlight == null ? C.brandGradient : null,
        color: front ? null : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: front ? Colors.transparent : C.a(C.amber200, 0.6)),
      ),
      // Both layers build the label the same way (same style merge), so their pills are exactly the same width.
      child: front
          ? TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: selected ? Colors.white : C.slate700),
              duration: _duration,
              curve: _curve,
              builder: (_, color, __) => Text(widget.labels[i], style: ts(12, w: weight, color: color ?? C.slate700)),
            )
          : Text(widget.labels[i], style: ts(12, w: weight, color: Colors.transparent)),
    );
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: front ? GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => widget.onSelect(i), child: box) : box,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_keys.length != widget.labels.length) _keys = List.generate(widget.labels.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final h = _highlight;
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none, // let the highlight's shadow show
      child: Stack(key: _stackKey, children: [
        Row(children: [for (var i = 0; i < widget.labels.length; i++) _pill(i, front: false)]),
        if (h != null)
          AnimatedPositioned(
            duration: _duration,
            curve: _curve,
            left: h.left,
            top: h.top,
            width: h.width,
            height: h.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: C.brandGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: C.a(C.orange500, 0.3), blurRadius: 8, offset: const Offset(0, 3))],
              ),
            ),
          ),
        Row(children: [for (var i = 0; i < widget.labels.length; i++) _pill(i, front: true)]),
      ]),
    );
  }
}

/// Floating orange "View Cart" bar shown above the bottom navigation on Home.
class FloatingCartBar extends StatelessWidget {
  const FloatingCartBar({super.key, required this.onOpenCart});
  final VoidCallback onOpenCart;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final count = s.cartItemCount;
    if (count == 0) return const SizedBox.shrink();
    final total = s.cart.fold<double>(0, (sum, l) => sum + (s.productById(l.productId)?.price ?? 0) * l.quantity);
    final current = s.canteenById(s.selectedCanteenId) ?? s.canteens.first;
    return Center(
      child: ConstrainedBox(
        // Kept clearly narrower than the dock below it.
        constraints: const BoxConstraints(maxWidth: 300),
        child: Tap(
          onTap: onOpenCart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              gradient: C.brandGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: C.a(const Color(0xFF431407), 0.2), blurRadius: 25, offset: const Offset(0, 20), spreadRadius: -5)],
            ),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: C.a(Colors.white, 0.2), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: RollingNumber(count, style: ts(12, w: w7, font: F.mono, color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  txt(current.name.toUpperCase(), 10, w: w6, color: C.orange100, maxLines: 1),
                  txt('₹${fmtNum(total)}', 14, w: w7, font: F.mono, color: Colors.white),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  txt('View Cart', 12, w: w7, color: C.brand),
                  const SizedBox(width: 4),
                  txt('→', 12, w: w7, color: C.brand),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
