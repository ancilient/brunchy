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
import '../../injection_container.dart';
import '../../services/local_storage_service.dart';
import 'dashboard_cubit.dart';
import 'dashboard_state.dart';
import 'widgets/peak_hours_bar.dart';
import 'widgets/period_selector.dart';
import 'widgets/sales_chart.dart';
import 'widgets/summary_card.dart';
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
        color: AppColors.primaryOrange,
        onRefresh: () => context.read<DashboardCubit>().loadDashboard(
              stallId: stallId,
              period: period,
            ),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const StallControlPanel(),
            const SizedBox(height: AppSpacing.md),
            // Row 1: Summary Cards with LayoutBuilder for responsive layout
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth <= 360) {
                  return Column(
                    children: [
                      SummaryCard(
                        title: 'Total Revenue',
                        value: CurrencyFormatter.format(stats.totalRevenue),
                        changeText: CurrencyFormatter.formatChangePct(
                          pct: stats.revenueChangePct,
                          isNew: stats.revenueChangeIsNew,
                          isNone: stats.revenueChangeIsNone,
                        ),
                        isPositive: stats.revenueChangePct >= 0,
                        isNeutral: stats.revenueChangeIsNone,
                        icon: Icons.currency_rupee,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SummaryCard(
                        title: 'Total Orders',
                        value: '${stats.orderCount}',
                        changeText: CurrencyFormatter.formatChangePct(
                          pct: stats.orderCountChangePct.toDouble(),
                          isNew: stats.orderChangeIsNew,
                          isNone: stats.orderChangeIsNone,
                        ),
                        isPositive: stats.orderCountChangePct >= 0,
                        isNeutral: stats.orderChangeIsNone,
                        icon: Icons.receipt_long,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        title: 'Total Revenue',
                        value: CurrencyFormatter.format(stats.totalRevenue),
                        changeText: CurrencyFormatter.formatChangePct(
                          pct: stats.revenueChangePct,
                          isNew: stats.revenueChangeIsNew,
                          isNone: stats.revenueChangeIsNone,
                        ),
                        isPositive: stats.revenueChangePct >= 0,
                        isNeutral: stats.revenueChangeIsNone,
                        icon: Icons.currency_rupee,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: SummaryCard(
                        title: 'Total Orders',
                        value: '${stats.orderCount}',
                        changeText: CurrencyFormatter.formatChangePct(
                          pct: stats.orderCountChangePct.toDouble(),
                          isNew: stats.orderChangeIsNew,
                          isNone: stats.orderChangeIsNone,
                        ),
                        isPositive: stats.orderCountChangePct >= 0,
                        isNeutral: stats.orderChangeIsNone,
                        icon: Icons.receipt_long,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            SummaryCard(
              title: 'Average Order Value (AOV)',
              value: CurrencyFormatter.format(stats.avgOrderValue),
              changeText: CurrencyFormatter.formatChangePct(
                pct: stats.aovChangePct,
                isNew: stats.aovChangeIsNew,
                isNone: stats.aovChangeIsNone,
              ),
              isPositive: stats.aovChangePct >= 0,
              isNeutral: stats.aovChangeIsNone,
              icon: Icons.analytics_outlined,
            ),
            const SizedBox(height: AppSpacing.md),

            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                side: const BorderSide(color: AppColors.grey200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        color: AppColors.primaryOrange),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Average preparation time',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    Text(
                      '${stats.avgPrepMinutes.toStringAsFixed(1)} min',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandBrown,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Sales Trend Chart
            SalesChart(
              chartData: stats.chartData,
              selectedMetric: state.chartMetric,
              onMetricChanged: (metric) =>
                  context.read<DashboardCubit>().changeChartMetric(metric),
            ),
            const SizedBox(height: AppSpacing.md),

            // Order Status Split
            _buildStatusSplitCard(context, stats.statusSplit),
            const SizedBox(height: AppSpacing.md),

            // Peak Rush Hours (only on today view)
            if (period == DashboardPeriod.today) ...[
              PeakHoursBar(peakHours: stats.peakHours),
              const SizedBox(height: AppSpacing.md),
            ],

            // Top & Slow Items
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

  Widget _buildStatusSplitCard(BuildContext context, Map<String, int> split) {
    final theme = Theme.of(context);
    final completed = split['collected'] ?? split['completed'] ?? 0;
    final cancelled = split['cancelled'] ?? 0;
    final total = completed + cancelled;

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
            Text(
              'Order Fulfillment Split',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Completed',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.successGreen,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('$completed orders',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.successGreen)),
                        if (total > 0)
                          Text(
                              '${((completed / total) * 100).toStringAsFixed(0)}% success rate',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.grey600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cancelled / Refunded',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.errorRed,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('$cancelled orders',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.errorRed)),
                        if (total > 0)
                          Text(
                              '${((cancelled / total) * 100).toStringAsFixed(0)}% drop rate',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.grey600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
