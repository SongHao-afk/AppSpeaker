import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_application_3/l10n/app_localizations.dart';
import 'package:flutter_application_3/screens/home/home_screen.dart';
import 'package:flutter_application_3/services/app_settings_service.dart';
import 'package:flutter_application_3/services/background_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_application_3/cubits/home_cubit.dart';

void main() {
  // ✅ TEST LOG: mỗi 1s in ra để chắc chắn terminal nhận log Dart
  //Timer.periodic(const Duration(seconds: 1), (_) {
  // debugPrint ổn định hơn print trên Flutter
  //  debugPrint("🔥 DART TICK ${DateTime.now().toIso8601String()}");
  //});

  // Initialize foreground task
  BackgroundService.initialize();

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  Locale _locale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final localeCode = await AppSettingsService.readLocaleCode();
    if (localeCode == null || !_isSupported(localeCode)) return;
    if (!mounted) return;

    setState(() => _locale = Locale(localeCode));
  }

  bool _isSupported(String languageCode) {
    return AppLocalizations.supportedLocales.any(
      (locale) => locale.languageCode == languageCode,
    );
  }

  Future<void> _setLocale(Locale locale) async {
    if (!_isSupported(locale.languageCode)) return;

    setState(() => _locale = Locale(locale.languageCode));
    await AppSettingsService.saveLocaleCode(locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider(
        create: (context) => HomeCubit(),
        child: WithForegroundTask(
          child: Homepage(locale: _locale, onLocaleChanged: _setLocale),
        ),
      ),
    );
  }
}
