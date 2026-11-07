import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/order.dart';
import '../../data/models/order_filter.dart';
import '../../data/models/order_status.dart';
import '../../data/models/cancel_reason.dart';
import '../../data/repositories/order_repository.dart';
import '../../injection_container.dart';
import '../../services/local_storage_service.dart';
import '../../services/realtime_connection_state.dart';
import 'orders_cubit.dart';
import 'orders_state.dart';
import 'widgets/otp_entry_sheet.dart';
import '../handover/handover_result.dart';
import '../handover/handover_service.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersCubit, OrdersState>(
      builder: (context, state) {
        if (state is OrdersInitial || state is OrdersLoading) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryOrange));
        }
        if (state is OrdersError) {
          return _ErrorState(
              message: state.message,
              onRetry: () {
                final stallId = sl<LocalStorageService>()
                        .getStallId(DateFormatter.todayKey()) ??
                    'stall_001';
                context.read<OrdersCubit>().loadOrders(stallId);
              });
        }

        final loaded = state is OrdersLoaded
            ? state
            : (state as dynamic).base as OrdersLoaded;
        return Column(
          children: [
            _AcceptingOrdersToggle(loaded: loaded),
            if (loaded.connectionState != RealtimeConnectionState.connected)
              _ReconnectingBanner(),

            // Capacity Gate & Simulation Bar
            _CapacityGateBar(loaded: loaded),

            // Overload Protection Banner
            if (loaded.overloadLevel > 0) _OverloadBanner(loaded: loaded),

            // Board Filter Tabs (Queued | Preparing | Ready | All)
            _FilterTabs(loaded: loaded),

            // Sticky Make List (shown on Preparing tab)
            if (loaded.activeFilter == OrderFilter.preparing &&
                loaded.makeList.isNotEmpty)
              _MakeListBar(makeList: loaded.makeList),

            // Batch Actions Bar (shown when batches exist)
            if (loaded.batches.isNotEmpty &&
                (loaded.activeFilter == OrderFilter.newOrders ||
                    loaded.activeFilter == OrderFilter.preparing))
              _BatchActionBar(loaded: loaded),

            Expanded(child: _OrderList(loaded: loaded, state: state)),
          ],
        );
      },
    );
  }
}

class _AcceptingOrdersToggle extends StatelessWidget {
  final OrdersLoaded loaded;
  const _AcceptingOrdersToggle({required this.loaded});
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrdersCubit>();
    final accepting = cubit.acceptingOrders;
    return Container(color: AppColors.cardWhite, padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4), child: Row(children: [
      Icon(accepting ? Icons.check_circle : Icons.pause_circle, color: accepting ? AppColors.successGreen : AppColors.errorRed),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Accepting orders', style: TextStyle(fontWeight: FontWeight.bold)), Text(accepting ? 'ON - students can order' : 'OFF - students see Not taking orders', style: TextStyle(fontSize: 12, color: accepting ? AppColors.successGreen : AppColors.errorRed))])),
      Switch(value: accepting, onChanged: (value) async {
        if (value) { await cubit.setAcceptingOrders(true); return; }
        if (!context.mounted) return;
        final stop = await showModalBottomSheet<bool>(context: context, useRootNavigator: true, builder: (sheet) => SafeArea(child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text('Stop new orders?', style: Theme.of(sheet).textTheme.titleLarge), Text('${loaded.newOrderCount} queued and ${loaded.preparingCount} preparing orders will continue.'), const SizedBox(height: AppSpacing.md), ElevatedButton(onPressed: () => Navigator.of(sheet).pop(true), child: const Text('Stop new orders')), TextButton(onPressed: () => Navigator.of(sheet).pop(false), child: const Text('Cancel'))]))));
        if (stop == true) await cubit.setAcceptingOrders(false);
      }),
    ]));
  }
}

class _CapacityGateBar extends StatelessWidget {
  final OrdersLoaded loaded;
  const _CapacityGateBar({required this.loaded});

