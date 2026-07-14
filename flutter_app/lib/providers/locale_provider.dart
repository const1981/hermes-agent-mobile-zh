import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the active locale and persists it via SharedPreferences.
///
/// Supported values:
///   - `null`  → follow system locale
///   - `zh`   → Simplified Chinese
///   - `en`   → English
class LocaleProvider extends ChangeNotifier {
  String? _languageCode; // null = system
  static const _key = 'app_language';

  LocaleProvider();

  /// Current resolved locale (never null).
  ///
  /// Falls back to `zh` when system locale is not zh or en.
  Locale get locale {
    if (_languageCode == null) {
      // Follow system
      final sys = platformLocale;
      if (sys.languageCode == 'zh' || sys.languageCode == 'en') return sys;
      return const Locale('zh'); // default for other languages
    }
    return Locale(_languageCode!);
  }

  /// The raw stored code: null | "zh" | "en".
  String? get languageCode => _languageCode;

  /// Whether we are following the system.
  bool get isFollowingSystem => _languageCode == null;

  /// System locale from [PlatformDispatcher].
  static Locale get platformLocale {
    final raw = PlatformDispatcher.instance.locale;
    if (raw.isEmpty) return const Locale('zh');
    return Locale.fromSubtags(languageCode: raw);
  }

  Future<void> init() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _languageCode = sp.getString(_key);
      notifyListeners();
    } catch (_) {}
  }

  /// Set locale. Pass `null` to follow system.
  Future<void> setLanguage(String? code) async {
    if (_languageCode == code) return;
    _languageCode = code;
    try {
      final sp = await SharedPreferences.getInstance();
      if (code == null) {
        await sp.remove(_key);
      } else {
        await sp.setString(_key, code);
      }
    } catch (_) {}
    notifyListeners();
  }

  /// Convenience: switch to follow-system.
  Future<void> followSystem() => setLanguage(null);

  /// Convenience: switch to Chinese.
  Future<void> toChinese() => setLanguage('zh');

  /// Convenience: switch to English.
  Future<void> toEnglish() => setLanguage('en');
}
