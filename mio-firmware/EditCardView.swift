import SwiftUI

struct EditCardView: View {
    let card: CardData
    let cardSet: CardSet
    @ObservedObject var cardSetManager: CardSetManager
    @Environment(\.dismiss) private var dismiss
    @State private var cardName: String
    @State private var showingDeleteAlert = false
    
    init(card: CardData, cardSet: CardSet, cardSetManager: CardSetManager) {
        self.card = card
        self.cardSet = cardSet
        self.cardSetManager = cardSetManager
        self._cardName = State(initialValue: card.name)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Kart İsmi Düzenleme
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kart İsmi")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Kart ismini girin", text: $cardName)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Kart Data Gösterimi (Sadece Okunabilir)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kart Data (Değiştirilemez)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Block4: \(card.block4)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Block5: \(card.block5)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Block6: \(card.block6)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Block7: \(card.block7)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Block8: \(card.block8)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // Butonlar
                VStack(spacing: 12) {
                    // Kaydet Butonu
                    Button("Kaydet") {
                        saveCard()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(cardName.isEmpty)
                    
                    // Sil Butonu
                    Button("Kartı Sil") {
                        showingDeleteAlert = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red, lineWidth: 1)
                    )
                }
            }
            .padding()
            .navigationTitle("Kart Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
            }
            .alert("Kartı Sil", isPresented: $showingDeleteAlert) {
                Button("İptal", role: .cancel) { }
                Button("Sil", role: .destructive) {
                    deleteCard()
                }
            } message: {
                Text("Bu kartı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.")
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func saveCard() {
        // Yeni kart data'sı oluştur (sadece isim değişti)
        let updatedCard = CardData(
            name: cardName,
            block4: card.block4,
            block5: card.block5,
            block6: card.block6,
            block7: card.block7,
            block8: card.block8
        )
        
        // Eski kartı sil ve yenisini ekle
        cardSetManager.removeCardFromSet(card, from: cardSet)
        cardSetManager.addCardToSet(updatedCard, to: cardSet)
        
        dismiss()
    }
    
    private func deleteCard() {
        cardSetManager.removeCardFromSet(card, from: cardSet)
        dismiss()
    }
}

#Preview {
    let sampleCard = CardData(
        name: "Test Kart",
        block4: "01 00 00 00 30 00 17 01 1A 00 1C 00 26 00 2B 00",
        block5: "56 00 64 00 66 00 6F 00 00 00 00 00 00 00 00 00",
        block6: "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00",
        block7: "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00",
        block8: "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
    )
    
    let sampleCardSet = CardSet(name: "Test Set", cards: [sampleCard])
    
    EditCardView(card: sampleCard, cardSet: sampleCardSet, cardSetManager: CardSetManager())
}
