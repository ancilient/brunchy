// Picks the Razorpay Checkout implementation for the platform:
// Android/iOS -> razorpay_flutter plugin, web -> Checkout.js bridge (web/payment.js), anything else -> unsupported.
export 'razorpay_checkout_stub.dart'
    if (dart.library.io) 'razorpay_checkout_mobile.dart'
    if (dart.library.html) 'razorpay_checkout_web.dart';
