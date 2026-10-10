import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 10));
      return null;
    } on TimeoutException {
      return 'Connection timed out. Check your internet.';
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> registerCustomer({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    try {
      UserCredential result = await _auth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 10));

      await _firestore.collection('users').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'email': email,
        'fullName': fullName,
        'phone': phone,
        'role': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 5));

      return null;
    } on TimeoutException {
      return 'Account created but profile sync timed out. Try logging in.';
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> registerVendor({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String storeName,
  }) async {
    try {
      UserCredential result = await _auth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 10));

      await _firestore.collection('users').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'email': email,
        'fullName': fullName,
        'phone': phone,
        'role': 'vendor',
        'storeName': storeName,
        'isVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 5));

      return null;
    } on TimeoutException {
      return 'Account created but profile sync timed out. Try logging in.';
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}