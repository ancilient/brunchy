// lib/features/inventory/widgets/inventory_item_row.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/adjustment_reason.dart';
import '../../../data/models/inventory_item.dart';

class InventoryItemRow extends StatelessWidget {
  final InventoryItem item;
  final ValueChanged<int> onStockChanged;
  final ValueChanged<AdjustmentReason> onReasonChanged;

  const InventoryItemRow({
    super.key,
    required this.item,
    required this.onStockChanged,
    required this.onReasonChanged,
  });

  void _showReasonSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adjustment Reason: ${item.menuItemName}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Select why this inventory count is being adjusted:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.grey600),
            ),
            const SizedBox(height: AppSpacing.md),
            ...AdjustmentReason.values.map((reason) {
              final isSelected = item.reason == reason;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? AppColors.primaryOrange : AppColors.grey500,
                ),
                title: Text(reason.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onReasonChanged(reason);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canDecrement = item.currentStock > 0;
    final canIncrement = item.currentStock < item.openingStock;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: const BorderSide(color: AppColors.grey200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onLongPress: () => _showReasonSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Item details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.menuItemName,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Opening: ${item.openingStock}',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.grey600),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        GestureDetector(
                          onTap: () => _showReasonSheet(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.grey100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.reason.label,
                                  style: const TextStyle(fontSize: 10, color: AppColors.grey700),
                                ),
                                const Icon(Icons.arrow_drop_down, size: 14, color: AppColors.grey700),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Sold today count
                    Text(
                      '${item.soldToday} sold today',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: item.soldToday > 0 ? AppColors.primaryOrange : AppColors.grey500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Stepper: - [Count] +
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Minus button (min 44px)
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: canDecrement ? AppColors.grey100 : AppColors.grey50,
                      foregroundColor: canDecrement ? AppColors.brandBrown : AppColors.grey400,
                      minimumSize: const Size(44, 44),
                    ),
                    icon: const Icon(Icons.remove, size: 20),
                    onPressed: canDecrement ? () => onStockChanged(item.currentStock - 1) : null,
                  ),
                  Container(
                    width: 44,
                    alignment: Alignment.center,
                    child: Text(
                      '${item.currentStock}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandBrown,
                      ),
                    ),
                  ),
                  // Plus button (min 44px)
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: canIncrement ? AppColors.primaryOrange.withValues(alpha: 0.12) : AppColors.grey50,
                      foregroundColor: canIncrement ? AppColors.primaryOrange : AppColors.grey400,
                      minimumSize: const Size(44, 44),
                    ),
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: canIncrement ? () => onStockChanged(item.currentStock + 1) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
