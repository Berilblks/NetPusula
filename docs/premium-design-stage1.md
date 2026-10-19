# Premium tasarım yenileme — Aşama 1

## Kapsam

Marka paleti, pusula/wordmark varyasyonları, Android/iOS uygulama ikonları ve ana
sayfanın sunumu yenilendi. Başlangıçta çalışma ağacı temizdi. Backend, veritabanı,
migration, API sözleşmeleri, Riverpod provider/repository sınıfları, route guard'ları
ve bağımlılık sürümleri değiştirilmedi. Commit/push yapılmadı.

Giriş/kayıt, onboarding, deneme formu/detayı, detaylı istatistik ve hedef düzenleme
sayfaları yeniden tasarlanmadı; merkezi Material 3 temasının renklerini devralırlar.

## Marka ve asset'ler

- `BrandColors`, istenen dokuz rengi merkezi olarak tanımlar. Küçük ikincil metinde
  kontrast için `#686583` kullanılır; referans `#77759A` token olarak korunur.
- Sistem dark mode desteği korunur; koyu yüzeyler ve lavanta ön plan kullanılır.
- Ad: **NetPusula**. Slogan: **Sınav yolculuğunda yanında.**
- Kullanıcının birleşik referans görseli geçici dosyada mevcuttu; repoda özgün
  SVG/AI veya ayrı yüksek çözünürlüklü logo/ikon master'ı yoktu.
- `CompassPainter` referanstaki pusula ve parıltının yerel vektör uyarlamasıdır.
  Özgün tasarım dosyasının birebir kopyası olduğu iddia edilmez. Sonraki marka
  onayında özgün master dosyası sağlanırsa bununla değiştirilebilir.
- `mobile/assets/brand/`: açık/koyu wordmark, şeffaf pusula varyasyonları ve 1024px
  ikon. Wordmark sloganı içerir; uygulama ikonunda yazı yoktur.
- Ana sayfa pusulayı doğrudan vektör çizer. Marka PNG master'ları çalışma asset'idir;
  kullanılmayan büyük PNG'ler Flutter asset bundle'a eklenmedi.
- Android adaptive icon: lacivert arka plan + şeffaf ön plan, güvenli alan içinde
  pusula. Yuvarlatma cihaz launcher maskesine bırakılır. Eski Android için density
  mipmap'leri, iOS için mevcut AppIcon kataloğunun bütün boyutları yenilendi.
  iOS köşeleri sistem tarafından maskelenir; iOS ikonları opaktır.
- Yeniden üretim: `cd mobile; flutter test tool/export_brand.dart`. Çizim Flutter
  canvas'ını ve SDK'nın Roboto fontunu kullanır; yeni paket gerektirmez.

## Ana sayfa ve gerçek veriler

- Karşılama adı mevcut authenticated-user state'inden gelir.
- Sınav, hedef, son/ortalama/en iyi net, deneme sayısı, hedef farkı ve kısa dönem
  değişimi mevcut dashboard API DTO'sundan okunur. Sabit örnek net/yüzde yoktur.
- Decimal-string skorlar mevcut `Score.display` / `NetTarget` biçimleyicileriyle
  gösterilir. Yeni ortalama, net farkı veya performans yüzdesi hesaplanmaz.
- Daire için yalnızca çizim oranı `latest / target`, 0–1 aralığına sınırlandırılır.
  Negatif net metinde korunur; daire negatif çizilmez. Hedef aşılırsa sunucunun
  işaretli farkı mevcut “Hedefin üzerinde” metniyle gösterilir.
- Mini grafik mevcut kronolojik serinin son en fazla beş noktasını kullanır.
  Ana grafik API'nin sağladığı seriyi ve hedef referansını kullanır. Düz çizgiler
  korunur; yalnızca ana sayfada sıfır tabanına yarı saydam mor alan dolgusu eklenir.
  İstatistik detay ekranındaki grafik varsayılan sunumu değişmedi.
- Yetersiz karşılaştırma verisi `—` ve mevcut açıklamayla gösterilir. Boş durum
  ilk denemeyi ekleme eylemini sunar; hata boş veri olarak gösterilmez.
