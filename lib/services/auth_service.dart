import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  bool available = false;

  final FirebaseAuth _fb = FirebaseAuth.instance;
  String? _verificationId;
  int? _resendToken;

  void activate() => available = true;

  Stream<User?> get authState => _fb.authStateChanges();
  String? get currentPhone => _fb.currentUser?.phoneNumber;

  Future<void> sendOtp({
    required String phoneE164,
    required VoidCallback onCodeSent,
    required void Function(String message) onError,
    required VoidCallback onAutoVerified,
  }) async {
    await _fb.verifyPhoneNumber(
      phoneNumber: phoneE164,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      verificationCompleted: (cred) async {
        try {
          await _fb.signInWithCredential(cred);
          onAutoVerified();
        } catch (_) {
          onError('auto');
        }
      },
      verificationFailed: (e) {
        onError(e.code);
      },
      codeSent: (id, token) {
        _verificationId = id;
        _resendToken = token;
        onCodeSent();
      },
      codeAutoRetrievalTimeout: (id) {
        _verificationId = id;
      },
    );
  }

  Future<bool> verifyOtp(String code) async {
    final id = _verificationId;
    if (id == null) return false;
    final cred = PhoneAuthProvider.credential(
        verificationId: id, smsCode: code.trim());
    await _fb.signInWithCredential(cred);
    return true;
  }

  Future<void> signOut() => _fb.signOut();
}
