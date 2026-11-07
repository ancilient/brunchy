// Colours, fonts and small building blocks matching the React app's Tailwind classes.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const cream = Color(0xFFFAF2E4); // bg-[#FAF2E4]
  static const brand = Color(0xFFE63E11); // #E63E11
  static const brandLight = Color(0xFFFF6E40); // #FF6E40
  static const indigoBrand = Color(0xFF3A3D9E); // #3A3D9E
  static const white = Colors.white;

  static const slate900 = Color(0xFF0F172A), slate800 = Color(0xFF1E293B), slate700 = Color(0xFF334155),
      slate600 = Color(0xFF475569), slate500 = Color(0xFF64748B), slate400 = Color(0xFF94A3B8),
      slate300 = Color(0xFFCBD5E1), slate200 = Color(0xFFE2E8F0), slate100 = Color(0xFFF1F5F9), slate50 = Color(0xFFF8FAFC);
  static const amber50 = Color(0xFFFFFBEB), amber100 = Color(0xFFFEF3C7), amber200 = Color(0xFFFDE68A), amber300 = Color(0xFFFCD34D),
      amber500 = Color(0xFFF59E0B), amber600 = Color(0xFFD97706), amber700 = Color(0xFFB45309), amber800 = Color(0xFF92400E), amber900 = Color(0xFF78350F);
  static const orange50 = Color(0xFFFFF7ED), orange100 = Color(0xFFFFEDD5), orange200 = Color(0xFFFED7AA), orange500 = Color(0xFFF97316);
  static const emerald50 = Color(0xFFECFDF5), emerald100 = Color(0xFFD1FAE5), emerald200 = Color(0xFFA7F3D0), emerald500 = Color(0xFF10B981),
      emerald600 = Color(0xFF059669), emerald700 = Color(0xFF047857), emerald800 = Color(0xFF065F46);
  static const rose50 = Color(0xFFFFF1F2), rose200 = Color(0xFFFECDD3), rose600 = Color(0xFFE11D48), rose700 = Color(0xFFBE123C);
  static const purple100 = Color(0xFFF3E8FF), purple500 = Color(0xFFA855F7), purple700 = Color(0xFF7E22CE), purple800 = Color(0xFF6B21A8);
  static const indigo50 = Color(0xFFEEF2FF), indigo100 = Color(0xFFE0E7FF), indigo600 = Color(0xFF4F46E5);
  static const blue50 = Color(0xFFEFF6FF), blue200 = Color(0xFFBFDBFE), blue500 = Color(0xFF3B82F6), blue600 = Color(0xFF2563EB);
  static const purple50 = Color(0xFFFAF5FF), purple200 = Color(0xFFE9D5FF), purple600 = Color(0xFF9333EA);
  static const sky50 = Color(0xFFF0F9FF), sky200 = Color(0xFFBAE6FD), sky600 = Color(0xFF0284C7);
  static const emeraldBorder = Color(0xFFA7F3D0);

  static const brandGradient = LinearGradient(colors: [brandLight, brand]); // from-[#FF6E40] to-[#E63E11]
  static const brandGradientDiag = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [brandLight, brand]);

  static Color hex(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));
  static Color a(Color c, double opacity) => c.withValues(alpha: opacity);
}

enum F { sans, display, mono }

/// Text in the app's fonts: Inter (body), Poppins (font-display / headings), JetBrains Mono (font-mono).
TextStyle ts(double size, {FontWeight w = FontWeight.w400, Color color = C.slate900, F font = F.sans, double? spacing, double? height}) {
  final base = TextStyle(fontSize: size, fontWeight: w, color: color, letterSpacing: spacing, height: height);
  switch (font) {
    case F.display:
      return GoogleFonts.poppins(textStyle: base);
    case F.mono:
      return GoogleFonts.jetBrainsMono(textStyle: base);
    case F.sans:
      return GoogleFonts.inter(textStyle: base);
  }
}

Widget txt(String s, double size, {FontWeight w = FontWeight.w400, Color color = C.slate900, F font = F.sans, double? spacing, TextAlign? align, int? maxLines, double? height}) =>
    Text(s, textAlign: align, maxLines: maxLines, overflow: maxLines != null ? TextOverflow.ellipsis : null,
        style: ts(size, w: w, color: color, font: font, spacing: spacing, height: height));

const w4 = FontWeight.w400, w5 = FontWeight.w500, w6 = FontWeight.w600, w7 = FontWeight.w700, w8 = FontWeight.w800;

/// Tappable box with a press-shrink like `active:scale-[0.98]`.
class Tap extends StatefulWidget {
  const Tap({super.key, required this.child, this.onTap, this.scale = 0.98});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(scale: _down ? widget.scale : 1.0, duration: const Duration(milliseconds: 100), child: widget.child),
    );
  }
}

/// Orange gradient button used for the main actions.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.child, this.onTap, this.radius = 16, this.padding = const EdgeInsets.symmetric(vertical: 14), this.shadow = true});
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final EdgeInsets padding;
  final bool shadow;
  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: C.brandGradient,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: shadow ? [BoxShadow(color: C.a(C.orange500, 0.25), blurRadius: 15, offset: const Offset(0, 8))] : null,
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// White rounded card with the light amber border (`bg-white rounded-3xl border border-amber-200/80`).
BoxDecoration card({double radius = 24, Color color = Colors.white, Color? border, double borderWidth = 1, List<BoxShadow>? shadow}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border ?? C.a(C.amber200, 0.8), width: borderWidth),
      boxShadow: shadow ?? [BoxShadow(color: C.a(Colors.black, 0.04), blurRadius: 3, offset: const Offset(0, 1))],
    );

/// Small pill label (`px-2 py-0.5 rounded-md text-[10px] font-bold`).
Widget pill(String text, {required Color bg, required Color fg, double size = 10, FontWeight w = w7, double radius = 6, EdgeInsets? pad, double? spacing}) => Container(
      padding: pad ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
      child: txt(text, size, w: w, color: fg, spacing: spacing),
    );

Widget dot(Color c, [double s = 8]) => Container(width: s, height: s, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

/// The orange square logo tile with crossed utensils.
Widget logoTile(double size, double radius, Widget icon) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: C.brandGradientDiag,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: C.a(C.orange500, 0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Center(child: icon),
    );

// ---------------- dialogs (the React app uses alert() / confirm()) ----------------
Future<void> showAlert(BuildContext context, String message) => showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(message, style: ts(14, color: C.slate800)),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text('OK', style: ts(14, w: w7, color: C.brand)))],
      ),
    );

Future<bool> showConfirm(BuildContext context, String message) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(message, style: ts(14, color: C.slate800)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel', style: ts(14, w: w6, color: C.slate500))),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text('OK', style: ts(14, w: w7, color: C.brand))),
      ],
    ),
  );
  return r ?? false;
}
