# Faz 4 — Flutter kimlik doğrulama

Bu faz yalnızca kayıt, giriş, oturum yenileme/geri yükleme ve çıkışı kapsar. Backend sözleşmesi değiştirilmedi. Gerçek dashboard, sınav seçimi, UserExam, deneme girişi, istatistik ve alt gezinme yoktur.

## Mimari ve dosyalar

- `mobile/lib/core/config/api_config.dart`: tek API origin'i, derleme zamanı yapılandırması.
- `core/network/api_client.dart`: Dio oluşturma, zaman aşımı, origin kontrolü; yönlendirme ve credential logging yok.
- `core/network/auth_interceptor.dart`: Bearer ekleme, 401 sonrası tek tekrar, oturum nesli kontrolü.
- `core/storage/session_storage.dart`: test edilebilir SessionStorage ve flutter_secure_storage uygulaması.
- `features/auth/domain/`: güvenli kullanıcı DTO'su, token zarfı ve kullanıcıya uygun hata türleri.
- `features/auth/data/auth_repository.dart`: gerçek API sözleşmesi, kalıcılık, tek refresh Future'ı, logout, invalidation akışı.
- `features/auth/application/auth_controller.dart`: Riverpod durum ve işlem koordinasyonu.
- `features/auth/presentation/`: splash, giriş, kayıt ve geçici home; ortak form parçaları ve yerelleştirilmiş hata eşlemesi.
- `features/welcome/welcome_screen.dart`: Türkçe karşılama ve giriş/kayıt seçenekleri.
- `core/routing/app_router.dart`: auth durumundan türeyen yönlendirme.
- `l10n/app_tr.arb`: tüm yeni kullanıcı metinleri; Flutter tarafından üretilen yerelleştirme sınıfları.

Provider'lar: `apiConfigProvider`, `sessionStorageProvider`, `authRepositoryProvider`, `apiDioProvider`, `authControllerProvider`, `appRouterProvider`. AuthState yalnızca `status`, `busy`, güvenli `AuthUser {id, displayName, email}` ve `AuthIssue` tutar. Durumlar initializing, unauthenticated, authenticated ve startupError'dır. UI istekleri repository'ye doğrudan göndermez.

## Sözleşme

| İşlem | İstek | Yanıt |
| --- | --- | --- |
| POST /api/auth/register | displayName, email, password | 201 AuthResponse |
| POST /api/auth/login | email, password | 200 AuthResponse |
| POST /api/auth/refresh | refreshToken | 200 AuthResponse |
| POST /api/auth/logout | refreshToken | 204 |
| GET /api/auth/me | Authorization: Bearer access token | id, displayName, email |

AuthResponse: accessToken, accessTokenExpiresAtUtc, refreshToken, refreshTokenExpiresAtUtc, tokenType=Bearer, user. Kayıt ve giriş yanıtı oturumu doğrudan açar; ikinci login veya gereksiz /me çağrısı yapılmaz. Yeniden başlatmada kullanıcı mutlaka /me ile alınır. Kayıt parolası 8–128 UTF-16 birimi, en az bir harf ve rakam, kontrol karakteri yok; parola trim edilmez. Görünen ad trim sonrası 2–120 karakterdir. Standart e-posta biçimi istemcide doğrulanır; backend nihai doğrulama otoritesidir.

## Başlangıç ve yönlendirme

1. Flutter binding ve ProviderScope başlatılır; router /splash gösterir.
2. Güvenli depoda kayıt yoksa /welcome açılır.
3. Access token süresi dolmuşsa veya bitişine 30 saniyeden az kalmışsa refresh yapılır; sonra /me çağrılır.
4. Doğrulanmış kullanıcı /home'a geçer. Home yalnızca selamlama ve çıkış içerir.
5. /home'a anonim/deep-link erişimi /welcome'a yönlenir. Oturum açıkken /welcome, /login ve /register erişimi /home'a yönlenir.
6. Başlangıç doğrulaması veya kurtarma hatası sırasında korumalı içerik oluşturulmaz.

Geçerli token ile /me ağ hatası, oturumu silmeden splash üzerinde yeniden denemeye veya yerel çıkışa izin verir. Geçersiz/sona ermiş refresh veya başarısız refresh oturumu temizler; karşılama ekranında güvenli hata mesajı görünür. Native güvenli depoya erişilemiyorsa uygulama erişimi kapalı tutar; silme başarısızken açık oturum iddia etmez.

