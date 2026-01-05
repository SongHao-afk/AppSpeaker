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

class Loopback {
  static const MethodChannel _ch = MethodChannel('loopback');
  static const EventChannel _ev = EventChannel('loopback_events');

  static Stream<double>? _rmsStream;

  static Future<void> start({bool voiceMode = false}) =>
      _ch.invokeMethod('start', {'voiceMode': voiceMode});

  static Future<void> stop() => _ch.invokeMethod('stop');

  static Future<void> setParams(LoopbackParams p) =>
      _ch.invokeMethod('setParams', p.toMap());

  static Stream<double> rmsStream() {
    _rmsStream ??= _ev.receiveBroadcastStream().map(
      (e) => (e is num) ? e.toDouble() : 0.0,
    );
    return _rmsStream!;
  }
}
