import 'package:flutter/foundation.dart';

import '../core/db/app_database.dart';
import '../data/models/models.dart';

class FieldProvider extends ChangeNotifier {
  final AppDatabase db;

  List<Crop> crops = [];
  List<FieldPlot> plots = [];

  FieldProvider(this.db);

  Crop? cropById(String? id) {
    for (final c in crops) {
      if (c.id == id) return c;
    }
    return null;
  }

  FieldPlot? plotById(String id) {
    for (final p in plots) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> load() async {
    crops = await db.getCrops();
    plots = await db.getPlots();
    notifyListeners();
  }

  Future<void> assignCrop(FieldPlot plot, String cropId, DateTime sowingDate) {
    return _save(
      FieldPlot(
        id: plot.id,
        rowIdx: plot.rowIdx,
        colIdx: plot.colIdx,
        cropId: cropId,
        sowingDate: sowingDate,
        areaAcres: plot.areaAcres,
      ),
    );
  }

  Future<void> clearPlot(FieldPlot plot) {
    return _save(
      FieldPlot(id: plot.id, rowIdx: plot.rowIdx, colIdx: plot.colIdx, areaAcres: plot.areaAcres),
    );
  }

  Future<void> _save(FieldPlot updated) async {
    await db.savePlot(updated);
    await load();
  }
}
