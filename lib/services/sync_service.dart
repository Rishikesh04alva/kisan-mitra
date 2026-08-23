import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

import '../core/constants.dart';
import '../core/db/app_database.dart';
import '../data/models/models.dart';

const String kPeriodicSyncTask = 'kisanPeriodicSync';
const String kManualSyncTask = 'kisanManualSync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case kPeriodicSyncTask:
      case kManualSyncTask:
        return SyncService.runOnce();
      default:
        return false;
    }
  });
}

class SyncService {
  static Future<bool> runOnce() async {
    try {
      final db = AppDatabase.instance;
      await db.init();
      final pushed = await _pushOps(db);
      final pulled = await _pullSchemes(db);
      return pushed || pulled;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _pushOps(AppDatabase db) async {
    final ops = await db.getPendingOps(limit: 50);
    if (ops.isEmpty) return true;
    try {
      final res = await http
          .post(
            Uri.parse('$kSyncBaseUrl/sync'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(
              ops
                  .map((o) => {
                        'id': o['id'],
                        'type': o['opType'],
                        'payload':
                            jsonDecode(o['payload'] as String),
                      })
                  .toList(),
            ),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        for (final o in ops) {
          await db.deleteOp(o['id'] as String);
        }
        return true;
      }
      await _markRetries(db, ops);
      return false;
    } catch (_) {
      await _markRetries(db, ops);
      return false;
    }
  }

  static Future<void> _markRetries(
      AppDatabase db, List<Map<String, Object?>> ops) async {
    for (final o in ops) {
      await db.incrementRetries(o['id'] as String);
    }
  }

  static Future<bool> _pullSchemes(AppDatabase db) async {
    try {
      final res = await http
          .get(Uri.parse('$kSyncBaseUrl/schemes'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        final schemes = list
            .map((e) => Scheme.fromMap(e as Map<String, dynamic>))
            .toList();
        if (schemes.isNotEmpty) {
          await db.seedSchemes(schemes);
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
