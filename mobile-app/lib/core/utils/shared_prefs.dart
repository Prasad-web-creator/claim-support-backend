import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SharedPrefs {
  static SharedPreferences? _instance;

  static Future<SharedPreferences> init() async {
    try {
      _instance ??= await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('[SharedPrefs] Init error: $e');
    }
    return _instance!;
  }

  static SharedPreferences get instance {
    if (_instance == null) {
      debugPrint('[SharedPrefs] instance accessed before async init completed.');
    }
    return _instance!;
  }

  static Future<SharedPreferences> getAsync() async {
    _instance ??= await SharedPreferences.getInstance();
    return _instance!;
  }
}
