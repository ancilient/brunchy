import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/order_repository.dart';
import 'data/repositories/menu_repository.dart';
import 'data/repositories/inventory_repository.dart';
import 'data/repositories/dashboard_repository.dart';
import 'data/mock/mock_auth_repository.dart';
import 'data/mock/mock_order_repository.dart';
import 'data/mock/mock_menu_repository.dart';
import 'data/mock/mock_inventory_repository.dart';
import 'data/mock/mock_dashboard_repository.dart';
import 'data/mock/mock_stall_control_repository.dart';
import 'data/repositories/stall_control_repository.dart';
import 'services/local_storage_service.dart';
import 'services/audio_service.dart';
import 'services/tts_service.dart';
import 'services/realtime_service.dart';
import 'features/orders/orders_cubit.dart';
import 'features/menu/menu_cubit.dart';
import 'features/inventory/inventory_cubit.dart';
import 'features/dashboard/dashboard_cubit.dart';
import 'features/stall_control/stall_control_cubit.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  final prefs = await SharedPreferences.getInstance();

  // Services
  sl.registerSingleton<LocalStorageService>(LocalStorageService(prefs));

  final audioService = AudioService();
  await audioService.init();
  sl.registerSingleton<AudioService>(audioService);

  final ttsService = TtsService();
  await ttsService.init();
  sl.registerSingleton<TtsService>(ttsService);

  // Repositories
  sl.registerSingleton<AuthRepository>(MockAuthRepository(prefs));

  final mockOrderRepo = MockOrderRepository();
  sl.registerSingleton<OrderRepository>(mockOrderRepo);
  sl.registerSingleton<MockOrderRepository>(mockOrderRepo);
  final mockStallControlRepo = MockStallControlRepository(mockOrderRepo);
  mockOrderRepo.isStallOpen = mockStallControlRepo.isOpenSync;
  mockOrderRepo.isAcceptingOrders = (stallId) =>
      sl<LocalStorageService>().isAcceptingOrders(stallId);
  sl.registerSingleton<StallControlRepository>(mockStallControlRepo);

  sl.registerSingleton<MenuRepository>(MockMenuRepository());
  sl.registerSingleton<InventoryRepository>(MockInventoryRepository());
  sl.registerSingleton<DashboardRepository>(MockDashboardRepository());

  // Realtime
  sl.registerSingleton<RealtimeService>(RealtimeService(mockOrderRepo));

  // Cubits (singletons so Home shell shares them across tabs)
  sl.registerSingleton<OrdersCubit>(OrdersCubit(
    sl<OrderRepository>(),
    sl<RealtimeService>(),
    sl<AudioService>(),
    sl<TtsService>(),
  ));
  sl.registerSingleton<MenuCubit>(MenuCubit(sl<MenuRepository>()));
  sl.registerSingleton<InventoryCubit>(
      InventoryCubit(sl<InventoryRepository>()));
  sl.registerSingleton<DashboardCubit>(
      DashboardCubit(sl<DashboardRepository>()));
  sl.registerSingleton<StallControlCubit>(
      StallControlCubit(sl<StallControlRepository>()));
}
