import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/dashboard_stats.dart';

class TopItemsList extends StatelessWidget {
  final List<TopItem> topItems;
  final List<TopItem> slowItems;

  const TopItemsList({
    super.key,
    required this.topItems,
    required this.slowItems,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          context: context,
          title: 'Top-Selling Items',
          icon: Icons.trending_up,
          iconColor: AppColors.vendorTeal,
          items: topItems,
          emptyMessage: 'No sales data yet.',
          isTop: true,
        ),
        const SizedBox(height: AppSpacing.md),
        _buildSection(
          context: context,
          title: 'Slow-Selling Items (Needs Attention)',
          icon: Icons.warning_amber_rounded,
          iconColor: AppColors.warningAmber,
          items: slowItems,
          emptyMessage: 'All menu items are performing well!',
          isTop: false,
        ),
      ],
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<TopItem> items,
    required String emptyMessage,
    required bool isTop,
  }) {
    final theme = Theme.of(context);

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
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: Text(
                    emptyMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.grey600),
                  ),
                ),
              )
            else
              ...List.generate(items.length, (i) {
                final item = items[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isTop ? AppColors.primaryOrange.withValues(alpha: 0.12) : AppColors.grey200,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isTop ? AppColors.primaryOrange : AppColors.grey700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.grey100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${item.qty} sold',
                          style: const TextStyle(fontSize: 12, color: AppColors.grey700),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          CurrencyFormatter.format(item.revenue),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandBrown,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}