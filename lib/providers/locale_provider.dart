import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

class LocaleProvider extends ChangeNotifier {
  String code = 'en';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('locale') ?? 'en';
    code = kSupportedLocales.any((l) => l.languageCode == saved) ? saved : 'en';
    notifyListeners();
  }

  Future<void> set(String newCode) async {
    if (newCode == code) return;
    code = newCode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', newCode);
  }
}
