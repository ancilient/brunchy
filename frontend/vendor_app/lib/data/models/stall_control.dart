import 'package:equatable/equatable.dart';

enum StallOperatingMode { open, paused, closedForDay, emergencyStopped }

enum EmergencyStopReason { gasCut, powerFailure, shortage, other }

extension EmergencyStopReasonX on EmergencyStopReason {
  String get label => switch (this) {
        EmergencyStopReason.gasCut => 'Gas cut',
        EmergencyStopReason.powerFailure => 'Power failure',
        EmergencyStopReason.shortage => 'Shortage',
        EmergencyStopReason.other => 'Other',
      };
  String get apiValue => switch (this) {
        EmergencyStopReason.gasCut => 'GAS_CUT',
        EmergencyStopReason.powerFailure => 'POWER_FAILURE',
        EmergencyStopReason.shortage => 'SHORTAGE',
        EmergencyStopReason.other => 'OTHER',
      };
}

class StallControlState extends Equatable {
  final String stallId;
  final StallOperatingMode mode;
  final DateTime? pausedUntil;
  final DateTime? changedAt;
  final EmergencyStopReason? emergencyReason;
  final String? emergencyDetail;
  final bool pendingSync;

  const StallControlState(
      {required this.stallId,
      this.mode = StallOperatingMode.open,
      this.pausedUntil,
      this.changedAt,
      this.emergencyReason,
      this.emergencyDetail,
      this.pendingSync = false});
  bool get acceptsNewOrders => mode == StallOperatingMode.open;
  bool get canFinishPreparing => true;
  bool get isEmergencyStopped => mode == StallOperatingMode.emergencyStopped;
  StallControlState copyWith(
          {StallOperatingMode? mode,
          DateTime? pausedUntil,
          bool clearPause = false,
          DateTime? changedAt,
          EmergencyStopReason? emergencyReason,
          String? emergencyDetail,
          bool clearEmergency = false,
          bool? pendingSync}) =>
      StallControlState(
        stallId: stallId,
        mode: mode ?? this.mode,
        pausedUntil: clearPause ? null : (pausedUntil ?? this.pausedUntil),
        changedAt: changedAt ?? this.changedAt,
        emergencyReason:
            clearEmergency ? null : (emergencyReason ?? this.emergencyReason),
        emergencyDetail:
            clearEmergency ? null : (emergencyDetail ?? this.emergencyDetail),
        pendingSync: pendingSync ?? this.pendingSync,
      );
  @override
  List<Object?> get props => [
        stallId,
        mode,
        pausedUntil,
        changedAt,
        emergencyReason,
        emergencyDetail,
        pendingSync
      ];
}

class StallControlAuditEntry extends Equatable {
  final String action;
  final DateTime occurredAt;
  final String staffId;
  final StallOperatingMode previousMode;
  final StallOperatingMode nextMode;
  final String? reason;
  final int affectedOrderCount;
  const StallControlAuditEntry(
      {required this.action,
      required this.occurredAt,
      required this.staffId,
      required this.previousMode,
      required this.nextMode,
      this.reason,
      this.affectedOrderCount = 0});
  @override
  List<Object?> get props => [
        action,
        occurredAt,
        staffId,
        previousMode,
        nextMode,
        reason,
        affectedOrderCount
      ];
}

class EmergencyStopResult extends Equatable {
  final StallControlState control;
  final List<String> refundedOrderIds;
  final List<String> preparingOrderIds;
  const EmergencyStopResult(
      {required this.control,
      required this.refundedOrderIds,
      required this.preparingOrderIds});
  @override
  List<Object?> get props => [control, refundedOrderIds, preparingOrderIds];
}
