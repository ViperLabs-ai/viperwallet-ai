
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../security/wallet_security.dart';

class AppProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  static const String _localeKey = 'app_locale';

  AppProvider() {
    _loadLocalePreference();
  }

  Locale get locale => _locale;

  Future<void> _loadLocalePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLocale = prefs.getString(_localeKey);
      if (savedLocale != null) {
        _locale = Locale(savedLocale);
        notifyListeners();
      }
    } catch (e) {
      print('❌ Locale loading error: $e');
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;

    _locale = locale;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale.languageCode);
    } catch (e) {
      print('❌ Locale saving error: $e');
    }
  }

  Future<void> deleteWalletData() async {
    await WalletSecurity.deleteWalletData();
    notifyListeners();
  }

  Future<bool> hasWallet() async {
    return await WalletSecurity.hasWallet();
  }
}