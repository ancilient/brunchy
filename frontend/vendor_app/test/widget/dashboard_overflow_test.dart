import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brunchy_vendor/features/dashboard/widgets/summary_card.dart';
import 'package:brunchy_vendor/features/dashboard/widgets/sales_chart.dart';
import 'package:brunchy_vendor/data/models/dashboard_stats.dart';
import 'package:brunchy_vendor/data/models/dashboard_period.dart';

void main() {
  final sampleChartData = List.generate(
    24,
    (i) => ChartPoint(label: '$i:00', revenue: (i * 120.0), orders: i + 1),
  );

  group('Dashboard Overflow Regression Tests', () {
    for (final width in [320.0, 360.0, 411.0]) {
      for (final textScale in [1.0, 1.3, 2.0]) {
        testWidgets('No overflow on SummaryCard at width: $width, textScale: $textScale', (tester) async {
          tester.view.physicalSize = Size(width * 2.0, 800 * 2.0);
          tester.view.devicePixelRatio = 2.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 800),
                  textScaler: TextScaler.linear(textScale),
                ),
                child: Scaffold(
                  body: SizedBox(
                    width: width / 2 - 16,
                    child: const SummaryCard(
                      title: 'Total Revenue',
                      value: '₹3,240',
                      changeText: '+12.5%',
                      isPositive: true,
                      icon: Icons.currency_rupee,
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
        });

        testWidgets('No overflow on SalesChart at width: $width, textScale: $textScale', (tester) async {
          tester.view.physicalSize = Size(width * 2.0, 800 * 2.0);
          tester.view.devicePixelRatio = 2.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 800),
                  textScaler: TextScaler.linear(textScale),
                ),
                child: Scaffold(
                  body: SizedBox(
                    width: width,
                    child: SalesChart(
                      chartData: sampleChartData,
                      selectedMetric: ChartMetric.revenue,
                      onMetricChanged: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
