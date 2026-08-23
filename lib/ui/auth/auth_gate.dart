import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/theme.dart';
import '../home_shell.dart';
import 'consent_screen.dart';

/// No account required: goes straight to the one-time consent screen,
/// then straight into the app. Login/OTP removed.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _consentAccepted = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    context.read<AppDatabase>().getSetting('consent_v1').then((v) {
      if (!mounted) return;
      setState(() {
        _consentAccepted = v == '1';
        _checked = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const _Splash();
    if (!_consentAccepted) {
      return ConsentScreen(
        db: context.read<AppDatabase>(),
        onAccepted: () => setState(() => _consentAccepted = true),
      );
    }
    return const HomeShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('🌾', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            CircularProgressIndicator(color: AppColors.green),
          ],
        ),
      ),
    );
  }
}
