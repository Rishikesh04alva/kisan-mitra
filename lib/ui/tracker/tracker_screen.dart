import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../providers/field_provider.dart';
import '../../providers/tracker_provider.dart';
import '../../services/weather_service.dart';
import '../guide/fertilizer_guide_screen.dart';
import '../widgets/common.dart';

class TrackerScreen extends StatefulWidget {
  final VoidCallback onOpenMapper;

  const TrackerScreen({super.key, required this.onOpenMapper});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  bool _bootstrapped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapped) {
      _bootstrapped = true;
      context.read<TrackerProvider>().refresh();
      context.read<FieldProvider>().load();
    }
  }

  String _tr(String key, [Map<String, String>? params]) =>
      S.of(context).tf(key, params ?? {});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tracker = context.watch<TrackerProvider>();
    final fieldProvider = context.watch<FieldProvider>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          _WeatherStrip(tracker: tracker),
          SectionHeader(text: s.t('today_plan'), emoji: '🚜'),
          if (tracker.plan.isEmpty)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.42,
              child: EmptyState(
                emoji: '🌱',
                text: s.t('no_fields_yet'),
                hint: s.t('no_fields_hint'),
                buttonLabel: s.t('open_mapper'),
                onButton: widget.onOpenMapper,
              ),
            )
          else
            ...tracker.plan.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _PlanCard(
                    row: row,
                    cropName: _cropName(fieldProvider, row.plot.cropId),
                    onWatered: () =>
                        context.read<TrackerProvider>().markWatered(row.plot.id),
                    tr: _tr,
                  ),
                )),
          ..._fertCards(tracker.plan, s),
          SectionHeader(text: s.t('fg_title'), emoji: '📖'),
          NeoButton(
            label: s.t('open_guide'),
            emoji: '🧪',
            color: AppColors.greenLight,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FertilizerGuideScreen()),
            ),
          ),
        ],
      ),
    );
  }

  String? _cropName(FieldProvider fp, String? cropId) {
    final crop = fp.cropById(cropId);
    return crop == null ? null : crop.localName(context);
  }

  List<Widget> _fertCards(List<PlanRow> plan, S s) {
    final due =
        plan.where((r) => r.fertDue != null).toList(growable: false);
    if (due.isEmpty) return [];
    final fieldProvider = context.read<FieldProvider>();
    return [
      SectionHeader(text: s.t('fert_due'), emoji: '🧪'),
      ...due.map((r) {
        final crop = fieldProvider.cropById(r.plot.cropId);
        final stage = r.fertDue!;
        final window =
            '${stage.fromDay}–${stage.toDay} ${s.t('days')}';
        final fert = <Widget>[];
        stage.fert.forEach((nutrient, kg) {
          if (kg <= 0) return;
          final emoji = nutrient == 'urea'
              ? '⚪️'
              : nutrient == 'dap'
                  ? '🟤'
                  : '🟥';
          fert.add(Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_nutName(nutrient)}  ${_fmt(kg)} ${s.t('kg_per_acre')}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ));
        });
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NeoCard(
            color: AppColors.yellow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(crop?.icon ?? '🌾',
                        style: const TextStyle(fontSize: 30)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            crop == null ? '' : crop.localName(context),
                            style:
                                Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s.t(stage.labelKey)} • $window',
                            style:
                                Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (fert.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.t('apply_now'),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        ...fert,
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    ];
  }

  String _fmt(double kg) => kg % 1 == 0 ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);

  String _nutName(String n) {
    switch (n) {
      case 'urea':
        return 'Urea (46-0-0)';
      case 'dap':
        return 'DAP (18-46-0)';
      case 'mop':
        return 'MOP (0-0-60)';
      default:
        return n;
    }
  }
}

class _WeatherStrip extends StatelessWidget {
  final TrackerProvider tracker;

  const _WeatherStrip({required this.tracker});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final w = tracker.weather;
    return NeoCard(
      color: AppColors.blue,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _WeatherCell(emoji: '🌡️', label: s.t('temp'), value: w == null ? '--' : '${w.tempC.round()}°C'),
              _WeatherCell(emoji: '💧', label: s.t('humidity'), value: w == null ? '--' : '${w.humidity.round()}%'),
              _WeatherCell(emoji: '🌧️', label: s.t('rain'), value: w == null ? '--' : '${w.rainMm.toStringAsFixed(1)}mm'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              NeoBadge(
                text: w == null ? s.t('weather_offline') : s.t('weather_stale'),
                color: Colors.white,
              ),
              const Spacer(),
              if (tracker.loadingWeather)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              else
                NeoIconSquare(
                  icon: Icons.refresh_rounded,
                  size: 44,
                  onTap: () => context
                      .read<TrackerProvider>()
                      .refreshWeatherOnline(WeatherService()),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherCell extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _WeatherCell({required this.emoji, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanRow row;
  final String? cropName;
  final VoidCallback onWatered;
  final String Function(String, [Map<String, String>?]) tr;

  const _PlanCard({
    required this.row,
    required this.cropName,
    required this.onWatered,
    required this.tr,
  });

  Color get _bg {
    switch (row.decision) {
      case IrrigationDecision.water:
        return AppColors.blue;
      case IrrigationDecision.skip:
        return AppColors.surface;
      case IrrigationDecision.monitor:
        return AppColors.yellow;
    }
  }

  String get _emoji {
    switch (row.decision) {
      case IrrigationDecision.water:
        return '💦';
      case IrrigationDecision.skip:
        return '☔️';
      case IrrigationDecision.monitor:
        return '👀';
    }
  }

  String get _actionKey {
    switch (row.decision) {
      case IrrigationDecision.water:
        return 'water_now';
      case IrrigationDecision.skip:
        return 'dont_water';
      case IrrigationDecision.monitor:
        return 'just_monitor';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return NeoCard(
      color: _bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(_emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(_actionKey),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${cropName ?? ''} • ${s.t(row.reasonKey)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (row.decision == IrrigationDecision.water) ...[
            const SizedBox(width: 10),
            NeoButton(
              label: s.t('done'),
              emoji: '✅',
              color: AppColors.green,
              expanded: false,
              minHeight: 48,
              onTap: onWatered,
            ),
          ],
        ],
      ),
    );
  }
}
