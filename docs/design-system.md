# NetPusula tasarım sistemi — Faz 9

## Değişiklik öncesi UI denetimi

Welcome, login, register, splash, preparation loading, onboarding/goal edit, home/dashboard, history, detail, mock create/edit, statistics ve chart; auth_widgets ortak bileşenleri incelendi.

- Tema yalnız seed, input ve iki button stilini kapsıyordu; yüzey/kart/chip/text-button hiyerarşisi varsayılana bırakılmıştı.

- Page padding 20/24, card padding 16/20, form boşlukları 6/28/40 gibi değerlerle ayrışıyordu. Dashboard/statistics aynı metric/title/card yapısını tekrar ediyordu.

- Loading spinner'ları farklı yerleşim ve semantics ile kullanılıyor, mock error salt metin, auth error başka biçimde gösteriliyordu.

- History trailing net büyük metinde ad/tarihle yatay alan yarışına giriyordu. Mock form girdileri bitişik, validation form sonundaydı; iki sayı alanının yerel hatası belirgin değildi.

- Mock ekranları sınırsız genişlikte, statistics SafeArea davranışı farklıydı. Auth keyboard scroll yapısı doğruydu; korunmalı.

- Dashboard aksiyonları bağlamdan önce yer alıyor, tüm kartlar benzer ağırlık taşıyordu. İstatistiklerde tüm metrikler eşit vurgudaydı.

- Hazırlık hedef alanının net suffix'i literaldi; seçim semantics Material radio/chip üzerinden vardı ama görsel seçili kart farkı azdı.

- Mevcut auth/state/validation/route iş akışları ve decimal-string sözleşmesi korunmalı; backend değişikliği gerekmiyor.

## İlkeler ve kapsam

İçerik önce gelir: hazırlık bağlamı, ana metrik, ilişkili eylemler ve ayrıntılar sırasıyla okunur. Dashboard kısa kalır; ayrıntılı analiz ayrı statistics rotasındadır. Renk performansı iyi/kötü diye sınıflandırmaz. Net, hedef farkı ve karşılaştırmalar backend değerleri olarak gösterilir; görsel çalışma yeni hesaplama veya öneri üretmez.

## Tema, tipografi ve ölçüler

`AppTheme` Material 3 ColorScheme.fromSeed (teal `#146C60`) kullanır. Açık zemin `#F3F7F5`, koyu zemin `#101917`; kart, input, border, hata ve metin renkleri semantic color scheme rollerindendir. Ana metrik primaryContainer/onPrimaryContainer ile vurgulanır. Gölge yerine ince kart sınırı kullanılır. Sistem durum çubuğu simgeleri de tema parlaklığına uyar.

Sistem fontu korunur; dış font/asset indirilmez. Başlıklar 32/26, ana sayısal değer 36, ikincil metrik 24, kart başlığı 20; body stillerinin satır yüksekliği 1.4–1.45. Sayılarda tabular figures kullanılır. Sabit yükseklikte metin kutuları yoktur.

`AppSpace`: 4/8/12/16/24/32. Sayfa yatay boşluğu ve kart içi 16, alt boşluk 32. İçerik maksimum 720, auth formu 480 logical pixel; dar ekranda mevcut genişliğe uyarlanır. `AppRadius`: kontrol 12, kart 20. Butonlar en az 48, primary/outlined 52 logical pixel yüksekliğindedir; icon butonları 48'dir.

## Ortak sunum bileşenleri

`core/widgets/app_components.dart` yalnız sunum içerir; repository/provider/router iş mantığı almaz.

- PageBody: safe area, merkezlenmiş üst hizalı sınırlı genişlik.

- pageAppBar: 64 yükseklik; büyük yazıda 112 ve iki satır başlık.

- AppCard / SectionHeader / MetricValue: ortak kart, semantic başlık ve sayısal hiyerarşi.

- AppMessage: ikon, metin, isteğe bağlı retry/CTA; hata için live region. Ham exception göstermez.

- AppLoading: spinner + yerelleştirilmiş bekleme semantics etiketi.

- SubmitContent: işlem sırasında düğme etiketini korur, spinner ve semantic bekleme durumu ekler. Busy disable mevcut controller durumuna bağlıdır.

