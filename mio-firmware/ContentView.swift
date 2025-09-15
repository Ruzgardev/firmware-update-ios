//
//  ContentView.swift
//  mio-firmware
//
//  Created by Hüseyin Uludağ on 8.09.2025.
//

import SwiftUI
import CoreBluetooth

// MARK: - Theme Colors
extension Color {
    static let productionPurple = Color(red: 0.6, green: 0.2, blue: 0.8)
    static let productionPurpleLight = Color(red: 0.8, green: 0.6, blue: 0.9)
    static let productionPurpleDark = Color(red: 0.4, green: 0.1, blue: 0.6)
    static let productionBackground = Color(red: 0.95, green: 0.9, blue: 0.98)
    static let productionCardBackground = Color(red: 0.98, green: 0.95, blue: 1.0)
}

struct ContentView: View {
    @StateObject private var bluetoothService = BluetoothService()
    @StateObject private var firmwareService: FirmwareUpdateService
    @State private var selectedPeripheral: CBPeripheral?
    @State private var showingDeviceInfo = false
    
    // Theme properties
    private var isProductionMode: Bool {
        firmwareService.isProductionMode
    }
    
    private var primaryColor: Color {
        isProductionMode ? .productionPurple : .blue
    }
    
    private var backgroundColor: Color {
        isProductionMode ? .productionBackground : Color(.systemBackground)
    }
    
    private var cardBackgroundColor: Color {
        isProductionMode ? .productionCardBackground : Color(.systemGray6)
    }
    
    // MARK: - Button Views
    
    private var normalFirmwareButtons: some View {
        VStack(spacing: 10) {
            // Normal firmware update
            Button("Mio Firmware Update") {
                firmwareService.startFirmwareUpdate(isNewDevice: true, firmwareType: .normal)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!bluetoothService.isReady)
            
            // Üretim modu firmware update
            Button("Üretim Modu Firmware Update") {
                firmwareService.startFirmwareUpdate(isNewDevice: true, firmwareType: .production)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(!bluetoothService.isReady)
        }
    }
    
    private var nfcWriteModeButtons: some View {
        VStack(spacing: 15) {
            // NFC Yazma Modu Durum
            HStack {
                Circle()
                    .fill(firmwareService.isWriteModeActive ? .green : .gray)
                    .frame(width: 12, height: 12)
                
                Text(firmwareService.writeModeStatusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
        }
    }
    
    init() {
        let bluetooth = BluetoothService()
        _bluetoothService = StateObject(wrappedValue: bluetooth)
        let firmware = FirmwareUpdateService()
        firmware.setBluetoothService(bluetooth)
        _firmwareService = StateObject(wrappedValue: firmware)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Ana Sayfa
                    mainView
                    
                    // Mesaj Logları - sadece bağlantı kurulduktan sonra göster
                    if bluetoothService.isConnected {
                        messageLogView
                    }
                }
            }
            .background(backgroundColor)
            .navigationTitle(isProductionMode ? "Mio Üretim Modu" : "Mio Firmware Update")
            .navigationBarTitleDisplayMode(.inline)
            .onTapGesture {
                // Klavyeyi kapat
                hideKeyboard()
            }
        }
        .background(backgroundColor)
        .onAppear {
            bluetoothService.delegate = self
            _ = firmwareService.loadFirmwareFile(fileName: "firmware", firmwareType: .normal)
        }
    }
    
