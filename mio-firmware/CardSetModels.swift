import Foundation

// MARK: - CardSet
struct CardSet: Codable, Identifiable {
    let id = UUID()
    var name: String
    var cards: [CardData]
    var createdAt: Date
    var updatedAt: Date
    
    init(name: String, cards: [CardData] = []) {
        self.name = name
        self.cards = cards
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - CardSetManager
class CardSetManager: ObservableObject {
    @Published var cardSets: [CardSet] = []
    
    private let userDefaults = UserDefaults.standard
    private let cardSetsKey = "SavedCardSets"
    
    init() {
        loadCardSets()
    }
    
    // MARK: - Card Set Management
    
    func addCardSet(_ cardSet: CardSet) {
        cardSets.append(cardSet)
        saveCardSets()
    }
    
    func updateCardSet(_ cardSet: CardSet) {
        if let index = cardSets.firstIndex(where: { $0.id == cardSet.id }) {
            var updatedCardSet = cardSet
            updatedCardSet.updatedAt = Date()
            cardSets[index] = updatedCardSet
            saveCardSets()
        }
    }
    
    func deleteCardSet(_ cardSet: CardSet) {
        cardSets.removeAll { $0.id == cardSet.id }
        saveCardSets()
    }
    
    func addCardToSet(_ cardData: CardData, to cardSet: CardSet) {
        if let index = cardSets.firstIndex(where: { $0.id == cardSet.id }) {
            var updatedCardSet = cardSets[index]
            updatedCardSet.cards.append(cardData)
            updatedCardSet.updatedAt = Date()
            cardSets[index] = updatedCardSet
            saveCardSets()
        }
    }
    
    func removeCardFromSet(_ cardData: CardData, from cardSet: CardSet) {
        if let index = cardSets.firstIndex(where: { $0.id == cardSet.id }) {
            var updatedCardSet = cardSets[index]
            updatedCardSet.cards.removeAll { $0.block4 == cardData.block4 }
            updatedCardSet.updatedAt = Date()
            cardSets[index] = updatedCardSet
            saveCardSets()
        }
    }
    
    // MARK: - Persistence
    
    private func saveCardSets() {
        if let encoded = try? JSONEncoder().encode(cardSets) {
            userDefaults.set(encoded, forKey: cardSetsKey)
        }
    }
    
    private func loadCardSets() {
        if let data = userDefaults.data(forKey: cardSetsKey),
           let decoded = try? JSONDecoder().decode([CardSet].self, from: data) {
            cardSets = decoded
        }
    }
}
