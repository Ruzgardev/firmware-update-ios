//
//  BluetoothService.swift
//  mio-firmware
//
//  Created by Hüseyin Uludağ on 8.09.2025.
//

import Foundation
import CoreBluetooth
import SwiftUI

// MARK: - Bluetooth Service Delegate
protocol BluetoothServiceDelegate {
    func serialIsReady(_ peripheral: CBPeripheral, isNew: Bool)
    func serialDidReceiveString(_ message: String)
    func serialDidDisconnect(_ peripheral: CBPeripheral, error: Error?)
    func serialDidChangeState()
}

// MARK: - Bluetooth Service
class BluetoothService: NSObject, ObservableObject {
    
    // MARK: - Properties
    var delegate: BluetoothServiceDelegate?
    
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectionStatus = "Bağlantı yok"
    
    // Bluetooth Manager
    private var centralManager: CBCentralManager!
    private var pendingPeripheral: CBPeripheral?
    
    // Service and Characteristic UUIDs
    private var serviceUUID = CBUUID(string: "FFF0")
    private var RXCharacteristic = CBUUID(string: "FFF1")
    private var TXCharacteristic = CBUUID(string: "FFF2")
    private var RRXCharacteristic = CBUUID(string: "FFF3")
    
    // Mio için özel UUID'ler
    private let MIO_SERVICE_UUID = "9FA480E0-4967-4542-9390-D343DC5D04AE"
    private let MIO_CHARACTERISTIC_UUID = "AF0BADB1-5B99-43CD-917A-A77BC549E3CC"
    
    // Connection properties
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var txCharacteristic: CBCharacteristic?
    var isNewDevice = false
    
    // MARK: - Initialization
    override init() {
        super.init()
        Logger.shared.bluetooth("BluetoothService başlatılıyor...")
        centralManager = CBCentralManager(delegate: self, queue: nil)
        Logger.shared.bluetooth("CBCentralManager oluşturuldu")
    }
    
    // MARK: - Public Methods
    
    /// Bluetooth taramayı başlat
    func startScan() {
        Logger.shared.bluetooth("Tarama başlatılmaya çalışılıyor...")
        Logger.shared.bluetooth("Bluetooth durumu: \(centralManager.state.rawValue)")
        
        guard centralManager.state == .poweredOn else {
            connectionStatus = "Bluetooth kapalı"
            Logger.shared.bluetooth("Bluetooth kapalı, tarama başlatılamıyor", level: .error)
            return
        }
        
        isScanning = true
        discoveredPeripherals.removeAll()
        connectionStatus = "Cihazlar taranıyor..."
        
        Logger.shared.bluetooth("Bluetooth tarama başlatılıyor...")
        Logger.shared.bluetooth("Tarama seçenekleri: AllowDuplicates=false")
        
        // Hem eski hem yeni cihazları taramak için servis UUID'si belirtmeden tarama yap
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        
        Logger.shared.bluetooth("scanForPeripherals çağrıldı")
    }
    
    /// Bluetooth taramayı durdur
    func stopScan() {
        Logger.shared.bluetooth("Tarama durduruluyor...")
        centralManager.stopScan()
        isScanning = false
        connectionStatus = "Tarama durduruldu"
        Logger.shared.bluetooth("Tarama durduruldu")
    }
    
    /// Cihaza bağlan
    func connectToPeripheral(_ peripheral: CBPeripheral) {
        Logger.shared.connection("Cihaza bağlanmaya çalışılıyor: \(peripheral.name ?? "Bilinmeyen")")
        Logger.shared.connection("Cihaz UUID: \(peripheral.identifier)")
        Logger.shared.connection("Cihaz durumu: \(peripheral.state.rawValue)")
        
        pendingPeripheral = peripheral
        connectionStatus = "Bağlanıyor..."
        
        Logger.shared.connection("centralManager.connect çağrılıyor...")
        centralManager.connect(peripheral, options: nil)
    }
    
