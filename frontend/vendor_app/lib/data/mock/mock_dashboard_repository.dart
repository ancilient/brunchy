import '../../data/models/dashboard_stats.dart';
import '../../data/models/dashboard_period.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../mock/mock_data.dart';

class MockDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardStats> getDashboard({
    required String stallId, required DashboardPeriod period,
  }) async {
    // TODO(BACKEND-API): API-022 GET /stalls/{stallId}/dashboard?period=...
    await Future.delayed(const Duration(milliseconds: 800));
    return MockData.dashboardStats(period);
  }

  @override
  Future<List<ChartPoint>> getChartData({
    required String stallId, required DashboardPeriod period, required ChartMetric metric,
  }) async {
    // TODO(BACKEND-API): API-023 GET /stalls/{stallId}/dashboard/chart?period=...&metric=...
    await Future.delayed(const Duration(milliseconds: 600));
    return MockData.dashboardStats(period).chartData;
  }
}

