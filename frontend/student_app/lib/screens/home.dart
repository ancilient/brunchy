// StudentHome.tsx — layout after the Stitch "Pre-Book & Skip Queue" mockup:
// status row, hero, Skip-the-Queue pass, search, then the station deck (overview cards, or the tilted rail + menu panel).
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../state/models.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';

/// Soft warm shadow for the white cards (the mockup's `shadow-soft`).
List<BoxShadow> get _softShadow => [
      BoxShadow(color: C.a(C.brand, 0.07), blurRadius: 28, offset: const Offset(0, 8), spreadRadius: -4),
      BoxShadow(color: C.a(Colors.black, 0.03), blurRadius: 10, offset: const Offset(0, 3), spreadRadius: -2),
    ];

/// The emoji on a stall's tile, guessed from its name.
String _stallEmoji(String name) {
  final n = name.toLowerCase();
  if (n.contains('burger')) return '🍔';
  if (n.contains('juice') || n.contains('shake')) return '🍹';
  if (n.contains('chai') || n.contains('tea') || n.contains('coffee')) return '☕';
  if (n.contains('parotta') || n.contains('paratha')) return '🫓';
  if (n.contains('grill') || n.contains('bbq')) return '🍢';
  if (n.contains('south') || n.contains('meals')) return '🍛';
  return '🍽️';
}

/// A stall's photo (assets/stalls, transparent PNG), the colours behind it and the glow around the food.
/// Stalls without a photo get null and their emoji on their own accent colour.
(String?, List<Color>, Color) _stallLook(Stall st) {
  final n = st.name.toLowerCase();
  if (n.contains('burger')) return ('assets/stalls/burger.png', const [C.slate800, C.slate900], C.brandLight);
  if (n.contains('chai') || n.contains('snack')) return ('assets/stalls/chai.png', const [C.emerald700, Color(0xFF064E3B)], C.amber300);
  if (n.contains('juice') || n.contains('shake')) return ('assets/stalls/juice.png', const [C.indigo600, C.indigoBrand], C.amber500);
  if (n.contains('parotta') || n.contains('paratha')) return ('assets/stalls/parotta.png', const [C.amber600, C.amber800], C.amber200);
  final accent = C.hex(st.accentColor);
  return (null, [accent, Color.lerp(accent, Colors.black, 0.35)!], Colors.white);
}

/// The stall's picture with no background: its photo, or the emoji when it has none.
Widget _stallArt(Stall st, double size) {
  final (asset, _, _) = _stallLook(st);
  return asset != null
      ? Image.asset(asset, width: size, height: size, fit: BoxFit.contain, filterQuality: FilterQuality.medium)
      : SizedBox(width: size, height: size, child: Center(child: Text(_stallEmoji(st.name), style: TextStyle(fontSize: size * 0.6))));
}

/// OPEN / PAUSED / CLOSED for a stall (CLOSED also while the canteen is outside its hours).
(String, Color, Color, Color, Color) _stallState(bool canteenOpen, String stallStatus) => !canteenOpen || stallStatus == 'closed'
    ? ('CLOSED', C.slate400, C.slate500, C.slate100, C.slate200)
    : stallStatus == 'paused'
        ? ('PAUSED', C.amber500, C.amber700, C.amber50, C.amber200)
        : ('OPEN', C.emerald500, C.emerald700, C.emerald50, C.emerald200);

class StudentHome extends StatefulWidget {
  const StudentHome({super.key, required this.onOpenCanteenPicker, this.onOpenCart, this.onOpenOrders});
  final VoidCallback onOpenCanteenPicker;
  final VoidCallback? onOpenCart;
  final VoidCallback? onOpenOrders;
  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  int? _openStall; // null = deck overview; otherwise the stall shown in the rail view
  final _search = TextEditingController();
  final _deckKey = GlobalKey();
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

  void _scrollToDeck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _deckKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

