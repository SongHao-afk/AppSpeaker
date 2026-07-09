// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Realtime Mic -> Speaker';

  @override
  String get settings => 'Настройки';

  @override
  String get close => 'Закрыть';

  @override
  String get theme => 'Тема';

  @override
  String get themeDescription => 'Изменить цвета приложения';

  @override
  String get chooseThemeTitle => 'Выберите тему';

  @override
  String selectedTheme(String theme) {
    return 'Выбрано: $theme';
  }

  @override
  String get language => 'Язык';

  @override
  String get languageDescription => 'Выберите язык интерфейса';

  @override
  String get chooseLanguageTitle => 'Выберите ваш язык';

  @override
  String selectedLanguage(String language) {
    return 'Выбрано: $language';
  }

  @override
  String get languageComingSoon => 'Этот язык будет добавлен позже';

  @override
  String get privacyPolicyAndTerms => 'Политика конфиденциальности и условия';

  @override
  String get privacyPolicyAndTermsSubtitle =>
      'Условия использования и политика конфиденциальности';

  @override
  String get termsOfUse => 'Условия использования';

  @override
  String get privacyPolicy => 'Политика конфиденциальности';

  @override
  String get save => 'Сохранить';

  @override
  String get themeDefault => 'По умолчанию';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeRed => 'Красная';

  @override
  String get themeGreen => 'Зелёная';

  @override
  String get themeBlue => 'Синяя';

  @override
  String get themePink => 'Розовая';

  @override
  String get microphoneStarting => 'ЗАПУСК';

  @override
  String get stop => 'СТОП';

  @override
  String get startMicrophone => 'СТАРТ';

  @override
  String get voiceMode => 'Голосовой режим';

  @override
  String get headsetMic => 'Микрофон гарнитуры';

  @override
  String get equalizer => 'Эквалайзер';

  @override
  String get runningInBackground =>
      'Работает в фоне - можно переключиться на другое приложение';

  @override
  String get presetFlat => 'Flat';

  @override
  String get presetRock => 'Rock';

  @override
  String get presetPop => 'Pop';

  @override
  String get presetJazz => 'Jazz';

  @override
  String get presetHeavyMetal => 'Heavy Metal';

  @override
  String get notificationTitle => 'Mic Loopback работает';

  @override
  String get notificationText => 'Аудио перенаправляется...';

  @override
  String get notificationStopButton => 'Стоп';

  @override
  String get languageEnglishNative => 'English';

  @override
  String get languageEnglishLocal => 'Английский';

  @override
  String get languageVietnameseNative => 'Tiếng Việt';

  @override
  String get languageVietnameseLocal => 'Вьетнамский';

  @override
  String get languageIndonesianNative => 'Indonesia';

  @override
  String get languageIndonesianLocal => 'Индонезийский';

  @override
  String get languageThaiNative => 'ภาษาไทย';

  @override
  String get languageThaiLocal => 'Тайский';

  @override
  String get languageMalayNative => 'Bahasa Melayu';

  @override
  String get languageMalayLocal => 'Малайский';

  @override
  String get languageFilipinoNative => 'Filipino';

  @override
  String get languageFilipinoLocal => 'Филиппинский';

  @override
  String get languageJapaneseNative => '日本語';

  @override
  String get languageJapaneseLocal => 'Японский';

  @override
  String get languageKoreanNative => '한국어';

  @override
  String get languageKoreanLocal => 'Корейский';

  @override
  String get languageChineseNative => '中文';

  @override
  String get languageChineseLocal => 'Китайский';

  @override
  String get languageHindiNative => 'हिन्दी';

  @override
  String get languageHindiLocal => 'Хинди';

  @override
  String get languageSpanishNative => 'Español';

  @override
  String get languageSpanishLocal => 'Испанский';

  @override
  String get languagePortugueseNative => 'Português';

  @override
  String get languagePortugueseLocal => 'Португальский';

  @override
  String get languageFrenchNative => 'Français';

  @override
  String get languageFrenchLocal => 'Французский';

  @override
  String get languageGermanNative => 'Deutsch';

  @override
  String get languageGermanLocal => 'Немецкий';

  @override
  String get languageItalianNative => 'Italiano';

  @override
  String get languageItalianLocal => 'Итальянский';

  @override
  String get languageTurkishNative => 'Türkçe';

  @override
  String get languageTurkishLocal => 'Турецкий';

  @override
  String get languageArabicNative => 'العربية';

  @override
  String get languageArabicLocal => 'Арабский';

  @override
  String get languageRussianNative => 'Русский';

  @override
  String get languageRussianLocal => 'Русский';
}
