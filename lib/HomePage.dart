import 'dart:async';
import 'dart:io'; // ✅ ADD: để check Platform.isAndroid
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'loopback.dart';
import 'background_service.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});
  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  bool running = false;
  bool _starting = false;

  /// true: SCO realtime (headset) ~0.1s
  /// false: A2DP auto-route (loa BT ổn định)
  bool voiceMode = false; // ✅ default A2DP ổn định

  double volume = 0.0;
  StreamSubscription<double>? _rmsSub;

  bool eqEnabled = true;
  double outputGain = 1.0;

  double bassGain = 1.0;
  double lowMidGain = 1.0;
  double midGain = 1.0;
  double highMidGain = 1.0;
  double trebleGain = 1.0;

  final Map<String, List<double>> presets = {
    'Flat': [1, 1, 1, 1, 1],
    'Rock': [1.4, 1.2, 1.0, 1.3, 1.5],
    'Pop': [1.2, 1.1, 1.0, 1.0, 1.3],
    'Jazz': [1.1, 1.2, 1.3, 1.2, 1.1],
    'Heavy Metal': [1.5, 1.3, 1.0, 1.2, 1.4],
  };
  String currentPreset = 'Flat';

  Timer? _paramDebounce;

  // ================== ✅ ADDED: Wired mic UI state ==================
  bool wiredPresent = false; // đang cắm tai nghe dây/USB?
  bool preferWiredMic = false; // switch: dùng mic tai nghe
  Timer? _wiredPoll; // poll enable/disable switch
  double headsetBoost = 2.2; // boost cho mic tai nghe
  // =================================================================

  // ================== ✅ ADDED: BT headset presence for enabling voiceMode ==================
  bool btHeadsetPresent = false; // có tai nghe BT có mic không?
  Timer? _btPoll; // poll enable/disable voiceMode switch
  // =================================================================

  // ✅ ADDED: Callback for notification button
  void _onReceiveTaskData(dynamic data) {
    if (data == 'stop' && running) {
      _stop();
    }
  }

  @override
  void initState() {
    super.initState();

    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    // poll wired
    _wiredPoll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      try {
        final v = await Loopback.isWiredPresent();
        if (!mounted) return;

        if (v != wiredPresent) {
          setState(() => wiredPresent = v);

          if (!v && preferWiredMic) {
            preferWiredMic = false;
            try {
              await Loopback.setPreferWiredMic(
                false,
                headsetBoost: headsetBoost,
              );
            } catch (_) {}
            if (mounted) setState(() {});
          }
        }
      } catch (_) {}
    });

    // poll bt headset mic
    _btPoll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      try {
        final v = await Loopback.isBtHeadsetPresent();
        if (!mounted) return;

        if (v != btHeadsetPresent) {
          setState(() => btHeadsetPresent = v);

          if (!v && voiceMode) {
            setState(() => voiceMode = false);
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _wiredPoll?.cancel();
    _btPoll?.cancel();
    _paramDebounce?.cancel();
    _rmsSub?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);

    if (running) {
      Loopback.stop();
      BackgroundService.stop();
    }
    super.dispose();
  }

  LoopbackParams _buildParams() => LoopbackParams(
    eqEnabled: eqEnabled,
    outputGain: outputGain,
    bandGains: [bassGain, lowMidGain, midGain, highMidGain, trebleGain],
  );

  Future<void> _pushParams() async {
    try {
      await Loopback.setParams(_buildParams());
    } catch (_) {}
  }

  void _pushParamsDebounced() {
    _paramDebounce?.cancel();
    _paramDebounce = Timer(const Duration(milliseconds: 40), () {
      if (running) _pushParams();
    });
  }

  // ✅✅✅ FIX CHÍNH NẰM Ở ĐÂY
  // - Android: xin permission bằng permission_handler
  // - iOS: KHÔNG chặn ở đây, để native requestRecordPermission tự bật popup
  Future<void> _start() async {
    if (_starting || running) return;
    _starting = true;

    try {
      if (Platform.isAndroid) {
        final statuses = await [
          Permission.microphone,
          Permission.bluetoothConnect,
          Permission.notification,
        ].request();

        final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
        if (!micGranted) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('⚠️ Cần quyền Micro')));
          }
          return;
        }
      }

      // set input preference trước khi start
      try {
        await Loopback.setPreferWiredMic(
          preferWiredMic,
          headsetBoost: headsetBoost,
        );
      } catch (_) {}

      // Start foreground service (Android cần; iOS gọi cũng không sao)
      await BackgroundService.start();

      // ✅ iOS sẽ popup xin mic ở native nếu đang undetermined
      await Loopback.start(voiceMode: voiceMode);
      await _pushParams();

      _rmsSub?.cancel();
      _rmsSub = Loopback.rmsStream().listen((rms) {
        if (!mounted) return;
        setState(() => volume = rms.clamp(0.0, 1.0));
      });

      if (mounted) setState(() => running = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Start loopback fail: $e')));
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> _stop() async {
    try {
      await Loopback.stop();
    } catch (_) {}
    await _rmsSub?.cancel();
    _rmsSub = null;

    await BackgroundService.stop();

    if (mounted) {
      setState(() {
        running = false;
        volume = 0.0;
      });
    }
  }

  void _applyPreset(String name) {
    final v = presets[name]!;
    setState(() {
      currentPreset = name;
      bassGain = v[0];
      lowMidGain = v[1];
      midGain = v[2];
      highMidGain = v[3];
      trebleGain = v[4];
    });
    _pushParamsDebounced();
  }

  Widget _band(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        RotatedBox(
          quarterTurns: -1,
          child: Slider(
            value: value,
            onChanged: (v) {
              onChanged(v);
              _pushParamsDebounced();
            },
            min: 0.5,
            max: 1.5,
            divisions: 10,
            activeColor: Colors.greenAccent,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = (volume * 100).clamp(0, 100).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('🎤 Realtime Mic → Speaker'),
        backgroundColor: Colors.grey[900],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                width: 260,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[800],
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: (260 * volume).clamp(0, 260),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Âm lượng: $level%',
                style: const TextStyle(color: Colors.white70),
              ),

              if (running) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.greenAccent),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.greenAccent,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '🔊 Đang chạy nền - Có thể chuyển sang app khác',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Voice mode (SCO ~0.1s)',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 10),
                        Switch(
                          value: voiceMode,
                          activeThumbColor: Colors.greenAccent,
                          onChanged: (running || !btHeadsetPresent)
                              ? null
                              : (v) => setState(() => voiceMode = v),
                        ),
                      ],
                    ),
                    Text(
                      !btHeadsetPresent
                          ? '⚠️ Chỉ bật được khi có tai nghe Bluetooth (có mic/SCO). Loa Bluetooth (A2DP) không bật được.'
                          : (voiceMode
                                ? '✅ SCO realtime (tai nghe BT). Loa BT có thể fail.'
                                : '✅ A2DP auto-route (loa BT ổn định, quality tốt hơn)'),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (running) ...[
                      const SizedBox(height: 6),
                      const Text(
                        '⚠️ Muốn đổi mode thì STOP rồi bật lại',
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Mic tai nghe (wired)',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 10),
                        Switch(
                          value: preferWiredMic,
                          activeThumbColor: Colors.cyanAccent,
                          onChanged: (!wiredPresent)
                              ? null
                              : (v) async {
                                  setState(() => preferWiredMic = v);
                                  try {
                                    await Loopback.setPreferWiredMic(
                                      v,
                                      headsetBoost: headsetBoost,
                                    );
                                  } catch (_) {}
                                },
                        ),
                      ],
                    ),
                    Text(
                      wiredPresent
                          ? (preferWiredMic
                                ? '✅ Input: mic tai nghe'
                                : '✅ Input: mic điện thoại (default)')
                          : '⚠️ Chỉ bật được khi cắm tai nghe dây/USB',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (wiredPresent && preferWiredMic) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Headset mic boost: x${headsetBoost.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      Slider(
                        value: headsetBoost,
                        min: 1.0,
                        max: 6.0,
                        divisions: 50,
                        activeColor: Colors.cyanAccent,
                        onChanged: (v) async {
                          setState(() => headsetBoost = v);
                          try {
                            await Loopback.setPreferWiredMic(
                              true,
                              headsetBoost: v,
                            );
                          } catch (_) {}
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Custom Equalizer',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Switch(
                    value: eqEnabled,
                    activeThumbColor: Colors.greenAccent,
                    onChanged: (v) {
                      setState(() => eqEnabled = v);
                      _pushParamsDebounced();
                    },
                  ),
                ],
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _band('60Hz', bassGain, (v) => setState(() => bassGain = v)),
                  _band(
                    '230Hz',
                    lowMidGain,
                    (v) => setState(() => lowMidGain = v),
                  ),
                  _band('910Hz', midGain, (v) => setState(() => midGain = v)),
                  _band(
                    '3600Hz',
                    highMidGain,
                    (v) => setState(() => highMidGain = v),
                  ),
                  _band(
                    '14000Hz',
                    trebleGain,
                    (v) => setState(() => trebleGain = v),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              DropdownButton<String>(
                value: currentPreset,
                dropdownColor: Colors.grey[900],
                style: const TextStyle(color: Colors.white),
                onChanged: (val) => _applyPreset(val!),
                items: presets.keys
                    .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                    .toList(),
              ),

              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Output Gain',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'x${outputGain.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.white54,
                            size: 18,
                          ),
                          onPressed: () {
                            setState(() => outputGain = 1.0);
                            _pushParamsDebounced();
                          },
                        ),
                      ],
                    ),
                    Slider(
                      value: outputGain,
                      min: 0.5,
                      max: 4.0,
                      divisions: 35,
                      activeColor: Colors.orangeAccent,
                      onChanged: (v) {
                        setState(() => outputGain = v);
                        _pushParamsDebounced();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              ElevatedButton(
                onPressed: _starting ? null : (running ? _stop : _start),
                style: ElevatedButton.styleFrom(
                  backgroundColor: running ? Colors.red : Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: Text(
                  running ? 'DỪNG' : 'BẬT MICRO',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
