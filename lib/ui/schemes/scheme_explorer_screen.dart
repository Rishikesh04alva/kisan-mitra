import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../providers/scheme_provider.dart';
import '../widgets/common.dart';

class SchemeExplorerScreen extends StatefulWidget {
  const SchemeExplorerScreen({super.key});

  @override
  State<SchemeExplorerScreen> createState() => _SchemeExplorerScreenState();
}

class _SchemeExplorerScreenState extends State<SchemeExplorerScreen> {
  bool _bootstrapped = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapped) {
      _bootstrapped = true;
      context.read<SchemeProvider>().init();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final sp = context.watch<SchemeProvider>();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (q) => context.read<SchemeProvider>().setQuery(q),
              decoration: InputDecoration(
                hintText: s.t('search_hint'),
                prefixIcon: const Icon(Icons.search_rounded, size: 28),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          context.read<SchemeProvider>().setQuery('');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: sp.categories
                  .map((c) => _chip(c, c == sp.category, isState: false))
                  .toList(),
            ),
          ),
          if (sp.states.length > 2)
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: sp.states
                    .map((st) => _chip(st, st == sp.state, isState: true))
                    .toList(),
              ),
            ),
          Expanded(
            child: !sp.loaded
                ? const Center(child: CircularProgressIndicator())
                : sp.items.isEmpty
                    ? EmptyState(emoji: '📭', text: s.t('no_results'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: sp.items.length,
                        itemBuilder: (ctx, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SchemeCard(scheme: sp.items[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, {required bool isState}) {
    final s = S.of(context);
    final text = label == 'ALL' ? s.t('cat_all') : label;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: NeoCard(
        onTap: selected
            ? null
            : () => isState
                ? context.read<SchemeProvider>().setStateFilter(label)
                : context.read<SchemeProvider>().setCategory(label),
        color: selected ? AppColors.ink : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.yellow : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _SchemeCard extends StatelessWidget {
  final Scheme scheme;

  const _SchemeCard({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = s.code;
    return NeoCard(
      onTap: () => showNeoSheet(context, (_) => _DetailSheet(scheme: scheme)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scheme.name(lang),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  scheme.benefit(lang),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          NeoBadge(text: scheme.category, color: AppColors.blue),
        ],
      ),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  final Scheme scheme;

  const _DetailSheet({required this.scheme});

  Future<void> _openUrl(BuildContext context) async {
    if (scheme.url.isEmpty) return;
    try {
      await launchUrl(
        Uri.parse(scheme.url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Future<void> _call(BuildContext context) async {
    if (scheme.phone.isEmpty) return;
    try {
      await launchUrl(Uri(scheme: 'tel', path: scheme.phone));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = s.code;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      builder: (ctx, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(scheme.name(lang), style: Theme.of(ctx).textTheme.displaySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                NeoBadge(text: scheme.category, color: AppColors.blue),
                if (scheme.state != 'ALL')
                  NeoBadge(text: scheme.state, color: AppColors.yellow),
              ],
            ),
            SectionHeader(text: s.t('benefits'), emoji: '🎁'),
            NeoCard(
              color: AppColors.green,
              child: Text(
                scheme.benefit(lang),
                style: Theme.of(ctx)
                    .textTheme
                    .bodyLarge!
                    .copyWith(color: Colors.white),
              ),
            ),
            SectionHeader(text: s.t('elig'), emoji: '✅'),
            ...scheme.eligibility.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: NeoCard(
                  color: Colors.white,
                  shadowColor: Colors.black26,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      Expanded(child: Text(e, style: Theme.of(ctx).textTheme.bodyLarge)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            NeoButton(
              label: s.t('apply'),
              emoji: '🌐',
              color: AppColors.yellow,
              onTap: () => _openUrl(ctx),
            ),
            const SizedBox(height: 12),
            NeoButton(
              label: s.t('call_helpline'),
              emoji: '📞',
              color: Colors.white,
              onTap: () => _call(ctx),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