- Pull-to-refresh, hata/tekrar deneme, aktif hazırlık/auth kontrolleri, mevcut
  invalidation ve çıkış işlevleri korunur.

## Navigasyon ve erişilebilirlik

Alt menü yalnızca mevcut rotaları kullanır: Ana Sayfa (başa kaydır), Denemeler,
ortada Ekle, Hedef ve İstatistik. Profil rotası mevcut olmadığından sahte Profil
sayfası/butonu eklenmedi. Detaylı İstatistikler bağlantısı, yakın denemeler ve
bölüm sonuçları erişilebilir kalır. Bu aşamada diğer ekranlara ortak alt menü
eklenmedi.

SafeArea, ekran okuyucu etiketleri/eylemleri, gerçek grafik değerlerinin semantiği,
dar ekranda dikey yerleşim ve büyük metinde tek sütun özet kartları kullanılır.
320px / 2x yazı testleri ve mevcut tema kontrast testleri geçer.

## Doğrulama (2026-10-19)

- `flutter gen-l10n`: başarılı.
- `flutter analyze`: **No issues found**.
- `flutter test`: **222/222** başarılı (önceki 215 + 7 yeni test).
- Marka üreticisi: **1/1** başarılı; platform ikonları üretildi.
- Açık/koyu 390×844 fixture önizlemeleri görsel olarak incelendi. Bunlar test
  fixture'larıdır; uygulama çalışma zamanı örnek verilerle değiştirilmedi.
- Android arm64 debug APK başarıyla derlendi:
  `flutter build apk --debug --target-platform android-arm64 --dart-define=API_BASE_URL=http://127.0.0.1:5080 --dart-define=ALLOW_INSECURE_HTTP=true`.
- `git diff --check`: whitespace hatası yok. Git'in mevcut LF/CRLF
  normalizasyon bildirimi dışında hata yok.
- İlk çalıştırmalarda hedef metninin test eşleşmesi, büyük yazı taşmaları ve
  iki stil lint'i bulundu; düzeltildi, son analiz/testler başarılı.
- iOS ikonları üretildi; Windows ortamında iOS build/cihaz testi yapılmadı.
- Son cihaz kontrolünde Redmi bağlı değildi; yalnızca emulator-5554 görünüyordu.
  Yeni APK telefona kurulmadı. USB testinde telefon tekrar bağlanmalı ve mevcut
  yerel backend için `adb -s 155e6b22 reverse tcp:5080 tcp:5080` kullanılmalıdır.
  Bu debug APK localhost geliştirme bağlantısını kullanır; yayın sürümü değildir.
- APK, önizlemeler ve test/build logları `mobile/build/` altında ignored kalır.

## Değişen dosyalar

- `mobile/lib/core/constants/app_brand.dart`
- `mobile/lib/core/theme/app_theme.dart`, `design_tokens.dart`
- `mobile/lib/core/widgets/compass_mark.dart` (yeni)
- `mobile/lib/features/auth/presentation/home_screen.dart`
- `mobile/lib/features/dashboard/presentation/premium_widgets.dart` (yeni)
- `mobile/lib/features/dashboard/presentation/net_trend_chart.dart`
- `mobile/lib/l10n/app_tr.arb`, `app_localizations.dart`, `app_localizations_tr.dart`
- `mobile/test/dashboard_test.dart`, `premium_home_test.dart` (yeni)
- `mobile/tool/export_brand.dart` (yeni)
- `mobile/assets/brand/{app-icon,compass-light,compass-dark,logo-light,logo-dark}.png`
- Android: beş `mipmap-*/ic_launcher.png`, beş yeni `ic_launcher_foreground.png`,
  yeni `mipmap-anydpi-v26/ic_launcher.xml`, `values/brand_icon.xml`.
- iOS: mevcut `AppIcon.appiconset` içindeki 15 PNG.
- Bu rapor: `docs/premium-design-stage1.md`.

Sonraki tasarım aşamasına geçilmedi. Değişiklikler inceleme için uncommitted bırakıldı.
