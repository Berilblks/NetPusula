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
  /// **'Denemelerini takip et, gelişimini gör.'**
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

  /// No description provided for @prepWelcome.
  ///
  /// In tr, this message translates to:
  /// **'Şimdi hedefini birlikte belirleyelim.'**
  String get prepWelcome;

  /// No description provided for @prepWelcomeBody.
  ///
  /// In tr, this message translates to:
  /// **'Önce hazırlandığın sınavı seç. Hedefini ve sınav tarihini birlikte belirleyelim.'**
  String get prepWelcomeBody;

  /// No description provided for @prepExamTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hangi sınava hazırlanıyorsun?'**
  String get prepExamTitle;

  /// No description provided for @prepTargetTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hedef netin kaç?'**
  String get prepTargetTitle;

  /// No description provided for @prepTargetHint.
  ///
  /// In tr, this message translates to:
  /// **'Hedefini daha sonra değiştirebilirsin.'**
  String get prepTargetHint;

  /// No description provided for @prepDateTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sınav tarihin ne zaman?'**
  String get prepDateTitle;

  /// No description provided for @prepDateHint.
  ///
  /// In tr, this message translates to:
  /// **'Bu tarihi daha sonra değiştirebilirsin.'**
  String get prepDateHint;

  /// No description provided for @prepReviewTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hedefin hazır mı?'**
  String get prepReviewTitle;

  /// No description provided for @continueAction.
  ///
  /// In tr, this message translates to:
  /// **'Devam Et'**
  String get continueAction;

  /// No description provided for @backAction.
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get backAction;

  /// No description provided for @createGoalAction.
  ///
  /// In tr, this message translates to:
  /// **'Hedefimi Oluştur'**
  String get createGoalAction;

  /// No description provided for @editGoalAction.
  ///
  /// In tr, this message translates to:
  /// **'Hedefi Düzenle'**
  String get editGoalAction;

  /// No description provided for @saveGoalAction.
  ///
  /// In tr, this message translates to:
  /// **'Değişiklikleri Kaydet'**
  String get saveGoalAction;

  /// No description provided for @chooseDateAction.
  ///
  /// In tr, this message translates to:
  /// **'Tarih Seç'**
  String get chooseDateAction;

  /// No description provided for @targetNetLabel.
  ///
  /// In tr, this message translates to:
  /// **'Hedef net'**
  String get targetNetLabel;

  /// No description provided for @examLabel.
  ///
  /// In tr, this message translates to:
  /// **'Sınav'**
  String get examLabel;

  /// No description provided for @examDateLabel.
  ///
  /// In tr, this message translates to:
  /// **'Sınav tarihi'**
  String get examDateLabel;

  /// No description provided for @targetLabel.
  ///
  /// In tr, this message translates to:
  /// **'Hedefin'**
  String get targetLabel;

  /// No description provided for @prepLoading.
  ///
  /// In tr, this message translates to:
  /// **'Hedefin hazırlanıyor…'**
  String get prepLoading;

  /// No description provided for @examListEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Şu anda seçilebilecek bir sınav bulunmuyor. Daha sonra tekrar dene.'**
  String get examListEmpty;

  /// No description provided for @prepSaveError.
  ///
  /// In tr, this message translates to:
  /// **'Bilgiler kaydedilemedi. Lütfen tekrar dene.'**
  String get prepSaveError;

  /// No description provided for @prepLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Hedef bilgilerine ulaşılamadı. Lütfen tekrar dene.'**
  String get prepLoadError;

  /// No description provided for @prepNetwork.
  ///
  /// In tr, this message translates to:
  /// **'Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.'**
  String get prepNetwork;

  /// No description provided for @prepMissing.
  ///
  /// In tr, this message translates to:
  /// **'Sınav veya hazırlık artık kullanılamıyor. Bilgilerini yeniden kontrol et.'**
  String get prepMissing;

  /// No description provided for @prepConflict.
  ///
  /// In tr, this message translates to:
  /// **'Hazırlık bilgilerin değişmiş olabilir. Lütfen yeniden kontrol et.'**
  String get prepConflict;

  /// No description provided for @prepValidation.
  ///
  /// In tr, this message translates to:
  /// **'Bilgilerini kontrol edip tekrar dene.'**
  String get prepValidation;

  /// No description provided for @prepTargetInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Sıfırdan büyük, en fazla 8 tam ve 4 ondalık basamaklı bir net gir.'**
  String get prepTargetInvalid;

  /// No description provided for @prepDateInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Bugün veya gelecekte bir tarih seç. Sunucu Türkiye takvimini kullanır.'**
  String get prepDateInvalid;

  /// No description provided for @prepMaximum.
  ///
  /// In tr, this message translates to:
  /// **'Bu yapılandırmada en fazla {maximum} net.'**
  String prepMaximum(String maximum);

  /// No description provided for @prepStep.
  ///
  /// In tr, this message translates to:
  /// **'Adım {step} / 5'**
  String prepStep(int step);

  /// No description provided for @netValue.
  ///
  /// In tr, this message translates to:
  /// **'{net} net'**
  String netValue(String net);

  /// No description provided for @daysRemaining.
  ///
  /// In tr, this message translates to:
  /// **'{days} gün kaldı'**
  String daysRemaining(int days);

  /// No description provided for @examToday.
  ///
  /// In tr, this message translates to:
  /// **'Bugün'**
  String get examToday;

  /// No description provided for @examPassed.
  ///
  /// In tr, this message translates to:
  /// **'Sınav tarihi geçti'**
  String get examPassed;

  /// No description provided for @mockTrackingSoon.
  ///
  /// In tr, this message translates to:
  /// **'Deneme takibi yakında burada olacak.'**
  String get mockTrackingSoon;

  /// No description provided for @mockAdd.
  ///
  /// In tr, this message translates to:
  /// **'Deneme Ekle'**
  String get mockAdd;

  /// No description provided for @mockHistory.
  ///
  /// In tr, this message translates to:
  /// **'Deneme Geçmişi'**
  String get mockHistory;

  /// No description provided for @mockNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Deneme'**
  String get mockNew;

  /// No description provided for @mockName.
  ///
  /// In tr, this message translates to:
  /// **'Deneme adı'**
  String get mockName;

  /// No description provided for @mockNotes.
  ///
  /// In tr, this message translates to:
  /// **'Notlar (isteğe bağlı)'**
  String get mockNotes;

  /// No description provided for @mockDate.
  ///
  /// In tr, this message translates to:
  /// **'Deneme tarihi'**
  String get mockDate;

  /// No description provided for @mockNext.
  ///
  /// In tr, this message translates to:
  /// **'Devam Et'**
  String get mockNext;

  /// No description provided for @mockBack.
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get mockBack;

  /// No description provided for @mockCorrect.
  ///
  /// In tr, this message translates to:
  /// **'Doğru'**
  String get mockCorrect;

  /// No description provided for @mockWrong.
  ///
  /// In tr, this message translates to:
  /// **'Yanlış'**
  String get mockWrong;

  /// No description provided for @mockBlank.
  ///
  /// In tr, this message translates to:
  /// **'Boş'**
  String get mockBlank;

  /// No description provided for @mockReview.
  ///
  /// In tr, this message translates to:
  /// **'Kontrol'**
  String get mockReview;

  /// No description provided for @mockSave.
  ///
  /// In tr, this message translates to:
  /// **'Denemeyi Kaydet'**
  String get mockSave;

  /// No description provided for @mockSaved.
  ///
  /// In tr, this message translates to:
  /// **'Deneme kaydedildi'**
  String get mockSaved;

  /// No description provided for @mockTotal.
  ///
  /// In tr, this message translates to:
  /// **'Toplam Net'**
  String get mockTotal;

  /// No description provided for @mockToHistory.
  ///
  /// In tr, this message translates to:
  /// **'Deneme Geçmişine Git'**
  String get mockToHistory;

  /// No description provided for @mockHome.
  ///
  /// In tr, this message translates to:
  /// **'Ana Sayfaya Dön'**
  String get mockHome;

  /// No description provided for @mockEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz deneme eklemedin.'**
  String get mockEmpty;

  /// No description provided for @mockFirst.
  ///
  /// In tr, this message translates to:
  /// **'İlk Denemeni Ekle'**
  String get mockFirst;

  /// No description provided for @mockMore.
  ///
  /// In tr, this message translates to:
  /// **'Daha fazla yükle'**
  String get mockMore;

  /// No description provided for @mockRetry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar Dene'**
  String get mockRetry;

  /// No description provided for @mockEdit.
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get mockEdit;

  /// No description provided for @mockDelete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get mockDelete;

  /// No description provided for @mockCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get mockCancel;

  /// No description provided for @mockDeleteTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bu denemeyi silmek istediğine emin misin?'**
  String get mockDeleteTitle;

  /// No description provided for @mockDeleteBody.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilen deneme ve bölüm sonuçları kalıcı olarak kaldırılacak.'**
  String get mockDeleteBody;

  /// No description provided for @mockMissing.
  ///
  /// In tr, this message translates to:
  /// **'Deneme bulunamadı.'**
  String get mockMissing;

  /// No description provided for @mockNetwork.
  ///
  /// In tr, this message translates to:
  /// **'Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.'**
  String get mockNetwork;

  /// No description provided for @mockValidation.
  ///
  /// In tr, this message translates to:
  /// **'Adı, tarihi ve bölüm sayılarını kontrol et. Doğru ve yanlış toplamı soru sayısını aşamaz.'**
  String get mockValidation;

  /// No description provided for @mockSession.
  ///
  /// In tr, this message translates to:
  /// **'Oturumun sona erdi. Lütfen yeniden giriş yap.'**
  String get mockSession;

  /// No description provided for @mockConflict.
  ///
  /// In tr, this message translates to:
  /// **'Sınav yapılandırması kullanılamıyor veya değişti. Yeniden yükleyip tekrar dene.'**
  String get mockConflict;

  /// No description provided for @mockRateLimited.
  ///
  /// In tr, this message translates to:
  /// **'Çok fazla istek gönderdin. Biraz sonra tekrar dene.'**
  String get mockRateLimited;

  /// No description provided for @mockFailure.
  ///
  /// In tr, this message translates to:
  /// **'İşlem tamamlanamadı. Lütfen tekrar dene.'**
  String get mockFailure;

  /// No description provided for @mockNoPreparation.
  ///
  /// In tr, this message translates to:
  /// **'Devam etmek için aktif hazırlık oluşturmalısın.'**
  String get mockNoPreparation;

  /// No description provided for @mockPreparationAction.
  ///
  /// In tr, this message translates to:
  /// **'Hazırlığı Kontrol Et'**
  String get mockPreparationAction;

  /// No description provided for @mockNoSections.
  ///
  /// In tr, this message translates to:
  /// **'Bu sınav için henüz bölüm yapılandırılmamış. Daha sonra tekrar dene.'**
  String get mockNoSections;

  /// No description provided for @mockQuestions.
  ///
  /// In tr, this message translates to:
  /// **'soru'**
  String get mockQuestions;

  /// No description provided for @mockNet.
  ///
  /// In tr, this message translates to:
  /// **'net'**
  String get mockNet;

  /// No description provided for @mockSections.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm sonuçları'**
  String get mockSections;

  /// No description provided for @dashboardLatest.
  ///
  /// In tr, this message translates to:
  /// **'Son Net'**
  String get dashboardLatest;

  /// No description provided for @dashboardAverage.
  ///
  /// In tr, this message translates to:
  /// **'Ortalama'**
  String get dashboardAverage;

  /// No description provided for @dashboardBest.
  ///
  /// In tr, this message translates to:
  /// **'En Yüksek'**
  String get dashboardBest;

  /// No description provided for @dashboardRemaining.
  ///
  /// In tr, this message translates to:
  /// **'Hedefe Kalan'**
  String get dashboardRemaining;

  /// No description provided for @dashboardReached.
  ///
  /// In tr, this message translates to:
  /// **'Hedefe ulaştın'**
  String get dashboardReached;

  /// No description provided for @dashboardAbove.
  ///
  /// In tr, this message translates to:
  /// **'Hedefin üzerinde'**
  String get dashboardAbove;

  /// No description provided for @dashboardTrend.
  ///
  /// In tr, this message translates to:
  /// **'Net Gelişimi'**
  String get dashboardTrend;

  /// No description provided for @dashboardSections.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm Performansı'**
  String get dashboardSections;

  /// No description provided for @dashboardRecent.
  ///
  /// In tr, this message translates to:
  /// **'Son Denemeler'**
  String get dashboardRecent;

  /// No description provided for @dashboardNoData.
  ///
  /// In tr, this message translates to:
  /// **'Henüz veri yok'**
  String get dashboardNoData;

  /// No description provided for @dashboardInsufficient.
  ///
  /// In tr, this message translates to:
  /// **'Gelişim karşılaştırması için en az 6 deneme gerekli.'**
  String get dashboardInsufficient;

  /// No description provided for @dashboardChartHint.
  ///
  /// In tr, this message translates to:
  /// **'Noktalar deneme sırasındadır; kesikli çizgi hedef neti gösterir.'**
  String get dashboardChartHint;

  /// No description provided for @dashboardRefresh.
  ///
  /// In tr, this message translates to:
  /// **'Yenile'**
  String get dashboardRefresh;

  /// No description provided for @dashboardRetired.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş bölüm'**
  String get dashboardRetired;

  /// No description provided for @dashboardCount.
  ///
  /// In tr, this message translates to:
  /// **'Deneme sayısı'**
  String get dashboardCount;

  /// No description provided for @dashboardChange.
  ///
  /// In tr, this message translates to:
  /// **'Son 3 deneme ortalaman önceki 3 denemeye göre {change} net.'**
  String dashboardChange(String change);

  /// No description provided for @statisticsTitle.
  ///
  /// In tr, this message translates to:
  /// **'İstatistikler'**
  String get statisticsTitle;

  /// No description provided for @statisticsEntry.
  ///
  /// In tr, this message translates to:
  /// **'Detaylı İstatistikler'**
  String get statisticsEntry;

  /// No description provided for @statisticsAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get statisticsAll;

  /// No description provided for @statisticsLast.
  ///
  /// In tr, this message translates to:
  /// **'Son {count}'**
  String statisticsLast(String count);

  /// No description provided for @statisticsWorst.
  ///
  /// In tr, this message translates to:
  /// **'En Düşük'**
  String get statisticsWorst;

  /// No description provided for @statisticsInsufficient.
  ///
  /// In tr, this message translates to:
  /// **'Karşılaştırma için en az 6 deneme gerekli.'**
  String get statisticsInsufficient;

  /// No description provided for @statisticsEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz istatistik oluşturacak denemen yok.'**
  String get statisticsEmpty;

  /// No description provided for @statisticsSectionEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Bu bölüm için henüz veri yok.'**
  String get statisticsSectionEmpty;

  /// No description provided for @statisticsOverview.
  ///
  /// In tr, this message translates to:
  /// **'Genel Bakış'**
  String get statisticsOverview;

  /// No description provided for @statisticsBestMock.
  ///
  /// In tr, this message translates to:
  /// **'En İyi Deneme'**
  String get statisticsBestMock;

  /// No description provided for @statisticsSections.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm Analizi'**
  String get statisticsSections;

  /// No description provided for @statisticsAnswers.
  ///
  /// In tr, this message translates to:
  /// **'Cevap Dağılımı'**
  String get statisticsAnswers;

  /// No description provided for @statisticsCorrect.
  ///
  /// In tr, this message translates to:
  /// **'Ortalama Doğru'**
  String get statisticsCorrect;

  /// No description provided for @statisticsWrong.
  ///
  /// In tr, this message translates to:
  /// **'Ortalama Yanlış'**
  String get statisticsWrong;

  /// No description provided for @statisticsBlank.
  ///
  /// In tr, this message translates to:
  /// **'Ortalama Boş'**
  String get statisticsBlank;

  /// No description provided for @statisticsActivity.
  ///
  /// In tr, this message translates to:
  /// **'Deneme Düzeni'**
  String get statisticsActivity;

  /// No description provided for @statisticsFirst.
  ///
  /// In tr, this message translates to:
  /// **'İlk deneme'**
  String get statisticsFirst;

  /// No description provided for @statisticsLatestDate.
  ///
  /// In tr, this message translates to:
  /// **'Son deneme'**
  String get statisticsLatestDate;

  /// No description provided for @statisticsInterval.
  ///
  /// In tr, this message translates to:
  /// **'Ortalama gün aralığı'**
  String get statisticsInterval;

  /// No description provided for @statisticsActivityHint.
  ///
  /// In tr, this message translates to:
  /// **'Seçili denemeler arasındaki takvim günü aralığıdır. Aynı gün yapılan denemeler sıfır gün aralıkla hesaba katılır.'**
  String get statisticsActivityHint;

  /// No description provided for @statisticsAnswerHistory.
  ///
  /// In tr, this message translates to:
  /// **'Denemelere göre doğru / yanlış / boş'**
  String get statisticsAnswerHistory;

  /// No description provided for @statisticsChartHint.
  ///
  /// In tr, this message translates to:
  /// **'Noktalar deneme sırasındadır; zaman aralıkları eşit olmayabilir.'**
  String get statisticsChartHint;

  /// No description provided for @statisticsCap.
  ///
  /// In tr, this message translates to:
  /// **'Tümü görünümü son {limit} denemeyi içeriyor. Toplam {available} denemen var.'**
  String statisticsCap(int limit, int available);

  /// No description provided for @prepJourney.
  ///
  /// In tr, this message translates to:
  /// **'Sınavını, hedefini ve tarihini belirle.'**
  String get prepJourney;

  /// No description provided for @mockStep.
  ///
  /// In tr, this message translates to:
  /// **'Adım {step} / 3'**
  String mockStep(int step);

  /// No description provided for @mockCountsInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Doğru ve yanlış toplamı {maximum} soruyu aşamaz.'**
  String mockCountsInvalid(int maximum);

  /// No description provided for @mockDeleted.
  ///
  /// In tr, this message translates to:
  /// **'Deneme silindi.'**
  String get mockDeleted;

  /// No description provided for @mockUpdated.
  ///
  /// In tr, this message translates to:
  /// **'Değişiklikler kaydedildi.'**
  String get mockUpdated;

  /// No description provided for @chartSinglePoint.
  ///
  /// In tr, this message translates to:
  /// **'Henüz tek deneme var; gelişim çizgisi sonraki denemelerle oluşacak.'**
  String get chartSinglePoint;

  /// No description provided for @homeEncouragement.
  ///
  /// In tr, this message translates to:
  /// **'Bugün de hedeflerine bir adım daha yaklaş!'**
  String get homeEncouragement;

  /// No description provided for @homeNavHome.
  ///
  /// In tr, this message translates to:
  /// **'Ana Sayfa'**
  String get homeNavHome;

  /// No description provided for @homeNavMocks.
  ///
  /// In tr, this message translates to:
  /// **'Denemeler'**
  String get homeNavMocks;

  /// No description provided for @homeNavAdd.
  ///
  /// In tr, this message translates to:
  /// **'Ekle'**
  String get homeNavAdd;

  /// No description provided for @homeNavGoal.
  ///
  /// In tr, this message translates to:
  /// **'Hedef'**
  String get homeNavGoal;

  /// No description provided for @homeNavStatistics.
  ///
  /// In tr, this message translates to:
  /// **'İstatistik'**
  String get homeNavStatistics;

  /// No description provided for @homeRecentTrend.
  ///
  /// In tr, this message translates to:
  /// **'Son denemelerin'**
  String get homeRecentTrend;

  /// No description provided for @homeNetChange.
  ///
  /// In tr, this message translates to:
  /// **'Net değişimi'**
  String get homeNetChange;
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
