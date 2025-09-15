# 📱 Mobil App Implementasyon Rehberi

## NFC Kart Yazma Modu - ESP32 BLE Entegrasyonu

Bu rehber, ESP32'de implement edilen **Kart Yazma Modu + Test Modu** özelliğinin mobil uygulamada nasıl kullanılacağını açıklar.

---

## 🎯 Genel Bakış

### Özellikler
- ✅ **Manuel Yazma Modu:** İstediğin zaman aç/kapat
- ✅ **Hex Data Format:** Android'den gelen veriyi direkt kullan
- ✅ **Otomatik Test:** Her kart yazıldıktan sonra test edilir
- ✅ **LED Feedback:** Görsel durum göstergesi
- ✅ **İstatistik Takibi:** Toplam/Başarılı/Hata sayıları
- ✅ **BLE Bağlantı Desteği:** Yazma modunda normal kart okuma çalışır

### Çalışma Akışı
```
Mobil App → ESP32'ye Kart Data + Yazma Modu Aç (Type 50)
↓
ESP32 → Yazma Modu Aktif (LED yanar)
↓
Kullanıcı → Kartları tek tek okutur
ESP32 → Her kart okutulduğunda → Yaz → Test → Başarı/Hata
↓
Mobil App → ESP32'ye Yazma Modu Kapat (Type 51)
↓
ESP32 → Normal Moda Dön
```

---

## 📡 BLE Komut Yapısı

### 1. Yazma Modu Başlat (Type 50)

```json
{
  "Type": 50,
  "WriteMode": {
    "Action": "START",
    "CardData": {
      "Block4": "01 00 00 00 30 00 17 01 1A 00 1C 00 26 00 2B 00",
      "Block5": "56 00 64 00 66 00 6F 00 00 00 00 00 00 00 00 00",
      "Block6": "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00",
      "Block7": "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00",
      "Block8": "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
    }
  }
}
```

### 2. Yazma Modu Durdur (Type 51)

```json
{
  "Type": 51,
  "WriteMode": {
    "Action": "STOP"
  }
}
```

---

## 📨 ESP32'den Gelen Yanıtlar

### Yazma Modu Başlatıldı
```json
{
  "Type": 50,
  "WriteMode": {
    "Status": "SUCCESS",
    "Stats": {
      "Total": 0,
      "Success": 0,
      "Error": 0
    }
  }
}
```

### Kart Başarıyla Yazıldı
```json
{
  "Type": 50,
  "WriteMode": {
    "Status": "SUCCESS",
    "Stats": {
      "Total": 1,
      "Success": 1,
      "Error": 0
    }
  }
}
```

### Kart Yazma Hatası
```json
{
  "Type": 50,
  "WriteMode": {
    "Status": "ERROR",
    "Stats": {
      "Total": 1,
      "Success": 0,
      "Error": 1
    }
  }
}
```

### Kart Okuma - Hex Data (RType 52)
ESP32'ye herhangi bir kart okuttuğunda (BLE bağlantısı varsa) otomatik olarak gönderilir:
```json
{
  "RType": 52,
  "CardData": {
    "Block4": "01 00 00 00 30 00 17 01 1A 00 1C 00 26 00 2B 00",
    "Block5": "56 00 64 00 66 00 6F 00 00 00 00 00 00 00 00 00",
    "Block6": "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00",
    "Block7": "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00",
    "Block8": "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
  }
}
```

---

## 💻 Android/Kotlin Implementasyonu

### 1. Data Class'ları

```kotlin
data class CardData(
    val block4: String,
    val block5: String,
    val block6: String,
    val block7: String,
    val block8: String
)

data class WriteModeStats(
    val total: Int,
    val success: Int,
    val error: Int
)

data class WriteModeResponse(
    val type: Int,
    val writeMode: WriteModeData
)

data class WriteModeData(
    val status: String,
    val stats: WriteModeStats
)
```

