# NetPusula — Google ile giriş kurulumu

28 Ekim 2026: Kullanıcı Web/server ve Android debug OAuth istemcilerini oluşturduğunu,
test kullanıcısını eklediğini bildirdi. Yerel `.env` içinde Google Auth etkinleştirildi
ve bildirilen Web Client ID audience olarak tanımlandı. Üretim varsayılanları kapalıdır.
Gerçek Google hesabıyla cihaz girişi henüz doğrulanmadı.

Güncel cihaz hazırlığı ve engeller: [Android Google test hazırlığı](google-android-validation.md).

## 1. Google Auth Platform

1. [Google Cloud Console](https://console.cloud.google.com/) içinde NetPusula için
   kullanacağınız projeyi seçin veya oluşturun. Android, iOS ve Web istemcileri
   aynı projeye ait olmalıdır.
2. **Google Auth Platform → Branding** altında uygulama adını `NetPusula`, destek
   e-postasını ve geliştirici iletişim adresini girin. Yayına hazırlanırken gerçek
   ana sayfa, gizlilik politikası ve kullanım şartları adreslerini ekleyin;
   olmayan URL'ler yazmayın.
3. **Audience** altında kişisel Google hesapları kullanılacaksa **External**
   seçin. Testing durumunda deneyeceğiniz Google hesaplarını test kullanıcısı
   olarak ekleyin. Internal yalnızca uygun Workspace kuruluşları içindir.
4. **Data Access**: kimlik için `openid`, `email`, `profile` yeterlidir. Bu
   uygulama Drive/Gmail/People API erişimi veya offline Google refresh token
   istemez. Ek kapsam açmayın.
5. Yayına geçmeden önce Console'un istediği doğrulama/yayın adımlarını tamamlayın.
   İstemci oluşturmak, uygulamanın doğrulandığı/yayımlandığı anlamına gelmez.

## 2. Web/server OAuth istemcisi

**Clients → Create client → Web application** ile örneğin
`NetPusula API` istemcisi oluşturun. Client ID'yi kaydedin.

- Bu ID Flutter'da `GOOGLE_SERVER_CLIENT_ID`, backend'de
  `GoogleAuth:Audiences:0` olarak **aynı değer** olmalıdır.
- Native SDK'dan alınan ID token'ı API'ye POST eden bu akışta tarayıcı redirect
  callback kullanılmıyor. Hayalî redirect URI eklemeyin.
- Client secret bu akışta kullanılmaz. Flutter'a, repoya veya sohbete eklemeyin.
- Client ID gizli anahtar değildir; yine de projeye sabitlenmez, derleme/ortam
  konfigürasyonuyla verilir.

## 3. Android OAuth istemcisi

**Clients → Create client → Android** seçin:

- Mevcut applicationId: `dev.netpusula.netpusula`
- Bu geliştirme bilgisayarının debug SHA-1:
  `1F:AE:40:2F:95:28:70:2F:2C:9D:81:53:CF:04:32:E5:89:BB:BA:68`
- Debug SHA-256:
  `28:13:4C:90:44:38:A2:04:A3:49:D8:2D:B4:78:2D:4C:A7:4C:EC:7E:C4:A1:18:38:5A:76:45:31:FA:73:EB:A2`

Bunlar 19 Ekim 2026 tarihinde yerel debug sertifikasından okundu; başka
bilgisayarda veya debug keystore yeniden oluşturulduğunda değişebilir. Yeniden
kontrol için:

```powershell
cd D:\Projects\NetPusula\mobile\android
.\gradlew.bat signingReport
```

Release ve Google Play App Signing sertifikaları debug sertifikasından farklıdır.
Her dağıtım sertifikasına uygun Android OAuth istemcisini aynı Cloud projesinde
tanımlayın. Play'de kullanıcıya dağıtılan uygulama için **app signing** SHA'sını
kullanın; yalnızca upload-key SHA'sı yeterli değildir.

Bu entegrasyonda `google-services.json` veya Firebase gerekmiyor.
Android OAuth client ID'yi `GOOGLE_SERVER_CLIENT_ID` olarak kullanmayın; oraya
**Web** client ID gelmelidir.

## 4. Backend

Önce mevcut veritabanının yedeğini ve doğru bağlantıyı kontrol edin. Yeni migration
`20261019161619_AddGoogleIdentity`, `Users.GoogleSubject` nullable `varchar(255)`
alanını ve unique index'i ekler. Mevcut e-posta/şifre hesaplarını değiştirmez.

```powershell
cd D:\Projects\NetPusula\backend
# ConnectionStrings__Database ve mevcut Jwt ayarları güvenli ortamdan sağlanmalı.
dotnet ef database update --project src/NetPusula.Infrastructure
```

API sürecine şu ortam ayarlarını verin:

```text
GoogleAuth__Enabled=true
GoogleAuth__Audiences__0=<WEB_CLIENT_ID>.apps.googleusercontent.com
```

Varsayılan `Enabled=false`, `Audiences=[]` güvenli kapalı durumdur. Enabled=true
iken boş/geçersiz audience konfigürasyonu başlangıç doğrulamasında reddedilir.
Gerekirse aynı uygulamaya ait başka Web client ID'ler `__1`, `__2` olarak
eklenebilir; wildcard veya Android/iOS istemcisini kabul listesi olarak kullanmayın.

Repodaki `.env` dosyası .NET tarafından kendiliğinden yüklenmez. Ortam değişkenleri
API'yi başlatan sürece aktarılmalı; production'da secret manager/deployment
konfigürasyonu kullanılmalıdır. Kimlik bilgilerini appsettings'e yazmayın.

API'nin Google'ın HTTPS discovery/JWKS adreslerine çıkışı ve doğru sistem saati
olmalıdır. Production API HTTPS kullanmalıdır. Google token'ını URL/query
parametresine koymayın veya request-body loglamasını açmayın.

## 5. Flutter / Android build

```powershell
cd D:\Projects\NetPusula\mobile
flutter pub get
flutter build apk --debug --dart-define=API_BASE_URL=https://<API_HOST> --dart-define=GOOGLE_SERVER_CLIENT_ID=<WEB_CLIENT_ID>.apps.googleusercontent.com
```

Gerçek ID'lerle yerel ignored bir `--dart-define-from-file` dosyası da
kullanılabilir. Client secret bu dosyada da gerekmiyor.

Mevcut USB geliştirme bağlantısında localhost HTTP yalnızca debug için açık
izinle kullanılabilir; bu bir production ayarı değildir:

```powershell
flutter build apk --debug --target-platform android-arm64 --dart-define=API_BASE_URL=http://127.0.0.1:5080 --dart-define=ALLOW_INSECURE_HTTP=true --dart-define=GOOGLE_SERVER_CLIENT_ID=<WEB_CLIENT_ID>.apps.googleusercontent.com
adb -s 155e6b22 reverse tcp:5080 tcp:5080
```

Release modunda `ALLOW_INSECURE_HTTP` etkisizdir. Uzak bir API'ye Google ID token
gönderirken HTTPS kullanın. Dart define değişiklikleri için yeniden build gerekir.

## 6. iOS — kimliği değiştirmeden hazırlık

Repoda mevcut Runner Bundle ID `dev.netpusula.netpusula`; bu aşamada
değiştirilmedi ve nihai App Store kimliği olarak varsayılmadı. Önce Apple
Developer/Xcode tarafındaki nihai Bundle ID'yi siz teyit edin.

1. Teyit edilen ID ile aynı Google Cloud projesinde **iOS** OAuth client oluşturun.
2. iOS client ID'yi `GOOGLE_IOS_CLIENT_ID` Dart define olarak verin.
3. Xcode Runner target Build Settings altında **tüm ilgili konfigürasyonlar**
   için `GOOGLE_REVERSED_CLIENT_ID` user-defined ayarını tanımlayın:
   `com.googleusercontent.apps.<iOS-client-ID-prefix>`.
4. `Info.plist` içindeki `CFBundleURLSchemes`, bu build setting'i kullanır.
   Web client ID'nin tersini kullanmayın. Ayarı boş bırakıp Google girişini
   etkinleştirmeyin; URL scheme native SDK için zorunludur.
5. Web/server ID'yi de sağlayın:

```text
--dart-define=GOOGLE_SERVER_CLIENT_ID=<WEB_CLIENT_ID>.apps.googleusercontent.com
--dart-define=GOOGLE_IOS_CLIENT_ID=<IOS_CLIENT_ID>.apps.googleusercontent.com
```

Mac üzerinde CocoaPods/Xcode kurulumu ve gerçek cihaz testi ayrıca yapılmalıdır.
Bu Windows oturumunda iOS build yapılmadı. iOS sürümünü yayımlamadan önce
Apple'ın üçüncü taraf giriş için geçerli App Review gereksinimlerini ayrıca
değerlendirin; bu aşamada Apple ile giriş eklenmedi.

## 7. Hesap güvenliği politikası

- `POST /api/auth/google` yalnızca `{ "idToken": "..." }` alır.
- İmza Google'ın HTTPS üzerinden alınan anahtarlarıyla RS256 olarak doğrulanır.
  Issuer, izin verilen audience, expiration/not-before, `sub`, geçerli e-posta
  ve `email_verified=true` zorunludur. Token'daki key URL'lerine güvenilmez.
- Kalıcı eşleştirme **Google sub** üzerinden yapılır. E-posta ile otomatik
  bağlama yapılmaz. İlgili e-posta başka hesaba aitse `409 google_conflict`;
  kullanıcı mevcut giriş yöntemini kullanmalıdır.
- Manuel hesap bağlama/birleştirme bu aşamada yoktur. Gelecekte eklenirse her iki
  hesabın sahipliği ayrıca doğrulanmalıdır.
- Yeni Google hesabının şifresi yoktur; rastgele/sabit ortak şifre oluşturulmaz.
  Şifreli giriş böyle bir hesap için reddedilir.
- Tekrarlanan giriş aynı sub'u kullanır. Google'daki ad/e-posta değişikliği yerel
  hesabı başka hesaba taşımaz; profil otomatik güncellenmez.
- Doğrulanmış Google e-postası, başka bir yerel hesabın sahipliğine kanıt sayılmaz.
  Google dışı e-posta sağlayıcılarında `email_verified` güncel posta kutusu
  sahipliğine kalıcı garanti değildir; bu yüzden de otomatik bağlama yoktur.
- API kendi access JWT + refresh token çiftini üretir. Mevcut secure storage,
  refresh rotation, token-family replay revocation ve logout korunur.
- Google ID token saklanmaz/loglanmaz ve uygulama API'sine Bearer token olarak
  kabul edilmez. Google API access token/offline refresh token istenmez.
- Kullanıcının iptalinde hata gösterilmez. Eksik ayar/sağlayıcı hatası veya ağ
  sorunu hesap açılması gibi gösterilmez.

## 8. Gerçek cihaz doğrulama listesi

Console ayarları tamamlandıktan sonra:

1. Test kullanıcısıyla hem giriş hem kayıt ekranından Google hesap seçicisini açın.
2. İptalde ekranda hata/oturum oluşmadığını doğrulayın.
3. Yeni hesapta onboarding, aktif hazırlığı bulunan tekrar girişte ana sayfa
   açılmalıdır. Uygulamayı kapatıp açınca mevcut session restore çalışmalıdır.
4. Aynı e-postalı şifreli hesapta otomatik bağlama olmadan açıklama çıkmalıdır;
   e-posta/şifre girişi çalışmaya devam etmelidir.
5. Çıkış, tekrar giriş/başka hesap seçimi, ağ kesintisi ve refresh deneyin.
6. API loglarında token, şifre veya provider claim'leri bulunmamalıdır.
7. Debug ve release imzalarıyla ayrı ayrı deneyin; iOS'u Mac/gerçek cihazda test edin.

Android SDK bazı yanlış SHA/package/server-ID durumlarını da `canceled` olarak
bildirebilir. Hesap seçtikten sonra sürekli sessiz dönüş oluyorsa önce Console
eşleşmelerini kontrol edin; plugin bunu gerçek iptalden ayıramayabilir.

## Resmî kaynaklar

- [Flutter Google Sign-In](https://pub.dev/packages/google_sign_in)
- [Android kurulumu ve hatalar](https://pub.dev/packages/google_sign_in_android)
- [iOS kurulumu](https://pub.dev/packages/google_sign_in_ios)
- [Backend token doğrulama](https://developers.google.com/identity/sign-in/web/backend-auth)
- [Google marka kuralları](https://developers.google.com/identity/branding-guidelines)

Google düğmesinin renkli G asset'i bu son kaynağın yayımladığı
`https://developers.google.com/static/identity/images/g-logo.png` dosyasıdır;
yeniden çizilmedi.
