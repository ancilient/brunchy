import 'package:brunchy_vendor/data/models/dashboard_period.dart';
import 'package:brunchy_vendor/data/models/dashboard_stats.dart';

/// Abstract repository for dashboard analytics.
/// Concrete implementations: [MockDashboardRepository] (dev) and a future DioDashboardRepository (prod).
abstract class DashboardRepository {
  /// [API-022] Fetches aggregated dashboard statistics for [stallId] and [period].
  /// Dashboard counts only orders with status IN (accepted, ready, collected) — R-03.
  Future<DashboardStats> getDashboard({
    required String stallId,
    required DashboardPeriod period,
  });

  /// [API-023] Fetches chart data points for [stallId] and [period].
  /// [metric] controls whether revenue or order count is returned on the Y-axis.
  Future<List<ChartPoint>> getChartData({
    required String stallId,
    required DashboardPeriod period,
    required ChartMetric metric,
  });
}

