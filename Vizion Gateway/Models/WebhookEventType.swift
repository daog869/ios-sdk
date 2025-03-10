import Foundation

enum WebhookEventType: String, CaseIterable {
    case paymentSucceeded = "payment.succeeded"
    case paymentFailed = "payment.failed"
    case paymentPending = "payment.pending"
    case paymentRefunded = "payment.refunded"
    case paymentDisputed = "payment.disputed"
    
    case customerCreated = "customer.created"
    case customerUpdated = "customer.updated"
    case customerDeleted = "customer.deleted"
    
    case applicationCreated = "application.created"
    case applicationUpdated = "application.updated"
    case applicationDeleted = "application.deleted"
    
    case verificationSucceeded = "verification.succeeded"
    case verificationFailed = "verification.failed"
    case verificationPending = "verification.pending"
    
    case accountUpdated = "account.updated"
    case accountDeactivated = "account.deactivated"
    
    var displayName: String {
        switch self {
        case .paymentSucceeded: return "Payment Succeeded"
        case .paymentFailed: return "Payment Failed"
        case .paymentPending: return "Payment Pending"
        case .paymentRefunded: return "Payment Refunded"
        case .paymentDisputed: return "Payment Disputed"
            
        case .customerCreated: return "Customer Created"
        case .customerUpdated: return "Customer Updated"
        case .customerDeleted: return "Customer Deleted"
            
        case .applicationCreated: return "Application Created"
        case .applicationUpdated: return "Application Updated"
        case .applicationDeleted: return "Application Deleted"
            
        case .verificationSucceeded: return "Verification Succeeded"
        case .verificationFailed: return "Verification Failed"
        case .verificationPending: return "Verification Pending"
            
        case .accountUpdated: return "Account Updated"
        case .accountDeactivated: return "Account Deactivated"
        }
    }
    
    var description: String {
        switch self {
        case .paymentSucceeded:
            return "Triggered when a payment is successfully processed"
        case .paymentFailed:
            return "Triggered when a payment attempt fails"
        case .paymentPending:
            return "Triggered when a payment is awaiting processing"
        case .paymentRefunded:
            return "Triggered when a payment is refunded"
        case .paymentDisputed:
            return "Triggered when a payment is disputed by the customer"
            
        case .customerCreated:
            return "Triggered when a new customer is created"
        case .customerUpdated:
            return "Triggered when customer information is updated"
        case .customerDeleted:
            return "Triggered when a customer is deleted"
            
        case .applicationCreated:
            return "Triggered when a new application is registered"
        case .applicationUpdated:
            return "Triggered when an application is updated"
        case .applicationDeleted:
            return "Triggered when an application is deleted"
            
        case .verificationSucceeded:
            return "Triggered when an identity verification is successful"
        case .verificationFailed:
            return "Triggered when an identity verification fails"
        case .verificationPending:
            return "Triggered when an identity verification is pending review"
            
        case .accountUpdated:
            return "Triggered when account settings are updated"
        case .accountDeactivated:
            return "Triggered when an account is deactivated"
        }
    }
} 