import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_application_3/screens/home/home_screen.dart';
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

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BlocProvider(
        create: (context) => HomeCubit(),
        child: WithForegroundTask(child: const Homepage()),
      ),
    );
  }
}
