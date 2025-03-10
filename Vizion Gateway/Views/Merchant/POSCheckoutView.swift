import SwiftUI
import SwiftData

// Model for cart items
struct CartItem: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var price: Decimal
    var quantity: Int
    
    var subtotal: Decimal {
        price * Decimal(quantity)
    }
}

struct POSCheckoutView: View {
    @State private var cartItems: [CartItem] = []
    @State private var itemName: String = ""
    @State private var itemPrice: String = ""
    @State private var itemQuantity: Int = 1
    @State private var taxRate: Decimal = 0.15 // 15% tax
    @State private var discount: String = ""
    @State private var showingPaymentView = false
    @State private var showingReceiptView = false
    @State private var currentTransaction: Transaction?
    @Environment(\.modelContext) private var modelContext
    
    var subtotal: Decimal {
        cartItems.reduce(Decimal(0)) { $0 + $1.subtotal }
    }
    
    var discountAmount: Decimal {
        if let discountValue = Decimal(string: discount), discountValue > 0 {
            return subtotal * (discountValue / 100)
        }
        return 0
    }
    
    var taxAmount: Decimal {
        (subtotal - discountAmount) * taxRate
    }
    
    var total: Decimal {
        subtotal - discountAmount + taxAmount
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Merchant Checkout")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            // Cart Items
            List {
                Section(header: Text("Items").font(.headline)) {
                    ForEach(cartItems) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.headline)
                                Text("\(formatCurrency(item.price)) × \(item.quantity)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(formatCurrency(item.subtotal))
                                .font(.headline)
                        }
                        .contentShape(Rectangle())
                        .swipeActions {
                            Button(role: .destructive) {
                                if let index = cartItems.firstIndex(of: item) {
                                    cartItems.remove(at: index)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    
                    if cartItems.isEmpty {
                        HStack {
                            Spacer()
                            Text("No items added yet")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical)
                    }
                }
                
                // Add New Item Section
                Section(header: Text("Add Item").font(.headline)) {
                    TextField("Item Name", text: $itemName)
                        .padding(.vertical, 4)
                    
                    TextField("Price", text: $itemPrice)
                        .keyboardType(.decimalPad)
                        .padding(.vertical, 4)
                    
                    Stepper("Quantity: \(itemQuantity)", value: $itemQuantity, in: 1...100)
                    
                    Button(action: addItem) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add to Cart")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .disabled(itemName.isEmpty || itemPrice.isEmpty || (Decimal(string: itemPrice) ?? 0) <= 0)
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
                
                // Order Summary Section
                Section(header: Text("Order Summary").font(.headline)) {
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text(formatCurrency(subtotal))
                    }
                    
                    HStack {
                        Text("Discount")
                        Spacer()
                        TextField("Discount %", text: $discount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("%")
                    }
                    
                    HStack {
                        Text("Tax (\(NSDecimalNumber(decimal: taxRate * 100).intValue)%)")
                        Spacer()
                        Text(formatCurrency(taxAmount))
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Total")
                            .font(.headline)
                        Spacer()
                        Text(formatCurrency(total))
                            .font(.headline)
                    }
                }
            }
            .listStyle(.insetGrouped)
            
            // Checkout Button
            Button(action: {
                showingPaymentView = true
            }) {
                HStack {
                    Image(systemName: "creditcard.fill")
                    Text("Proceed to Payment")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(cartItems.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(cartItems.isEmpty)
            .padding()
        }
        .sheet(isPresented: $showingPaymentView) {
            NavigationStack {
                POSPaymentView(amount: total, items: cartItems, discount: discountAmount, tax: taxAmount) { transaction in
                    self.currentTransaction = transaction
                    showingPaymentView = false
                    showingReceiptView = true
                }
                .navigationTitle("Payment")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingPaymentView = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingReceiptView) {
            if let transaction = currentTransaction {
                NavigationStack {
                    POSReceiptView(transaction: transaction, items: cartItems, discount: discountAmount, tax: taxAmount)
                        .navigationTitle("Receipt")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showingReceiptView = false
                                    resetCart()
                                }
                            }
                        }
                }
            }
        }
    }
    
    private func addItem() {
        guard let price = Decimal(string: itemPrice), price > 0, !itemName.isEmpty else { return }
        
        let newItem = CartItem(
            name: itemName,
            price: price,
            quantity: itemQuantity
        )
        
        cartItems.append(newItem)
        
        // Reset input fields
        itemName = ""
        itemPrice = ""
        itemQuantity = 1
    }
    
    private func resetCart() {
        cartItems = []
        itemName = ""
        itemPrice = ""
        itemQuantity = 1
        discount = ""
        currentTransaction = nil
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "XCD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$\(amount)"
    }
}

// Preview provider
#Preview {
    POSCheckoutView()
        .modelContainer(for: Transaction.self, inMemory: true)
} 