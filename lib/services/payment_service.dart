import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Paystack payments via our free-tier backend (Cloudflare Worker).
///
/// The app never leaves Nigeria-grade secrets in the APK: the Worker's URL
/// and app key are read live from Firestore (settings/backend), and the
/// Paystack secret key is stored as a Cloudflare secret on the server.
///
/// Configure: Firestore -> settings/backend -> { url: "https://<your-worker>.workers.dev", key: "<APP_API_KEY>" }
class PaymentService {
  static String? _url;
  static String? _key;

  Future<({String url, String key})> _config() async {
    if (_url != null && _url!.isNotEmpty) {
      return (url: _url!, key: _key ?? '');
    }
    final doc =
        await FirebaseFirestore.instance.collection('settings').doc('backend').get();
    _url = ((doc.data()?['url']) ?? '') as String;
    _key = ((doc.data()?['key']) ?? '') as String;
    if (_url!.isEmpty) {
      throw 'Payment service is not configured yet — please pay cash on delivery.';
    }
    return (url: _url!, key: _key ?? '');
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final cfg = await _config();
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    final res = await http
        .post(
          Uri.parse('${cfg.url}$path'),
          headers: {
            'x-app-key': cfg.key,
            if (idToken != null) 'authorization': 'Bearer $idToken',
            'content-type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    final data = (res.body.isNotEmpty ? jsonDecode(res.body) : {}) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw (data['error'] ?? 'Payment request failed (${res.statusCode})') as Object;
    }
    return data;
  }

  /// Requests a Paystack checkout link for [orderId].
  /// Returns the authorization URL to open in a browser.
  Future<String> startPayment(String orderId) async {
    final data = await _post('/pay/initialize', {'orderId': orderId});
    final url = data['authorization_url'] as String?;
    if (url == null || url.isEmpty) {
      throw 'Could not start payment. Try again or pay cash on delivery.';
    }
    return url;
  }

  /// Asks the backend to check with Paystack whether [orderId] was paid.
  /// Returns true when the order is now marked Paid.
  Future<bool> verifyPayment(String orderId) async {
    final data = await _post('/pay/verify', {'orderId': orderId});
    return data['paid'] == true;
  }
}
