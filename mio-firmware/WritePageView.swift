import SwiftUI
import CoreBluetooth

struct WritePageView: View {
    let cardSet: CardSet
    @ObservedObject var bluetoothService: BluetoothService
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var firmwareService: FirmwareUpdateService
    @StateObject private var messageLogger = BluetoothMessageLogger.shared
    @ObservedObject var cardSetManager: CardSetManager
    @State private var selectedCardIndex: Int = 0
    @State private var showingEditCard: CardData?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerView
                
                // Kart Seçimi
                if !cardSet.cards.isEmpty {
                    cardSelectionView
                }
                
                // Büyük Yazma Butonu
                if !cardSet.cards.isEmpty {
                    writeButtonView
                }
                
                // Mesaj Log Alanı
                messageLogView
            }
            .padding()
        }
        .navigationTitle("Kart Yazma")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $showingEditCard) { card in
            EditCardView(card: card, cardSet: cardSet, cardSetManager: cardSetManager)
        }
    }
    
    
    // MARK: - View Components
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text(cardSet.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("\(cardSet.cards.count) kart mevcut")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }
    
    private var cardSelectionView: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Kart Seç")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Düzenleme Butonu
                if !cardSet.cards.isEmpty {
                    Button(action: {
                        showingEditCard = cardSet.cards[selectedCardIndex]
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                    }
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(cardSet.cards.enumerated()), id: \.offset) { index, card in
                        CardSelectionButton(
                            index: index,
                            card: card,
                            isSelected: selectedCardIndex == index,
                            onTap: { selectedCardIndex = index }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var writeButtonView: some View {
        VStack(spacing: 15) {
            Text("Seçilen Kart")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Block4: \(cardSet.cards[selectedCardIndex].block4)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Block5: \(cardSet.cards[selectedCardIndex].block5)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Block6: \(cardSet.cards[selectedCardIndex].block6)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            
            // Bluetooth Durumu
            HStack {
                Circle()
                    .fill(bluetoothService.isReady ? .green : .red)
                    .frame(width: 12, height: 12)
                
                Text(bluetoothService.isReady ? "Bluetooth Hazır" : "Bluetooth Bağlantısı Yok")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Büyük Yuvarlak Buton
            Button(action: {
                writeSelectedCard()
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 40))
                    
                    Text("KART YAZ")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(width: 200, height: 200)
                .background(
                    Circle()
                        .fill(
                            bluetoothService.isReady ? 
                            Color.green : Color.gray
                        )
                )
                .shadow(radius: 10)
            }
            .disabled(!bluetoothService.isReady)
            .scaleEffect(bluetoothService.isReady ? 1.0 : 0.9)
            .animation(.easeInOut(duration: 0.2), value: bluetoothService.isReady)
        }
    }
    
    private var messageLogView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mesaj Log")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messageLogger.messages.reversed()) { message in
                            MessageRowView(message: message, showRawData: false)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 400)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .onChange(of: messageLogger.messages.count) { _ in
                    // Yeni mesaj geldiğinde en alta scroll
                    if let lastMessage = messageLogger.messages.first {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    private func writeSelectedCard() {
        print("writeSelectedCard called")
        print("Bluetooth isReady: \(bluetoothService.isReady)")
        print("Bluetooth isConnected: \(bluetoothService.isConnected)")
        
        let selectedCard = cardSet.cards[selectedCardIndex]
        print("Selected card: \(selectedCard.block4)")
        
        let command = [
            "Type": 50,
            "WriteMode": [
                "Action": "START",
                "CardData": [
                    "Block4": selectedCard.block4,
                    "Block5": selectedCard.block5,
                    "Block6": selectedCard.block6,
                    "Block7": selectedCard.block7,
                    "Block8": selectedCard.block8
                ]
            ]
        ] as [String: Any]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: command),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("Sending JSON: \(jsonString)")
            bluetoothService.sendJSON(jsonString)
        } else {
            print("Failed to create JSON")
        }
    }
}

// MARK: - CardSelectionButton
struct CardSelectionButton: View {
    let index: Int
    let card: CardData
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(card.name.isEmpty ? "Kart \(index + 1)" : card.name)
                    .font(.caption)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                Text(card.block4.prefix(12) + "...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .frame(width: 90, height: 70)
            .background(
                isSelected ? 
                Color.blue.opacity(0.3) : Color.gray.opacity(0.1)
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.blue : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - BluetoothServiceDelegate
extension WritePageView: BluetoothServiceDelegate {
    func serialIsReady(_ peripheral: CBPeripheral, isNew: Bool) {
        // Handle connection
    }
    
    func serialDidReceiveString(_ message: String) {
        // Handle string messages
    }
    
    func serialDidDisconnect(_ peripheral: CBPeripheral, error: Error?) {
        // Handle disconnection
    }
    
    func serialDidChangeState() {
        // Handle state changes
    }
}

#Preview {
    let sampleCardSet = CardSet(
        name: "Örnek Kart Seti",
        cards: [
            CardData(
                name: "Test Kartı",
                block4: "01 00 00 00 30 00 17 01 1A 00 1C 00 26 00 2B 00",
                block5: "56 00 64 00 66 00 6F 00 00 00 00 00 00 00 00 00",
                block6: "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00",
                block7: "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00",
                block8: "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
            )
        ]
    )
    
    WritePageView(cardSet: sampleCardSet, bluetoothService: BluetoothService(), firmwareService: FirmwareUpdateService(), cardSetManager: CardSetManager())
}
