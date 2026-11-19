import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/page_transitions.dart';
import '../../data/repositories/auth_repository.dart';
import '../../injection_container.dart';
import '../../services/local_storage_service.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/choose_stall_screen.dart';
import '../../features/auth/auth_cubit.dart';
import '../../features/auth/choose_stall_cubit.dart';
import '../../features/home/home_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/orders/order_detail_screen.dart';
import '../../features/orders/past_orders_screen.dart';
import '../../features/orders/orders_cubit.dart';
import '../../features/handover/handover_screen.dart';
import '../../features/menu/menu_screen.dart';
import '../../features/menu/menu_cubit.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/inventory/inventory_cubit.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/dashboard/dashboard_cubit.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/stall_control/stall_control_cubit.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      // Splash handles its own routing — no redirect needed here
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (_, state) => sharedAxisPage(state, const SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => sharedAxisPage(state, BlocProvider(
          create: (_) =>
              AuthCubit(sl<AuthRepository>(), sl<LocalStorageService>()),
          child: const LoginScreen(),
        )),
      ),
      GoRoute(
        path: '/choose-stall',
        pageBuilder: (_, state) => sharedAxisPage(state, BlocProvider(
          create: (_) => ChooseStallCubit(sl<AuthRepository>()),
          child: const ChooseStallScreen(),
        )),
      ),
      GoRoute(
        path: '/order/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) =>
            sharedAxisPage(state, OrderDetailScreen(orderId: state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/past-orders',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => sharedAxisPage(state, BlocProvider.value(
          value: sl<OrdersCubit>(),
          child: const PastOrdersScreen(),
        )),
      ),
      GoRoute(
        path: '/handover',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) =>
            sharedAxisPage(state, HandoverScreen(initialCode: state.uri.queryParameters['code'])),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => sharedAxisPage(state, BlocProvider(
          create: (_) =>
              AuthCubit(sl<AuthRepository>(), sl<LocalStorageService>()),
          child: const SettingsScreen(),
        )),
      ),
      StatefulShellRoute(
        parentNavigatorKey: _rootNavigatorKey,
        // Tabs slide like the student app (see page_transitions.dart); each tab keeps its state.
        navigatorContainerBuilder: (context, shell, children) =>
            AnimatedBranchContainer(currentIndex: shell.currentIndex, children: children),
        pageBuilder: (context, state, shell) => sharedAxisPage(state, MultiBlocProvider(
          providers: [
            BlocProvider.value(value: sl<OrdersCubit>()),
            BlocProvider.value(value: sl<MenuCubit>()),
            BlocProvider.value(value: sl<InventoryCubit>()),
            BlocProvider.value(value: sl<DashboardCubit>()),
            BlocProvider.value(value: sl<StallControlCubit>()),
          ],
          child: HomeScreen(shell: shell),
        )),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKey,
            routes: [
              GoRoute(
                  path: '/home/orders',
                  builder: (_, __) => const OrdersScreen()),
            ],
          ),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/home/handover',
                builder: (_, __) => const HandoverScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/home/menu', builder: (_, __) => const MenuScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/home/inventory',
                builder: (_, __) => const InventoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/home/dashboard',
                builder: (_, __) => const DashboardScreen()),
          ]),
        ],
      ),
    ],
  );
}
