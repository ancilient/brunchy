import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/errors/app_exception.dart';
import '../../core/utils/date_formatter.dart';
import '../models/cancel_reason.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/order_status.dart';
import '../repositories/order_repository.dart';
import 'vendor_api.dart';

/// Orders = the backend's bills for this vendor's stall (one bill per stall per payment).
/// Live updates arrive over Socket.IO: `bill.new` for a newly paid bill, `bill.updated` for any change.
class RemoteOrderRepository implements OrderRepository {
  RemoteOrderRepository(this._api);
  final VendorApi _api;

  /// Last known copy of each order, so handover can send the pickup code the server expects.
  final Map<String, Order> _known = {};
  final _events = StreamController<({String event, Order order})>.broadcast();
  io.Socket? _socket;

  // ---------------------------------------------------------------- mapping

  static OrderStatus _status(String s) => switch (s) {
        'new' => OrderStatus.placed,
        'accepted' || 'preparing' => OrderStatus.accepted,
        'ready' => OrderStatus.ready,
        'collected' => OrderStatus.collected,
        'expired' => OrderStatus.cancelled,
        _ => OrderStatus.refunded, // rejected, cancelled, refunded: the student gets the money back
      };

  Order _order(Map<String, dynamic> b) {
    DateTime? t(String key) => b[key] == null ? null : DateTime.parse(b[key] as String).toLocal();
    final code = (b['pickupCode'] as String?) ?? '';
    final order = Order(
      id: b['id'] as String,
      billNumber: (b['billNo'] as String?) ?? '#${b['id']}',
      counterCode: RegExp(r'^[1-9]\d{2}$').hasMatch(code) ? code : '100',
      studentFirstName: (b['studentFirstName'] as String?) ?? 'Student',
      stallId: b['stallId'] as String,
      items: (b['items'] as List)
          .cast<Map<String, dynamic>>()
          .map((i) => OrderItem(
                menuItemId: i['productId'] as String,
                name: i['name'] as String,
                price: (i['price'] as num).toDouble(),
                quantity: (i['quantity'] as num).toInt(),
              ))
          .toList(),
      totalAmount: (b['total'] as num).toDouble(),
      status: _status(b['status'] as String),
      placedAt: t('createdAt') ?? DateTime.now(),
      acceptedAt: t('acceptedAt'),
      readyAt: t('readyAt'),
      collectedAt: t('collectedAt'),
      isPaid: true,
      otpLockedUntil: (b['codeLocked'] as bool? ?? false) ? DateTime.now().add(const Duration(minutes: 5)) : null,
      isCodeUsed: b['status'] == 'collected',
    );
    _known[order.id] = order;
    return order;
  }

  Future<Order> _bill(Future<Map<String, dynamic>> call) async => _order((await call)['bill'] as Map<String, dynamic>);

  // ---------------------------------------------------------------- reads

  @override
  Future<List<Order>> getOrders({required String stallId, String? date, String? status, int page = 1, int limit = 50}) async {
    final query = <String, dynamic>{'status': _statusFilter(status)};
    if (date != null && date != DateFormatter.todayKey()) query['date'] = date;
    final r = await _api.get('/vendor/bills', query: query);
    final all = (r['bills'] as List).cast<Map<String, dynamic>>().map(_order).toList()
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    final start = ((page - 1) * limit).clamp(0, all.length);
    return all.sublist(start, (start + limit).clamp(start, all.length));
  }

  static String _statusFilter(String? s) => switch (s) {
        'placed' => 'new',
        'accepted' => 'accepted',
        'ready' => 'ready',
        'collected' => 'collected',
        'cancelled' || 'refunded' => 'closed',
        _ => 'all',
      };

  @override
  Stream<({String event, Order order})> watchOrders(String stallId) {
    if (_socket == null) _connect();
    return _events.stream;
  }

  void _connect() {
    final token = _api.accessToken;
    if (token == null) return;
    final socket = io.io(
      _api.origin,
      io.OptionBuilder().setTransports(['websocket']).setAuth({'token': token}).disableAutoConnect().enableReconnection().build(),
    );
    socket.on('bill.new', (data) {
      if (data is Map) _events.add((event: 'new_order', order: _order(Map<String, dynamic>.from(data))));
    });
    socket.on('bill.updated', (data) {
      if (data is! Map) return;
      final order = _order(Map<String, dynamic>.from(data));
      final cancelled = order.status == OrderStatus.refunded || order.status == OrderStatus.cancelled;
      _events.add((event: cancelled ? 'order_cancelled' : 'order_updated', order: order));
    });
    // Access tokens last 15 minutes: refresh and reconnect when the server refuses the old one.
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

  @override
  Future<Order?> findOrderByCounterCode({required String stallId, required String code}) async {
    try {
      return await _bill(_api.get('/vendor/bills/lookup', query: {'code': code.trim()}));
    } on AppException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 400) return null;
      rethrow;
    }
  }

  // ---------------------------------------------------------------- actions

  Future<Order> _setStatus(String orderId, Map<String, dynamic> body) => _bill(_api.patch('/vendor/bills/$orderId/status', body));

  @override
  Future<Order> acceptOrder(String orderId) => _setStatus(orderId, {'status': 'accepted'});

  @override
  Future<Order> rejectOrder(String orderId, {CancelReason? reason}) =>
      _setStatus(orderId, {'status': 'rejected', 'reason': reason?.apiValue ?? 'STALL_REJECTED'});

  @override
  Future<Order> cancelOrder({required String orderId, required CancelReason reason}) =>
      _setStatus(orderId, {'status': 'rejected', 'reason': reason.apiValue});

  @override
  Future<Order> markReady(String orderId) => _setStatus(orderId, {'status': 'ready'});

  @override
  Future<Order> unreadyOrder(String orderId) => _setStatus(orderId, {'status': 'preparing'});

  @override
  Future<Order> collectOrder({required String orderId, required String otp}) =>
      _bill(_api.post('/vendor/bills/$orderId/handover', {'code': otp.trim()}));

  @override
  Future<Order> handoverOrder({required String stallId, required String orderId}) async {
    final code = _known[orderId]?.counterCode;
    if (code == null) throw const AppException(message: 'Refresh the orders and try again.', code: 'ORDER_UNKNOWN');
    return collectOrder(orderId: orderId, otp: code);
  }
}
