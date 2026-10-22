import 'package:flutter/material.dart';

import '../services/storage_service.dart';

/// إعدادات العرض والقراءة.
class SettingsState extends ChangeNotifier {
  SettingsState() {
    final storage = StorageService.instance;
    _themeMode = ThemeMode.values[
        storage.themeModeIndex.clamp(0, ThemeMode.values.length - 1)];
    _fontScale = storage.fontScale;
    _autoScroll = storage.autoScroll;
    _arabicDigits = storage.arabicDigits;
    _keepAwake = storage.keepAwake;
  }

  late ThemeMode _themeMode;
  late double _fontScale;
  late bool _autoScroll;
  late bool _arabicDigits;
  late bool _keepAwake;

  ThemeMode get themeMode => _themeMode;
  double get fontScale => _fontScale;
  bool get autoScroll => _autoScroll;
  bool get arabicDigits => _arabicDigits;
  bool get keepAwake => _keepAwake;

  static const double minFontScale = 0.85;
  static const double maxFontScale = 1.8;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await StorageService.instance.setThemeModeIndex(mode.index);
    notifyListeners();
  }

  Future<void> setFontScale(double value) async {
    _fontScale = value.clamp(minFontScale, maxFontScale);
    await StorageService.instance.setFontScale(_fontScale);
    notifyListeners();
  }

  Future<void> bumpFontScale(double delta) =>
      setFontScale(_fontScale + delta);

  Future<void> setAutoScroll(bool value) async {
    _autoScroll = value;
    await StorageService.instance.setAutoScroll(value);
    notifyListeners();
  }

  Future<void> setArabicDigits(bool value) async {
    _arabicDigits = value;
    await StorageService.instance.setArabicDigits(value);
    notifyListeners();
  }

  Future<void> setKeepAwake(bool value) async {
    _keepAwake = value;
    await StorageService.instance.setKeepAwake(value);
    notifyListeners();
  }
}
