/// The app's Terms & Conditions, shown as a checklist before sign-in. Keep the whole text 50-100 words
/// (test/terms_test.dart checks it). Change the wording here; bump [termsVersion] when the meaning changes.
const termsVersion = '2026-11-23';

const termsIntro = 'Brunchy lets students pre-order food from campus canteen stalls. By using the app you agree to:';

const termsPoints = [
  'Pay the total shown: food price plus platform and convenience fees. Your first two orders have no fees.',
  'Collect your order with your 3-digit pickup code during canteen hours.',
  'Refunds go to your original payment method when a stall rejects or cannot prepare an order. Fees are not refunded if you cancel.',
  'Use one account per person and do not misuse offers.',
];

const termsOutro = 'Brunchy may update these terms.';

/// All words of the terms (intro, points and closing line).
int termsWordCount() => [termsIntro, ...termsPoints, termsOutro].join(' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