    /// Bağlantıyı kes
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    /// Veri gönder
    func sendData(_ data: Data) {
        guard let characteristic = writeCharacteristic else { 
            Logger.shared.connection("Veri gönderilemedi: karakteristik bulunamadı", level: .error)
            return 
        }
        
        guard let peripheral = connectedPeripheral else {
            Logger.shared.connection("Veri gönderilemedi: cihaz bağlı değil", level: .error)
            return
        }
        
        Logger.shared.connection("Veri gönderiliyor: \(data.count) byte")
        Logger.shared.connection("Karakteristik: \(characteristic.uuid.uuidString)")
        
        // Mesaj loguna ekle
        if let string = String(data: data, encoding: .utf8) {
            BluetoothMessageLogger.shared.logOutgoingMessage(string, rawData: data)
        } else {
            let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            BluetoothMessageLogger.shared.logOutgoingMessage(hexString, rawData: data)
        }
        
        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        Logger.shared.connection("Veri gönderildi: \(data.count) byte")
    }
    
    /// String gönder
    func sendString(_ string: String) {
        Logger.shared.connection("String gönderiliyor: \(string)")
        guard let data = string.data(using: .utf8) else { 
            Logger.shared.connection("String veriye dönüştürülemedi", level: .error)
            return 
        }
        sendData(data)
    }
    
    /// JSON gönder
    func sendJSON(_ jsonString: String) {
        Logger.shared.connection("JSON gönderiliyor: \(jsonString)")
        sendString(jsonString)
    }
    
    // MARK: - Computed Properties
    