    // MARK: - Helper Functions
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    
    // MARK: - Main View
    private var mainView: some View {
        VStack(spacing: 20) {
            // Header
            headerView
            
            if bluetoothService.isConnected {
                // Bağlantı kurulduktan sonra sadece firmware update kısmını göster
                firmwareUpdateView
            } else {
                // Bağlantı yokken cihaz listesi ve bağlantı durumunu göster
                // Connection Status
                connectionStatusView
                
                // Device List
                if bluetoothService.isScanning || !bluetoothService.discoveredPeripherals.isEmpty {
                    deviceListView
                }
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if bluetoothService.isScanning {
                        bluetoothService.stopScan()
                    } else {
                        bluetoothService.startScan()
                    }
                }) {
                    Image(systemName: bluetoothService.isScanning ? "stop.circle.fill" : "magnifyingglass.circle.fill")
                        .foregroundColor(primaryColor)
                }
            }
        }
    }
    
    // MARK: - Message Log View
    private var messageLogView: some View {
        VStack(spacing: 0) {
            // Divider
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Mesaj log alanı
            BluetoothMessageLogView(bluetoothService: bluetoothService, firmwareService: firmwareService)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 10) {
            Image(systemName: isProductionMode ? "gear.badge.checkmark" : "antenna.radiowaves.left.and.right")
                .font(.system(size: 50))
                .foregroundColor(primaryColor)
            
            Text(isProductionMode ? "Mio ESP Üretim Modu" : "Mio ESP Firmware Update")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(isProductionMode ? .productionPurpleDark : .primary)
            
            Text(isProductionMode ? "Üretim modu aktif - Versiyon \(firmwareService.deviceFirmwareVersion)" : "Bluetooth ile firmware güncelleme")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Kart Okuma Butonu (Sadece Üretim Modunda)
            if isProductionMode {
                Button("Kart Oku") {
                    firmwareService.readCard()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(!bluetoothService.isReady)
            }
            
            // Son Okunan Kart Data (Sadece Üretim Modunda)
            if isProductionMode, let cardData = firmwareService.lastReadCardData {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Son Okunan Kart Data")
                        .font(.headline)
                        .foregroundColor(.productionPurpleDark)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Block4: \(cardData.block4)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Block5: \(cardData.block5)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Block6: \(cardData.block6)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Block7: \(cardData.block7)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Block8: \(cardData.block8)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Kart Setine Ekle Butonu
                    NavigationLink(destination: AddCardToSetView(cardData: cardData)) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Kart Setine Ekle")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(primaryColor)
                        .cornerRadius(15)
                    }
                }
            }
            
            // Kart Setleri Butonu (Sadece Üretim Modunda)
            if isProductionMode {
                NavigationLink(destination: CardSetsView(bluetoothService: bluetoothService, firmwareService: firmwareService)) {
                    HStack {
                        Image(systemName: "creditcard.and.123")
                        Text("Kart Setleri")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(primaryColor)
                    .cornerRadius(20)
                }
            }
        }
    }
    
    // MARK: - Connection Status View
    private var connectionStatusView: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(bluetoothService.isConnected ? .green : .red)
                    .frame(width: 12, height: 12)
                
                Text(bluetoothService.connectionStatus)
                    .font(.headline)
                
                Spacer()
            }
            
            if bluetoothService.isConnected {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Cihaz:")
                        Text(selectedPeripheral?.name ?? "Bilinmeyen")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    HStack {
                        Text("Tip:")
                        Text(isProductionMode ? "Üretim Modu Mio" : "Yeni Mio")
                            .fontWeight(.semibold)
                            .foregroundColor(primaryColor)
                        Spacer()
                    }
                    
                    HStack {
                        Text("Servis:")
                        Text("9FA480E0-4967-4542-9390-D343DC5D04AE")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(10)
    }
    
    // MARK: - Device List View
    private var deviceListView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bulunan Cihazlar")
                .font(.headline)
            
            if bluetoothService.discoveredPeripherals.isEmpty && bluetoothService.isScanning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Cihazlar taranıyor...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else {
                ForEach(bluetoothService.discoveredPeripherals, id: \.identifier) { peripheral in
                    DeviceRowView(
                        peripheral: peripheral,
                        isSelected: selectedPeripheral?.identifier == peripheral.identifier,
                        onTap: {
                            selectedPeripheral = peripheral
                            bluetoothService.connectToPeripheral(peripheral)
                        },
                        firmwareService: firmwareService
                    )
                }
            }
        }
    }
    
    // MARK: - Firmware Update View
    private var firmwareUpdateView: some View {
        VStack(spacing: 15) {
            Text("Firmware Update")
                .font(.headline)
            
            // Progress Bar
            if firmwareService.isUpdating {
                VStack(spacing: 8) {
                    ProgressView(value: firmwareService.updateProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    HStack {
                        Text("İlerleme: \(Int(firmwareService.updateProgress * 100))%")
                        Spacer()
                        Text(firmwareService.estimatedTimeRemaining)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    if firmwareService.transferSpeed > 0 {
                        Text("Hız: \(String(format: "%.1f", firmwareService.transferSpeed)) KB/s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Update Status
            Text(firmwareService.updateStatus)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Action Buttons
            VStack(spacing: 15) {
                if !firmwareService.isUpdating {
                    if isProductionMode {
                        // Üretim modu - hem NFC yazma modu hem firmware update
                        VStack(spacing: 15) {
                            // NFC Yazma Modu Bölümü
                            nfcWriteModeButtons
                            
                            // Divider
                            Divider()
                                .background(Color.gray.opacity(0.3))
                            
                            // Firmware Update Bölümü
                            VStack(spacing: 10) {
                                Text("Firmware Update")
                                    .font(.headline)
                                    .foregroundColor(.productionPurpleDark)
                                
                                // Normal firmware update
                                Button("Mio Firmware Update") {
                                    firmwareService.startFirmwareUpdate(isNewDevice: true, firmwareType: .normal)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(!bluetoothService.isReady)
                                
                                // Üretim modu firmware update
                                Button("Üretim Modu Firmware Update") {
                                    firmwareService.startFirmwareUpdate(isNewDevice: true, firmwareType: .production)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.productionPurple)
                                .disabled(!bluetoothService.isReady)
                            }
                        }
                    } else {
                        // Normal mod - firmware update butonları
                        normalFirmwareButtons
                    }
                } else {
                    Button("Durdur") {
                        firmwareService.stopFirmwareUpdate()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(10)
    }
}

// MARK: - Device Row View
struct DeviceRowView: View {
    let peripheral: CBPeripheral
    let isSelected: Bool
    let onTap: () -> Void
    @ObservedObject var firmwareService: FirmwareUpdateService
    
    private var isProductionMode: Bool {
        firmwareService.isProductionMode
    }
    
    private var primaryColor: Color {
        isProductionMode ? .productionPurple : .blue
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(primaryColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(peripheral.name ?? "Bilinmeyen Cihaz")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(peripheral.identifier.uuidString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(isSelected ? primaryColor.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}


// MARK: - BluetoothServiceDelegate
extension ContentView: BluetoothServiceDelegate {
    func serialIsReady(_ peripheral: CBPeripheral, isNew: Bool) {
        selectedPeripheral = peripheral
        bluetoothService.isNewDevice = isNew
    }
    
    func serialDidReceiveString(_ message: String) {
        firmwareService.handleBluetoothMessage(message)
    }
    
    func serialDidDisconnect(_ peripheral: CBPeripheral, error: Error?) {
        selectedPeripheral = nil
    }
    
    func serialDidChangeState() {
        // Bluetooth durumu değişti
    }
}

#Preview {
    ContentView()
}
