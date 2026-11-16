import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'razorpay_result.dart';

@JS('checkout')
external void _jsCheckout(JSString optionsJson);

@JS('_brunchyRazorpayResult')
external set _jsResultHandler(JSFunction handler);

Future<RazorpayCheckoutResult> openRazorpayCheckout(Map<String, dynamic> options) {
  final completer = Completer<RazorpayCheckoutResult>();

  _jsResultHandler = ((JSString responseJson) {
    if (completer.isCompleted) return;
    try {
      final map = jsonDecode(responseJson.toDart) as Map<String, dynamic>;
      completer.complete(RazorpayCheckoutResult.fromJson(map));
    } catch (e) {
      completer.complete(
        RazorpayCheckoutResult.failure(errorCode: 'PARSE_ERROR', errorDescription: '$e'),
      );
    }
  }).toJS;

  options.putIfAbsent('theme', () => {'color': '#E63E11'});
  _jsCheckout(jsonEncode(options).toJS);
  return completer.future;
}
