import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'razorpay_result.dart';

/// Android (and iOS) Razorpay Checkout through the official razorpay_flutter plugin.
/// Takes the same options map as the web bridge (web/payment.js) and returns the same result,
/// so AppState.completeRazorpayPayment works unchanged on every platform.
Future<RazorpayCheckoutResult> openRazorpayCheckout(Map<String, dynamic> options) {
  final completer = Completer<RazorpayCheckoutResult>();
  final razorpay = Razorpay();

  void finish(RazorpayCheckoutResult result) {
    if (completer.isCompleted) return;
    razorpay.clear();
    completer.complete(result);
  }

  razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
    final orderId = r.orderId;
    final paymentId = r.paymentId;
    final signature = r.signature;
    if (orderId == null || paymentId == null || signature == null) {
      finish(const RazorpayCheckoutResult.failure(
        errorCode: 'INCOMPLETE_RESPONSE',
        errorDescription: 'Razorpay did not return the payment details. If money was taken it will be refunded.',
      ));
      return;
    }
    finish(RazorpayCheckoutResult.success(orderId: orderId, paymentId: paymentId, signature: signature));
  });

  razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
    finish(RazorpayCheckoutResult.failure(
      // Same code the web bridge uses when the student closes the window, so the app treats it as "cancelled".
      errorCode: r.code == Razorpay.PAYMENT_CANCELLED ? 'MODAL_DISMISSED' : 'RAZORPAY_${r.code ?? 'ERROR'}',
      errorDescription: _friendlyMessage(r),
    ));
  });

  // Order-based payments do not support redirecting to an external wallet app; ask for UPI / card instead.
  razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
    finish(RazorpayCheckoutResult.failure(
      errorCode: 'EXTERNAL_WALLET',
      errorDescription: '${r.walletName ?? 'This wallet'} is not supported. Please pay with UPI or a card.',
    ));
  });

  final rzpOptions = Map<String, dynamic>.from(options)
    ..putIfAbsent('theme', () => {'color': '#E63E11'})
    ..putIfAbsent('retry', () => {'enabled': true, 'max_count': 2});

  try {
    razorpay.open(rzpOptions);
  } catch (e) {
    finish(RazorpayCheckoutResult.failure(errorCode: 'OPEN_FAILED', errorDescription: 'Could not open Razorpay: $e'));
  }
  return completer.future;
}

String _friendlyMessage(PaymentFailureResponse r) {
  switch (r.code) {
    case Razorpay.PAYMENT_CANCELLED:
      return 'Payment cancelled';
    case Razorpay.NETWORK_ERROR:
      return 'No internet connection. Please check your network and try again.';
    default:
      // Razorpay sends a JSON string for some errors; show it only if it is short plain text.
      final m = r.message;
      if (m != null && m.isNotEmpty && !m.trimLeft().startsWith('{') && m.length < 160) return m;
      return 'Payment failed. No money was taken; please try again.';
  }
}
