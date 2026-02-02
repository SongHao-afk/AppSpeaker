import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  late final HomeCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = HomeCubit()..onInit();
  }

  @override
  void dispose() {
    _cubit.onDispose();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F7FA),
            appBar: AppBar(
              elevation: 0,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B9D), Color(0xFFC06C84)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.mic,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Micro Karaoke',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.white,
              centerTitle: true,
            ),
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    const Color(0xFFF5F7FA),
                  ],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  children: [
                    // ========== PHẦN CHÍNH ==========
                    
                    // Main action button - modern and friendly
                    Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: LinearGradient(
                          colors: state.running
                              ? [const Color(0xFFFF6B6B), const Color(0xFFEE5A6F)]
                              : [const Color(0xFF4ECDC4), const Color(0xFF44A08D)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (state.running
                                    ? const Color(0xFFFF6B6B)
                                    : const Color(0xFF4ECDC4))
                                .withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: state.starting
                            ? null
                            : (state.running
                                  ? context.read<HomeCubit>().stop
                                  : () => context.read<HomeCubit>().start(context)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              state.running
                                  ? Icons.stop_circle_rounded
                                  : Icons.mic_rounded,
                              color: Colors.black,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              state.running ? 'DỪNG' : 'BẬT MICRO',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Service status indicator
                    if (state.running) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00D2A0), Color(0xFF00B894)],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00D2A0).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.black,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '🎵 Đang hoạt động',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Volume meter card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: RmsMeter(volume: state.volume),
                    ),

                    const SizedBox(height: 16),

                    // Equalizer section in card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 15,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: EqualizerSection(
                        eqEnabled: state.eqEnabled,
                        onEqEnabledChanged: (v) =>
                            context.read<HomeCubit>().setEqEnabled(v),
                        bassGain: state.bassGain,
                        lowMidGain: state.lowMidGain,
                        midGain: state.midGain,
                        highMidGain: state.highMidGain,
                        trebleGain: state.trebleGain,
                        onBassChanged: (v) =>
                            context.read<HomeCubit>().setBandGain(0, v),
                        onLowMidChanged: (v) =>
                            context.read<HomeCubit>().setBandGain(1, v),
                        onMidChanged: (v) =>
                            context.read<HomeCubit>().setBandGain(2, v),
                        onHighMidChanged: (v) =>
                            context.read<HomeCubit>().setBandGain(3, v),
                        onTrebleChanged: (v) =>
                            context.read<HomeCubit>().setBandGain(4, v),
                        presets: state.presets,
                        currentPreset: state.currentPreset,
                        onPresetChanged: (val) {
                          context.read<HomeCubit>().applyPreset(val!);
                        },
                        outputGain: state.outputGain,
                        onOutputGainChanged: (v) =>
                            context.read<HomeCubit>().setOutputGain(v),
                        onOutputGainReset: () =>
                            context.read<HomeCubit>().resetOutputGain(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ========== CÀI ĐẶT NÂNG CAO ==========
                    
                    Text(
                      'Cài đặt nâng cao',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Voice mode section in expandable card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: VoiceModeSection(
                        running: state.running,
                        btHeadsetPresent: state.btHeadsetPresent,
                        voiceMode: state.voiceMode,
                        onChanged: (v) => context.read<HomeCubit>().setVoiceMode(v),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Wired mic section in expandable card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: WiredMicSection(
                        wiredPresent: state.wiredPresent,
                        preferWiredMic: state.preferWiredMic,
                        headsetBoost: state.headsetBoost,
                        onPreferWiredMicChanged: (v) =>
                            context.read<HomeCubit>().setPreferWiredMic(v),
                        onHeadsetBoostChanged: (v) =>
                            context.read<HomeCubit>().setHeadsetBoost(v),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Friendly tip
                    Text(
                      '💡 Mẹo: Nhấn vào các mục để xem chi tiết',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================
// UI widgets (inlined)
// ============================

class RmsMeter extends StatelessWidget {
  final double volume;

  const RmsMeter({super.key, required this.volume});

  @override
  Widget build(BuildContext context) {
    final level = (volume * 100).clamp(0, 100).toStringAsFixed(1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(
              Icons.graphic_eq_rounded,
              color: Color(0xFF4ECDC4),
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Âm lượng',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Text(
              '$level%',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: double.infinity,
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey[300],
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              width: (MediaQuery.of(context).size.width - 72) * volume,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class VoiceModeSection extends StatefulWidget {
  final bool running;
  final bool btHeadsetPresent;
  final bool voiceMode;
  final ValueChanged<bool> onChanged;

  const VoiceModeSection({
    super.key,
    required this.running,
    required this.btHeadsetPresent,
    required this.voiceMode,
    required this.onChanged,
  });

  @override
  State<VoiceModeSection> createState() => _VoiceModeSectionState();
}

class _VoiceModeSectionState extends State<VoiceModeSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
        },
        leading: Icon(
          Icons.bluetooth_audio_rounded,
          color: _isExpanded ? const Color(0xFF4ECDC4) : Colors.grey[600],
        ),
        title: const Text(
          'Voice mode (SCO)',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        trailing: Switch(
          value: widget.voiceMode,
          activeColor: const Color(0xFF4ECDC4),
          onChanged: (widget.running || !widget.btHeadsetPresent) ? null : widget.onChanged,
        ),
        children: [
          Text(
            !widget.btHeadsetPresent
                ? '⚠️ Chỉ bật được khi có tai nghe Bluetooth (có mic/SCO). Loa Bluetooth (A2DP) không bật được.'
                : (widget.voiceMode
                      ? '✅ SCO realtime (tai nghe BT). Loa BT có thể fail.'
                      : '✅ A2DP auto-route (loa BT ổn định, quality tốt hơn)'),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          if (widget.running) ...[
            const SizedBox(height: 8),
            const Text(
              '⚠️ Muốn đổi mode thì STOP rồi bật lại',
              style: TextStyle(
                color: Color(0xFFFF6B6B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class WiredMicSection extends StatefulWidget {
  final bool wiredPresent;
  final bool preferWiredMic;
  final double headsetBoost;
  final ValueChanged<bool> onPreferWiredMicChanged;
  final ValueChanged<double> onHeadsetBoostChanged;

  const WiredMicSection({
    super.key,
    required this.wiredPresent,
    required this.preferWiredMic,
    required this.headsetBoost,
    required this.onPreferWiredMicChanged,
    required this.onHeadsetBoostChanged,
  });

  @override
  State<WiredMicSection> createState() => _WiredMicSectionState();
}

class _WiredMicSectionState extends State<WiredMicSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
        },
        leading: Icon(
          Icons.headset_mic_rounded,
          color: _isExpanded ? const Color(0xFF4ECDC4) : Colors.grey[600],
        ),
        title: const Text(
          'Mic tai nghe (wired)',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        trailing: Switch(
          value: widget.preferWiredMic,
          activeColor: const Color(0xFF4ECDC4),
          onChanged: (!widget.wiredPresent) ? null : widget.onPreferWiredMicChanged,
        ),
        children: [
          Text(
            widget.wiredPresent
                ? (widget.preferWiredMic
                      ? '✅ Input: mic tai nghe'
                      : '✅ Input: mic điện thoại (default)')
                : '⚠️ Chỉ bật được khi cắm tai nghe dây/USB',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          if (widget.wiredPresent && widget.preferWiredMic) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Boost:',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'x${widget.headsetBoost.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Slider(
              value: widget.headsetBoost,
              min: 1.0,
              max: 6.0,
              divisions: 50,
              activeColor: const Color(0xFF4ECDC4),
              onChanged: widget.onHeadsetBoostChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class EqualizerSection extends StatelessWidget {
  final bool eqEnabled;
  final ValueChanged<bool> onEqEnabledChanged;

  final double bassGain;
  final double lowMidGain;
  final double midGain;
  final double highMidGain;
  final double trebleGain;

  final ValueChanged<double> onBassChanged;
  final ValueChanged<double> onLowMidChanged;
  final ValueChanged<double> onMidChanged;
  final ValueChanged<double> onHighMidChanged;
  final ValueChanged<double> onTrebleChanged;

  final Map<String, List<double>> presets;
  final String currentPreset;
  final ValueChanged<String?> onPresetChanged;

  final double outputGain;
  final ValueChanged<double> onOutputGainChanged;
  final VoidCallback onOutputGainReset;

  const EqualizerSection({
    super.key,
    required this.eqEnabled,
    required this.onEqEnabledChanged,
    required this.bassGain,
    required this.lowMidGain,
    required this.midGain,
    required this.highMidGain,
    required this.trebleGain,
    required this.onBassChanged,
    required this.onLowMidChanged,
    required this.onMidChanged,
    required this.onHighMidChanged,
    required this.onTrebleChanged,
    required this.presets,
    required this.currentPreset,
    required this.onPresetChanged,
    required this.outputGain,
    required this.onOutputGainChanged,
    required this.onOutputGainReset,
  });

  Widget _band(String label, double value, ValueChanged<double> onChanged) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(
            height: 120,
            child: RotatedBox(
              quarterTurns: -1,
              child: Slider(
                value: value,
                onChanged: onChanged,
                min: 0.5,
                max: 1.5,
                divisions: 10,
                activeColor: const Color(0xFF4ECDC4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(
              Icons.equalizer_rounded,
              color: Color(0xFF4ECDC4),
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Equalizer',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Switch(
              value: eqEnabled,
              activeColor: const Color(0xFF4ECDC4),
              onChanged: onEqEnabledChanged,
            ),
          ],
        ),
        if (eqEnabled) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _band('60', bassGain, onBassChanged),
              _band('230', lowMidGain, onLowMidChanged),
              _band('910', midGain, onMidChanged),
              _band('3.6k', highMidGain, onHighMidChanged),
              _band('14k', trebleGain, onTrebleChanged),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<String>(
              value: currentPreset,
              dropdownColor: Colors.white,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              icon: const Icon(Icons.arrow_drop_down, size: 20),
              underline: const SizedBox(),
              isDense: true,
              onChanged: onPresetChanged,
              items: presets.keys
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Output Gain',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'x${outputGain.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  color: Colors.grey[600],
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onOutputGainReset,
              ),
            ],
          ),
          Slider(
            value: outputGain,
            min: 0.5,
            max: 4.0,
            divisions: 35,
            activeColor: const Color(0xFFFF6B9D),
            onChanged: onOutputGainChanged,
          ),
        ],
      ],
    );
  }
}