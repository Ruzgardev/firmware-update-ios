import SwiftUI

struct AddCardToSetView: View {
    let cardData: CardData?
    @StateObject private var cardSetManager = CardSetManager()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSetId: UUID?
    @State private var cardName = ""
    @State private var block4 = ""
    @State private var block5 = ""
    @State private var block6 = ""
    @State private var block7 = ""
    @State private var block8 = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Kart İsmi Girişi
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kart İsmi")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Kart ismini girin", text: $cardName)
                        .textFieldStyle(.roundedBorder)
                        .onAppear {
                            // Eğer kart ismi boşsa, otomatik isim öner
                            if cardName.isEmpty {
                                cardName = "Kart \(Date().timeIntervalSince1970)"
                            }
                        }
                }
                
                // Kart Data Gösterimi (Sadece mevcut data varsa)
                if let cardData = cardData {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kart Data")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
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
                    }
                } else {
                    // Manuel Kart Data Girişi
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kart Data")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 8) {
                            TextField("Block4", text: $block4)
                                .textFieldStyle(.roundedBorder)
                            TextField("Block5", text: $block5)
                                .textFieldStyle(.roundedBorder)
                            TextField("Block6", text: $block6)
                                .textFieldStyle(.roundedBorder)
                            TextField("Block7", text: $block7)
                                .textFieldStyle(.roundedBorder)
                            TextField("Block8", text: $block8)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                
                // Kart Setleri Listesi
                if cardSetManager.cardSets.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "creditcard.and.123")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("Henüz kart seti yok")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Önce bir kart seti oluşturun")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kart Seti Seç")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        List {
                            ForEach(cardSetManager.cardSets) { cardSet in
                                Button(action: {
                                    selectedSetId = cardSet.id
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(cardSet.name)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            Text("\(cardSet.cards.count) kart")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if selectedSetId == cardSet.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .frame(height: 200)
                    }
                }
                
                Spacer()
                
                // Ekle Butonu
                if let selectedSetId = selectedSetId,
                   let selectedSet = cardSetManager.cardSets.first(where: { $0.id == selectedSetId }) {
                    Button("Kartı Sete Ekle") {
                        let finalCardData: CardData
                        
                        if let cardData = cardData {
                            // Mevcut kart data'sını kullan
                            var updatedCardData = cardData
                            updatedCardData.name = cardName
                            finalCardData = updatedCardData
                        } else {
                            // Manuel giriş
                            finalCardData = CardData(
                                name: cardName,
                                block4: block4,
                                block5: block5,
                                block6: block6,
                                block7: block7,
                                block8: block8
                            )
                        }
                        
                        cardSetManager.addCardToSet(finalCardData, to: selectedSet)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(selectedSetId == nil || cardName.isEmpty || (!hasValidData()))
                }
            }
            .padding()
            .navigationTitle("Kart Setine Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func hasValidData() -> Bool {
        if cardData != nil {
            return true // Mevcut data varsa geçerli
        } else {
            // Manuel giriş için tüm alanlar dolu olmalı
            return !block4.isEmpty && !block5.isEmpty && !block6.isEmpty && !block7.isEmpty && !block8.isEmpty
        }
    }
}

#Preview {
    let sampleCardData = CardData(
        name: "Örnek Kart",
        block4: "01 00 00 00 30 00 17 01 1A 00 1C 00 26 00 2B 00",
        block5: "56 00 64 00 66 00 6F 00 00 00 00 00 00 00 00 00",
        block6: "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00",
        block7: "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00",
        block8: "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
    )
    
    AddCardToSetView(cardData: sampleCardData)
}
