import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../cubits/home_state.dart';
import '../../cubits/home_cubit.dart';
import '../../services/app_settings_service.dart';

enum _AppThemeMode { defaultMode, light, dark, red, green, blue, pink }

class _ThemePalette {
  const _ThemePalette({
    required this.mode,
    required this.page,
    required this.panel,
    required this.panelAlt,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.success,
    required this.danger,
    required this.ink,
    required this.muted,
    required this.track,
    required this.visualizerColors,
  });

  final _AppThemeMode mode;
  final Color page;
  final Color panel;
  final Color panelAlt;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color success;
  final Color danger;
  final Color ink;
  final Color muted;
  final Color track;
  final List<Color> visualizerColors;

  bool get isLight => mode == _AppThemeMode.light;

  static const all = [
    _ThemePalette(
      mode: _AppThemeMode.defaultMode,
      page: Color(0xFF150D25),
      panel: Color(0xFF241435),
      panelAlt: Color(0xFF2B1A41),
      primary: Color(0xFFE047FF),
      secondary: Color(0xFF8B5CFF),
      accent: Color(0xFF6EEBFF),
      success: Color(0xFF36FF9C),
      danger: Color(0xFFFF4FA3),
      ink: Color(0xFFF8EEFF),
      muted: Color(0xFFB9A8C8),
      track: Color(0xFF4A315F),
      visualizerColors: [
        Color(0xFFE047FF),
        Color(0xFFFF4FA3),
        Color(0xFF6EEBFF),
        Color(0xFFD7FF4A),
        Color(0xFF36FF9C),
        Color(0xFF8B5CFF),
        Color(0xFFFFB020),
      ],
    ),
    _ThemePalette(
      mode: _AppThemeMode.light,
      page: Color(0xFFF7F4FF),
      panel: Color(0xFFFFFFFF),
      panelAlt: Color(0xFFECE6F8),
      primary: Color(0xFF7C3AED),
      secondary: Color(0xFF2563EB),
      accent: Color(0xFF0891B2),
      success: Color(0xFF059669),
      danger: Color(0xFFE11D48),
      ink: Color(0xFF20142E),
      muted: Color(0xFF665775),
      track: Color(0xFFD9CCE9),
      visualizerColors: [
        Color(0xFF7C3AED),
        Color(0xFFE11D48),
        Color(0xFF0891B2),
        Color(0xFF16A34A),
        Color(0xFF0D9488),
        Color(0xFF2563EB),
        Color(0xFFF59E0B),
      ],
    ),
    _ThemePalette(
      mode: _AppThemeMode.dark,
      page: Color(0xFF090A12),
      panel: Color(0xFF161826),
      panelAlt: Color(0xFF202235),
      primary: Color(0xFF7DD3FC),
      secondary: Color(0xFFA78BFA),
      accent: Color(0xFF22D3EE),
      success: Color(0xFF34D399),
      danger: Color(0xFFFB7185),
      ink: Color(0xFFF8FAFC),
      muted: Color(0xFFA5B4C8),
      track: Color(0xFF34384F),
      visualizerColors: [
        Color(0xFF7DD3FC),
        Color(0xFFA78BFA),
        Color(0xFF22D3EE),
        Color(0xFF34D399),
        Color(0xFFFACC15),
        Color(0xFF60A5FA),
        Color(0xFFFB7185),
      ],
    ),
    _ThemePalette(
      mode: _AppThemeMode.red,
      page: Color(0xFF1C080C),
      panel: Color(0xFF2B0F14),
      panelAlt: Color(0xFF3A151B),
      primary: Color(0xFFFF4D6D),
      secondary: Color(0xFFFF7A59),
      accent: Color(0xFFFFC857),
      success: Color(0xFF4ADE80),
      danger: Color(0xFFFF375F),
      ink: Color(0xFFFFF1F3),
      muted: Color(0xFFE7A4AE),
      track: Color(0xFF65303A),
      visualizerColors: [
        Color(0xFFFF4D6D),
        Color(0xFFFF375F),
        Color(0xFFFF7A59),
        Color(0xFFFFC857),
        Color(0xFFFF8FAB),
        Color(0xFFFFB703),
        Color(0xFFFF6B6B),
      ],
    ),
    _ThemePalette(
      mode: _AppThemeMode.green,
      page: Color(0xFF06170F),
      panel: Color(0xFF0E2419),
      panelAlt: Color(0xFF163323),
      primary: Color(0xFF36FF9C),
      secondary: Color(0xFF14B86A),
      accent: Color(0xFFA3E635),
      success: Color(0xFF22C55E),
      danger: Color(0xFFFB7185),
      ink: Color(0xFFEFFFF6),
      muted: Color(0xFFA8D8BE),
      track: Color(0xFF2A5B42),
      visualizerColors: [
        Color(0xFF36FF9C),
        Color(0xFF14B86A),
        Color(0xFFA3E635),
        Color(0xFF22D3EE),
        Color(0xFF84CC16),
        Color(0xFF10B981),
        Color(0xFFFACC15),
      ],
    ),
    _ThemePalette(
      mode: _AppThemeMode.blue,
      page: Color(0xFF071326),
      panel: Color(0xFF0D1F3D),
      panelAlt: Color(0xFF14305B),
      primary: Color(0xFF38BDF8),
      secondary: Color(0xFF2563EB),
      accent: Color(0xFF67E8F9),
      success: Color(0xFF34D399),
      danger: Color(0xFFFB7185),
      ink: Color(0xFFEFF8FF),
      muted: Color(0xFFA9C5DF),
      track: Color(0xFF25476D),
      visualizerColors: [
        Color(0xFF38BDF8),
        Color(0xFF2563EB),
        Color(0xFF67E8F9),
        Color(0xFF60A5FA),
        Color(0xFF22D3EE),
        Color(0xFF818CF8),
        Color(0xFF34D399),
      ],
    ),
    _ThemePalette(
      mode: _AppThemeMode.pink,
      page: Color(0xFF210817),
      panel: Color(0xFF331025),
      panelAlt: Color(0xFF451735),
      primary: Color(0xFFFF4FA3),
      secondary: Color(0xFFEC4899),
      accent: Color(0xFFFF8BD1),
      success: Color(0xFF36FF9C),
      danger: Color(0xFFFF3D75),
      ink: Color(0xFFFFF0F8),
      muted: Color(0xFFF0A8CD),
      track: Color(0xFF6B3152),
      visualizerColors: [
        Color(0xFFFF4FA3),
        Color(0xFFFF8BD1),
        Color(0xFFEC4899),
        Color(0xFFE047FF),
        Color(0xFFFFB3C7),
        Color(0xFFC084FC),
        Color(0xFFFF7A1A),
      ],
    ),
  ];

