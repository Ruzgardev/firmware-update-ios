//
//  FirmwareUpdateService.swift
//  mio-firmware
//
//  Created by Hüseyin Uludağ on 8.09.2025.
//

import Foundation
import CoreBluetooth
import UIKit
import CoreMedia

// MARK: - FirmwareUpdateDataModel
struct FirmwareUpdateDataModel {
    let version: Int?
    let totalSize: Int?
    let fileName: String?
    let fileData: Data?
}

// MARK: - FirmwareUpdateService
class FirmwareUpdateService: ObservableObject {
    
    // MARK: - Properties
    @Published var updateProgress: Float = 0.0
    @Published var updateStatus: String = "Hazır"
    @Published var isUpdating: Bool = false
    @Published var estimatedTimeRemaining: String = ""
    @Published var transferSpeed: Double = 0.0
    
    private var bluetoothService: BluetoothService?
    private var firmwareData: Data?
    private var firmwarePackets: [[UInt8]] = []
    private var totalPackets: Int = 0
    private var currentPacketIndex: Int = 0
    private var startTime: CFTimeInterval = 0
    private var isNewDevice: Bool = true
    
    // Paket boyutları (sadece yeni cihaz için)
    private let packetSize = 155
    private let totalPacketSize = 155
    private let mtuSize = 155
    
    // MARK: - Initialization
    init() {
        Logger.shared.firmware("FirmwareUpdateService başlatıldı")
    }
    
    // MARK: - Public Methods
    
    /// BluetoothService referansını ayarla
    func setBluetoothService(_ service: BluetoothService) {
        self.bluetoothService = service
    }
    
    /// Firmware dosyasını yükle
    func loadFirmwareFile(fileName: String) -> Bool {
        Logger.shared.firmware("Firmware dosyası yüklenmeye çalışılıyor: \(fileName).bin")
        
        guard let fileURL = Bundle.main.url(forResource: fileName, withExtension: "bin") else {
            updateStatus = "Firmware dosyası bulunamadı"
            Logger.shared.firmware("Firmware dosyası bulunamadı: \(fileName).bin", level: .error)
            return false
        }
        
        Logger.shared.firmware("Firmware dosyası bulundu: \(fileURL.path)")
        
        do {
            firmwareData = try Data(contentsOf: fileURL)
            let fileSize = firmwareData?.count ?? 0
            updateStatus = "Firmware dosyası yüklendi (\(formatFileSize(fileSize)))"
            Logger.shared.firmware("Firmware dosyası başarıyla yüklendi: \(formatFileSize(fileSize))", level: .info)
            return true
        } catch {
            updateStatus = "Firmware dosyası yüklenemedi: \(error.localizedDescription)"
            Logger.shared.firmware("Firmware dosyası yükleme hatası: \(error.localizedDescription)", level: .error)
            return false
        }
    }
    
    /// Firmware update işlemini başlat
    func startFirmwareUpdate(isNewDevice: Bool) {
        guard let firmwareData = firmwareData else {
            updateStatus = "Firmware dosyası yüklenmemiş"
            return
        }
        
        guard bluetoothService?.isReady == true else {
            updateStatus = "Bluetooth bağlantısı hazır değil"
            return
        }
        
        self.isNewDevice = isNewDevice
        isUpdating = true
        updateProgress = 0.0
        currentPacketIndex = 0
        startTime = CACurrentMediaTime()
        
        // Firmware dosyasını hazırla
        prepareFirmwareData()
        
        if isNewDevice {
            startNewDeviceUpdate()
        } else {
            startOldDeviceUpdate()
        }
    }
    
    /// Firmware update işlemini durdur
    func stopFirmwareUpdate() {
        isUpdating = false
        updateStatus = "Update iptal edildi"
        updateProgress = 0.0
    }
    
    // MARK: - Private Methods
    
    /// Firmware verilerini hazırla
    private func prepareFirmwareData() {
        guard let firmwareData = firmwareData else { return }
        
        var bytes = [UInt8](firmwareData)
        
        // Padding ekleme
        let paddingSize = totalPacketSize - bytes.count % totalPacketSize
        for _ in 0..<paddingSize {
            bytes.append(0)
        }
        
        // Dosyayı paketlere böl
        firmwarePackets = bytes.chunked(into: packetSize)
        totalPackets = firmwarePackets.count
        
        updateStatus = "Firmware hazırlandı (\(totalPackets) paket)"
    }
    
