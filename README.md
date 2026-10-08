# FileFlyfer

**Türkçe** | [English](README.en.md)

[![MIT Lisansı](https://img.shields.io/badge/lisans-MIT-blue.svg)](LICENSE) [![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black)](#gereksinimler)

FileFlyfer, USB ile bağlanan Android telefonların ortak depolama alanını Mac'ten yönetmek için hazırlanmış ücretsiz ve açık kaynaklı bir macOS uygulamasıdır. Dosya aktarımını Android Debug Bridge (ADB) ile yapar; telefona ek uygulama kurmaz ve root erişimi istemez.

## Özellikler

- Bağlı Android cihazları bulma ve birden fazla cihaz arasında seçim yapma
- Cihaz modeli, adı ve Android sürümünü görüntüleme
- `/sdcard` klasörlerinde gezinme, konum yolunu izleme ve klasörleri favorilere ekleme
- Dosyaları ada, türe, boyuta ve değiştirilme tarihine göre görme
- Dosyaları Mac ile telefon arasında tek tek veya çoklu aktarma; sürükle ve bırak desteği
- Sıralı aktarım kuyruğunu iptal etme
- Telefonda klasör oluşturma, dosya veya klasör adını değiştirme ve onayla silme
- Aynı adda dosya varsa üzerine yazma, atlama veya yeni ad verme
- Türkçe karakter ve diğer Unicode dosya adlarını güvenli işleme

ADB güvenilir bir yüzde bilgisi sağlamadığı için aktarım sırasında sahte yüzde gösterilmez.

## Gereksinimler

- macOS 13 veya sonrası
- Xcode 15 veya sonrası (Xcode projesiyle çalıştırmak için)
- Swift 6 araç zinciri (Swift Package Manager ile derlemek için)
- Android SDK Platform-Tools içindeki `adb`
- USB hata ayıklaması açık ve kilidi açılmış bir Android cihaz

ADB'yi Android Studio'nun SDK Manager bölümünden veya Android SDK Platform-Tools paketinden yükleyin. Uygulama ADB'yi `ADB_PATH`, yaygın Homebrew yolları ve `~/Library/Android/sdk/platform-tools/adb` konumlarında arar. ADB farklı bir yerdeyse yolunu `ADB_PATH` ile belirtebilirsiniz.

## İndirip çalıştırma

GitHub deposunda **Code → Download ZIP** ile kaynak kodu indirebilir veya **Code** menüsündeki HTTPS adresini kullanabilirsiniz:

```sh
git clone <GitHub'daki-depo-HTTPS-adresi>
cd FileFlyfer
```

Xcode projesini açın, `FileFlyfer` şemasını seçin ve **Run** düğmesine basın:

```sh
open FileFlyferXcode/FileFlyferXcode.xcodeproj
```

Xcode ilk açılışta geliştirme için yerel imza ayarlamanızı isteyebilir. ADB kurulu değilse telefon bulunamaz; yukarıdaki gereksinimlerde anlatıldığı gibi Platform-Tools'u kurun.

## Komut satırından derleme

Swift 6 yüklü macOS'te proje kökünde:

```sh
swift build
swift run FileFlyfer
```

Testleri çalıştırmak için:

```sh
swift test
```

ADB yolu standart konumlarda değilse:

```sh
ADB_PATH="$HOME/Library/Android/sdk/platform-tools/adb" swift run FileFlyfer
```

## Android telefonu bağlama

1. Telefonda **Ayarlar → Telefon hakkında** bölümünü açın.
2. **Yapım numarası** seçeneğine yedi kez dokunarak geliştirici seçeneklerini etkinleştirin.
3. **Geliştirici seçenekleri → USB hata ayıklama** ayarını açın.
4. Telefonu veri aktarımını destekleyen bir USB kablosuyla Mac'e bağlayın.
5. Telefonun kilidini açın ve ekranda çıkan RSA hata ayıklama iznini onaylayın.

Telefon görünmüyorsa `adb devices -l` komutuyla bağlantıyı kontrol edin; cihaz `unauthorized` görünüyorsa RSA izin penceresini onaylayın.

## ADB ve gizlilik

ADB ikilisi kaynak kod deposuna dahil değildir. Her kullanıcı Android SDK Platform-Tools'u kendi bilgisayarına yükler ve kendi lisans koşullarını kabul eder. Uygulama ADB'yi yerel olarak çalıştırır; telefonla aktarım USB üzerinden yapılır.

Swift tarafı ADB'yi kabuk metni birleştirerek değil, yürütülebilir dosya ve ayrı argümanlarla çağırır. Telefon üzerindeki bazı işlemler uzak kabuk komutları gerektirir; dosya adları güvenli aktarılır ve uygulama işlemleri ortak depolama alanıyla sınırlar.

## Bilinen sınırlamalar

- Yalnızca USB üzerinden ADB bağlantısı vardır; MTP, Wi-Fi, iOS, root, bulut, eşitleme ve dosya önizleme desteklenmez.
- Klasör indirme şu an desteklenmez; dosyalar seçilerek indirilir.
- Bazı Android üretici yazılımları dosya bilgisi için kullanılan `stat` veya `base64` komutlarını içermeyebilir.
- ADB güvenilir aktarım yüzdesi vermediğinden ilerleme belirsiz gösterilir.

## Katkıda bulunma

Hata bildirmek veya özellik önermek için GitHub Issues kullanabilirsiniz. Değişiklik göndermeden önce `swift test` ve `swift build` komutlarını çalıştırın; pull request açıklamasında neyin değiştiğini belirtin. Ayrıntılar için [CONTRIBUTING.md](CONTRIBUTING.md) dosyasına bakın.

## Lisans

FileFlyfer, [MIT Lisansı](LICENSE) altında yayımlanır. Android SDK Platform-Tools ayrı bir Google ürünüdür ve kendi lisans koşullarına tabidir.
