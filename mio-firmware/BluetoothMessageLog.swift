//
//  BluetoothMessageLog.swift
//  mio-firmware
//
//  Created by Hüseyin Uludağ on 8.09.2025.
//

import Foundation
import SwiftUI
import AVFoundation

// MARK: - Message Direction
enum MessageDirection: String, CaseIterable {
    case incoming = "Gelen"
    case outgoing = "Giden"
    
    var color: Color {
        switch self {
        case .incoming: return .green
        case .outgoing: return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .incoming: return "arrow.down.circle.fill"
        case .outgoing: return "arrow.up.circle.fill"
        }
    }
}

// MARK: - Bluetooth Message Entry
struct BluetoothMessageEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let direction: MessageDirection
    let message: String
    let rawData: Data?
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    var formattedMessage: String {
        // JSON formatında güzel görünüm için
        if let jsonData = message.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) {
            
            // UID array'ini özel olarak düzenle
            if var dict = jsonObject as? [String: Any],
               let uidArray = dict["Uid"] as? [Int] {
                // UID array'ini tek satırda göster
                let uidString = "[\(uidArray.map { String($0) }.joined(separator: ", "))]"
                dict["Uid"] = uidString
                
                if let prettyData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    return prettyString
                }
            }
            
            // Normal JSON formatting
            if let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                return prettyString
            }
        }
        return message
    }
    
    var isJSON: Bool {
        if let jsonData = message.data(using: .utf8),
           let _ = try? JSONSerialization.jsonObject(with: jsonData) {
            return true
        }
        return false
    }
}

// MARK: - Bluetooth Message Logger
class BluetoothMessageLogger: ObservableObject {
    static let shared = BluetoothMessageLogger()
    
    @Published var messages: [BluetoothMessageEntry] = []
    @Published var isLoggingEnabled = true
    
    private let maxMessages = 500
    
    private init() {}
    
    // MARK: - Public Methods
    
    func logIncomingMessage(_ message: String, rawData: Data? = nil) {
        guard isLoggingEnabled else { return }
        
        let entry = BluetoothMessageEntry(
            timestamp: Date(),
            direction: .incoming,
            message: message,
            rawData: rawData
        )
        
        DispatchQueue.main.async {
            self.messages.insert(entry, at: 0)
            
            // Limit message count
            if self.messages.count > self.maxMessages {
                self.messages = Array(self.messages.prefix(self.maxMessages))
            }
        }
    }
    
    func logOutgoingMessage(_ message: String, rawData: Data? = nil) {
        guard isLoggingEnabled else { return }
        
        let entry = BluetoothMessageEntry(
            timestamp: Date(),
            direction: .outgoing,
            message: message,
            rawData: rawData
        )
        
        DispatchQueue.main.async {
            self.messages.insert(entry, at: 0)
            
            // Limit message count
            if self.messages.count > self.maxMessages {
                self.messages = Array(self.messages.prefix(self.maxMessages))
            }
        }
    }
    
    func clearMessages() {
        DispatchQueue.main.async {
            self.messages.removeAll()
        }
    }
    
    func exportMessages() -> String {
        return messages.map { entry in
            let direction = entry.direction == .incoming ? "←" : "→"
            return "[\(entry.formattedTimestamp)] \(direction) \(entry.message)"
        }.joined(separator: "\n")
    }
    
    func getMessagesByDirection(_ direction: MessageDirection) -> [BluetoothMessageEntry] {
        return messages.filter { $0.direction == direction }
    }
}

// MARK: - Bluetooth Message Log View
struct BluetoothMessageLogView: View {
    @ObservedObject private var messageLogger = BluetoothMessageLogger.shared
    @State private var selectedDirection: MessageDirection? = nil
    @State private var searchText = ""
    @State private var showRawData = false
    @State private var commandText = ""
    @State private var uniqueID = "T2123456789123"
    @State private var showingQRScanner = false
    
    // BluetoothService referansı - ContentView'dan geçilecek
    var bluetoothService: BluetoothService?
    var firmwareService: FirmwareUpdateService?
    
