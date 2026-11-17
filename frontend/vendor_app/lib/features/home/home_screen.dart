// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../injection_container.dart';
import '../../services/local_storage_service.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../core/utils/date_formatter.dart';
import '../orders/orders_cubit.dart';
import '../menu/menu_cubit.dart';
import '../inventory/inventory_cubit.dart';
import '../dashboard/dashboard_cubit.dart';
import '../orders/orders_state.dart';
import '../../data/models/dashboard_period.dart';
import '../../services/realtime_connection_state.dart';
import '../stall_control/stall_control_cubit.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/sliding_tabs.dart';
import '../../core/widgets/app_dialog.dart';

class HomeScreen extends StatefulWidget {
  final StatefulNavigationShell shell;
  const HomeScreen({super.key, required this.shell});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final storage = sl<LocalStorageService>();
    final stallId = storage.getStallId(DateFormatter.todayKey()) ?? 'stall_001';
    // Load all tabs
    sl<OrdersCubit>().loadOrders(stallId);
    sl<MenuCubit>().loadMenu(stallId);
    sl<InventoryCubit>()
        .loadInventory(stallId: stallId, date: DateFormatter.todayKey());
    sl<DashboardCubit>()
        .loadDashboard(stallId: stallId, period: DashboardPeriod.today);
    final staffId = storage.getVendor()?.id;
    if (staffId != null) {
      sl<StallControlCubit>().load(stallId: stallId, staffId: staffId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = sl<LocalStorageService>();
    final stallName = storage.getStallName() ?? 'Burger Point';
    final canteenName = storage.getCanteenName() ?? 'Main Canteen';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 58,
        titleSpacing: 0,
        surfaceTintColor: Colors.transparent,
        // Menu button on its own, separate from the logo.
        leading: Builder(
          builder: (ctx) => Center(
            child: Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Scaffold.of(ctx).openDrawer(),
                child: const Tooltip(
                  message: 'Open menu',
                  child: SizedBox(width: 32, height: 32, child: Icon(Icons.menu_rounded, size: 18, color: AppColors.ink)),
                ),
              ),
            ),
          ),
        ),
        // Brand block: logo, stall name, canteen.
        title: Row(children: [
          const BrandLogo(size: 36, shadow: false),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stallName,
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(children: [
                  const Icon(Icons.storefront_rounded, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      canteenName,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ]),
        actions: [
          // Live connection status as a clear pill.
          BlocBuilder<OrdersCubit, OrdersState>(
            builder: (_, state) {
              final isConnected = state is! OrdersLoaded ||
                  state.connectionState == RealtimeConnectionState.connected;
              final color = isConnected ? AppColors.successGreen : AppColors.warningAmber;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Tooltip(
                  message: isConnected ? 'Live connection: connected' : 'Reconnecting...',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: color.withValues(alpha: 0.35)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(isConnected ? 'Live' : 'Reconnecting',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                    ]),
                  ),
                ),
              );
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.divider),
        ),
      ),
      drawer: _buildDrawer(context),
      body: widget.shell,
      bottomNavigationBar: BlocBuilder<OrdersCubit, OrdersState>(
        builder: (context, state) {
          final newCount = state is OrdersLoaded ? state.newOrderCount : 0;
          return AnimatedDock(
            currentIndex: widget.shell.currentIndex,
            onTap: (index) => widget.shell.goBranch(index, initialLocation: index == widget.shell.currentIndex),
            items: [
              DockItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Orders', badge: newCount),
              const DockItem(icon: Icons.pin_outlined, activeIcon: Icons.pin, label: 'Handover'),
              const DockItem(icon: Icons.restaurant_menu_outlined, activeIcon: Icons.restaurant_menu, label: 'Menu'),
              const DockItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Inventory'),
              const DockItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Dashboard'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final storage = sl<LocalStorageService>();
    final vendor = storage.getVendor();
    final stallName = storage.getStallName() ?? 'Burger Point';
    final canteenName = storage.getCanteenName() ?? 'Main Canteen';

    return Drawer(
      child: SafeArea(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.brandTeal),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const BrandLogo(size: 56, shadow: false),
              const SizedBox(height: AppSpacing.sm),
              Text(vendor?.name ?? 'Vendor Partner',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              Text('$stallName • $canteenName',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70)),
            ]),
          ),
          ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Past Orders'),
              onTap: () {
                Navigator.pop(context);
                context.push('/past-orders');
              }),
          ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              }),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.wb_twilight_outlined,
                color: AppColors.warningAmber),
            title: const Text('End Day',
                style: TextStyle(
                    color: AppColors.warningAmber,
                    fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.pop(context);
              _showEndDayDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.errorRed),
            title: const Text('Log Out',
                style: TextStyle(
                    color: AppColors.errorRed, fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.pop(context);
              _confirmLogout(context);
            },
          ),
          Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text('Brunchy Vendor v1.0.0+1',
                  style: Theme.of(context).textTheme.labelSmall)),
        ]),
      ),
    );
  }

  Future<void> _showEndDayDialog(BuildContext context) async {
    final ordersState = sl<OrdersCubit>().state;
    int activeCount = 0;
    if (ordersState is OrdersLoaded) {
      activeCount = ordersState.newOrders.length +
          ordersState.preparingOrders.length +
          ordersState.readyOrders.length;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: Text(activeCount > 0 ? '⚠ Active Orders' : 'End Day?'),
        content: Text(activeCount > 0
            ? 'You have $activeCount active orders. Ending your day will cancel them and refund the students. This cannot be undone.'
            : 'End your day? This saves today\'s inventory as tomorrow\'s opening stock.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(activeCount > 0 ? 'Keep Working' : 'Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.pop(context, true),
            child: Text(activeCount > 0 ? 'Cancel All & End Day' : 'End Day'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final storage = sl<LocalStorageService>();
      final stallId =
          storage.getStallId(DateFormatter.todayKey()) ?? 'stall_001';
      // [API-017] POST /stalls/{stallId}/inventory/end-day
      await sl<InventoryRepository>()
          .closeDay(stallId: stallId, forceClose: activeCount > 0);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Day ended. Tomorrow\'s opening stock saved.')));
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final storage = sl<LocalStorageService>();
    final hasOffline = storage.hasPendingOfflineActions;
    final queueCount = storage.getOfflineQueue().length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: Text(hasOffline ? '⚠ Unsynced Offline Actions' : 'Log Out?'),
        content: Text(hasOffline
            ? 'You have $queueCount pending action(s) waiting to sync with the server. Logging out now will discard these actions.\n\nAre you sure you want to log out?'
            : 'Are you sure you want to log out of Brunchy Vendor? You will need to sign in again to access this stall.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await storage.clearSession();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }
}
