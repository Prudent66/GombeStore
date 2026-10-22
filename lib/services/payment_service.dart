import 'package:cloud_functions/cloud_functions.dart';

/// Paystack payments. The Flutter app never touches a secret key: it asks
/// our Cloud Function to initialize a Paystack transaction for an order,
/// opens the secure Paystack checkout page in the browser, and then asks
/// the function to verify the payment. The function owns the secret and
/// writes `paymentStatus: 'Paid'` on the order when verified.
class PaymentService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Requests a Paystack checkout link for [orderId].
  /// Returns the authorization URL to open in a browser.
  Future<String> startPayment(String orderId) async {
    final callable = _functions.httpsCallable(
      'createPaystackPayment',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final result = await callable.call({'orderId': orderId});
    return (result.data['authorization_url'] as String?) ??
        (throw Exception('Payment link missing'));
  }

  /// Asks the backend to check with Paystack whether [orderId] was paid.
  /// Returns true when the order is now marked Paid.
  Future<bool> verifyPayment(String orderId) async {
    final callable = _functions.httpsCallable(
      'verifyPaystackPayment',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final result = await callable.call({'orderId': orderId});
    return result.data['paid'] == true;
  }
}
