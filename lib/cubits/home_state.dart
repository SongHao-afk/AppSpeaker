import 'dart:async';

class HomeState {
  final bool running;
  final bool starting;
  final bool voiceMode;
  final double volume;
  final StreamSubscription<double>? rmsSub;
  final bool eqEnabled;
  final double outputGain;
  final double bassGain;
  final double lowMidGain;
  final double midGain;
  final double highMidGain;
  final double trebleGain;
  final String currentPreset;
  final bool wiredPresent;
  final bool preferWiredMic;
  final double headsetBoost;
  final bool btHeadsetPresent;

  const HomeState({
    this.running = false,
    this.starting = false,
    this.voiceMode = false,
    this.volume = 0.0,
    this.rmsSub,
    this.eqEnabled = true,
    this.outputGain = 1.0,
    this.bassGain = 1.0,
    this.lowMidGain = 1.0,
    this.midGain = 1.0,
    this.highMidGain = 1.0,
    this.trebleGain = 1.0,
    this.currentPreset = 'Flat',
    this.wiredPresent = false,
    this.preferWiredMic = false,
    this.headsetBoost = 2.2,
    this.btHeadsetPresent = false,
  });

  HomeState copyWith({
    bool? running,
    bool? starting,
    bool? voiceMode,
    double? volume,
    StreamSubscription<double>? rmsSub,
    bool? eqEnabled,
    double? outputGain,
    double? bassGain,
    double? lowMidGain,
    double? midGain,
    double? highMidGain,
    double? trebleGain,
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
      rmsSub: rmsSub ?? this.rmsSub,
      eqEnabled: eqEnabled ?? this.eqEnabled,
      outputGain: outputGain ?? this.outputGain,
      bassGain: bassGain ?? this.bassGain,
      lowMidGain: lowMidGain ?? this.lowMidGain,
      midGain: midGain ?? this.midGain,
      highMidGain: highMidGain ?? this.highMidGain,
      trebleGain: trebleGain ?? this.trebleGain,
      currentPreset: currentPreset ?? this.currentPreset,
      wiredPresent: wiredPresent ?? this.wiredPresent,
      preferWiredMic: preferWiredMic ?? this.preferWiredMic,
      headsetBoost: headsetBoost ?? this.headsetBoost,
      btHeadsetPresent: btHeadsetPresent ?? this.btHeadsetPresent,
    );
  }
}
