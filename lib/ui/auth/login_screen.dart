import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService.instance;
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _otp = TextEditingController();

  bool _otpStep = false;
  bool _busy = false;
  String? _error;
  int _resendIn = 0;
  Timer? _ticker;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendIn = 60;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn = _resendIn - 1);
      if (_resendIn <= 0) t.cancel();
    });
  }

  String get _e164 => '+91${_phone.text.trim()}';

  Future<void> _sendOtp() async {
    final p = _phone.text.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(p)) {
      setState(() => _error = 'auth_error');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await _auth.sendOtp(
      phoneE164: _e164,
      onCodeSent: () {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _otpStep = true;
        });
        _startResendTimer();
      },
      onAutoVerified: () {},
      onError: (msg) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'auth_error';
        });
      },
    );
    if (mounted && !_otpStep) setState(() => _busy = false);
  }

  Future<void> _verifyOtp() async {
    final code = _otp.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'wrong_code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await _auth.verifyOtp(code);
      if (!mounted) return;
      if (!ok) setState(() => _error = 'wrong_code');
    } catch (_) {
      if (mounted) setState(() => _error = 'wrong_code');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('🌾', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 56)),
                const SizedBox(height: 10),
                Text(
                  s.t(_otpStep ? 'otp_title' : 'login_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  s.t(_otpStep ? 'otp_sub' : 'login_sub'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 22),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: NeoCard(
                      color: AppColors.red,
                      padding: const EdgeInsets.all(10),
                      child: Row(children: [
                        const Text('⚠️', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(s.t(_error!),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                      ]),
                    ),
                  ),
                NeoCard(
                  color: AppColors.surface,
                  child: _otpStep ? _otpBody(s) : _phoneBody(),
                ),
                const SizedBox(height: 16),
                NeoButton(
                  label: s.t(_otpStep ? 'verify_otp' : 'send_otp'),
                  emoji: _otpStep ? '✅' : '📩',
                  color: _busy ? AppColors.surface : AppColors.green,
                  onTap: _busy ? null : () => _otpStep ? _verifyOtp() : _sendOtp(),
                ),
                if (_otpStep) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _resendIn > 0 || _busy ? null : _sendOtp,
                    child: Text(
                      _resendIn > 0
                          ? '${s.t('resend_otp')} (${_resendIn}s)'
                          : s.t('resend_otp'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color:
                              _resendIn > 0 ? Colors.black38 : AppColors.blue),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.yellow,
              border: Border.all(color: AppColors.ink, width: kBorderWidth),
              borderRadius: BorderRadius.circular(kRadius),
            ),
            child: const Text('+91',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                counterText: '',
                hintText: '9876543210',
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.ink, width: kBorderWidth),
                  borderRadius: BorderRadius.circular(kRadius),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.ink, width: kBorderWidth + 1),
                  borderRadius: BorderRadius.circular(kRadius),
                ),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _otpBody(S s) {
    return TextField(
      controller: _otp,
      keyboardType: TextInputType.number,
      maxLength: 6,
      textAlign: TextAlign.center,
      autofocus: true,
      style: const TextStyle(
          fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 12),
      decoration: InputDecoration(
        counterText: '',
        hintText: '• • • • • •',
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.ink, width: kBorderWidth),
          borderRadius: BorderRadius.circular(kRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.ink, width: kBorderWidth + 1),
          borderRadius: BorderRadius.circular(kRadius),
        ),
      ),
    );
  }
}
