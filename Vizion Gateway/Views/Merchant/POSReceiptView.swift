import SwiftUI
import PDFKit
import MessageUI

struct POSReceiptView: View {
    let transaction: Transaction
    let items: [CartItem]
    let discount: Decimal
    let tax: Decimal
    
    @State private var showingShareSheet = false
    @State private var showingEmailSheet = false
    @State private var receiptPDF: Data?
    @State private var showingSendSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Receipt Header
                VStack(spacing: 12) {
                    Image(systemName: "creditcard.and.123")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                    
                    Text("Transaction Receipt")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(transaction.reference)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // Transaction Status
                HStack {
                    StatusBadge(status: transaction.status)
                    Spacer()
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Line Items
                VStack(spacing: 0) {
                    Text("Items")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 8)
                    
                    Divider()
                    
                    ForEach(items) { item in
                        VStack(spacing: 0) {
                            HStack {
                                Text(item.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(item.quantity) × \(formatCurrency(item.price))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatCurrency(item.subtotal))
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 8)
                            
                            if item != items.last {
                                Divider()
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // Payment Details
                VStack(spacing: 16) {
                    ReceiptRow(title: "Subtotal", value: formatCurrency(subtotal))
                    
                    if discount > 0 {
                        Divider()
                        ReceiptRow(title: "Discount", value: "- \(formatCurrency(discount))")
                    }
                    
                    Divider()
                    
                    ReceiptRow(title: "Tax", value: formatCurrency(tax))
                    
                    Divider()
                    
                    ReceiptRow(title: "Total", value: formatCurrency(transaction.amount), isBold: true)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // Payment Method
                VStack(spacing: 16) {
                    ReceiptRow(title: "Payment Method", value: transaction.paymentMethod.rawValue)
                    
                    if let authCode = transaction.authorizationCode {
                        Divider()
                        ReceiptRow(title: "Authorization Code", value: authCode)
                    }
                    
                    Divider()
                    
                    ReceiptRow(title: "Merchant", value: transaction.merchantName)
                    
                    if let customerName = transaction.customerName {
                        Divider()
                        ReceiptRow(title: "Customer", value: customerName)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // QR Code (for digital verification)
                VStack {
                    Image(systemName: "qrcode")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                    
                    Text("Scan to verify")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Receipt Footer
                Text("This is an official receipt from Vizion Gateway. For questions or support, please contact support@viziongateway.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button(action: {
                    generatePDF()
                    showingShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                }
                
                Spacer()
                
                Button(action: {
                    generatePDF()
                    showingEmailSheet = true
                }) {
                    HStack {
                        Image(systemName: "envelope")
                        Text("Email")
                    }
                }
                
                Spacer()
                
                Button(action: {
                    generatePDF()
                    savePDF()
                }) {
                    HStack {
                        Image(systemName: "printer")
                        Text("Print")
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let pdf = receiptPDF {
                ShareSheet(items: [pdf])
            }
        }
        .sheet(isPresented: $showingEmailSheet) {
            if let pdf = receiptPDF {
                EmailSheet(
                    data: pdf,
                    subject: "Receipt for Transaction \(transaction.reference)",
                    recipients: [],
                    body: "Thank you for your purchase. Please find attached the receipt for your transaction with Vizion Gateway.",
                    onCompletion: { result in
                        if case .success(_) = result {
                            showingSendSuccess = true
                        }
                    }
                )
            }
        }
        .alert("Receipt Saved", isPresented: $showingSendSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your receipt has been saved successfully.")
        }
    }
    
    private var subtotal: Decimal {
        items.reduce(Decimal(0)) { $0 + $1.subtotal }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: transaction.timestamp)
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = transaction.currency
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$\(amount)"
    }
    
    private func generatePDF() {
        let receiptView = POSReceiptPDFView(
            transaction: transaction,
            items: items,
            discount: discount,
            tax: tax
        )
        let renderer = ImageRenderer(content: receiptView)
        
        // Configure renderer for PDF generation
        let pageSize = CGSize(width: 612, height: 792) // US Letter size
        renderer.proposedSize = .init(width: pageSize.width, height: pageSize.height)
        
        // Create PDF document
        if let pdfData = renderer.pdf(size: pageSize) {
            self.receiptPDF = pdfData
        }
    }
    
    private func savePDF() {
        guard let pdf = receiptPDF else { return }
        
        // Generate a unique filename
        let filename = "Receipt-\(transaction.reference).pdf"
        
        // Get the documents directory
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsDirectory.appendingPathComponent(filename)
            
            do {
                try pdf.write(to: fileURL)
                showingSendSuccess = true
            } catch {
                print("Error saving PDF: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Components
// StatusBadge, ReceiptRow, ShareSheet, and EmailSheet have been moved to separate files
// and are now imported from their respective locations

// MARK: - PDF View

struct POSReceiptPDFView: View {
    let transaction: Transaction
    let items: [CartItem]
    let discount: Decimal
    let tax: Decimal
    
    var body: some View {
        VStack(spacing: 24) {
            // Receipt Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("VIZION GATEWAY")
                        .font(.headline)
                    Text("Transaction Receipt")
                        .font(.subheadline)
                    Text("Date: \(formattedDate)")
                        .font(.caption)
                }
                
                Spacer()
                
                Text("#\(transaction.reference)")
                    .font(.caption)
            }
            .padding(.bottom)
            
            Divider()
            
            // Line Items
            VStack(alignment: .leading, spacing: 16) {
                Text("ITEMS")
                    .font(.headline)
                
                ForEach(items) { item in
                    HStack {
                        Text(item.name)
                            .font(.subheadline)
                        Spacer()
                        Text("\(item.quantity) × \(formatCurrency(item.price))")
                            .font(.caption)
                        Spacer()
                        Text(formatCurrency(item.subtotal))
                            .font(.subheadline)
                    }
                }
            }
            .padding(.bottom)
            
            Divider()
            
            // Totals
            VStack(spacing: 8) {
                HStack {
                    Text("Subtotal")
                    Spacer()
                    Text(formatCurrency(subtotal))
                }
                
                if discount > 0 {
                    HStack {
                        Text("Discount")
                        Spacer()
                        Text("- \(formatCurrency(discount))")
                    }
                }
                
                HStack {
                    Text("Tax")
                    Spacer()
                    Text(formatCurrency(tax))
                }
                
                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    Text(formatCurrency(transaction.amount))
                        .font(.headline)
                }
            }
            .padding(.bottom)
            
            Divider()
            
            // Payment Details
            VStack(alignment: .leading, spacing: 8) {
                Text("PAYMENT DETAILS")
                    .font(.headline)
                
                HStack {
                    Text("Payment Method")
                    Spacer()
                    Text(transaction.paymentMethod.rawValue)
                }
                
                HStack {
                    Text("Status")
                    Spacer()
                    Text(transaction.status.rawValue)
                }
                
                if let authCode = transaction.authorizationCode {
                    HStack {
                        Text("Authorization Code")
                        Spacer()
                        Text(authCode)
                    }
                }
            }
            .padding(.bottom)
            
            Divider()
            
            // Footer
            VStack(spacing: 8) {
                Text("Thank you for your business!")
                    .font(.subheadline)
                
                Text("For questions or support, please contact support@viziongateway.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
    }
    
    private var subtotal: Decimal {
        items.reduce(Decimal(0)) { $0 + $1.subtotal }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: transaction.timestamp)
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = transaction.currency
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$\(amount)"
    }
}

// Preview provider
#Preview {
    POSReceiptView(
        transaction: Transaction.previewTransaction(),
        items: [
            CartItem(name: "Coffee", price: 5.50, quantity: 2),
            CartItem(name: "Sandwich", price: 8.75, quantity: 1)
        ],
        discount: 2.00,
        tax: 3.00
    )
} 