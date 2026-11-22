import '../models/dashboard_period.dart';
import '../models/dashboard_stats.dart';
import '../repositories/dashboard_repository.dart';
import 'vendor_api.dart';

/// Sales dashboard from the backend's real bills (GET /vendor/reports/dashboard). Replaces the demo figures.
class RemoteDashboardRepository implements DashboardRepository {
  RemoteDashboardRepository(this._api);
  final VendorApi _api;

  @override
  Future<DashboardStats> getDashboard({required String stallId, required DashboardPeriod period}) async =>
      DashboardStats.fromJson(await _api.get('/vendor/reports/dashboard', query: {'period': period.apiValue}));

  /// The dashboard response already holds revenue and order counts per bucket; the chart picks the metric.
  @override
  Future<List<ChartPoint>> getChartData({
    required String stallId,
    required DashboardPeriod period,
    required ChartMetric metric,
  }) async =>
      (await getDashboard(stallId: stallId, period: period)).chartData;
}
