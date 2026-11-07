import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/order.dart';
import '../../data/models/order_status.dart';
import '../../data/models/cancel_reason.dart';
import '../../injection_container.dart';
import '../../data/repositories/order_repository.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final repo = sl<OrderRepository>();
    final orders = await repo.getOrders(stallId: 'stall_001');
    if (mounted) {
      setState(() {
        try {
          _order = orders.firstWhere((o) => o.id == widget.orderId);
        } catch (_) {}
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    if (order == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Order')),
          body: const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primaryOrange)));
    }

    final canCancel = order.status == OrderStatus.placed ||
        order.status == OrderStatus.accepted;
    return Scaffold(
      appBar: AppBar(title: Text('Order #${order.billNumber}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _StatusChip(order.status),
          const SizedBox(height: AppSpacing.md),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Items',
                            style: Theme.of(context).textTheme.titleMedium),
                        const Divider(),
                        ...order.items.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.xs),
                              child: Row(children: [
                                Expanded(
                                    child:
                                        Text('${item.name} ×${item.quantity}')),
                                Text(CurrencyFormatter.format(item.subtotal),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ]),
                            )),
                        const Divider(),
                        Row(children: [
                          const Expanded(
                              child: Text('Total',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16))),
                          Text(CurrencyFormatter.format(order.totalAmount),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: AppColors.primaryOrange)),
                        ]),
                      ]))),
          const SizedBox(height: AppSpacing.md),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Timeline',
                            style: Theme.of(context).textTheme.titleMedium),
                        const Divider(),
                        _TimelineRow('Placed', order.placedAt),
                        if (order.acceptedAt != null)
                          _TimelineRow('Accepted', order.acceptedAt!),
                        if (order.readyAt != null)
                          _TimelineRow('Ready', order.readyAt!),
                        if (order.collectedAt != null)
                          _TimelineRow('Collected', order.collectedAt!),
                      ]))),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
                color: AppColors.vendorTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
            child: const Row(children: [
              Icon(Icons.payment, color: AppColors.vendorTeal, size: 16),
              SizedBox(width: AppSpacing.sm),
              Text('Paid in-app (prepaid)',
                  style: TextStyle(color: AppColors.vendorTeal))
            ]),
          ),
          if (canCancel) ...[
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.errorRed,
                      side: const BorderSide(color: AppColors.errorRed),
                      minimumSize: const Size.fromHeight(52)),
                  onPressed: () => _showCancelDialog(context, order),
                  child: const Text('Cancel Order'),
                )),
          ],
        ]),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, Order order) {
    CancelReason? reason = CancelReason.outOfStock;
    showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
              builder: (ctx, setState) => AlertDialog(
                title: const Text('Cancel Order'),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: CancelReason.values
                        .map(
                          (r) => RadioListTile<CancelReason>(
                              title: Text(r.label),
                              value: r,
                              groupValue: reason,
                              onChanged: (v) => setState(() => reason = v)),
                        )
                        .toList()),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Keep')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.errorRed),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await sl<OrderRepository>()
                          .cancelOrder(orderId: order.id, reason: reason!);
                      if (context.mounted) context.pop();
                    },
                    child: const Text('Cancel Order'),
                  ),
                ],
              ),
            ));
  }
}

class _StatusChip extends StatelessWidget {
  final OrderStatus status;
  const _StatusChip(this.status);
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OrderStatus.collected => AppColors.successGreen,
      OrderStatus.cancelled || OrderStatus.refunded => AppColors.errorRed,
      OrderStatus.ready => AppColors.vendorTeal,
      _ => AppColors.primaryOrange,
    };
    return Chip(
        label: Text(status.label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        backgroundColor: color.withValues(alpha: 0.1));
  }
}

class _TimelineRow extends StatelessWidget {
  final String label;
  final DateTime time;
  const _TimelineRow(this.label, this.time);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
          Text(DateFormatter.displayDateTime(time),
              style: Theme.of(context).textTheme.bodyMedium),
        ]),
      );
}