## Güvenli saklama ve refresh

`netpusula.auth.session.v1` anahtarında tek JSON zarfı saklanır: access token, refresh token, UTC bitişleri ve `refreshPending` işareti. Kullanıcı profili, parola, PasswordHash veya imzalama key'i saklanmaz. Android secure storage, iOS cihazla sınırlı ve kilit açıkken erişilebilir Keychain kullanır; iCloud senkronizasyonu kapalıdır. Android backup kapalıdır. iOS entitlements Runner'ın üç build konfigürasyonuna bağlanmıştır.

Public auth Dio ile korumalı API Dio ayrıdır; login/register/refresh/logout'a Bearer eklenmez. Korumalı Dio erişim token'ını ekler. 401'de repository tek bir devam eden Future paylaşır. Bekleyen istekler aynı refresh sonucunu kullanır. Geç gelen eski-token 401'i yeni çifti kullanır, ikinci refresh başlatmaz. Her istek en çok bir kez yeniden gönderilir; tekrar 401 gelirse oturum temizlenir. Stream/FormData gibi tekrar kullanılamayan gövdeler otomatik tekrar gönderilmez.

Rotation öncesinde `refreshPending=true` güvenli depoya yazılır. Sunucu token'ı döndürürse yeni çift tek zarfla kaydedilir. Timeout/bağlantı kesilmesi veya uygulamanın arada kapanması, eski refresh'in tüketilip tüketilmediğini belirsiz bırakır. Backend replay halinde aileyi iptal ettiği için sonraki açılış eski token'ı yeniden göndermez; tekrar giriş gerekir. Bu bilinçli güvenlik/UX tercihidir. Güvenli depolama işlemleri sıralıdır; logout veya yeni oturum sonrası eski isteklerin token yazmasını oturum nesli engeller. Tek uygulama süreci/ana isolate için tasarlanmıştır; ek background isolate auth uygulaması bu koordinatörü paylaşmalıdır.

## Çıkış ve hatalar

Çıkışa basıldığında kullanıcı durumu hemen kaldırılır, yerel token'lar temizlenir; backend'e refresh token ile logout best-effort gönderilir. Güvenli silme önce boş zarf, ardından delete dener; biri başarılıysa yerel oturum geri yüklenemez. İkisi de başarısızsa açık hata gösterilir ve bu süreçte restore eski oturumu açmaz. OS deposu kalıcı biçimde kullanılamıyorsa diskten silme garanti edilemez; cihaz kilidini açıp tekrar deneme gerekir.

Sunucu logout ağ nedeniyle başarısızsa yerel çıkış tamamlanır ve bu durum kullanıcıya söylenir. Sunucudaki refresh token süresi dolana veya iptal edilene kadar geçerli kalabilir. Başarılı logout bile mevcut access JWT'yi anında iptal etmez; backend'de varsayılan en fazla 15 dakika geçerlidir. Refresh sonucu logout'tan sonra gelirse saklanmaz ve dönen token için iptal denenir.

400 alan hataları güvenli yerel doğrulama metinlerine, 401 genel hatalı kimlik bilgisine, 409 mevcut e-postaya, 429 bekleme mesajına, 5xx genel hataya, bağlantı/zaman aşımı ağ mesajına çevrilir. Raw JSON, stack trace ve sunucunun hata metni gösterilmez. LogInterceptor, token/header/parola print'i, sertifika atlatma veya Flutter içinde secret yoktur. Native keychain/keystore güvenliği fiziksel cihazda ayrıca sınanmalıdır; birim testler native şifrelemenin kanıtı değildir.

## Yerel backend ve Android emulator

Önce README'deki PostgreSQL/Docker kurulumu ve migration adımlarını tamamlayın. DB bağlantısı backend ortam değişkeninde bulunmalıdır. Repo kökünden ayrı PowerShell terminali:

```powershell
$env:ASPNETCORE_ENVIRONMENT = 'Development'
$env:Jwt__SigningKey = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
$env:AllowedHosts = 'localhost;127.0.0.1;10.0.2.2'
dotnet run --project backend/src/NetPusula.Api --no-launch-profile --urls http://0.0.0.0:5080
```

