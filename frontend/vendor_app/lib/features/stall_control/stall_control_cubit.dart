// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/stall_control.dart';
import '../../data/repositories/stall_control_repository.dart';

sealed class StallControlViewState {
  const StallControlViewState();
}

class StallControlLoading extends StallControlViewState {
  const StallControlLoading();
}

class StallControlReady extends StallControlViewState {
  final StallControlState control;
  final EmergencyStopResult? lastStop;
  const StallControlReady(this.control, {this.lastStop});
}

class StallControlFailure extends StallControlViewState {
  final String message;
  const StallControlFailure(this.message);
}

class StallControlCubit extends Cubit<StallControlViewState> {
  final StallControlRepository _repository;
  Timer? _expiryTimer;
  String? _stallId;
  String? _staffId;
  StallControlCubit(this._repository) : super(const StallControlLoading());
  Future<void> load({required String stallId, required String staffId}) async {
    _stallId = stallId;
    _staffId = staffId;
    emit(const StallControlLoading());
    try {
      final c = await _repository.getControl(stallId);
      emit(StallControlReady(c));
      _schedule(c);
    } catch (_) {
      emit(const StallControlFailure('Could not load stall controls.'));
    }
  }

  String _requireStall() {
    if (_stallId == null || _staffId == null || _staffId!.isEmpty)
      throw StateError('A signed-in staff member and stall are required.');
    return _stallId!;
  }

  void _schedule(StallControlState c) {
    _expiryTimer?.cancel();
    if (c.pausedUntil != null) {
      final wait = c.pausedUntil!.difference(DateTime.now());
      _expiryTimer = Timer(wait.isNegative ? Duration.zero : wait, () async {
        final n = await _repository.resolveExpiry(c.stallId);
        emit(StallControlReady(n));
      });
    }
  }

  Future<void> pause(int minutes) async {
    try {
      final id = _requireStall();
      final n = await _repository.pause(
          stallId: id,
          staffId: _staffId!,
          duration: Duration(minutes: minutes));
      emit(StallControlReady(n));
      _schedule(n);
    } catch (e) {
      emit(StallControlFailure(e.toString()));
    }
  }

  Future<void> closeForDay() async {
    try {
      final id = _requireStall();
      final n = await _repository.closeForDay(stallId: id, staffId: _staffId!);
      emit(StallControlReady(n));
    } catch (e) {
      emit(StallControlFailure(e.toString()));
    }
  }

  Future<void> emergencyStop(EmergencyStopReason reason,
      {String? detail}) async {
    try {
      final id = _requireStall();
      if (reason == EmergencyStopReason.other &&
          (detail == null || detail.trim().isEmpty))
        throw StateError('Please enter a reason.');
      final key = 'emergency-${DateTime.now().microsecondsSinceEpoch}';
      final r = await _repository.emergencyStop(
          stallId: id,
          staffId: _staffId!,
          reason: reason,
          detail: detail?.trim(),
          idempotencyKey: key);
      emit(StallControlReady(r.control, lastStop: r));
    } catch (e) {
      emit(StallControlFailure(e.toString()));
    }
  }

  Future<void> reopen() async {
    try {
      final id = _requireStall();
      final n = await _repository.reopen(stallId: id, staffId: _staffId!);
      emit(StallControlReady(n));
    } catch (e) {
      emit(StallControlFailure(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _expiryTimer?.cancel();
    return super.close();
  }
}
