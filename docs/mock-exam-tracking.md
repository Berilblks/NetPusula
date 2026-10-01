# Faz 6 — Deneme takibi

## API ve sahiplik

Tüm `/api/mock-exams` uç noktaları JWT gerektirir. Yanıtlar `no-store`; üretimde HTTPS zorunludur. Kullanıcı JWT subject üzerinden, sahiplik MockExam → UserExam.UserId üzerinden çözülür. Request DTO'ları EF entity değildir; bilinmeyen alanlar kökte ve sonuç satırlarında 400 döndürür. `userId`, `userExamId`, `examId`, `net`, `totalNet` istemciden atanamaz.

| Yöntem / yol | Başarı | Davranış |
| --- | --- | --- |
| GET /api/mock-exams?page=1&pageSize=20 | 200 | Yalnız aktif hazırlık; items/page/pageSize/totalCount/totalPages |
| GET /api/mock-exams/{id} | 200 | Sahibe ait tarihsel kayıt ve bölüm sonuçları |
| POST /api/mock-exams | 201 + Location | Aktif UserExam sunucudan çözülür |
| PUT /api/mock-exams/{id} | 200 | Aynı aggregate ve tarihsel bölüm kümesi güncellenir |
| DELETE /api/mock-exams/{id} | 204 | Sahibe ait aggregate transaction içinde silinir |

Yabancı ve bulunamayan kimlikler aynı 404'ü verir. Liste/oluşturma için aktif hazırlık yoksa 409 ProblemDetails ve `code: active_preparation_required` döner. Sahip eski/inaktif hazırlığındaki kaydı doğrudan kimliğiyle okuyabilir, düzenleyebilir ve silebilir; liste eski hazırlıkları göstermez. Aktif sınav devre dışıysa veya hiç etkin bölümü yoksa oluşturma 409 verir. Diğer doğrulama hataları 400; beklenmeyen hatalar ayrıntısız 500'dür.

POST ve PUT örneği:

```json
{
  "name": "Türkiye Geneli Deneme 1",
  "takenAt": "2026-09-29",
  "notes": "Süre yönetimine dikkat",
  "results": [
    { "examSectionId": "<bölüm-uuid>", "correctCount": 42, "wrongCount": 6, "blankCount": 2 }
  ]
}
```

Örnekteki satır her yapılandırılmış etkin bölüm için tekrarlanır. Ad trim sonrası 1–200 karakter, not en çok 4000 karakterdir; boş not null olur. Sonuç kümesi 1–100 satırdır; bölüm atlanamaz, mükerrer/yabancı/inaktif bölüm eklenemez. Düzenlemede mevcut tarihsel sonuç kümesinin tamamı gerekir; yeni katalog bölümünü eski denemeye sonradan eklemez.

Detay: id, name, takenAt, notes, totalNet, results. Her sonuç: examSectionId, sectionCode, sectionName, groupCode, groupName, questionCount, correctCount, wrongCount, blankCount, net. Liste kartı: id, name, takenAt, totalNet, createdAtUtc. Sahiplik kimlikleri ve bölen gibi iç yapılandırma alanları DTO'da yoktur.

## Boş sayısı ve decimal net

Doğru/yanlış negatif olmayan tamsayıdır. Sunucu `blank = questionCount - correct - wrong` hesaplar. `blankCount` opsiyoneldir; gönderilirse hesaplanan değere eşit olmak zorundadır. Böylece kaydedilen üç sayı soru sayısını tam karşılar. Flutter yalnız doğru/yanlış girişi ister ve boşu gösterir; API yine bağımsız doğrular. Önceki domain net hesaplayıcısının `toplam <= soru sayısı` semantiği, önceki tarihsel kayıtları bozmamak için değişmedi; yeni API daha sıkıdır.

Mevcut decimal `NetCalculator`: `correct - wrong / penaltyDivisor`. Sonuç.Net, kaydın soru/bölen snapshot'ını kullanır. TotalNet, sayfaya/detaya alınan sonuçların decimal toplamıdır; Net ve TotalNet sütunları yoktur. Erken yuvarlama yoktur. Yeni deneme DTO'larının `net` ve `totalNet` alanları JSON decimal **metinleri** (`"40.5"`, `"81.0"`) olarak gider. Bu, Flutter JSON double dönüşümünün hassasiyet kaybını önler. Mobil bu metni BigInt ile yalnız gösterim için iki ondalığa yarımdan yukarı yuvarlayıp virgülle biçimler; iş hesabı/yerel net önizlemesi yoktur. Bölüm bazında yuvarlanmış gösterimlerin toplamı bazı bölenlerde toplam gösteriminden 0,01 farklı olabilir; otorite sunucunun yuvarlanmamış decimal toplamıdır.

## Snapshot ve migration

Sayısal snapshot'lar korunur: QuestionCountSnapshot, PenaltyDivisorSnapshot. Yeni alanlar: SectionCodeSnapshot, SectionNameSnapshot, GroupCodeSnapshot, GroupNameSnapshot, SortOrderSnapshot. Bölüm kimliği ve ExamId mevcut FK'larla korunur. Bunlar oluşturulurken kopyalanır; edit yalnız cevap sayılarını değiştirir. Katalog ad/bölen/soru sayısı veya etkinlik değişikliği geçmiş anlamı değiştirmez.