    /// Yeni cihaz için update başlat
    private func startNewDeviceUpdate() {
        let firmwareModel = FirmwareUpdateDataModel(
            version: 1,
            totalSize: firmwareData?.count ?? 0,
            fileName: "firmware.bin",
            fileData: firmwareData
        )
        
        let command = Commands.PRG_COMMAND(firmwareModel: firmwareModel)
        bluetoothService?.sendJSON(command)
        
        updateStatus = "Update komutu gönderildi (Yeni cihaz)"
    }
    
    /// Eski cihaz için update başlat
    private func startOldDeviceUpdate() {
        guard let firmwareData = firmwareData else { return }
        
        // CRC32 hesapla
        let crc32 = calculateCRC32(data: firmwareData)
        
        // Update komutunu gönder
        let command = "FOPEN_PRG_\(crc32)_\(firmwareData.count)_0_"
        bluetoothService?.sendString(command)
        
        updateStatus = "Update komutu gönderildi (Eski cihaz)"
    }
    
    /// CRC32 hesapla
    private func calculateCRC32(data: Data) -> String {
        var crc: UInt32 = 0xFFFFFFFF
        let polynomial: UInt32 = 0xEDB88320
        
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ polynomial
                } else {
                    crc >>= 1
                }
            }
        }
        
        crc ^= 0xFFFFFFFF
        return String(format: "%08X", crc)
    }
    
    /// Sonraki paketi gönder
    private func sendNextPacket() {
        guard currentPacketIndex < firmwarePackets.count else { return }
        
        let packet = firmwarePackets[currentPacketIndex]
        let data = Data(packet)
        bluetoothService?.sendData(data)
        
        currentPacketIndex += 1
        updateProgress = Float(currentPacketIndex) / Float(totalPackets)
        
        // İlerleme hesaplama
        let elapsedTime = CACurrentMediaTime() - startTime
        let remainingPackets = totalPackets - currentPacketIndex
        let averageTimePerPacket = elapsedTime / Double(currentPacketIndex)
        let estimatedTimeRemaining = Double(remainingPackets) * averageTimePerPacket
        let estimatedTime = formatTime(estimatedTimeRemaining)
        
        updateStatus = "Gönderiliyor... \(currentPacketIndex)/\(totalPackets) (\(Int(updateProgress * 100))%)"
    }
    
    /// Yeni Mio cihazı için paket gecikmesi hesapla
    private func getPacketDelay() -> Double {
        // Daha yavaş timing - cihazın işlemesi için daha fazla zaman
        let deviceModel = UIDevice.current.model
        
        if deviceModel.contains("iPhone 6") || deviceModel.contains("iPhone 6s") || deviceModel.contains("iPhone 7") || deviceModel.contains("iPhone SE") {
            return 0.050  // 50ms (daha yavaş)
        } else if deviceModel.contains("iPhone 8") || deviceModel.contains("iPhone X") || deviceModel.contains("iPhone 11") || deviceModel.contains("iPhone 12") || deviceModel.contains("iPhone 13") || deviceModel.contains("iPhone 14") || deviceModel.contains("iPhone 15") || deviceModel.contains("iPhone 16") {
            return 0.020  // 20ms (daha yavaş)
        } else {
            return 0.030  // 30ms (daha yavaş)
        }
    }
    
    /// Update işlemini tamamla
    private func completeUpdate() {
        isUpdating = false
        updateProgress = 1.0
        updateStatus = "Dosya gönderimi tamamlandı, FILE OK bekleniyor..."
        
        // MD'ye göre: Dosya gönderimi tamamlandıktan sonra FILE OK mesajı beklenir
        // FILE OK geldiğinde GETUPDATE komutu gönderilir
        // GETUPDATE OK geldiğinde ATYRESTART ile cihaz yeniden başlatılır
        Logger.shared.firmware("Dosya gönderimi tamamlandı, cihazdan FILE OK mesajı bekleniyor...")
    }
    
    /// Update işlemini finalize et
    private func finalizeUpdate() {
        isUpdating = false
        updateProgress = 1.0
        updateStatus = "Firmware update başarıyla tamamlandı!"
        
        let endTime = CACurrentMediaTime()
        let duration = endTime - startTime
        let fileSizeKB = (firmwareData?.count ?? 0) / 1024
        let speed = Double(fileSizeKB) / duration
        
        Logger.shared.firmware("Firmware update tamamlandı!")
        Logger.shared.firmware("Süre: \(String(format: "%.2f", duration)) saniye")
        Logger.shared.firmware("Dosya boyutu: \(fileSizeKB) KB")
        Logger.shared.firmware("Ortalama hız: \(String(format: "%.2f", speed)) KB/s")
    }
    
    /// Bluetooth mesajını işle
    func handleBluetoothMessage(_ message: String) {
        Logger.shared.firmware("Gelen mesaj: \(message)")
        
        // JSON mesajları için özel işlem
        if message.hasPrefix("{") && message.hasSuffix("}") {
            handleJSONMessage(message)
            return
        }
        
        // String mesajları için işlem
        if message.contains("FOPEN") {
            Logger.shared.firmware("FOPEN mesajı alındı, paket gönderimi başlatılıyor...")
            // Eski cihaz için paket göndermeye başla
            DispatchQueue.global().async {
                for _ in 0..<self.firmwarePackets.count {
                    DispatchQueue.main.async {
                        self.sendNextPacket()
                    }
                    usleep(8000) // 8ms bekle
                }
            }
        } else if message.contains("FILE OK") {
            Logger.shared.firmware("FILE OK mesajı alındı, GETUPDATE komutu gönderiliyor...")
            updateStatus = "FILE OK alındı, GETUPDATE gönderiliyor..."
            bluetoothService?.sendString("GETUPDATE")
        } else if message.contains("GETUPDATE OK") {
            Logger.shared.firmware("GETUPDATE OK mesajı alındı, RESET_MIO komutu gönderiliyor...")
            updateStatus = "GETUPDATE OK alındı, RESET_MIO gönderiliyor..."
            
            // Orijinal kodda RESET_MIO komutu gönderilir (JSON format)
            let resetCommand = Commands.RESET_MIO()
            bluetoothService?.sendJSON(resetCommand)
            
            // Cihaz yeniden başlatıldı, update tamamlandı
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.finalizeUpdate()
            }
        } else if message.contains("Login") {
            Logger.shared.firmware("Login mesajı alındı: \(message)")
        } else if message.contains("Error") || message.contains("ERROR") {
            Logger.shared.firmware("Hata mesajı alındı: \(message)", level: .error)
        } else {
            Logger.shared.firmware("Bilinmeyen mesaj: \(message)", level: .warning)
        }
    }
    
    /// JSON mesajını işle
    private func handleJSONMessage(_ jsonString: String) {
        Logger.shared.firmware("JSON mesajı işleniyor: \(jsonString)")
        
        guard let data = jsonString.data(using: .utf8) else {
            Logger.shared.firmware("JSON veriye dönüştürülemedi", level: .error)
            return
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            Logger.shared.firmware("JSON parse edildi: \(json)")
            
            if let dict = json as? [String: Any] {
                // Login mesajı (MD'ye göre otomatik gelir)
                if let login = dict["Login"] as? [String: Any] {
                    Logger.shared.firmware("Login bilgileri alındı: \(login)")
                    handleLoginPackage(login)
                }
                
                // Success Response (MD'ye göre firmware update için önemli)
                if let response = dict["Response"] as? [String: Any] {
                    Logger.shared.firmware("Response alındı: \(response)")
                    handleSuccessResponse(response)
                }
                
                // File OK Response (MD'ye göre dosya transferi tamamlandığında)
                if let fileOK = dict["ResponseType1"] as? [String: Any] {
                    if let result = fileOK["Result"] as? Int, result == 0 {
                        Logger.shared.firmware("FILE OK response alındı, GETUPDATE komutu gönderiliyor...")
                        updateStatus = "FILE OK alındı, GETUPDATE gönderiliyor..."
                        bluetoothService?.sendString("GETUPDATE")
                    }
                }
                
                // GETUPDATE OK Response kontrolü
                if let getUpdateOK = dict["GETUPDATE"] as? [String: Any] {
                    if let result = getUpdateOK["Result"] as? Int, result == 0 {
                        Logger.shared.firmware("GETUPDATE OK response alındı, RESET_MIO komutu gönderiliyor...")
                        updateStatus = "GETUPDATE OK alındı, RESET_MIO gönderiliyor..."
                        
                        // Orijinal kodda RESET_MIO komutu gönderilir (JSON format)
                        let resetCommand = Commands.RESET_MIO()
                        bluetoothService?.sendJSON(resetCommand)
                        
                        // Cihaz yeniden başlatıldı, update tamamlandı
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.finalizeUpdate()
                        }
                    }
                }
                
                // Hata mesajı
                if let error = dict["Error"] as? String {
                    Logger.shared.firmware("Hata mesajı: \(error)", level: .error)
                }
                
                // Başarı mesajı
                if let success = dict["Success"] as? Bool {
                    Logger.shared.firmware("Başarı durumu: \(success)")
                }
            }
        } catch {
            Logger.shared.firmware("JSON parse hatası: \(error.localizedDescription)", level: .error)
        }
    }
    
    /// Login package işle (MD'ye göre)
    private func handleLoginPackage(_ login: [String: Any]) {
        if let uniqueID = login["UniqueID"] as? String {
            Logger.shared.firmware("Cihaz ID: \(uniqueID)")
        }
        if let battery = login["BatteryVoltage"] as? Int {
            Logger.shared.firmware("Batarya: \(battery) mV")
            // MD'ye göre batarya seviyesi kontrolü
            if battery >= 387 {
                Logger.shared.firmware("Batarya: %100")
            } else if battery >= 370 && battery <= 386 {
                Logger.shared.firmware("Batarya: %50")
            } else if battery <= 369 {
                Logger.shared.firmware("Batarya: %25")
            }
        }
        if let version = login["FWVersion"] as? Int {
            Logger.shared.firmware("Firmware versiyonu: \(version)")
            // MD'ye göre versiyonu noktalı formata çevir
            let versionString = String(version)
            var formattedVersion = ""
            for (index, char) in versionString.enumerated() {
                if index == versionString.count - 1 {
                    formattedVersion += "\(char)"
                } else {
                    formattedVersion += "\(char)."
                }
            }
            Logger.shared.firmware("Formatlanmış versiyon: \(formattedVersion)")
        }
        if let timeout = login["Timeout"] as? Int {
            Logger.shared.firmware("Timeout: \(timeout) dakika")
        }
        if let randomPlay = login["RandomPlay"] as? Int {
            Logger.shared.firmware("Random Play: \(randomPlay == 1 ? "Açık" : "Kapalı")")
        }
    }
    
    /// Success Response işle (MD'ye göre firmware update için kritik)
    private func handleSuccessResponse(_ response: [String: Any]) {
        if let result = response["Result"] as? Int {
            Logger.shared.firmware("Response Result: \(result)")
            
            // MD'ye göre: Result = 0 ise başarılı, firmware update başlat
            if result == 0 && isUpdating {
                Logger.shared.firmware("Firmware update onayı alındı, dosya gönderimi başlatılıyor...")
                startFileTransfer()
            } else if result != 0 {
                Logger.shared.firmware("Firmware update reddedildi", level: .error)
                isUpdating = false
                updateStatus = "Update reddedildi"
            }
        }
    }
    
    /// Dosya transferini başlat (MD'ye göre)
    private func startFileTransfer() {
        Logger.shared.firmware("Dosya transferi başlatılıyor...")
        updateStatus = "Dosya gönderiliyor..."
        
        // Daha yavaş ve güvenli transfer
        DispatchQueue.global().async {
            for (index, packet) in self.firmwarePackets.enumerated() {
                DispatchQueue.main.async {
                    self.sendPacket(packet, index: index)
                }
                
                // Daha yavaş timing - cihazın işlemesi için
                let delay = self.getPacketDelay()
                usleep(useconds_t(delay * 1000000)) // saniyeyi mikrosaniyeye çevir
                
                // Her 50 pakette bir ekstra bekleme
                if (index + 1) % 50 == 0 {
                    Logger.shared.firmware("50 paket gönderildi, ekstra bekleme...")
                    usleep(100000) // 100ms ekstra bekleme
                }
            }
        }
    }
    
    /// Paket gönder
    private func sendPacket(_ packet: [UInt8], index: Int) {
        let data = Data(packet)
        bluetoothService?.sendData(data)
        
        currentPacketIndex = index + 1
        updateProgress = Float(currentPacketIndex) / Float(totalPackets)
        updateStatus = "Gönderiliyor... \(currentPacketIndex)/\(totalPackets) (\(Int(updateProgress * 100))%)"
        
        // İlerleme hesaplama
        let elapsedTime = CACurrentMediaTime() - startTime
        let remainingPackets = totalPackets - currentPacketIndex
        let averageTimePerPacket = elapsedTime / Double(currentPacketIndex)
        let estimatedTimeRemaining = Double(remainingPackets) * averageTimePerPacket
        self.estimatedTimeRemaining = formatTime(estimatedTimeRemaining)
        
        // Transfer hızı hesaplama
        let fileSizeKB = (firmwareData?.count ?? 0) / 1024
        transferSpeed = Double(fileSizeKB) / elapsedTime
        
        // Sadece her 100 pakette bir log (çok yer kaplamasın)
        if (index + 1) % 100 == 0 || index == 0 {
            Logger.shared.firmware("Paket gönderildi: \(index + 1)/\(totalPackets)")
        }
        
        // Son paket gönderildi
        if currentPacketIndex >= totalPackets {
            completeUpdate()
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Array Extension
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
