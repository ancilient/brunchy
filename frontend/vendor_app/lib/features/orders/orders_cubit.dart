import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/order.dart';
import '../../data/models/order_filter.dart';
import '../../data/models/order_status.dart';
import '../../data/models/cancel_reason.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/stall_control_repository.dart';
import '../../services/realtime_service.dart';
import '../../services/audio_service.dart';
import '../../services/tts_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/realtime_connection_state.dart';
import '../../injection_container.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/date_formatter.dart';
import 'orders_state.dart';

class OrdersCubit extends Cubit<OrdersState> {
  final OrderRepository _orderRepository;
  final RealtimeService _realtimeService;
  final AudioService _audioService;
  final TtsService _ttsService;
  final LocalStorageService _localStorageService;
  /// Server-side stall state (production). Null in the offline demo, where the switch stays on the phone.
  final StallControlRepository? _stallControl;

  StreamSubscription? _orderSub;
  StreamSubscription? _connectionSub;
  Timer? _burstDebounceTimer;
  int _accumulatedBurstOrders = 0;
  String? _currentStallId;
  int _maxCapacity = 15;
  bool _isOverrideActive = false;
  bool _isFiringBatch = false;
  Timer? _stallStateTimer;
  bool? _serverAccepting;
  bool _canteenOpen = true;
  String? _canteenOpeningTime;
  String? _canteenClosingTime;

  bool get acceptingOrders => _stallControl != null
      ? (_serverAccepting ?? true)
      : (_currentStallId == null || _localStorageService.isAcceptingOrders(_currentStallId!));

  String? get currentStallId => _currentStallId;
  int get maxCapacity => _maxCapacity;
  bool get isOverrideActive => _isOverrideActive;

  OrdersCubit(
    this._orderRepository,
    this._realtimeService,
    this._audioService,
    this._ttsService, [
    LocalStorageService? localStorageService,
    StallControlRepository? stallControl,
  ])  : _localStorageService = localStorageService ?? sl<LocalStorageService>(),
        _stallControl = stallControl,
        super(const OrdersInitial()) {
    _maxCapacity = _localStorageService.getMaxCapacity();
  }

  Future<void> setMaxCapacity(int capacity) async {
    _maxCapacity = capacity.clamp(0, 50);
    await _localStorageService.setMaxCapacity(_maxCapacity);
    final base = _currentLoaded;
    if (base != null) {
      final updated = base.copyWith(maxCapacity: _maxCapacity);
      emit(updated);
      unawaited(_autoPromoteQueueIfNeeded(updated));
    }
  }

  Future<void> setAcceptingOrders(bool value) async {
    final stallId = _currentStallId ??
        _localStorageService.getStallId(DateFormatter.todayKey()) ??
        'stall_001';
    _currentStallId = stallId;
    final control = _stallControl;
    if (control != null) {
      // The server decides who can order: OFF closes the stall to new orders (orders already placed continue),
      // ON reopens it. Students can still only order while the canteen is inside its hours.
      try {
        if (value) {
          await control.reopen(stallId: stallId, staffId: 'orders-toggle');
        } else {
          await control.closeForDay(stallId: stallId, staffId: 'orders-toggle');
        }
      } catch (_) {
        // Keep showing what the server says; refreshStallState below re-reads it.
      }
      await refreshStallState();
      return;
    }
    await _localStorageService.setAcceptingOrders(stallId, value);
    if (!value) {
      await _localStorageService.queueOfflineAction(
          '{"action":"set_accepting_orders","stallId":"$stallId","accepting":false}');
    }
    final base = _currentLoaded;
    if (base != null) emit(base.copyWith(acceptingOrders: value));
  }

