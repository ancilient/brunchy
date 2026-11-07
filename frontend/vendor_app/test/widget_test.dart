import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brunchy_vendor/features/dashboard/widgets/summary_card.dart';
import 'package:brunchy_vendor/features/menu/widgets/menu_item_tile.dart';
import 'package:brunchy_vendor/data/models/menu_item.dart';

void main() {
  testWidgets('SummaryCard displays title, value and change indicator', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SummaryCard(
            title: 'Total Revenue',
            value: '₹3,420',
            changeText: '+12.5%',
            isPositive: true,
            icon: Icons.currency_rupee,
          ),
        ),
      ),
    );

    expect(find.text('Total Revenue'), findsOneWidget);
    expect(find.text('₹3,420'), findsOneWidget);
    expect(find.text('+12.5%'), findsOneWidget);
  });

  testWidgets('MenuItemTile shows name, price and responds to toggle', (WidgetTester tester) async {
    bool toggled = false;
    final item = MenuItem(
      id: 'item_1',
      stallId: 'stall_1',
      name: 'Paneer Wrap',
      price: 120,
      isAvailable: true,
      category: 'Wraps',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MenuItemTile(
            item: item,
            onToggleAvailability: (val) {
              toggled = val;
            },
            onEdit: () {},
          ),
        ),
      ),
    );

    expect(find.text('Paneer Wrap'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(toggled, isFalse);
  });
}
