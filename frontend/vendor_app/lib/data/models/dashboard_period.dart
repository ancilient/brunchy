enum DashboardPeriod { today, thisWeek, thisMonth }

extension DashboardPeriodLabel on DashboardPeriod {
  String get label {
    switch (this) {
      case DashboardPeriod.today:    return 'Today';
      case DashboardPeriod.thisWeek: return 'This Week';
      case DashboardPeriod.thisMonth: return 'This Month';
    }
  }

  String get apiValue {
    switch (this) {
      case DashboardPeriod.today:    return 'today';
      case DashboardPeriod.thisWeek: return 'this_week';
      case DashboardPeriod.thisMonth: return 'this_month';
    }
  }
}

enum ChartMetric { revenue, orderCount }

extension ChartMetricLabel on ChartMetric {
  String get label {
    switch (this) {
      case ChartMetric.revenue:    return 'Revenue';
      case ChartMetric.orderCount: return 'Orders';
    }
  }

  String get apiValue {
    switch (this) {
      case ChartMetric.revenue:    return 'revenue';
      case ChartMetric.orderCount: return 'order_count';
    }
  }
}

