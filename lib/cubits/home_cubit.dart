import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/loopback_service.dart';
import '../services/background_service.dart';
import '../models/loopback_params.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final Map<String, List<double>> presets = {
    'Flat': [1, 1, 1, 1, 1],
    'Rock': [1.4, 1.2, 1.0, 1.3, 1.5],
    'Pop': [1.2, 1.1, 1.0, 1.0, 1.3],
    'Jazz': [1.1, 1.2, 1.3, 1.2, 1.1],
    'Heavy Metal': [1.5, 1.3, 1.0, 1.2, 1.4],
  };

  Timer? _paramDebounce;
  Timer? _wiredPoll;
  Timer? _btPoll;

  HomeCubit() : super(const HomeState());

  void initialize() {
    // observe app lifecycle for iOS background audio
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver(this));

    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    // poll wired
    _wiredPoll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      try {
        final v = await Loopback.isWiredPresent();

        if (v != state.wiredPresent) {
          emit(state.copyWith(wiredPresent: v));

          if (!v && state.preferWiredMic) {
            emit(state.copyWith(preferWiredMic: false));
            try {
              await Loopback.setPreferWiredMic(
                false,
                headsetBoost: state.headsetBoost,
              );
            } catch (_) {}
          }
        }
      } catch (_) {}
    });

    // poll bt headset mic
    _btPoll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      try {
        final v = await Loopback.isBtHeadsetPresent();

        if (v != state.btHeadsetPresent) {
          emit(state.copyWith(btHeadsetPresent: v));

          if (!v && state.voiceMode) {
            emit(state.copyWith(voiceMode: false));
          }
        }
      } catch (_) {}
    });
  }

  void _onReceiveTaskData(dynamic data) {
    if (data == 'stop' && state.running) {
      stop();
    }
  }

  void didChangeAppLifecycleState(AppLifecycleState appState) {
    debugPrint('🔄 AppLifecycleState: $appState, running=${state.running}');

    if (appState == AppLifecycleState.resumed && state.running) {
      // Khi trở lại foreground: re-subscribe RMS stream để volume meter hoạt động lại
      state.rmsSub?.cancel();
      final newSub = Loopback.rmsStream().listen((rms) {
        emit(state.copyWith(volume: rms.clamp(0.0, 1.0)));
      });
      emit(state.copyWith(rmsSub: newSub));
      debugPrint('✅ Re-subscribed RMS stream after resume');
    }
    // KHÔNG stop loopback khi paused/inactive → để native tiếp tục chạy nền
  }

  LoopbackParams _buildParams() => LoopbackParams(
    eqEnabled: state.eqEnabled,
    outputGain: state.outputGain,
    bandGains: [
      state.bassGain,
      state.lowMidGain,
      state.midGain,
      state.highMidGain,
      state.trebleGain
    ],
  );

  Future<void> _pushParams() async {
    try {
      await Loopback.setParams(_buildParams());
    } catch (_) {}
  }

  void _pushParamsDebounced() {
    _paramDebounce?.cancel();
    _paramDebounce = Timer(const Duration(milliseconds: 40), () {
      if (state.running) _pushParams();
    });
  }

  Future<void> start() async {
    if (state.starting || state.running) return;
    emit(state.copyWith(starting: true));

    try {
      if (Platform.isAndroid) {
        final statuses = await [
          Permission.microphone,
          Permission.bluetoothConnect,
          Permission.notification,
        ].request();

        final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
        if (!micGranted) {
          emit(state.copyWith(starting: false));
          return;
        }
      }

      // set input preference trước khi start
      try {
        await Loopback.setPreferWiredMic(
          state.preferWiredMic,
          headsetBoost: state.headsetBoost,
        );
      } catch (_) {}

      // Start foreground service (Android cần; iOS gọi cũng không sao)
      await BackgroundService.start();

      // ✅ iOS sẽ popup xin mic ở native nếu đang undetermined
      await Loopback.start(voiceMode: state.voiceMode);
      await _pushParams();

      state.rmsSub?.cancel();
      final newSub = Loopback.rmsStream().listen((rms) {
        emit(state.copyWith(volume: rms.clamp(0.0, 1.0)));
      });

      emit(state.copyWith(running: true, rmsSub: newSub));
    } catch (e) {
      debugPrint('❌ Start loopback fail: $e');
    } finally {
      emit(state.copyWith(starting: false));
    }
  }

  Future<void> stop() async {
    try {
      await Loopback.stop();
    } catch (_) {}
    await state.rmsSub?.cancel();

    await BackgroundService.stop();

    emit(state.copyWith(running: false, volume: 0.0, rmsSub: null));
  }

  void applyPreset(String name) {
    final v = presets[name]!;
    emit(state.copyWith(
      currentPreset: name,
      bassGain: v[0],
      lowMidGain: v[1],
      midGain: v[2],
      highMidGain: v[3],
      trebleGain: v[4],
    ));
    _pushParamsDebounced();
  }

  void setVoiceMode(bool value) {
    emit(state.copyWith(voiceMode: value));
  }

  void setPreferWiredMic(bool value) async {
    emit(state.copyWith(preferWiredMic: value));
    try {
      await Loopback.setPreferWiredMic(
        value,
        headsetBoost: state.headsetBoost,
      );
    } catch (_) {}
  }

  void setHeadsetBoost(double value) async {
    emit(state.copyWith(headsetBoost: value));
    try {
      await Loopback.setPreferWiredMic(
        true,
        headsetBoost: value,
      );
    } catch (_) {}
  }

  void setEqEnabled(bool value) {
    emit(state.copyWith(eqEnabled: value));
    _pushParamsDebounced();
  }

  void setBassGain(double value) {
    emit(state.copyWith(bassGain: value));
    _pushParamsDebounced();
  }

  void setLowMidGain(double value) {
    emit(state.copyWith(lowMidGain: value));
    _pushParamsDebounced();
  }

  void setMidGain(double value) {
    emit(state.copyWith(midGain: value));
    _pushParamsDebounced();
  }

  void setHighMidGain(double value) {
    emit(state.copyWith(highMidGain: value));
    _pushParamsDebounced();
  }

  void setTrebleGain(double value) {
    emit(state.copyWith(trebleGain: value));
    _pushParamsDebounced();
  }

  void setOutputGain(double value) {
    emit(state.copyWith(outputGain: value));
    _pushParamsDebounced();
  }

  @override
  Future<void> close() {
    _wiredPoll?.cancel();
    _btPoll?.cancel();
    _paramDebounce?.cancel();
    state.rmsSub?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);

    if (state.running) {
      Loopback.stop();
      BackgroundService.stop();
    }

    return super.close();
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final HomeCubit cubit;

  _AppLifecycleObserver(this.cubit);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    cubit.didChangeAppLifecycleState(state);
  }
}