  static _ThemePalette byMode(_AppThemeMode mode) =>
      all.firstWhere((theme) => theme.mode == mode);
}

enum _LanguageCode {
  en,
  vi,
  id,
  th,
  ms,
  fil,
  ja,
  ko,
  zh,
  hi,
  es,
  pt,
  fr,
  de,
  it,
  tr,
  ar,
  ru,
}

class _LanguageOption {
  const _LanguageOption({required this.code, required this.locale});

  final _LanguageCode code;
  final Locale locale;

  static const all = [
    _LanguageOption(code: _LanguageCode.en, locale: Locale('en')),
    _LanguageOption(code: _LanguageCode.vi, locale: Locale('vi')),
    _LanguageOption(code: _LanguageCode.id, locale: Locale('id')),
    _LanguageOption(code: _LanguageCode.th, locale: Locale('th')),
    _LanguageOption(code: _LanguageCode.ms, locale: Locale('ms')),
    _LanguageOption(code: _LanguageCode.fil, locale: Locale('fil')),
    _LanguageOption(code: _LanguageCode.ja, locale: Locale('ja')),
    _LanguageOption(code: _LanguageCode.ko, locale: Locale('ko')),
    _LanguageOption(code: _LanguageCode.zh, locale: Locale('zh')),
    _LanguageOption(code: _LanguageCode.hi, locale: Locale('hi')),
    _LanguageOption(code: _LanguageCode.es, locale: Locale('es')),
    _LanguageOption(code: _LanguageCode.pt, locale: Locale('pt')),
    _LanguageOption(code: _LanguageCode.fr, locale: Locale('fr')),
    _LanguageOption(code: _LanguageCode.de, locale: Locale('de')),
    _LanguageOption(code: _LanguageCode.it, locale: Locale('it')),
    _LanguageOption(code: _LanguageCode.tr, locale: Locale('tr')),
    _LanguageOption(code: _LanguageCode.ar, locale: Locale('ar')),
    _LanguageOption(code: _LanguageCode.ru, locale: Locale('ru')),
  ];
}

