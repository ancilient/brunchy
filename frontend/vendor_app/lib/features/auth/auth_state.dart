import 'package:equatable/equatable.dart';
import '../../data/models/vendor.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState { const AuthInitial(); }
class AuthLoading extends AuthState { const AuthLoading(); }

/// The login code was sent. [devCode] is the code itself when the backend runs in development.
class AuthOtpSent extends AuthState {
  final String phone;
  final String? devCode;
  const AuthOtpSent(this.phone, this.devCode);
  @override List<Object?> get props => [phone, devCode];
}

class AuthSuccess extends AuthState {
  final Vendor vendor;
  const AuthSuccess(this.vendor);
  @override List<Object?> get props => [vendor.id];
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override List<Object?> get props => [message];
}

