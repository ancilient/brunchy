// lib/features/dashboard/widgets/peak_hours_bar.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/dashboard_stats.dart';

class PeakHoursBar extends StatelessWidget {
  final List<HourCount> peakHours;

  const PeakHoursBar({super.key, required this.peakHours});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Empty state: no order data or all zero counts
    if (peakHours.isEmpty || peakHours.every((h) => h.count == 0)) {
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
                  const Icon(Icons.access_time_filled, size: 20, color: AppColors.primaryOrange),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Peak Rush Hours (Today)',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Heatmap of order volume throughout the day. Darker orange = heavier rush.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.grey600),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      const Icon(Icons.analytics_outlined, size: 48, color: AppColors.grey300),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'No order data for today',
                        style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.grey600),
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

    final maxCount = peakHours.fold<int>(1, (prev, e) => e.count > prev ? e.count : prev);

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
                const Icon(Icons.access_time_filled, size: 20, color: AppColors.primaryOrange),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Peak Rush Hours (Today)',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Heatmap of order volume throughout the day. Darker orange = heavier rush.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.grey600),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 24,
                separatorBuilder: (_, __) => const SizedBox(width: 4),
                itemBuilder: (context, hour) {
                  final item = peakHours.firstWhere(
                    (h) => h.hour == hour,
                    orElse: () => HourCount(hour: hour, count: 0),
                  );
                  final ratio = maxCount > 0 ? (item.count / maxCount).clamp(0.0, 1.0) : 0.0;
                  final Color boxColor;
                  if (item.count == 0) {
                    boxColor = AppColors.grey100;
                  } else {
                    boxColor = Color.lerp(
                      AppColors.primaryOrange.withValues(alpha: 0.2),
                      AppColors.primaryOrange,
                      ratio,
                    )!;
                  }

                  return Tooltip(
                    message: '$hour:00 – ${item.count} orders',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 22,
                          height: 32,
                          decoration: BoxDecoration(
                            color: boxColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: item.count > 0
                              ? Text(
                                  '${item.count}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: ratio > 0.5 ? AppColors.white : AppColors.brandBrown,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$hour',
                          style: const TextStyle(fontSize: 9, color: AppColors.grey600),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}