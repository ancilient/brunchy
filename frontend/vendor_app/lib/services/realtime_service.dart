import 'dart:async';
import '../data/models/order.dart';
import '../data/repositories/order_repository.dart';
import 'realtime_connection_state.dart';

/// Live order events for the current stall. The events come from the order repository:
/// Socket.IO from the backend (RemoteOrderRepository) or the in-memory demo (MockOrderRepository).
class RealtimeService {
  final OrderRepository _orders;
  final void Function()? _onDisconnect;

  RealtimeConnectionState _connectionState = RealtimeConnectionState.connected;
  final _connectionController = StreamController<RealtimeConnectionState>.broadcast();

  RealtimeService(this._orders, {void Function()? onDisconnect}) : _onDisconnect = onDisconnect;

  RealtimeConnectionState get connectionState => _connectionState;

  Stream<RealtimeConnectionState> get connectionStateStream => _connectionController.stream;

  Stream<({String event, Order order})> get orderStream => _orders.watchOrders(_stallId ?? '');

  String? _stallId;
  final List<Future<void> Function()> _offlineOperations = [];

  /// Executes immediately when connected, otherwise retains FIFO work until reconnect.
  Future<void> runWhenConnected(Future<void> Function() operation) async {
    if (_connectionState != RealtimeConnectionState.connected) {
      _offlineOperations.add(operation);
      return;
    }
    await operation();
  }

  Future<void> connect(String stallId) async {
    _stallId = stallId;
    _connectionState = RealtimeConnectionState.connected;
    _connectionController.add(_connectionState);
    while (_offlineOperations.isNotEmpty) {
      final operation = _offlineOperations.removeAt(0);
      await operation();
    }
  }

  Future<void> disconnect() async {
    _stallId = null;
    _onDisconnect?.call();
  }
}
