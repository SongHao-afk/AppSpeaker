import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/platform/loopback.dart';
import '../../../core/services/background_service.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit() : super(HomeState.initial());

  StreamSubscription<double>? _rmsSub;
  Timer? _paramDebounce;

  Timer? _wiredPoll;
  Timer? _btPoll;

  // ✅ ADDED: Callback for notification button
  void _onReceiveTaskData(dynamic data) {
    if (data == 'stop' && state.running) {
      stop();
    }
  }

  void onInit() {
    // ✅ Listen for notification button events
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    // ✅ ADDED: poll xem có cắm wired không để enable/disable switch
    _wiredPoll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      try {
        final v = await Loopback.isWiredPresent();

        if (v != state.wiredPresent) {
          emit(state.copyWith(wiredPresent: v));

          // nếu rút dây -> tắt preferWiredMic cho khỏi "kẹt"
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

    // ================== ✅ ADDED: poll xem có tai nghe BT có mic không để enable voiceMode ==================
    _btPoll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      try {
        final v = await Loopback.isBtHeadsetPresent();

        if (v != state.btHeadsetPresent) {
          emit(state.copyWith(btHeadsetPresent: v));

          // nếu tai nghe BT bị ngắt mà đang bật voiceMode -> tự tắt để khỏi "kẹt"
          if (!v && state.voiceMode) {
            emit(state.copyWith(voiceMode: false));
          }
        }
      } catch (_) {}
    });
    // =======================================================================================================
  }

  Future<void> onDispose() async {
    _wiredPoll?.cancel();
    _btPoll?.cancel();
    _paramDebounce?.cancel();

    await _rmsSub?.cancel();
    _rmsSub = null;

    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);

    if (state.running) {
      Loopback.stop();
      BackgroundService.stop();
    }
  }

  LoopbackParams _buildParams() => LoopbackParams(
    eqEnabled: state.eqEnabled,
    outputGain: state.outputGain,
    bandGains: [
      state.bassGain,
      state.lowMidGain,
      state.midGain,
      state.highMidGain,
      state.trebleGain,
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

  Future<void> start(BuildContext context) async {
    if (state.starting || state.running) return;
    emit(state.copyWith(starting: true));

    try {
      final statuses = await [
        Permission.microphone,
        Permission.bluetoothConnect, // Android 12+ (ignore nếu thấp hơn)
        Permission.notification, // Android 13+ for foreground notification
      ].request();

      final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
      if (!micGranted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('⚠️ Cần quyền Micro')));
        return;
      }

      // ✅ ADDED: set input preference trước khi start (để native pick đúng)
      try {
        await Loopback.setPreferWiredMic(
          state.preferWiredMic,
          headsetBoost: state.headsetBoost,
        );
      } catch (_) {}

      // Start foreground service
      await BackgroundService.start();

      await Loopback.start(voiceMode: state.voiceMode);
      await _pushParams();

      await _rmsSub?.cancel();
      _rmsSub = Loopback.rmsStream().listen((rms) {
        emit(state.copyWith(volume: rms.clamp(0.0, 1.0)));
      });

      emit(state.copyWith(running: true));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Start loopback fail: $e')));
    } finally {
      emit(state.copyWith(starting: false));
    }
  }

  Future<void> stop() async {
    try {
      await Loopback.stop();
    } catch (_) {}

    await _rmsSub?.cancel();
    _rmsSub = null;

    // Stop foreground service
    await BackgroundService.stop();

    emit(state.copyWith(running: false, volume: 0.0));
  }

  void setVoiceMode(bool v) {
    emit(state.copyWith(voiceMode: v));
  }

  void setEqEnabled(bool v) {
    emit(state.copyWith(eqEnabled: v));
    _pushParamsDebounced();
  }

  void setOutputGain(double v) {
    emit(state.copyWith(outputGain: v));
    _pushParamsDebounced();
  }

  void resetOutputGain() {
    emit(state.copyWith(outputGain: 1.0));
    _pushParamsDebounced();
  }

  void setBandGain(int index, double value) {
    switch (index) {
      case 0:
        emit(state.copyWith(bassGain: value));
        break;
      case 1:
        emit(state.copyWith(lowMidGain: value));
        break;
      case 2:
        emit(state.copyWith(midGain: value));
        break;
      case 3:
        emit(state.copyWith(highMidGain: value));
        break;
      case 4:
        emit(state.copyWith(trebleGain: value));
        break;
    }
    _pushParamsDebounced();
  }

  void applyPreset(String name) {
    final v = state.presets[name]!;
    emit(
      state.copyWith(
        currentPreset: name,
        bassGain: v[0],
        lowMidGain: v[1],
        midGain: v[2],
        highMidGain: v[3],
        trebleGain: v[4],
      ),
    );
    _pushParamsDebounced();
  }

  Future<void> setPreferWiredMic(bool v) async {
    emit(state.copyWith(preferWiredMic: v));
    try {
      await Loopback.setPreferWiredMic(v, headsetBoost: state.headsetBoost);
    } catch (_) {}
  }

  Future<void> setHeadsetBoost(double v) async {
    emit(state.copyWith(headsetBoost: v));
    try {
      await Loopback.setPreferWiredMic(true, headsetBoost: v);
    } catch (_) {}
  }
}