class Homepage extends StatefulWidget {
  const Homepage({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage>
    with SingleTickerProviderStateMixin {
  late HomeCubit _homeCubit;
  late final AnimationController _pulseController;
  bool _hasUsedMicrophone = false;
  _AppThemeMode _themeMode = _AppThemeMode.defaultMode;

  _ThemePalette get _theme => _ThemePalette.byMode(_themeMode);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _homeCubit = context.read<HomeCubit>();
    _homeCubit.initialize();
    _loadThemeMode();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadThemeMode() async {
    final themeName = await AppSettingsService.readThemeModeName();
    if (themeName == null) return;

    for (final mode in _AppThemeMode.values) {
      if (mode.name == themeName) {
        if (mounted) setState(() => _themeMode = mode);
        return;
      }
    }
  }

  Future<void> _saveThemeMode(_AppThemeMode mode) async {
    await AppSettingsService.saveThemeModeName(mode.name);
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext)!;

        return _bottomSheetFrame(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sheetHandle(),
              const SizedBox(height: 14),
              _sheetHeader(
                title: l10n.settings,
                onClose: () => Navigator.of(sheetContext).pop(),
              ),
              const SizedBox(height: 10),
              _settingsActionTile(
                icon: Icons.palette_rounded,
                title: l10n.theme,
                subtitle: l10n.selectedTheme(_themeLabel(_theme, l10n)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openThemeSheet();
                },
              ),
              const SizedBox(height: 10),
              _settingsActionTile(
                icon: Icons.language_rounded,
                title: l10n.language,
                subtitle: l10n.selectedLanguage(_currentLanguageName(l10n)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openLanguageSheet();
                },
              ),
              const SizedBox(height: 10),
              _settingsActionTile(
                icon: Icons.privacy_tip_rounded,
                title: l10n.privacyPolicyAndTerms,
                subtitle: l10n.privacyPolicyAndTermsSubtitle,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openLegalCenter();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openLegalCenter() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const _LegalCenterPage()));
  }

  void _openThemeSheet() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, sheetSetState) {
            final l10n = AppLocalizations.of(sheetContext)!;

            return _bottomSheetFrame(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sheetHandle(),
                  const SizedBox(height: 14),
                  _sheetHeader(
                    title: l10n.chooseThemeTitle,
                    leadingBack: true,
                    onClose: () => Navigator.of(sheetContext).pop(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _ThemePalette.all
                        .map(
                          (option) =>
                              _themeOptionChip(option, sheetSetState, l10n),
                        )
                        .toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openLanguageSheet() {
    Locale pendingLocale = widget.locale;
    final languageScrollController = ScrollController();

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, sheetSetState) {
            final l10n = AppLocalizations.of(sheetContext)!;

            return FractionallySizedBox(
              heightFactor: 0.92,
              child: _bottomSheetFrame(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sheetHeader(
                      title: l10n.chooseLanguageTitle,
                      leadingBack: true,
                      onClose: () => Navigator.of(sheetContext).pop(),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Scrollbar(
                        controller: languageScrollController,
                        thumbVisibility: true,
                        child: GridView.builder(
                          controller: languageScrollController,
                          padding: const EdgeInsets.only(right: 4, bottom: 4),
                          itemCount: _LanguageOption.all.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.7,
                              ),
                          itemBuilder: (context, index) {
                            final option = _LanguageOption.all[index];
                            final selected = _sameLocale(
                              pendingLocale,
                              option.locale,
                            );

                            return _languageOptionCard(
                              option: option,
                              selected: selected,
                              l10n: l10n,
                              onTap: () {
                                sheetSetState(() {
                                  pendingLocale = option.locale;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onLocaleChanged(pendingLocale);
                          Navigator.of(sheetContext).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _theme.danger,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          l10n.save,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(languageScrollController.dispose);
  }

  Widget _bottomSheetFrame({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(18, 12, 18, 20),
  }) {
    final theme = _theme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: theme.panel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.ink.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.isLight ? 0.12 : 0.38,
              ),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _sheetHandle() {
    final theme = _theme;

    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: theme.muted.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }

  Widget _sheetHeader({
    required String title,
    required VoidCallback onClose,
    bool leadingBack = false,
  }) {
    final theme = _theme;
    final l10n = AppLocalizations.of(context)!;

    if (!leadingBack) {
      return Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: theme.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.close,
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: theme.ink),
          ),
        ],
      );
    }

    return Row(
      children: [
        IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: onClose,
          icon: Icon(Icons.arrow_back_rounded, color: theme.ink),
        ),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: theme.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _settingsActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = _theme;

    return Material(
      color: theme.panelAlt,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [theme.primary, theme.secondary, theme.accent],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: theme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.muted, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeOptionChip(
    _ThemePalette option,
    StateSetter sheetSetState,
    AppLocalizations l10n,
  ) {
    final theme = _theme;
    final selected = option.mode == _themeMode;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (selected) return;

          setState(() => _themeMode = option.mode);
          sheetSetState(() {});
          _saveThemeMode(option.mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 126,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? theme.primary.withValues(alpha: theme.isLight ? 0.14 : 0.24)
                : theme.panelAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? theme.primary.withValues(alpha: 0.65)
                  : theme.ink.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            children: [
              _themeSwatch(option),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _themeLabel(option, l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? theme.ink : theme.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.primary,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeSwatch(_ThemePalette option) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [option.primary, option.secondary, option.accent],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _languageOptionCard({
    required _LanguageOption option,
    required bool selected,
    required AppLocalizations l10n,
    required VoidCallback onTap,
  }) {
    final theme = _theme;

    return Material(
      color: selected
          ? theme.primary.withValues(alpha: theme.isLight ? 0.12 : 0.2)
          : theme.panelAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? theme.danger
                  : theme.ink.withValues(alpha: theme.isLight ? 0.05 : 0.06),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: EdgeInsets.only(right: selected ? 14 : 0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _languageNativeName(option, l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.ink,
                          fontSize: 14,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _languageLocalName(option, l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.muted,
                          fontSize: 10,
                          height: 1.05,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: theme.danger,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _sameLocale(Locale a, Locale b) {
    return a.languageCode == b.languageCode && a.scriptCode == b.scriptCode;
  }

  String _currentLanguageName(AppLocalizations l10n) {
    final selected = _LanguageOption.all.firstWhere(
      (option) => _sameLocale(widget.locale, option.locale),
      orElse: () => _LanguageOption.all.first,
    );
    return _languageNativeName(selected, l10n);
  }

  String _themeLabel(_ThemePalette theme, AppLocalizations l10n) {
    switch (theme.mode) {
      case _AppThemeMode.defaultMode:
        return l10n.themeDefault;
      case _AppThemeMode.light:
        return l10n.themeLight;
      case _AppThemeMode.dark:
        return l10n.themeDark;
      case _AppThemeMode.red:
        return l10n.themeRed;
      case _AppThemeMode.green:
        return l10n.themeGreen;
      case _AppThemeMode.blue:
        return l10n.themeBlue;
      case _AppThemeMode.pink:
        return l10n.themePink;
    }
  }

  String _languageNativeName(_LanguageOption option, AppLocalizations l10n) {
    switch (option.code) {
      case _LanguageCode.en:
        return l10n.languageEnglishNative;
      case _LanguageCode.vi:
        return l10n.languageVietnameseNative;
      case _LanguageCode.id:
        return l10n.languageIndonesianNative;
      case _LanguageCode.th:
        return l10n.languageThaiNative;
      case _LanguageCode.ms:
        return l10n.languageMalayNative;
      case _LanguageCode.fil:
        return l10n.languageFilipinoNative;
      case _LanguageCode.ja:
        return l10n.languageJapaneseNative;
      case _LanguageCode.ko:
        return l10n.languageKoreanNative;
      case _LanguageCode.zh:
        return l10n.languageChineseNative;
      case _LanguageCode.hi:
        return l10n.languageHindiNative;
      case _LanguageCode.es:
        return l10n.languageSpanishNative;
      case _LanguageCode.pt:
        return l10n.languagePortugueseNative;
      case _LanguageCode.fr:
        return l10n.languageFrenchNative;
      case _LanguageCode.de:
        return l10n.languageGermanNative;
      case _LanguageCode.it:
        return l10n.languageItalianNative;
      case _LanguageCode.tr:
        return l10n.languageTurkishNative;
      case _LanguageCode.ar:
        return l10n.languageArabicNative;
      case _LanguageCode.ru:
        return l10n.languageRussianNative;
    }
  }

  String _languageLocalName(_LanguageOption option, AppLocalizations l10n) {
    switch (option.code) {
      case _LanguageCode.en:
        return l10n.languageEnglishLocal;
      case _LanguageCode.vi:
        return l10n.languageVietnameseLocal;
      case _LanguageCode.id:
        return l10n.languageIndonesianLocal;
      case _LanguageCode.th:
        return l10n.languageThaiLocal;
      case _LanguageCode.ms:
        return l10n.languageMalayLocal;
      case _LanguageCode.fil:
        return l10n.languageFilipinoLocal;
      case _LanguageCode.ja:
        return l10n.languageJapaneseLocal;
      case _LanguageCode.ko:
        return l10n.languageKoreanLocal;
      case _LanguageCode.zh:
        return l10n.languageChineseLocal;
      case _LanguageCode.hi:
        return l10n.languageHindiLocal;
      case _LanguageCode.es:
        return l10n.languageSpanishLocal;
      case _LanguageCode.pt:
        return l10n.languagePortugueseLocal;
      case _LanguageCode.fr:
        return l10n.languageFrenchLocal;
      case _LanguageCode.de:
        return l10n.languageGermanLocal;
      case _LanguageCode.it:
        return l10n.languageItalianLocal;
      case _LanguageCode.tr:
        return l10n.languageTurkishLocal;
      case _LanguageCode.ar:
        return l10n.languageArabicLocal;
      case _LanguageCode.ru:
        return l10n.languageRussianLocal;
    }
  }

  String _presetLabel(String preset, AppLocalizations l10n) {
    switch (preset) {
      case 'Flat':
        return l10n.presetFlat;
      case 'Rock':
        return l10n.presetRock;
      case 'Pop':
        return l10n.presetPop;
      case 'Jazz':
        return l10n.presetJazz;
      case 'Heavy Metal':
        return l10n.presetHeavyMetal;
      default:
        return preset;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        final cubit = context.read<HomeCubit>();

        return Scaffold(
          backgroundColor: theme.page,
          body: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return _AnimatedBackdrop(
                theme: theme,
                phase: _pulseController.value,
                child: child!,
              );
            },
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 430,
                          minHeight: math.max(0, constraints.maxHeight - 46),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Header(
                              theme: theme,
                              title: l10n.appTitle,
                              onSettingsTap: _openSettings,
                            ),
                            const SizedBox(height: 18),
                            _heroPanel(state, cubit),
                            const SizedBox(height: 16),
                            _modeSelector(state, cubit),
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
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _heroPanel(HomeState state, HomeCubit cubit) {
    final theme = _theme;
    final level = (state.volume * 100).clamp(0, 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: _heroDecoration(),
      child: Column(
        children: [
          _micStatusBadge(state),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (state.running ? theme.success : theme.primary).withValues(
                    alpha: theme.isLight ? 0.2 : 0.26,
                  ),
                  theme.panelAlt.withValues(alpha: theme.isLight ? 0.34 : 0.22),
                  Colors.transparent,
                ],
              ),
            ),
            child: _mainMicButton(state, cubit),
          ),
          const SizedBox(height: 20),
          Center(child: _volumeBars(state.volume, state.running)),
          const SizedBox(height: 14),
          _volumePill(state, level),
        ],
      ),
    );
  }

  Widget _micStatusBadge(HomeState state) {
    final theme = _theme;
    final color = state.starting
        ? theme.accent
        : state.running
        ? theme.success
        : (_hasUsedMicrophone ? theme.danger : theme.primary);

    return Align(
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: theme.isLight ? 0.13 : 0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.42)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: state.running ? 0.34 : 0.16),
              blurRadius: state.running ? 22 : 14,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_micStatusIcon(state), color: color, size: 15),
            const SizedBox(width: 8),
            Text(
              _micStatusLabel(state),
              style: TextStyle(
                color: theme.ink,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _micStatusIcon(HomeState state) {
    if (state.starting) return Icons.bolt_rounded;
    if (state.running) return Icons.hearing_rounded;
    if (_hasUsedMicrophone) return Icons.stop_circle_rounded;
    return Icons.radio_button_checked_rounded;
  }

  String _micStatusLabel(HomeState state) {
    if (state.starting) return 'STARTING';
    if (state.running) return 'LISTENING';
    return _hasUsedMicrophone ? 'STOPPED' : 'READY';
  }

  Widget _volumePill(HomeState state, String level) {
    final theme = _theme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: theme.panelAlt.withValues(alpha: theme.isLight ? 0.7 : 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.ink.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            state.running
                ? Icons.graphic_eq_rounded
                : Icons.radio_button_unchecked_rounded,
            color: state.running ? theme.success : theme.muted,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '$level%',
            style: TextStyle(
              color: theme.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainMicButton(HomeState state, HomeCubit cubit) {
    final theme = _theme;
    final l10n = AppLocalizations.of(context)!;
    final onTap = state.starting
        ? null
        : (state.running
              ? () {
                  setState(() => _hasUsedMicrophone = true);
                  cubit.stop();
                }
              : () {
                  setState(() => _hasUsedMicrophone = true);
                  cubit.start(
                    notificationTitle: l10n.notificationTitle,
                    notificationText: l10n.notificationText,
                    notificationStopButton: l10n.notificationStopButton,
                  );
                });

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final pulse = state.running ? _pulseController.value : 0.18;
        final activeColor = state.running ? theme.success : theme.primary;

        return SizedBox(
          width: 214,
          height: 214,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _PulseRing(
                color: activeColor,
                scale: 0.78 + pulse * 0.32,
                opacity: state.running ? (0.34 * (1 - pulse)) : 0.16,
                size: 202,
                strokeWidth: 2.4,
              ),
              _PulseRing(
                color: theme.accent,
                scale: 0.64 + pulse * 0.2,
                opacity: state.running ? (0.24 * (1 - pulse)) : 0.12,
                size: 182,
              ),
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.panel.withValues(
                    alpha: theme.isLight ? 0.7 : 0.34,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: theme.isLight ? 0.38 : 0.1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(
                        alpha: state.running ? 0.28 : 0.18,
                      ),
                      blurRadius: 36,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: theme.isLight ? 0.1 : 0.34,
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 144,
                  height: 144,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: state.running
                          ? [theme.danger, theme.secondary, theme.success]
                          : [theme.primary, theme.secondary, theme.accent],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primary.withValues(alpha: 0.48),
                        blurRadius: 34,
                        spreadRadius: 3,
                        offset: const Offset(0, 18),
                      ),
                      BoxShadow(
                        color: theme.accent.withValues(alpha: 0.28),
                        blurRadius: 42,
                        spreadRadius: 7,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        state.running
                            ? Icons.stop_rounded
                            : Icons.mic_none_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.starting
                            ? l10n.microphoneStarting
                            : (state.running
                                  ? l10n.stop
                                  : l10n.startMicrophone),
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
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _volumeBars(double volume, bool running) {
    final theme = _theme;
    final normalized = volume.clamp(0.0, 1.0);
    const maxHeights = [24.0, 38.0, 52.0, 64.0, 48.0, 36.0, 26.0];
    const idleHeights = [7.0, 10.0, 13.0, 16.0, 12.0, 9.0, 7.0];
    final colors = theme.visualizerColors;
    const rhythm = [0.45, 0.8, 0.62, 1.0, 0.74, 0.55, 0.9];

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.panel.withValues(alpha: theme.isLight ? 0.46 : 0.32),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.ink.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
            width: 7,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  colors[index].withValues(alpha: running ? 0.78 : 0.45),
                  colors[index],
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: colors[index].withValues(alpha: running ? 0.58 : 0.28),
                  blurRadius: running ? 18 : 10,
                  spreadRadius: running ? 1 : 0,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _modeSelector(HomeState state, HomeCubit cubit) {
    final theme = _theme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.panel.withValues(alpha: theme.isLight ? 0.72 : 0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.ink.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.isLight ? 0.08 : 0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          _controlDeckButton(
            icon: Icons.record_voice_over_rounded,
            label: l10n.voiceMode,
            selected: state.voiceMode,
            colorA: theme.primary,
            colorB: theme.secondary,
            onTap: () => cubit.setVoiceMode(!state.voiceMode),
          ),
          const SizedBox(height: 8),
          _controlDeckButton(
            icon: Icons.headset_mic_rounded,
            label: l10n.headsetMic,
            selected: state.preferWiredMic,
            colorA: theme.accent,
            colorB: theme.success,
            onTap: () => cubit.setPreferWiredMic(!state.preferWiredMic),
          ),
        ],
      ),
    );
  }

  Widget _controlDeckButton({
    required IconData icon,
    required String label,
    required bool selected,
    required Color colorA,
    required Color colorB,
    required VoidCallback onTap,
  }) {
    final theme = _theme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      height: 76,
      decoration: BoxDecoration(
        gradient: selected
            ? LinearGradient(
                colors: [colorA, colorB],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : LinearGradient(
                colors: [theme.panelAlt, theme.panel],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: selected
              ? Colors.white.withValues(alpha: 0.32)
              : theme.ink.withValues(alpha: 0.08),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.18)
                        : theme.panelAlt,
                    border: Border.all(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.3)
                          : theme.ink.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? Colors.white : theme.muted,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? Colors.white : theme.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected ? Colors.white : theme.muted,
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        blurRadius: 10,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            selected ? 'ON' : 'OFF',
                            style: TextStyle(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : theme.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.9)
                      : theme.muted.withValues(alpha: 0.62),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _equalizerPanel(HomeState state, HomeCubit cubit) {
    final theme = _theme;
    final l10n = AppLocalizations.of(context)!;
    final activeColor = state.eqEnabled ? theme.primary : theme.muted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: state.eqEnabled
                        ? [theme.primary, theme.secondary, theme.accent]
                        : [theme.panelAlt, theme.panel],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(
                        alpha: state.eqEnabled ? 0.32 : 0.08,
                      ),
                      blurRadius: state.eqEnabled ? 22 : 12,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: state.eqEnabled ? Colors.white : theme.muted,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.equalizer,
                      style: TextStyle(
                        color: theme.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'STUDIO PRESET',
                      style: TextStyle(
                        color: activeColor.withValues(alpha: 0.78),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              _eqStatePill(state.eqEnabled),
              const SizedBox(width: 8),
              Switch(
                value: state.eqEnabled,
                activeThumbColor: theme.primary,
                activeTrackColor: theme.primary.withValues(alpha: 0.38),
                inactiveThumbColor: theme.muted,
                inactiveTrackColor: theme.track,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => cubit.setEqEnabled(v),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _presetChips(state, cubit),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
            decoration: BoxDecoration(
              color: theme.panelAlt.withValues(
                alpha: theme.isLight ? 0.62 : 0.42,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.ink.withValues(alpha: 0.06)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _band(
                          '60Hz',
                          state.bassGain,
                          theme.visualizerColors[0],
                          (v) => cubit.setBassGain(v),
                          enabled: state.eqEnabled,
                        ),
                        _band(
                          '230Hz',
                          state.lowMidGain,
                          theme.visualizerColors[2],
                          (v) => cubit.setLowMidGain(v),
                          enabled: state.eqEnabled,
                        ),
                        _band(
                          '910Hz',
                          state.midGain,
                          theme.visualizerColors[3],
                          (v) => cubit.setMidGain(v),
                          enabled: state.eqEnabled,
                        ),
                        _band(
                          '3.6kHz',
                          state.highMidGain,
                          theme.visualizerColors[4],
                          (v) => cubit.setHighMidGain(v),
                          enabled: state.eqEnabled,
                        ),
                        _band(
                          '14kHz',
                          state.trebleGain,
                          theme.visualizerColors[6],
                          (v) => cubit.setTrebleGain(v),
                          enabled: state.eqEnabled,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _eqStatePill(bool enabled) {
    final theme = _theme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: (enabled ? theme.success : theme.panelAlt).withValues(
          alpha: enabled ? 0.18 : 0.72,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (enabled ? theme.success : theme.muted).withValues(
            alpha: 0.28,
          ),
        ),
      ),
      child: Text(
        enabled ? 'ON' : 'OFF',
        style: TextStyle(
          color: enabled ? theme.success : theme.muted,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _presetChips(HomeState state, HomeCubit cubit) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: cubit.presets.keys.map((name) {
          final selected = state.currentPreset == name;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _presetChip(
              label: _presetLabel(name, l10n),
              selected: selected,
              onTap: () => cubit.applyPreset(name),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _presetChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = _theme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        gradient: selected
            ? LinearGradient(
                colors: [theme.primary, theme.secondary],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: selected ? null : theme.panelAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? Colors.white.withValues(alpha: 0.24)
              : theme.ink.withValues(alpha: 0.07),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: theme.primary.withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : theme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _runningNotice() {
    final theme = _theme;
    final l10n = AppLocalizations.of(context)!;
    final textColor = theme.isLight ? const Color(0xFF064E3B) : theme.ink;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.success.withValues(alpha: theme.isLight ? 0.13 : 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: theme.success, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.runningInBackground,
              style: TextStyle(
                color: textColor,
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
    ValueChanged<double> onChanged, {
    required bool enabled,
  }) {
    final theme = _theme;
    final displayValue = (value * 100).round();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.48,
      child: SizedBox(
        width: 48,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$displayValue%',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: enabled ? color : theme.muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 128,
              width: 34,
              decoration: BoxDecoration(
                color: theme.panel.withValues(
                  alpha: theme.isLight ? 0.52 : 0.34,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.ink.withValues(alpha: 0.06)),
              ),
              child: RotatedBox(
                quarterTurns: -1,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 5,
                    activeTrackColor: enabled ? color : theme.muted,
                    inactiveTrackColor: theme.track.withValues(alpha: 0.74),
                    thumbColor: enabled
                        ? (theme.isLight ? theme.primary : Colors.white)
                        : theme.muted,
                    overlayColor: color.withValues(alpha: 0.18),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                      disabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: Slider(
                    value: value,
                    onChanged: enabled ? onChanged : null,
                    min: 0.5,
                    max: 1.5,
                    divisions: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _heroDecoration() {
    final theme = _theme;

    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          theme.panel.withValues(alpha: theme.isLight ? 0.78 : 0.72),
          theme.panelAlt.withValues(alpha: theme.isLight ? 0.7 : 0.58),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: theme.ink.withValues(alpha: 0.08)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: theme.isLight ? 0.12 : 0.28),
          blurRadius: 30,
          offset: const Offset(0, 18),
        ),
        BoxShadow(
          color: theme.primary.withValues(alpha: 0.16),
          blurRadius: 44,
          spreadRadius: 1,
        ),
      ],
    );
  }

  BoxDecoration _panelDecoration() {
    final theme = _theme;

    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          theme.panel.withValues(alpha: theme.isLight ? 0.82 : 0.76),
          theme.panelAlt.withValues(alpha: theme.isLight ? 0.72 : 0.54),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: theme.ink.withValues(alpha: 0.06)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: theme.isLight ? 0.08 : 0.26),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
        BoxShadow(color: theme.primary.withValues(alpha: 0.08), blurRadius: 30),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.theme,
    required this.title,
    required this.onSettingsTap,
  });

  final _ThemePalette theme;
  final String title;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.panel.withValues(alpha: theme.isLight ? 0.76 : 0.58),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.ink.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.isLight ? 0.08 : 0.2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [theme.primary, theme.secondary, theme.accent],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.primary.withValues(alpha: 0.34),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.ink,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Material(
            color: theme.panelAlt.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onSettingsTap,
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Icon(Icons.settings_rounded, color: theme.ink, size: 19),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedBackdrop extends StatelessWidget {
  const _AnimatedBackdrop({
    required this.theme,
    required this.phase,
    required this.child,
  });

  final _ThemePalette theme;
  final double phase;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wave = math.sin(phase * math.pi * 2);
    final counterWave = math.cos(phase * math.pi * 2);

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.page,
                  theme.panel.withValues(alpha: theme.isLight ? 0.62 : 0.9),
                  theme.page,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Positioned(
          top: -96 + wave * 18,
          left: -86 + counterWave * 20,
          child: _AuraBlob(
            size: 250,
            color: theme.primary,
            opacity: theme.isLight ? 0.18 : 0.24,
          ),
        ),
        Positioned(
          top: 170 + counterWave * 16,
          right: -110 + wave * 24,
          child: _AuraBlob(
            size: 230,
            color: theme.accent,
            opacity: theme.isLight ? 0.15 : 0.2,
          ),
        ),
        Positioned(
          bottom: -130 + wave * 20,
          left: 50 + counterWave * 18,
          child: _AuraBlob(
            size: 260,
            color: theme.secondary,
            opacity: theme.isLight ? 0.12 : 0.18,
          ),
        ),
        child,
      ],
    );
  }
}

class _AuraBlob extends StatelessWidget {
  const _AuraBlob({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({
    required this.color,
    required this.scale,
    required this.opacity,
    this.size = 168,
    this.strokeWidth = 2,
  });

  final Color color;
  final double scale;
  final double opacity;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: strokeWidth),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.32),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalDocument {
  const _LegalDocument({required this.title, this.url});

  final String title;
  final String? url;
}

class _LegalCenterPage extends StatelessWidget {
  const _LegalCenterPage();

  static const _ink = Color(0xFF251A2E);
  static const _divider = Color(0xFFEDEAF0);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final documents = [
      _LegalDocument(
        title: l10n.termsOfUse,
        url:
            'https://medlatec.vn/tin-tuc/lgbt-la-gi-va-cach-de-tu-bao-ve-suc-khoe-ban-than-cho-lgbt-s195-n18492',
      ),
      _LegalDocument(
        title: l10n.privacyPolicy,
        url: 'https://vi.wikipedia.org/wiki/T%E1%BB%B1_h%C3%A0o_LGBT',
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink, size: 26),
        ),
        titleSpacing: 0,
        title: Text(
          l10n.privacyPolicy,
          style: TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: _divider),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 26, 16, 24),
          itemCount: documents.length,
          separatorBuilder: (_, __) => const SizedBox(height: 30),
          itemBuilder: (context, index) {
            final document = documents[index];

            return _LegalLinkButton(
              title: document.title,
              onTap: document.url == null
                  ? null
                  : () => _openLegalWebView(context, document),
            );
          },
        ),
      ),
    );
  }

  static void _openLegalWebView(BuildContext context, _LegalDocument document) {
    final url = document.url;
    if (url == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LegalWebViewPage(title: document.title, url: url),
      ),
    );
  }
}

class _LegalLinkButton extends StatelessWidget {
  const _LegalLinkButton({required this.title, required this.onTap});

  final String title;
  final VoidCallback? onTap;

  static const _ink = Color(0xFF251A2E);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalWebViewPage extends StatefulWidget {
  const _LegalWebViewPage({required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<_LegalWebViewPage> createState() => _LegalWebViewPageState();
}

class _LegalWebViewPageState extends State<_LegalWebViewPage> {
  late final WebViewController _controller;

  static const _ink = Color(0xFF251A2E);
  static const _divider = Color(0xFFEDEAF0);

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink, size: 26),
        ),
        titleSpacing: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: _divider),
        ),
      ),
      body: SafeArea(top: false, child: WebViewWidget(controller: _controller)),
    );
  }
}
