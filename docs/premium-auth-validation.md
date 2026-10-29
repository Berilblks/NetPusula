# Premium tasarım Aşama 2 — Auth ve Google

## 29 Ekim 2026 — Commit öncesi son kontrol

- Backend: 217/217; Flutter: 251/251; Flutter analyze: temiz; `git diff --check`: başarılı.
- ReleaseHardening testindeki aralıklı hata, minimal API başlangıcı başarısız olduğunda `Run` tarafından dispose edilen host ile `WebApplicationFactory.DeferredHost` arasındaki yarıştan kaynaklanıyordu. Test önceki commit'te de aynı yaşam döngüsünü kullanıyordu.
- Database options kaydı aynı kurallarla ortak metoda taşındı. Test bu gerçek kaydı kullanarak kendi yönettiği host üzerinde `StartAsync` çağırır; `OptionsValidationException` ve options türü doğrulanır. Geçerli Production ve boş Development yapılandırmaları için iki kontrol testi eklendi.
- Production doğrulaması, Google/JWT davranışı, kullanıcı verileri ve veritabanı migration geçmişi bu düzeltmede değiştirilmedi. Test çıktıları için ignored `backend/obj/link-validation/bin/` kullanıldı.
- Yerel `.env`, OAuth sırları, APK ve build/test çıktıları commit kapsamı dışındadır.

20 Ekim 2026. Değişiklikler inceleme için uncommitted bırakıldı.

## Uygulama

- Login: mevcut pusula markası, lacivert/mor başlık, slogan, yuvarlatılmış form, gradient giriş düğmesi.
- Register: açık zemin, mevcut display name alanına bağlı Ad Soyad, e-posta, şifre ve tekrar alanları.
- Her iki ekranda resmi Google G görseli ve ortak Google giriş akışı.
- Mevcut email/şifre, session storage, routing ve preparation guard korunur.
- Google SDK iptali sessizdir; ağ/sunucu/hesap çakışması için yerelleştirilmiş hata gösterilir.
- Küçük ekran, klavye, büyük yazı ve açık/koyu tema widget testleri eklendi.

## Backend ve veri modeli

`POST /api/auth/google`, `idToken` kabul eder. Google'ın sabit HTTPS discovery
adresinden alınan anahtarlarla RS256 imza, issuer, yapılandırılmış audience ve
expiry doğrulanır. Doğrulanmış e-posta ve geçerli sub zorunludur.

`20261019161619_AddGoogleIdentity` migration'ı User'a nullable GoogleSubject ve
benzersiz index ekler. Mevcut kullanıcıların kimlikleri/şifreleri korunur.
Yeni Google hesabı şifresiz oluşturulur; aynı e-postalı mevcut hesaba otomatik
bağlanmaz (409). Tekrarlanan Google girişinde sub kullanılır. Uygulamanın kendi
JWT/refresh token akışı kullanılır; Google token'ı uygulama bearer token'ı değildir.

## Doğrulama

| Kontrol | Sonuç |
|---|---|
| Backend build | Başarılı; 0 hata, 0 uyarı |
| Backend test | 209/209; 17 yeni Google testi |
| Flutter analyze | No issues found |
| Flutter test | 241/241; 19 yeni Google/UI testi |
| Android arm64 debug APK | Başarılı (248 saniye); yerel API development dart-defines |
| EF pending model changes | Yok |
| Gerçek PostgreSQL | Ayrı geçici veritabanında başarılı |
| git diff --check | Başarılı; Git LF/CRLF dönüşüm uyarıları verdi |

APK: `mobile/build/app/outputs/flutter-apk/app-debug.apk`. Google client ID
tanımlanmadan derlendi; Google butonu kurulum tamamlanana kadar uygun
yapılandırma mesajını gösterir. Bu aşamada telefona yüklenmedi.

PostgreSQL kontrolü önceki migration'dan yükseltme, mevcut kullanıcının korunması,
birden çok nullable kimlik, benzersiz Google sub ihlalinin engellenmesi,
downgrade/reapply ve veri korunmasını doğruladı. Geçici veritabanı kaldırıldı.
Kullanıcının mevcut veritabanı bu doğrulamada değiştirilmedi.

