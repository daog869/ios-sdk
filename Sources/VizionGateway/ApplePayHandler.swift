import SwiftUI
import PassKit

/// Handles Apple Pay payment processing
public class ApplePayHandler: NSObject, PKPaymentAuthorizationViewControllerDelegate {
    /// Completion handler type for payment results
    public typealias CompletionHandler = (Bool) -> Void
    
    private var completion: CompletionHandler?
    private let paymentManager = PaymentManager.shared
    private var amount: Decimal
    private var sourceId: String
    private var destinationId: String
    private var orderId: String
    private var metadata: [String: String]
    
    /// Initialize the Apple Pay handler
    /// - Parameters:
    ///   - amount: The payment amount
    ///   - sourceId: ID of the source account or customer
    ///   - destinationId: ID of the destination account or merchant
    ///   - orderId: The order ID associated with this payment
    ///   - metadata: Optional metadata for the transaction
    public init(
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
    
    /// Check if Apple Pay is available
    /// - Returns: A tuple indicating if the device can make payments and if it has cards set up
    public static func applePayStatus() -> (canMakePayments: Bool, canSetupCards: Bool) {
        return (
            PKPaymentAuthorizationViewController.canMakePayments(),
            PKPaymentAuthorizationViewController.canMakePayments(usingNetworks: [.visa, .masterCard, .amex])
        )
    }
    
    /// Present the Apple Pay sheet
    /// - Parameters:
    ///   - viewController: The view controller to present from
    ///   - completion: A completion handler called when the payment is complete
    public func presentApplePay(in viewController: UIViewController, completion: @escaping CompletionHandler) {
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.viziongateway.payment" // Your merchant ID
        request.countryCode = "LC" // Saint Lucia or your Caribbean country code
        request.currencyCode = "XCD" // Eastern Caribbean Dollar
        request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        request.merchantCapabilities = [.capability3DS, .capabilityDebit, .capabilityCredit]
        
        // Add the payment amount
        let total = NSDecimalNumber(decimal: amount)
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(label: "Order #\(orderId)", amount: total)
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
    
    /// Called when a payment is authorized in Apple Pay
    public func paymentAuthorizationViewController(
        _ controller: PKPaymentAuthorizationViewController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        // Process payment with the payment manager
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
    
    /// Called when the payment UI is dismissed
    public func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true)
    }
    
    // MARK: - Private Methods
    
    /// Process an Apple Pay payment
    /// - Parameters:
    ///   - token: The Apple Pay token
    ///   - amount: The payment amount
    ///   - currency: The payment currency
    ///   - sourceId: ID of the source account or customer
    ///   - destinationId: ID of the destination account or merchant
    ///   - metadata: Optional metadata for the transaction
    /// - Returns: The payment result
    private func processApplePayment(
        token: PKPaymentToken,
        amount: Decimal,
        currency: Currency,
        sourceId: String,
        destinationId: String,
        metadata: [String: String]? = nil
    ) async throws -> PaymentResult {
        // Convert token to base64 string for storage
        let tokenData = try JSONEncoder().encode(token.paymentData)
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