import '../models/stall_control.dart';

abstract class StallControlRepository {
  Future<StallControlState> getControl(String stallId);
  Future<StallControlState> pause(
      {required String stallId,
      required String staffId,
      required Duration duration});
  Future<StallControlState> closeForDay(
      {required String stallId, required String staffId});
  Future<EmergencyStopResult> emergencyStop(
      {required String stallId,
      required String staffId,
      required EmergencyStopReason reason,
      String? detail,
      required String idempotencyKey});
  Future<StallControlState> reopen(
      {required String stallId, required String staffId});
  Future<StallControlState> resolveExpiry(String stallId);
  List<StallControlAuditEntry> auditFor(String stallId);
}
