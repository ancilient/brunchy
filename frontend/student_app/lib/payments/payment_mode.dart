/// The line under "Pay securely with Razorpay" on the payment sheet. It depends on the checkout `payment` payload
/// from the server, so the student is only told "no real money" when that is actually true.
String paymentModeNote(Map<String, dynamic>? payment) {
  final gateway = payment?['gateway'] as String? ?? 'mock';
  if (gateway == 'mock') return 'Development payment: no real money moves.';
  final keyId = payment?['keyId'] as String? ?? '';
  if (keyId.startsWith('rzp_test_')) return 'UPI, cards and netbanking. Razorpay test mode: no real money moves.';
  return 'UPI, cards and netbanking.';
}
