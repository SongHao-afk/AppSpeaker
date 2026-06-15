import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubits/home_state.dart';
import '../../cubits/home_cubit.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});
  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  late HomeCubit _homeCubit;
  bool _voiceButtonOn = false;
  bool _headsetMicButtonOn = false;

  static const _primary = Color(0xFFE047FF);
  static const _ink = Color(0xFFF8EEFF);
  static const _muted = Color(0xFFB9A8C8);
  static const _page = Color(0xFF150D25);
  static const _panel = Color(0xFF241435);
  static const _cyan = Color(0xFF6EEBFF);

  @override
  void initState() {
    super.initState();
    _homeCubit = context.read<HomeCubit>();
    _homeCubit.initialize();
  }

  @override
  void dispose() {
    _homeCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        final cubit = context.read<HomeCubit>();

        return Scaffold(
          backgroundColor: _page,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Header(),
                      const SizedBox(height: 24),
                      Center(child: _mainMicButton(state, cubit)),
                      const SizedBox(height: 20),
                      _volumeBars(state.volume, state.running),
                      const SizedBox(height: 18),
                      _modeSelector(),
                      const SizedBox(height: 18),
                      _equalizerPanel(state, cubit),
                      if (state.running) ...[
                        const SizedBox(height: 14),
                        _runningNotice(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _mainMicButton(HomeState state, HomeCubit cubit) {
    return GestureDetector(
      onTap: state.starting
          ? null
          : (state.running ? () => cubit.stop() : () => cubit.start()),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 132,
        height: 132,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: state.running
                ? const [Color(0xFFFF4FA3), Color(0xFFFF7A1A)]
                : const [
                    Color(0xFFE047FF),
                    Color(0xFF8B5CFF),
                    Color(0xFF8DF7FF),
                  ],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: 0.48),
              blurRadius: 34,
              spreadRadius: 3,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: _cyan.withValues(alpha: 0.28),
              blurRadius: 42,
              spreadRadius: 7,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              state.running ? Icons.stop_rounded : Icons.mic_none_rounded,
              color: Colors.white,
              size: 34,
            ),
            const SizedBox(height: 8),
            Text(
              state.starting
                  ? 'ĐANG BẬT'
                  : (state.running ? 'DỪNG' : 'BẮT ĐẦU'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _volumeBars(double volume, bool running) {
    final normalized = volume.clamp(0.0, 1.0);
    const maxHeights = [24.0, 38.0, 52.0, 64.0, 48.0, 36.0, 26.0];
    const idleHeights = [7.0, 10.0, 13.0, 16.0, 12.0, 9.0, 7.0];
    const colors = [
      Color(0xFFE047FF),
      Color(0xFFFF4FA3),
      Color(0xFF6EEBFF),
      Color(0xFFD7FF4A),
      Color(0xFF36FF9C),
      Color(0xFF8B5CFF),
      Color(0xFFFFB020),
    ];
    const rhythm = [0.45, 0.8, 0.62, 1.0, 0.74, 0.55, 0.9];

    return SizedBox(
      height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(maxHeights.length, (index) {
          final level = running ? (0.18 + normalized * rhythm[index]) : 0.0;
          final height = running
              ? (idleHeights[index] +
                    (maxHeights[index] - idleHeights[index]) *
                        level.clamp(0.0, 1.0))
              : idleHeights[index];

          return AnimatedContainer(
            duration: const Duration(milliseconds: 85),
            curve: Curves.easeOutCubic,
            width: 6,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: colors[index],
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: colors[index].withValues(alpha: running ? 0.58 : 0.36),
                  blurRadius: running ? 16 : 10,
                  spreadRadius: running ? 1 : 0,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _modeSelector() {
    return Row(
      children: [
        Expanded(
          child: _toggleButton(
            label: 'Chế độ Voice',
            selected: _voiceButtonOn,
            colorA: const Color(0xFFE047FF),
            colorB: const Color(0xFF8B5CFF),
            onTap: () => setState(() => _voiceButtonOn = !_voiceButtonOn),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _toggleButton(
            label: 'Mic tai nghe',
            selected: _headsetMicButtonOn,
            colorA: const Color(0xFF6EEBFF),
            colorB: const Color(0xFF36FF9C),
            onTap: () =>
                setState(() => _headsetMicButtonOn = !_headsetMicButtonOn),
          ),
        ),
      ],
    );
  }

  Widget _toggleButton({
    required String label,
    required bool selected,
    required Color colorA,
    required Color colorB,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      height: 50,
      decoration: BoxDecoration(
        gradient: selected
            ? LinearGradient(
                colors: [colorA, colorB],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF2B1A41), Color(0xFF3A2255)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: selected
              ? Colors.white.withValues(alpha: 0.32)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? colorA.withValues(alpha: 0.42)
                : Colors.black.withValues(alpha: 0.24),
            blurRadius: selected ? 24 : 14,
            spreadRadius: selected ? 1 : 0,
            offset: const Offset(0, 10),
          ),
          if (selected)
            BoxShadow(
              color: colorB.withValues(alpha: 0.28),
              blurRadius: 34,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(25),
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? Colors.white : _muted,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.78),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _equalizerPanel(HomeState state, HomeCubit cubit) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 18),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Bộ lọc âm',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Switch(
                value: state.eqEnabled,
                activeThumbColor: _primary,
                activeTrackColor: _primary.withValues(alpha: 0.38),
                inactiveThumbColor: const Color(0xFFCFC4DC),
                inactiveTrackColor: const Color(0xFF3A254E),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => cubit.setEqEnabled(v),
              ),
              const SizedBox(width: 6),
              _presetMenu(state, cubit),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _band(
                '60Hz',
                state.bassGain,
                const Color(0xFFE047FF),
                (v) => cubit.setBassGain(v),
              ),
              _band(
                '230Hz',
                state.lowMidGain,
                const Color(0xFF6EEBFF),
                (v) => cubit.setLowMidGain(v),
              ),
              _band(
                '910Hz',
                state.midGain,
                const Color(0xFFD7FF4A),
                (v) => cubit.setMidGain(v),
              ),
              _band(
                '3.6kHz',
                state.highMidGain,
                const Color(0xFF36FF9C),
                (v) => cubit.setHighMidGain(v),
              ),
              _band(
                '14kHz',
                state.trebleGain,
                const Color(0xFFFFB020),
                (v) => cubit.setTrebleGain(v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetMenu(HomeState state, HomeCubit cubit) {
    return Container(
      height: 30,
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2E1A43),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: state.currentPreset,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 17,
            color: Color.fromARGB(255, 0, 221, 255),
          ),
          style: const TextStyle(
            color: Color.fromARGB(255, 0, 221, 255),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          dropdownColor: const Color.fromARGB(255, 60, 33, 16),
          onChanged: (val) => cubit.applyPreset(val!),
          items: cubit.presets.keys
              .map((n) => DropdownMenuItem(value: n, child: Text(n)))
              .toList(),
        ),
      ),
    );
  }

  Widget _runningNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2D27),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF36FF9C).withValues(alpha: 0.35),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF36FF9C), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đang chạy nền - có thể chuyển sang ứng dụng khác',
              style: TextStyle(
                color: Color(0xFFB8FFD9),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _band(
    String label,
    double value,
    Color color,
    ValueChanged<double> onChanged,
  ) {
    return SizedBox(
      width: 45,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 120,
            child: RotatedBox(
              quarterTurns: -1,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: color,
                  inactiveTrackColor: const Color(0xFF4A315F),
                  thumbColor: Colors.white,
                  overlayColor: color.withValues(alpha: 0.18),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                ),
                child: Slider(
                  value: value,
                  onChanged: onChanged,
                  min: 0.5,
                  max: 1.5,
                  divisions: 10,
                ),
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.26),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
        BoxShadow(color: _primary.withValues(alpha: 0.08), blurRadius: 30),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.graphic_eq_rounded,
          color: _HomepageState._primary,
          size: 16,
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Realtime Mic → Speaker',
            style: TextStyle(
              color: _HomepageState._primary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