    var isReady: Bool {
        return centralManager.state == .poweredOn &&
               connectedPeripheral != nil &&
               writeCharacteristic != nil
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothService: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Logger.shared.bluetooth("Bluetooth durumu güncellendi: \(central.state.rawValue)")
        
        switch central.state {
        case .poweredOn:
            connectionStatus = "Bluetooth hazır"
            Logger.shared.bluetooth("Bluetooth açık ve hazır", level: .info)
        case .poweredOff:
            connectionStatus = "Bluetooth kapalı"
            Logger.shared.bluetooth("Bluetooth kapalı", level: .warning)
        case .resetting:
            connectionStatus = "Bluetooth sıfırlanıyor"
            Logger.shared.bluetooth("Bluetooth sıfırlanıyor", level: .warning)
        case .unauthorized:
            connectionStatus = "Bluetooth yetkisi yok"
            Logger.shared.bluetooth("Bluetooth yetkisi yok", level: .error)
        case .unsupported:
            connectionStatus = "Bluetooth desteklenmiyor"
            Logger.shared.bluetooth("Bluetooth desteklenmiyor", level: .error)
        case .unknown:
            connectionStatus = "Bluetooth durumu bilinmiyor"
            Logger.shared.bluetooth("Bluetooth durumu bilinmiyor", level: .warning)
        @unknown default:
            connectionStatus = "Bilinmeyen durum"
            Logger.shared.bluetooth("Bilinmeyen Bluetooth durumu", level: .error)
        }
        
        delegate?.serialDidChangeState()
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        let deviceName = peripheral.name ?? "Bilinmeyen"
        let rssiValue = RSSI.intValue
        
        Logger.shared.bluetooth("Cihaz keşfedildi: \(deviceName)")
        Logger.shared.bluetooth("UUID: \(peripheral.identifier)")
        Logger.shared.bluetooth("RSSI: \(rssiValue) dBm")
        Logger.shared.bluetooth("Advertisement Data: \(advertisementData)")
        
        // Cihaz tipini tespit et (seri numarası uzunluğuna göre)
        let isNewDevice = detectDeviceType(deviceName: deviceName)
        Logger.shared.bluetooth("Cihaz tipi tespit edildi: \(isNewDevice ? "Yeni Mio" : "Eski Tolkido")")
        
        // Sadece Mio veya Tolkido cihazlarını listele
        if deviceName.contains("Mio") || deviceName.contains("Tolkido") || deviceName.contains("ESP") {
            Logger.shared.bluetooth("Uygun cihaz bulundu: \(deviceName)", level: .info)
            
            // Aynı cihazı tekrar ekleme
            if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                discoveredPeripherals.append(peripheral)
                Logger.shared.bluetooth("Cihaz listeye eklendi: \(deviceName)")
            } else {
                Logger.shared.bluetooth("Cihaz zaten listede: \(deviceName)")
            }
        } else {
            Logger.shared.bluetooth("Cihaz filtrelendi (uygun değil): \(deviceName)")
        }
    }
    
    /// Cihaz tipini tespit et (seri numarası uzunluğuna göre)
    private func detectDeviceType(deviceName: String) -> Bool {
        // Cihaz adından seri numarasını çıkar
        let splitedDigit = deviceName.split(separator: "-")
        if splitedDigit.count >= 2 {
            let stringDigit = String(splitedDigit[1])
            let isNew = stringDigit.count > 7
            Logger.shared.bluetooth("Seri numarası: \(stringDigit), Uzunluk: \(stringDigit.count), Yeni cihaz: \(isNew)")
            return isNew
        } else {
            Logger.shared.bluetooth("Seri numarası bulunamadı, yeni cihaz olarak kabul ediliyor")
            return true  // Sadece yeni cihaz kullanıyoruz
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Logger.shared.connection("Bağlantı başarılı: \(peripheral.name ?? "Bilinmeyen")", level: .info)
        Logger.shared.connection("Cihaz UUID: \(peripheral.identifier)")
        
        // Bağlantı kurulduğunda taramayı durdur
        if isScanning {
            stopScan()
            Logger.shared.connection("Bağlantı kuruldu, tarama durduruldu")
        }
        
        // Cihaz tipini tespit et
        let deviceName = peripheral.name ?? "Bilinmeyen"
        isNewDevice = detectDeviceType(deviceName: deviceName)
        Logger.shared.connection("Bağlanan cihaz tipi: Yeni Mio", level: .info)
        
        connectedPeripheral = peripheral
        peripheral.delegate = self
        connectionStatus = "Bağlandı - Servisler keşfediliyor..."
        isConnected = true
        
        Logger.shared.connection("Servis keşfi başlatılıyor...")
        // Servisleri keşfet
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let errorMessage = error?.localizedDescription ?? "Bilinmeyen hata"
        Logger.shared.connection("Bağlantı başarısız: \(peripheral.name ?? "Bilinmeyen")", level: .error)
        Logger.shared.connection("Hata: \(errorMessage)", level: .error)
        
        connectionStatus = "Bağlantı başarısız: \(errorMessage)"
        isConnected = false
        delegate?.serialDidDisconnect(peripheral, error: error)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripheral = nil
        writeCharacteristic = nil
        txCharacteristic = nil
        connectionStatus = "Bağlantı kesildi"
        isConnected = false
        delegate?.serialDidDisconnect(peripheral, error: error)
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothService: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            Logger.shared.connection("Servis keşfi hatası: \(error.localizedDescription)", level: .error)
            return
        }
        
        guard let services = peripheral.services else {
            Logger.shared.connection("Hiç servis bulunamadı", level: .warning)
            return
        }
        
        Logger.shared.connection("\(services.count) servis keşfedildi")
        
        for service in services {
            Logger.shared.connection("Servis bulundu: \(service.uuid.uuidString)")
            
            // Yeni Mio cihazı için servisler (hem yeni hem eski format)
            if service.uuid.uuidString == MIO_SERVICE_UUID || service.uuid.uuidString == "00FF" {
                Logger.shared.connection("Yeni Mio cihazı tespit edildi! Servis: \(service.uuid.uuidString)", level: .info)
                serviceUUID = CBUUID(string: service.uuid.uuidString)
                
                // Servis tipine göre karakteristik UUID'leri ayarla
                if service.uuid.uuidString == MIO_SERVICE_UUID {
                    // Yeni format
                    RXCharacteristic = CBUUID(string: MIO_CHARACTERISTIC_UUID)
                    TXCharacteristic = CBUUID(string: MIO_CHARACTERISTIC_UUID)
                    RRXCharacteristic = CBUUID(string: MIO_CHARACTERISTIC_UUID)
                    Logger.shared.connection("Yeni format karakteristikleri kullanılıyor")
                } else {
                    // 00FF servisi için - tüm karakteristikleri keşfet
                    Logger.shared.connection("00FF servisi için tüm karakteristikleri keşfediliyor...")
                    peripheral.discoverCharacteristics(nil, for: service)
                    return  // Erken çıkış, karakteristik keşfi tamamlandığında devam edecek
                }
                
                isNewDevice = true
                Logger.shared.connection("Mio karakteristikleri keşfediliyor...")
                peripheral.discoverCharacteristics([RXCharacteristic, TXCharacteristic, RRXCharacteristic], for: service)
            } else {
                Logger.shared.connection("Desteklenmeyen servis: \(service.uuid.uuidString)", level: .warning)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            Logger.shared.connection("Karakteristik keşfi hatası: \(error.localizedDescription)", level: .error)
            return
        }
        
        Logger.shared.connection("Karakteristik keşfi tamamlandı. Servis: \(service.uuid.uuidString)")
        Logger.shared.connection("Aranan servis: \(serviceUUID.uuidString)")
        
        guard service.uuid == serviceUUID else { 
            Logger.shared.connection("Servis UUID eşleşmiyor, karakteristik keşfi atlanıyor", level: .warning)
            return 
        }
        
        guard let characteristics = service.characteristics else {
            Logger.shared.connection("Hiç karakteristik bulunamadı", level: .warning)
            return
        }
        
        Logger.shared.connection("\(characteristics.count) karakteristik bulundu")
        
        // 00FF servisi için özel işlem
        if service.uuid.uuidString == "00FF" {
            Logger.shared.connection("00FF servisi karakteristikleri işleniyor...")
            
            for characteristic in characteristics {
                Logger.shared.connection("Karakteristik bulundu: \(characteristic.uuid.uuidString)")
                
                // İlk bulunan karakteristiği kullan
                if writeCharacteristic == nil {
                    writeCharacteristic = characteristic
                    txCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    Logger.shared.connection("Ana karakteristik ayarlandı: \(characteristic.uuid.uuidString)")
                }
            }
            
            // Bağlantı hazır
            if writeCharacteristic != nil {
                connectionStatus = "Bağlantı hazır"
                Logger.shared.connection("Bağlantı hazır! Cihaz türü: Yeni Mio", level: .info)
                delegate?.serialIsReady(peripheral, isNew: isNewDevice)
            }
            return
        }
        
        // Normal karakteristik işleme
        for characteristic in characteristics {
            Logger.shared.connection("Karakteristik bulundu: \(characteristic.uuid.uuidString)")
            
            if characteristic.uuid == RXCharacteristic {
                Logger.shared.connection("RX karakteristiği bulundu: \(characteristic.uuid.uuidString)")
                peripheral.setNotifyValue(true, for: characteristic)
                writeCharacteristic = characteristic
            }
            
            if characteristic.uuid == TXCharacteristic {
                Logger.shared.connection("TX karakteristiği bulundu: \(characteristic.uuid.uuidString)")
                peripheral.setNotifyValue(true, for: characteristic)
                writeCharacteristic = characteristic
                txCharacteristic = characteristic
            }
            
            if characteristic.uuid == RRXCharacteristic {
                Logger.shared.connection("RRX karakteristiği bulundu: \(characteristic.uuid.uuidString)")
                peripheral.setNotifyValue(true, for: characteristic)
                writeCharacteristic = characteristic
                
                // Bağlantı hazır
                connectionStatus = "Bağlantı hazır"
                Logger.shared.connection("Bağlantı hazır! Cihaz türü: Yeni Mio", level: .info)
                delegate?.serialIsReady(peripheral, isNew: isNewDevice)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            Logger.shared.connection("Veri alma hatası: \(error.localizedDescription)", level: .error)
            return
        }
        
        guard let data = characteristic.value else { 
            Logger.shared.connection("Gelen veri boş", level: .warning)
            return 
        }
        
        Logger.shared.connection("Veri alındı: \(data.count) byte")
        Logger.shared.connection("Karakteristik: \(characteristic.uuid.uuidString)")
        Logger.shared.connection("Ham veri: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // String olarak çözümle
        if let string = String(data: data, encoding: .utf8) {
            Logger.shared.connection("String veri: \(string)")
            print("🔵 MIO RESPONSE: \(string)") // Debug için
            
            // Mesaj loguna ekle
            BluetoothMessageLogger.shared.logIncomingMessage(string, rawData: data)
            print("🔵 MESSAGE LOGGED: \(string)") // Debug için
            
            delegate?.serialDidReceiveString(string)
        } else {
            Logger.shared.connection("Veri string olarak çözülemedi", level: .warning)
            // Hex string olarak gönder
            let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            Logger.shared.connection("Hex veri: \(hexString)")
            print("🔵 MIO HEX RESPONSE: \(hexString)") // Debug için
            
            // Mesaj loguna ekle
            BluetoothMessageLogger.shared.logIncomingMessage(hexString, rawData: data)
            print("🔵 HEX MESSAGE LOGGED: \(hexString)") // Debug için
            
            delegate?.serialDidReceiveString(hexString)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            Logger.shared.connection("Notification state update error: \(error.localizedDescription)", level: .error)
        } else {
            Logger.shared.connection("Notification state updated for characteristic: \(characteristic.uuid.uuidString)")
            Logger.shared.connection("Notification enabled: \(characteristic.isNotifying)")
        }
    }
}