### 2. BLE Komut Gönderme

```kotlin
class NFCWriteModeManager {
    
    // Yazma modu başlat
    fun startWriteMode(cardData: CardData) {
        val json = JSONObject().apply {
            put("Type", 50)
            put("WriteMode", JSONObject().apply {
                put("Action", "START")
                put("CardData", JSONObject().apply {
                    put("Block4", cardData.block4)
                    put("Block5", cardData.block5)
                    put("Block6", cardData.block6)
                    put("Block7", cardData.block7)
                    put("Block8", cardData.block8)
                })
            })
        }
        sendBleCommand(json.toString())
    }
    
    // Yazma modu durdur
    fun stopWriteMode() {
        val json = JSONObject().apply {
            put("Type", 51)
            put("WriteMode", JSONObject().apply {
                put("Action", "STOP")
            })
        }
        sendBleCommand(json.toString())
    }
    
    private fun sendBleCommand(command: String) {
        // BLE karakteristiğine yazma işlemi
        bluetoothGatt?.getService(SERVICE_UUID)
            ?.getCharacteristic(CHARACTERISTIC_UUID)
            ?.let { characteristic ->
                characteristic.value = command.toByteArray()
                bluetoothGatt?.writeCharacteristic(characteristic)
            }
    }
}
```

### 3. ESP32 Yanıtlarını İşleme

```kotlin
class BLEResponseHandler {
    
    fun handleResponse(response: String) {
        try {
            val json = JSONObject(response)
            
            // Type veya RType kontrolü
            val type = if (json.has("RType")) {
                json.getInt("RType")
            } else {
                json.getInt("Type")
            }
            
            when (type) {
                50 -> handleWriteModeResponse(json)
                52 -> handleCardDataResponse(json)
                // Diğer type'lar...
            }
        } catch (e: Exception) {
            Log.e("BLE", "Response parse error: ${e.message}")
        }
    }
    
    private fun handleWriteModeResponse(response: JSONObject) {
        val writeMode = response.getJSONObject("WriteMode")
        val status = writeMode.getString("Status")
        val stats = writeMode.getJSONObject("Stats")
        
        val total = stats.getInt("Total")
        val success = stats.getInt("Success")
        val error = stats.getInt("Error")
        
        when (status) {
            "SUCCESS" -> {
                if (total > 0) {
                    // Kart yazıldı
                    showCardWrittenMessage(total, success, error)
                } else {
                    // Yazma modu başlatıldı
                    showWriteModeStarted()
                }
            }
            "ERROR" -> {
                showCardWriteError(total, success, error)
            }
        }
    }
    
    private fun showCardWrittenMessage(total: Int, success: Int, error: Int) {
        // UI güncelleme
        runOnUiThread {
            statusText.text = "Kart yazıldı! Toplam: $total, Başarılı: $success, Hata: $error"
            updateStatsDisplay(total, success, error)
        }
    }
    
    private fun showWriteModeStarted() {
        runOnUiThread {
            statusText.text = "Yazma modu aktif - Kartları okutun"
            writeModeIndicator.isVisible = true
        }
    }
    
    private fun showCardWriteError(total: Int, success: Int, error: Int) {
        runOnUiThread {
            statusText.text = "Kart yazma hatası! Toplam: $total, Hata: $error"
            showErrorDialog("Kart yazma hatası")
        }
    }
    
    private fun handleCardDataResponse(response: JSONObject) {
        val cardData = response.getJSONObject("CardData")
        
        val block4 = cardData.getString("Block4")
        val block5 = cardData.getString("Block5")
        val block6 = cardData.getString("Block6")
        val block7 = cardData.getString("Block7")
        val block8 = cardData.getString("Block8")
        
        runOnUiThread {
            statusText.text = "Kart okundu - Hex data alındı"
            
            // Hex data'yı UI'da göster veya kaydet
            displayCardData(block4, block5, block6, block7, block8)
        }
    }
    
    private fun displayCardData(block4: String, block5: String, block6: String, block7: String, block8: String) {
        // Hex data'yı UI'da göster
        block4Input.setText(block4)
        block5Input.setText(block5)
        block6Input.setText(block6)
        block7Input.setText(block7)
        block8Input.setText(block8)
        
        // Log'a yazdır
        Log.i("NFC", "Card Data Received:")
        Log.i("NFC", "Block4: $block4")
        Log.i("NFC", "Block5: $block5")
        Log.i("NFC", "Block6: $block6")
        Log.i("NFC", "Block7: $block7")
        Log.i("NFC", "Block8: $block8")
    }
}
```

