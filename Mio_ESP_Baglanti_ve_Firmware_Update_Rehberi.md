# Mio ESP Bağlantısı ve Firmware Update Rehberi

Bu doküman, Tolkido projesinde Mio ESP cihazına bağlanma ve firmware update işlemlerinin nasıl yapıldığını adım adım açıklamaktadır.

## İçindekiler
1. [Mio Cihaz Tanımlama](#mio-cihaz-tanımlama)
2. [Bluetooth Bağlantı Süreci](#bluetooth-bağlantı-süreci)
3. [Servis ve Karakteristik Keşfi](#servis-ve-karakteristik-keşfi)
4. [Login Package Response](#login-package-response)
5. [Send Message ve Read Response](#send-message-ve-read-response)
6. [Firmware Update İşlemi](#firmware-update-işlemi)
7. [Kullanılan Komutlar](#kullanılan-komutlar)
8. [Dosya Transferi](#dosya-transferi)
9. [Eski vs Yeni Cihaz Farkları](#eski-vs-yeni-cihaz-farkları)

---

## Mio Cihaz Tanımlama

### 1. Cihaz Tespiti

Mio cihazı, cihaz adındaki seri numarası uzunluğuna göre tespit edilir:

```swift
// Cihaz adından tespit (örn: "Tolkido-123456789")
if let splitedDigit = peri.peripheral.name?.split(separator: "-"), splitedDigit.count >= 2 {
    let stringDigit = String(splitedDigit[1])
    Constants.ConnectionReachability.isNewDevice = stringDigit.count > 7
} else {
    Constants.ConnectionReachability.isNewDevice = false
}

// Yeni cihaz tespit edildiğinde servis UUID'si ayarlanır
serial.serviceUUID = Constants.ConnectionReachability.isNewDevice ? 
    CBUUID(string: "00FF") : CBUUID(string: "FFF0")
```

**Tespit Kriteri:**
- **Yeni Mio**: Seri numarası 7 karakterden fazla
- **Eski Tolkido**: Seri numarası 7 karakter veya daha az

---

## Bluetooth Bağlantı Süreci

### 1. Bluetooth Tarama

```swift
// Bluetooth taramayı başlat
func startScan() {
    guard centralManager.state == .poweredOn else { return }
    centralManager.scanForPeripherals(withServices: nil, options: nil)
}
```

### 2. Cihaz Seçimi ve Bağlantı

```swift
// Cihaza bağlan
func connectToPeripheral(_ peripheral: CBPeripheral) {
    pendingPeripheral = peripheral
    centralManager.connect(peripheral, options: nil)
}
```

### 3. Bağlantı Başarılı

```swift
func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    // Peripheral ayarları
    peripheral.delegate = self
    pendingPeripheral = nil
    connectedPeripheral = peripheral
    Constants.ConnectionReachability.connectedPeripheral = peripheral
    
    // Delegate'e bağlantı bildirimi
    delegate?.serialDidConnect(peripheral)
    
    // Servis keşfini başlat
    peripheral.discoverServices([serviceUUID])
}
```

---

## Servis ve Karakteristik Keşfi

### 1. Mio Servis Keşfi

Mio cihazı bağlandığında, cihazın servisleri keşfedilir:

```swift
func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    for service in peripheral.services! {
        // Mio cihazı için özel servis
        if (service.uuid.uuidString == "9FA480E0-4967-4542-9390-D343DC5D04AE") {
            serviceUUID = CBUUID(string: service.uuid.uuidString)
            RXCharacteristic = CBUUID(string: "AF0BADB1-5B99-43CD-917A-A77BC549E3CC")
            TXCharacteristic = CBUUID(string: "AF0BADB1-5B99-43CD-917A-A77BC549E3CC")
            RRXCharacteristic = CBUUID(string: "AF0BADB1-5B99-43CD-917A-A77BC549E3CC")
            peripheral.discoverCharacteristics([RXCharacteristic,TXCharacteristic,RRXCharacteristic], for: service)
        }
    }
}
```

**Mio Servis Bilgileri:**
- **Service UUID**: `9FA480E0-4967-4542-9390-D343DC5D04AE`
- **Characteristic UUID**: `AF0BADB1-5B99-43CD-917A-A77BC549E3CC`

### 2. Karakteristik Keşfi ve Bildirim Ayarları

```swift
func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    if (service.uuid == serviceUUID) {
        for characteristic in service.characteristics! {
            if characteristic.uuid == RXCharacteristic {
                // RX karakteristiği için bildirimleri etkinleştir
                peripheral.setNotifyValue(true, for: characteristic)
                writeCharacteristic = characteristic
            }
            
            if characteristic.uuid == TXCharacteristic {
                // TX karakteristiği için bildirimleri etkinleştir
                peripheral.setNotifyValue(true, for: characteristic)
                writeCharacteristic = characteristic
                txCharacteristic = characteristic
            }
            
            if characteristic.uuid == RRXCharacteristic {
                // RRX karakteristiği için bildirimleri etkinleştir
                peripheral.setNotifyValue(true, for: characteristic)
                writeCharacteristic = characteristic
                
                // Bağlantı hazır - delegate'e bildir
                delegate?.serialIsReady(peripheral, isNew: Constants.ConnectionReachability.isNewDevice)
            }
        }
    }
}
```

### 3. Bağlantı Hazır Durumu

Karakteristikler keşfedildikten sonra:
- Tüm karakteristikler için bildirimler etkinleştirilir
- `writeCharacteristic` ayarlanır
- `serialIsReady` delegate metodu çağrılır
- Cihaz veri alışverişi için hazır hale gelir

---

## Login Package Response

### 1. Login Package Alımı

Mio cihazı bağlantı kurulduktan sonra otomatik olarak login package gönderir:

```swift
func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    let data = characteristic.value
    guard data != nil else { return }
    
    // Yeni cihaz için JSON verisi işle
    if Constants.ConnectionReachability.isNewDevice {
        guard let newData = data else { return }
        handleJson(jsonData: newData)
    }
}
```

### 2. JSON Veri İşleme

```swift
func handleJson(jsonData: Data) {
    let str = String.init(data: jsonData, encoding: .utf8)
    let decoder = JSONDecoder()
    
    do {
        // Login package'ı decode et
        let loginPackageModel = try decoder.decode(LoginPackageModelsBase.self, from: jsonData)
        
        if loginPackageModel.Login != nil {
            // Login verisini kaydet
            AppUtils.loginResponseModel = loginPackageModel
            NotificationCenter.default.post(name: .init("connectionVariablesReceived"), object: nil)
        }
    } catch {
        print("JSON decode error: ", error.localizedDescription)
    }
}
```

### 3. Login Package Yapısı

```swift
struct LoginPackageModelsBase: Codable {
    var RType: Int?        // Response Type (yanıt türü)
    var Login: LoginPackageModel?  // Login bilgileri
}

struct LoginPackageModel: Codable {
    var UniqueID: String?      // Cihazın benzersiz ID'si
    var BatteryVoltage: Int?   // Batarya voltajı
    var RandomPlay: Int?       // Rastgele oynatma durumu
    var Timeout: Int?          // Otomatik kapanma süresi
    var FWVersion: Int?        // Firmware versiyonu
}
```

### 4. Örnek Login Package

```json
{
  "RType": 1,
  "Login": {
    "UniqueID": "T123456789",
    "BatteryVoltage": 387,
    "RandomPlay": 1,
    "Timeout": 30,
    "FWVersion": 123
  }
}
```

### 5. Login Package Veri İşleme

#### A) Seri Numarası İşleme
```swift
if let uniqueid = loginPackageModel.Login?.UniqueID, !uniqueid.isEmpty {
    Constants.ConnectionReachability.connectedSerialNo = uniqueid
    print("Device serial no: ", uniqueid)
}
```

#### B) Batarya Seviyesi İşleme
```swift
if let batteryVal = loginPackageModel.Login?.BatteryVoltage {
    NotificationCenter.default.post(name: .init("dismissConnection"), object: nil)
    Definations.battery = Double(batteryVal)
    
    // Batarya seviyesi kontrolü
    if Definations.battery >= 387.0 {
        Definations.TolkidoMioCharge = "Type 3"  // %100
    } else if Definations.battery >= 370.0 && Definations.battery <= 386.0 {
        Definations.TolkidoMioCharge = "Type 2"  // %50
    } else if Definations.battery <= 369.0 {
        Definations.TolkidoMioCharge = "Type 1"  // %25
    }
}
```

#### C) Rastgele Oynatma Durumu
```swift
if let randomPlayVal = loginPackageModel.Login?.RandomPlay {
    if randomPlayVal == 1 {
        Definations.randPlayTolkido = "Açık"
    } else {
        Definations.randPlayTolkido = "Kapalı"
    }
    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "randomPlayTolkido"), object: nil, userInfo: nil)
}
```

#### D) Firmware Versiyonu İşleme
```swift
if let deviceVersion = loginPackageModel.Login?.FWVersion {
    let deviceVersionString = String(deviceVersion)
    var versionString = ""
    
    // Versiyonu noktalı formata çevir (örn: 123 -> 1.2.3)
    for (index, letter) in deviceVersionString.enumerated() {
        if index == deviceVersionString.count - 1 {
            versionString += "\(letter)"
        } else {
            versionString += "\(letter)."
        }
    }
    
    Definations.firmwareVersion = versionString
    if let doubleVersion = Double(versionString) { 
        Definations.Mio_version = doubleVersion 
    }
}
```

#### E) Timeout Süresi İşleme
```swift
if let deviceTimeout = loginPackageModel.Login?.Timeout {
    let deviceTimeOutString = String(deviceTimeout)
    print("auto close time = ", deviceTimeOutString)
    Definations.autoCloseTolkido = deviceTimeOutString
    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "autoClosedTolkido"), object: nil, userInfo: nil)
}
```

### 6. UI Güncellemeleri

Login package alındıktan sonra UI güncellemeleri yapılır:

```swift
// Bağlantı kurulduğunda UI güncellemeleri
NotificationCenter.default.post(name: .init("connectionVariablesReceived"), object: nil)
NotificationCenter.default.post(name: .init("batteryLevel"), object: nil)
NotificationCenter.default.post(name: .init("randomPlayTolkido"), object: nil)
NotificationCenter.default.post(name: .init("autoClosedTolkido"), object: nil)
```

---

## Send Message ve Read Response

### 1. Send Message İşlemleri

Mio cihazına mesaj gönderme işlemi `BluetoothService.swift` dosyasında yönetilmektedir:

#### A) String Mesaj Gönderme
```swift
/// Send a string to the device
func sendMessageToDevice(_ message: String) {
    guard isReady else { return }
    print("message data \(isReady): ", message)
    if let data = message.data(using: String.Encoding.utf8) {
        connectedPeripheral!.writeValue(data, for: writeCharacteristic!, type: writeType)
    }
}
```

#### B) Byte Array Gönderme
```swift
/// Send an array of bytes to the device
func sendBytesToDevice(_ bytes: [UInt8]) {
    guard isReady else { return }
    
    let data = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
    connectedPeripheral!.writeValue(data, for: writeCharacteristic!, type: writeType)
}
```

#### C) Data Gönderme
```swift
/// Send data to the device
func sendDataToDevice(_ data: Data) {
    guard isReady else { return }
    connectedPeripheral!.writeValue(data, for: writeCharacteristic!, type: writeType)
}
```

### 2. Read Response İşlemleri

Mio cihazından gelen yanıtlar `didUpdateValueFor` delegate metodu ile işlenir:

```swift
func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    // notify the delegate in different ways
    let data = characteristic.value
    guard data != nil else { return }
    
    //desc: - send receive data -
    lastConnectionStatus = .didReceiveData(receivedData: data!, isNewTolkido: Constants.ConnectionReachability.isNewDevice)
    
    // first the data
    delegate?.serialDidReceiveData(data!, isNew: Constants.ConnectionReachability.isNewDevice)
    
    // then the string
    if Constants.ConnectionReachability.isNewDevice {
        guard let newData = data else {return}
        handleJson(jsonData: newData)
    } else {
        if let str = String(data: data!, encoding: String.Encoding.utf8) {
            delegate?.serialDidReceiveString(str, isNew: Constants.ConnectionReachability.isNewDevice)
            // Eski cihaz için string işleme...
        }
    }
    
    // now the bytes array
    var bytes = [UInt8](repeating: 0, count: data!.count / MemoryLayout<UInt8>.size)
    (data! as NSData).getBytes(&bytes, length: data!.count)
    delegate?.serialDidReceiveBytes(bytes, isNew: Constants.ConnectionReachability.isNewDevice)
}
```

### 3. Mio JSON Response İşleme

Mio cihazından gelen JSON yanıtları `handleJson` fonksiyonu ile işlenir:

```swift
func handleJson(jsonData: Data) {
    let str = String.init(data: jsonData, encoding: .utf8)
    let decoder = JSONDecoder()
    
    do {
        // Login package model
        let loginPackageModel = try decoder.decode(LoginPackageModelsBase.self, from: jsonData)
        if loginPackageModel.Login != nil {
            AppUtils.loginResponseModel = loginPackageModel
            NotificationCenter.default.post(name: .init("connectionVariablesReceived"), object: nil)
        }
        
        // Success response model
        if let currentResponseModel = try? decoder.decode(SuccessResponseBase.self, from: jsonData) {
            print("response model: ", String.init(data: jsonData, encoding: .utf8) ?? "nil")
            
            // Firmware update response
            if ((AppUtils.isFirmwareUpdate || AppUtils.isAffirmationUpdate) && 
                currentResponseModel.Response?.Result ?? 1 == 0) {
                DispatchQueue.main.async {
                    Definations.startTime = CACurrentMediaTime()
                    DispatchQueue.global().async {
                        for element in Definations.finalBytes {
                            usleep(useconds_t(AppUtils().milisSec))
                            UploadTolkido.sendFileToTolkido(element)
                        }
                    }
                }
                print("response is firmware update!!")
            }
        }
        
        // Card read model
        if let cardReadModel = try? decoder.decode(ReadCardModel.self, from: jsonData) {
            print("data detail = ", cardReadModel)
            if !AppUtils.isUploadStarted {
                var readCardStr = ""
                if let ids = cardReadModel.Uid {
                    for id in ids {
                        readCardStr += String(id)
                    }
                    UploadTolkido.sendOnlyOneSound(str: "LNUid:")
                }
                Definations.readedLnUid = readCardStr
                AppUtils.cardReadModel = cardReadModel
            }
        }
        
        // File folder model
        if let fileFolderModel = try? decoder.decode(FileFolderModel.self, from: jsonData) {
            if let folder = fileFolderModel.Directory?.Folder,
               let file = fileFolderModel.Directory?.File {
                Definations.currentFile = -3
                let emptyFileFolderSTR = "EMPTY FOLDER-FILE-DATA:\(folder):\(file): OK"
                UploadTolkido.sendOnlyOneSound(str: emptyFileFolderSTR)
            }
        }
        
        // File OK response model
        if let fileOKResponseModel = try? decoder.decode(FileOKModelBase.self, from: jsonData) {
            if AppUtils.isAffirmationUpdate && (fileOKResponseModel.ResponseType1?.Result ?? -11) == 0 {
                NotificationCenter.default.post(name: .init("affirmationUpdateEnd"), object: nil)
            } else {
                if let responseCode = fileOKResponseModel.ResponseType1?.Result, AppUtils.isUploadStarted {
                    AppUtils.isUploadStarted = false
                    AppUtils.isCardUpdateStarted = true
                    UploadTolkido.sendOnlyOneSound(str: "FILE OK")
                }
            }
        }
        
        // Log file response model
        if let logFileResponseModel = try? decoder.decode(LogFileResponse.self, from: jsonData) {
            print("file response: ", logFileResponseModel)
            if let files = logFileResponseModel.LogFiles, !files.isEmpty {
                var newLogfileString = ""
                for (index, file) in files.enumerated() {
                    if index == files.count - 1 {
                        newLogfileString += "\(file).txt:END"
                    } else {
                        newLogfileString += "\(file).txt:"
                    }
                }
                print("received log string: ", newLogfileString)
                logStringReceived(str: newLogfileString)
            }
        }
        
    } catch {
        let errorMessage = error.localizedDescription
        print("an json handle error: ", errorMessage)
    }
}
```

### 4. Response Model Yapıları

#### A) Success Response
```swift
struct SuccessResponseBase: Codable {
    var Response: SuccessResponse?
}

struct SuccessResponse: Codable {
    var Result: Int?  // 0 = Başarılı, 1 = Hata
}
```

#### B) Card Read Model
```swift
struct ReadCardModel: Codable {
    var Uid: [Int]?  // Kart ID'si
}
```

#### C) File Folder Model
```swift
struct FileFolderModel: Codable {
    var Directory: DirectoryInfo?
}

struct DirectoryInfo: Codable {
    var Folder: Int?
    var File: Int?
}
```

#### D) File OK Model
```swift
struct FileOKModelBase: Codable {
    var ResponseType1: FileOKResponse?
}

struct FileOKResponse: Codable {
    var Result: Int?  // 0 = Başarılı, 1 = Hata
}
```

#### E) Log File Response
```swift
struct LogFileResponse: Codable {
    var LogFiles: [String]?  // Log dosya isimleri
}
```

### 5. Mesaj Gönderme Örnekleri

#### A) Komut Gönderme
```swift
// JSON komut gönderme
let command = Commands.NewCommands.SENDEMPTYFILEFOLDER(5, 1)
Constants.ConnectionReachability.connectedPeripheral?.writeValue(
    command.data(using: .utf8)!,
    for: Constants.ConnectionReachability.currentCharacteristic!,
    type: .withoutResponse
)

// String komut gönderme (eski cihaz için)
let command = Commands.GETEMPTYFILE(count: 5)
serial.sendMessageToDevice(command)
```

#### B) Dosya Gönderme
```swift
// Dosya verisi gönderme
let data = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
Constants.ConnectionReachability.connectedPeripheral?.writeValue(
    data, 
    for: Constants.ConnectionReachability.currentCharacteristic!, 
    type: .withoutResponse
)
```

### 6. Response İşleme Akışı

1. **Veri Alımı**: `didUpdateValueFor` ile veri alınır
2. **Cihaz Kontrolü**: Yeni cihaz mı eski cihaz mı kontrol edilir
3. **JSON İşleme**: Yeni cihaz için JSON decode edilir
4. **String İşleme**: Eski cihaz için string parse edilir
5. **Delegate Bildirimi**: İlgili delegate metodları çağrılır
6. **UI Güncelleme**: NotificationCenter ile UI güncellenir

### 7. Hata Yönetimi

```swift
// JSON decode hatası
catch {
    let errorMessage = error.localizedDescription
    print("an json handle error: ", errorMessage)
}

// String decode hatası
if let str = String(data: data!, encoding: String.Encoding.utf8) {
    // String işleme
} else {
    print("Received an invalid string!")
}
```

---

## Firmware Update İşlemi

### 1. Mio Firmware Update Başlatma

Mio cihazı için firmware update JSON formatında komutla başlatılır:

```swift
// Mio firmware update komutu
static public func PRG_COMMAND(firmwareModel: FirmwareUpdateDataModel) -> String {
    return """
           {
             "Type": 6,
             "Update": {
               "Version": \(firmwareModel.version ?? 0),
               "Size": \(firmwareModel.totalSize ?? 0)
             }
           }
           """
}

// Firmware update komutunu gönder
let command = Commands.NewCommands.PRG_COMMAND(firmwareModel: updateModel).data(using: .utf8)
Constants.ConnectionReachability.connectedPeripheral?.writeValue(
    command!,
    for: Constants.ConnectionReachability.currentCharacteristic!,
    type: .withoutResponse
)
```

### 2. Mio Firmware Dosyası Hazırlama

```swift
// Mio için firmware dosyası hazırlama
if Constants.ConnectionReachability.isNewDevice {
    var bytes = [UInt8](resultData)
    let paddingSize = AppUtils().mtuSize - bytes.count % AppUtils().mtuSize
    for _ in 0..<paddingSize { bytes.append(0) }
    
    Definations.finalBytes = bytes.chunked(into: AppUtils().mtuSize)
    Definations.totalCount = bytes.count
    
    // Firmware update modeli oluştur
    let updateModel = FirmwareUpdateDataModel.init(
        version: Int(deviceUpdateVersion.replacingOccurrences(of: ".", with: "")), 
        totalSize: resultData.count
    )
    
    // Update komutunu gönder
    let command = Commands.NewCommands.PRG_COMMAND(firmwareModel: updateModel).data(using: .utf8)
    Constants.ConnectionReachability.connectedPeripheral?.writeValue(command!, for: characteristic, type: .withoutResponse)
}
```

### 3. Mio Firmware Update Süreci

Mio cihazı için firmware update süreci şu adımları takip eder:

1. **Update Komutu**: JSON formatında update başlatma komutu gönderilir
2. **Response Bekleme**: Cihazdan response beklenir
3. **Dosya Transferi**: Firmware dosyası paketler halinde gönderilir
4. **İlerleme Takibi**: Transfer ilerlemesi takip edilir
5. **Tamamlama**: Update tamamlandığında cihaz yeniden başlatılır

```swift
// Mio firmware update response işleme
if let currentResponseModel = try? decoder.decode(SuccessResponseBase.self, from: jsonData) {
    if ((AppUtils.isFirmwareUpdate || AppUtils.isAffirmationUpdate) && 
        currentResponseModel.Response?.Result ?? 1 == 0) {
        
        DispatchQueue.main.async {
            // Firmware transfer başlat
            Definations.startTime = CACurrentMediaTime()
            DispatchQueue.global().async {
                for element in Definations.finalBytes {
                    usleep(useconds_t(AppUtils().milisSec))
                    UploadTolkido.sendFileToTolkido(element)
                }
            }
        }
        print("response is firmware update!!")
    }
}
```

### 4. Mio Update Response Yapısı

```swift
struct SuccessResponseBase: Codable {
    var Response: SuccessResponse?
}

struct SuccessResponse: Codable {
    var Result: Int?  // 0 = Başarılı, 1 = Hata
}
```

### 5. Update Tamamlama

```swift
// Update tamamlandığında
if str.contains("FILE OK") {
    AppUtils.isUploadStarted = false
    AppUtils.isCardUpdateStarted = true
    UploadTolkido.sendOnlyOneSound(str: "FILE OK")
}
```

---

## Kullanılan Komutlar

### 1. Mio Temel Komutları (JSON Format)

#### A) Boş Dosya Klasörü Sorgulama
```swift
static public func SENDEMPTYFILEFOLDER(_ count: Int, _ gameMode: Int) -> String {
    return """
           {
             "Type": 2,
             "Request": {
                "GameMode": \(gameMode),
                "FileCount": \(count)
             }
           }
           """
}
```

#### B) Dosya Açma Komutu
```swift
static public func SENDFOPENJSON(_ folder: Int, _ file: Int, _ dataSize: Int) -> String {
    return """
           {
             "Type": 4,
             "Record": {
                "FolderDir": \(folder),
                "File": \(file),
                "Size": \(dataSize)
             }
           }
           """
}
```

#### C) Cihaz Sıfırlama
```swift
static public func RESET_MIO() {
    let string = """
                 {
                   "Type": 15,
                   "Device": 2
                 }
                 """
    Constants.ConnectionReachability.connectedPeripheral?.writeValue(
        string.data(using: .utf8)!,
        for: Constants.ConnectionReachability.currentCharacteristic!,
        type: .withoutResponse
    )
}
```

#### D) Cihazı Tamamen Silme
```swift
static public func ERASEMIO() -> String {
    return """
           {
              "Type": 30,
              "EraseAll": 1
           }
           """
}
```

### 2. Mio Ayarlar Komutları

#### A) Timeout Ayarı
```swift
static public func SENDTIMEOUTJSON(_ timeoutVal: Int) -> String {
    return """
           {
             "Type": 9,
             "Standby": {
                "Timeout": \(timeoutVal)
             }
           }
           """
}
```

#### B) Rastgele Oynatma Ayarı
```swift
static public func SENDAUTOPLAYJSON(_ playVal: Int) -> String {
    return """
           {
             "Type": 27,
             "RandomPlay": \(playVal)
           }
           """
}
```

#### C) Saat Güncelleme
```swift
static public func CLOCK_UPDATE(second: Int, minute: Int, hour: Int, day: Int, month: Int, year: Int) -> String {
    return """
           {
             "Type": 7,
             "SetRTC": {
                "Minute": \(minute),
                "Hour": \(hour),
                "Day": \(day),
                "Month": \(month),
                "Year": \(year)
             }
           }
           """
}
```

### 3. Mio Log Komutları

#### A) Log Listesi Alma
```swift
static public func GET_LOG_LIST() {
    let string = """
                 {
                      "Type": 10,
                      "LogList": 1
                 }
                 """
    Constants.ConnectionReachability.connectedPeripheral?.writeValue(
        string.data(using: .utf8)!,
        for: Constants.ConnectionReachability.currentCharacteristic!,
        type: .withoutResponse
    )
}
```

#### B) Log İçeriği Alma
```swift
static public func GET_LOG_CONTENT(fileName: String) {
    let string = """
                 {
                    "Type": 12,
                    "LogContent": {
                        "FileName": "\(fileName)"
                    }
                 }
                 """
    Constants.ConnectionReachability.connectedPeripheral?.writeValue(
        string.data(using: .utf8)!,
        for: Constants.ConnectionReachability.currentCharacteristic!,
        type: .withoutResponse
    )
}
```

#### C) Log Dosyası Silme
```swift
static public func DELETE_LOG_FILE(fileName: String) {
    let string = """
                 {
                    "Type": 13,
                    "LogDelete": {
                        "FileName": "0-\(fileName)"
                    }
                 }
                 """
    Constants.ConnectionReachability.connectedPeripheral?.writeValue(
        string.data(using: .utf8)!,
        for: Constants.ConnectionReachability.currentCharacteristic!,
        type: .withoutResponse
    )
}
```

---

## Dosya Transferi

### 1. Mio Dosya Gönderme Fonksiyonu

```swift
static public func sendFileToTolkido(_ bytes: [UInt8]) {
    let data = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
    Definations.counter += 1
    usleep(useconds_t(Definations.milisSec))
    
    // İlerleme takibi
    DispatchQueue.main.async {
        if Definations.counter == (Definations.finalBytes.count / 100) * 10 {
            Definations.progressViewProgress = Float("0.\(10)")
            print(".....%10.....")
        }
        // Diğer yüzde kontrolleri...
        
        NotificationCenter.default.post(name: NSNotification.Name.init(rawValue: "refreshCompletion"), object: nil, userInfo: nil)
    }
    
    // Dosya tamamlandığında
    if Definations.counter == Definations.finalBytes.count {
        let anan = Definations.totalCount / 1024
        let baban = CACurrentMediaTime() - Definations.sendStartTime
        let ben = Double(anan) / Double(baban)
        
        Definations.counter = 0
        DispatchQueue.main.async {
            print(".....%100.....")
            print("\(ben) KBps")
            print("Time: \(secondsToHoursMinutesSeconds(seconds: Int(CACurrentMediaTime() - Definations.sendStartTime)))")
            Definations.progressViewProgress = Float("0.\(99)")
            
            if Definations.tolkidoUpdating || AppUtils.isFirmwareUpdate {
                NotificationCenter.default.post(name: .init("updateEnd"), object: nil)
            }
        }
    }
    
    // Veriyi Mio'ya gönder
    Constants.ConnectionReachability.connectedPeripheral?.writeValue(
        data, 
        for: Constants.ConnectionReachability.currentCharacteristic!, 
        type: .withoutResponse
    )
}
```

### 2. Mio Paket Boyutu ve Timing

```swift
// Mio için MTU boyutu
AppUtils().mtuSize = 155

// Mio için timing ayarları (daha hızlı)
static public var milisSec: Int {
    get {
        if UIDevice.modelName.contains("iPhone 6") || UIDevice.modelName.contains("iPhone 6s") || UIDevice.modelName.contains("iPhone 7") || UIDevice.modelName.contains("iPhone SE") {
            return Constants.ConnectionReachability.isNewDevice ? 12000 : 6000
        } else if UIDevice.modelName.contains("iPhone 8") || UIDevice.modelName.contains("iPhone X") || UIDevice.modelName.contains("iPhone 11") || UIDevice.modelName.contains("iPhone 12") {
            return Constants.ConnectionReachability.isNewDevice ? 3500 : 2500
        } else {
            return Constants.ConnectionReachability.isNewDevice ? 6000 : 5000
        }
    }
}
```

### 3. Mio Dosya Hazırlama

```swift
// Mio için dosya hazırlama
if Constants.ConnectionReachability.isNewDevice {
    var bytes = [UInt8](resultData)
    let paddingSize = AppUtils().mtuSize - bytes.count % AppUtils().mtuSize
    for _ in 0..<paddingSize { bytes.append(0) }
    
    Definations.finalBytes = bytes.chunked(into: AppUtils().mtuSize)
    Definations.totalCount = bytes.count
}
```

---

## Eski vs Yeni Cihaz Farkları

### 1. Cihaz Tanımlama

| Özellik | Yeni Mio | Eski Tolkido |
|---------|----------|--------------|
| **Tespit Kriteri** | Seri numarası > 7 karakter | Seri numarası ≤ 7 karakter |
| **Servis UUID** | `9FA480E0-4967-4542-9390-D343DC5D04AE` | `FFF0` |
| **Characteristic UUID** | `AF0BADB1-5B99-43CD-917A-A77BC549E3CC` | `FFF1`, `FFF2`, `FFF3` |

### 2. Komut Formatı

| Özellik | Yeni Mio | Eski Tolkido |
|---------|----------|--------------|
| **Format** | JSON | String |
| **Örnek** | `{"Type": 2, "Request": {...}}` | `"GETEMPTYFILEFOLDERX_1_"` |
| **Parsing** | JSONDecoder | String parsing |

### 3. Performans Farkları

| Özellik | Yeni Mio | Eski Tolkido |
|---------|----------|--------------|
| **Paket Boyutu** | 155 byte (MTU) | 620 byte |
| **Timing (iPhone 8+)** | 3500 μs | 2500 μs |
| **Timing (iPhone 6/7)** | 12000 μs | 6000 μs |

### 4. Veri İşleme

| Özellik | Yeni Mio | Eski Tolkido |
|---------|----------|--------------|
| **Login Data** | JSON Package | String responses |
| **Batarya** | `BatteryVoltage: 387` | `"VBAT=3.87"` |
| **Versiyon** | `FWVersion: 123` | `"ATYOK_V1.2.3"` |

---

## Bağlantı Akış Özeti

### Mio Cihazı İçin Tam Bağlantı Süreci:

1. **🔍 Cihaz Tespiti**: Seri numarası uzunluğuna göre Mio tespit edilir
2. **📡 Bluetooth Tarama**: Yakındaki cihazlar taranır
3. **🔗 Bağlantı Kurma**: Seçilen Mio cihazına bağlantı kurulur
4. **🔧 Servis Keşfi**: `9FA480E0-4967-4542-9390-D343DC5D04AE` servisi keşfedilir
5. **⚙️ Karakteristik Keşfi**: `AF0BADB1-5B99-43CD-917A-A77BC549E3CC` karakteristiği keşfedilir
6. **📢 Bildirim Ayarları**: Tüm karakteristikler için bildirimler etkinleştirilir
7. **✅ Bağlantı Hazır**: `serialIsReady` delegate metodu çağrılır
8. **📦 Login Package**: Cihaz otomatik olarak login package gönderir
9. **🔄 Veri İşleme**: JSON verisi decode edilir ve UI güncellenir
10. **🎯 Kullanıma Hazır**: Cihaz tüm işlemler için hazır

---

## Önemli Notlar

### 1. Mio Özellikleri
- ✅ JSON formatında yapılandırılmış komutlar
- ✅ Daha hızlı veri transferi
- ✅ Gelişmiş hata yönetimi
- ✅ Detaylı log sistemi
- ✅ Otomatik login package

### 2. Bağlantı Durumu
```swift
// Bağlantı durumu kontrolü
var isReady: Bool {
    get {
        return centralManager.state == .poweredOn &&
               connectedPeripheral != nil &&
               writeCharacteristic != nil
    }
}
```

### 3. Hata Yönetimi
- Bluetooth bağlantısı kesildiğinde otomatik yeniden bağlanma
- JSON decode hatalarında uygulama çökmez
- Firmware update sırasında hata durumunda işlemi iptal etme
- Dosya transferi sırasında ilerleme takibi

### 4. Performans Optimizasyonu
- Cihaz modeline göre timing ayarları
- MTU boyutu optimizasyonu (155 byte)
- Background thread kullanımı
- NotificationCenter ile asenkron UI güncellemeleri

---

## Sonuç

Bu rehber, Tolkido projesinde Mio ESP cihazına bağlanma ve firmware update işlemlerinin nasıl gerçekleştirildiğini detaylı olarak açıklamaktadır. Mio cihazı JSON formatında komutlar kullanır ve daha gelişmiş bir haberleşme protokolüne sahiptir. Bağlantı kurulduktan sonra otomatik olarak login package gönderir ve cihaz durumu hakkında detaylı bilgiler sağlar. Firmware update işlemi güvenli bir şekilde paketler halinde gerçekleştirilir ve tüm süreç takip edilir.
