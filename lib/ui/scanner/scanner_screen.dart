import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../providers/scanner_provider.dart';
import '../../services/nutrition_service.dart';
import '../../services/scan_prediction.dart';
import '../../services/crop_catalog.dart';
import '../widgets/common.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _cropCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  String? _selectedCropPrefix;
  String? _selectedCropDisplay;
  bool _prefsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefsLoaded) return;
    _prefsLoaded = true;
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    final prefix = sp.getString('scan_crop_prefix');
    final age = sp.getString('scan_age_days');
    if (!mounted) return;
    final s = S.of(context);
    if (prefix != null && prefix.isNotEmpty) {
      final opt = kCropCatalog
          .firstWhere((c) => c.prefix == prefix, orElse: () => kCropCatalog.first);
      setState(() {
        _selectedCropPrefix = opt.prefix;
        _selectedCropDisplay = opt.names[s.code] ?? opt.names['en'];
        _cropCtrl.text = _selectedCropDisplay!;
      });
    }
    if (age != null) _ageCtrl.text = age;
  }

  @override
  void dispose() {
    _cropCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final s = S.of(context);
    try {
      final xfile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 80,
      );
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      if (!mounted) return;

      final cropOpt = _selectedCropPrefix != null
          ? kCropCatalog.firstWhere(
              (c) => c.prefix == _selectedCropPrefix,
              orElse: () => kCropCatalog.first,
            )
          : matchCrop(_cropCtrl.text);
      final prefix = cropOpt?.prefix;
      final display =
          cropOpt?.names[s.code] ?? cropOpt?.names['en'];
      final age = int.tryParse(_ageCtrl.text.trim());

      await context.read<ScannerProvider>().analyze(
            xfile.path,
            bytes,
            cropPrefix: prefix,
            cropDisplay: display,
            ageDays: age,
          );

      final sp = await SharedPreferences.getInstance();
      sp.setString('scan_crop_prefix', prefix ?? '');
      sp.setString('scan_age_days', _ageCtrl.text.trim());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('err_generic'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scanner = context.watch<ScannerProvider>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          NeoCard(
            color: AppColors.yellow,
            child: Row(
              children: [
                const Text('🔍', style: TextStyle(fontSize: 34)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.t('scan_title'),
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(s.t('scan_hint'),
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          NeoCard(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🌱', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Text(s.t('ctx_title'),
                          style:
                              Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Autocomplete<CropOption>(
                    initialValue: _selectedCropDisplay != null
                        ? TextEditingValue(text: _selectedCropDisplay!)
                        : TextEditingValue.empty,
                    optionsBuilder: (v) {
                      final q = v.text.trim().toLowerCase();
                      if (q.isEmpty) return kCropCatalog;
                      final matches = kCropCatalog.where((c) {
                        for (final n in [
                          c.names['en']!,
                          ...c.names.values,
                          ...c.aliases,
                          c.prefix.toLowerCase()
                        ]) {
                          final nLow = n.toLowerCase();
                          if (nLow.contains(q) || q.contains(nLow))
                            return true;
                        }
                        return false;
                      });
                      return matches.isEmpty ? kCropCatalog : matches;
                    },
                    displayStringForOption: (o) =>
                        o.names[s.code] ?? o.names['en']!,
                    onSelected: (o) {
                      final name =
                          o.names[s.code] ?? o.names['en']!;
                      setState(() {
                        _selectedCropPrefix = o.prefix;
                        _selectedCropDisplay = name;
                        _cropCtrl.text = name;
                      });
                    },
                    fieldViewBuilder:
                        (ctx, ctrl, focusNode, onSubmitted) {
                      return TextField(
                        controller: ctrl,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: s.t('ctx_crop_hint'),
                          isDense: true,
                        ),
                        onSubmitted: (_) => onSubmitted(),
                      );
                    },
                    optionsViewBuilder: (ctx, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxHeight: 180),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (ctx, i) {
                                final o = options.elementAt(i);
                                final name =
                                    o.names[s.code] ?? o.names['en']!;
                                return ListTile(
                                  dense: true,
                                  leading: Text(o.emoji),
                                  title: Text(name),
                                  onTap: () => onSelected(o),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: s.t('ctx_age_hint'),
                      suffixText: s.t('ctx_days'),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: NeoButton(
                  label: s.t('take_photo'),
                  emoji: '📷',
                  color: AppColors.green,
                  onTap: scanner.state == ScanState.analyzing
                      ? null
                      : () => _pick(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeoButton(
                  label: s.t('gallery'),
                  emoji: '🖼️',
                  color: Colors.white,
                  onTap: scanner.state == ScanState.analyzing
                      ? null
                      : () => _pick(ImageSource.gallery),
                ),
              ),
            ],
          ),
          if (scanner.state == ScanState.analyzing) ...[
            const SizedBox(height: 20),
            NeoCard(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 16),
                    Text(s.t('analyzing'),
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            ),
          ],
          if (scanner.state == ScanState.done && scanner.lastResult != null)
            _ResultCard(
              record: scanner.lastResult!,
              demo: scanner.lastWasDemo,
              prediction: scanner.lastPrediction,
              kb: scanner.kb,
              cropDisplay: scanner.lastCropDisplay,
              ageDays: scanner.lastAgeDays,
              cropPrefix: scanner.lastCropPrefix,
            ),
          if (scanner.state == ScanState.error)
            NeoCard(
              color: AppColors.red,
              child: Text(s.t(scanner.errorKey),
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
          SectionHeader(text: s.t('history'), emoji: '🗂️'),
          if (scanner.history.isEmpty)
            NeoCard(
              color: Colors.white,
              child: Center(child: Text(s.t('no_history'))),
            )
          else
            ...scanner.history.map((rec) => _HistoryRow(record: rec)),
        ],
      ),
    );
  }
}

String _prettyLabel(String raw) {
  final parts = raw.split('___');
  final cropPart = parts.isNotEmpty ? parts.first.replaceAll('_', ' ') : '';
  final diseasePart = parts.length > 1 ? parts.sublist(1).join(' ').replaceAll('_', ' ') : '';
  if (diseasePart.isEmpty) return cropPart;
  return '$diseasePart • $cropPart';
}

class _ResultCard extends StatelessWidget {
  final ScanRecord record;
  final bool demo;
  final ScanPrediction? prediction;
  final Map<String, DiseaseInfo> kb;
  final String? cropDisplay;
  final int? ageDays;
  final String? cropPrefix;

  const _ResultCard({
    required this.record,
    required this.demo,
    this.prediction,
    this.kb = const {},
    this.cropDisplay,
    this.ageDays,
    this.cropPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = s.code;
    final healthy = record.healthy;
    final uncertain = prediction?.uncertain ?? false;
    final blurry = prediction?.blurry ?? false;
    final info = kb[record.label];
    final Color bg = healthy
        ? AppColors.green
        : uncertain
            ? AppColors.yellow
            : AppColors.red;
    final onBg = healthy || !uncertain ? Colors.white : AppColors.ink;

    return NeoCard(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(healthy ? '😊' : (uncertain ? '🤔' : '⚠️'),
                  style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      healthy
                          ? s.t('healthy_msg')
                          : uncertain
                              ? s.t('uncertain_scan')
                              : s.t('disease_detected'),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge!
                          .copyWith(color: onBg),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _prettyLabel(record.label),
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: onBg, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!healthy && !uncertain && info != null) ...[
            const SizedBox(height: 8),
            Text(
              info.tx('desc', lang),
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
          if (blurry) ...[
            const SizedBox(height: 8),
            Text('📸 ${s.t('blurry_hint')}',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: AppColors.ink, fontWeight: FontWeight.w800)),
          ],
          if ((cropDisplay != null && cropDisplay!.isNotEmpty) ||
              ageDays != null) ...[
            const SizedBox(height: 8),
            Text(
              '🌱 ${cropDisplay ?? ""}${ageDays != null ? ' · $ageDays ${s.t('ctx_days')}' : ''}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: onBg),
            ),
          ],
          if (prediction?.cropFiltered == true &&
              cropDisplay != null) ...[
            const SizedBox(height: 4),
            Text(
              s.t('ctx_filtered').replaceAll('{crop}', cropDisplay!),
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: onBg, fontWeight: FontWeight.w700),
            ),
          ],
          if ((ageDays ?? 999) <= 30) ...[
            const SizedBox(height: 6),
            Text(s.t('ctx_age_note'),
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: onBg,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700)),
          ],
          if (!healthy && !uncertain && info != null) ...[
            const SizedBox(height: 14),
            NeoCard(
              color: Colors.white,
              shadowColor: Colors.black26,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('💊', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Text(s.t('treatment'),
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _TxRow(
                      emoji: '🌿',
                      title: s.t('organic_head'),
                      body: info.tx('organic', lang).isNotEmpty
                          ? info.tx('organic', lang)
                          : s.t(record.txKey)),
                  const SizedBox(height: 10),
                  _TxRow(
                      emoji: '🧪',
                      title: s.t('chemical_head'),
                      body: info.tx('chemical', lang)),
                  const SizedBox(height: 10),
                  _TxRow(
                      emoji: '🛡️',
                      title: s.t('prevention_head'),
                      body: info.tx('prevention', lang)),
                  const SizedBox(height: 10),
                  _TxRow(
                      emoji: '🌾',
                      title: s.t('fert_advice'),
                      body: () {
                        final n =
                            NutritionService.getAdviceLocalized(record.label, lang);
                        return '${n.nitrogenRule}\n\n${n.potashPhosphorusRule}\n\n${n.micronutrientSpray}\n\n${n.bioFertilizer}';
                      }()),
                  const SizedBox(height: 8),
                  Text(
                    s.t('dose_note'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${s.t('confidence')}: ${(record.confidence * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge!
                      .copyWith(color: onBg, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              NeoBadge(text: _confLabel(record.confidence, s), color: Colors.white),
            ],
          ),
          const SizedBox(height: 6),
          ConfidenceBar(value: record.confidence),
          if ((prediction?.top.length ?? 0) > 1) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: prediction!.top.skip(1).take(2).map((e) => NeoBadge(
                    text:
                        '${_prettyLabel(e.key)} ${(e.value * 100).round()}%',
                    color: Colors.white,
                  )).toList(),
            ),
          ],
          if (uncertain) ...[
            const SizedBox(height: 8),
            Text(s.t('retake_hint'),
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: AppColors.ink, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  static String _confLabel(double c, S s) {
    if (c >= 0.80) return '💪 ${s.t('conf_high')}';
    if (c >= 0.55) return '👌 ${s.t('conf_medium')}';
    return '❓ ${s.t('conf_low')}';
  }
}

class _TxRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;

  const _TxRow({required this.emoji, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final ScanRecord record;

  const _HistoryRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeoCard(
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 64,
                height: 64,
                child: kIsWeb
                    ? Container(
                        color: AppColors.paper,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined),
                      )
                    : _FileImage(path: record.imagePath),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _prettyLabel(record.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${record.createdAt.day}/${record.createdAt.month} • ${(record.confidence * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            NeoBadge(
              text: record.healthy ? '✅' : '⚠️',
              color: record.healthy ? AppColors.green : AppColors.red,
            ),
            const SizedBox(width: 4),
            NeoIconSquare(
              icon: Icons.medical_services_rounded,
              size: 46,
              color: AppColors.yellow,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 5),
                    content: Text(s.t(record.txKey)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FileImage extends StatelessWidget {
  final String path;
  const _FileImage({required this.path});

  @override
  Widget build(BuildContext context) {
    // This widget is only used on non-web (guarded by kIsWeb check above).
    // On native platforms, show the scan image from the file system.
    // Using a simple placeholder icon since dart:io can't be imported on web.
    return Container(
      color: AppColors.paper,
      alignment: Alignment.center,
      child: const Icon(Icons.image_rounded, color: AppColors.green),
    );
  }
}
