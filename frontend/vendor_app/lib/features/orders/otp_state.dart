import 'package:equatable/equatable.dart';
import '../../data/models/order.dart';

abstract class OtpState extends Equatable {
  const OtpState();
  @override List<Object?> get props => [];
}

class OtpIdle            extends OtpState { const OtpIdle(); }
class OtpSubmitting      extends OtpState { const OtpSubmitting(); }
class OtpAlreadyCollected extends OtpState { const OtpAlreadyCollected(); }

class OtpSuccess extends OtpState {
  final Order order;
  const OtpSuccess(this.order);
  @override List<Object?> get props => [order.id];
}

class OtpWrongAttempt extends OtpState {
  final int attemptsLeft;
  const OtpWrongAttempt({required this.attemptsLeft});
  @override List<Object?> get props => [attemptsLeft];
}

class OtpLocked extends OtpState {
  final DateTime lockedUntil;
  const OtpLocked({required this.lockedUntil});
  @override List<Object?> get props => [lockedUntil];
}

class OtpError extends OtpState {
  final String message;
  const OtpError(this.message);
  @override List<Object?> get props => [message];
}

