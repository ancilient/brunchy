// lib/features/dashboard/widgets/summary_card.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String changeText;
  final bool isPositive;
  final bool isNeutral;
  final IconData icon;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.changeText,
    required this.isPositive,
    this.isNeutral = false,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color badgeBg;
    final Color badgeTextColor;
    final IconData badgeIcon;

    if (isNeutral) {
      badgeBg = AppColors.grey100;
      badgeTextColor = AppColors.grey700;
      badgeIcon = Icons.remove;
    } else if (isPositive) {
      badgeBg = AppColors.successGreen.withValues(alpha: 0.12);
      badgeTextColor = AppColors.successGreen;
      badgeIcon = Icons.arrow_upward;
    } else {
      badgeBg = AppColors.errorRed.withValues(alpha: 0.12);
      badgeTextColor = AppColors.errorRed;
      badgeIcon = Icons.arrow_downward;
    }

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: const BorderSide(color: AppColors.grey200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.grey600,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(icon, size: 20, color: AppColors.primaryOrange),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandBrown,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: badgeTextColor),
                    const SizedBox(width: 2),
                    Text(
                      changeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeTextColor,
                      ),
                    ),
                    const Text(
                      ' vs prev',
                      style: TextStyle(fontSize: 10, color: AppColors.grey600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
