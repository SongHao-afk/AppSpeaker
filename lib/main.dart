import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_application_3/HomePage.dart';
import 'package:flutter_application_3/background_service.dart';

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

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: WithForegroundTask(child: const Homepage()));
  }
}