  void _onSliderChanged(BuildContext context, double value) {
    final intValue = value.round();
    if (intValue == 0) {
      // Show confirmation dialog before stopping new orders
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Stop New Orders?'),
          content: const Text(
            'Setting max concurrent orders to 0 will stop new incoming orders for your stall. Existing orders can still be prepared.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
              onPressed: () {
                Navigator.of(ctx).pop();
                context.read<OrdersCubit>().setMaxCapacity(0);
              },
              child: const Text('Confirm Stop'),
            ),
          ],
        ),
      );
    } else {
      context.read<OrdersCubit>().setMaxCapacity(intValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardWhite,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.speed, size: 20, color: AppColors.primaryOrange),
              const SizedBox(width: 6),
              Text(
                'Max Concurrent Orders: ${loaded.maxCapacity}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.brandBrown),
              ),
              const Spacer(),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              activeTrackColor: loaded.maxCapacity == 0
                  ? AppColors.errorRed
                  : AppColors.primaryOrange,
              thumbColor: loaded.maxCapacity == 0
                  ? AppColors.errorRed
                  : AppColors.primaryOrange,
            ),
            child: Slider(
              value: loaded.maxCapacity.toDouble(),
              min: 0,
              max: 50,
              divisions: 50,
              label: '${loaded.maxCapacity}',
              onChanged: (val) => _onSliderChanged(context, val),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverloadBanner extends StatelessWidget {
  final OrdersLoaded loaded;
  const _OverloadBanner({required this.loaded});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (loaded.overloadLevel) {
      case 1:
        bg = AppColors.warningAmber.withValues(alpha: 0.15);
        fg = AppColors.warningAmber;
        icon = Icons.hourglass_bottom;
      case 2:
        bg = AppColors.secondaryOrange.withValues(alpha: 0.15);
        fg = AppColors.secondaryOrange;
        icon = Icons.warning_amber_rounded;
      case 3:
      default:
        bg = AppColors.errorRed.withValues(alpha: 0.15);
        fg = AppColors.errorRed;
        icon = Icons.pause_circle_filled;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      color: bg,
      child: Row(
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              loaded.overloadStatusText,
              style: TextStyle(
                  color: fg, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: const Size(0, 28),
            ),
            onPressed: () =>
                context.read<OrdersCubit>().toggleOverloadOverride(),
            child: Text(
              loaded.isOverrideActive ? 'Override Active' : 'Override',
              style: TextStyle(
                  color: fg, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _MakeListBar extends StatelessWidget {
  final Map<String, int> makeList;
  const _MakeListBar({required this.makeList});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.brandBrown,
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.soup_kitchen,
                color: AppColors.accentYellow, size: 18),
            const SizedBox(width: 6),
            const Text(
              'MAKE NOW:',
              style: TextStyle(
                  color: AppColors.accentYellow,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
            const SizedBox(width: 8),
            ...makeList.entries.map((entry) => Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${entry.key} ×${entry.value}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _BatchActionBar extends StatelessWidget {
  final OrdersLoaded loaded;
  const _BatchActionBar({required this.loaded});

  @override
  Widget build(BuildContext context) {
    final firstBatch = loaded.batches.entries.firstOrNull;
    if (firstBatch == null) return const SizedBox.shrink();

    final batchName = firstBatch.key;
    final batchOrders = firstBatch.value;
    final orderIds = batchOrders.map((o) => o.id).toList();

    return Container(
      color: AppColors.grey100,
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      child: Row(
        children: [
          Text(
            '$batchName (${batchOrders.length} ${batchOrders.length == 1 ? 'order' : 'orders'})',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.brandBrown),
          ),
          const Spacer(),
          if (loaded.activeFilter == OrderFilter.newOrders)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: const Size(0, 36),
              ),
              icon: const Icon(Icons.local_fire_department,
                  size: 16, color: Colors.white),
              label: Text('FIRE $batchName',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              onPressed: () async { await context.read<OrdersCubit>().fireBatch(orderIds); if (context.mounted) _showResult(context); },
            ),
          if (loaded.activeFilter == OrderFilter.preparing)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: const Size(0, 36),
              ),
              icon: const Icon(Icons.done_all, size: 16, color: Colors.white),
              label: Text('Ready All ($batchName)',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              onPressed: () async { await context.read<OrdersCubit>().readyBatch(orderIds); if (context.mounted) _showResult(context); },
            ),
        ],
      ),
    );
  }

  void _showResult(BuildContext context) {
    final state = context.read<OrdersCubit>().state;
    if (state is OrderActionError && state.orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
    }
  }
}

class _ReconnectingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.warningAmber,
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm, horizontal: AppSpacing.md),
        child: const Row(children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 16),
          SizedBox(width: AppSpacing.sm),
          Text(AppStrings.reconnecting,
              style: TextStyle(color: Colors.white, fontSize: 13)),
        ]),
      );
}

class _FilterTabs extends StatelessWidget {
  final OrdersLoaded loaded;
  const _FilterTabs({required this.loaded});

  String _tabTitle(OrderFilter filter) {
    switch (filter) {
      case OrderFilter.newOrders:
        return 'Queued (${loaded.newOrderCount})';
      case OrderFilter.preparing:
        return 'Preparing (${loaded.preparingCount})';
      case OrderFilter.ready:
        return 'Ready (${loaded.readyCount})';
      case OrderFilter.all:
        return 'All (${loaded.allOrders.length})';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardWhite,
      child: Row(
        children: OrderFilter.values.map((f) {
          final active = f == loaded.activeFilter;
          return Expanded(
              child: GestureDetector(
            onTap: () => context.read<OrdersCubit>().changeFilter(f),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: active
                            ? AppColors.primaryOrange
                            : Colors.transparent,
                        width: 2.5)),
              ),
              child: Text(
                _tabTitle(f),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active
                      ? AppColors.primaryOrange
                      : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ));
        }).toList(),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final OrdersLoaded loaded;
  final OrdersState state;
  const _OrderList({required this.loaded, required this.state});

  List<Order> _ordersForFilter() {
    switch (loaded.activeFilter) {
      case OrderFilter.newOrders:
        return loaded.newOrders;
      case OrderFilter.preparing:
        return loaded.preparingOrders;
      case OrderFilter.ready:
        return loaded.readyOrders;
      case OrderFilter.all:
        return loaded.allOrders;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = _ordersForFilter();
    if (orders.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.receipt_long_outlined,
            size: 64, color: AppColors.textSecondary),
        const SizedBox(height: AppSpacing.md),
        Text(AppStrings.noOrders,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(AppStrings.noOrdersSubtitle,
            style: Theme.of(context).textTheme.bodyMedium),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: orders.length,
      itemBuilder: (_, i) => _OrderCard(
        order: orders[i],
        state: state,
        queuePosition:
            loaded.activeFilter == OrderFilter.newOrders ? (i + 1) : null,
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final Order order;
  final OrdersState state;
  final int? queuePosition;
  const _OrderCard(
      {required this.order, required this.state, this.queuePosition});
  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.order.secondsUntilAutoCancel;
    if (widget.order.status == OrderStatus.placed) _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _secondsLeft = widget.order.secondsUntilAutoCancel);
      if (_secondsLeft > 0) _startTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isLoading = widget.state is OrderActionInProgress &&
        (widget.state as OrderActionInProgress).orderId == order.id;

    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#${order.counterCode}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.studentFirstName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandBrown,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Bill #${order.billNumber} • ${DateFormatter.displayTime(order.placedAt)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.grey600),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(order.totalAmount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primaryOrange,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PAID',
                    style: TextStyle(
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ]),

          // Queue position and wait estimate for queued orders
          if (widget.queuePosition != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.secondaryOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Queue #${widget.queuePosition} • Est. wait ~${(widget.queuePosition! * 2)} min',
                style: const TextStyle(
                  color: AppColors.secondaryOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xs),
          Text(
            order.items.map((i) => '${i.quantity}× ${i.name}').join(', '),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Actions
          if (order.status == OrderStatus.placed) ...[
            _TimerBar(secondsLeft: _secondsLeft),
            const SizedBox(height: AppSpacing.sm),
            if (isLoading)
              const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primaryOrange))
            else
              Row(children: [
                const Expanded(
                  child: Text(
                    'Queued - capacity and batch controls start preparation automatically.',
                    style: TextStyle(fontSize: 14, color: AppColors.grey600),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton(
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(96, 52)),
                  onPressed: () => _showRejectDialog(context, order.id),
                  child: const Text(AppStrings.reject),
                ),
              ]),
          ],
          if (order.status == OrderStatus.accepted) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
                'Accepted ${DateFormatter.displayDateTime(order.acceptedAt ?? order.placedAt)}',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            if (isLoading)
              const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primaryOrange))
            else
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _markReady(context, order),
                  child: const Text(AppStrings.markReady),
                ),
              ),
          ],
          if (order.status == OrderStatus.ready) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(children: [
              const Icon(Icons.check_circle,
                  color: AppColors.vendorTeal, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Text('Ready • Waiting for student',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.vendorTeal)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successGreen),
                icon: const Icon(Icons.verified_outlined, color: Colors.white),
                    onPressed: () => _openOtpSheet(context, order),
                label: const Text('Hand Over',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
          ],
          if (order.status == OrderStatus.collected)
            Chip(
                label: const Text('Collected ✓'),
                backgroundColor: AppColors.successGreen.withValues(alpha: 0.1),
                labelStyle: const TextStyle(color: AppColors.successGreen)),
          if (order.status == OrderStatus.cancelled ||
              order.status == OrderStatus.refunded)
            Chip(
                label: Text(order.status == OrderStatus.cancelled
                    ? 'Cancelled'
                    : 'Refunded'),
                backgroundColor: AppColors.errorRed.withValues(alpha: 0.1),
                labelStyle: const TextStyle(color: AppColors.errorRed)),
        ]),
      ),
    );
  }

  void _markReady(BuildContext context, Order order) {
    context.read<OrdersCubit>().markReady(order.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text(AppStrings.markedReady),
      action: SnackBarAction(
        label: AppStrings.undo,
        onPressed: () => context.read<OrdersCubit>().undoReady(order.id),
      ),
      duration: const Duration(seconds: 5),
    ));
  }

  Future<void> _openOtpSheet(BuildContext context, Order order) async {
    final result = await showModalBottomSheet<HandoverResult?>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg))),
      builder: (_) => OtpEntrySheet(order: order, stallId: sl<LocalStorageService>().getStallIdDirect() ?? order.stallId, handoverService: HandoverService(sl<OrderRepository>()), onSuccess: (sheetResult) => Navigator.of(context, rootNavigator: true).pop(sheetResult)),
    );
    if (!context.mounted || result == null) return;
    if (result.isSuccess) {
      await context.read<OrdersCubit>().markCollected(order.id);
      if (!context.mounted) return;
      await HapticFeedback.mediumImpact();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order #${order.billNumber} handed over to ${order.studentFirstName}'), backgroundColor: AppColors.successGreen));
    }
  }

  Future<void> _showRejectDialog(BuildContext context, String orderId) async {
    final ordersCubit = context.read<OrdersCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<_RejectResult>(
      context: context,
      builder: (dialogContext) {
        CancelReason? reason;
        var isSubmitting = false;
        return StatefulBuilder(
            builder: (ctx, setState) => AlertDialog(
                  title: const Text('Reject Order'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Select a reason (optional):'),
                    ...CancelReason.values
                        .map((r) => RadioListTile<CancelReason>(
                              title: Text(r.label),
                              value: r,
                              groupValue: reason,
                              onChanged: (v) => setState(() => reason = v),
                            )),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: isSubmitting
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                        child: const Text('Back')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.errorRed),
                      onPressed: isSubmitting ? null : () async {
                        setState(() => isSubmitting = true);
                        final error = await ordersCubit.rejectOrder(orderId, reason: reason);
                        if (!ctx.mounted) return;
                        if (Navigator.of(dialogContext).canPop()) {
                          Navigator.of(dialogContext).pop(_RejectResult(error: error));
                        }
                      },
                      child: isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                          : const Text('Reject & Refund'),
                    ),
                  ],
                ));
      },
    );
    if (!mounted || result == null) return;
    final order = widget.order;
    final message = result.error == null
        ? 'Order #${order.billNumber} rejected & refunded'
        : result.error!;
    messenger.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: result.error == null ? AppColors.successGreen : AppColors.errorRed,
    ));
  }
}

class _RejectResult {
  final String? error;
  const _RejectResult({this.error});
}

class _TimerBar extends StatelessWidget {
  final int secondsLeft;
  const _TimerBar({required this.secondsLeft});

  @override
  Widget build(BuildContext context) {
    final frac = (secondsLeft / 180.0).clamp(0.0, 1.0);
    final isUrgent = secondsLeft <= 60;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.timer_outlined,
            size: 14,
            color: isUrgent ? AppColors.errorRed : AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          isUrgent
              ? 'HURRY: $secondsLeft s before refund'
              : 'Auto-accept in: $secondsLeft s',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isUrgent ? FontWeight.w700 : FontWeight.w400,
            color: isUrgent ? AppColors.errorRed : AppColors.textSecondary,
          ),
        ),
      ]),
      const SizedBox(height: AppSpacing.xs),
      LinearProgressIndicator(
        value: frac,
        color: isUrgent ? AppColors.errorRed : AppColors.primaryOrange,
        backgroundColor: AppColors.grey200,
      ),
    ]);
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.errorRed),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      );
}
