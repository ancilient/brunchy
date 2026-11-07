// lib/features/menu/widgets/menu_item_tile.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/menu_item.dart';

class MenuItemTile extends StatelessWidget {
  final MenuItem item;
  final ValueChanged<bool> onToggleAvailability;
  final ValueChanged<int>? onStockChanged;
  final VoidCallback onEdit;

  const MenuItemTile({
    super.key,
    required this.item,
    required this.onToggleAvailability,
    this.onStockChanged,
    required this.onEdit,
  });

  void _showTapToTypeDialog(BuildContext context) {
    if (onStockChanged == null) return;
    final controller = TextEditingController(text: '${item.stock}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set Stock for ${item.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Available Units',
            hintText: 'Enter quantity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
            onPressed: () {
              final newStock = int.tryParse(controller.text.trim()) ?? item.stock;
              Navigator.pop(ctx);
              onStockChanged!(newStock.clamp(0, 999));
              if (newStock == 0 && item.isAvailable) {
                onToggleAvailability(false);
              } else if (newStock > 0 && !item.isAvailable) {
                onToggleAvailability(true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRestockSheet(BuildContext context) {
    if (onStockChanged == null) return;
    final customCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.md,
          top: AppSpacing.lg,
          left: AppSpacing.lg,
          right: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildVegNonVegBadge(item.isVeg),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Restock: ${item.name}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Current stock: ${item.stock} units',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.grey600),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Quick Add:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [5, 10, 20, 50].map((add) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.1),
                    label: Text('+$add', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      final newTotal = item.stock + add;
                      onStockChanged!(newTotal);
                      if (!item.isAvailable) onToggleAvailability(true);
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Custom amount',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    minimumSize: const Size(80, 48),
                  ),
                  onPressed: () {
                    final added = int.tryParse(customCtrl.text.trim()) ?? 0;
                    if (added > 0) {
                      Navigator.pop(ctx);
                      final newTotal = item.stock + added;
                      onStockChanged!(newTotal);
                      if (!item.isAvailable) onToggleAvailability(true);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVegNonVegBadge(bool isVeg) {
    final color = isVeg ? AppColors.successGreen : AppColors.errorRed;
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    String text;
    Color bg;
    Color fg;

    if (item.stock == 0 || !item.isAvailable) {
      text = 'Sold Out';
      bg = AppColors.errorRed.withValues(alpha: 0.12);
      fg = AppColors.errorRed;
    } else if (item.isLowStock) {
      text = 'Low (${item.stock})';
      bg = AppColors.warningAmber.withValues(alpha: 0.15);
      fg = AppColors.warningAmber;
    } else {
      text = 'In Stock (${item.stock})';
      bg = AppColors.successGreen.withValues(alpha: 0.12);
      fg = AppColors.successGreen;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAvailable = item.isAvailable && item.stock > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(
          color: isAvailable ? AppColors.grey200 : AppColors.grey300,
        ),
      ),
      color: isAvailable ? AppColors.white : AppColors.grey50,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item Photo / Icon Placeholder (min 48dp)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 52,
                    height: 52,
                    color: AppColors.background,
                    child: Center(
                      child: Image.asset(
                        'assets/images/logo_mascot.png',
                        width: 38,
                        height: 38,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                // Name, Veg Badge & Category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildVegNonVegBadge(item.isVeg),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: isAvailable ? AppColors.brandBrown : AppColors.grey500,
                                decoration: isAvailable ? null : TextDecoration.lineThrough,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            CurrencyFormatter.format(item.price),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isAvailable ? AppColors.primaryOrange : AppColors.grey500,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (item.category != null && item.category!.isNotEmpty) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '• ${item.category!}',
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.grey600),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildStatusChip(),
                          if (item.isPendingApproval) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warningAmber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Pending Approval',
                                style: TextStyle(color: AppColors.warningAmber, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Edit & On/Off switch (min 48dp targets)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.grey600),
                      tooltip: 'Edit Item',
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      onPressed: onEdit,
                    ),
                    Semantics(
                      label: '${item.name} availability toggle',
                      child: Switch(
                        value: isAvailable,
                        activeColor: AppColors.vendorTeal,
                        activeTrackColor: AppColors.vendorTeal.withValues(alpha: 0.3),
                        inactiveThumbColor: AppColors.grey400,
                        inactiveTrackColor: AppColors.grey200,
                        onChanged: (val) {
                          onToggleAvailability(val);
                          if (!val && onStockChanged != null) {
                            // If toggled off, keep stock or leave as is
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.xs),

            // Quantity Stepper with Quick Chips
            Row(
              children: [
                // Decrement button (min 48dp)
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: item.stock > 0 ? AppColors.grey200 : AppColors.grey100,
                      foregroundColor: item.stock > 0 ? AppColors.brandBrown : AppColors.grey400,
                    ),
                    icon: const Icon(Icons.remove, size: 20),
                    onPressed: item.stock > 0 && onStockChanged != null
                        ? () {
                            final next = item.stock - 1;
                            onStockChanged!(next);
                            if (next == 0) onToggleAvailability(false);
                          }
                        : null,
                  ),
                ),

                // Tap number to type directly
                InkWell(
                  onTap: () => _showTapToTypeDialog(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 54,
                    height: 48,
                    alignment: Alignment.center,
                    child: Text(
                      '${item.stock}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandBrown,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),

                // Increment button (min 48dp)
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.15),
                      foregroundColor: AppColors.primaryOrange,
                    ),
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: onStockChanged != null
                        ? () {
                            final next = item.stock + 1;
                            onStockChanged!(next);
                            if (!item.isAvailable) onToggleAvailability(true);
                          }
                        : null,
                  ),
                ),

                const Spacer(),

                // Quick add chips +5, +10, +20
                if (onStockChanged != null) ...[
                  ...[5, 10, 20].map((quickAdd) => Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: ActionChip(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          backgroundColor: AppColors.grey100,
                          label: Text('+$quickAdd', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            final next = item.stock + quickAdd;
                            onStockChanged!(next);
                            if (!item.isAvailable) onToggleAvailability(true);
                          },
                        ),
                      )),
                ],

                // Restock button on Sold-out or Low items
                if (item.isLowStock || item.stock == 0 || !item.isAvailable)
                  Padding(
                    padding: const EdgeInsets.only(left: 6.0),
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        minimumSize: const Size(0, 36),
                      ),
                      icon: const Icon(Icons.inventory, size: 14, color: AppColors.primaryOrange),
                      label: const Text('Restock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                      onPressed: () => _showRestockSheet(context),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
