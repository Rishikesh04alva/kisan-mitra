import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/theme.dart';
import '../home_shell.dart';
import 'consent_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _consentAccepted = false;
  String? _checkedForUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }
        final user = snap.data;
        if (user == null) {
          _checkedForUid = null;
          return const LoginScreen();
        }
        if (_checkedForUid != user.uid) {
          _checkedForUid = user.uid;
          _consentAccepted = false;
          context.read<AppDatabase>().getSetting('consent_v1').then((v) {
            if (mounted && v == '1') setState(() => _consentAccepted = true);
          });
        }
        if (!_consentAccepted) {
          return ConsentScreen(
            db: context.read<AppDatabase>(),
            onAccepted: () => setState(() => _consentAccepted = true),
          );
        }
        return const HomeShell();
      },
    );
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
