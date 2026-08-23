import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/db/app_database.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';
class ConsentScreen extends StatefulWidget {
  final AppDatabase db;
  final VoidCallback onAccepted;

  const ConsentScreen({
    super.key,
    required this.db,
    required this.onAccepted,
  });

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreed = false;
  bool _busy = false;

  Future<void> _accept() async {
    if (!_agreed || _busy) return;
    setState(() => _busy = true);
    try {
      await Permission.camera.request();
      await Permission.microphone.request();
      await Permission.photos.request();
    } catch (_) {}
    try {
      await widget.db.saveSetting('consent_v1', '1');
    } catch (_) {}
    widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('📜',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text(
                    s.t('consent_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 18),
                  NeoCard(
                    color: AppColors.yellow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.t('terms_head'),
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(s.t('terms_body'),
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35)),
                      ],
                    ),
                  ),
                  SectionHeader(text: s.t('perms_head'), emoji: '🔐'),
                  _permTile(context, '📷', s.t('perm_camera'), AppColors.greenLight),
                  _permTile(context, '🎤', s.t('perm_mic'), AppColors.blue),
                  _permTile(context, '🖼️', s.t('perm_photos'), AppColors.surface),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _agreed = !_agreed),
                    behavior: HitTestBehavior.opaque,
                    child: Row(children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: _agreed ? AppColors.green : Colors.white,
                          border: Border.all(color: AppColors.ink, width: kBorderWidth),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: _agreed
                            ? const Icon(Icons.check, size: 18, color: AppColors.ink)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(s.t('agree_check'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  NeoButton(
                    label: s.t('accept_btn'),
                    emoji: '✅',
                    color: _agreed && !_busy ? AppColors.green : AppColors.surface,
                    onTap: _agreed && !_busy ? _accept : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permTile(BuildContext context, String emoji, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: NeoCard(
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}