  /// Reads the stall's real state and the canteen hours from the server and updates the screen.
  Future<void> refreshStallState() async {
    final control = _stallControl;
    final stallId = _currentStallId;
    if (control == null || stallId == null) return;
    try {
      final st = await control.getControl(stallId);
      _serverAccepting = st.acceptsNewOrders;
      _canteenOpen = st.canteenTakingOrders;
      _canteenOpeningTime = st.canteenOpeningTime;
      _canteenClosingTime = st.canteenClosingTime;
    } catch (_) {
      return; // offline: keep the last known state
    }
    final base = _currentLoaded;
    if (base != null) {
      emit(base.copyWith(
        acceptingOrders: acceptingOrders,
        canteenOpen: _canteenOpen,
        canteenOpeningTime: _canteenOpeningTime,
        canteenClosingTime: _canteenClosingTime,
      ));
    }
  }

  void toggleOverloadOverride() {
    _isOverrideActive = !_isOverrideActive;
    final base = _currentLoaded;
    if (base != null) {
      emit(base.copyWith(isOverrideActive: _isOverrideActive));
    }
  }

  Future<void> loadOrders(String stallId) async {
    _currentStallId = stallId;
    emit(const OrdersLoading());
    try {
      // [API-005] GET /stalls/{stallId}/orders
      final orders = await _orderRepository.getOrders(
        stallId: stallId,
        date: DateFormatter.todayKey(),
      );
      _emitLoaded(orders, OrderFilter.newOrders);
      _subscribeRealtime(stallId);
      unawaited(refreshStallState());
      _stallStateTimer?.cancel();
      if (_stallControl != null) {
        _stallStateTimer = Timer.periodic(const Duration(minutes: 1), (_) => refreshStallState());
      }
    } on AppException catch (e) {
      emit(OrdersError(e.message));
    } catch (_) {
      emit(const OrdersError('Failed to load orders.'));
    }
  }

  void _subscribeRealtime(String stallId) {
    _orderSub?.cancel();
    _connectionSub?.cancel();

    // [API-006] WS /ws/stalls/{stallId}/orders
    _connectionSub = _realtimeService.connectionStateStream.listen((connState) {
      onConnectionStateChanged(connState);
    });

    // Set the stall before deriving the production websocket stream.
    unawaited(_realtimeService.connect(stallId));
    _orderSub = _realtimeService.orderStream.listen((event) {
      onRealtimeEvent(event.order, event.event);
    });
  }

  Future<void> acceptOrder(String orderId) async {
    final base = _currentLoaded;
    if (base == null) return;
    emit(OrderActionInProgress(orderId: orderId, base: base));
    try {
      // [API-007] PATCH /orders/{orderId}/accept
      final updated = await _orderRepository.acceptOrder(orderId);
      _updateOrderInState(updated, base);
    } on AppException catch (e) {
      if (e.code == 'ORDER_ALREADY_CANCELLED') {
        _removeOrderFromState(orderId, base);
        emit(
            OrderActionError(orderId: orderId, message: e.message, base: base));
      } else {
        emit(
            OrderActionError(orderId: orderId, message: e.message, base: base));
      }
    } catch (_) {
      emit(OrderActionError(
          orderId: orderId,
          message: 'Could not accept — tap to retry',
          base: base));
    }
  }

  Future<String?> rejectOrder(String orderId, {CancelReason? reason}) async {
    final base = _currentLoaded;
    if (base == null) return 'Orders are unavailable.';
    emit(OrderActionInProgress(orderId: orderId, base: base));
    try {
      // [API-008] PATCH /orders/{orderId}/reject
      final updated =
          await _orderRepository.rejectOrder(orderId, reason: reason);
      _updateOrderInState(updated, base);
      return null;
    } on AppException catch (e) {
      emit(OrderActionError(orderId: orderId, message: e.message, base: base));
      return e.message;
    } catch (_) {
      const message = 'Could not reject order.';
      emit(OrderActionError(orderId: orderId, message: message, base: base));
      return message;
    }
  }

  Future<void> cancelAndRefund(String orderId, CancelReason reason) async {
    final base = _currentLoaded;
    if (base == null) return;
    emit(OrderActionInProgress(orderId: orderId, base: base));
    try {
      // TODO(BACKEND-API): API-020 POST /orders/{orderId}/cancel-refund
      final updated =
          await _orderRepository.cancelOrder(orderId: orderId, reason: reason);
      _updateOrderInState(updated, base);
      await _autoPromoteQueueIfNeeded(_currentLoaded);
    } on AppException catch (e) {
      emit(OrderActionError(orderId: orderId, message: e.message, base: base));
    } catch (_) {
      emit(OrderActionError(
          orderId: orderId,
          message: 'Could not cancel and refund order.',
          base: base));
    }
  }

