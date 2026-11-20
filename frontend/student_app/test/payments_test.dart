import 'package:brunchy/api/mappers.dart';
import 'package:brunchy/payments/payment_mode.dart';
import 'package:brunchy/payments/razorpay_result.dart';
import 'package:flutter_test/flutter_test.dart';

/// A bill as the backend sends it (GET /orders/:id → order.bills[]).
Map<String, dynamic> billJson({
  String status = 'new',
  double total = 80,
  double platformFee = 1.89,
  double refundedAmount = 0,
  String? cancelReason,
}) =>
    {
      'id': '17',
      'orderId': '14',
      'stallId': '1',
      'stallName': 'Burger Hub',
      'canteenId': '1',
      'billNo': 'BH-0004',
      'status': status,
      'pickupCode': '253',
      'subtotal': total,
      'tax': 0,
      'total': total,
      'platformFee': platformFee,
      'refundedAmount': refundedAmount,
      'cancelReason': cancelReason,
      'createdAt': '2026-11-20T06:51:00.000Z',
      'items': [
        {'id': '30', 'productId': '101', 'name': 'Cheese Burger', 'price': total, 'gstRate': 0, 'quantity': 1, 'status': 'active'},
      ],
    };

void main() {
  group('paymentModeNote', () {
    test('says "no real money" for the mock gateway', () {
      expect(paymentModeNote({'gateway': 'mock'}), contains('no real money'));
      expect(paymentModeNote(null), contains('no real money'));
    });

    test('says "test mode" only for Razorpay test keys', () {
      expect(paymentModeNote({'gateway': 'razorpay', 'keyId': 'rzp_test_abc'}), contains('test mode'));
    });

    test('never says "no real money" for live keys', () {
      final note = paymentModeNote({'gateway': 'razorpay', 'keyId': 'rzp_live_abc'});
      expect(note, isNot(contains('no real money')));
      expect(note, isNot(contains('test')));
    });
  });

  group('billFromApi', () {
    test('what the student paid = item total + platform fee share', () {
      final b = billFromApi(billJson());
      expect(b.total, 80);
      expect(b.platformFee, 1.89);
      expect(b.amountPaid, 81.89);
    });

    test('keeps the refund amount the server reports', () {
      final b = billFromApi(billJson(status: 'cancelled', total: 60, platformFee: 1.42, refundedAmount: 60, cancelReason: 'CANCELLED_BY_USER'));
      expect(b.status, 'refunded'); // a cancelled paid bill is shown as refunded
      expect(b.refundedAmount, 60);
      expect(b.amountPaid, 61.42);
    });

    test('older bills without the new fields still load', () {
      final j = billJson()..remove('platformFee')..remove('refundedAmount');
      final b = billFromApi(j);
      expect(b.platformFee, 0);
      expect(b.amountPaid, b.total);
    });
  });

  group('RazorpayCheckoutResult.fromJson', () {
    test('success carries the ids the backend verifies', () {
      final r = RazorpayCheckoutResult.fromJson({
        'isSuccessful': true,
        'orderId': 'order_1',
        'paymentId': 'pay_1',
        'signature': 'abc123',
      });
      expect(r.isSuccessful, isTrue);
      expect([r.orderId, r.paymentId, r.signature], ['order_1', 'pay_1', 'abc123']);
    });

    test('a closed checkout window is reported as MODAL_DISMISSED', () {
      final r = RazorpayCheckoutResult.fromJson({'isSuccessful': false, 'errorCode': 'MODAL_DISMISSED'});
      expect(r.isSuccessful, isFalse);
      expect(r.errorCode, 'MODAL_DISMISSED');
      expect(r.errorDescription, 'Payment failed');
    });
  });
}
