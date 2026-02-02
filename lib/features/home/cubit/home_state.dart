import 'package:equatable/equatable.dart';

class HomeState extends Equatable {
  final bool running;
  final bool starting;

  /// true: SCO realtime (headset) ~0.1s
  /// false: A2DP auto-route (loa BT ổn định)
  final bool voiceMode;

  final double volume;

  final bool eqEnabled;
  final double outputGain;

  final double bassGain;
  final double lowMidGain;
  final double midGain;
  final double highMidGain;
  final double trebleGain;

  final Map<String, List<double>> presets;
  final String currentPreset;

  // Wired mic UI state
  final bool wiredPresent;
  final bool preferWiredMic;
  final double headsetBoost;

  // BT headset presence for enabling voiceMode
  final bool btHeadsetPresent;

  const HomeState({
    required this.running,
    required this.starting,
    required this.voiceMode,
    required this.volume,
    required this.eqEnabled,
    required this.outputGain,
    required this.bassGain,
    required this.lowMidGain,
    required this.midGain,
    required this.highMidGain,
    required this.trebleGain,
    required this.presets,
    required this.currentPreset,
    required this.wiredPresent,
    required this.preferWiredMic,
    required this.headsetBoost,
    required this.btHeadsetPresent,
  });

  factory HomeState.initial() {
    final presets = <String, List<double>>{
      'Flat': [1, 1, 1, 1, 1],
      'Rock': [1.4, 1.2, 1.0, 1.3, 1.5],
      'Pop': [1.2, 1.1, 1.0, 1.0, 1.3],
      'Jazz': [1.1, 1.2, 1.3, 1.2, 1.1],
      'Heavy Metal': [1.5, 1.3, 1.0, 1.2, 1.4],
    };

    return HomeState(
      running: false,
      starting: false,
      voiceMode: false,
      volume: 0.0,
      eqEnabled: true,
      outputGain: 1.0,
      bassGain: 1.0,
      lowMidGain: 1.0,
      midGain: 1.0,
      highMidGain: 1.0,
      trebleGain: 1.0,
      presets: presets,
      currentPreset: 'Flat',
      wiredPresent: false,
      preferWiredMic: false,
      headsetBoost: 2.2,
      btHeadsetPresent: false,
    );
  }

  HomeState copyWith({
    bool? running,
    bool? starting,
    bool? voiceMode,
    double? volume,
    bool? eqEnabled,
    double? outputGain,
    double? bassGain,
    double? lowMidGain,
    double? midGain,
    double? highMidGain,
    double? trebleGain,
    Map<String, List<double>>? presets,
    String? currentPreset,
    bool? wiredPresent,
    bool? preferWiredMic,
    double? headsetBoost,
    bool? btHeadsetPresent,
  }) {
    return HomeState(
      running: running ?? this.running,
      starting: starting ?? this.starting,
      voiceMode: voiceMode ?? this.voiceMode,
      volume: volume ?? this.volume,
      eqEnabled: eqEnabled ?? this.eqEnabled,
      outputGain: outputGain ?? this.outputGain,
      bassGain: bassGain ?? this.bassGain,
      lowMidGain: lowMidGain ?? this.lowMidGain,
      midGain: midGain ?? this.midGain,
      highMidGain: highMidGain ?? this.highMidGain,
      trebleGain: trebleGain ?? this.trebleGain,
      presets: presets ?? this.presets,
      currentPreset: currentPreset ?? this.currentPreset,
      wiredPresent: wiredPresent ?? this.wiredPresent,
      preferWiredMic: preferWiredMic ?? this.preferWiredMic,
      headsetBoost: headsetBoost ?? this.headsetBoost,
      btHeadsetPresent: btHeadsetPresent ?? this.btHeadsetPresent,
    );
  }

  @override
  List<Object?> get props => [
    running,
    starting,
    voiceMode,
    volume,
    eqEnabled,
    outputGain,
    bassGain,
    lowMidGain,
    midGain,
    highMidGain,
    trebleGain,
    presets,
    currentPreset,
    wiredPresent,
    preferWiredMic,
    headsetBoost,
    btHeadsetPresent,
  ];
}
