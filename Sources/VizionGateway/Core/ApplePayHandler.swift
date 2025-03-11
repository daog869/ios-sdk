import Foundation
import PassKit

/// Handles Apple Pay payment processing in the Vizion Gateway system
@available(iOS 17.0, macOS 14.0, *)
public final class ApplePayHandler: NSObject {
    
    // MARK: - Properties
    
    private let amount: Decimal
    private let sourceId: String
    private let destinationId: String
    private let orderId: String
    private let paymentManager: PaymentManager
    private var completion: ((Bool) -> Void)?
    
    // MARK: - Initialization
    
    /// Initialize an Apple Pay payment handler
    /// - Parameters:
    ///   - amount: The payment amount
    ///   - sourceId: The customer's ID
    ///   - destinationId: The merchant's ID
    ///   - orderId: The unique order identifier
    public init(
        amount: Decimal,
        sourceId: String,
        destinationId: String,
        orderId: String
    ) {
        self.amount = amount
        self.sourceId = sourceId
        self.destinationId = destinationId
        self.orderId = orderId
        self.paymentManager = PaymentManager()
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Present the Apple Pay payment sheet
    /// - Parameters:
    ///   - viewController: The view controller to present from
    ///   - completion: Completion handler with success boolean
    public func presentApplePay(
        in viewController: UIViewController,
        completion: @escaping (Bool) -> Void
    ) {
        guard VizionGateway.shared.isConfigured else {
            completion(false)
            return
        }
        
        self.completion = completion
        
        let request = PKPaymentRequest()
        request.merchantIdentifier = VizionGateway.shared.merchantId
        request.supportedNetworks = [.visa, .masterCard, .amex]
        request.merchantCapabilities = .capability3DS
        request.countryCode = "LC" // Saint Lucia
        request.currencyCode = "XCD"
        
        let total = PKPaymentSummaryItem(
            label: "Total",
            amount: NSDecimalNumber(decimal: amount)
        )
        request.paymentSummaryItems = [total]
        
        guard let controller = PKPaymentAuthorizationViewController(paymentRequest: request) else {
            completion(false)
            return
        }
        
        controller.delegate = self
        viewController.present(controller, animated: true)
    }
}

// MARK: - PKPaymentAuthorizationViewControllerDelegate

@available(iOS 17.0, macOS 14.0, *)
extension ApplePayHandler: PKPaymentAuthorizationViewControllerDelegate {
    
    public func paymentAuthorizationViewController(
        _ controller: PKPaymentAuthorizationViewController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        // Process the payment with Vizion Gateway
        paymentManager.processCardPayment(
            amount: amount,
            currency: "XCD",
            sourceId: sourceId,
            destinationId: destinationId,
            orderId: orderId
        ) { result in
            switch result {
            case .success:
                completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
            case .failure(let error):
                let errors = [
                    NSError(
                        domain: "com.viziongateway.error",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
                    )
                ]
                completion(PKPaymentAuthorizationResult(status: .failure, errors: errors))
            }
        }
    }
    
    public func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.completion?(true)
        }
    }
} 