Signing key yalnızca backend terminalinde tutulur; Flutter'a aktarılmaz. Her yeniden üretim eski access JWT'leri geçersiz kılar. LAN binding yerel geliştirme içindir; güvenilir ağ kullanın. Android emulator host bilgisayarı `10.0.2.2` ile görür; emulator içindeki localhost bilgisayar değildir.

```powershell
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5080 --dart-define=ALLOW_INSECURE_HTTP=true
```

HTTP hem debug modunu hem ALLOW_INSECURE_HTTP=true seçeneğini gerektirir. Android debug manifest HTTP'ye izin verir; ana/release manifest vermez. API_BASE_URL verilmezse uydurma bir servise bağlanılmaz; ilk ağ işleminde yerel bağlantı yapılandırma hatası gösterilir.

## Fiziksel Android cihaz

Aynı Wi-Fi'daki bilgisayarın gerçek LAN IPv4 adresini kullanın. Backend terminalinde `AllowedHosts` listesine bu IP'yi de ekleyip API'yi yeniden başlatın. Windows Firewall'da geliştirme portunu yalnızca gereken özel ağ için açın.

```powershell
# mobile dizininde; örnek IP yerine bilgisayarın gerçek adresini yazın:
$apiHostIp = Read-Host 'Bilgisayarin LAN IPv4 adresi'
flutter run -d <ANDROID_DEVICE_ID> --dart-define="API_BASE_URL=http://${apiHostIp}:5080" --dart-define=ALLOW_INSECURE_HTTP=true
```

DEVICE_ID için `flutter devices` kullanın. Alternatif USB `adb reverse tcp:5080 tcp:5080` ile cihazdan http://127.0.0.1:5080 kullanılabilir; ALLOW_INSECURE_HTTP yine gereklidir. İnternete açık üretim sunucusunda bu geliştirme HTTP ayarlarını kullanmayın.

## Üretim ve iOS

Gerçek HTTPS API origin'i dağıtım ortamından sağlanır; repo üretim URL'si varsaymaz. Base URL yalnızca scheme/host/port olabilir; /api yolu, query, fragment veya kullanıcı bilgisi eklenmez. Dart-define secret deposu değildir.

```powershell
cd mobile
# NETPUSULA_API_URL dağıtım ortamında gerçek https origin olarak tanımlanmış olmalı.
if (-not $env:NETPUSULA_API_URL -or -not $env:NETPUSULA_API_URL.StartsWith('https://')) { throw 'Gercek HTTPS API origin gerekli' }
flutter build appbundle --release --dart-define="API_BASE_URL=$env:NETPUSULA_API_URL"
```

Üretim imzalama/keystore ve dağıtım ayarları ayrıca yapılmalıdır; debug APK üretim paketi değildir. ALLOW_INSECURE_HTTP release/profile modunda etkisizdir. iOS'ta ATS gevşetilmedi; yerelde de cihazın güvendiği HTTPS sertifikası kullanın. Mac/Xcode üzerinde entitlement, signing, Keychain, gerçek cihaz session restore ve çıkış testlerini tamamlayın. Windows'ta iOS derlemesi yapılmadı.

## Manuel kabul akışı

1. Temiz kurulum → welcome; /home deep link'i içerik açmamalı.
2. Hatalı e-posta, boş alanlar, zayıf parola, eşleşmeyen tekrar → Türkçe alan hataları.
3. Kayıt → otomatik home; logout → welcome; aynı e-postayla kayıt → anlaşılır hata.
4. Giriş → home; uygulamayı tamamen kapat/aç → kısa splash ve /me sonrası home.
5. Yerel backend'de kısa access ömrü ayarlayıp süreyi bekle → refresh ve restore; expired refresh → tekrar giriş.
6. Ağ kapalı /me → retry splash; refresh sırasında ağ kesintisi → güvenli yeniden giriş.
7. Ağ kapalı logout → welcome, yerel oturum geri gelmemeli; sunucuda olası açık oturum uyarısı görünmeli.
8. Küçük ekran, büyük yazı, açık klavye, geri tuşu ve parola görünürlüğünü gerçek Android/iOS cihazda doğrulayın.

Otomatik testler gerçek backend gerektirmez. Detay ve çalıştırma sonuçları: [phase4-validation.md](phase4-validation.md).
