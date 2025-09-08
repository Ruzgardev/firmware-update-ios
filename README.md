# Mio ESP Firmware Update

iOS uygulaması ile Mio ESP cihazlarına Bluetooth üzerinden firmware güncelleme yapma aracı.

## 🚀 Özellikler

- **Bluetooth Low Energy (BLE)** bağlantısı
- **Yeni Mio cihazları** için JSON tabanlı komutlar
- **Firmware güncelleme** işlemi
- **Gerçek zamanlı ilerleme takibi**
- **Detaylı log sistemi**
- **Cihaz bilgileri görüntüleme**
- **Modern SwiftUI arayüzü**

## 📱 Desteklenen Cihazlar

### Yeni Mio Cihazları
- **Servis UUID**: `9FA480E0-4967-4542-9390-D343DC5D04AE`
- **Characteristic UUID**: `AF0BADB1-5B99-43CD-917A-A77BC549E3CC`
- **Komut Formatı**: JSON
- **Seri Numarası**: 7 karakterden fazla

## 🔧 Kurulum

### Gereksinimler
- iOS 14.0+
- Xcode 12.0+
- Swift 5.0+

### Adımlar
1. Projeyi klonlayın:
```bash
git clone https://github.com/yourusername/mio-firmware.git
cd mio-firmware
```

2. Xcode'da projeyi açın:
```bash
open mio-firmware.xcodeproj
```

3. Firmware dosyasını `firmware.bin` olarak projeye ekleyin

4. Uygulamayı derleyin ve çalıştırın

## 📖 Kullanım

### 1. Cihaz Bağlantısı
- Uygulamayı açın
- "Tarama Başlat" butonuna basın
- Bulunan Mio cihazını seçin
- Bağlantı otomatik olarak kurulacak

### 2. Firmware Güncelleme
- Cihaz bağlandıktan sonra "Mio Firmware Update" butonuna basın
- İlerleme çubuğunu takip edin
- Güncelleme tamamlandığında cihaz otomatik olarak yeniden başlayacak

### 3. Cihaz Bilgileri
- **Cihaz Bilgileri**: Cihaz durumu ve bilgileri
- **Log Listesi**: Sistem loglarını görüntüleme
- **Zaman Ayarı**: Otomatik kapanma süresi
- **Random Play**: Rastgele oynatma ayarı

## 🏗️ Proje Yapısı

```
mio-firmware/
├── mio-firmware/
│   ├── ContentView.swift          # Ana arayüz
│   ├── BluetoothService.swift     # Bluetooth yönetimi
│   ├── FirmwareUpdateService.swift # Firmware güncelleme
│   ├── Commands.swift             # Cihaz komutları
│   ├── Logger.swift               # Log sistemi
│   ├── firmware.bin               # Firmware dosyası
│   └── Assets.xcassets/           # Görsel kaynaklar
├── Mio_ESP_Baglanti_ve_Firmware_Update_Rehberi.md
└── README.md
```

## 🔄 Firmware Update Süreci

### 1. Bağlantı
- Bluetooth tarama
- Cihaz seçimi ve bağlantı
- Servis ve karakteristik keşfi

### 2. Login Package
- Cihaz otomatik olarak login bilgileri gönderir
- Batarya, versiyon, timeout bilgileri alınır

### 3. Update Komutu
```json
{
  "Type": 6,
  "Update": {
    "Version": 1,
    "Size": 1253040
  }
}
```

### 4. Dosya Transferi
- Firmware dosyası paketler halinde gönderilir
- Her paket 155 byte
- Timing: iPhone 8+ için 20ms, iPhone 6/7 için 50ms

### 5. Tamamlama
- `FILE OK` response beklenir
- `GETUPDATE` komutu gönderilir
- `GETUPDATE OK` response beklenir
- `RESET_MIO` komutu ile cihaz yeniden başlatılır

## ⚙️ Teknik Detaylar

### Bluetooth Ayarları
- **Protocol**: Bluetooth Low Energy (BLE)
- **Connection Type**: Central Manager
- **Service Discovery**: Automatic
- **Characteristic Discovery**: Automatic

### Timing Ayarları
- **iPhone 8+**: 20ms paket gecikmesi
- **iPhone 6/7**: 50ms paket gecikmesi
- **Ek Güvenlik**: Her 50 pakette 100ms ekstra bekleme

### Log Sistemi
- **Seviyeler**: DEBUG, INFO, WARNING, ERROR
- **Kategoriler**: Bluetooth, Firmware, Connection
- **Export**: Logları dışa aktarma özelliği

## 🐛 Sorun Giderme

### Bağlantı Sorunları
- Bluetooth'un açık olduğundan emin olun
- Cihazın görünür modda olduğunu kontrol edin
- Uygulamayı yeniden başlatın

### Firmware Update Sorunları
- Cihazın batarya seviyesini kontrol edin (%25+)
- Firmware dosyasının doğru olduğundan emin olun
- Logları kontrol edin

### Performans Sorunları
- Cihaz modeline göre timing ayarları otomatik
- Yavaş cihazlarda daha uzun süre bekleyin

## 📝 Lisans

Bu proje MIT lisansı altında lisanslanmıştır.

## 🤝 Katkıda Bulunma

1. Fork yapın
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Commit yapın (`git commit -m 'Add amazing feature'`)
4. Push yapın (`git push origin feature/amazing-feature`)
5. Pull Request oluşturun

## 📞 İletişim

- **Proje Sahibi**: Hüseyin Uludağ
- **Email**: your.email@example.com
- **GitHub**: [@yourusername](https://github.com/yourusername)

## 🙏 Teşekkürler

- CoreBluetooth framework
- SwiftUI
- Tolkido ekibi

---

**Not**: Bu uygulama sadece Mio ESP cihazları ile test edilmiştir. Diğer cihazlarla uyumluluk garantisi yoktur.
