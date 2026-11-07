import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/order.dart';
import '../../data/models/order_status.dart';
import '../../injection_container.dart';
import '../../data/repositories/order_repository.dart';
import '../../services/local_storage_service.dart';

class PastOrdersScreen extends StatefulWidget {
  const PastOrdersScreen({super.key});
  @override State<PastOrdersScreen> createState() => _PastOrdersScreenState();
}

class _PastOrdersScreenState extends State<PastOrdersScreen> {
  String _selectedDate = DateFormatter.todayKey();
  List<Order> _orders = [];
  bool _loading = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    // [API-005] GET /stalls/{stallId}/orders?date=...
    final stallId = sl<LocalStorageService>().getStallId(_selectedDate) ?? 'stall_001';
    final orders = await sl<OrderRepository>().getOrders(stallId: stallId, date: _selectedDate);
    setState(() { _orders = orders; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Past Orders')),
      body: Column(children: [
        SizedBox(height: 48, child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: 7,
          itemBuilder: (_, i) {
            final d = DateTime.now().subtract(Duration(days: i));
            final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
            final label = i == 0 ? 'Today' : i == 1 ? 'Yesterday' : DateFormatter.displayDate(d);
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm, top: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(label), selected: _selectedDate == key,
                onSelected: (_) { setState(() => _selectedDate = key); _load(); },
              ),
            );
          },
        )),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
          : _orders.isEmpty
            ? const Center(child: Text('No orders on this date'))
            : ListView.builder(
                itemCount: _orders.length,
                itemBuilder: (_, i) {
                  final o = _orders[i];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.1), child: Text(o.billNumber.substring(1), style: const TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.w700, fontSize: 12))),
                    title: Text('#${o.billNumber}'),
                    subtitle: Text('${o.items.length} item${o.items.length > 1 ? 's' : ''}'),
                    trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(CurrencyFormatter.format(o.totalAmount), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryOrange)),
                      Chip(
                        label: Text(o.status.label, style: const TextStyle(fontSize: 10)),
                        backgroundColor: o.status == OrderStatus.collected ? AppColors.successGreen.withValues(alpha: 0.1) : AppColors.errorRed.withValues(alpha: 0.1),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ]),
                  );
                },
              )),
      ]),
    );
  }
}

