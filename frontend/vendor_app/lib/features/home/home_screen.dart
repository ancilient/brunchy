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
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Image.asset('assets/images/logo_mascot.png'),
            ),
            tooltip: 'Open Menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              stallName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.brandBrown,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              canteenName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.grey600,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          BlocBuilder<OrdersCubit, OrdersState>(
            builder: (_, state) {
              final isConnected = state is! OrdersLoaded ||
                  state.connectionState == RealtimeConnectionState.connected;
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Tooltip(
                  message: isConnected
                      ? 'Live Connection: Connected'
                      : 'Reconnecting...',
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected
                          ? AppColors.successGreen
                          : AppColors.warningAmber,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: widget.shell,
      bottomNavigationBar: BlocBuilder<OrdersCubit, OrdersState>(
        builder: (context, state) {
          final newCount = state is OrdersLoaded ? state.newOrderCount : 0;
          return BottomNavigationBar(
            currentIndex: widget.shell.currentIndex,
            onTap: (index) {
              widget.shell.goBranch(index,
                  initialLocation: index == widget.shell.currentIndex);
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppColors.primaryOrange,
            unselectedItemColor: AppColors.grey500,
            items: [
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: newCount > 0,
                  label: Text('$newCount'),
                  child: const Icon(Icons.receipt_long_outlined),
                ),
                activeIcon: Badge(
                  isLabelVisible: newCount > 0,
                  label: Text('$newCount'),
                  child: const Icon(Icons.receipt_long),
                ),
                label: 'Orders',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.pin_outlined),
                activeIcon: Icon(Icons.pin),
                label: 'Handover',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.restaurant_menu_outlined),
                activeIcon: Icon(Icons.restaurant_menu),
                label: 'Menu',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2),
                label: 'Inventory',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart),
                label: 'Dashboard',
              ),
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
            decoration: const BoxDecoration(color: AppColors.vendorTeal),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Image.asset('assets/branding/brunchy_vendor_badge_transparent.png', height: 50),
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
      builder: (_) => AlertDialog(
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
      builder: (ctx) => AlertDialog(
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
