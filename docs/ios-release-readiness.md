# NetPusula — iOS yayın hazırlığı teknik denetimi

Tarih: 30 Ekim 2026. İncelenen temel: `main`, `ee3b930`.

## Karar ve sınırlar

**App Store yayınına henüz hazır değil.** Flutter iOS iskeleti ve platformdan bağımsız auth altyapısı mevcut; native bağımlılık kurulumu, Apple kimliği, hesap silme, mağaza belgeleri ve imzalı macOS doğrulaması eksik.

Denetim başlangıcında Git çalışma ağacı temizdi. Bu çalışma yalnızca bu belgeyi oluşturur. Kod, backend ayarları, veritabanı ve migration geçmişi değiştirilmedi; hesap/CI oluşturulmadı, anahtar üretilmedi, commit/push yapılmadı. Yerel sırlar rapora alınmadı.

Önceki doğrulanmış temel backend 217/217, Flutter 251/251 ve temiz analyze sonucudur; bu salt okunur denetimde testler yeniden çalıştırılmadı. Windows ortamında Xcode, CocoaPods çözümlemesi, iOS archive, TestFlight ve fiziksel iPhone testi yapılmadı. Android başarısı iOS doğrulaması sayılmaz. Apple Developer/Google Console/production kaynaklarına erişilmedi; bu hesapların durumu bilinmiyor.

Durumlar: **Hazır** kaynakta mevcut teknik temel; **Eksik** somut eksik veya yayın engeli; **Doğrulama gerekiyor** dış hesap, native build veya cihaz kanıtı gerekli. Hazır, mağaza onayı garantisi değildir.

## Öncelik sırası

| Öncelik | Durum | İş |
|---|---|---|
| P0 | Eksik | iOS 12.0 hedefini yayın için geçerli seviyeye çıkarmak; Xcode 26+ / iOS 26 SDK ile Flutter uyumunu doğrulamak. |
| P0 | Eksik | Native paket entegrasyonunu tamamlamak: Podfile/Pods yapılandırması veya doğrulanmış SPM alternatifi. |
| P0 | Eksik | Google girişine eşdeğer, Apple 4.8 koşullarını karşılayan giriş seçeneği; önerilen çözüm Sign in with Apple. |
| P0 | Eksik | Uygulama içinden hesap silme ve ilişkili verilerin/oturumların güvenli kaldırılması. |
| P0 | Eksik | Google iOS client ve URL scheme değerlerinin release yapılandırmasına bağlanması. |
| P0 | Doğrulama gerekiyor | Apple üyeliği, nihai Bundle ID kaydı, signing/provisioning ve production HTTPS API. |
| P1 | Eksik | Gizlilik politikası, uygulama içi erişim, App Privacy beyanı, mağaza metinleri ve ekran görüntüleri. |
| P1 | Eksik | Tekrarlanabilir macOS CI, imzalı IPA, TestFlight cihaz kabul testi. |
| P2 | Eksik | Marka uyumlu LaunchScreen; kullanım koşulları/EULA tercihi. |