  Future<void> markReady(String orderId) async {
    final base = _currentLoaded;
    if (base == null) return;
    emit(OrderActionInProgress(orderId: orderId, base: base));
    try {
      // [API-009] PATCH /orders/{orderId}/ready
      final updated = await _orderRepository.markReady(orderId);
      _updateOrderInState(updated, base);

      // Capacity gate auto-promotion: promote oldest queued order into Preparing
      await _autoPromoteQueueIfNeeded(_currentLoaded);
    } on AppException catch (e) {
      emit(OrderActionError(orderId: orderId, message: e.message, base: base));
    } catch (_) {
      emit(OrderActionError(
          orderId: orderId, message: 'Could not mark ready.', base: base));
    }
  }

  Future<void> undoReady(String orderId) async {
    final base = _currentLoaded;
    if (base == null) return;
    try {
      // [API-021] PATCH /orders/{orderId}/unready
      final updated = await _orderRepository.unreadyOrder(orderId);
      _updateOrderInState(updated, base);
    } on AppException catch (e) {
      if (e.code == 'UNDO_WINDOW_EXPIRED') {
        emit(OrderActionError(
            orderId: orderId, message: 'Undo window expired', base: base));
      }
    } catch (_) {}
  }

  void changeFilter(OrderFilter filter) {
    final base = _currentLoaded;
    if (base == null) return;
    emit(base.copyWith(activeFilter: filter));
  }

  Future<void> markCollected(String orderId) async {
    final base = _currentLoaded;
    if (base == null) return;
    final order = base.allOrders
        .firstWhere((o) => o.id == orderId, orElse: () => base.allOrders.first);
    final updated = order.copyWith(
      status: OrderStatus.collected,
      collectedAt: DateTime.now(),
      isCodeUsed: true,
    );
    _updateOrderInState(updated, base);
    await _autoPromoteQueueIfNeeded(_currentLoaded);
  }

  /// Fire a batch of queued orders into Preparing respecting capacity limit
  Future<void> fireBatch(List<String> orderIds) async {
    final base = _currentLoaded;
    if (base == null || orderIds.isEmpty || _isFiringBatch) return;
    _isFiringBatch = true;

    final availableSlots = _maxCapacity - base.preparingCount;
    if (availableSlots <= 0) {
      _isFiringBatch = false;
      emit(OrderActionError(
          orderId: '',
          message:
              'Capacity full (${base.preparingCount}/$_maxCapacity). Mark orders Ready or raise the limit.',
          base: base));
      return;
    }

    final toPromote = orderIds.take(availableSlots).toList();
    var started = 0;
    for (final orderId in toPromote) {
      try {
        final updated = await _orderRepository.acceptOrder(orderId);
        final current = _currentLoaded;
        if (current != null) _updateOrderInState(updated, current);
        started++;
      } catch (_) {}
    }
    _isFiringBatch = false;
    final current = _currentLoaded;
    if (current != null)
      emit(OrderActionError(
          orderId: '',
          message: '$started ${started == 1 ? 'order' : 'orders'} started',
          base: current));
  }

  /// Mark all orders in a batch as Ready
  Future<void> readyBatch(List<String> orderIds) async {
    final base = _currentLoaded;
    if (base == null || orderIds.isEmpty) return;

    var ready = 0;
    for (final orderId in orderIds) {
      try {
        final updated = await _orderRepository.markReady(orderId);
        final current = _currentLoaded;
        if (current != null) _updateOrderInState(updated, current);
        ready++;
      } catch (_) {}
    }

    await _autoPromoteQueueIfNeeded(_currentLoaded);
    final current = _currentLoaded;
    if (current != null)
      emit(OrderActionError(
          orderId: '',
          message: '$ready ${ready == 1 ? 'order' : 'orders'} ready',
          base: current));
  }

