import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_tr.dart';

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('tr')
  ];

  /// No description provided for @welcomeTagline.
  ///
  /// In tr, this message translates to:
  /// **'Hedefine giden yolu netlerinle keşfet.'**
  String get welcomeTagline;

  /// No description provided for @loginAction.
  ///
  /// In tr, this message translates to:
  /// **'Giriş Yap'**
  String get loginAction;

  /// No description provided for @registerAction.
  ///
  /// In tr, this message translates to:
  /// **'Hesap Oluştur'**
  String get registerAction;

  /// No description provided for @logoutAction.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış Yap'**
  String get logoutAction;

  /// No description provided for @loginTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar hoş geldin'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Hedefine kaldığın yerden devam et.'**
  String get loginSubtitle;

  /// No description provided for @registerTitle.
  ///
  /// In tr, this message translates to:
  /// **'İlk adımı at'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesabını oluştur, yolculuğuna başla.'**
  String get registerSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In tr, this message translates to:
  /// **'E-posta'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In tr, this message translates to:
  /// **'Şifre'**
  String get passwordLabel;

  /// No description provided for @nameLabel.
  ///
  /// In tr, this message translates to:
  /// **'Ad / Görünen Ad'**
  String get nameLabel;

  /// No description provided for @passwordConfirmation.
  ///
  /// In tr, this message translates to:
  /// **'Şifre Tekrar'**
  String get passwordConfirmation;

  /// No description provided for @showPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi göster'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi gizle'**
  String get hidePassword;

  /// No description provided for @noAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın yok mu? Hesap Oluştur'**
  String get noAccount;

  /// No description provided for @haveAccount.
  ///
  /// In tr, this message translates to:
  /// **'Zaten hesabın var mı? Giriş Yap'**
  String get haveAccount;

  /// No description provided for @requiredField.
  ///
  /// In tr, this message translates to:
  /// **'Bu alanı doldur.'**
  String get requiredField;

  /// No description provided for @emailInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir e-posta adresi gir.'**
  String get emailInvalid;

  /// No description provided for @nameInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Adın 2–120 karakter olmalı.'**
  String get nameInvalid;

  /// No description provided for @passwordPolicy.
  ///
  /// In tr, this message translates to:
  /// **'Şifren 8–128 karakter olmalı; en az bir harf ve bir rakam içermeli.'**
  String get passwordPolicy;

  /// No description provided for @passwordHint.
  ///
  /// In tr, this message translates to:
  /// **'En az 8 karakter, bir harf ve bir rakam.'**
  String get passwordHint;

  /// No description provided for @passwordMismatch.
  ///
  /// In tr, this message translates to:
  /// **'Şifreler eşleşmiyor.'**
  String get passwordMismatch;

  /// No description provided for @invalidCredentials.
  ///
  /// In tr, this message translates to:
  /// **'E-posta veya şifre hatalı.'**
  String get invalidCredentials;

  /// No description provided for @validationError.
  ///
  /// In tr, this message translates to:
  /// **'Bilgilerini kontrol edip tekrar dene.'**
  String get validationError;

  /// No description provided for @duplicateEmail.
  ///
  /// In tr, this message translates to:
  /// **'Bu e-posta adresiyle zaten bir hesap var. Giriş yapabilirsin.'**
  String get duplicateEmail;

  /// No description provided for @rateLimited.
  ///
  /// In tr, this message translates to:
  /// **'Çok fazla deneme yaptın. Lütfen biraz bekleyip tekrar dene.'**
  String get rateLimited;

  /// No description provided for @networkError.
  ///
  /// In tr, this message translates to:
  /// **'Sunucuya ulaşılamadı. İnternet bağlantını kontrol edip tekrar dene.'**
  String get networkError;

  /// No description provided for @unexpectedError.
  ///
  /// In tr, this message translates to:
  /// **'Bir hata oluştu. Lütfen tekrar dene.'**
  String get unexpectedError;

  /// No description provided for @sessionExpired.
  ///
  /// In tr, this message translates to:
  /// **'Oturumun sona erdi. Lütfen yeniden giriş yap.'**
  String get sessionExpired;

  /// No description provided for @storageError.
  ///
  /// In tr, this message translates to:
  /// **'Güvenli oturum bilgilerine erişilemedi. Cihazının kilidini açıp tekrar dene.'**
  String get storageError;

  /// No description provided for @configurationError.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama şu anda bağlantı kuramıyor. Lütfen daha sonra tekrar dene.'**
  String get configurationError;

  /// No description provided for @localLogout.
  ///
  /// In tr, this message translates to:
  /// **'Bu cihazdan çıkış yaptın. Sunucuya ulaşılamadığı için oturum sunucuda açık kalmış olabilir.'**
  String get localLogout;

  /// No description provided for @pleaseWait.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen bekle'**
  String get pleaseWait;

  /// No description provided for @startupMessage.
  ///
  /// In tr, this message translates to:
  /// **'Senin için hazırlanıyoruz…'**
  String get startupMessage;

  /// No description provided for @retryAction.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar Dene'**
  String get retryAction;

  /// No description provided for @localSignOutAction.
  ///
  /// In tr, this message translates to:
  /// **'Bu cihazdan çıkış yap'**
  String get localSignOutAction;

  /// No description provided for @homeGreeting.
  ///
  /// In tr, this message translates to:
  /// **'Merhaba, {displayName}'**
  String homeGreeting(String displayName);

  /// No description provided for @homeWelcome.
  ///
  /// In tr, this message translates to:
  /// **'NetPusula’ya hoş geldin.'**
  String get homeWelcome;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'tr': return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