İlk Flutter test çalışmasında eski submit widget beklentisi ve async test
bekleyişi düzeltildi; yukarıdaki sonuçlar son tam çalışmaya aittir.

## Kurulum ve sınırlar

[Google Console kurulum rehberi](google-signin-setup.md) Web/server, Android
package/SHA, iOS client/scheme ve backend audience ayarlarını içerir.
Console istemcileri kullanıcı tarafından henüz oluşturulmadı. Gerçek cihazda
Google hesabıyla giriş doğrulanmadı. iOS build/test Windows üzerinde yapılmadı;
Bundle ID değiştirilmedi. Hesap bağlama/şifre kurtarma yeni özellikleri eklenmedi.

Yerel backend derleme sırasında assembly kilidini kaldırmak için durduruldu.
Mevcut yerel veritabanına migration uygulayıp backend'i yeniden başlatma komutu
otomatik güvenlik denetimince engellendi; gerekçe ayrıntısı sağlanmadı.
Yerel backend yeniden başlatılmış değildir. Kurulum rehberindeki migration
adımı ardından yerel backend başlatılmalıdır. Docker CLI de bu oturumda
yanıt vermedi; diğer container'lara müdahale edilmedi.

APK, önizlemeler, test logları ve geçici PostgreSQL doğrulama projesi build/obj
altında yerel/ignored tutulur. OAuth client secret veya gerçek kimlik bilgisi
kaynak dosyalara eklenmedi. Commit/push yapılmadı.

## Değişen dosyalar

- `backend/src/NetPusula.Api/appsettings.json`
- `backend/src/NetPusula.Api/Auth/AuthEndpoints.cs`
- `backend/src/NetPusula.Api/Auth/AuthSetup.cs`
- `backend/src/NetPusula.Api/Auth/GoogleTokenValidator.cs`
- `backend/src/NetPusula.Application/Auth/AuthContracts.cs`
- `backend/src/NetPusula.Application/Auth/GoogleAuthContracts.cs`
- `backend/src/NetPusula.Domain/User.cs`
- `backend/src/NetPusula.Infrastructure/Auth/AuthService.cs`
- `backend/src/NetPusula.Infrastructure/DomainModelConfiguration.cs`
- `backend/src/NetPusula.Infrastructure/Migrations/20261019161619_AddGoogleIdentity.cs`
- `backend/src/NetPusula.Infrastructure/Migrations/20261019161619_AddGoogleIdentity.Designer.cs`
- `backend/src/NetPusula.Infrastructure/Migrations/NetPusulaDbContextModelSnapshot.cs`
- `backend/tests/NetPusula.Tests/GoogleAuthTests.cs`
- `docs/google-signin-setup.md`
- `docs/premium-auth-validation.md`
- `mobile/assets/auth/google-g.png`
- `mobile/ios/Runner/Info.plist`
- `mobile/lib/features/auth/application/auth_controller.dart`
- `mobile/lib/features/auth/data/auth_repository.dart`
- `mobile/lib/features/auth/data/google_identity_client.dart`
- `mobile/lib/features/auth/domain/auth_issue.dart`
- `mobile/lib/features/auth/presentation/auth_text.dart`
- `mobile/lib/features/auth/presentation/auth_widgets.dart`
- `mobile/lib/features/auth/presentation/login_screen.dart`
- `mobile/lib/features/auth/presentation/premium_auth_page.dart`
- `mobile/lib/features/auth/presentation/register_screen.dart`
- `mobile/lib/l10n/app_localizations_tr.dart`
- `mobile/lib/l10n/app_localizations.dart`
- `mobile/lib/l10n/app_tr.arb`
- `mobile/pubspec.lock`
- `mobile/pubspec.yaml`
- `mobile/test/design_system_test.dart`
- `mobile/test/google_auth_test.dart`
- `mobile/test/premium_auth_ui_test.dart`
- `README.md`
