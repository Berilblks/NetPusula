# Google hesabını mevcut hesaba bağlama

## Akış ve güvenlik

Ana sayfadaki **Hesap Ayarları** → **Google Hesabını Bağla** ekranında mevcut
yerel şifre yeniden girilir ve Google hesabı seçilir. Şifre ve Google ID token,
uygulamanın mevcut authenticated Dio istemcisiyle `POST /api/auth/google/link`
endpoint'ine gönderilir. Kullanıcı ID'si request'ten alınmaz; JWT'den çözülür.

Şifreli hesap için her bağlama isteğinde şifre yeniden doğrulanır. Google token
aynı mevcut imza, issuer, audience, expiration, verified email ve sub kontrollerinden
geçer. Yanlış şifre/Google token 400, bağlantı çakışması 409, provider erişim sorunu
503 döner; 401 yalnız geçersiz/eksik uygulama oturumuna ayrılır. Böylece yanlış
şifre mevcut JWT oturumunu gereksiz yere yeniletmez veya kapatmaz.

Google sub başka kullanıcıdaysa veya kullanıcının farklı bir Google sub bağlantısı
varsa işlem reddedilir. Aynı sub tekrar gönderilirse mevcut profil döner.
Şifresiz Google hesabı için yalnız mevcut aynı sub'ın doğrulanmış tekrarı kabul edilir.
Google hesabını değiştirme/bağlantıyı kaldırma bu çalışmanın kapsamında değildir.

E-posta eşleşmesi otomatik bağlama sağlamaz. Her iki kimliğe sahiplik açıkça
doğrulandığından farklı e-postalı Google hesabı da bağlanabilir; yerel e-posta/ad
değişmez ve başka NetPusula hesapları birleştirilmez.

Tek SQL koşullu UPDATE yalnız boş GoogleSubject alanını doldurur; aynı kullanıcıya
eşzamanlı farklı sub yazılması engellenir. Mevcut benzersiz indeks, farklı kullanıcıların
aynı sub'ı almasını engeller; PostgreSQL unique çakışması güvenli 409'a çevrilir.
Kullanıcı ID, şifre hash'i, deneme/istatistik/hedef ilişkileri değiştirilmez.
Bağlama yeni oturum/token üretmez; mevcut refresh rotation/replay koruması korunur.

`/me` ve auth profil yanıtlarına yalnız `googleLinked` boolean alanı eklendi.
Google sub, token veya şifre istemciye geri döndürülmez. Yeni migration yoktur;
önceden uygulanmış AddGoogleIdentity kullanılır.

## Flutter

`/account` yalnız authenticated kullanıcıya açıktır; preparation tamamlanmasını
gerektirmez. Ekran profili backend'den yükler ve bağlı durumunu gösterir. İptal
sessizdir; işlem sırasında düğme devre dışıdır. Şifre alanı Google seçimi öncesinde
temizlenir; request map'i tamamlandığında temizlenir. Oturum değişmişse geciken
Google seçimi/HTTP yanıtı işlenmez. Hatalar yerelleştirilir; raw exceptions gösterilmez.

## Cihazda kullanıcı doğrulaması

1. Mevcut email/şifre ile giriş yapın.
2. Ana sayfa → Hesap Ayarları → mevcut şifre → Google Hesabını Bağla.
3. Doğru Google hesabını seçin; **Google hesabı bağlı** durumunu kontrol edin.
4. Çıkış yapıp Google ile giriş yapın.
5. Önceki denemelerinizin ve hedefinizin aynı olduğunu kontrol edin.

Gerçek kullanıcı şifresi istenmez/loglanmaz; interaktif hesap seçimi kullanıcıya
bırakılır. Cihazda bu akış tamamlanmadan gerçek giriş doğrulanmış sayılmaz.

## Doğrulama — 29 Ekim 2026

- Backend: **215/215** (6 yeni bağlama testi); build 0 hata, 0 uyarı.
- Flutter: **247/247** (6 yeni bağlama testi); analyze temiz.
- EF model kontrolü: bekleyen model değişikliği yok; yeni migration oluşturulmadı/uygulanmadı.
- Güncel yerel API health: HTTP 200; oturumsuz `/api/auth/google/link`: HTTP 401.
- Android arm64 debug APK başarılı (Gradle 46,1 saniye); mevcut Web client ID ile
  derlendi ve Redmi Note 8'e veriler korunarak `install -r` ile yüklendi/açıldı.
  USB reverse sonrası telefonun health isteği HTTP 200 döndü. Kullanıcının gerçek
  şifre/Google seçimiyle bağlama ve yeniden giriş doğrulaması bekleniyor.
- `git diff --check`: temiz.
- İlk backend çalışmasında yeni güvenli profil alanı için test beklentisi güncellendi.
  Mevcut production startup testinde bir kez ObjectDisposedException görüldü;
  test gevşetilmeden tam tekrar 215/215 geçti.
- İlk Flutter çalışmasında logout sonrası reddin DioException ile sarılması nedeniyle
  testin hata beklentisi düzeltildi; son tam çalışma 247/247 geçti.

## Bu özellikte değişen dosyalar

- Backend: `AuthContracts.cs`, `GoogleAuthContracts.cs`, `AuthService.cs`, `AuthEndpoints.cs`.
- Backend testleri: `AuthTests.cs`, `GoogleAuthTests.cs`.
- Flutter: `auth_models.dart`, `auth_repository.dart`, yeni `account_screen.dart`,
  `home_screen.dart`, `app_router.dart`.
- Yerelleştirme: `app_tr.arb` ve üretilen localization Dart dosyaları.
- Flutter testleri: yeni `google_link_test.dart`.
- Dokümantasyon: bu dosya.

Önceki commit edilmemiş premium auth/Google giriş çalışmaları korunmuştur.
Commit/push yapılmamıştır.