  void _openStation(int stallId) {
    setState(() => _openStall = stallId);
    _scrollToDeck();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final current = s.canteenById(s.selectedCanteenId) ?? s.canteens.first;
    final canteenOpen = current.status == 'open';
    final stalls = s.stalls.where((st) => st.canteenId == s.selectedCanteenId).toList();
    final menu = s.products.where((p) => p.canteenId == s.selectedCanteenId && p.approvalStatus == 'published' && p.isActive).toList();
    final q = _search.text.trim().toLowerCase();
    final searching = _search.text.isNotEmpty;
    // The open station may belong to another canteen after switching: fall back to the overview.
    final openStall = stalls.where((st) => st.id == _openStall).firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 170), // clears the cart bar and the dock
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 416),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _statusRow(current, canteenOpen),
            const SizedBox(height: 14),
            // Hero and pass step aside while searching, so results come straight up under the search box.
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: searching
                  ? const SizedBox(width: double.infinity)
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _HeroCard(canteen: current, stalls: stalls, onOrderNow: () {
                        if (_openStall == null) {
                          final firstOpen = stalls.where((st) => st.status == 'open').firstOrNull;
                          if (firstOpen != null) return _openStation(firstOpen.id);
                        }
                        _scrollToDeck();
                      }),
                      const SizedBox(height: 14),
                    ]),
            ),
            _searchBox(),
            const SizedBox(height: 18),
            if (searching)
              ..._searchResults(context, s, stalls, menu, q, canteenOpen)
            else ...[
              _deckHeader(openStall),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 340),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(anim), alignment: Alignment.topCenter, child: child),
                ),
                layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topCenter, children: [...prev, if (cur != null) cur]),
                child: openStall == null
                    ? KeyedSubtree(key: const ValueKey('deck'), child: _deckOverview(stalls, menu, canteenOpen))
                    : KeyedSubtree(key: const ValueKey('rail'), child: _railView(context, s, stalls, openStall, menu, canteenOpen)),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  // ---------------- top row: live clock + canteen picker ----------------

  Widget _statusRow(Canteen current, bool canteenOpen) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: C.a(C.orange100, 0.7), borderRadius: BorderRadius.circular(99), border: Border.all(color: C.a(C.orange200, 0.6))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _PulseDot(color: canteenOpen ? C.emerald500 : C.slate400, pulse: canteenOpen),
          const SizedBox(width: 6),
          txt(formatClock(_now), 11, w: w7, color: C.slate800, font: F.mono),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: txt('•', 11, w: w7, color: C.orange500)),
          txt(canteenOpen ? 'Kitchens Active' : 'Closed', 11, w: w7, color: canteenOpen ? C.emerald700 : C.slate500),
        ]),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: Tap(
            onTap: widget.onOpenCanteenPicker,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: C.a(C.orange200, 0.9)),
                boxShadow: [BoxShadow(color: C.a(Colors.black, 0.04), blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const LIcon('MapPin', size: 13, color: C.brand, strokeWidth: 2.4),
                const SizedBox(width: 5),
                Flexible(child: txt(current.name, 12, w: w7, color: C.slate800, maxLines: 1)),
                const SizedBox(width: 4),
                const LIcon('ChevronDown', size: 13, color: C.slate400, strokeWidth: 2.5),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  // ---------------- search ----------------

  Widget _searchBox() {
    return Container(
      height: 48,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: _softShadow),
      child: TextField(
        controller: _search,
        style: ts(13, color: C.slate800, w: w5),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search burger, chai, fries, samosa...',
          hintStyle: ts(13, color: C.slate400),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          prefixIcon: const Padding(padding: EdgeInsets.only(left: 16, right: 10), child: LIcon('Search', size: 17, color: C.slate400, strokeWidth: 2.2)),
          prefixIconConstraints: const BoxConstraints(minWidth: 44),
          suffixIcon: _search.text.isEmpty
              ? null
              : Tap(
                  onTap: () => _search.clear(),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Center(
                      widthFactor: 1,
                      child: Container(
                        width: 24, height: 24,
                        decoration: const BoxDecoration(color: C.slate100, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const LIcon('X', size: 12, color: C.slate500, strokeWidth: 2.6),
                      ),
                    ),
                  ),
                ),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: C.a(C.amber200, 0.8))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: C.brandLight, width: 1.6)),
        ),
      ),
    );
  }

  List<Widget> _searchResults(BuildContext context, AppState s, List<Stall> stalls, List<Product> menu, String q, bool canteenOpen) {
    final hits = menu.where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q)).toList();
    final shown = stalls.where((st) => hits.any((p) => p.stallId == st.id)).toList();
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
        child: txt(hits.isEmpty ? 'No dishes found' : '${hits.length} ${hits.length == 1 ? 'dish' : 'dishes'} found', 12, w: w6, color: C.slate500),
      ),
      if (shown.isEmpty) _emptyState(_search.text.trim()),
      for (final st in shown)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _stallSection(context, s, st, hits.where((p) => p.stallId == st.id).toList(), canteenOpen),
        ),
    ];
  }

  Widget _emptyState(String? query) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: C.a(C.amber100, 0.9)), boxShadow: _softShadow),
      child: Column(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: C.cream, shape: BoxShape.circle, border: Border.all(color: C.amber100)),
          alignment: Alignment.center,
          child: const Text('🔍', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(height: 12),
        txt(query == null ? 'Nothing on the menu yet' : 'No dishes match "$query"', 14, w: w7, font: F.display, align: TextAlign.center),
        const SizedBox(height: 4),
        txt(query == null ? 'Check back a little later, stalls are still setting up.' : 'Try another name, like "chai" or "burger".', 12, color: C.slate500, align: TextAlign.center),
      ]),
    );
  }

  // ---------------- station deck ----------------

  Widget _deckHeader(Stall? openStall) {
    final rail = openStall != null;
    return Row(key: _deckKey, children: [
      txt('Food Stations', 15, w: w8, font: F.display, spacing: -0.2),
      const SizedBox(width: 8),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Container(
          key: ValueKey(rail),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: rail ? C.brand : C.orange100,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: rail ? C.brand : C.orange200),
          ),
          child: txt(rail ? 'RAIL VIEW' : 'DECK VIEW', 9, w: w8, color: rail ? Colors.white : C.brand, spacing: 0.8),
        ),
      ),
      const Spacer(),
      AnimatedOpacity(
        opacity: rail ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        child: IgnorePointer(
          ignoring: !rail,
          child: Tap(
            onTap: () => setState(() => _openStall = null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: C.orange50, borderRadius: BorderRadius.circular(99), border: Border.all(color: C.orange200)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const LIcon('ArrowLeft', size: 12, color: C.brand, strokeWidth: 2.6),
                const SizedBox(width: 4),
                txt('All Cards', 11, w: w7, color: C.brand),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  /// Overview: one card per stall with a peek at its first dishes. Tapping opens the rail view.
  Widget _deckOverview(List<Stall> stalls, List<Product> menu, bool canteenOpen) {
    final withItems = stalls.where((st) => menu.any((p) => p.stallId == st.id)).toList();
    if (withItems.isEmpty) return _emptyState(null);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < withItems.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _FadeSlideIn(
            delay: Duration(milliseconds: math.min(i, 5) * 70),
            child: _stationCard(withItems[i], menu.where((p) => p.stallId == withItems[i].id).toList(), canteenOpen),
          ),
        ),
    ]);
  }

  /// Full-width colour card: stall details on the left, its food photo large on the right (no white background).
  Widget _stationCard(Stall stall, List<Product> items, bool canteenOpen) {
    final (label, dotColor, _, _, _) = _stallState(canteenOpen, stall.status);
    final open = label == 'OPEN';
    final inStock = items.where((p) => p.stock > 0).length;
    final fromPrice = items.isEmpty ? null : items.map((p) => p.price).reduce(math.min);
    final (asset, colors, glow) = _stallLook(stall);
    final white70 = C.a(Colors.white, 0.75);
    return Tap(
      onTap: () => _openStation(stall.id),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          boxShadow: [BoxShadow(color: C.a(colors.last, 0.35), blurRadius: 22, offset: const Offset(0, 10), spreadRadius: -8)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          // soft light behind the food
          Positioned(
            right: -40,
            top: -30,
            child: Container(width: 210, height: 210, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [C.a(glow, 0.38), C.a(glow, 0)]))),
          ),
          Positioned(
            right: -14,
            bottom: -18,
            child: AnimatedOpacity(
              opacity: open ? 1 : 0.55,
              duration: const Duration(milliseconds: 250),
              child: asset != null
                  ? Image.asset(asset, width: 172, height: 172, fit: BoxFit.contain, filterQuality: FilterQuality.medium)
                  : SizedBox(width: 150, height: 150, child: Center(child: Text(_stallEmoji(stall.name), style: const TextStyle(fontSize: 76)))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 150, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: C.a(Colors.white, 0.16), borderRadius: BorderRadius.circular(99), border: Border.all(color: C.a(Colors.white, 0.25))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  dot(dotColor, 6),
                  const SizedBox(width: 5),
                  txt(label, 9, w: w8, color: Colors.white, spacing: 0.6),
                ]),
              ),
              const SizedBox(height: 8),
              txt(stall.name, 19, w: w7, color: Colors.white, font: F.display, maxLines: 1, spacing: -0.3),
              const SizedBox(height: 4),
              Row(children: [
                LIcon('Clock', size: 11, color: white70, strokeWidth: 2.4),
                const SizedBox(width: 4),
                Flexible(child: txt('~${stall.avgPrepMins} min · ${open ? '$inStock ready' : '${items.length} items'}', 11, w: w5, color: white70, maxLines: 1)),
              ]),
              const Spacer(),
              Row(children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(11, 6, 9, 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    txt('View menu', 11, w: w8, color: colors.last),
                    const SizedBox(width: 3),
                    LIcon('ArrowRight', size: 12, color: colors.last, strokeWidth: 2.8),
                  ]),
                ),
                if (fromPrice != null) ...[
                  const SizedBox(width: 8),
                  Flexible(child: txt('from ₹${fmtNum(fromPrice)}', 11, w: w6, color: white70, maxLines: 1)),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _miniStatus(String label, Color dotColor, Color fg, Color bg, Color border) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99), border: Border.all(color: C.a(border, 0.7))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          dot(dotColor, 5),
          const SizedBox(width: 4),
          txt(label, 9, w: w8, color: fg, spacing: 0.3),
        ]),
      );

  /// Rail view: the chosen stall's menu on the left, the stall cards in a rail on the right.
  Widget _railView(BuildContext context, AppState s, List<Stall> stalls, Stall open, List<Product> menu, bool canteenOpen) {
    final railStalls = stalls.where((st) => menu.any((p) => p.stallId == st.id)).toList();
    // Same height for rail and panel, so the panel's footer sits at the bottom instead of mid-card.
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: _menuPanel(context, s, open, menu.where((p) => p.stallId == open.id).toList(), canteenOpen)),
      const SizedBox(width: 10),
      SizedBox(
        width: 92,
        child: Column(children: [
          for (final st in railStalls)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RailCard(
                art: _stallArt(st, 46),
                name: st.name,
                state: _stallState(canteenOpen, st.status),
                active: st.id == open.id,
                onTap: () => setState(() => _openStall = st.id),
              ),
            ),
          Tap(
            onTap: () => setState(() => _openStall = null),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: C.a(C.orange100, 0.7), borderRadius: BorderRadius.circular(14), border: Border.all(color: C.orange200)),
              child: Column(children: [
                const LIcon('ArrowLeft', size: 15, color: C.brand, strokeWidth: 2.6),
                const SizedBox(height: 2),
                txt('All Cards', 10, w: w7, color: C.brand),
              ]),
            ),
          ),
        ]),
      ),
    ]),
    );
  }

  Widget _menuPanel(BuildContext context, AppState s, Stall stall, List<Product> items, bool canteenOpen) {
    final (label, dotColor, fg, bg, border) = _stallState(canteenOpen, stall.status);
    final ordering = label == 'OPEN';
    final inCartHere = s.cart.where((l) => s.productById(l.productId)?.stallId == stall.id).fold<int>(0, (n, l) => n + l.quantity);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: C.a(C.orange100, 0.9)), boxShadow: _softShadow),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _stallArt(stall, 30),
                  const SizedBox(width: 6),
                  Flexible(child: txt(stall.name, 14, w: w8, font: F.display, maxLines: 1)),
                ]),
                const SizedBox(height: 5),
                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const LIcon('Clock', size: 10, color: C.slate400, strokeWidth: 2.4),
                    const SizedBox(width: 3),
                    txt('~${stall.avgPrepMins} mins', 10, w: w5, color: C.slate500),
                  ]),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
                    child: txt(ordering ? 'OPEN NOW' : label, 9, w: w8, color: fg, spacing: 0.3),
                  ),
                ]),
              ]),
            ),
            Tap(
              onTap: () => setState(() => _openStall = null),
              child: Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(color: C.slate100, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const LIcon('X', size: 13, color: C.slate500, strokeWidth: 2.6),
              ),
            ),
          ]),
        ),
        Divider(height: 1, thickness: 1, color: C.a(C.slate100, 0.9)),
        if (!ordering)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: C.slate50, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.slate200)),
            child: txt(!canteenOpen ? 'Canteen is closed right now.' : stall.status == 'paused' ? 'Paused for a few minutes.' : 'Not taking orders right now.', 10, w: w5, color: C.slate600),
          ),
        // Rows slide in one after another each time a station opens.
        KeyedSubtree(
          key: ValueKey(stall.id),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Divider(height: 1, thickness: 1, color: C.a(C.slate100, 0.9))),
              _FadeSlideIn(
                delay: Duration(milliseconds: math.min(i, 7) * 60),
                child: AnimatedOpacity(opacity: ordering ? 1 : 0.55, duration: const Duration(milliseconds: 250), child: _compactRow(context, s, items[i])),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 6),
        const Spacer(),
        // Footer: selected station, and how many of its dishes are in the cart (the cart bar below does checkout)
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(color: C.a(C.orange50, 0.8), border: Border(top: BorderSide(color: C.a(C.orange100, 0.9)))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                txt('Selected Station', 9, w: w5, color: C.slate500),
                txt('${stall.name} · pickup', 11, w: w7, color: C.slate900, maxLines: 1),
              ]),
            ),
            if (inCartHere > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: C.orange200)),
                child: txt('$inCartHere in cart', 10, w: w7, color: C.brand),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  /// One dish in the narrow menu panel: tile, veg mark, name, line, price, stock, then + or a small stepper.
  Widget _compactRow(BuildContext context, AppState s, Product p) {
    CartLine? line;
    for (final l in s.cart) {
      if (l.productId == p.id) line = l;
    }
    final soldOut = p.stock <= 0;
    final low = p.stock > 0 && p.stock <= 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(children: [
        Opacity(
          opacity: soldOut ? 0.5 : 1,
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: const Color(0xFFFAFAF9), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.a(C.slate100, 0.9))),
            alignment: Alignment.center,
            child: Text(foodEmoji(p.name), style: const TextStyle(fontSize: 21)),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (p.isVeg != null) ...[Padding(padding: const EdgeInsets.only(top: 2), child: _vegMark(p.isVeg!, 11)), const SizedBox(width: 5)],
              Expanded(child: txt(p.name, 12, w: w7, color: soldOut ? C.slate500 : C.slate800, maxLines: 2, height: 1.25)),
            ]),
            if (p.description.isNotEmpty) ...[
              const SizedBox(height: 1),
              txt(p.description, 10, color: C.slate400, maxLines: 1),
            ],
            const SizedBox(height: 3),
            Row(children: [
              txt('₹${fmtNum(p.price)}', 12, w: w8, font: F.mono, color: soldOut ? C.slate400 : C.slate900),
              const SizedBox(width: 5),
              Flexible(
                child: soldOut
                    ? _stockTag('SOLD OUT', C.slate100, C.slate500, 8)
                    : low
                        ? _stockTag('ONLY ${p.stock} LEFT', C.amber100, C.amber800, 8)
                        : _stockTag('IN STOCK', C.emerald50, C.emerald600, 8),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, anim) => ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(anim), child: FadeTransition(opacity: anim, child: child)),
          child: line != null
              ? Container(
                  key: const ValueKey('stepper'),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: C.orange50, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.orange200)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _miniBtn('Minus', Colors.white, C.brand, () => s.updateCartQuantity(p.id, -1)),
                    SizedBox(width: 20, child: Center(child: RollingNumber(line.quantity, style: ts(12, w: w8, font: F.mono, color: C.slate900)))),
                    _miniBtn('Plus', C.brand, Colors.white, () {
                      if (line!.quantity >= p.stock) {
                        showAlert(context, 'Only ${p.stock} available in stock.');
                      } else {
                        s.updateCartQuantity(p.id, 1);
                      }
                    }),
                  ]),
                )
              : soldOut
                  ? SizedBox(key: const ValueKey('soldout'), width: 30, child: Center(child: txt('—', 12, w: w7, color: C.slate300)))
                  : Tap(
                      key: const ValueKey('add'),
                      scale: 0.88,
                      onTap: () {
                        final reason = s.addToCart(p);
                        if (reason != null) showAlert(context, reason);
                      },
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(color: C.orange50, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.orange200)),
                        alignment: Alignment.center,
                        child: const LIcon('Plus', size: 15, color: C.brand, strokeWidth: 3),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _miniBtn(String icon, Color bg, Color fg, VoidCallback onTap) => Tap(
        scale: 0.85,
        onTap: onTap,
        child: Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: C.a(Colors.black, 0.06), blurRadius: 2, offset: const Offset(0, 1))],
          ),
          alignment: Alignment.center,
          child: LIcon(icon, size: 12, color: fg, strokeWidth: 3),
        ),
      );

  // ---------------- search results: one stall card with full-width rows ----------------

  Widget _stallSection(BuildContext context, AppState s, Stall stall, List<Product> items, bool canteenOpen) {
    final (label, dotColor, fg, bg, border) = _stallState(canteenOpen, stall.status);
    final ordering = label == 'OPEN';
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: C.a(C.amber100, 0.9)), boxShadow: _softShadow),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(children: [
            _stallArt(stall, 40),
            const SizedBox(width: 10),
            Expanded(child: txt(stall.name, 14, w: w7, font: F.display, maxLines: 1)),
            _miniStatus(label, dotColor, fg, bg, border),
          ]),
        ),
        Divider(height: 1, thickness: 1, color: C.a(C.amber100, 0.9)),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) Padding(padding: const EdgeInsets.only(left: 64), child: Divider(height: 1, thickness: 1, color: C.a(C.slate100, 0.9))),
          AnimatedOpacity(opacity: ordering ? 1 : 0.55, duration: const Duration(milliseconds: 250), child: _compactRow(context, s, items[i])),
        ],
      ]),
    );
  }

  /// The Indian veg / non-veg mark: a square outline with a dot.
  Widget _vegMark(bool veg, [double size = 13]) {
    final c = veg ? C.emerald600 : C.rose600;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), border: Border.all(color: c, width: 1.3)),
      alignment: Alignment.center,
      child: dot(c, size * 0.4),
    );
  }

  Widget _stockTag(String label, Color bg, Color fg, [double size = 9]) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: txt(label, size, w: w8, color: fg, spacing: 0.3, maxLines: 1),
      );
}