- StepProgress: metinle adım/toplam ve görsel ilerleme; tek erişilebilir duyuru.

- MockSummaryCard: ad/tarih/net dikey akışı ve tüm karta dokunma; uzun isim/büyük yazıda trailing net sıkışması yoktur.

## Ekranlar

Welcome pusula işareti ve kısa değer cümlesi kullanır. Login/register mevcut Form, parola visibility, autofill ve keyboard scroll davranışlarını korur. Auth hata/submit ortak bileşenlerdedir.

Onboarding adımı görünürdür; seçili sınav kartı primaryContainer ile ayrılır. Hedef suffix'i localization'dan gelir. Tarih/geri/özet ve draft korunur.

Dashboard önce hazırlık bağlamını, sonra eylemleri gösterir; son deneme metrik kartı vurgulanır. Hedef farkı metin olarak kalır: negatif/üst hedef değerleri hatalı bir yüzde/progress geometrisine çevrilmez. Statistics range ve bölüm seçicileri Wrap akışında kalır, ortalama ana değerdir; en iyi deneme aynı summary kartını kullanır.

History ve detail ortak sayfa genişliği/spacing kullanır. Delete mevcut onay dialog'u ardından kısa snackbar verir. Mock formunda adım etiketi, sayı alanları arasında boşluk, bölüme yakın soru sınırı hatası ve klavye next/done eylemleri vardır. Drag klavyeyi kapatır; adım geçişi odağı kaldırır; busy sırasında sayı alanları kapalıdır. Edit draft ve create/edit API davranışı değişmez.

## Durumlar, grafik ve geri bildirim

Loading, boş veri ve hata ayrı kalır. Boş kart mevcut ekleme eylemini, hata mevcut retry'ı sunar. Yenileme hatası mevcut veriyi silmez. Mevcut auth/preparation guards yetkilidir.

NetTrendChart özel düz çizgi painter'ını korur; üç hafif yatay kılavuz okuma kolaylığı sağlar. Tek noktada açıklama gösterilir. Tarih/değer etiketleri, negatif aralık, opsiyonel hedef ve erişilebilir metin korunur. Yeni chart bağımlılığı, smoothing veya sahte trend yoktur. Cevap çubukları ayrı semantic etiketler taşır.

Yeni özel animasyon yoktur. Material'ın kısa yerleşik ripple/selection/route ve loading geri bildirimleri yeterlidir; sayıları veya grafikleri süsleyici animasyonlarla geciktirmeyiz.

## Erişilebilirlik ve responsive davranış

Başlık semantics, native radio/chip checked/selected durumları, live error/busy duyuruları, parola tooltip'leri ve chart açıklamaları korunur. Renk tek bilgi kanalı değildir. Önemli onSurface/onSurfaceVariant/onPrimary/onPrimaryContainer/error metin çiftleri açık/koyu temada en az 4.5:1 kontrast testiyle denetlenir.

320×640 logical pixel ve 1×/2× yazı ölçeğinde dokuz ekran test edilir. Scroll, Wrap, Expanded ve maksimum genişlik kullanılır; sabit iki sütun metrik düzeni dayatılmaz. Klavye görünürken form eylemleri kaydırılarak erişilebilir. Uzun listeler lazy kalır.

Sistem açık/koyu teması desteklenir; ayrı kalıcı ayar eklenmez. Koyu tema widget testinde kontrol edilir; gerçek cihaz/TalkBack kullanıcı testi yapılmış sayılmaz.

## Localization ve bakım

Kullanıcı metni ARB'de tutulur; generated localization dosyaları mevcut repo geleneğiyle korunur. `prepJourney`, `mockStep`, `mockCountsInvalid`, `mockDeleted`, `mockUpdated`, `chartSinglePoint` ve welcome tagline günceldir. Sayı/tarih formatı mevcut exact decimal/localized formatter'lardan gelir. Motivasyon metni puan/rank/başarı garantisi vermez. Yeni sunumlarda önce mevcut bileşen/token kullanılmalı; tek kullanımlık widget için genel framework büyütülmemelidir.

