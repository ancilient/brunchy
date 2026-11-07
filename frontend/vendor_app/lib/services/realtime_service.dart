import 'dart:async';
import '../data/models/order.dart';
import '../data/mock/mock_order_repository.dart';
import 'realtime_connection_state.dart';

class RealtimeService {
  final MockOrderRepository _mockRepo;

  RealtimeConnectionState _connectionState = RealtimeConnectionState.connected;
  final _connectionController = StreamController<RealtimeConnectionState>.broadcast();

  RealtimeService(this._mockRepo);

  RealtimeConnectionState get connectionState => _connectionState;

  Stream<RealtimeConnectionState> get connectionStateStream => _connectionController.stream;

  Stream<({String event, Order order})> get orderStream => _mockRepo.watchOrders(_stallId ?? '');

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
    // In production: open WebSocket, start exponential backoff reconnect loop
    // [API-006] WS /ws/stalls/{stallId}/orders
  }

  Future<void> disconnect() async {
    _stallId = null;
    _mockRepo.stopWatching();
    // In production: close WebSocket, cancel reconnect timer
  }
}

