import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/db/app_database.dart';
import 'core/l10n.dart';
import 'core/theme.dart';
import 'data/models/models.dart';
import 'providers/assistant_provider.dart';
import 'providers/field_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/scheme_provider.dart';
import 'providers/scanner_provider.dart';
import 'providers/tracker_provider.dart';
import 'services/intent_engine.dart';
import 'services/tflite_service.dart';
import 'ui/home_shell.dart';

class KisanMitraApp extends StatelessWidget {
  final AppDatabase db;
  final TfliteService tflite;

  const KisanMitraApp({super.key, required this.db, required this.tflite});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()..load()),
        Provider<AppDatabase>.value(value: db),
        Provider<TfliteService>.value(value: tflite),
        Provider<IntentEngine>(
          create: (_) => IntentEngine()..load(),
        ),
        ChangeNotifierProvider(
          create: (c) => FieldProvider(c.read<AppDatabase>())..load(),
        ),
        ChangeNotifierProvider(
          create: (c) => TrackerProvider(c.read<AppDatabase>()),
        ),
        ChangeNotifierProvider(
          create: (c) => ScannerProvider(
            c.read<AppDatabase>(),
            c.read<TfliteService>(),
          )..init(),
        ),
        ChangeNotifierProvider(
          create: (c) => SchemeProvider(c.read<AppDatabase>())..init(),
        ),
        ChangeNotifierProvider(
          create: (c) => AssistantProvider(
            c.read<AppDatabase>(),
            c.read<IntentEngine>(),
          ),
        ),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, lp, _) => MaterialApp(
          title: 'Kisan Mitra',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          locale: Locale(lp.code),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomeShell(),
          builder: (ctx, child) => S(code: lp.code, child: child!),
        ),
      ),
    );
  }
}