---

## 🍎 iOS/SwiftUI Implementasyonu

### 1. Data Models

```swift
import Foundation

struct CardData: Codable {
    let block4: String
    let block5: String
    let block6: String
    let block7: String
    let block8: String
    
    enum CodingKeys: String, CodingKey {
        case block4 = "Block4"
        case block5 = "Block5"
        case block6 = "Block6"
        case block7 = "Block7"
        case block8 = "Block8"
    }
}

struct WriteModeStats: Codable {
    let total: Int
    let success: Int
    let error: Int
}

struct WriteModeData: Codable {
    let status: String
    let stats: WriteModeStats
}

struct WriteModeResponse: Codable {
    let type: Int
    let writeMode: WriteModeData
    
    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case writeMode = "WriteMode"
    }
}

struct CardDataResponse: Codable {
    let rType: Int
    let cardData: CardData
    
    enum CodingKeys: String, CodingKey {
        case rType = "RType"
        case cardData = "CardData"
    }
}
```

### 2. BLE Manager

```swift
import CoreBluetooth
import Combine

class NFCWriteModeManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var isWriteModeActive = false
    @Published var stats = WriteModeStats(total: 0, success: 0, error: 0)
    @Published var receivedCardData: CardData?
    @Published var statusMessage = "Hazır"
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    
    private let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")
    private let characteristicUUID = CBUUID(string: "87654321-4321-4321-4321-CBA987654321")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }
    
    func startWriteMode(cardData: CardData) {
        let command = [
            "Type": 50,
            "WriteMode": [
                "Action": "START",
                "CardData": [
                    "Block4": cardData.block4,
                    "Block5": cardData.block5,
                    "Block6": cardData.block6,
                    "Block7": cardData.block7,
                    "Block8": cardData.block8
                ]
            ]
        ] as [String : Any]
        
        sendCommand(command)
        isWriteModeActive = true
        statusMessage = "Yazma modu başlatıldı"
    }
    
    func stopWriteMode() {
        let command = [
            "Type": 51,
            "WriteMode": [
                "Action": "STOP"
            ]
        ] as [String : Any]
        
        sendCommand(command)
        isWriteModeActive = false
        statusMessage = "Yazma modu durduruldu"
    }
    
    private func sendCommand(_ command: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: command),
              let characteristic = writeCharacteristic else { return }
        
        connectedPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    private func handleResponse(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        // Type veya RType kontrolü
        let type: Int
        if let rType = json["RType"] as? Int {
            type = rType
        } else if let typeValue = json["Type"] as? Int {
            type = typeValue
        } else {
            return
        }
        
        switch type {
        case 50:
            handleWriteModeResponse(json)
        case 52:
            handleCardDataResponse(json)
        default:
            break
        }
    }
    
    private func handleWriteModeResponse(_ json: [String: Any]) {
        guard let writeModeData = json["WriteMode"] as? [String: Any],
              let status = writeModeData["Status"] as? String,
              let statsData = writeModeData["Stats"] as? [String: Any] else { return }
        
        let newStats = WriteModeStats(
            total: statsData["Total"] as? Int ?? 0,
            success: statsData["Success"] as? Int ?? 0,
            error: statsData["Error"] as? Int ?? 0
        )
        
        DispatchQueue.main.async {
            self.stats = newStats
            
            if status == "SUCCESS" {
                if newStats.total > 0 {
                    self.statusMessage = "Kart yazıldı! Toplam: \(newStats.total), Başarılı: \(newStats.success)"
                } else {
                    self.statusMessage = "Yazma modu aktif - Kartları okutun"
                }
            } else {
                self.statusMessage = "Kart yazma hatası! Hata: \(newStats.error)"
            }
        }
    }
    
    private func handleCardDataResponse(_ json: [String: Any]) {
        guard let cardDataDict = json["CardData"] as? [String: Any] else { return }
        
        let cardData = CardData(
            block4: cardDataDict["Block4"] as? String ?? "",
            block5: cardDataDict["Block5"] as? String ?? "",
            block6: cardDataDict["Block6"] as? String ?? "",
            block7: cardDataDict["Block7"] as? String ?? "",
            block8: cardDataDict["Block8"] as? String ?? ""
        )
        
        DispatchQueue.main.async {
            self.receivedCardData = cardData
            self.statusMessage = "Kart okundu - Hex data alındı"
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension NFCWriteModeManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScanning()
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
    }
}

// MARK: - CBPeripheralDelegate
extension NFCWriteModeManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                writeCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                
                DispatchQueue.main.async {
                    self.isConnected = true
                    self.statusMessage = "ESP32'ye bağlandı"
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        handleResponse(data)
    }
}
```

