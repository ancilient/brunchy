// lib/features/dashboard/widgets/sales_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/dashboard_period.dart';
import '../../../data/models/dashboard_stats.dart';

class SalesChart extends StatelessWidget {
  final List<ChartPoint> chartData;
  final ChartMetric selectedMetric;
  final ValueChanged<ChartMetric> onMetricChanged;

  const SalesChart({
    super.key,
    required this.chartData,
    required this.selectedMetric,
    required this.onMetricChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRevenue = selectedMetric == ChartMetric.revenue;
    final isHourly = chartData.length == 24 &&
        chartData.every((point) => point.label.endsWith(':00'));

    if (chartData.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('No chart data available.')),
      );
    }

    double maxY = 0;
    for (final p in chartData) {
      final val = isRevenue ? p.revenue : p.orders.toDouble();
      if (val > maxY) maxY = val;
    }
    if (maxY == 0) maxY = 10;
    maxY = maxY * 1.25;

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
            // Responsive Title & Metric Toggle Header
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                Text(
                  'Sales Trend',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SegmentedButton<ChartMetric>(
                  segments: const [
                    ButtonSegment(
                      value: ChartMetric.revenue,
                      label: Text('Revenue', style: TextStyle(fontSize: 12)),
                    ),
                    ButtonSegment(
                      value: ChartMetric.orderCount,
                      label: Text('Orders', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  selected: {selectedMetric},
                  onSelectionChanged: (set) => onMetricChanged(set.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.brandBrown,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final point = chartData[group.x.toInt()];
                        final valStr = isRevenue
                            ? CurrencyFormatter.format(point.revenue)
                            : '${point.orders} orders';
                        return BarTooltipItem(
                          '${point.label}\n$valStr',
                          const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) {
                          if (value == 0 || value >= meta.max) {
                            return const SizedBox.shrink();
                          }
                          final text = isRevenue
                              ? (value >= 1000
                                  ? '₹${(value / 1000).toStringAsFixed(1)}k'
                                  : '₹${value.toInt()}')
                              : value.toInt().toString();
                          return Text(text,
                              style: const TextStyle(
                                  color: AppColors.grey600, fontSize: 10));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= chartData.length) {
                            return const SizedBox.shrink();
                          }

                          // For 24-hour views (today), only show every 3 hours (0, 3, 6, 9, 12, 15, 18, 21)
                          if (isHourly) {
                            if (idx % 3 != 0) return const SizedBox.shrink();
                            final hourLabel = '${idx}h';
                            return Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                hourLabel,
                                style: const TextStyle(
                                    color: AppColors.grey600,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                              ),
                            );
                          }

                          // For weekly or monthly views (<= 12 points), format concisely
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              chartData[idx].label,
                              style: const TextStyle(
                                  color: AppColors.grey600,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppColors.grey200,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(chartData.length, (i) {
                    final val = isRevenue
                        ? chartData[i].revenue
                        : chartData[i].orders.toDouble();
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: val,
                          color: AppColors.primaryOrange,
                          width: chartData.length > 15 ? 7 : 14,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
