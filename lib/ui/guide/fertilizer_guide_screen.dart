import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';

class FertilizerGuideScreen extends StatelessWidget {
  const FertilizerGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: Text(
          s.t('fg_title'),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(kBorderWidth),
          child: Divider(height: kBorderWidth, thickness: kBorderWidth, color: AppColors.ink),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          NeoCard(
            color: AppColors.yellow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🧪', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 6),
                Text(s.t('fg_sub'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(s.t('fg_basics'), style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          _FertCard(
            emoji: '🌿',
            name: 'Urea (46-0-0)',
            useKey: 'fg_urea_use',
            stepsKey: 'fg_urea_steps',
            color: AppColors.blue,
          ),
          _FertCard(
            emoji: '🌱',
            name: 'DAP (18-46-0)',
            useKey: 'fg_dap_use',
            stepsKey: 'fg_dap_steps',
            color: AppColors.surface,
          ),
          _FertCard(
            emoji: '🪨',
            name: 'MOP / Potash (0-0-60)',
            useKey: 'fg_mop_use',
            stepsKey: 'fg_mop_steps',
            color: AppColors.greenLight,
          ),
          const SizedBox(height: 14),
          NeoCard(
            color: AppColors.red,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.t('fg_safety'),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FertCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String useKey;
  final String stepsKey;
  final Color color;

  const _FertCard({
    required this.emoji,
    required this.name,
    required this.useKey,
    required this.stepsKey,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: NeoCard(
        color: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 10),
                Text(name, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const Divider(height: 16, thickness: 2, color: AppColors.ink),
            Text(
              s.t(useKey),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(s.t(stepsKey), style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