### 3. SwiftUI View

```swift
import SwiftUI

struct NFCWriteModeView: View {
    @StateObject private var bleManager = NFCWriteModeManager()
    @State private var cardData = CardData(
        block4: "01 00 00 00 30 00 17 01 1A 00 1C 00 26 00 2B 00",
        block5: "56 00 64 00 66 00 6F 00 00 00 00 00 00 00 00 00",
        block6: "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00",
        block7: "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00",
        block8: "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
    )
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Durum Göstergesi
                VStack {
                    Text(bleManager.statusMessage)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    // Yazma Modu Göstergesi
                    if bleManager.isWriteModeActive {
                        Rectangle()
                            .fill(Color.green)
                            .frame(height: 4)
                            .cornerRadius(2)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // İstatistikler
                HStack(spacing: 20) {
                    StatView(title: "Toplam", value: bleManager.stats.total, color: .blue)
                    StatView(title: "Başarılı", value: bleManager.stats.success, color: .green)
                    StatView(title: "Hata", value: bleManager.stats.error, color: .red)
                }
                
                // Kontrol Butonları
                HStack(spacing: 15) {
                    Button(action: {
                        bleManager.startWriteMode(cardData: cardData)
                    }) {
                        Text("Yazma Modu Başlat")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(bleManager.isWriteModeActive ? Color.gray : Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(bleManager.isWriteModeActive || !bleManager.isConnected)
                    
                    Button(action: {
                        bleManager.stopWriteMode()
                    }) {
                        Text("Yazma Modu Durdur")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(!bleManager.isWriteModeActive ? Color.gray : Color.red)
                            .cornerRadius(10)
                    }
                    .disabled(!bleManager.isWriteModeActive || !bleManager.isConnected)
                }
                
                // Kart Data Girişi
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Kart Data (Hex Format)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        CardDataInputView(
                            title: "Block4",
                            text: $cardData.block4,
                            placeholder: "01 00 00 00 30 00 17 01 1A 00 1C 00 26 00 2B 00"
                        )
                        
                        CardDataInputView(
                            title: "Block5",
                            text: $cardData.block5,
                            placeholder: "56 00 64 00 66 00 6F 00 00 00 00 00 00 00 00 00"
                        )
                        
                        CardDataInputView(
                            title: "Block6",
                            text: $cardData.block6,
                            placeholder: "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
                        )
                        
                        CardDataInputView(
                            title: "Block7",
                            text: $cardData.block7,
                            placeholder: "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
                        )
                        
                        CardDataInputView(
                            title: "Block8",
                            text: $cardData.block8,
                            placeholder: "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
                        )
                        
                        Button("Örnek Data Yükle") {
                            loadExampleData()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                }
                
                // Okunan Kart Data Gösterimi
                if let receivedData = bleManager.receivedCardData {
                    VStack(alignment: .leading) {
                        Text("Son Okunan Kart Data")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("Block4: \(receivedData.block4)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Block5: \(receivedData.block5)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Block6: \(receivedData.block6)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Block7: \(receivedData.block7)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Block8: \(receivedData.block8)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("NFC Yazma Modu")
        }
    }
    
    private func loadExampleData() {
        cardData = CardData(
            block4: "01 00 00 00 30 00 17 01 1A 00 1C 00 26 00 2B 00",
            block5: "56 00 64 00 66 00 6F 00 00 00 00 00 00 00 00 00",
            block6: "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00",
            block7: "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00",
            block8: "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
        )
    }
}

struct StatView: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack {
            Text("\(value)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct CardDataInputView: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(.body, design: .monospaced))
        }
    }
}

#Preview {
    NFCWriteModeView()
}
```