// ---------------- tilted rail card ----------------

/// A stall card in the right-hand rail. Idle cards lean slightly towards the menu; the active one stands
/// straight, steps out towards the menu and gets an orange ring.
class _RailCard extends StatelessWidget {
  const _RailCard({required this.art, required this.name, required this.state, required this.active, required this.onTap});
  final Widget art; // the stall's photo (or emoji), no background
  final String name;
  final (String, Color, Color, Color, Color) state;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, _, fg, bg, _) = state;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: active ? 1 : 0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) {
        // idle: a gentle 10deg lean hinged on the right edge, scale .94 · active: upright, scale 1.03, 4 px towards the menu
        final ry = 10 * (1 - t) * math.pi / 180;
        final scale = 0.94 + 0.09 * t;
        return Opacity(
          opacity: 0.75 + 0.25 * t,
          child: Transform(
            alignment: Alignment.centerRight,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 1 / 900)
              ..translateByDouble(-4 * t, 0, 0, 1)
              ..rotateY(ry)
              ..scaleByDouble(scale, scale, 1, 1),
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 9),
              // Transparent card: no fill or shadow; only the selected one shows a thin orange ring.
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.a(C.orange500, t), width: 1.5),
              ),
              child: child,
            ),
          ),
        );
      },
      child: Tap(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Column(mainAxisSize: MainAxisSize.min, children: [
            art,
            const SizedBox(height: 4),
            txt(name, 11, w: w8, color: C.slate800, align: TextAlign.center, maxLines: 2, height: 1.15),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
              child: txt(label, 8, w: w8, color: fg, spacing: 0.5),
            ),
          ]),
          // active indicator bar on the edge facing the menu
          Positioned(
            left: -6,
            top: 4,
            bottom: 4,
            child: AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: Container(width: 3, decoration: BoxDecoration(color: C.brand, borderRadius: BorderRadius.circular(2))),
            ),
          ),
        ]),
      ),
    );
  }
}

