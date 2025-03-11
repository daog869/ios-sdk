import SwiftUI
import PassKit

class ApplePayHandler: NSObject, PKPaymentAuthorizationViewControllerDelegate {
    typealias CompletionHandler = (Bool) -> Void
    
    private var completion: CompletionHandler?
    private let paymentManager = PaymentManager.shared
    private var amount: Decimal
    private var sourceId: String
    private var destinationId: String
    private var orderId: String
    private var metadata: [String: String]
    
    init(
        amount: Decimal,
        sourceId: String,
        destinationId: String,
        orderId: String,
        metadata: [String: String] = [:]
    ) {
        self.amount = amount
        self.sourceId = sourceId
        self.destinationId = destinationId
        self.orderId = orderId
        self.metadata = metadata
        super.init()
    }
    
    // Check if Apple Pay is available
    static func applePayStatus() -> (canMakePayments: Bool, canSetupCards: Bool) {
        return (
            PKPaymentAuthorizationViewController.canMakePayments(),
            PKPaymentAuthorizationViewController.canMakePayments(usingNetworks: [.visa, .masterCard, .amex])
        )
    }
    
    // Present Apple Pay sheet
    func presentApplePay(in viewController: UIViewController, completion: @escaping CompletionHandler) {
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.viziongateway.payment" // Your merchant ID
        request.countryCode = "LC" // Saint Lucia or your Caribbean country code
        request.currencyCode = "XCD" // Eastern Caribbean Dollar
        request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        request.merchantCapabilities = [.capability3DS, .capabilityDebit, .capabilityCredit]
        
        // Add the payment amount
        let total = NSDecimalNumber(decimal: amount)
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(label: "Chef Reloaded Order #\(orderId)", amount: total)
        ]
        
        // Create and present the Apple Pay sheet
        if let applePayController = PKPaymentAuthorizationViewController(paymentRequest: request) {
            self.completion = completion
            applePayController.delegate = self
            viewController.present(applePayController, animated: true)
        } else {
            completion(false)
        }
    }
    
    // MARK: - PKPaymentAuthorizationViewControllerDelegate
    
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, 
                                           didAuthorizePayment payment: PKPayment, 
                                           handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        // Process payment with Vizion Gateway
        Task {
            do {
                // Add order ID to metadata
                var paymentMetadata = self.metadata
                paymentMetadata["order_id"] = orderId
                
                // Process the payment
                let result = try await processApplePayment(
                    token: payment.token,
                    amount: amount,
                    currency: .xcd,
                    sourceId: sourceId,
                    destinationId: destinationId,
                    metadata: paymentMetadata
                )
                
                if result.status == .completed {
                    completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
                    self.completion?(true)
                } else {
                    let errors = [PKPaymentError(.unknownError)]
                    completion(PKPaymentAuthorizationResult(status: .failure, errors: errors))
                    self.completion?(false)
                }
            } catch {
                let errors = [PKPaymentError(.unknownError)]
                completion(PKPaymentAuthorizationResult(status: .failure, errors: errors))
                self.completion?(false)
            }
        }
    }
    
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true)
    }
    
    // Process Apple Pay payment
    private func processApplePayment(
        token: PKPaymentToken,
        amount: Decimal,
        currency: Currency,
        sourceId: String,
        destinationId: String,
        metadata: [String: String]? = nil
    ) async throws -> PaymentResult {
        // Convert token to base64 string for storage
        let tokenData = try JSONEncoder().encode(token)
        let tokenBase64 = tokenData.base64EncodedString()
        
        // Create combined metadata with Apple Pay token
        var combinedMetadata = metadata ?? [:]
        combinedMetadata["apple_pay_token"] = tokenBase64
        
        // Use standard payment process with Apple Pay method
        return try await paymentManager.processPayment(
            amount: amount,
            currency: currency,
            method: .applePay,
            sourceId: sourceId,
            destinationId: destinationId,
            metadata: combinedMetadata
        )
    }
} 