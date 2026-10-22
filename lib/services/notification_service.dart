import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Registers this device's FCM token on the signed-in user's document
/// (users/{uid}.fcmTokens) so Cloud Functions can push order updates
/// and new-order alerts to their devices.
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Re-save whenever the token rotates (app restores, security events).
      _messaging.onTokenRefresh.listen(_saveToken);

      // Save / refresh the token whenever someone signs in.
      FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (user != null) {
          final token = await _messaging.getToken();
          if (token != null) await _saveToken(token);
        }
      });
    } catch (_) {
      // Notifications are a nice-to-have: never let them crash the app.
    }
  }

  Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
    } catch (_) {
      // Non-critical; retried on next token refresh / sign-in.
    }
  }
}
