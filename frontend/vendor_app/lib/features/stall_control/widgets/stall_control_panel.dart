// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/stall_control.dart';
import '../../../data/models/cancel_reason.dart';
import '../../orders/orders_cubit.dart';
import '../../orders/orders_state.dart';
import '../stall_control_cubit.dart';

class StallControlPanel extends StatelessWidget {
  const StallControlPanel({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<StallControlCubit, StallControlViewState>(
          builder: (context, state) {
        if (state is StallControlLoading) return const SizedBox.shrink();
        if (state is StallControlFailure)
          return _Banner(color: AppColors.errorRed, text: state.message);
        final ready = state as StallControlReady;
        final c = ready.control;
        if (c.isEmergencyStopped)
          return Card(
              color: AppColors.errorRed.withValues(alpha: .08),
              child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.warning_amber_rounded,
                              color: AppColors.errorRed),
                          SizedBox(width: 8),
                          Text('STALL CLOSED - EMERGENCY STOP',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.errorRed))
                        ]),
                        const SizedBox(height: 6),
                        Text(
                            '${c.emergencyReason?.label ?? 'Emergency'}${c.emergencyDetail == null ? '' : ': ${c.emergencyDetail}'}'),
                        if (ready.lastStop != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                  '${ready.lastStop!.refundedOrderIds.length} cancelled and refunded, ${ready.lastStop!.preparingOrderIds.length} need your choice.')),
                        const SizedBox(height: 8),
                        if (ready.lastStop != null &&
                            ready.lastStop!.preparingOrderIds.isNotEmpty)
                          OutlinedButton.icon(
                              onPressed: () => _showPreparingChoices(context),
                              icon: const Icon(Icons.restaurant),
                              label: const Text('Review preparing orders')),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                            onPressed: () =>
                                context.read<StallControlCubit>().reopen(),
                            icon: const Icon(Icons.lock_open),
                            label: const Text('Reopen stall')),
                      ])));
        if (c.mode == StallOperatingMode.paused)
          return _Banner(
              color: AppColors.warningAmber,
              text:
                  'PAUSED until ${TimeOfDay.fromDateTime(c.pausedUntil!).format(context)}');
        if (c.mode == StallOperatingMode.closedForDay)
          return Card(
              color: AppColors.errorRed.withValues(alpha: .08),
              child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(children: [
                    const Expanded(
                        child: Text('CLOSED FOR TODAY',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.errorRed))),
                    OutlinedButton(
                        onPressed: () =>
                            context.read<StallControlCubit>().reopen(),
                        child: const Text('Reopen'))
                  ])));
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorRed,
                      minimumSize: const Size.fromHeight(52)),
                  onPressed: () => _confirmEmergency(context),
                  icon: const Icon(Icons.warning_amber_rounded,
                      color: Colors.white),
                  label: const Text('Emergency stop + refund',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in [10, 15, 30])
                  OutlinedButton(
                      onPressed: () =>
                          context.read<StallControlCubit>().pause(m),
                      child: Text('Pause $m min')),
                OutlinedButton(
                    onPressed: () =>
                        context.read<StallControlCubit>().closeForDay(),
                    child: const Text('Close for today'))
              ]),
            ]);
      });
  Future<void> _confirmEmergency(BuildContext context) async {
    EmergencyStopReason? reason;
    final detail = TextEditingController();
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (ctx, setState) => AlertDialog(
                    title: const Text('Emergency stop + refund?'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(
                          'Queued orders will be cancelled and refunded. Choose a reason.'),
                      ...EmergencyStopReason.values.map((r) =>
                          RadioListTile<EmergencyStopReason>(
                              value: r,
                              groupValue: reason,
                              title: Text(r.label),
                              onChanged: (v) => setState(() => reason = v))),
                      if (reason == EmergencyStopReason.other)
                        TextField(
                            controller: detail,
                            autofocus: true,
                            decoration: const InputDecoration(
                                labelText: 'Required reason'))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Keep open')),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.errorRed),
                          onPressed: reason == null ||
                                  (reason == EmergencyStopReason.other &&
                                      detail.text.trim().isEmpty)
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  context
                                      .read<StallControlCubit>()
                                      .emergencyStop(reason!,
                                          detail: detail.text);
                                },
                          child: const Text('Stop and refund'))
                    ])));
    detail.dispose();
  }

  Future<void> _showPreparingChoices(BuildContext context) async {
    final ordersState = context.read<OrdersCubit>().state;
    final orders = ordersState is OrdersLoaded ? ordersState.preparingOrders : const [];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const Text('Preparing orders need your choice',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            const Text('Finish keeps food moving. Cancel & refund stops only this paid preparing order.'),
            const SizedBox(height: AppSpacing.md),
            ...orders.map((order) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('#${order.counterCode} - ${order.studentFirstName}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(order.itemsSummary),
                      const SizedBox(height: AppSpacing.sm),
                      Row(children: [
                        Expanded(child: OutlinedButton(
                          onPressed: () { context.read<OrdersCubit>().markReady(order.id); Navigator.pop(sheetContext); },
                          child: const Text('Finish order'),
                        )),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
                          onPressed: () { context.read<OrdersCubit>().cancelAndRefund(order.id, CancelReason.stallEmergency); Navigator.pop(sheetContext); },
                          child: const Text('Cancel & refund'),
                        )),
                      ]),
                    ]),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final String text;
  const _Banner({required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      color: color,
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)));
}
