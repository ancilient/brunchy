class RazorpayCheckoutResult {
  const RazorpayCheckoutResult.success({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  })  : isSuccessful = true,
        errorCode = null,
        errorDescription = null;

  const RazorpayCheckoutResult.failure({
    required this.errorCode,
    required this.errorDescription,
  })  : isSuccessful = false,
        orderId = null,
        paymentId = null,
        signature = null;

  factory RazorpayCheckoutResult.fromJson(Map<String, dynamic> j) {
    if (j['isSuccessful'] == true) {
      return RazorpayCheckoutResult.success(
        orderId: j['orderId'] as String,
        paymentId: j['paymentId'] as String,
        signature: j['signature'] as String,
      );
    }
    return RazorpayCheckoutResult.failure(
      errorCode: (j['errorCode'] as String?) ?? 'FAILED',
      errorDescription: (j['errorDescription'] as String?) ?? 'Payment failed',
    );
  }

  final bool isSuccessful;
  final String? orderId;
  final String? paymentId;
  final String? signature;
  final String? errorCode;
  final String? errorDescription;
}
