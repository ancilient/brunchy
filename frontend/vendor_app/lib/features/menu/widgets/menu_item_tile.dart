// lib/features/menu/widgets/menu_item_tile.dart
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/menu_item.dart';
import '../../../core/widgets/rolling_number.dart';
import '../../../core/widgets/app_dialog.dart';

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
      builder: (ctx) => AppDialog(
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    label: Text('+$add', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
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
                    backgroundColor: AppColors.primary,
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
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.4),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Container(
          width: 6,
          height: 6,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAvailable = item.isAvailable && item.stock > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 3),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(
          color: isAvailable ? AppColors.grey200 : AppColors.grey300,
        ),
      ),
      color: isAvailable ? AppColors.white : AppColors.grey50,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
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
                    width: 44,
                    height: 44,
                    color: AppColors.background,
                    child: _buildItemPhoto(item.imageUrl),
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
                                fontSize: 14,
                                color: isAvailable ? AppColors.ink : AppColors.grey500,
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
                              fontSize: 13,
                              color: isAvailable ? AppColors.primary : AppColors.grey500,
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
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.grey600),
                      tooltip: 'Edit Item',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: onEdit,
                    ),
                    Semantics(
                      label: '${item.name} availability toggle',
                      child: Transform.scale(
                        scale: 0.8,
                        child: Switch(
                        value: isAvailable,
                        activeColor: AppColors.brandTeal,
                        activeTrackColor: AppColors.brandTeal.withValues(alpha: 0.3),
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
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 6),

            // Stock: a compact [ - n + ] pill, quick-add chips and (when low / sold out) Restock.
            // The right-hand group scales down instead of overflowing on narrow screens.
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.grey50,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _miniButton(
                      icon: Icons.remove,
                      bg: item.stock > 0 ? AppColors.white : AppColors.grey100,
                      fg: item.stock > 0 ? AppColors.ink : AppColors.grey400,
                      onTap: item.stock > 0 && onStockChanged != null
                          ? () {
                              final next = item.stock - 1;
                              onStockChanged!(next);
                              if (next == 0) onToggleAvailability(false);
                            }
                          : null,
                    ),
                    // Tap the number to type it
                    InkWell(
                      onTap: () => _showTapToTypeDialog(context),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 32,
                        height: 26,
                        alignment: Alignment.center,
                        child: RollingNumber(item.stock,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 14)),
                      ),
                    ),
                    _miniButton(
                      icon: Icons.add,
                      bg: AppColors.primary,
                      fg: AppColors.white,
                      onTap: onStockChanged != null
                          ? () {
                              final next = item.stock + 1;
                              onStockChanged!(next);
                              if (!item.isAvailable) onToggleAvailability(true);
                            }
                          : null,
                    ),
                  ]),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (onStockChanged != null)
                          for (final quickAdd in const [5, 10, 20])
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: _chip(
                                label: '+$quickAdd',
                                onTap: () {
                                  onStockChanged!(item.stock + quickAdd);
                                  if (!item.isAvailable) onToggleAvailability(true);
                                },
                              ),
                            ),
                        if (item.isLowStock || item.stock == 0 || !item.isAvailable)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _chip(
                              label: 'Restock',
                              icon: Icons.inventory_2_outlined,
                              color: AppColors.primary,
                              onTap: () => _showRestockSheet(context),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The item's photo: an asset, a web link, or a file picked with the camera/gallery (image_helper.dart).
  Widget _buildItemPhoto(String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('assets/')) {
        return Image.asset(imageUrl, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholder());
      }
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        return Image.network(imageUrl, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholder());
      }
      if (!kIsWeb) {
        return Image.file(File(imageUrl), width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholder());
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() => Center(child: Image.asset('assets/brand/burger.png', width: 32, height: 32));

  Widget _miniButton({required IconData icon, required Color bg, required Color fg, VoidCallback? onTap}) => Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 26, height: 26, child: Icon(icon, size: 14, color: fg)),
        ),
      );

  Widget _chip({required String label, required VoidCallback onTap, IconData? icon, Color? color}) {
    final fg = color ?? AppColors.textPrimary;
    return Material(
      color: color == null ? AppColors.grey100 : color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
            Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
          ]),
        ),
      ),
    );
  }
}
