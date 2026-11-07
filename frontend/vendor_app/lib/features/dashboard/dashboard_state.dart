import 'package:equatable/equatable.dart';
import '../../data/models/dashboard_period.dart';
import '../../data/models/dashboard_stats.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();
  @override List<Object?> get props => [];
}

class DashboardInitial extends DashboardState { const DashboardInitial(); }

class DashboardLoading extends DashboardState {
  final DashboardPeriod period;
  const DashboardLoading(this.period);
  @override List<Object?> get props => [period];
}

class DashboardLoaded extends DashboardState {
  final DashboardStats stats;
  final DashboardPeriod period;
  final ChartMetric chartMetric;
  const DashboardLoaded({
    required this.stats,
    required this.period,
    required this.chartMetric,
  });
  @override List<Object?> get props => [stats, period, chartMetric];
}

class DashboardError extends DashboardState {
  final String message;
  final DashboardPeriod period;
  const DashboardError({required this.message, required this.period});
  @override List<Object?> get props => [message, period];
}