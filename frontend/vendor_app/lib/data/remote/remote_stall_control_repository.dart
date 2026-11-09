import '../models/stall_control.dart';
import '../repositories/stall_control_repository.dart';
import 'vendor_api.dart';

/// Pause / Close for today / Emergency stop / Reopen on the server. The server keeps the authoritative
/// audit log; this class keeps a local copy of today's actions for the panel's history list.
class RemoteStallControlRepository implements StallControlRepository {
  RemoteStallControlRepository(this._api);
  final VendorApi _api;
  final Map<String, List<StallControlAuditEntry>> _audit = {};
  final Map<String, ({EmergencyStopReason reason, String? detail})> _emergency = {};

  StallControlState _state(String stallId, Map<String, dynamic> s) {
    final status = s['status'] as String;
    final emergency = _emergency[stallId];
    final mode = switch (status) {
      'paused' => StallOperatingMode.paused,
      'closed' => emergency != null ? StallOperatingMode.emergencyStopped : StallOperatingMode.closedForDay,
      _ => StallOperatingMode.open,
    };
    if (mode != StallOperatingMode.emergencyStopped) _emergency.remove(stallId);
    return StallControlState(
      stallId: stallId,
      mode: mode,
      pausedUntil: s['pausedUntil'] == null ? null : DateTime.parse(s['pausedUntil'] as String).toLocal(),
      changedAt: DateTime.now(),
      emergencyReason: mode == StallOperatingMode.emergencyStopped ? emergency?.reason : null,
      emergencyDetail: mode == StallOperatingMode.emergencyStopped ? emergency?.detail : null,
    );
  }

  Future<StallControlState> _action(String stallId, String staffId, String label, Map<String, dynamic> body, {String? reason}) async {
    final before = await getControl(stallId);
    final r = await _api.post('/vendor/stall/status', body);
    final after = _state(stallId, r['stall'] as Map<String, dynamic>);
    (_audit[stallId] ??= []).add(StallControlAuditEntry(
      action: label,
      occurredAt: DateTime.now(),
      staffId: staffId,
      previousMode: before.mode,
      nextMode: after.mode,
      reason: reason,
      affectedOrderCount: (r['refundedBillIds'] as List?)?.length ?? 0,
    ));
    return after;
  }

  @override
  Future<StallControlState> getControl(String stallId) async =>
      _state(stallId, (await _api.get('/vendor/stall'))['stall'] as Map<String, dynamic>);

  /// The server reopens a paused stall by itself when the pause ends; reading the state is enough.
  @override
  Future<StallControlState> resolveExpiry(String stallId) => getControl(stallId);

  @override
  Future<StallControlState> pause({required String stallId, required String staffId, required Duration duration}) {
    const allowed = [10, 15, 30];
    final minutes = allowed.firstWhere((m) => m >= duration.inMinutes, orElse: () => 30);
    return _action(stallId, staffId, 'PAUSE', {'action': 'pause', 'minutes': minutes}, reason: '$minutes min');
  }

  @override
  Future<StallControlState> closeForDay({required String stallId, required String staffId}) =>
      _action(stallId, staffId, 'CLOSE_FOR_DAY', {'action': 'close'});

  @override
  Future<StallControlState> reopen({required String stallId, required String staffId}) =>
      _action(stallId, staffId, 'REOPEN', {'action': 'resume'});

  @override
  Future<EmergencyStopResult> emergencyStop({
    required String stallId,
    required String staffId,
    required EmergencyStopReason reason,
    String? detail,
    required String idempotencyKey,
  }) async {
    final before = await getControl(stallId);
    final r = await _api.post('/vendor/stall/status', {
      'action': 'emergency',
      'reason': reason.apiValue,
      if (detail != null && detail.isNotEmpty) 'detail': detail,
    });
    _emergency[stallId] = (reason: reason, detail: detail);
    final control = _state(stallId, r['stall'] as Map<String, dynamic>);
    final refunded = (r['refundedBillIds'] as List).cast<String>();
    (_audit[stallId] ??= []).add(StallControlAuditEntry(
      action: 'EMERGENCY_STOP',
      occurredAt: DateTime.now(),
      staffId: staffId,
      previousMode: before.mode,
      nextMode: control.mode,
      reason: reason.apiValue,
      affectedOrderCount: refunded.length,
    ));
    return EmergencyStopResult(
      control: control,
      refundedOrderIds: refunded,
      preparingOrderIds: (r['preparingBillIds'] as List).cast<String>(),
    );
  }

  @override
  List<StallControlAuditEntry> auditFor(String stallId) => List.unmodifiable(_audit[stallId] ?? const []);
}
