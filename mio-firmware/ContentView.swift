//
//  ContentView.swift
//  mio-firmware
//
//  Created by Hüseyin Uludağ on 8.09.2025.
//

import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject private var bluetoothService = BluetoothService()
    @StateObject private var firmwareService: FirmwareUpdateService
    @State private var selectedPeripheral: CBPeripheral?
    @State private var showingDeviceInfo = false
    @State private var showingLogs = false
    
    init() {
        let bluetooth = BluetoothService()
        _bluetoothService = StateObject(wrappedValue: bluetooth)
        let firmware = FirmwareUpdateService()
        firmware.setBluetoothService(bluetooth)
        _firmwareService = StateObject(wrappedValue: firmware)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                headerView
                
                // Connection Status
                connectionStatusView
                
                // Device List
                if bluetoothService.isScanning || !bluetoothService.discoveredPeripherals.isEmpty {
                    deviceListView
                }
                
                // Firmware Update Section
                if bluetoothService.isConnected {
                    firmwareUpdateView
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Mio Firmware Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingLogs = true
                    }) {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if bluetoothService.isScanning {
                            bluetoothService.stopScan()
                        } else {
                            bluetoothService.startScan()
                        }
                    }) {
                        Image(systemName: bluetoothService.isScanning ? "stop.circle.fill" : "magnifyingglass.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingLogs) {
                LogView()
            }
        }
        .onAppear {
            bluetoothService.delegate = self
            _ = firmwareService.loadFirmwareFile(fileName: "firmware")
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 10) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Mio ESP Firmware Update")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Bluetooth ile firmware güncelleme")
                .font(.caption)
                .foregroundColor(.secondary)
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
                        Text("Yeni Mio")
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
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
        .background(Color(.systemGray6))
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
                        }
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
            VStack(spacing: 10) {
                if !firmwareService.isUpdating {
                    // Sadece yeni Mio cihazı için
                    Button("Mio Firmware Update") {
                        firmwareService.startFirmwareUpdate(isNewDevice: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!bluetoothService.isReady)
                    
                    // Yeni cihaz için ek özellikler
                    HStack(spacing: 10) {
                        Button("Cihaz Bilgileri") {
                            let command = Commands.GET_DEVICE_INFO()
                            bluetoothService.sendJSON(command)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!bluetoothService.isReady)
                        
                        Button("Log Listesi") {
                            let command = Commands.GET_LOG_LIST()
                            bluetoothService.sendJSON(command)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!bluetoothService.isReady)
                    }
                    
                    // Ek özellikler
                    HStack(spacing: 10) {
                        Button("Zaman Ayarı") {
                            let command = Commands.SET_TIMEOUT(30)
                            bluetoothService.sendJSON(command)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!bluetoothService.isReady)
                        
                        Button("Random Play") {
                            let command = Commands.SET_RANDOM_PLAY(true)
                            bluetoothService.sendJSON(command)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!bluetoothService.isReady)
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
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Device Row View
struct DeviceRowView: View {
    let peripheral: CBPeripheral
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.blue)
                
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
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
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
