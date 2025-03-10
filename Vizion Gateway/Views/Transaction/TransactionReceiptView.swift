import SwiftUI
import PDFKit
import MessageUI

struct TransactionReceiptView: View {
    let transaction: Transaction
    @State private var showingShareSheet = false
    @State private var showingEmailSheet = false
    @State private var receiptPDF: Data?
    @State private var showingSendSuccess = false
    @Environment(\.dismiss) private var dismiss
    
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
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                
                // Transaction Status
                HStack {
                    StatusBadge(status: transaction.status)
                    Spacer()
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Transaction Details
                VStack(spacing: 16) {
                    ReceiptRow(title: "Amount", value: formattedAmount)
                    
                    Divider()
                    
                    ReceiptRow(title: "Payment Method", value: transaction.paymentMethod.rawValue)
                    
                    if let description = transaction.transactionDescription {
                        Divider()
                        ReceiptRow(title: "Description", value: description)
                    }
                    
                    Divider()
                    
                    ReceiptRow(title: "Merchant", value: transaction.merchantName)
                    
                    if let customerName = transaction.customerName {
                        Divider()
                        ReceiptRow(title: "Customer", value: customerName)
                    }
                    
                    Divider()
                    
                    ReceiptRow(title: "Reference", value: transaction.reference)
                    
                    if let authCode = transaction.authorizationCode {
                        Divider()
                        ReceiptRow(title: "Authorization Code", value: authCode)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                
                // Fee Details
                VStack(spacing: 16) {
                    ReceiptRow(title: "Subtotal", value: formattedAmount)
                    
                    Divider()
                    
                    ReceiptRow(title: "Fee", value: formattedFee)
                    
                    Divider()
                    
                    ReceiptRow(title: "Total", value: formattedNetAmount, isBold: true)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
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
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        generatePDF()
                        showingShareSheet = true
                    }) {
                        Label("Share Receipt", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: {
                        generatePDF()
                        showingEmailSheet = true
                    }) {
                        Label("Email Receipt", systemImage: "envelope")
                    }
                    
                    Button(action: {
                        generatePDF()
                        savePDF()
                    }) {
                        Label("Save PDF", systemImage: "arrow.down.doc")
                    }
                    
                    Button(action: {
                        UIPasteboard.general.string = transaction.reference
                    }) {
                        Label("Copy Reference", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
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
                    body: "Please find attached the receipt for your transaction with Vizion Gateway.",
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
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = transaction.currency
        return formatter.string(from: NSDecimalNumber(decimal: transaction.amount)) ?? "$\(transaction.amount)"
    }
    
    private var formattedFee: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = transaction.currency
        return formatter.string(from: NSDecimalNumber(decimal: transaction.fee)) ?? "$\(transaction.fee)"
    }
    
    private var formattedNetAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = transaction.currency
        return formatter.string(from: NSDecimalNumber(decimal: transaction.netAmount)) ?? "$\(transaction.netAmount)"
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: transaction.timestamp)
    }
    
    private func generatePDF() {
        let receiptView = TransactionReceiptPDFView(transaction: transaction)
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

struct TransactionReceiptPDFView: View {
    let transaction: Transaction
    
    var body: some View {
        VStack(spacing: 24) {
            // Receipt Header
            VStack(spacing: 12) {
                Text("VIZION GATEWAY")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Transaction Receipt")
                    .font(.title2)
                
                Text(transaction.reference)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            
            // Transaction Details
            VStack(spacing: 16) {
                HStack {
                    Text("Status:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(transaction.status.rawValue)
                }
                
                HStack {
                    Text("Date:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(formattedDate)
                }
                
                HStack {
                    Text("Amount:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(formattedAmount)
                }
                
                HStack {
                    Text("Payment Method:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(transaction.paymentMethod.rawValue)
                }
                
                if let description = transaction.transactionDescription {
                    HStack {
                        Text("Description:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(description)
                    }
                }
                
                HStack {
                    Text("Merchant:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(transaction.merchantName)
                }
                
                if let customerName = transaction.customerName {
                    HStack {
                        Text("Customer:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(customerName)
                    }
                }
                
                HStack {
                    Text("Reference:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(transaction.reference)
                }
                
                if let authCode = transaction.authorizationCode {
                    HStack {
                        Text("Authorization Code:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(authCode)
                    }
                }
            }
            .padding()
            
            // Fee Details
            VStack(spacing: 16) {
                HStack {
                    Text("Subtotal:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(formattedAmount)
                }
                
                HStack {
                    Text("Fee:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(formattedFee)
                }
                
                HStack {
                    Text("Total:")
                        .fontWeight(.bold)
                    Spacer()
                    Text(formattedNetAmount)
                        .fontWeight(.bold)
                }
            }
            .padding()
            
            // Footer
            VStack(spacing: 8) {
                Text("This is an official receipt from Vizion Gateway.")
                    .font(.caption)
                
                Text("For questions or support, please contact support@viziongateway.com")
                    .font(.caption)
                
                Text("Receipt generated on \(Date().formatted(.dateTime))")
                    .font(.caption2)
            }
            .padding()
        }
        .padding()
        .frame(width: 612, height: 792) // US Letter size
        .background(Color.white)
    }
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = transaction.currency
        return formatter.string(from: NSDecimalNumber(decimal: transaction.amount)) ?? "$\(transaction.amount)"
    }
    
    private var formattedFee: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = transaction.currency
        return formatter.string(from: NSDecimalNumber(decimal: transaction.fee)) ?? "$\(transaction.fee)"
    }
    
    private var formattedNetAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = transaction.currency
        return formatter.string(from: NSDecimalNumber(decimal: transaction.netAmount)) ?? "$\(transaction.netAmount)"
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: transaction.timestamp)
    }
}

struct ReceiptRow: View {
    let title: String
    let value: String
    var isBold: Bool = false
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(isBold ? .headline : .subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(isBold ? .headline : .subheadline)
                .fontWeight(isBold ? .bold : .regular)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct EmailSheet: UIViewControllerRepresentable {
    let data: Data
    let subject: String
    let recipients: [String]
    let body: String
    let onCompletion: (Result<MFMailComposeResult, Error>) -> Void
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let viewController = MFMailComposeViewController()
        viewController.mailComposeDelegate = context.coordinator
        viewController.setSubject(subject)
        viewController.setToRecipients(recipients)
        viewController.setMessageBody(body, isHTML: false)
        viewController.addAttachmentData(data, mimeType: "application/pdf", fileName: "receipt.pdf")
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: EmailSheet
        
        init(_ parent: EmailSheet) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if let error = error {
                parent.onCompletion(.failure(error))
            } else {
                parent.onCompletion(.success(result))
            }
            controller.dismiss(animated: true)
        }
    }
}

// For ImageRenderer PDF generation
extension ImageRenderer {
    @MainActor func pdf(size: CGSize) -> Data? {
        // We need to ensure we're calling this on the main thread since uiImage is main-actor isolated
        if !Thread.isMainThread {
            // If we're not on the main thread, dispatch synchronously to the main thread
            var result: Data?
            DispatchQueue.main.sync {
                result = self.pdf(size: size)
            }
            return result
        }
        
        // We're on the main thread now, so we can safely capture the UIImage
        let uiImage = self.uiImage // Capture this on the main thread
        
        // Now we can do the PDF rendering which can happen on any thread
        let bounds = CGRect(origin: .zero, size: size)
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        
        return renderer.pdfData { context in
            context.beginPage()
            
            guard let capturedImage = uiImage, 
                  let cgImage = capturedImage.cgImage else { return }
            
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: bounds.height)
            cgContext.scaleBy(x: 1, y: -1)
            cgContext.draw(cgImage, in: bounds)
        }
    }
}

#Preview {
    TransactionReceiptView(transaction: Transaction.previewTransaction(
        merchantName: "Premium Services Ltd",
        customerId: "CUST456",
        customerName: "Jane Smith",
        reference: "TXN-12345678",
        fee: 1.50,
        authorizationCode: "AUTH123456"
    ))
} 
