import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/order_repository.dart';
import 'data/repositories/menu_repository.dart';
import 'data/repositories/inventory_repository.dart';
import 'data/repositories/dashboard_repository.dart';
import 'data/repositories/stall_control_repository.dart';
import 'data/mock/mock_auth_repository.dart';
import 'data/mock/mock_order_repository.dart';
import 'data/mock/mock_menu_repository.dart';
import 'data/mock/mock_inventory_repository.dart';
import 'data/mock/mock_dashboard_repository.dart';
import 'data/mock/mock_stall_control_repository.dart';
import 'data/remote/vendor_api.dart';
import 'data/remote/remote_auth_repository.dart';
import 'data/remote/remote_order_repository.dart';
import 'data/remote/remote_menu_repository.dart';
import 'data/remote/remote_stall_control_repository.dart';
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

/// The app talks to the Brunchy backend by default.
/// `flutter run --dart-define=USE_MOCK=true` runs the old offline demo with in-memory data instead.
const bool kUseMock = bool.fromEnvironment('USE_MOCK');

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

  if (kUseMock) {
    _registerMockRepositories(prefs);
  } else {
    _registerRemoteRepositories(prefs);
  }

  // Dashboard figures: still demo data until the backend has a reports endpoint.
  sl.registerSingleton<DashboardRepository>(MockDashboardRepository());

  // Cubits (singletons so Home shell shares them across tabs)
  sl.registerSingleton<OrdersCubit>(OrdersCubit(
    sl<OrderRepository>(),
    sl<RealtimeService>(),
    sl<AudioService>(),
    sl<TtsService>(),
  ));
  sl.registerSingleton<MenuCubit>(MenuCubit(sl<MenuRepository>()));
  sl.registerSingleton<InventoryCubit>(InventoryCubit(sl<InventoryRepository>()));
  sl.registerSingleton<DashboardCubit>(DashboardCubit(sl<DashboardRepository>()));
  sl.registerSingleton<StallControlCubit>(StallControlCubit(sl<StallControlRepository>()));
}

void _registerRemoteRepositories(SharedPreferences prefs) {
  final api = VendorApi(prefs);
  sl.registerSingleton<VendorApi>(api);
  sl.registerSingleton<AuthRepository>(RemoteAuthRepository(api, prefs));
  final orders = RemoteOrderRepository(api);
  sl.registerSingleton<OrderRepository>(orders);
  sl.registerSingleton<StallControlRepository>(RemoteStallControlRepository(api));
  sl.registerSingleton<MenuRepository>(RemoteMenuRepository(api));
  sl.registerSingleton<InventoryRepository>(RemoteInventoryRepository(api));
  sl.registerSingleton<RealtimeService>(RealtimeService(orders, onDisconnect: orders.disconnect));
}

void _registerMockRepositories(SharedPreferences prefs) {
  sl.registerSingleton<AuthRepository>(MockAuthRepository(prefs));
  final mockOrderRepo = MockOrderRepository();
  sl.registerSingleton<OrderRepository>(mockOrderRepo);
  sl.registerSingleton<MockOrderRepository>(mockOrderRepo);
  final mockStallControlRepo = MockStallControlRepository(mockOrderRepo);
  mockOrderRepo.isStallOpen = mockStallControlRepo.isOpenSync;
  mockOrderRepo.isAcceptingOrders = (stallId) => sl<LocalStorageService>().isAcceptingOrders(stallId);
  sl.registerSingleton<StallControlRepository>(mockStallControlRepo);
  sl.registerSingleton<MenuRepository>(MockMenuRepository());
  sl.registerSingleton<InventoryRepository>(MockInventoryRepository());
  sl.registerSingleton<RealtimeService>(RealtimeService(mockOrderRepo, onDisconnect: mockOrderRepo.stopWatching));
}
