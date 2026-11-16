// The app's pop-up dialog (drop-in for AlertDialog: title, content, actions).
// Buttons sit in one row with equal widths; a TextButton (Cancel, Close...) is shown as a proper secondary
// button instead of a link, and every button has the same height.
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppDialog extends StatelessWidget {
  const AppDialog({super.key, this.title, this.content, this.actions});
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttons = actions ?? const <Widget>[];
    final radius = BorderRadius.circular(10);
    const label = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
    // Button styles for this dialog only. Explicit styles on a button (e.g. a red "Delete") still win.
    final buttonTheme = theme.copyWith(
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.grey100,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: AppColors.grey300)),
          textStyle: label,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: label,
        ),
      ),
    );

    return Dialog(
      backgroundColor: AppColors.cardWhite,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (title != null)
              DefaultTextStyle(
                style: theme.textTheme.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
                child: title!,
              ),
            if (content != null) ...[
              if (title != null) const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: DefaultTextStyle(
                    style: theme.textTheme.bodyMedium!.copyWith(fontSize: 13.5, height: 1.45, color: AppColors.textSecondary),
                    child: content!,
                  ),
                ),
              ),
            ],
            if (buttons.isNotEmpty) ...[
              const SizedBox(height: 20),
              Theme(
                data: buttonTheme,
                child: Row(children: [
                  for (var i = 0; i < buttons.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: buttons[i]),
                  ],
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