// ---------------- hero banner ----------------

/// Premium dark banner: soft orange light on deep slate, a faint dot grid, and a frosted-glass gauge with the
/// canteen's live average prep time. Tapping anywhere opens the food stations.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.canteen, required this.stalls, required this.onOrderNow});
  final Canteen canteen;
  final List<Stall> stalls;
  final VoidCallback onOrderNow;

  @override
  Widget build(BuildContext context) {
    final canteenOpen = canteen.status == 'open';
    final open = stalls.where((st) => st.status == 'open').toList();
    final avgPrep = open.isEmpty ? 0 : (open.fold<int>(0, (sum, st) => sum + st.avgPrepMins) / open.length).round();
    final headline = ts(22, w: w7, color: Colors.white, font: F.display, height: 1.18, spacing: -0.5);

    return Tap(
      scale: 0.985,
      onTap: onOrderNow,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF111827), C.slate900, Color(0xFF1C1917)]),
          border: Border.all(color: C.a(Colors.white, 0.06)),
          boxShadow: [BoxShadow(color: C.a(C.slate900, 0.3), blurRadius: 28, offset: const Offset(0, 14), spreadRadius: -10)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          // soft light
          Positioned(
            right: -70,
            top: -90,
            child: Container(width: 260, height: 260, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [C.a(C.brandLight, 0.42), C.a(C.brand, 0.10), C.a(C.brand, 0)], stops: const [0, 0.5, 1]))),
          ),
          Positioned(
            left: -80,
            bottom: -110,
            child: Container(width: 240, height: 240, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [C.a(C.amber500, 0.16), C.a(C.amber500, 0)]))),
          ),
          const Positioned.fill(child: CustomPaint(painter: _HeroTexturePainter())),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _PulseDot(color: canteenOpen ? C.emerald500 : C.slate400, pulse: canteenOpen, size: 6),
                    const SizedBox(width: 7),
                    txt(canteenOpen ? 'LIVE · PRE-ORDER' : 'CLOSED NOW', 10, w: w7, color: C.slate400, spacing: 1.6),
                  ]),
                  const SizedBox(height: 12),
                  Text('Your canteen,', style: headline),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: 'now just a ', style: headline),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: ShaderMask(
                        shaderCallback: (r) => const LinearGradient(colors: [C.brandLight, C.amber500]).createShader(r),
                        child: Text('tap away.', style: headline),
                      ),
                    ),
                  ])),
                  const SizedBox(height: 8),
                  txt('Order ahead, skip the line and pick up the moment it’s ready.', 12, color: C.slate400, height: 1.45),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (canteenOpen)
                      _glassPill(const LIcon('Store', size: 12, color: C.slate300, strokeWidth: 2.2), '${open.length}/${stalls.length} stalls open')
                    else
                      _glassPill(const LIcon('Clock', size: 12, color: C.slate300, strokeWidth: 2.2), 'Opens ${canteen.openingTime}'),
                    _glassPill(null, 'Explore', trailing: const LIcon('ArrowRight', size: 12, color: C.brandLight, strokeWidth: 2.6), highlight: true),
                  ]),
                ]),
              ),
              const SizedBox(width: 12),
              _PrepGauge(minutes: canteenOpen && open.isNotEmpty ? avgPrep : null, share: stalls.isEmpty ? 0 : open.length / stalls.length),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _glassPill(Widget? lead, String label, {Widget? trailing, bool highlight = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: C.a(highlight ? C.brand : Colors.white, highlight ? 0.14 : 0.06),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: C.a(highlight ? C.brandLight : Colors.white, highlight ? 0.35 : 0.10)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (lead != null) ...[lead, const SizedBox(width: 6)],
          txt(label, 11, w: w6, color: highlight ? C.brandLight : C.slate200),
          if (trailing != null) ...[const SizedBox(width: 4), trailing],
        ]),
      );
}

