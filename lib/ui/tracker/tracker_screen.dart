import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../providers/field_provider.dart';
import '../../providers/tracker_provider.dart';
import '../../services/location_service.dart';
import '../../services/nutrition_service.dart';
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

  void _openLocationSelector() {
    final s = S.of(context);
    final tracker = context.read<TrackerProvider>();
    showNeoSheet(context, (sheetCtx) {
      return _LocationSelectorSheet(
        tracker: tracker,
        s: s,
        onSelected: (loc) async {
          Navigator.of(sheetCtx).pop();
          await tracker.setLocation(
            lat: loc.latitude,
            lon: loc.longitude,
            name: loc.displayName,
            isGps: loc.isGps,
          );
        },
        onGpsTap: () async {
          Navigator.of(sheetCtx).pop();
          await tracker.refreshWeatherOnline(requestGps: true);
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tracker = context.watch<TrackerProvider>();
    final fieldProvider = context.watch<FieldProvider>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          _WeatherStrip(
            tracker: tracker,
            onLocationTap: _openLocationSelector,
          ),
          SectionHeader(text: s.t('today_plan'), emoji: '🚜'),
          if (tracker.plan.isEmpty)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.35,
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

          // 1. Stage-wise Fertilizer for Active Crops
          ..._fertCards(tracker.plan, s),

          // 2. Disease & Pest Specific Fertilizer / Recovery Guidance
          if (tracker.latestScan != null && !tracker.latestScan!.healthy) ...[
            SectionHeader(
              text: s.t('disease_nutrition_title'),
              emoji: '💊',
            ),
            _DiseaseNutritionCard(
              scan: tracker.latestScan!,
              s: s,
            ),
          ],

          // 3. Planted Crops Nutritional Schedule (All mapped plants)
          if (fieldProvider.plots.any((p) => p.isPlanted)) ...[
            SectionHeader(
              text: s.t('crop_stage_nutrition'),
              emoji: '🌾',
            ),
            ..._plantedCropNutritionList(fieldProvider, s),
          ],
        ],
      ),
    );
  }

  String? _cropName(FieldProvider fp, String? cropId) {
    final crop = fp.cropById(cropId);
    return crop?.localName(context);
  }

  List<Widget> _fertCards(List<PlanRow> plan, S s) {
    final due = plan.where((r) => r.fertDue != null).toList(growable: false);
    if (due.isEmpty) return [];
    final fieldProvider = context.read<FieldProvider>();
    return [
      SectionHeader(text: s.t('fert_due'), emoji: '🧪'),
      ...due.map((r) {
        final crop = fieldProvider.cropById(r.plot.cropId);
        final stage = r.fertDue!;
        final window = '${stage.fromDay}–${stage.toDay} ${s.t('days')}';
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
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
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
                    Text(crop?.icon ?? '🌾', style: const TextStyle(fontSize: 30)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            crop == null ? '' : crop.localName(context),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s.t(stage.labelKey)} • $window',
                            style: Theme.of(context).textTheme.bodyMedium,
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

  List<Widget> _plantedCropNutritionList(FieldProvider fp, S s) {
    final plantedPlots = fp.plots.where((p) => p.isPlanted).toList();
    final uniqueCropIds = plantedPlots.map((p) => p.cropId!).toSet();
    final widgets = <Widget>[];

    for (final cid in uniqueCropIds) {
      final crop = fp.cropById(cid);
      if (crop == null) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: NeoCard(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(crop.icon, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${crop.localName(context)} (${crop.harvestDays} ${s.t('days')})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...crop.stages.map((stage) {
                  final fertItems = stage.fert.entries
                      .where((e) => e.value > 0)
                      .map((e) => '${_nutName(e.key)}: ${_fmt(e.value)} kg/ac')
                      .join(' • ');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6, right: 8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.green,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${s.t(stage.labelKey)} (Day ${stage.fromDay}–${stage.toDay})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              if (fertItems.isNotEmpty)
                                Text(
                                  fertItems,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              else
                                const Text(
                                  'Soil moisture maintenance / No chemical top-dress',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  String _fmt(double kg) =>
      kg % 1 == 0 ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);

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

class _DiseaseNutritionCard extends StatelessWidget {
  final ScanRecord scan;
  final S s;

  const _DiseaseNutritionCard({required this.scan, required this.s});

  @override
  Widget build(BuildContext context) {
    final advice = NutritionService.getAdviceLocalized(scan.label, s.code);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: NeoCard(
        color: AppColors.paper,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🧪', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        advice.headline,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Targeting: ${scan.label.replaceAll('___', ' ').replaceAll('_', ' ')}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _NutritionPoint(
              emoji: '🚫',
              title: 'Nitrogen (Urea) Rule',
              description: advice.nitrogenRule,
              color: Colors.red.shade900,
            ),
            const SizedBox(height: 8),
            _NutritionPoint(
              emoji: '🛡️',
              title: 'Potash & Immunity',
              description: advice.potashPhosphorusRule,
              color: Colors.green.shade900,
            ),
            const SizedBox(height: 8),
            _NutritionPoint(
              emoji: '💧',
              title: 'Foliar Recovery Spray',
              description: advice.micronutrientSpray,
              color: Colors.blue.shade900,
            ),
            const SizedBox(height: 8),
            _NutritionPoint(
              emoji: '🌱',
              title: 'Bio-Fertilizer / Soil Health',
              description: advice.bioFertilizer,
              color: Colors.amber.shade900,
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionPoint extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final Color color;

  const _NutritionPoint({
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherStrip extends StatelessWidget {
  final TrackerProvider tracker;
  final VoidCallback onLocationTap;

  const _WeatherStrip({
    required this.tracker,
    required this.onLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final w = tracker.weather;
    final isLocating = tracker.isLocating;
    final isLoading = tracker.loadingWeather;
    final locationName = w?.locationName ?? 'Nagpur, Maharashtra';
    final isGps = w?.isGpsLocation ?? false;

    return NeoCard(
      color: AppColors.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Interactive Location & GPS status row
          InkWell(
            onTap: onLocationTap,
            child: Row(
              children: [
                const Text('📍', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          locationName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_location_alt_rounded, size: 18),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (isLocating)
                  NeoBadge(
                    text: s.t('locating_gps'),
                    color: AppColors.yellow,
                  )
                else
                  NeoBadge(
                    text: isGps ? s.t('gps_live') : s.t('gps_offline'),
                    color: isGps ? AppColors.greenLight : Colors.white,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Weather Condition Banner
          if (w != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.ink, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(w.weatherEmoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      s.t(w.conditionKey),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (w.apparentTempC != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '• ${w.apparentTempC!.round()}°C',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkMuted,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Realtime Weather Metrics Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _WeatherCell(
                emoji: '🌡️',
                label: s.t('temp'),
                value: w == null ? '--' : '${w.tempC.round()}°C',
              ),
              _WeatherCell(
                emoji: '💧',
                label: s.t('humidity'),
                value: w == null ? '--' : '${w.humidity.round()}%',
              ),
              _WeatherCell(
                emoji: '🌧️',
                label: s.t('rain'),
                value: w == null ? '--' : '${w.rainMm.toStringAsFixed(1)}mm',
              ),
              _WeatherCell(
                emoji: '💨',
                label: s.t('wind'),
                value: w == null ? '--' : '${w.windSpeedKmH.round()}km/h',
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Footer row with Sync Status & Refresh Button
          Row(
            children: [
              NeoBadge(
                text: w == null
                    ? s.t('weather_offline')
                    : (tracker.weatherStale
                        ? s.t('weather_stale')
                        : s.t('weather_live')),
                color: Colors.white,
              ),
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              else
                NeoIconSquare(
                  icon: Icons.my_location_rounded,
                  size: 44,
                  onTap: () => context
                      .read<TrackerProvider>()
                      .refreshWeatherOnline(requestGps: true),
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

  const _WeatherCell({
    required this.emoji,
    required this.label,
    required this.value,
  });

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

class _LocationSelectorSheet extends StatefulWidget {
  final TrackerProvider tracker;
  final S s;
  final ValueChanged<UserLocation> onSelected;
  final VoidCallback onGpsTap;

  const _LocationSelectorSheet({
    required this.tracker,
    required this.s,
    required this.onSelected,
    required this.onGpsTap,
  });

  @override
  State<_LocationSelectorSheet> createState() => _LocationSelectorSheetState();
}

class _LocationSelectorSheetState extends State<_LocationSelectorSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<UserLocation> _filtered = LocationService.popularLocations;
  bool _searching = false;

  void _onSearchChanged(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _filtered = LocationService.popularLocations;
        _searching = false;
      });
      return;
    }

    final localMatches = LocationService.popularLocations
        .where((loc) =>
            loc.displayName.toLowerCase().contains(q.toLowerCase()))
        .toList();

    if (localMatches.isNotEmpty) {
      setState(() {
        _filtered = localMatches;
        _searching = false;
      });
    }

    if (q.trim().length >= 3) {
      setState(() => _searching = true);
      final onlineResults =
          await widget.tracker.locationService.searchCities(q);
      if (mounted && _searchCtrl.text.trim() == q.trim()) {
        setState(() {
          _filtered = onlineResults.isNotEmpty ? onlineResults : localMatches;
          _searching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📍', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(
                  widget.s.t('select_location'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 14),
            NeoButton(
              label: widget.s.t('use_live_gps'),
              emoji: '🎯',
              color: AppColors.greenLight,
              onTap: widget.onGpsTap,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: widget.s.t('search_city_hint'),
                prefixIcon: const Icon(Icons.search, color: AppColors.ink),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.s.t('popular_agri_zones'),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (ctx, i) {
                  final loc = _filtered[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () => widget.onSelected(loc),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.ink,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                loc.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 14),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
