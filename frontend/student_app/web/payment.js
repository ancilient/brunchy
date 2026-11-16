// Razorpay Checkout.js bridge for Flutter web (test + live).
// Dart calls checkout(optionsJson); JS calls back via window._brunchyRazorpayResult(json).
function checkout(optionsStr) {
  var options = JSON.parse(optionsStr);
  var isProcessing = true;

  options.modal = options.modal || {};
  options.modal.escape = false;
  options.modal.ondismiss = function () {
    if (!isProcessing) return;
    window._brunchyRazorpayResult(
      JSON.stringify({
        isSuccessful: false,
        errorCode: 'MODAL_DISMISSED',
        errorDescription: 'Payment cancelled',
      }),
    );
  };

  options.handler = function (response) {
    isProcessing = false;
    window._brunchyRazorpayResult(
      JSON.stringify({
        isSuccessful: true,
        orderId: response.razorpay_order_id,
        paymentId: response.razorpay_payment_id,
        signature: response.razorpay_signature,
      }),
    );
  };

  var rzp = new Razorpay(options);
  rzp.on('payment.failed', function (response) {
    isProcessing = false;
    window._brunchyRazorpayResult(
      JSON.stringify({
        isSuccessful: false,
        errorCode: (response.error && response.error.code) || 'FAILED',
        errorDescription: (response.error && response.error.description) || 'Payment failed',
      }),
    );
  });
  rzp.open();
}
