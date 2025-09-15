import SwiftUI

struct CardManagementView: View {
    let cardSet: CardSet
    @ObservedObject var cardSetManager: CardSetManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddCard = false
    @State private var showingEditCard: CardData?
    
    var body: some View {
        VStack {
            if cardSet.cards.isEmpty {
                // Boş durum
                VStack(spacing: 20) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Henüz kart yok")
                        .font(.title2)
                        .foregroundColor(.gray)
                    
                    Text("İlk kartınızı ekleyin")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Kart Ekle") {
                        showingAddCard = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Kart listesi
                List {
                    ForEach(cardSet.cards) { card in
                        CardRowView(
                            card: card,
                            onEdit: {
                                showingEditCard = card
                            },
                            onDelete: {
                                deleteCard(card)
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle("Kart Yönetimi")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Ekle") {
                    showingAddCard = true
                }
            }
        }
        .sheet(isPresented: $showingAddCard) {
            AddCardToSetView(cardData: nil)
        }
        .sheet(item: $showingEditCard) { card in
            EditCardView(card: card, cardSet: cardSet, cardSetManager: cardSetManager)
        }
    }
    
    private func deleteCard(_ card: CardData) {
        cardSetManager.removeCardFromSet(card, from: cardSet)
    }
}

// MARK: - CardRowView
struct CardRowView: View {
    let card: CardData
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name.isEmpty ? "İsimsiz Kart" : card.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Block4: \(card.block4.prefix(20))...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Düzenle") {
                onEdit()
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            .font(.caption)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Sil", role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - AddCardView
struct AddCardView: View {
    let cardSet: CardSet
    @ObservedObject var cardSetManager: CardSetManager
    @Environment(\.dismiss) private var dismiss
    @State private var cardName = ""
    @State private var block4 = ""
    @State private var block5 = ""
    @State private var block6 = ""
    @State private var block7 = ""
    @State private var block8 = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kart Adı")
                        .font(.headline)
                    
                    TextField("Kart adı girin", text: $cardName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Block4")
                        .font(.headline)
                    
                    TextField("Block4 verisi", text: $block4)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Block5")
                        .font(.headline)
                    
                    TextField("Block5 verisi", text: $block5)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Block6")
                        .font(.headline)
                    
                    TextField("Block6 verisi", text: $block6)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Block7")
                        .font(.headline)
                    
                    TextField("Block7 verisi", text: $block7)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Block8")
                        .font(.headline)
                    
                    TextField("Block8 verisi", text: $block8)
                        .textFieldStyle(.roundedBorder)
                }
                
                Spacer()
                
                Button("Kart Ekle") {
                    let newCard = CardData(
                        name: cardName,
                        block4: block4,
                        block5: block5,
                        block6: block6,
                        block7: block7,
                        block8: block8
                    )
                    cardSetManager.addCardToSet(newCard, to: cardSet)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(cardName.isEmpty || block4.isEmpty)
            }
            .padding()
            .navigationTitle("Yeni Kart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
            }
        }
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
    
    CardManagementView(cardSet: sampleCardSet, cardSetManager: CardSetManager())
}
