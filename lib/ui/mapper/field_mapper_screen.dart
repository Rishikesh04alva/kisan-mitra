import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models/models.dart';
import '../../providers/field_provider.dart';
import '../widgets/common.dart';

class FieldMapperScreen extends StatefulWidget {
  final VoidCallback onOpenScanner;

  const FieldMapperScreen({super.key, required this.onOpenScanner});

  @override
  State<FieldMapperScreen> createState() => _FieldMapperScreenState();
}

class _FieldMapperScreenState extends State<FieldMapperScreen> {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final fp = context.watch<FieldProvider>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Text(s.t('mapper_hint'), style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: kGridCols,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: fp.plots.length,
            itemBuilder: (ctx, i) => _PlotTile(
              plot: fp.plots[i],
              crop: fp.cropById(fp.plots[i].cropId),
              onTap: () => _openPlotEditor(fp.plots[i]),
            ),
          ),
        ],
      ),
    );
  }

  void _openPlotEditor(FieldPlot plot) {
    final s = S.of(context);
    final fp = context.read<FieldProvider>();
    if (fp.crops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('err_no_data'))),
      );
      return;
    }
    showNeoSheet(context, (sheetCtx) {
      return _PlotEditorSheet(
        plot: plot,
        crops: fp.crops,
        onSaved: () {
          Navigator.of(sheetCtx).pop();
          setState(() {});
        },
        onCleared: () {
          Navigator.of(sheetCtx).pop();
          setState(() {});
        },
        onScanPressed: widget.onOpenScanner,
      );
    });
  }
}

class _PlotTile extends StatelessWidget {
  final FieldPlot plot;
  final Crop? crop;
  final VoidCallback onTap;

  const _PlotTile({required this.plot, required this.crop, required this.onTap});

  Color get _bg {
    if (crop == null) return AppColors.surface;
    final now = DateTime.now();
    final elapsed = dayDiff(now, plot.sowingDate!);
    final remaining = crop!.harvestDays - elapsed;
    if (remaining < 8) return AppColors.red;
    if (remaining < 31) return AppColors.yellow;
    return AppColors.green;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return NeoCard(
      onTap: onTap,
      color: _bg,
      child: crop == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded,
                      size: 40, color: AppColors.ink),
                  const SizedBox(height: 4),
                  Text(
                    '${plot.rowIdx + 1}-${plot.colIdx + 1}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(crop!.icon, style: const TextStyle(fontSize: 38)),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    crop!.localName(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 4),
                if (plot.sowingDate != null)
                  NeoBadge(
                    text:
                        '${crop!.harvestDays - dayDiff(DateTime.now(), plot.sowingDate!)} ${s.t('days')}',
                  ),
              ],
            ),
    );
  }
}

class _PlotEditorSheet extends StatefulWidget {
  final FieldPlot plot;
  final List<Crop> crops;
  final VoidCallback onSaved;
  final VoidCallback onCleared;
  final VoidCallback onScanPressed;

  const _PlotEditorSheet({
    required this.plot,
    required this.crops,
    required this.onSaved,
    required this.onCleared,
    required this.onScanPressed,
  });

  @override
  State<_PlotEditorSheet> createState() => _PlotEditorSheetState();
}

class _PlotEditorSheetState extends State<_PlotEditorSheet> {
  String? _selectedCropId;
  late DateTime _sowingDate;

  @override
  void initState() {
    super.initState();
    _selectedCropId = widget.plot.cropId;
    _sowingDate = widget.plot.sowingDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final planted = widget.plot.isPlanted;
    Crop? crop;
    for (final c in widget.crops) {
      if (c.id == widget.plot.cropId) {
        crop = c;
        break;
      }
    }

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
                Expanded(
                  child: Text(
                    '${s.t('choose_crop')} (${widget.plot.rowIdx + 1}-${widget.plot.colIdx + 1})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (planted && crop != null) ...[
              NeoCard(
                color: AppColors.green,
                child: Row(
                  children: [
                    Text(crop.icon, style: const TextStyle(fontSize: 34)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(crop.localName(context),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            '${s.t('sowing_date')}: ${_fmt(_sowingDate)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              NeoButton(
                label: s.t('delete'),
                emoji: '🗑️',
                color: AppColors.red,
                onTap: () async {
                  final confirmed = await _confirm(s.t('confirm_clear'));
                  if (confirmed != true) return;
                  await context
                      .read<FieldProvider>()
                      .clearPlot(widget.plot);
                  widget.onCleared();
                },
              ),
            ] else ...[
              SizedBox(
                height: 300,
                child: GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: widget.crops.length,
                  itemBuilder: (ctx, i) {
                    final c = widget.crops[i];
                    final selected = c.id == _selectedCropId;
                    return NeoCard(
                      color: selected ? AppColors.yellow : AppColors.surface,
                      onTap: () => setState(() => _selectedCropId = c.id),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(c.icon, style: const TextStyle(fontSize: 30)),
                          const SizedBox(height: 4),
                          Text(
                            c.localName(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              NeoCard(
                color: Colors.white,
                onTap: _pickSowingDate,
                child: Row(
                  children: [
                    const Icon(Icons.event_rounded, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${s.t('sowing_date')}: ${_fmt(_sowingDate)}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: NeoButton(
                      label: s.t('cancel'),
                      color: AppColors.surface,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NeoButton(
                      label: s.t('save'),
                      color: AppColors.green,
                      onTap: _save,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickSowingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _sowingDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _sowingDate = picked);
  }

  Future<bool?> _confirm(String message) {
    final s = S.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.ink, width: kBorderWidth),
          borderRadius: BorderRadius.circular(kRadius),
        ),
        content: Text(message, style: Theme.of(dCtx).textTheme.bodyLarge),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: Text(s.t('no')),
          ),
          NeoButton(label: s.t('yes'), expanded: false, onTap: () => Navigator.of(dCtx).pop(true)),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final s = S.of(context);
    if (_selectedCropId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('choose_crop'))),
      );
      return;
    }
    await context.read<FieldProvider>().assignCrop(
          widget.plot,
          _selectedCropId!,
          _sowingDate,
        );
    widget.onSaved();
  }

  String _fmt(DateTime d) =>
      '${d.day} ${_monthName(d.month)} ${d.year}';
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _monthName(int m) => _months[(m - 1).clamp(0, 11)];