/// Frosted-glass tile with a ring: the ring fills with the share of open stalls, the centre shows avg prep minutes.
class _PrepGauge extends StatelessWidget {
  const _PrepGauge({required this.minutes, required this.share});
  final int? minutes; // null when nothing is cooking
  final double share;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 98,
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          decoration: BoxDecoration(
            color: C.a(Colors.white, 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: C.a(Colors.white, 0.12)),
          ),
          child: Column(children: [
            SizedBox(
              width: 70, height: 70,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: share.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => CustomPaint(
                  painter: _RingPainter(v),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      txt(minutes == null ? '—' : '~$minutes', 20, w: w7, color: Colors.white, font: F.display, height: 1),
                      txt('min', 9, w: w6, color: C.slate400, spacing: 0.5),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            txt('AVG PREP', 9, w: w7, color: C.slate400, spacing: 1.4),
          ]),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.value);
  final double value;

  @override
  void paint(Canvas c, Size s) {
    final rect = (Offset.zero & s).deflate(4);
    c.drawArc(rect, 0, math.pi * 2, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 5..color = C.a(Colors.white, 0.08));
    if (value <= 0) return;
    c.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(colors: [C.amber500, C.brandLight, C.brand, C.amber500], transform: GradientRotation(-math.pi / 2)).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

/// Faint dot grid that fades out to the left, plus two thin arcs in the top-right corner.
class _HeroTexturePainter extends CustomPainter {
  const _HeroTexturePainter();

  @override
  void paint(Canvas c, Size s) {
    final dot = Paint();
    const step = 14.0;
    for (var x = step / 2; x < s.width; x += step) {
      final fade = (x / s.width).clamp(0.0, 1.0);
      dot.color = C.a(Colors.white, 0.055 * fade);
      for (var y = step / 2; y < s.height; y += step) {
        c.drawCircle(Offset(x, y), 0.9, dot);
      }
    }
    final arc = Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = C.a(Colors.white, 0.07);
    final center = Offset(s.width + 10, -10);
    c.drawCircle(center, 110, arc);
    c.drawCircle(center, 150, arc..color = C.a(Colors.white, 0.045));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------- small animations ----------------

/// Fades and slides its child up into place after [delay], once, when it first appears.
class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;
  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final _anim = CurvedAnimation(parent: _c, curve: const Cubic(0.16, 1, 0.3, 1));
  Timer? _start;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _start = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) {
        final v = _anim.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: Transform.scale(scale: 0.97 + 0.03 * v, child: child)),
        );
      },
      child: widget.child,
    );
  }
}

