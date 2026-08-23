import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../data/models/models.dart';
import '../constants.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._();
  AppDatabase._();

  Database? _db;
  Database get database => _db!;

  Future<void> init() async {
    if (_db != null) return;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'kisan_mitra.db'),
      version: 1,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE crops(
            id TEXT PRIMARY KEY, nameKey TEXT NOT NULL, icon TEXT NOT NULL,
            waterIntervalDays INTEGER NOT NULL, harvestDays INTEGER NOT NULL,
            fertSchedule TEXT NOT NULL)
        ''');
        await d.execute('''
          CREATE TABLE fields(
            id TEXT PRIMARY KEY, rowIdx INTEGER NOT NULL, colIdx INTEGER NOT NULL,
            cropId TEXT, sowingDate TEXT, areaAcres REAL NOT NULL DEFAULT 1,
            updatedAt TEXT NOT NULL,
            UNIQUE(rowIdx, colIdx))
        ''');
        await d.execute(
          'CREATE TABLE watering_log(id TEXT PRIMARY KEY, fieldId TEXT NOT NULL, wateredOn TEXT NOT NULL)',
        );
        await d.execute(
          'CREATE INDEX idx_water_field ON watering_log(fieldId, wateredOn)',
        );
        await d.execute('''
          CREATE TABLE scans(
            id TEXT PRIMARY KEY, imagePath TEXT NOT NULL, label TEXT NOT NULL,
            confidence REAL NOT NULL, createdAt TEXT NOT NULL, fieldId TEXT)
        ''');
        await d.execute(
          'CREATE INDEX idx_scans_created ON scans(createdAt DESC)',
        );
        await d.execute('''
          CREATE TABLE schemes(
            id TEXT PRIMARY KEY, nameEn TEXT NOT NULL, nameHi TEXT NOT NULL,
            nameMr TEXT NOT NULL, category TEXT NOT NULL, state TEXT NOT NULL DEFAULT 'ALL',
            elig TEXT NOT NULL DEFAULT '', benEn TEXT NOT NULL, benHi TEXT NOT NULL,
            benMr TEXT NOT NULL, url TEXT NOT NULL DEFAULT '', phone TEXT NOT NULL DEFAULT '')
        ''');
        await d.execute('CREATE INDEX idx_scheme_cat ON schemes(category)');
        await d.execute('CREATE INDEX idx_scheme_state ON schemes(state)');
        await d.execute('''
          CREATE TABLE weather_cache(
            id INTEGER PRIMARY KEY CHECK(id = 1),
            tempC REAL NOT NULL, humidity REAL NOT NULL, rainMm REAL NOT NULL,
            fetchedAt TEXT NOT NULL)
        ''');
        await d.execute('''
          CREATE TABLE pending_ops(
            id TEXT PRIMARY KEY, opType TEXT NOT NULL, payload TEXT NOT NULL,
            createdAt TEXT NOT NULL, retries INTEGER NOT NULL DEFAULT 0)
        ''');
        await d.execute(
          'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
      },
    );
    final existing =
        await database.query('fields', columns: ['rowIdx', 'colIdx']);
    final have = existing.map((e) => '${e['rowIdx']}_${e['colIdx']}').toSet();
    for (var r = 0; r < kGridRows; r++) {
      for (var c = 0; c < kGridCols; c++) {
        final key = '${r}_$c';
        if (!have.contains(key)) {
          await database.insert('fields', {
            'id': 'plot_${r}_$c',
            'rowIdx': r,
            'colIdx': c,
            'areaAcres': 1.0,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }
      }
    }
  }

  static const int kGridColsCount = kGridCols;
  static const int kGridRowsCount = kGridRows;

  Future<void> seedCrops(List<Crop> crops) async {
    final batch = database.batch();
    for (final c in crops) {
      batch.insert(
        'crops',
        {
          'id': c.id,
          'nameKey': c.nameKey,
          'icon': c.icon,
          'waterIntervalDays': c.waterIntervalDays,
          'harvestDays': c.harvestDays,
          'fertSchedule':
              jsonEncode(c.stages.map((s) => {'from': s.fromDay, 'to': s.toDay, 'label': s.labelKey}).toList()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> seedSchemes(List<Scheme> schemes) async {
    final batch = database.batch();
    for (final s in schemes) {
      batch.insert('schemes', s.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Crop>> getCrops() async {
    final rows = await database.query('crops', orderBy: 'nameKey');
    return rows.map((r) {
      final stagesRaw = jsonDecode(r['fertSchedule'] as String) as List;
      return Crop(
        id: r['id'] as String,
        nameKey: r['nameKey'] as String,
        icon: r['icon'] as String,
        waterIntervalDays: r['waterIntervalDays'] as int,
        harvestDays: r['harvestDays'] as int,
        stages: stagesRaw
            .map((e) => FertStage(
                  fromDay: e['from'] as int,
                  toDay: e['to'] as int,
                  labelKey: e['label'] as String,
                ))
            .toList(),
      );
    }).toList();
  }

  Future<List<FieldPlot>> getPlots() async {
    final rows = await database.query('fields', orderBy: 'rowIdx, colIdx');
    return rows.map(_plotFromRow).toList();
  }

  FieldPlot _plotFromRow(Map<String, Object?> r) => FieldPlot(
        id: r['id'] as String,
        rowIdx: r['rowIdx'] as int,
        colIdx: r['colIdx'] as int,
        cropId: r['cropId'] as String?,
        sowingDate: r['sowingDate'] == null
            ? null
            : DateTime.parse(r['sowingDate'] as String),
        areaAcres: (r['areaAcres'] as num?)?.toDouble() ?? 1.0,
      );

  Future<void> savePlot(FieldPlot plot) async {
    await database.update(
      'fields',
      {
        'cropId': plot.cropId,
        'sowingDate': plot.sowingDate == null
            ? null
            : dateOnly(plot.sowingDate!),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [plot.id],
    );
    await enqueueOp('upsert_field', {
      'id': plot.id,
      'cropId': plot.cropId,
      'sowingDate': plot.sowingDate == null ? null : dateOnly(plot.sowingDate!),
      'areaAcres': plot.areaAcres,
    });
  }

  Future<DateTime?> lastWateredOn(String fieldId) async {
    final rows = await database.query(
      'watering_log',
      where: 'fieldId = ?',
      whereArgs: [fieldId],
      orderBy: 'wateredOn DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['wateredOn'] as String);
  }

  Future<void> logWater(String fieldId, DateTime on) async {
    await database.insert('watering_log', {
      'id': 'w_${fieldId}_${dateOnly(on)}',
      'fieldId': fieldId,
      'wateredOn': dateOnly(on),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await enqueueOp('water_event', {'fieldId': fieldId, 'on': dateOnly(on)});
  }

  Future<List<ScanRecord>> getScans({int limit = 20}) async {
    final rows = await database.query('scans',
        orderBy: 'createdAt DESC', limit: limit);
    return rows.map((r) => ScanRecord(
          id: r['id'] as String,
          imagePath: r['imagePath'] as String,
          label: r['label'] as String,
          confidence: (r['confidence'] as num).toDouble(),
          createdAt: DateTime.parse(r['createdAt'] as String),
          fieldId: r['fieldId'] as String?,
        )).toList();
  }

  Future<void> addScan(ScanRecord scan) async {
    await database.insert('scans', {
      'id': scan.id,
      'imagePath': scan.imagePath,
      'label': scan.label,
      'confidence': scan.confidence,
      'createdAt': scan.createdAt.toIso8601String(),
      'fieldId': scan.fieldId,
    });
    await enqueueOp('scan_result', {
      'label': scan.label,
      'confidence': scan.confidence,
      'at': scan.createdAt.toIso8601String(),
    });
  }

  Future<ScanRecord?> latestScan() async {
    final all = await getScans(limit: 1);
    return all.isEmpty ? null : all.first;
  }

  Future<List<Scheme>> getSchemes({
    String category = '',
    String state = '',
    String query = '',
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (category.isNotEmpty && category != 'ALL') {
      where.add('category = ?');
      args.add(category);
    }
    if (state.isNotEmpty && state != 'ALL') {
      where.add("(state IN (?, 'ALL'))");
      args.add(state);
    }
    if (query.trim().isNotEmpty) {
      final q = '%${query.trim().toLowerCase()}%';
      where.add('(LOWER(nameEn) LIKE ? OR nameHi LIKE ? OR nameMr LIKE ?)');
      args.addAll([q, q, q]);
    }
    final rows = await database.query(
      'schemes',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'id',
    );
    return rows.map(Scheme.fromMap).toList();
  }

  Future<WeatherSnapshot?> getCachedWeather() async {
    final rows = await database.query('weather_cache', limit: 1);
    if (rows.isEmpty) return null;
    return WeatherSnapshot(
      tempC: (rows.first['tempC'] as num).toDouble(),
      humidity: (rows.first['humidity'] as num).toDouble(),
      rainMm: (rows.first['rainMm'] as num).toDouble(),
      fetchedAt: DateTime.parse(rows.first['fetchedAt'] as String),
    );
  }

  Future<void> saveWeather(WeatherSnapshot w) async {
    await database.insert(
      'weather_cache',
      {
        'id': 1,
        'tempC': w.tempC,
        'humidity': w.humidity,
        'rainMm': w.rainMm,
        'fetchedAt': w.fetchedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> enqueueOp(String opType, Map<String, dynamic> payload) async {
    await database.insert('pending_ops', {
      'id': 'op_${DateTime.now().microsecondsSinceEpoch}',
      'opType': opType,
      'payload': jsonEncode(payload),
      'createdAt': DateTime.now().toIso8601String(),
      'retries': 0,
    });
  }

  Future<List<Map<String, Object?>>> getPendingOps({int limit = 50}) =>
      database.query('pending_ops', orderBy: 'createdAt', limit: limit);

  Future<void> deleteOp(String id) =>
      database.delete('pending_ops', where: 'id = ?', whereArgs: [id]);

  Future<void> incrementRetries(String id) => database.rawUpdate(
        'UPDATE pending_ops SET retries = retries + 1 WHERE id = ?',
        [id],
      );

  Future<String?> getSetting(String key) async {
    final rows = await database
        .query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }
}
