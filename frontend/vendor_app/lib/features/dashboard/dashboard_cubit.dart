import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/models/dashboard_period.dart';
import '../../core/errors/app_exception.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository _dashboardRepository;

  DashboardCubit(this._dashboardRepository) : super(const DashboardInitial());

  Future<void> loadDashboard({required String stallId, required DashboardPeriod period}) async {
    emit(DashboardLoading(period));
    try {
      // [API-018] GET /stalls/{stallId}/dashboard?period=...
      final stats = await _dashboardRepository.getDashboard(stallId: stallId, period: period);
      emit(DashboardLoaded(stats: stats, period: period, chartMetric: ChartMetric.revenue));
    } on AppException catch (e) {
      emit(DashboardError(message: e.message, period: period));
    } catch (_) {
      emit(DashboardError(message: 'Failed to load dashboard.', period: period));
    }
  }

  Future<void> changePeriod({required String stallId, required DashboardPeriod period}) async {
    loadDashboard(stallId: stallId, period: period);
  }

  void changeChartMetric(ChartMetric metric) {
    final s = state;
    if (s is DashboardLoaded) {
      emit(DashboardLoaded(stats: s.stats, period: s.period, chartMetric: metric));
    }
  }

  Future<void> retry({required String stallId}) async {
    final s = state;
    final period = s is DashboardError ? s.period : DashboardPeriod.today;
    loadDashboard(stallId: stallId, period: period);
  }
}