---

## 🎨 UI Tasarım Önerileri

### Ana Ekran Layout

```xml
<LinearLayout
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="16dp">

    <!-- Durum Göstergesi -->
    <TextView
        android:id="@+id/statusText"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="Hazır"
        android:textSize="16sp"
        android:gravity="center"
        android:padding="8dp" />

    <!-- Yazma Modu Göstergesi -->
    <View
        android:id="@+id/writeModeIndicator"
        android:layout_width="match_parent"
        android:layout_height="4dp"
        android:background="@color/green"
        android:visibility="gone" />

    <!-- İstatistikler -->
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:layout_marginTop="16dp">

        <TextView
            android:id="@+id/totalCount"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Toplam: 0"
            android:gravity="center" />

        <TextView
            android:id="@+id/successCount"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Başarılı: 0"
            android:gravity="center" />

        <TextView
            android:id="@+id/errorCount"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Hata: 0"
            android:gravity="center" />

    </LinearLayout>

    <!-- Kontrol Butonları -->
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:layout_marginTop="24dp">

        <Button
            android:id="@+id/startWriteModeBtn"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Yazma Modu Başlat"
            android:layout_marginEnd="8dp" />

        <Button
            android:id="@+id/stopWriteModeBtn"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Yazma Modu Durdur"
            android:layout_marginStart="8dp" />

    </LinearLayout>

    <!-- Kart Data Girişi -->
    <ScrollView
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"
        android:layout_marginTop="16dp">

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="vertical">

            <TextView
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:text="Kart Data (Hex Format)"
                android:textSize="18sp"
                android:textStyle="bold" />

            <EditText
                android:id="@+id/block4Input"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:hint="Block4: 01 00 00 00 30 00 17 01 1A 00 1C 00 26 00 2B 00"
                android:layout_marginTop="8dp" />

            <EditText
                android:id="@+id/block5Input"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:hint="Block5: 56 00 64 00 66 00 6F 00 00 00 00 00 00 00 00 00" />

            <EditText
                android:id="@+id/block6Input"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:hint="Block6: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00" />

            <EditText
                android:id="@+id/block7Input"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:hint="Block7: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00" />

            <EditText
                android:id="@+id/block8Input"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:hint="Block8: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00" />

            <Button
                android:id="@+id/loadExampleBtn"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:text="Örnek Data Yükle"
                android:layout_marginTop="16dp" />

        </LinearLayout>

    </ScrollView>

</LinearLayout>
```

### Activity Kod Örneği

