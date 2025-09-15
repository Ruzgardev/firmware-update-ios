import SwiftUI

struct CardSetsView: View {
    @ObservedObject var bluetoothService: BluetoothService
    @ObservedObject var firmwareService: FirmwareUpdateService
    @StateObject private var cardSetManager = CardSetManager()
    @State private var showingAddSet = false
    
    var body: some View {
        NavigationView {
            VStack {
                if cardSetManager.cardSets.isEmpty {
                    // Boş durum
                    VStack(spacing: 20) {
                        Image(systemName: "creditcard.and.123")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Henüz kart seti yok")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        Text("İlk kart setinizi oluşturun")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("Kart Seti Oluştur") {
                            showingAddSet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Kart setleri listesi
                    List {
                        ForEach(cardSetManager.cardSets) { cardSet in
                            CardSetRowView(
                                cardSet: cardSet,
                                onTap: {
                                    // Artık kullanılmıyor, butonlar ile navigation yapılıyor
                                },
                                onDelete: {
                                    cardSetManager.deleteCardSet(cardSet)
                                },
                                bluetoothService: bluetoothService,
                                firmwareService: firmwareService,
                                cardSetManager: cardSetManager
                            )
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Kart Setleri")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Ekle") {
                        showingAddSet = true
                    }
                }
            }
            .sheet(isPresented: $showingAddSet) {
                AddCardSetView(cardSetManager: cardSetManager)
            }
        }
    }
}

// MARK: - CardSetRowView
struct CardSetRowView: View {
    let cardSet: CardSet
    let onTap: () -> Void
    let onDelete: () -> Void
    let bluetoothService: BluetoothService
    let firmwareService: FirmwareUpdateService
    let cardSetManager: CardSetManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Ana kart seti bilgileri ve butonlar
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cardSet.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("\(cardSet.cards.count) kart")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Güncellendi: \(cardSet.updatedAt, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Butonlar
                HStack(spacing: 12) {
                    // Düzenleme Butonu
                    NavigationLink(destination: CardManagementView(cardSet: cardSet, cardSetManager: cardSetManager)) {
                        HStack {
                            Image(systemName: "pencil.circle.fill")
                            Text("Düzenle")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(15)
                    }
                    
                    // Kart Yazma Butonu
                    NavigationLink(destination: WritePageView(cardSet: cardSet, bluetoothService: bluetoothService, firmwareService: firmwareService)) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                            Text("Kart Yaz")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(15)
                    }
                    
                    Spacer()
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Sil", role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - AddCardSetView
struct AddCardSetView: View {
    @ObservedObject var cardSetManager: CardSetManager
    @Environment(\.dismiss) private var dismiss
    @State private var setName = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kart Seti Adı")
                        .font(.headline)
                    
                    TextField("Örn: Müşteri Kartları", text: $setName)
                        .textFieldStyle(.roundedBorder)
                }
                
                Spacer()
                
                Button("Kart Seti Oluştur") {
                    let newSet = CardSet(name: setName)
                    cardSetManager.addCardSet(newSet)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(setName.isEmpty)
            }
            .padding()
            .navigationTitle("Yeni Kart Seti")
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
    CardSetsView(bluetoothService: BluetoothService(), firmwareService: FirmwareUpdateService())
}
