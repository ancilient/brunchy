// lib/features/menu/menu_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/menu_item.dart';
import '../../injection_container.dart';
import '../../services/local_storage_service.dart';
import 'menu_cubit.dart';
import 'menu_state.dart';
import 'widgets/add_edit_item_sheet.dart';
import 'widgets/menu_item_tile.dart';
import '../../core/widgets/rolling_number.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  String _getStallId() {
    return sl<LocalStorageService>().getStallId(DateFormatter.todayKey()) ?? 'stall_001';
  }

  void _openAddEditSheet(BuildContext context, {MenuItem? item}) {
    final cubit = context.read<MenuCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      // Header and buttons stay put; the form in between scrolls on short screens.
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => AddEditItemSheet(existingItem: item, menuCubit: cubit),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Item', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
        onPressed: () => _openAddEditSheet(context),
      ),
      body: BlocConsumer<MenuCubit, MenuState>(
        listener: (context, state) {
          if (state is MenuError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.errorRed,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is MenuLoading || state is MenuInitial) {
            return _buildShimmerLoading();
          }

          if (state is MenuError) {
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
                      onPressed: () => context.read<MenuCubit>().loadMenu(_getStallId()),
                    ),
                  ],
                ),
              ),
            );
          }

          final List<MenuItem> items;
          if (state is MenuLoaded) {
            items = state.items;
          } else if (state is MenuSaving) {
            items = state.items;
          } else {
            items = [];
          }

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.restaurant_menu, size: 64, color: AppColors.grey400),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No Menu Items Yet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Tap the "+ Add Item" button below to add your first dish.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.grey600),
                    ),
                  ],
                ),
              ),
            );
          }

          final total = items.length;
          final available = items.where((i) => i.isAvailable).length;
          final soldOut = total - available;

          // Group by category
          final Map<String, List<MenuItem>> grouped = {};
          for (final item in items) {
            final cat = item.category?.trim().isNotEmpty == true ? item.category! : 'General';
            grouped.putIfAbsent(cat, () => []).add(item);
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => context.read<MenuCubit>().loadMenu(_getStallId()),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 80, top: AppSpacing.sm),
              children: [
                _buildOverview(total, available, soldOut),
                ...grouped.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 4),
                        child: Row(children: [
                          Text(
                            entry.key.toUpperCase(),
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w800, letterSpacing: 1),
                          ),
                          const SizedBox(width: 6),
                          Text('${entry.value.length}', style: const TextStyle(fontSize: 11, color: AppColors.grey500, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      ...entry.value.map((item) {
                        return MenuItemTile(
                          item: item,
                          onToggleAvailability: (val) {
                            context.read<MenuCubit>().toggleAvailability(
                                  itemId: item.id,
                                  isAvailable: val,
                                );
                          },
                          onStockChanged: (newStock) {
                            context.read<MenuCubit>().updateStock(
                                  itemId: item.id,
                                  stock: newStock,
                                );
                          },
                          onEdit: () => _openAddEditSheet(context, item: item),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  /// One compact card: the item count on the left, an availability bar with a legend on the right.
  Widget _buildOverview(int total, int available, int soldOut) {
    final share = total == 0 ? 0.0 : available / total;
    const valueStyle = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary);
    Widget legend(Color color, String label, int count, [String? extra]) => Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const Spacer(),
          RollingNumber(count, style: valueStyle),
          if (extra != null) Text(extra, style: valueStyle),
        ]);
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.restaurant_menu_rounded, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          RollingNumber(total, style: const TextStyle(fontSize: 20, height: 1.1, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const Text('items on the menu', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
        ]),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // available (teal) vs sold out (red), in proportion
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 6,
                child: Row(children: [
                  if (available > 0) Expanded(flex: available, child: Container(color: AppColors.brandTeal)),
                  if (available > 0 && soldOut > 0) const SizedBox(width: 2),
                  if (soldOut > 0) Expanded(flex: soldOut, child: Container(color: AppColors.errorRed)),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            legend(AppColors.brandTeal, 'Available', available, '  ·  ${(share * 100).round()}%'),
            const SizedBox(height: 3),
            legend(AppColors.errorRed, 'Sold out', soldOut),
          ]),
        ),
      ]),
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
            height: 72,
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
