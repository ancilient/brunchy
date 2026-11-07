import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/order_repository.dart';
import '../../core/errors/app_exception.dart';
import 'otp_state.dart';

class OtpCubit extends Cubit<OtpState> {
  final OrderRepository _orderRepository;

  OtpCubit(this._orderRepository) : super(const OtpIdle());

  Future<void> submitOtp({required String orderId, required String otp}) async {
    emit(const OtpSubmitting());
    try {
      // [API-010] POST /orders/{orderId}/collect
      final updated = await _orderRepository.collectOrder(orderId: orderId, otp: otp);
      emit(OtpSuccess(updated));
    } on AppException catch (e) {
      switch (e.code) {
        case 'OTP_WRONG':
          final attemptsLeft = int.tryParse(e.message.split(' ').last) ?? 0;
          emit(OtpWrongAttempt(attemptsLeft: attemptsLeft));
        case 'OTP_LOCKED':
          final lockedUntil = DateTime.tryParse(e.message.split('until ').last) ?? DateTime.now().add(const Duration(seconds: 30));
          emit(OtpLocked(lockedUntil: lockedUntil));
        case 'ORDER_ALREADY_COLLECTED':
          emit(const OtpAlreadyCollected());
        case 'ORDER_NOT_READY':
          emit(const OtpError('Mark food ready first'));
        default:
          emit(OtpError(e.message));
      }
    } catch (_) {
      emit(const OtpError('Something went wrong. Please try again.'));
    }
  }

  void reset() => emit(const OtpIdle());
}