```kotlin
class NFCWriteModeActivity : AppCompatActivity() {
    
    private lateinit var nfcWriteModeManager: NFCWriteModeManager
    private lateinit var bleResponseHandler: BLEResponseHandler
    
    private var isWriteModeActive = false
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_nfc_write_mode)
        
        nfcWriteModeManager = NFCWriteModeManager()
        bleResponseHandler = BLEResponseHandler()
        
        setupUI()
        setupBLE()
    }
    
    private fun setupUI() {
        startWriteModeBtn.setOnClickListener {
            if (!isWriteModeActive) {
                startWriteMode()
            }
        }
        
        stopWriteModeBtn.setOnClickListener {
            if (isWriteModeActive) {
                stopWriteMode()
            }
        }
        
        loadExampleBtn.setOnClickListener {
            loadExampleData()
        }
    }
    
    private fun startWriteMode() {
        val cardData = CardData(
            block4 = block4Input.text.toString(),
            block5 = block5Input.text.toString(),
            block6 = block6Input.text.toString(),
            block7 = block7Input.text.toString(),
            block8 = block8Input.text.toString()
        )
        
        if (validateCardData(cardData)) {
            nfcWriteModeManager.startWriteMode(cardData)
            isWriteModeActive = true
            updateUI()
        } else {
            showErrorDialog("Geçersiz kart data formatı")
        }
    }
    
    private fun stopWriteMode() {
        nfcWriteModeManager.stopWriteMode()
        isWriteModeActive = false
        updateUI()
    }
    
    private fun loadExampleData() {
        block4Input.setText("01 00 00 00 30 00 17 01 1A 00 1C 00 26 00 2B 00")
        block5Input.setText("56 00 64 00 66 00 6F 00 00 00 00 00 00 00 00 00")
        block6Input.setText("00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00")
        block7Input.setText("00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00")
        block8Input.setText("00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00")
    }
    
    private fun validateCardData(cardData: CardData): Boolean {
        // Hex format validation
        val hexPattern = "^[0-9A-Fa-f ]+$"
        return listOf(cardData.block4, cardData.block5, cardData.block6, cardData.block7, cardData.block8)
            .all { it.matches(hexPattern.toRegex()) }
    }
    
    private fun updateUI() {
        startWriteModeBtn.isEnabled = !isWriteModeActive
        stopWriteModeBtn.isEnabled = isWriteModeActive
        writeModeIndicator.visibility = if (isWriteModeActive) View.VISIBLE else View.GONE
    }
    
    private fun updateStatsDisplay(total: Int, success: Int, error: Int) {
        totalCount.text = "Toplam: $total"
        successCount.text = "Başarılı: $success"
        errorCount.text = "Hata: $error"
    }
}
```

---

## 🔧 LED Feedback Sistemi

ESP32'de LED durumları:

| Durum | PWR_L1 | PWR_L2 | Açıklama |
|-------|--------|--------|----------|
| **Yazma Modu Aktif** | 🔴 ON | 🟢 ON | Her iki LED yanık |
| **Başarılı Yazma** | 🔴 OFF | 🟢 ON | Sadece yeşil LED |
| **Hatalı Yazma** | 🔴 ON | 🟢 OFF | Sadece kırmızı LED |
| **Normal Mod** | 🔴 OFF | 🟢 OFF | LED'ler sönük |

---

## 🧪 Test Senaryosu

### 1. Temel Test
1. **App'i aç ve ESP32'ye bağlan**
2. **"Örnek Data Yükle" butonuna bas**
3. **"Yazma Modu Başlat" butonuna bas**
4. **ESP32 LED'lerinin yandığını kontrol et**
5. **Bir NFC kartı ESP32'ye okut**
6. **Başarılı yazma için yeşil LED'i kontrol et**
7. **App'te istatistiklerin güncellendiğini kontrol et**
8. **"Yazma Modu Durdur" butonuna bas**
9. **ESP32 LED'lerinin söndüğünü kontrol et**

