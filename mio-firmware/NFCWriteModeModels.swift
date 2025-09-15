//
//  NFCWriteModeModels.swift
//  mio-firmware
//
//  Created by Hüseyin Uludağ on 8.09.2025.
//

import Foundation

// MARK: - NFC Write Mode Data Models

struct CardData: Codable, Identifiable {
    let id = UUID()
    var name: String
    let block4: String
    let block5: String
    let block6: String
    let block7: String
    let block8: String
    
    init(name: String = "", block4: String, block5: String, block6: String, block7: String, block8: String) {
        self.name = name
        self.block4 = block4
        self.block5 = block5
        self.block6 = block6
        self.block7 = block7
        self.block8 = block8
    }
    
    enum CodingKeys: String, CodingKey {
        case name
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

// MARK: - NFC Write Mode Commands

struct NFCWriteModeCommands {
    
    /// Yazma modu başlat komutu
    static func startWriteMode(cardData: CardData) -> [String: Any] {
        return [
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
        ]
    }
    
    /// Yazma modu durdur komutu
    static func stopWriteMode() -> [String: Any] {
        return [
            "Type": 51,
            "WriteMode": [
                "Action": "STOP"
            ]
        ]
    }
}

