import SwiftUI
import SwiftData

struct PreviewContainer {
    static let shared = PreviewContainer()
    
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    init() {
        do {
            let schema = Schema([
                Wallet.self,
                WalletTransaction.self,
                WithdrawalRequest.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = ModelContext(modelContainer)
            setupPreviewData()
        } catch {
            fatalError("Could not create preview container: \(error)")
        }
    }
    
    private func setupPreviewData() {
        // Create mock wallet
        let wallet = Wallet(userId: "preview_user", type: .user)
        wallet.balances = [
            Balance(amount: 1000.0, currency: .usd),
            Balance(amount: 500.0, currency: .eur)
        ]
        
        // Create mock transactions
        let transactions = [
            WalletTransaction(
                amount: 100.0,
                currency: .usd,
                type: .payment,
                status: .completed,
                sourceId: "preview_user",
                destinationId: "merchant_1"
            ),
            WalletTransaction(
                amount: 50.0,
                currency: .eur,
                type: .deposit,
                status: .completed,
                sourceId: "bank_1",
                destinationId: "preview_user"
            )
        ]
        
        modelContext.insert(wallet)
        transactions.forEach { modelContext.insert($0) }
    }
}

struct PreviewWallet {
    static let wallet = Wallet(userId: "preview_user", type: .user)
    static let transaction = WalletTransaction(
        amount: 100.0,
        currency: .usd,
        type: .payment,
        status: .completed,
        sourceId: "preview_user",
        destinationId: "merchant_1"
    )
}

#Preview {
    ContentView()
        .modelContainer(PreviewContainer.shared.modelContainer)
} 