Gerçek EF tooling ile oluşturulan `20261001114310_SnapshotMockSectionDisplay` yalnız beş gösterim alanını ekler. Eski sonuçların gösterim bilgisi migration anındaki referans katalogdan doldurulur; migration öncesinde değişmiş eski bir adın geçmiş sürümü geri kazanılamaz. Sayısal snapshot'lar değiştirilmez. Önceki migration'lar değişmedi. FK RESTRICT davranışları korunur.

## Tarih

API `takenAt` alanı `yyyy-MM-dd` DateOnly'dir; timestamp kabul edilmez. Bugün Türkiye takvimidir (mevcut UTC+3 PreparationRules); ileri gün reddedilir. Veritabanındaki mevcut TakenAtUtc sütunu korunur, yeni API günü UTC 00:00 olarak kodlar; istemci bunu yerel saate çevirmez. Önceki doğrudan domain kayıtları UTC gününe göre gösterilir, yıkıcı tarih migration'ı yapılmaz. Flutter takvim seçicisi cihazın bugününü üst sınır yapar; sunucu Türkiye gününü tekrar doğrular.

## Transaction, sıralama ve silme

Create/edit tek transaction içindedir, tüm satırlar önce doğrulanır. PostgreSQL'de kullanıcı satırı FOR UPDATE kilidi, hazırlık değişimi ve aynı kullanıcının create/edit/delete işlemleriyle sıralanır. SQLite test sağlayıcısı PostgreSQL kilit davranışını kanıtlamaz. Edit eşzamanlılığında son tamamlanan geçerli yazım kazanır; sürüm/ETag çatışma çözümü yoktur.

Silme önce yalnız ilgili sonuçları, sonra ilgili MockExam'i siler; iki SaveChanges aynı transaction'dadır. Üst kaydın silinmesi başarısızsa çocuk silmeleri de geri alınır. Kullanıcı, hazırlık, sınav ve bölüm kayıtları silinmez; hiçbir FK kısıtı gevşetilmez.

Liste takenAtUtc DESC, createdAtUtc DESC, id DESC sırasındadır. Varsayılan page=1/pageSize=20, en çok 100; geçersiz veya offset taşıran değerler 400'dür. Boş listede totalPages=0. Belleğe yalnız sayfadaki denemelerin sonuçları alınır. Offset sayfalama eşzamanlı ekleme/silme sırasında sayfa sınırlarını kaydırabilir; yeniden açma listeyi yeniler.

## Flutter

Rotalar: `/mock-exams`, `/mock-exams/new`, `/mock-exams/:id`, `/mock-exams/:id/edit`. Hazırlık/auth guard'ları korunur. Home'da Deneme Ekle ve Deneme Geçmişi vardır; dashboard/alt navigasyon yoktur.

MockExamRepository yalnız HTTP/DTO dönüşümü yapar. Riverpod history controller sayfa/yükleme/hata durumunu; detail FutureProvider tek kaydı; draft FutureProvider form taslağını; mutation controller tek devam eden save/delete işlemini yönetir. Widget'lar repository'yi doğrudan çağırmaz. Kullanıcı veya hazırlık değişiminde provider bağımlılıkları cache/taslağı sıfırlar; epoch ve mounted kontrolleri geç yanıtın eski oturumu yeniden doldurmasını önler. Save/delete history ve detail provider'larını geçersiz kılar.

Form: genel bilgi → API'den bölüm/grup metadata'sı → kontrol → sunucu sonucu. Adımlar ve hatalar aynı taslağı korur; edit sayısal kuralları ve başlıkları detay snapshot'ından yükler. Backend neti gelmeden final net gösterilmez. Kaydetme devam ederken tekrar gönderim ve geri çıkış kapalıdır. Silme ayrı açıklamalı onay ister; hata halinde detay korunur. Route'tan çıkınca taslak dispose edilir; yeniden başlatmalar arası offline kayıt yoktur.

400/401/404/409/429/5xx ve ağ/timeout hataları Türkçe güvenli mesajlara çevrilir. Yalnız açık `active_preparation_required` kodu hazırlığı tekrar kontrol etme eylemi sunar; onboarding yönlendirmesi /active 204 ile doğrulanır. Ağ hatası hazırlık yok sayılmaz. Raw exception/token/UI log eklenmedi.

## Sınırlar ve manuel kontrol

Mevcut katalog yalnız ALES bölümlerini içerir; diğer sınavların bölüm sayıları uydurulmaz, boş katalog güvenli mesaj gösterir. Grup metadata'sı dinamik render edilir; TYT/AYT kuralı hardcode edilmez.

POST devam ederken çift dokunma engellenir; yanıt kaybolduktan sonraki manuel tekrar için sunucu idempotency key yoktur. Belirsiz ağ hatasında tekrar kaydetmeden geçmişi kontrol etmek gerekir. Mobil cihaz/emulator ile gerçek API uçtan uca testi, gerçek PostgreSQL kilit/transaction testi ve iOS build ayrıca gereklidir.

Docker Linux engine açıldıktan sonra bağlantı bilgisini ortam değişkeniyle sağlayın, backend dizininde `dotnet ef database update --project src/NetPusula.Infrastructure` komutunu iki kez çalıştırın. Auth, tek aktif hazırlık index'i, yeni mock create/edit/delete ve eşzamanlı hazırlık değişimini gerçek PostgreSQL'de doğrulayın. Secret'ları kaynak dosyasına koymayın.
