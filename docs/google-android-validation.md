# Google Android test hazırlığı — 28 Ekim 2026

Kullanıcı Web/server ve Android debug istemcileri ile test kullanıcısının Console'da
oluşturulduğunu bildirdi. Console üzerinde bu oturumda değişiklik yapılmadı.

- Project: `netpusula`
- Web/server client: `909493652404-ob2qvuiqo56ku7vpfv9l3k576bmlsnk4.apps.googleusercontent.com`
- Android applicationId: `dev.netpusula.netpusula`
- Debug SHA-1: `1F:AE:40:2F:95:28:70:2F:2C:9D:81:53:CF:04:32:E5:89:BB:BA:68`

## Yerel yapılandırma

Git dışında tutulan kök `.env` dosyasına `GoogleAuth__Enabled=true` ve
`GoogleAuth__Audiences__0=<yukarıdaki Web client ID>` eklendi. Mevcut yerel
başlatma script'i bu değişkenleri process environment'a aktarır. .NET varsayılan
configuration sistemi bunları `GoogleAuth:Enabled` ve `GoogleAuth:Audiences:0`
olarak okur. `.env` tek başına .NET tarafından otomatik yüklenmez.

Üretim appsettings varsayılanları değiştirilmedi. Client secret/OAuth JSON eklenmedi.
Flutter resmi SDK'ya `GOOGLE_SERVER_CLIENT_ID` değerini serverClientId olarak verir.
Android client ID bu parametre yerine kullanılmaz. Firebase bağımlılığı eklenmedi.

## Cihaz için derleme

`mobile` klasöründe:

```powershell
flutter build apk --debug --target-platform android-arm64 --dart-define=API_BASE_URL=http://127.0.0.1:5080 --dart-define=ALLOW_INSECURE_HTTP=true --dart-define=GOOGLE_SERVER_CLIENT_ID=909493652404-ob2qvuiqo56ku7vpfv9l3k576bmlsnk4.apps.googleusercontent.com
```

HTTP istisnası yalnız USB reverse ile bu yerel development testi içindir.
Üretim HTTPS gereksinimi korunur.

## Mevcut engeller ve manuel doğrulama

- İlk `adb devices` kontrolü boştu; sonraki kontrolde yalnız `emulator-5554`
  göründü. Gerçek Android telefon bağlı değil; hesap seçimi/gerçek Google girişi yapılmadı.
- PostgreSQL'in 55441 TCP portu erişilebilir. Bu, veritabanı kimlik doğrulamasının
  başarılı olduğunu kanıtlamaz. API 5080 portunda çalışmıyordu.
- Docker CLI yanıt vermedi; bekleyen kontrol komutu sonlandırıldı, container'lara
  müdahale edilmedi.
- DB kontrolü, migration ve API başlatma komutu otomatik güvenlik denetimince
  engellendi; ayrıntılı gerekçe verilmedi. Migration uygulanmış/API başlatılmış
  olarak raporlanmaz.

Backend başlatılmadan önce kurulum rehberindeki migration adımını yerel DB ayarlarıyla
çalıştırın. Mevcut `.env.start-backend.ps1`, Docker CLI çalışır duruma geldikten sonra
kullanılabilir. USB hata ayıklamasını onaylayıp `adb devices` ile cihazı doğrulayın;
hedef cihaz için `adb -s <serial> reverse tcp:5080 tcp:5080` uygulayın ve APK'yı kurun.

Test kullanıcısıyla Google düğmesine basıp hesap seçimini kullanıcı yapmalıdır.
Yeni hesapta onboarding, tekrar girişte aynı hesap, oturum yenileme ve çıkış kontrol
edilmelidir. Aynı e-postalı mevcut şifreli hesap otomatik bağlanmamalıdır; mevcut
hesap bilgileriyle email/şifre girişi ayrıca cihazda doğrulanmalıdır.
Bu cihaz kontrolleri henüz yapılmadı; gerçek kullanıcı şifresi/tokenı istenmedi veya loglanmadı.

Backend kodu imza/issuer/audience/expiration ve doğrulanmış e-posta/sub kontrollerini
korur; mevcut JWT/refresh rotation/replay altyapısını kullanır. Yeniden yazılmadı.

## Otomatik doğrulamalar

- `dotnet test`: 209/209 başarılı. Google doğrulama, hesap çakışması, tekrarlanan
  giriş, refresh/replay ve mevcut email/şifre akışlarını kapsar. Bunlar gerçek
  Google hesabıyla cihaz testinin yerine geçmez.
- `flutter analyze`: temiz. İlk çalışmadaki iki test parantez lint'i düzeltildi.
- `flutter test --concurrency=1`: 241/241 başarılı.
- İlk paralel test/APK çalışmasında Dart `Could not start thread DartWorker`
  ve Gradle daemon kapanması görüldü; testler 217'de yarım kaldı. Testler tek
  işçiyle tekrarlandı; APK ayrıca düşük Gradle bellek/işçi sınırıyla yeniden denendi.
- Derleme logları ve APK `mobile/build` altında ignored tutulur.
- APK yeniden derlemesi başarılı (Gradle 35,1 saniye):
  `mobile/build/app/outputs/flutter-apk/app-debug.apk`. Yukarıdaki Web client ID
  dart-define ile derlendi. Telefona kurulmadı. Son `adb devices` çıktısı tekrar boştu.
- `git diff --check`: başarılı.

Bu oturumdaki değişiklikler: ignored `.env`, iki test lint düzeltmesi
(`mobile/test/google_auth_test.dart`), kurulum rehberi ve bu rapor. Önceki Aşama 2
değişiklikleri korunur. Commit/push yapılmadı.