/// A status dot with a soft ring that keeps pulsing outwards (only while [pulse]).
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, required this.pulse, this.size = 8});
  final Color color;
  final bool pulse;
  final double size;
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _c.repeat();
  }

  @override
  void didUpdateWidget(_PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_c.isAnimating) _c.repeat();
    if (!widget.pulse && _c.isAnimating) _c.reset();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s, height: s,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        if (widget.pulse)
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Transform.scale(
              scale: 1 + _c.value * 1.4,
              child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: C.a(widget.color, 0.45 * (1 - _c.value)))),
            ),
          ),
        dot(widget.color, s),
      ]),
    );
  }
}

/// Gently floats its child up and down (the mockup's slow bounce).
class _Bob extends StatefulWidget {
  const _Bob({required this.child});
  final Widget child;
  @override
  State<_Bob> createState() => _BobState();
}

class _BobState extends State<_Bob> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(offset: Offset(0, -8 * Curves.easeInOut.transform(_c.value)), child: child),
      child: widget.child,
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
        constraints: const BoxConstraints(maxWidth: 320),
        child: Tap(
          onTap: onOpenCart,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: C.brandGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: C.a(Colors.white, 0.18)),
              boxShadow: [BoxShadow(color: C.a(C.brand, 0.35), blurRadius: 24, offset: const Offset(0, 12), spreadRadius: -6)],
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: C.a(Colors.white, 0.2), borderRadius: BorderRadius.circular(13)),
                child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                  const LIcon('ShoppingBag', size: 17, color: Colors.white, strokeWidth: 2.2),
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
                      alignment: Alignment.center,
                      child: RollingNumber(count, style: ts(10, w: w8, font: F.mono, color: C.brand)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  txt('${count == 1 ? '1 item' : '$count items'} · ${current.name}', 10, w: w6, color: C.orange100, maxLines: 1),
                  txt('₹${fmtNum(total)}', 15, w: w8, font: F.mono, color: Colors.white),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  txt('View Cart', 12, w: w8, color: C.brand),
                  const SizedBox(width: 4),
                  const LIcon('ArrowRight', size: 14, color: C.brand, strokeWidth: 2.6),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
