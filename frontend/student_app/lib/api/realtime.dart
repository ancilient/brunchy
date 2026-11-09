// Live bill updates from the backend over Socket.IO (no pull-to-refresh needed).
// Events: 'bill.updated' (one bill changed) and 'order.updated' (paid / expired / refund).
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_client.dart';

class Realtime {
  Realtime(this._api);
  final ApiClient _api;
  io.Socket? _socket;

  void Function(Map<String, dynamic> bill)? onBill;
  void Function(Map<String, dynamic> order)? onOrder;
  void Function()? onReconnect;

  void connect() {
    disconnect();
    final token = _api.accessToken;
    if (token == null) return;
    final socket = io.io(
      _api.origin,
      io.OptionBuilder().setTransports(['websocket']).setAuth({'token': token}).disableAutoConnect().enableReconnection().build(),
    );
    socket.on('bill.updated', (data) {
      if (data is Map) onBill?.call(Map<String, dynamic>.from(data));
    });
    socket.on('order.updated', (data) {
      if (data is Map) onOrder?.call(Map<String, dynamic>.from(data));
    });
    // Catch up on anything missed while disconnected.
    socket.onConnect((_) => onReconnect?.call());
    // The access token lasts 15 minutes: when the server refuses it, refresh and reconnect with the new one.
    socket.onConnectError((err) async {
      if ('$err'.contains('UNAUTHORIZED') && await _api.refreshSession()) {
        socket.auth = {'token': _api.accessToken};
        socket.connect();
      }
    });
    socket.connect();
    _socket = socket;
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
