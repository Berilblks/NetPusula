# iOS A1 — Native proje ve imzasız CI

30 Ekim 2026; temel `ee3b930`. Önceki [teknik denetim](ios-release-readiness.md) değişiklik öncesi durumu belgeler; bu belge A1 güncellemesidir.

## Araç zinciri kararı

- Yerel Windows: Flutter **3.29.0**, Dart **3.7.0**; SDK değiştirilmedi.
- iOS CI: Flutter **3.38.0** (kendi Dart SDK'sı ile), Xcode **26.3**, `macos-26`, CocoaPods **1.16.2**.
- Flutter 3.35 duyurusu Xcode/iOS 26 beta uyum çalışmalarını anlatır; tam destek için resmi 3.38 duyurusu 3.38+ önerir. Dolayısıyla 3.29'un Xcode 26 uyumlu olduğu varsayılmadı; 3.38.0 bu işte açıkça sabitlenen doğrulama tabanıdır, bütün uygulama için doğrulanmış SDK yükseltmesi değildir. [Flutter 3.38](https://flutter.dev/blog/whats-new-in-flutter-3-38)
- Runner imajında Xcode 26.3 yolu mevcut olarak belgelenmiştir. İmaj değişkendir; sürüm kalkarsa workflow bilinçli olarak durur, sessizce başka Xcode'a geçmez. [GitHub macOS runner envanteri](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)

## iOS minimumu ve konfigürasyonlar

Minimum **iOS 13.0**. Apple'ın güncel minimum hedef şartını ve seçilen Flutter tabanını karşılar. Mevcut native paket podspec minimumları 12.0 olduğundan bu sınırın altına inilmez. [Apple şartları](https://developer.apple.com/news/upcoming-requirements/)

Project Debug/Profile/Release hedefleri, AppFrameworkInfo.plist ve Podfile 13.0'dır. Runner ve RunnerTests proje seviyesinden miras alır; daha düşük target override bulunmuyor. Pod post_install yalnız 13.0'dan düşük native hedefleri yükseltir, gelecekte daha yüksek minimum isteyen paketi zorla düşürmez. Böyle bir paket ilk çözümlemede çıkarsa yeniden değerlendirilir.

Debug ve Release xcconfig dosyalarına ilgili Pods config include'u eklendi. Profile için ayrı Profile.xcconfig ve pbxproj referansı eklendi; Profile artık yanlışlıkla Release Pods ayarına dayanmaz. Generated.xcconfig Flutter tarafından üretilecek ve ignore kapsamında kalacaktır. Bundle ID, Google URL scheme, auth kodu ve signing ayarları değiştirilmedi.

## Native yöntem: CocoaPods

Mevcut Flutter 3.29 ve CI 3.38 tabanıyla, kurulu Google Sign-In/secure storage/path provider paketlerinin podspec desteğini kullanan en küçük değişiklik seçildi. Podfile Flutter podhelper'ını kullanır; RunnerTests search path'lerini miras alır ve Flutter build ayarlarını uygular. Native bağımlılıkların Xcode projeye eklenmesini pod install yapar; Windows'ta Pods dosyaları taklit edilmedi.

SPM uzun vadeli alternatiftir; güncel Flutter belgelerinde 3.44 itibarıyla varsayılan olduğu ve desteklemeyen paketlerde CocoaPods fallback kullanıldığı belirtilir. A1'de SDK yükseltmesi ve SPM geçişi birlikte yapılmadı. CI SPM'yi açıkça kapatır. CocoaPods registry'nin 2 Aralık 2026 için duyurulan read-only geçişi nedeniyle sonraki SDK yükseltmesinde SPM tekrar değerlendirilmeli. [Flutter SPM](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers)

**Tekrarlanabilirlik sınırı:** Flutter/Xcode/CocoaPods sürümleri sabit; hosted macOS imajı ve CocoaPods transitif Ruby bağımlılıkları tam kilitli değil. Podfile.lock henüz yok, Windows'ta üretilmedi. İlk CI pod install çözümlemesini ve yeni Flutter'ın pubspec.lock sonucunu artifact olarak saklar. İncelenmiş Podfile.lock uygulama kaynağı olarak sonraki onaylı değişiklikte tutulmalı; Pods/build klasörleri tutulmamalı. Lock mevcut olduğunda workflow `pod install --deployment` ile drift'i reddeder. Yeni Flutter'ın SDK-pinli Dart bağımlılıkları mevcut lock'u değiştirebilir; CI analyze/test bu çözümün kabul kapısıdır, sonuçları henüz bilinmiyor. İlk bootstrap çalışmasını tam kilitli yayın hattı olarak kabul etmeyin.

## Workflow nasıl çalıştırılır?

Dosya: `.github/workflows/ios-unsigned.yml`; ad: **iOS unsigned readiness**.

1. Bu aşamada commit/push yapılmadığından GitHub'da henüz çalıştırılamaz. Kullanıcı sonraki aşamada onaylayıp workflow'u varsayılan dala gönderdiğinde görünür olur.
2. GitHub → Actions → iOS unsigned readiness → Run workflow → istenen branch → Run workflow.
3. macOS Actions erişimi ve özel repo dakika/bütçe hakkı gerekli. Apple hesabı, signing secret veya production bilgisi gerekli değil.
4. Workflow Xcode sürümünü kontrol eder, Flutter'ı kurar, iOS cache/pub get/gen-l10n/analyze/test çalıştırır. CocoaPods kurar, Podfile Ruby syntax ve plist/pbxproj doğrular, pod install çalıştırır; üç konfigürasyonun native build settings çıktısını kontrol eder.
5. `flutter build ios --release --no-codesign` çalışır. `API_BASE_URL=https://example.invalid` yalnız derleme placeholder'ıdır; gerçek API bağlantısı veya Google login testi yapmaz. Google client ID'leri A1'de enjekte edilmez. Auth akışı değiştirilmez.
6. Başarı halinde `ios-unsigned-app` zip'i ve `ios-dependency-resolution` artifact'ları 7 gün tutulur. Çıktı **imzasız Runner.app**, cihazda kurulabilir IPA değildir. App Store/TestFlight upload veya sertifika üretimi yok.

Workflow yalnız `workflow_dispatch` ile tetiklenir; push/PR otomatik maliyet oluşturmaz. Repository erişimi read-only; checkout credential kalıcılığı kapalı. Flutter'ın çağırdığı pod da pinned wrapper üzerinden 1.16.2 kullanır. CocoaPods/generated workspace değişiklikleri CI checkout'unda kalır, workflow repo'ya yazmaz.

## Doğrulama

Windows statik kontrolü: üç deployment target, plist minimumu, xcconfig/ID eşleşmeleri, workspace/scheme XML ve workflow YAML yapısı başarılı. Bunlar Xcode parser/build doğrulamasının yerini tutmaz.

Yerel Windows sonuçları (Flutter 3.29.0 / Dart 3.7.0):

- `flutter analyze`: temiz.
- `flutter test --concurrency=1`: 251/251 başarılı.
- `dotnet test`: 217/217 başarılı. Çalışan backend çıktılarıyla çakışmamak için `BaseOutputPath=backend/obj/link-validation/bin/` kullanıldı; kullanıcı veritabanında işlem yapılmadı.
- `git diff --check`: başarılı; Git yalnız mevcut CRLF dönüşüm uyarısını bildirdi.
- Workflow YAML ve tüm run adımlarında `bash -n`: başarılı.
- Generated.xcconfig, Pods ve build artifact'larının ignore kapsamında olduğu doğrulandı.

Bu sonuçlar CI için seçilen Flutter 3.38.0'ın başarılı çalıştığını göstermez; o sürümün analyze/test ve native build sonuçları ilk macOS çalıştırmasında alınacak.

macOS'ta henüz doğrulanmayanlar: Flutter 3.38 üzerinde tüm analiz/testler, Ruby/Podfile çalışması, pod dependency çözümü, Xcode proje entegrasyonu ve üç konfigürasyonun effective build settings'i, release unsigned build, archive/SDK uyumu. Signing, cihaz Keychain/Google callback ve TestFlight A1 dışındadır.

## Dosya kapsamı

- `mobile/ios/Runner.xcodeproj/project.pbxproj`
- `mobile/ios/Flutter/AppFrameworkInfo.plist`
- `mobile/ios/Flutter/Debug.xcconfig`
- `mobile/ios/Flutter/Release.xcconfig`
- `mobile/ios/Flutter/Profile.xcconfig` (yeni)
- `mobile/ios/Podfile` (yeni)
- `.github/workflows/ios-unsigned.yml` (yeni)
- `docs/ios-native-a1.md` (bu belge)

Önceden untracked olan `docs/ios-release-readiness.md` korundu. Backend, veritabanı, migration, kullanıcı verileri, Dart auth kodu ve dependency sürümleri bu işte değiştirilmedi. Commit/push yapılmadı.
