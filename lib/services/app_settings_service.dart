import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AppSettingsService {
  const AppSettingsService._();

  static Future<File> _settingsFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}app_settings.json');
  }

  static Future<Map<String, dynamic>> load() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) return <String, dynamic>{};

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    return <String, dynamic>{};
  }

  static Future<void> save(Map<String, dynamic> settings) async {
    try {
      final file = await _settingsFile();
      await file.create(recursive: true);
      await file.writeAsString(jsonEncode(settings));
    } catch (_) {}
  }

  static Future<String?> readThemeModeName() async {
    final settings = await load();
    final theme = settings['theme'];
    return theme is String ? theme : null;
  }

  static Future<void> saveThemeModeName(String themeModeName) async {
    final settings = await load();
    settings['theme'] = themeModeName;
    await save(settings);
  }

  static Future<String?> readLocaleCode() async {
    final settings = await load();
    final locale = settings['locale'];
    return locale is String ? locale : null;
  }

  static Future<void> saveLocaleCode(String localeCode) async {
    final settings = await load();
    settings['locale'] = localeCode;
    await save(settings);
  }
}
