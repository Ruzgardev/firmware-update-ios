//
//  Commands.swift
//  mio-firmware
//
//  Created by Hüseyin Uludağ on 8.09.2025.
//

import Foundation

// MARK: - Commands
struct Commands {
    
    // MARK: - Temel Komutlar
    
    /// Cihaz durumu sorgulama
    static func ATY() -> String {
        return "ATY?"
    }
    
    /// Batarya seviyesi sorgulama
    static func VBAT() -> String {
        return "VBAT?"
    }
    
    /// Seri numarası sorgulama
    static func RUNIQID() -> String {
        return "RUNIQID"
    }
    
    /// Cihazı yeniden başlatma
    static func ATYRESTART() -> String {
        return "ATYRESTART"
    }
    
    /// Update başlatma
    static func GETUPDATE() -> String {
        return "GETUPDATE"
    }
    
    // MARK: - Yeni Mio Komutları (JSON Format)
    
    /// Firmware update komutu (Yeni Mio için)
    static func PRG_COMMAND(firmwareModel: FirmwareUpdateDataModel) -> String {
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
    
    /// Boş dosya klasörü sorgulama
    static func SENDEMPTYFILEFOLDER(_ count: Int, _ gameMode: Int) -> String {
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
    
    /// Dosya açma komutu
    static func SENDFOPENJSON(_ folder: Int, _ file: Int, _ dataSize: Int) -> String {
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
    
    /// Cihazı sıfırlama
    static func RESET_MIO() -> String {
        return """
               {
                 "Type": 15,
                 "Device": 2
               }
               """
    }
    
    /// Zaman aşımı ayarlama
    static func SET_TIMEOUT(_ timeout: Int) -> String {
        return """
               {
                 "Type": 9,
                 "Standby": {
                    "Timeout": \(timeout)
                 }
               }
               """
    }
    
    /// Log listesi alma
    static func GET_LOG_LIST() -> String {
        return """
               {
                 "Type": 10,
                 "LogList": 1
               }
               """
    }
    
    /// Log içeriği alma
    static func GET_LOG_CONTENT(_ fileName: String) -> String {
        return """
               {
                 "Type": 12,
                 "LogContent": {
                    "FileName": "\(fileName)"
                 }
               }
               """
    }
    
    /// Cihaz bilgilerini alma
    static func GET_DEVICE_INFO() -> String {
        return """
               {
                 "Type": 1,
                 "Request": {
                    "Info": 1
                 }
               }
               """
    }
    
    /// Random play ayarlama
    static func SET_RANDOM_PLAY(_ enabled: Bool) -> String {
        return """
               {
                 "Type": 8,
                 "RandomPlay": \(enabled ? 1 : 0)
               }
               """
    }
    
    // MARK: - Eski Tolkido Komutları
    
    /// Eski Tolkido için firmware update
    static func UPDATETOLKIDO(crc32: String, totalCount: Int) -> String {
        return "FOPEN_PRG_\(crc32)_\(totalCount)_0_"
    }
    
    // MARK: - Test Komutları
    
    /// Test komutu
    static func TEST() -> String {
        return "TEST"
    }
    
    /// Ping komutu
    static func PING() -> String {
        return "PING"
    }
    
    /// Cihaz bilgilerini al
    static func DEVICE_INFO() -> String {
        return "DEVICE_INFO"
    }
}