### 2. Kart Okuma Testi
1. **App'i aç ve ESP32'ye bağlan**
2. **Herhangi bir NFC kartı ESP32'ye okut**
3. **App'te hex data'nın otomatik geldiğini kontrol et**
4. **Block4-8 verilerinin doğru gösterildiğini kontrol et**
5. **Farklı kartlarla test et**

### 3. Hata Testi
1. **Geçersiz hex data ile yazma modu başlat**
2. **Hata mesajının geldiğini kontrol et**
3. **Geçerli data ile tekrar dene**

### 4. Çoklu Kart Testi
1. **Yazma modu başlat**
2. **5-10 kartı arka arkaya okut**
3. **Her kartın başarıyla yazıldığını kontrol et**
4. **İstatistiklerin doğru güncellendiğini kontrol et**

---

## ⚠️ Hata Yönetimi

### BLE Bağlantı Hataları
```kotlin
private fun handleBLEError(error: String) {
    when (error) {
        "CONNECTION_LOST" -> {
            isWriteModeActive = false
            showErrorDialog("BLE bağlantısı kesildi. Yazma modu kapatıldı.")
        }
        "WRITE_FAILED" -> {
            showErrorDialog("Komut gönderilemedi. Tekrar deneyin.")
        }
    }
}
```

### Data Validation
```kotlin
private fun validateHexString(hexString: String): Boolean {
    // Boşlukları temizle
    val cleanHex = hexString.replace(" ", "")
    
    // Uzunluk kontrolü (16 byte = 32 hex karakter)
    if (cleanHex.length != 32) return false
    
    // Hex karakter kontrolü
    return cleanHex.matches("[0-9A-Fa-f]+".toRegex())
}
```

### Timeout Yönetimi
```kotlin
private fun startWriteModeWithTimeout() {
    val timeoutHandler = Handler(Looper.getMainLooper())
    val timeoutRunnable = Runnable {
        if (isWriteModeActive) {
            showErrorDialog("ESP32'den yanıt alınamadı")
        }
    }
    
    timeoutHandler.postDelayed(timeoutRunnable, 5000) // 5 saniye timeout
}
```

---

## 📊 Performans Optimizasyonu

### 1. BLE Buffer Yönetimi
```kotlin
private val bleBuffer = StringBuilder()

private fun appendToBuffer(data: ByteArray) {
    bleBuffer.append(String(data))
    
    // Tam JSON mesajı kontrolü
    if (bleBuffer.toString().contains("}")) {
        processCompleteMessage(bleBuffer.toString())
        bleBuffer.clear()
    }
}
```

### 2. UI Thread Optimizasyonu
```kotlin
private fun updateStatsOnUIThread(total: Int, success: Int, error: Int) {
    if (Looper.myLooper() == Looper.getMainLooper()) {
        updateStatsDisplay(total, success, error)
    } else {
        runOnUiThread {
            updateStatsDisplay(total, success, error)
        }
    }
}
```

---

## 🔒 Güvenlik Önerileri

1. **Data Validation:** Tüm hex input'ları validate et
2. **BLE Encryption:** Üretim ortamında BLE encryption kullan
3. **Error Logging:** Hataları logla ama hassas data'yı expose etme
4. **Timeout Handling:** Sonsuz beklemeleri önle
5. **Memory Management:** JSON objelerini düzgün temizle

---

## 📝 Notlar

- **Hex Format:** Boşluklarla ayrılmış format kullan (örn: "01 00 00 00")
- **Block Sırası:** Block4-8 sırasıyla gönder
- **LED Feedback:** ESP32 LED'lerini takip et
- **İstatistikler:** Her yazma işleminden sonra güncellenir
- **Test Modu:** Her kart yazıldıktan sonra otomatik test edilir

Bu implementasyon ile yüzlerce kartı hızlı ve güvenilir şekilde yazabilirsin! 🚀
