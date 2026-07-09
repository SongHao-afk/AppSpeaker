import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fil.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_ms.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_th.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fil'),
    Locale('fr'),
    Locale('hi'),
    Locale('id'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('ms'),
    Locale('pt'),
    Locale('ru'),
    Locale('th'),
    Locale('tr'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Realtime Mic -> Speaker'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeDescription.
  ///
  /// In en, this message translates to:
  /// **'Change the app colors'**
  String get themeDescription;

  /// No description provided for @chooseThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose theme'**
  String get chooseThemeTitle;

  /// No description provided for @selectedTheme.
  ///
  /// In en, this message translates to:
  /// **'Selected: {theme}'**
  String selectedTheme(String theme);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the display language'**
  String get languageDescription;

  /// No description provided for @chooseLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguageTitle;

  /// No description provided for @selectedLanguage.
  ///
  /// In en, this message translates to:
  /// **'Selected: {language}'**
  String selectedLanguage(String language);

  /// No description provided for @languageComingSoon.
  ///
  /// In en, this message translates to:
  /// **'This language will be added later'**
  String get languageComingSoon;

  /// No description provided for @privacyPolicyAndTerms.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy & Terms'**
  String get privacyPolicyAndTerms;

  /// No description provided for @privacyPolicyAndTermsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use and Privacy Policy'**
  String get privacyPolicyAndTermsSubtitle;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @themeDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get themeDefault;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get themeRed;

  /// No description provided for @themeGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get themeGreen;

  /// No description provided for @themeBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get themeBlue;

  /// No description provided for @themePink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get themePink;

  /// No description provided for @microphoneStarting.
  ///
  /// In en, this message translates to:
  /// **'STARTING'**
  String get microphoneStarting;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'STOP'**
  String get stop;

  /// No description provided for @startMicrophone.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get startMicrophone;

  /// No description provided for @voiceMode.
  ///
  /// In en, this message translates to:
  /// **'Voice mode'**
  String get voiceMode;

  /// No description provided for @headsetMic.
  ///
  /// In en, this message translates to:
  /// **'Headset mic'**
  String get headsetMic;

  /// No description provided for @equalizer.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get equalizer;

  /// No description provided for @runningInBackground.
  ///
  /// In en, this message translates to:
  /// **'Running in background - you can switch to another app'**
  String get runningInBackground;

  /// No description provided for @presetFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get presetFlat;

  /// No description provided for @presetRock.
  ///
  /// In en, this message translates to:
  /// **'Rock'**
  String get presetRock;

  /// No description provided for @presetPop.
  ///
  /// In en, this message translates to:
  /// **'Pop'**
  String get presetPop;

  /// No description provided for @presetJazz.
  ///
  /// In en, this message translates to:
  /// **'Jazz'**
  String get presetJazz;

  /// No description provided for @presetHeavyMetal.
  ///
  /// In en, this message translates to:
  /// **'Heavy Metal'**
  String get presetHeavyMetal;

  /// No description provided for @notificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Mic Loopback is running'**
  String get notificationTitle;

  /// No description provided for @notificationText.
  ///
  /// In en, this message translates to:
  /// **'Audio is being routed...'**
  String get notificationText;

  /// No description provided for @notificationStopButton.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get notificationStopButton;

  /// No description provided for @languageEnglishNative.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglishNative;

  /// No description provided for @languageEnglishLocal.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglishLocal;

  /// No description provided for @languageVietnameseNative.
  ///
  /// In en, this message translates to:
  /// **'Tiếng Việt'**
  String get languageVietnameseNative;

  /// No description provided for @languageVietnameseLocal.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get languageVietnameseLocal;

  /// No description provided for @languageIndonesianNative.
  ///
  /// In en, this message translates to:
  /// **'Indonesia'**
  String get languageIndonesianNative;

  /// No description provided for @languageIndonesianLocal.
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get languageIndonesianLocal;

  /// No description provided for @languageThaiNative.
  ///
  /// In en, this message translates to:
  /// **'ภาษาไทย'**
  String get languageThaiNative;

  /// No description provided for @languageThaiLocal.
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get languageThaiLocal;

  /// No description provided for @languageMalayNative.
  ///
  /// In en, this message translates to:
  /// **'Bahasa Melayu'**
  String get languageMalayNative;

  /// No description provided for @languageMalayLocal.
  ///
  /// In en, this message translates to:
  /// **'Malay'**
  String get languageMalayLocal;

  /// No description provided for @languageFilipinoNative.
  ///
  /// In en, this message translates to:
  /// **'Filipino'**
  String get languageFilipinoNative;

  /// No description provided for @languageFilipinoLocal.
  ///
  /// In en, this message translates to:
  /// **'Filipino'**
  String get languageFilipinoLocal;

  /// No description provided for @languageJapaneseNative.
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get languageJapaneseNative;

  /// No description provided for @languageJapaneseLocal.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageJapaneseLocal;

  /// No description provided for @languageKoreanNative.
  ///
  /// In en, this message translates to:
  /// **'한국어'**
  String get languageKoreanNative;

  /// No description provided for @languageKoreanLocal.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get languageKoreanLocal;

  /// No description provided for @languageChineseNative.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageChineseNative;

  /// No description provided for @languageChineseLocal.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageChineseLocal;

  /// No description provided for @languageHindiNative.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get languageHindiNative;

  /// No description provided for @languageHindiLocal.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get languageHindiLocal;

  /// No description provided for @languageSpanishNative.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get languageSpanishNative;

  /// No description provided for @languageSpanishLocal.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanishLocal;

  /// No description provided for @languagePortugueseNative.
  ///
  /// In en, this message translates to:
  /// **'Português'**
  String get languagePortugueseNative;

  /// No description provided for @languagePortugueseLocal.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get languagePortugueseLocal;

  /// No description provided for @languageFrenchNative.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFrenchNative;

  /// No description provided for @languageFrenchLocal.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrenchLocal;

  /// No description provided for @languageGermanNative.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGermanNative;

  /// No description provided for @languageGermanLocal.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGermanLocal;

  /// No description provided for @languageItalianNative.
  ///
  /// In en, this message translates to:
  /// **'Italiano'**
  String get languageItalianNative;

  /// No description provided for @languageItalianLocal.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get languageItalianLocal;

  /// No description provided for @languageTurkishNative.
  ///
  /// In en, this message translates to:
  /// **'Türkçe'**
  String get languageTurkishNative;

  /// No description provided for @languageTurkishLocal.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get languageTurkishLocal;

  /// No description provided for @languageArabicNative.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabicNative;

  /// No description provided for @languageArabicLocal.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabicLocal;

  /// No description provided for @languageRussianNative.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussianNative;

  /// No description provided for @languageRussianLocal.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussianLocal;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fil',
    'fr',
    'hi',
    'id',
    'it',
    'ja',
    'ko',
    'ms',
    'pt',
    'ru',
    'th',
    'tr',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fil':
      return AppLocalizationsFil();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'ms':
      return AppLocalizationsMs();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'th':
      return AppLocalizationsTh();
    case 'tr':
      return AppLocalizationsTr();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
