import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/services/background_service.dart';

void main() {
  // Initialize foreground task
  BackgroundService.initialize();

  runApp(const App());
}
