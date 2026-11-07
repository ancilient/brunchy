// ignore_for_file: curly_braces_in_flow_control_structures

import '../../data/models/stall_control.dart';
import '../../data/repositories/stall_control_repository.dart';
import 'mock_order_repository.dart';

class MockStallControlRepository implements StallControlRepository {
  final MockOrderRepository _orders;
  final Map<String, StallControlState> _controls = {};
  final Map<String, List<StallControlAuditEntry>> _audit = {};
  final Set<String> _handledKeys = {};
  MockStallControlRepository(this._orders);
  StallControlState _state(String id) =>
      _controls[id] ?? StallControlState(stallId: id);
  bool isOpenSync(String stallId) {
    final state = _state(stallId);
    if (state.mode == StallOperatingMode.paused &&
        state.pausedUntil != null &&
        !DateTime.now().isBefore(state.pausedUntil!)) return true;
    return state.acceptsNewOrders;
  }

  void _log(String id, String staffId, String action, StallOperatingMode from,
          StallOperatingMode to, {String? reason, int count = 0}) =>
      (_audit[id] ??= []).add(StallControlAuditEntry(
          action: action,
          occurredAt: DateTime.now(),
          staffId: staffId,
          previousMode: from,
          nextMode: to,
          reason: reason,
          affectedOrderCount: count));
  @override
  Future<StallControlState> getControl(String stallId) async =>
      resolveExpiry(stallId);
  @override
  Future<StallControlState> resolveExpiry(String stallId) async {
    final s = _state(stallId);
    if (s.mode == StallOperatingMode.paused &&
        s.pausedUntil != null &&
        !DateTime.now().isBefore(s.pausedUntil!)) {
      final n = s.copyWith(
          mode: StallOperatingMode.open,
          clearPause: true,
          changedAt: DateTime.now());
      _controls[stallId] = n;
      _log(stallId, 'system', 'PAUSE_EXPIRED', s.mode, n.mode);
    }
    return _state(stallId);
  }

  @override
  Future<StallControlState> pause(
      {required String stallId,
      required String staffId,
      required Duration duration}) async {
    final s = _state(stallId);
    final n = s.copyWith(
        mode: StallOperatingMode.paused,
        pausedUntil: DateTime.now().add(duration),
        clearEmergency: true,
        changedAt: DateTime.now());
    _controls[stallId] = n;
    _log(stallId, staffId, 'PAUSE', s.mode, n.mode,
        reason: '${duration.inMinutes} min');
    return n;
  }

  @override
  Future<StallControlState> closeForDay(
      {required String stallId, required String staffId}) async {
    final s = _state(stallId);
    final n = s.copyWith(
        mode: StallOperatingMode.closedForDay,
        clearPause: true,
        clearEmergency: true,
        changedAt: DateTime.now());
    _controls[stallId] = n;
    _log(stallId, staffId, 'CLOSE_FOR_DAY', s.mode, n.mode);
    return n;
  }

  @override
  Future<EmergencyStopResult> emergencyStop(
      {required String stallId,
      required String staffId,
      required EmergencyStopReason reason,
      String? detail,
      required String idempotencyKey}) async {
    final s = _state(stallId);
    if (!_handledKeys.add(idempotencyKey))
      return EmergencyStopResult(
          control: s,
          refundedOrderIds: const [],
          preparingOrderIds: _orders.preparingIds(stallId));
    final refunded = _orders.emergencyStopAndRefundPlaced(stallId);
    final n = s.copyWith(
        mode: StallOperatingMode.emergencyStopped,
        clearPause: true,
        emergencyReason: reason,
        emergencyDetail: detail,
        changedAt: DateTime.now());
    _controls[stallId] = n;
    _log(stallId, staffId, 'EMERGENCY_STOP', s.mode, n.mode,
        reason: reason.apiValue, count: refunded.length);
    return EmergencyStopResult(
        control: n,
        refundedOrderIds: refunded,
        preparingOrderIds: _orders.preparingIds(stallId));
  }

  @override
  Future<StallControlState> reopen(
      {required String stallId, required String staffId}) async {
    final s = _state(stallId);
    final n = s.copyWith(
        mode: StallOperatingMode.open,
        clearPause: true,
        clearEmergency: true,
        changedAt: DateTime.now());
    _controls[stallId] = n;
    _log(stallId, staffId, 'REOPEN', s.mode, n.mode);
    return n;
  }

  @override
  List<StallControlAuditEntry> auditFor(String stallId) =>
      List.unmodifiable(_audit[stallId] ?? const []);
}
