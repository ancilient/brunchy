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
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold)),
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
            color: AppColors.primaryOrange,
            onRefresh: () => context.read<MenuCubit>().loadMenu(_getStallId()),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 80, top: AppSpacing.sm),
              children: [
                // Summary Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      _buildCountBadge('Total', '$total', AppColors.grey700, AppColors.grey100),
                      const SizedBox(width: AppSpacing.sm),
                      _buildCountBadge('Available', '$available', AppColors.vendorTeal, AppColors.vendorTeal.withValues(alpha: 0.12)),
                      const SizedBox(width: AppSpacing.sm),
                      _buildCountBadge('Sold Out', '$soldOut', AppColors.errorRed, AppColors.errorRed.withValues(alpha: 0.12)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                ...grouped.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
                        child: Text(
                          entry.key.toUpperCase(),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.grey600,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                        ),
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

  Widget _buildCountBadge(String label, String value, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 11)),
          ],
        ),
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
