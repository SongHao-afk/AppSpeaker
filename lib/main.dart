import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_application_3/HomePage.dart';
import 'package:flutter_application_3/background_service.dart';

void main() {
  // Initialize foreground task
  BackgroundService.initialize();
  
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: WithForegroundTask(
        child: const Homepage(),
      ),
    );
  }
}

///ngu
