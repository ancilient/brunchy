class ChartPoint {
  final String label;
  final double revenue;
  final int orders;

  const ChartPoint({required this.label, required this.revenue, required this.orders});

  factory ChartPoint.fromJson(Map<String, dynamic> json) => ChartPoint(
        label: json['label'] as String,
        revenue: (json['revenue'] as num).toDouble(),
        orders: json['orders'] as int,
      );
}

class TopItem {
  final String name;
  final int qty; // Units sold
  final int orderCount; // Unique orders
  final double revenue;

  const TopItem({
    required this.name,
    required this.qty,
    required this.orderCount,
    required this.revenue,
  });

  factory TopItem.fromJson(Map<String, dynamic> json) => TopItem(
        name: json['name'] as String,
        qty: json['qty'] as int,
        orderCount: json['orderCount'] as int? ?? 0,
        revenue: (json['revenue'] as num).toDouble(),
      );
}

class HourCount {
  final int hour; // 0–23
  final int count;

  const HourCount({required this.hour, required this.count});

  factory HourCount.fromJson(Map<String, dynamic> json) =>
      HourCount(hour: json['hour'] as int, count: json['count'] as int);
}

class DashboardStats {
  final double totalRevenue;
  final int orderCount;
  final double avgOrderValue;
  final double revenueChangePct;
  final int orderCountChangePct;
  final double aovChangePct;
  final bool revenueChangeIsNew; // prev=0, current>0
  final bool revenueChangeIsNone; // both=0
  final bool orderChangeIsNew;
  final bool orderChangeIsNone;
  final bool aovChangeIsNew;
  final bool aovChangeIsNone;
  final List<ChartPoint> chartData;
  final List<TopItem> topItems;
  final List<TopItem> slowItems;
  final List<HourCount> peakHours;
  final Map<String, int> statusSplit;
  final double avgPrepMinutes;

  const DashboardStats({
    required this.totalRevenue,
    required this.orderCount,
    required this.avgOrderValue,
    required this.revenueChangePct,
    required this.orderCountChangePct,
    required this.aovChangePct,
    required this.revenueChangeIsNew,
    required this.revenueChangeIsNone,
    required this.orderChangeIsNew,
    required this.orderChangeIsNone,
    required this.aovChangeIsNew,
    required this.aovChangeIsNone,
    required this.chartData,
    required this.topItems,
    required this.slowItems,
    required this.peakHours,
    required this.statusSplit,
    this.avgPrepMinutes = 8.5,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        totalRevenue: (json['totalRevenue'] as num).toDouble(),
        orderCount: json['orderCount'] as int,
        avgOrderValue: (json['avgOrderValue'] as num).toDouble(),
        revenueChangePct: (json['revenueChangePct'] as num?)?.toDouble() ?? 0,
        orderCountChangePct: (json['orderCountChangePct'] as int?) ?? 0,
        aovChangePct: (json['aovChangePct'] as num?)?.toDouble() ?? 0,
        revenueChangeIsNew: (json['revenueChangeIsNew'] as bool?) ?? false,
        revenueChangeIsNone: (json['revenueChangeIsNone'] as bool?) ?? false,
        orderChangeIsNew: (json['orderChangeIsNew'] as bool?) ?? false,
        orderChangeIsNone: (json['orderChangeIsNone'] as bool?) ?? false,
        aovChangeIsNew: (json['aovChangeIsNew'] as bool?) ?? false,
        aovChangeIsNone: (json['aovChangeIsNone'] as bool?) ?? false,
        chartData: (json['chartData'] as List? ?? []).map((e) => ChartPoint.fromJson(e)).toList(),
        topItems: (json['topItems'] as List? ?? []).map((e) => TopItem.fromJson(e)).toList(),
        slowItems: (json['slowItems'] as List? ?? []).map((e) => TopItem.fromJson(e)).toList(),
        peakHours: (json['peakHours'] as List? ?? []).map((e) => HourCount.fromJson(e)).toList(),
        statusSplit: Map<String, int>.from(json['statusSplit'] ?? {}),
        avgPrepMinutes: (json['avgPrepMinutes'] as num?)?.toDouble() ?? 8.5,
      );

  static DashboardStats empty() => const DashboardStats(
        totalRevenue: 0, orderCount: 0, avgOrderValue: 0,
        revenueChangePct: 0, orderCountChangePct: 0, aovChangePct: 0,
        revenueChangeIsNew: false, revenueChangeIsNone: true,
        orderChangeIsNew: false, orderChangeIsNone: true,
        aovChangeIsNew: false, aovChangeIsNone: true,
        chartData: [], topItems: [], slowItems: [], peakHours: [], statusSplit: {},
        avgPrepMinutes: 0.0,
      );
}
