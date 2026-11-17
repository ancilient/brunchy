// lib/features/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/dashboard_period.dart';
import '../../data/models/dashboard_stats.dart';
import '../../injection_container.dart';
import '../../services/local_storage_service.dart';
import 'dashboard_cubit.dart';
import 'dashboard_state.dart';
import 'widgets/peak_hours_bar.dart';
import 'widgets/period_selector.dart';
import 'widgets/sales_chart.dart';
import 'widgets/top_items_list.dart';
import '../stall_control/widgets/stall_control_panel.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _getStallId() {
    return sl<LocalStorageService>().getStallId(DateFormatter.todayKey()) ??
        'stall_001';
  }

  @override
  Widget build(BuildContext context) {
    final stallId = _getStallId();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<DashboardCubit, DashboardState>(
        listener: (context, state) {
          if (state is DashboardError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.errorRed),
            );
          }
        },
        builder: (context, state) {
          DashboardPeriod currentPeriod = DashboardPeriod.today;
          if (state is DashboardLoading) currentPeriod = state.period;
          if (state is DashboardLoaded) currentPeriod = state.period;
          if (state is DashboardError) currentPeriod = state.period;

          return Column(
            children: [
              // Period Selector Tabs - responsive and unclipped
              PeriodSelector(
                selectedPeriod: currentPeriod,
                onPeriodChanged: (period) {
                  context.read<DashboardCubit>().changePeriod(
                        stallId: stallId,
                        period: period,
                      );
                },
              ),

              // Body content
              Expanded(
                child: _buildBody(context, state, stallId, currentPeriod),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    DashboardState state,
    String stallId,
    DashboardPeriod period,
  ) {
    if (state is DashboardLoading || state is DashboardInitial) {
      return _buildShimmerLoading();
    }

    if (state is DashboardError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.errorRed),
              const SizedBox(height: AppSpacing.md),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text(AppStrings.retry),
                onPressed: () =>
                    context.read<DashboardCubit>().retry(stallId: stallId),
              ),
            ],
          ),
        ),
      );
    }

    if (state is DashboardLoaded) {
      final stats = state.stats;

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => context.read<DashboardCubit>().loadDashboard(
              stallId: stallId,
              period: period,
            ),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const StallControlPanel(),
            const SizedBox(height: AppSpacing.md),
            _buildHero(stats, period),
            const SizedBox(height: AppSpacing.md),
            _sectionLabel('Sales trend'),
            // Sales Trend Chart
            SalesChart(
              chartData: stats.chartData,
              selectedMetric: state.chartMetric,
              onMetricChanged: (metric) =>
                  context.read<DashboardCubit>().changeChartMetric(metric),
            ),
            const SizedBox(height: AppSpacing.md),

            _sectionLabel('Orders'),
            _buildStatusSplitCard(context, stats.statusSplit),
            const SizedBox(height: AppSpacing.md),

            // Peak Rush Hours (only on today view)
            if (period == DashboardPeriod.today) ...[
              PeakHoursBar(peakHours: stats.peakHours),
              const SizedBox(height: AppSpacing.md),
            ],

            _sectionLabel('Menu performance'),
            TopItemsList(
              topItems: stats.topItems,
              slowItems: stats.slowItems,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ---------------- redesigned pieces ----------------

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, AppSpacing.sm, 4, 6),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: AppColors.textSecondary)),
      );

  /// One teal card: total revenue up top, then orders / average order / prep time as mini tiles.
  Widget _buildHero(DashboardStats stats, DashboardPeriod period) {
    String change(double pct, bool isNew, bool isNone) =>
        CurrencyFormatter.formatChangePct(pct: pct, isNew: isNew, isNone: isNone);
    IconData arrow(double pct, bool isNone) =>
        isNone ? Icons.remove_rounded : (pct >= 0 ? Icons.north_east_rounded : Icons.south_east_rounded);

    Widget tile(IconData icon, String value, String label, [String? sub]) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              Text(label, style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8))),
              if (sub != null) ...[
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
              ],
            ]),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandTeal, AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('Total revenue',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
            child: Text(period.label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ]),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(CurrencyFormatter.format(stats.totalRevenue),
              style: const TextStyle(fontSize: 30, height: 1.15, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(arrow(stats.revenueChangePct, stats.revenueChangeIsNone), size: 13, color: Colors.white),
            const SizedBox(width: 3),
            Flexible(
              child: Text('${change(stats.revenueChangePct, stats.revenueChangeIsNew, stats.revenueChangeIsNone)} vs previous period',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        // Same height for all three tiles.
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          tile(Icons.receipt_long_rounded, '${stats.orderCount}', 'Orders',
              change(stats.orderCountChangePct.toDouble(), stats.orderChangeIsNew, stats.orderChangeIsNone)),
          const SizedBox(width: AppSpacing.sm),
          tile(Icons.shopping_bag_outlined, CurrencyFormatter.format(stats.avgOrderValue), 'Avg order',
              change(stats.aovChangePct, stats.aovChangeIsNew, stats.aovChangeIsNone)),
          const SizedBox(width: AppSpacing.sm),
          tile(Icons.timer_outlined, '${stats.avgPrepMinutes.toStringAsFixed(1)} min', 'Avg prep'),
          ]),
        ),
      ]),
    );
  }

  /// Completed vs cancelled as one bar with a legend.
  Widget _buildStatusSplitCard(BuildContext context, Map<String, int> split) {
    final completed = split['collected'] ?? split['completed'] ?? 0;
    final cancelled = split['cancelled'] ?? 0;
    final total = completed + cancelled;
    final success = total == 0 ? 0 : (completed / total * 100).round();

    Widget legend(Color color, String label, int count, String note) => Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Text('$count', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(width: 6),
          SizedBox(width: 38, child: Text(note, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: AppColors.grey500))),
        ]);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
            child: Text('Order fulfilment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.successGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
            child: Text('$success% success', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.successGreen)),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 8,
            child: total == 0
                ? Container(color: AppColors.grey200)
                : Row(children: [
                    if (completed > 0) Expanded(flex: completed, child: Container(color: AppColors.successGreen)),
                    if (completed > 0 && cancelled > 0) const SizedBox(width: 2),
                    if (cancelled > 0) Expanded(flex: cancelled, child: Container(color: AppColors.errorRed)),
                  ]),
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        legend(AppColors.successGreen, 'Completed', completed, total == 0 ? '' : '$success%'),
        const SizedBox(height: 4),
        legend(AppColors.errorRed, 'Cancelled / refunded', cancelled, total == 0 ? '' : '${100 - success}%'),
      ]),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          children: [
            Expanded(child: _shimmerBox(height: 100)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _shimmerBox(height: 100)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _shimmerBox(height: 220),
        const SizedBox(height: AppSpacing.md),
        _shimmerBox(height: 120),
      ],
    );
  }

  Widget _shimmerBox({required double height}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
    );
  }
}
