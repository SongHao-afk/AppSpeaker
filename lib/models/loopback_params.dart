import 'dart:async';
import 'package:flutter/services.dart';

class LoopbackParams {
  final bool eqEnabled;
  final double outputGain; // linear
  final List<double> bandGains; // length=5 linear (0.5..1.5)

  const LoopbackParams({
    required this.eqEnabled,
    required this.outputGain,
    required this.bandGains,
  });

  Map<String, dynamic> toMap() => {
    'eqEnabled': eqEnabled,
    'outputGain': outputGain,
    'bandGains': bandGains,
  };
}