Apple kaynağı 9 Eylül 2026'dan beri yüklemeler için iOS/iPadOS 13+ hedefini, 28 Nisan 2026'dan beri Xcode 26+ ve iOS 26 SDK şartını bildiriyor. SDK sürümü ile minimum çalıştırılabilir iOS sürümü farklıdır. Yayın günü tekrar kontrol edilmeli. [Apple güncel gereksinimler](https://developer.apple.com/news/upcoming-requirements/)

## 1. Flutter iOS projesi

| Konu | Durum | Kanıt ve yapılacak kontrol |
|---|---|---|
| iOS klasörü | Hazır | `mobile/ios` mevcut; Runner, Flutter config ve RunnerTests var. |
| Xcode proje/workspace | Hazır | `Runner.xcodeproj/project.pbxproj`, ortak Runner scheme ve `Runner.xcworkspace` mevcut. Workspace yalnız Runner projesini referanslıyor; native build başarısı henüz yok. |
| Bundle Identifier | Doğrulama gerekiyor | Debug/Profile/Release: `dev.netpusula.netpusula`; test: `dev.netpusula.netpusula.RunnerTests`. Apple'da benzersiz kayıt ve kullanıcı nihai kararı doğrulanmadı. Değiştirilmedi. |
| Minimum iOS | Eksik | pbxproj ve `Flutter/AppFrameworkInfo.plist` 12.0. Güncel mağaza şartıyla uyumsuz. Seçilecek Flutter/plugin zincirinin en yüksek minimumuyla birlikte tutarlı güncellenmeli. |
| Swift | Hazır | `SWIFT_VERSION = 5.0`; AppDelegate `FlutterAppDelegate` kullanır, GeneratedPluginRegistrant kaydı vardır. Xcode 26 derlemesi doğrulanmalı. |
| CocoaPods/SPM | Eksik | Podfile ve Podfile.lock yok; Debug/Release xcconfig yalnız Generated.xcconfig içeriyor, Pods include yok. pbxproj'de Pods veya FlutterGeneratedPluginSwiftPackage entegrasyonu yok. Seçilen Flutter sürümünün desteklediği native paket yöntemi kurulmalı; eski Windows generated dosyaları CI'a taşınmamalı. |
| Flutter araç zinciri | Doğrulama gerekiyor | Yerel generated config Flutter 3.29.0 gösteriyor; pubspec Dart `^3.7.0`. macOS/Xcode 26 uyumu kanıtlanmadı; gerekirse ayrı, testli SDK yükseltme işi. CI'da kesin sürüm sabitlenmeli. Güncel Flutter belgesi iOS 13+ destek tabanını belirtir. [Flutter iOS release](https://docs.flutter.dev/deployment/ios) |
| Info.plist / uygulama adı | Hazır | CFBundleName ve CFBundleDisplayName `NetPusula`; build adı/numarası Flutter değişkenlerinden. Main/LaunchScreen storyboard bağlı. |
| İzinler / ATS | Hazır | Kamera, mikrofon, konum, fotoğraf izni ve geniş ATS istisnası yok. Mevcut akışlar bunları gerektirmiyor; salt ağ bağlantısı için ek runtime izin istenmez. Google login için URL scheme gerekir. |
| Yönler ve iPad | Doğrulama gerekiyor | Device family `1,2`: iPhone+iPad. Portrait/landscape tanımlı. iPad, rotasyon, safe area, büyük yazı, klavye ve karanlık tema native ortamda test edilmeli. iPad desteği sessizce kaldırılmamalı. |
| AppIcon | Hazır | AppIcon asset kataloğu ve 1024px NetPusula pusula ikonu mevcut; büyük ikon görsel olarak incelendi. Tüm boyutlar, alfa kanalı ve archive asset validation CI'da doğrulanmalı. |
| LaunchScreen | Eksik | Storyboard mevcut, beyaz arka planda LaunchImage kullanıyor. LaunchImage.png görsel olarak boş şablon; premium açılış görünümü tamamlanmamış. İşlevsel derleme engeli olarak değil marka eksikliği olarak değerlendirildi. |

### Paketler

| Paket / kurulu native karşılığı | Durum | Değerlendirme |
|---|---|---|
| `google_sign_in 7.2.0` / `google_sign_in_ios 6.2.1` | Doğrulama gerekiyor | iOS implementasyonu var. Yerel podspec iOS 12, Swift 5, GoogleSignIn `~>9.0`, GTMSessionFetcher `>=3.4.0` bildiriyor. Podfile.lock olmadığından gerçek native çözüm/sürüm zinciri kanıtlanmadı. |
| `flutter_secure_storage ^10.3.4` / Darwin 0.3.2 | Doğrulama gerekiyor | Native Keychain desteği var; podspec minimum 12.0. Signing altında gerçek okuma/yazma/silme testi gerekli. |
| `path_provider_foundation 2.4.2` (transitif) | Doğrulama gerekiyor | iOS podspec mevcut, minimum 12.0. Archive ile doğrulanmalı. |
| Riverpod, go_router, Dio, intl, Flutter localization | Hazır | Kaynakta iOS'u dışlayan bağımlılık yok; native auth dönüşü/routing ve HTTP erişimi cihazda ayrıca doğrulanmalı. |
| Privacy manifests | Doğrulama gerekiyor | Yukarıdaki üç kurulu native pakette PrivacyInfo.xcprivacy bulundu. Runner için özel manifest yok. Bu tek başına ihlal kanıtı değildir; kullanılan required-reason API'ler ve archive'a gerçekten dahil olan manifest/SDK imzaları incelenmeli. Beyanlar tahmin edilmemeli. |

## 2. Kimlik doğrulama

| Konu | Durum | Kanıt / eksik |
|---|---|---|
| Google SDK iOS kodu | Hazır | `google_identity_client.dart` iOS'ta `GOOGLE_IOS_CLIENT_ID`, ortak server için `GOOGLE_SERVER_CLIENT_ID` okur; SDK initialize'a clientId/serverClientId gönderir. Eksik değerlerde googleUnavailable döner. |
| iOS OAuth client | Eksik | Nihai Bundle ID için ayrı iOS OAuth client yapılandırmasının projeye bağlandığına dair kanıt yok. Android client/fingerprint bunun yerine geçmez. Console'da var olup olmadığı dış doğrulama konusu. |
| URL scheme | Eksik | Info.plist `$(GOOGLE_REVERSED_CLIENT_ID)` içeriyor, fakat Xcode build setting tanımı yok. Dart define bu Xcode değişkenini otomatik doldurmaz. iOS client ID'nin ters çevrilmiş değeri tüm konfigürasyonlarda sağlanmalı. |
| Google plist anahtarları | Hazır | GIDClientID/GIDServerClientID yokluğu tek başına hata değil; SDK değerleri Dart initialize üzerinden alıyor. URL scheme yine zorunlu. Firebase veya client secret gerekmez. [Flutter Google iOS entegrasyonu](https://pub.dev/packages/google_sign_in_ios) |
| Google backend / hesap bağlama | Hazır | `/api/auth/google` ve yetkili `/api/auth/google/link` mevcut. İmza/issuer/audience/expiry ve doğrulanmış e-posta denetlenir. `sub` kimliktir; e-posta eşleşmesi otomatik bağlamaz. Yerel şifreli hesap bağlamada şifre tekrar doğrulanır. iOS uçtan uca test gerekli. |
| Sign in with Apple | Eksik | Paket, buton, entitlement, endpoint ve Apple token doğrulayıcı bulunmadı. Mevcut Google doğrulayıcı Apple token'ı için kullanılamaz. |
| Apple hesabı bağlama | Eksik | User yalnız GoogleSubject destekler. Gelecekte ayrı provider/sub, çakışma ve idempotency kuralları, yakın kimlik doğrulama, relay e-posta/ilk girişte ad bilgisi ele alınmalı; aynı e-postayla otomatik bağlama yapılmamalı. Bu aşamada model/migration önerisi uygulanmadı. |
| Hesap silme | Eksik | Account ekranı ve auth endpoint'lerinde hesap silme yok. Logout hesap silme değildir. Yeniden doğrulama, token iptali, ilişkili deneme/hedef/veri silme ve saklama istisnalarının açıklanması tasarlanmalı. Apple eklenirse Apple token revocation da ele alınmalı. |
| JWT / refresh saklama | Hazır | `SecureSessionStorage`: iOS Keychain, `unlocked_this_device`, `synchronizable:false`; session JSON'u Keychain içinde. Refresh rotation/replay koruması backend'de mevcut. |
| Keychain cihaz davranışı | Doğrulama gerekiyor | Runner.entitlements boş keychain-access-groups dizisi içeriyor ve üç build config'e bağlı. Signed entitlements, kilitli cihaz, restart, logout, uygulama güncelleme ve uninstall/reinstall sonrası Keychain kalıcılığı test edilmeli. Android testi bu kanıtı sağlamaz. |

Google birincil hesap girişi sunduğu için Apple 4.8 değerlendirmesi önemlidir: kural belirli gizlilik özelliklerine sahip eşdeğer giriş ister; yalnız email/şifre seçeneği bunu otomatik karşılamaz. Bu projede görünen bir istisna yok; Sign in with Apple önerilir. Apple bağlama ayrı ürün/güvenlik işidir. Hesap oluşturulan uygulamada uygulama içi silme sağlanmalıdır. [Apple Review Guidelines 4.8 ve 5.1.1](https://developer.apple.com/app-store/review/guidelines/), [hesap silme rehberi](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion/)

## 3. Backend ve üretim ortamı

| Konu | Durum | Kanıt / gerekli iş |
|---|---|---|
| API URL | Hazır | `ApiConfig.environment()` `API_BASE_URL` ister; yalnız debug + açık ALLOW_INSECURE_HTTP ile HTTP kabul edilir. Release HTTPS zorunlu. iPhone'da localhost geliştirme PC'si değildir; ADB reverse iOS çözümü değildir. |
| Production adresi | Eksik | Yayına ait doğrulanmış domain/TLS/hosting bilgisi yok. `AllowedHosts` varsayılanı localhost/127.0.0.1; production hostname ortamdan verilmelidir. CI release'e erişilebilir HTTPS URL sağlamalı. |
| Ortam ayrımı | Hazır | Development'ta Swagger; dış ortamda HSTS/HTTPS yönlendirme, auth/veri endpoint'lerinde HTTPS kontrolü. Options ValidateOnStart mevcut. `.env` bir deployment/secret manager yerine geçmez. |
| Reverse proxy | Doğrulama gerekiyor | Program.cs'de trusted forwarded headers kurulumu yok. TLS proxy'de sonlanırsa Request.IsHttps ve IP rate limit davranışı doğrulanmalı; tüm proxy'lere güvenmek yerine bilinen proxy tasarımı gerekir. |
| CORS | Hazır | Açık origin allowlist, wildcard reddi; native Flutter tarayıcı CORS kısıtına tabi değil. iOS'u çalıştırmak için CORS'u herkese açmak gerekmez. |
| Google production | Doğrulama gerekiyor | Varsayılan Enabled=false/Audiences boş. Production secret/config yönetiminde etkinlik ve gerçek Web/server audience sağlanmalı. iOS'tan dönen token audience'ı kontrollü test edilmeli; token loglanmamalı. |
| Apple doğrulama | Eksik | Apple JWKS/imza/issuer/audience/expiry, nonce ve tekrar kullanım koruması, yetki kodu/token iptali akışı yok. İleride Google'dan bağımsız doğrulayıcı gerekir. |
| PostgreSQL / migrations | Doğrulama gerekiyor | EF kaynak migration'ları ve GoogleSubject migration'ı mevcut. Yerel PostgreSQL doğrulaması production kanıtı değil. docker-compose yerel PostgreSQL16, loopback port ve volume içerir; production deployment değildir. TLS, least privilege, yedek/restore, migration sırası ve onaylı dağıtım prosedürü gerekli. Bu denetimde DB bağlantısı veya migration çalıştırılmadı. |
| Health | Hazır | `/api/health` sağlıklı süreç yanıtı verir. DB readiness ölçmez. `--check-database` bağlantı kontrolü mevcut; bu denetimde çalıştırılmadı. |
| Loglama | Doğrulama gerekiyor | GlobalExceptionHandler yalnız exception türü loglar; auth kullanıcı ID'si loglayabilir. Token içeriği loglanmıyor. Production proxy/APM/EF logları, saklama süresi, erişim ve kişisel veri redaksiyonu ayrıca denetlenmeli. |

## 4. App Store yayın içeriği

| Konu | Durum | Değerlendirme |
|---|---|---|
| Sürüm | Hazır | `pubspec.yaml`: `1.0.0+1`; Info.plist Flutter build değişkenlerine bağlı. Her upload'da benzersiz artan build numarası CI'da yönetilmeli. |
| Gizlilik politikası | Eksik | Setup belgeleri gerekliliğini anlatıyor ancak yayımlanmış URL ve uygulama içi erişim bulunmadı. Veri, amaç, üçüncü taraflar, saklama/silme ve iletişim bilgileri gerçek uygulamayla tutarlı olmalı. |
| Kullanım koşulları / EULA | Eksik | Ürüne ait metin/link bulunmadı. Apple standart EULA veya özel EULA tercihi yapılmalı; özel sözleşme her uygulama için otomatik zorunlu değildir. |
| Hesap silme | Eksik | Yukarıdaki P0 iş; yalnız e-posta ile destek talebi sıradan uygulama için yeterli çözüm kabul edilmemeli. |
| Ekran görüntüleri | Eksik | Doğrulanmış iOS App Store seti yok. Android/mockup yerine gerçek iOS build'den desteklenen iPhone/iPad boyutları için görüntüler hazırlanmalı. |
| Review hesabı | Eksik | Ayrı, kişisel veri içermeyen çalışır demo hesabı ve review talimatları hazırlanmamış. E-posta/şifre girişi inceleyene Google hesabı zorunluluğunu kaldırır. API inceleme boyunca erişilebilir olmalı. Hesap bu aşamada oluşturulmadı. |
| App Privacy | Eksik | Final beyan yok. İsim/e-posta (Contact Info), kullanıcı/provider kimlikleri (Identifiers), deneme sonuçları/hedefler (uygun User Content/Other Data kategorisi), server logları ve Google SDK davranışı envanterlenmeli. Veriler kullanıcı hesabıyla ilişkilidir; “veri toplanmıyor” uygun değildir. |
| Tracking / ATT | Doğrulama gerekiyor | Kaynakta reklam/izleme SDK'sı ve ATT talebi yok. Google girişini otomatik tracking saymak da tüm SDK zincirini kontrol etmeden “tracking yok” demek de doğru değil. Gerçek kullanım ve partner davranışı değerlendirilmeli. |
| Release imzalama | Eksik | DEVELOPMENT_TEAM yok; distribution profile/export ayarları yok. Developer identity girdileri distribution imzası kanıtı değildir. Apple üyeliği, App ID, App Store Connect kayıtları dışarıdan doğrulanmalı. |
| Diğer metadata | Eksik | Support URL/iletişim, kategori, yaş derecesi soruları, bölge/dağıtım ve encryption export compliance cevapları hazırlanmalı. HTTPS/Keychain nedeniyle uygun muafiyet değerlendirilmeden ITSAppUsesNonExemptEncryption değeri tahmin edilmemeli. |

App Privacy değerlendirmesi uygulama ve üçüncü tarafların gerçek veri kullanımını kapsamalı; kategori/amaç listesi yukarıda taslaktır, gönderilmiş beyan değildir. Privacy manifest ayrı bir teknik dosyadır ve mağaza veri beyanının yerine geçmez. [Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/)

## 5. Windows'tan macOS CI yolu

**Durum: Eksik.** Repo içinde Codemagic/GitHub Actions iOS workflow yok. Windows geliştirmeye devam edilebilir; archive/signing Apple araçlarıyla macOS runner'da yapılır. CI fiziksel iPhone testinin yerine geçmez.

Önerilen Codemagic veya GitHub Actions macOS hattı (henüz kurulmadı):

1. Kullanıcı onayıyla nihai Bundle ID, Apple Developer üyeliği ve App Store Connect app kaydı doğrulansın. Developer Team, dağıtım sertifikası/private key ve provisioning profile yönetimi belirlensin.
2. Xcode 26+ / iOS 26 SDK sağlayan macOS imajı seçilsin; uyumlu Flutter, Ruby/CocoaPods sürümleri sabitlensin. İlk iş imzasız derleme ve bağımlılık çözümü olsun; gerekirse Flutter yükseltmesi ayrı commit kapsamı olsun.
3. Flutter pub get, gen-l10n, analyze/test; native dependency çözümü ve gerektiğinde pod install çalışsın. Podfile/xcconfig veya SPM entegrasyonu kaynakta tekrar üretilebilir hale getirilsin. Generated.xcconfig, Pods ve build çıktıları commit edilmesin; seçilen CocoaPods yolunda uygulamanın Podfile.lock dosyası sürüm kontrolünde tutulsun.
4. Release build'e HTTPS API_BASE_URL, GOOGLE_SERVER_CLIENT_ID, GOOGLE_IOS_CLIENT_ID verilsin; GOOGLE_REVERSED_CLIENT_ID ayrıca Xcode setting olarak sağlansın. Client ID sır değildir; signing private key/API key ise CI secret store'da, loglarda maskeli tutulmalı. OAuth client secret mobile build'e konulmamalı.
5. İmzalı `flutter build ipa --release` ve App Store export, ardından archive validation. Provisioning, Keychain entitlement, Apple capability, privacy manifests ve dSYM artefact'ları kontrol edilsin.
6. İlk upload kullanıcı onaylı TestFlight olsun; otomatik production yayın adımı eklenmesin. IPA/dSYM erişimi ve saklama süresi sınırlandırılsın. TestFlight cihazında Google callback, Apple, linking, silme, refresh/logout ve mevcut kullanıcı verisi test edilsin.

Codemagic App Store Connect entegrasyonu signing sertifikası/provisioning yönetimini destekler; API anahtarı ile signing sertifikasının private key'i farklı varlıklardır. Repository içinde saklanmazlar. Bu denetim hiçbir hesap/anahtar oluşturmadı. [Codemagic iOS signing](https://docs.codemagic.io/flutter-code-signing/ios-code-signing/), [Flutter macOS build ve IPA](https://docs.flutter.dev/deployment/ios)

## 6. Küçük, bağımsız sonraki aşamalar

| Aşama | Durum | Kapsam ve kabul ölçütü |
|---|---|---|
| A — Kimlik ve araç zinciri | Eksik | Bundle ID/Apple hesap kararı; iOS minimumu ve native paket kurulumu; macOS CI imzasız archive başarılı. Gerekli SDK yükseltmesi bağımsız testli değişiklik. |
| B — Google iOS | Eksik | iOS OAuth client/URL scheme; iPhone'da giriş, iptal, mevcut hesaba bağlama, logout/refresh; Android regresyonu temiz. |
| C — Apple giriş | Eksik | UI, capability, backend doğrulama ve ayrı provider kimliği; ilk/tekrar giriş, relay email, yanlış audience/imza/nonce testleri. |
| D — Apple hesap bağlama | Eksik | Geçerli oturum + yeniden doğrulama, çakışma/idempotency testleri; mevcut kullanıcı ID ve deneme verileri korunur. |
| E — Hesap silme | Eksik | UI ve güvenli backend işlem; ilgili veriler ve oturumlar kaldırılır, provider iptali/saklama politikası test edilir. Şema gereksinimi uygulama öncesi ayrıca değerlendirilir. |
| F — Production operasyonu | Doğrulama gerekiyor | HTTPS domain/proxy, secrets, PostgreSQL TLS/restore/migration prosedürü ve izleme kabul testi. |
| G — Mağaza ve gizlilik | Eksik | Yayımlı politika/koşullar, uygulama içi linkler, privacy manifest/beyan denetimi, launch görseli, iOS screenshot ve review bilgileri. |
| H — İmzalı TestFlight | Eksik | CI signing, IPA upload ve gerçek iPhone/iPad regresyonu; kullanıcı onayından sonra App Store submission. |

Bu aşamalar öneridir; geliştirmeye başlanmadı. Kod düzeyinde hazır görünen temel, fiziksel iOS doğrulaması yapılmadan “yayına hazır” olarak işaretlenmemelidir.
