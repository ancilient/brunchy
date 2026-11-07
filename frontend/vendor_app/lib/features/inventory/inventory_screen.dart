// lib/features/inventory/inventory_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/date_formatter.dart';
import '../../injection_container.dart';
import '../../services/local_storage_service.dart';
import '../../data/models/inventory_item.dart';
import '../../data/models/adjustment_reason.dart';
import 'inventory_cubit.dart';
import 'inventory_state.dart';
import 'widgets/inventory_item_row.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  String _getStallId() {
    return sl<LocalStorageService>().getStallId(DateFormatter.todayKey()) ?? 'stall_001';
  }

  Future<void> _showResetStockDialog(BuildContext context, String stallId, String date, List<InventoryItem> items) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Daily Stock?'),
        content: const Text(
          'This will reset the current stock of all items back to their opening values for today. This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset Stock'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final cubit = context.read<InventoryCubit>();
      for (final item in items) {
        await cubit.updateStock(
          stallId: stallId,
          itemId: item.id,
          newStock: item.openingStock,
          reason: AdjustmentReason.correction,
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All item stock reset to opening stock.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stallId = _getStallId();
    final today = DateFormatter.todayKey();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<InventoryCubit, InventoryState>(
        listener: (context, state) {
          if (state is InventoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.errorRed),
            );
          }
        },
        builder: (context, state) {
          if (state is InventoryLoading || state is InventoryInitial) {
            return _buildShimmerLoading();
          }

          if (state is InventoryError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.errorRed),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text(AppStrings.retry),
                      onPressed: () => context.read<InventoryCubit>().loadInventory(
                            stallId: stallId,
                            date: today,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is InventoryEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.grey400),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No Inventory Configured',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Inventory items will appear here automatically when linked with menu dishes.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.grey600),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is InventoryLoaded) {
            final items = state.items;

            return RefreshIndicator(
              color: AppColors.primaryOrange,
              onRefresh: () => context.read<InventoryCubit>().loadInventory(
                    stallId: stallId,
                    date: today,
                  ),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [
                  // Restock banner
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.vendorTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.vendorTeal.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: AppColors.vendorTeal, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Pre-filled from yesterday\'s closing stock. Tap + / − to adjust current physical count.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.brandBrown,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: const Size(0, 32),
                            ),
                            icon: const Icon(Icons.restart_alt, size: 16, color: AppColors.primaryOrange),
                            label: const Text('Reset Daily Stock', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () => _showResetStockDialog(context, stallId, today, items),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Inventory list
                  ...items.map((item) {
                    return InventoryItemRow(
                      item: item,
                      onStockChanged: (newStock) {
                        context.read<InventoryCubit>().updateStock(
                              stallId: stallId,
                              itemId: item.id,
                              newStock: newStock,
                              reason: item.reason,
                            );
                      },
                      onReasonChanged: (reason) {
                        context.read<InventoryCubit>().updateStock(
                              stallId: stallId,
                              itemId: item.id,
                              newStock: item.currentStock,
                              reason: reason,
                            );
                      },
                    );
                  }),

                  // Explanatory footer note (R-18 mandatory)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.grey100,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: AppColors.grey600),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              'Note: "Sold today" reflects total stock reduction (sales + waste + spoilage). It may differ from the sales dashboard order count.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.grey600,
                                    fontSize: 11,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 6,
      itemBuilder: (_, __) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 76,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
        );
      },
    );
  }
}
