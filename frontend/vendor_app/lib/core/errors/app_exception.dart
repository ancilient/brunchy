class AppException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  const AppException({required this.message, this.code, this.statusCode});

  factory AppException.network() =>
      const AppException(message: 'No connection. Check your internet.', code: 'NETWORK_ERROR');

  factory AppException.server(int statusCode, String? code) =>
      AppException(message: 'Server error ($statusCode)', code: code, statusCode: statusCode);

  factory AppException.orderAlreadyCancelled() =>
      const AppException(message: 'Order was auto-cancelled', code: 'ORDER_ALREADY_CANCELLED');

  factory AppException.otpWrong(int attemptsLeft) =>
      AppException(message: 'Wrong OTP. $attemptsLeft attempts left', code: 'OTP_WRONG');

  factory AppException.otpLocked(DateTime lockedUntil) =>
      AppException(message: 'OTP locked until ${lockedUntil.toIso8601String()}', code: 'OTP_LOCKED');

  factory AppException.alreadyCollected() =>
      const AppException(message: 'This order has already been collected', code: 'ORDER_ALREADY_COLLECTED');

  factory AppException.stallAlreadyClaimed(String claimedBy) =>
      AppException(message: 'Stall already claimed by $claimedBy', code: 'STALL_ALREADY_CLAIMED');

  factory AppException.undoWindowExpired() =>
      const AppException(message: 'Undo window expired', code: 'UNDO_WINDOW_EXPIRED');

  @override
  String toString() => 'AppException($code): $message';
}

