import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../providers/locale_provider.dart';
import '../providers/scheme_provider.dart';
import '../providers/tracker_provider.dart';
import '../services/sync_service.dart';
import '../services/weather_service.dart';
import 'assistant/assistant_screen.dart';
import 'mapper/field_mapper_screen.dart';
import 'scanner/scanner_screen.dart';
import 'schemes/scheme_explorer_screen.dart';
import 'tracker/tracker_screen.dart';
import 'widgets/common.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  DateTime _lastSyncAttempt = DateTime.fromMillisecondsSinceEpoch(0);
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  @override
  void initState() {
    super.initState();
    _connSub = Connectivity().onConnectivityChanged.listen(_onConnectivity);
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (!online) return;
    final now = DateTime.now();
    if (now.difference(_lastSyncAttempt) < const Duration(seconds: 60)) return;
    _lastSyncAttempt = now;
    SyncService.runOnce();
    if (!mounted) return;
    context.read<TrackerProvider>().refreshWeatherOnline(WeatherService());
    context.read<SchemeProvider>().init();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  void _goTo(int i) => setState(() => _index = i);

  Future<void> _openLanguageSheet() async {
    final s = S.of(context);
    showNeoSheet(context, (sheetCtx) {
      final options = [
        ('en', 'English'),
        ('hi', 'हिन्दी'),
        ('mr', 'मराठी'),
        ('kn', 'ಕನ್ನಡ'),
        ('ta', 'தமிழ்'),
        ('te', 'తెలుగు'),
        ('ml', 'മലയാളം'),
      ];
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('language'),
                  style: Theme.of(sheetCtx).textTheme.titleLarge),
              const SizedBox(height: 14),
              ...options.map((o) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NeoButton(
                      label: o.$2,
                      emoji: o.$1 == sheetCtx.read<LocaleProvider>().code
                          ? '✅'
                          : null,
                      onTap: () async {
                        await sheetCtx.read<LocaleProvider>().set(o.$1);
                        if (Navigator.of(sheetCtx).canPop()) {
                          Navigator.of(sheetCtx).pop();
                        }
                      },
                    ),
                  )),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final pages = [
      TrackerScreen(onOpenMapper: () => _goTo(1)),
      FieldMapperScreen(onOpenScanner: () => _goTo(2)),
      ScannerScreen(),
      SchemeExplorerScreen(),
    ];
    final navItems = [
      (Icons.home_rounded, s.t('nav_home')),
      (Icons.grid_view_rounded, s.t('nav_fields')),
      (Icons.camera_alt_rounded, s.t('nav_scan')),
      (Icons.account_balance, s.t('nav_schemes')),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.t('app_title'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              s.t('tagline'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.greenDark,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: NeoIconSquare(
              icon: Icons.translate_rounded,
              size: 46,
              onTap: _openLanguageSheet,
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(kBorderWidth),
          child: Divider(height: kBorderWidth, thickness: kBorderWidth, color: AppColors.ink),
        ),
      ),
      body: Stack(
        children: [
          IndexedStack(index: _index, children: pages),
          Positioned(
            right: 16,
            bottom: 16 + 68,
            child: _AssistantBubble(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.ink, width: kBorderWidth),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: List.generate(navItems.length, (i) {
              final selected = i == _index;
              return Expanded(
                child: Material(
                  color: selected ? AppColors.yellow : Colors.transparent,
                  child: InkWell(
                    onTap: () => _goTo(i),
                    child: SizedBox(
                      height: 64,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(navItems[i].$1,
                              size: 26,
                              color: AppColors.ink),
                          const SizedBox(height: 3),
                          Text(
                            navItems[i].$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  selected ? FontWeight.w900 : FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AssistantScreen()),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: AppColors.yellow,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.ink, width: kBorderWidth),
          boxShadow: const [
            BoxShadow(color: AppColors.ink, offset: Offset(4, 4), blurRadius: 0),
          ],
        ),
        child: const Center(
          child: Text('💬', style: TextStyle(fontSize: 28)),
        ),
      ),
    );
  }
}
