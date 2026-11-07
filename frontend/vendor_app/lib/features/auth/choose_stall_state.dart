import 'package:equatable/equatable.dart';
import '../../data/models/stall.dart';

abstract class ChooseStallState extends Equatable {
  const ChooseStallState();
  @override List<Object?> get props => [];
}

class ChooseStallInitial  extends ChooseStallState { const ChooseStallInitial(); }
class ChooseStallLoading  extends ChooseStallState { const ChooseStallLoading(); }
class ChooseStallEmpty    extends ChooseStallState { const ChooseStallEmpty(); }
class StallSelected       extends ChooseStallState {
  final Stall stall;
  const StallSelected(this.stall);
  @override List<Object?> get props => [stall.id];
}

class ChooseStallLoaded extends ChooseStallState {
  final List<Stall> stalls;
  const ChooseStallLoaded(this.stalls);
  @override List<Object?> get props => [stalls];
}

class ChooseStallError extends ChooseStallState {
  final String message;
  const ChooseStallError(this.message);
  @override List<Object?> get props => [message];
}

class StallClaimConflict extends ChooseStallState {
  final String claimedBy;
  final String stallId;
  const StallClaimConflict({required this.claimedBy, required this.stallId});
  @override List<Object?> get props => [claimedBy, stallId];
}

