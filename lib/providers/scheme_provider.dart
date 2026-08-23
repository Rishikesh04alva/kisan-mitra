import 'package:flutter/foundation.dart';

import '../core/db/app_database.dart';
import '../data/models/models.dart';

class SchemeProvider extends ChangeNotifier {
  final AppDatabase db;

  String category = 'ALL';
  String state = 'ALL';
  String query = '';
  List<Scheme> items = [];
  List<String> categories = ['ALL'];
  List<String> states = ['ALL'];
  bool loaded = false;

  SchemeProvider(this.db);

  Future<void> init() async {
    final all = await db.getSchemes();
    categories = ['ALL', ...all.map((s) => s.category).toSet().toList()..sort()];
    states = [
      'ALL',
      ...all.map((s) => s.state).toSet().where((e) => e != 'ALL').toList()..sort(),
    ];
    await apply();
    loaded = true;
  }

  Future<void> setCategory(String c) async {
    category = c;
    await apply();
  }

  Future<void> setStateFilter(String s) async {
    state = s;
    await apply();
  }

  Future<void> setQuery(String q) async {
    query = q;
    await apply();
  }

  Future<void> apply() async {
    items = await db.getSchemes(
      category: category,
      state: state,
      query: query,
    );
    notifyListeners();
  }
}
