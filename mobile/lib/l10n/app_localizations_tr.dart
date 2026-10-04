// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get welcomeTagline => 'Hedefine giden yolu netlerinle keşfet.';

  @override
  String get loginAction => 'Giriş Yap';

  @override
  String get registerAction => 'Hesap Oluştur';

  @override
  String get logoutAction => 'Çıkış Yap';

  @override
  String get loginTitle => 'Tekrar hoş geldin';

  @override
  String get loginSubtitle => 'Hedefine kaldığın yerden devam et.';

  @override
  String get registerTitle => 'İlk adımı at';

  @override
  String get registerSubtitle => 'Hesabını oluştur, yolculuğuna başla.';

  @override
  String get emailLabel => 'E-posta';

  @override
  String get passwordLabel => 'Şifre';

  @override
  String get nameLabel => 'Ad / Görünen Ad';

  @override
  String get passwordConfirmation => 'Şifre Tekrar';

  @override
  String get showPassword => 'Şifreyi göster';

  @override
  String get hidePassword => 'Şifreyi gizle';

  @override
  String get noAccount => 'Hesabın yok mu? Hesap Oluştur';

  @override
  String get haveAccount => 'Zaten hesabın var mı? Giriş Yap';

  @override
  String get requiredField => 'Bu alanı doldur.';

  @override
  String get emailInvalid => 'Geçerli bir e-posta adresi gir.';

  @override
  String get nameInvalid => 'Adın 2–120 karakter olmalı.';

  @override
  String get passwordPolicy => 'Şifren 8–128 karakter olmalı; en az bir harf ve bir rakam içermeli.';

  @override
  String get passwordHint => 'En az 8 karakter, bir harf ve bir rakam.';

  @override
  String get passwordMismatch => 'Şifreler eşleşmiyor.';

  @override
  String get invalidCredentials => 'E-posta veya şifre hatalı.';

  @override
  String get validationError => 'Bilgilerini kontrol edip tekrar dene.';

  @override
  String get duplicateEmail => 'Bu e-posta adresiyle zaten bir hesap var. Giriş yapabilirsin.';

  @override
  String get rateLimited => 'Çok fazla deneme yaptın. Lütfen biraz bekleyip tekrar dene.';

  @override
  String get networkError => 'Sunucuya ulaşılamadı. İnternet bağlantını kontrol edip tekrar dene.';

  @override
  String get unexpectedError => 'Bir hata oluştu. Lütfen tekrar dene.';

  @override
  String get sessionExpired => 'Oturumun sona erdi. Lütfen yeniden giriş yap.';

  @override
  String get storageError => 'Güvenli oturum bilgilerine erişilemedi. Cihazının kilidini açıp tekrar dene.';

  @override
  String get configurationError => 'Uygulama şu anda bağlantı kuramıyor. Lütfen daha sonra tekrar dene.';

  @override
  String get localLogout => 'Bu cihazdan çıkış yaptın. Sunucuya ulaşılamadığı için oturum sunucuda açık kalmış olabilir.';

  @override
  String get pleaseWait => 'Lütfen bekle';

  @override
  String get startupMessage => 'Senin için hazırlanıyoruz…';

  @override
  String get retryAction => 'Tekrar Dene';

  @override
  String get localSignOutAction => 'Bu cihazdan çıkış yap';

  @override
  String homeGreeting(String displayName) {
    return 'Merhaba, $displayName';
  }

  @override
  String get homeWelcome => 'NetPusula’ya hoş geldin.';

  @override
  String get prepWelcome => 'Şimdi hedefini birlikte belirleyelim.';

  @override
  String get prepWelcomeBody => 'Önce hazırlandığın sınavı seç. Hedefini ve sınav tarihini birlikte belirleyelim.';

  @override
  String get prepExamTitle => 'Hangi sınava hazırlanıyorsun?';

  @override
  String get prepTargetTitle => 'Hedef netin kaç?';

  @override
  String get prepTargetHint => 'Hedefini daha sonra değiştirebilirsin.';

  @override
  String get prepDateTitle => 'Sınav tarihin ne zaman?';

  @override
  String get prepDateHint => 'Bu tarihi daha sonra değiştirebilirsin.';

  @override
  String get prepReviewTitle => 'Hedefin hazır mı?';

  @override
  String get continueAction => 'Devam Et';

  @override
  String get backAction => 'Geri';

  @override
  String get createGoalAction => 'Hedefimi Oluştur';

  @override
  String get editGoalAction => 'Hedefi Düzenle';

  @override
  String get saveGoalAction => 'Değişiklikleri Kaydet';

  @override
  String get chooseDateAction => 'Tarih Seç';

  @override
  String get targetNetLabel => 'Hedef net';

  @override
  String get examLabel => 'Sınav';

  @override
  String get examDateLabel => 'Sınav tarihi';

  @override
  String get targetLabel => 'Hedefin';

  @override
  String get prepLoading => 'Hedefin hazırlanıyor…';

  @override
  String get examListEmpty => 'Şu anda seçilebilecek bir sınav bulunmuyor. Daha sonra tekrar dene.';

  @override
  String get prepSaveError => 'Bilgiler kaydedilemedi. Lütfen tekrar dene.';

  @override
  String get prepLoadError => 'Hedef bilgilerine ulaşılamadı. Lütfen tekrar dene.';

  @override
  String get prepNetwork => 'Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.';

  @override
  String get prepMissing => 'Sınav veya hazırlık artık kullanılamıyor. Bilgilerini yeniden kontrol et.';

  @override
  String get prepConflict => 'Hazırlık bilgilerin değişmiş olabilir. Lütfen yeniden kontrol et.';

  @override
  String get prepValidation => 'Bilgilerini kontrol edip tekrar dene.';

  @override
  String get prepTargetInvalid => 'Sıfırdan büyük, en fazla 8 tam ve 4 ondalık basamaklı bir net gir.';

  @override
  String get prepDateInvalid => 'Bugün veya gelecekte bir tarih seç. Sunucu Türkiye takvimini kullanır.';

  @override
  String prepMaximum(String maximum) {
    return 'Bu yapılandırmada en fazla $maximum net.';
  }

  @override
  String prepStep(int step) {
    return 'Adım $step / 5';
  }

  @override
  String netValue(String net) {
    return '$net net';
  }

  @override
  String daysRemaining(int days) {
    return '$days gün kaldı';
  }

  @override
  String get examToday => 'Bugün';

  @override
  String get examPassed => 'Sınav tarihi geçti';

  @override
  String get mockTrackingSoon => 'Deneme takibi yakında burada olacak.';

  @override
  String get mockAdd => 'Deneme Ekle';

  @override
  String get mockHistory => 'Deneme Geçmişi';

  @override
  String get mockNew => 'Yeni Deneme';

  @override
  String get mockName => 'Deneme adı';

  @override
  String get mockNotes => 'Notlar (isteğe bağlı)';

  @override
  String get mockDate => 'Deneme tarihi';

  @override
  String get mockNext => 'Devam Et';

  @override
  String get mockBack => 'Geri';

  @override
  String get mockCorrect => 'Doğru';

  @override
  String get mockWrong => 'Yanlış';

  @override
  String get mockBlank => 'Boş';

  @override
  String get mockReview => 'Kontrol';

  @override
  String get mockSave => 'Denemeyi Kaydet';

  @override
  String get mockSaved => 'Deneme kaydedildi';

  @override
  String get mockTotal => 'Toplam Net';

  @override
  String get mockToHistory => 'Deneme Geçmişine Git';

  @override
  String get mockHome => 'Ana Sayfaya Dön';

  @override
  String get mockEmpty => 'Henüz deneme eklemedin.';

  @override
  String get mockFirst => 'İlk Denemeni Ekle';

  @override
  String get mockMore => 'Daha fazla yükle';

  @override
  String get mockRetry => 'Tekrar Dene';

  @override
  String get mockEdit => 'Düzenle';

  @override
  String get mockDelete => 'Sil';

  @override
  String get mockCancel => 'Vazgeç';

  @override
  String get mockDeleteTitle => 'Bu denemeyi silmek istediğine emin misin?';

  @override
  String get mockDeleteBody => 'Kaydedilen deneme ve bölüm sonuçları kalıcı olarak kaldırılacak.';

  @override
  String get mockMissing => 'Deneme bulunamadı.';

  @override
  String get mockNetwork => 'Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.';

  @override
  String get mockValidation => 'Adı, tarihi ve bölüm sayılarını kontrol et. Doğru ve yanlış toplamı soru sayısını aşamaz.';

  @override
  String get mockSession => 'Oturumun sona erdi. Lütfen yeniden giriş yap.';

  @override
  String get mockConflict => 'Sınav yapılandırması kullanılamıyor veya değişti. Yeniden yükleyip tekrar dene.';

  @override
  String get mockRateLimited => 'Çok fazla istek gönderdin. Biraz sonra tekrar dene.';

  @override
  String get mockFailure => 'İşlem tamamlanamadı. Lütfen tekrar dene.';

  @override
  String get mockNoPreparation => 'Devam etmek için aktif hazırlık oluşturmalısın.';

  @override
  String get mockPreparationAction => 'Hazırlığı Kontrol Et';

  @override
  String get mockNoSections => 'Bu sınav için henüz bölüm yapılandırılmamış. Daha sonra tekrar dene.';

  @override
  String get mockQuestions => 'soru';

  @override
  String get mockNet => 'net';

  @override
  String get mockSections => 'Bölüm sonuçları';

  @override
  String get dashboardLatest => 'Son Net';

  @override
  String get dashboardAverage => 'Ortalama';

  @override
  String get dashboardBest => 'En Yüksek';

  @override
  String get dashboardRemaining => 'Hedefe Kalan';

  @override
  String get dashboardReached => 'Hedefe ulaştın';

  @override
  String get dashboardAbove => 'Hedefin üzerinde';

  @override
  String get dashboardTrend => 'Net Gelişimi';

  @override
  String get dashboardSections => 'Bölüm Performansı';

  @override
  String get dashboardRecent => 'Son Denemeler';

  @override
  String get dashboardNoData => 'Henüz veri yok';

  @override
  String get dashboardInsufficient => 'Gelişim karşılaştırması için en az 6 deneme gerekli.';

  @override
  String get dashboardChartHint => 'Noktalar deneme sırasındadır; kesikli çizgi hedef neti gösterir.';

  @override
  String get dashboardRefresh => 'Yenile';

  @override
  String get dashboardRetired => 'Geçmiş bölüm';

  @override
  String get dashboardCount => 'Deneme sayısı';

  @override
  String dashboardChange(String change) {
    return 'Son 3 deneme ortalaman önceki 3 denemeye göre $change net.';
  }
}