  void onRealtimeEvent(Order updatedOrder, String event) {
    final base = _currentLoaded;
    if (base == null) return;

    if (event == 'new_order') {
      final allOrders = [updatedOrder, ...base.allOrders];
      _emitLoadedFromAll(allOrders, base.activeFilter, base.connectionState);
      unawaited(_autoPromoteQueueIfNeeded(_currentLoaded));

      // Debounce voice & chime for rush bursts
      _accumulatedBurstOrders++;
      _burstDebounceTimer?.cancel();
      _burstDebounceTimer = Timer(const Duration(milliseconds: 400), () {
        _audioService.playNewOrder();
        _ttsService.announceNewOrders(_accumulatedBurstOrders);
        _accumulatedBurstOrders = 0;
      });
    } else {
      _updateOrderInState(updatedOrder, base);
    }
  }

  void onConnectionStateChanged(RealtimeConnectionState connState) {
    final base = _currentLoaded;
    if (base == null) return;
    emit(base.copyWith(connectionState: connState));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _autoPromoteQueueIfNeeded(OrdersLoaded? base) async {
    if (base == null || _maxCapacity <= 0) return;
    final available = _maxCapacity - base.preparingCount;
    if (available <= 0 || base.newOrders.isEmpty) return;

    // FIFO: promote oldest placed queued order
    final oldestQueued = List<Order>.from(base.newOrders)
      ..sort((a, b) => a.placedAt.compareTo(b.placedAt));
    final toPromote = oldestQueued.take(available).toList();

    for (final order in toPromote) {
      try {
        final promoted = await _orderRepository.acceptOrder(order.id);
        final current = _currentLoaded;
        if (current != null) _updateOrderInState(promoted, current);
      } catch (_) {
        return;
      }
    }
  }

  OrdersLoaded? get _currentLoaded {
    final s = state;
    if (s is OrdersLoaded) return s;
    if (s is OrderActionInProgress) return s.base;
    if (s is OrderActionError) return s.base;
    return null;
  }

  void _updateOrderInState(Order updated, OrdersLoaded base) {
    final allOrders =
        base.allOrders.map((o) => o.id == updated.id ? updated : o).toList();
    if (!allOrders.any((o) => o.id == updated.id)) {
      allOrders.insert(0, updated);
    }
    _emitLoadedFromAll(allOrders, base.activeFilter, base.connectionState);
  }

  void _removeOrderFromState(String orderId, OrdersLoaded base) {
    final allOrders = base.allOrders.where((o) => o.id != orderId).toList();
    _emitLoadedFromAll(allOrders, base.activeFilter, base.connectionState);
  }

  void _emitLoaded(List<Order> orders, OrderFilter filter) {
    _emitLoadedFromAll(orders, filter, RealtimeConnectionState.connected);
  }

  void _emitLoadedFromAll(
      List<Order> all, OrderFilter filter, RealtimeConnectionState connState) {
    final sorted = List<Order>.from(all)
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    emit(OrdersLoaded(
      newOrders: sorted.where((o) => o.status == OrderStatus.placed).toList(),
      preparingOrders:
          sorted.where((o) => o.status == OrderStatus.accepted).toList(),
      readyOrders: sorted.where((o) => o.status == OrderStatus.ready).toList(),
      allOrders: sorted,
      activeFilter: filter,
      connectionState: connState,
      maxCapacity: _maxCapacity,
      isOverrideActive: _isOverrideActive,
      acceptingOrders: acceptingOrders,
      canteenOpen: _canteenOpen,
      canteenOpeningTime: _canteenOpeningTime,
      canteenClosingTime: _canteenClosingTime,
    ));
  }

  @override
  Future<void> close() {
    _burstDebounceTimer?.cancel();
    _stallStateTimer?.cancel();
    _orderSub?.cancel();
    _connectionSub?.cancel();
    _realtimeService.disconnect();
    return super.close();
  }
}