    private var filteredMessages: [BluetoothMessageEntry] {
        var filtered = messageLogger.messages
        
        // Filter by direction
        if let direction = selectedDirection {
            filtered = filtered.filter { $0.direction == direction }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.message.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages - Sabit boyutlu scroll alanı
            VStack(spacing: 0) {
                if filteredMessages.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "message")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                        
                        Text("Henüz mesaj yok")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Cihaza komut gönderin veya cihazdan gelen response'ları bekleyin")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(filteredMessages.reversed()) { message in
                                    MessageRowView(message: message, showRawData: showRawData)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .frame(height: 300) // Sabit yükseklik
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .onChange(of: filteredMessages.count) { _ in
                            // Yeni mesaj geldiğinde en alta scroll yap
                            if let lastMessage = filteredMessages.first {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
            
            // Command Input - mesaj kutusunun altında
            commandInputView
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingQRScanner) {
            QRScannerView(uniqueID: $uniqueID, isPresented: $showingQRScanner)
        }
    }
    
    
    private var commandInputView: some View {
        VStack(spacing: 12) {
            // Command input
            HStack(spacing: 12) {
                TextField("Command", text: $commandText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                
                Button(action: {
                    showingQRScanner = true
                }) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    sendCommand()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(commandText.isEmpty ? .gray : .blue)
                }
                .disabled(commandText.isEmpty)
            }
            
            // Quick command buttons - sadece normal modda göster
            if !(firmwareService?.isProductionMode ?? false) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        QuickCommandButton(title: "Trans X3", command: "{\"Type\": 33, \"Transx3\": 1}") {
                            commandText = "{\"Type\": 33, \"Transx3\": 1}"
                            sendCommand()
                        }
                        
                        QuickCommandButton(title: "Set Unique ID", command: "{\"Type\": 36, \"UniqueID\": \"\(uniqueID)\"}") {
                            commandText = "{\"Type\": 36, \"UniqueID\": \"\(uniqueID)\"}"
                            sendCommand()
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal, 16)
    }
    
    
    private func sendCommand() {
        guard !commandText.isEmpty else { return }
        
        // BluetoothService'e komut gönder
        if let bluetoothService = bluetoothService {
            bluetoothService.sendJSON(commandText)
        } else {
            // Fallback: sadece log'a ekle
            messageLogger.logOutgoingMessage(commandText)
        }
        commandText = ""
    }
    
    
}

// MARK: - Quick Command Button
struct QuickCommandButton: View {
    let title: String
    let command: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(command)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(minWidth: 140)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}


// MARK: - Message Row View
struct MessageRowView: View {
    let message: BluetoothMessageEntry
    let showRawData: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Timestamp and direction
            HStack {
                if message.direction == .outgoing {
                    Spacer()
                }
                
                Text(message.formattedTimestamp)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Text("|")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Image(systemName: message.direction.icon)
                    .foregroundColor(message.direction.color)
                    .font(.system(size: 10))
                
                Text("!!!")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .fontWeight(.bold)
                
                if message.direction == .incoming {
                    Spacer()
                }
            }
            
            // Message content - JSON format like in the image
            HStack {
                if message.direction == .outgoing {
                    Spacer()
                }
                
                VStack(alignment: message.direction == .outgoing ? .trailing : .leading, spacing: 4) {
                    if showRawData, let rawData = message.rawData {
                        Text("Ham Veri: \(rawData.map { String(format: "%02X", $0) }.joined(separator: " "))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                    
                    // JSON message in a styled container
                    VStack(alignment: message.direction == .outgoing ? .trailing : .leading, spacing: 2) {
                        Text(message.formattedMessage)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(message.direction == .outgoing ? .trailing : .leading)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(message.direction == .incoming ? Color.green.opacity(0.3) : Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.8, alignment: message.direction == .outgoing ? .trailing : .leading)
                
                if message.direction == .incoming {
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - QR Scanner View
struct QRScannerView: View {
    @Binding var uniqueID: String
    @Binding var isPresented: Bool
    @State private var isScanning = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                Text("QR Kodu Okutun")
                    .font(.headline)
                    .padding()
                
                Text("Mevcut Unique ID: \(uniqueID)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom)
                
                // QR Scanner
                QRCodeScannerView { result in
                    switch result {
                    case .success(let code):
                        uniqueID = code
                        isPresented = false
                    case .failure(let error):
                        alertMessage = "QR kod okuma hatası: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
                .frame(height: 300)
                .cornerRadius(12)
                .padding()
                
                Text("QR kodu kameraya doğru tutun")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top)
                
                Spacer()
            }
            .navigationTitle("QR Kod Okuyucu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        isPresented = false
                    }
                }
            }
            .alert("Hata", isPresented: $showingAlert) {
                Button("Tamam") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
}

// MARK: - QR Code Scanner View
struct QRCodeScannerView: UIViewControllerRepresentable {
    let completion: (Result<String, Error>) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.completion = completion
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

// MARK: - QR Scanner View Controller
class QRScannerViewController: UIViewController {
    var completion: ((Result<String, Error>) -> Void)?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setupCamera()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }
    
    private func setupCamera() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            completion?(.failure(QRScannerError.cameraNotAvailable))
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            completion?(.failure(error))
            return
        }
        
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else { return }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            completion?(.failure(QRScannerError.cannotAddInput))
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            completion?(.failure(QRScannerError.cannotAddOutput))
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.previewLayer?.frame = self.view.layer.bounds
            self.previewLayer?.videoGravity = .resizeAspectFill
            self.view.layer.addSublayer(self.previewLayer!)
        }
    }
    
    private func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    private func stopScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
}

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            completion?(.success(stringValue))
        }
    }
}

enum QRScannerError: Error, LocalizedError {
    case cameraNotAvailable
    case cannotAddInput
    case cannotAddOutput
    
    var errorDescription: String? {
        switch self {
        case .cameraNotAvailable:
            return "Kamera mevcut değil"
        case .cannotAddInput:
            return "Kamera girişi eklenemedi"
        case .cannotAddOutput:
            return "Kamera çıkışı eklenemedi"
        }
    }
}

#Preview {
    BluetoothMessageLogView()
}
