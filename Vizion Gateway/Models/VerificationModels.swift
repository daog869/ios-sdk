import SwiftUI
import Foundation

// MARK: - Verification Status Enums

/// Basic verification status for simple identity checks
enum BasicVerificationStatus: String, CaseIterable {
    case pending = "Pending"
    case inReview = "In Review"
    case approved = "Approved"
    case rejected = "Rejected"
    case expired = "Expired"
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .inReview: return .blue
        case .approved: return .green
        case .rejected: return .red
        case .expired: return .gray
        }
    }
}

/// Detailed KYC verification status with additional states
enum KYCVerificationStatus: String, Codable, CaseIterable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case documentVerificationPending = "Document Verification Pending"
    case underReview = "Under Review"
    case enhancedDueDiligence = "Enhanced Due Diligence"
    case additionalInformationRequired = "Additional Information Required"
    case verified = "Verified"
    case rejected = "Rejected"
    
    var color: Color {
        switch self {
        case .notStarted:
            return .gray
        case .inProgress, .documentVerificationPending:
            return .blue
        case .underReview:
            return .orange
        case .enhancedDueDiligence:
            return .purple
        case .additionalInformationRequired:
            return .yellow
        case .verified:
            return .green
        case .rejected:
            return .red
        }
    }
    
    var description: String {
        switch self {
        case .notStarted:
            return "Identity verification not started"
        case .inProgress:
            return "Verification in progress"
        case .documentVerificationPending:
            return "Verifying your documents"
        case .underReview:
            return "Your information is under review"
        case .enhancedDueDiligence:
            return "Additional verification required"
        case .additionalInformationRequired:
            return "We need more information"
        case .verified:
            return "Identity verified"
        case .rejected:
            return "Verification rejected"
        }
    }
}

// MARK: - Document Type Enums

/// Basic document types for simple identity verification
enum BasicDocumentType: String, CaseIterable {
    case passport = "Passport"
    case driverLicense = "Driver's License"
    case nationalId = "National ID"
    case utilityBill = "Utility Bill"
    case bankStatement = "Bank Statement"
}

/// Detailed document types for KYC verification
enum KYCDocumentType: String, CaseIterable {
    case identityPassport = "identity_passport"
    case identityDriverLicense = "identity_drivers_license"
    case identityNationalId = "identity_national_id"
    case addressUtilityBill = "address_utility_bill"
    case addressBankStatement = "address_bank_statement"
    case selfie = "selfie"
    
    var displayName: String {
        switch self {
        case .identityPassport:
            return "Passport"
        case .identityDriverLicense:
            return "Driver's License"
        case .identityNationalId:
            return "National ID"
        case .addressUtilityBill:
            return "Utility Bill"
        case .addressBankStatement:
            return "Bank Statement"
        case .selfie:
            return "Selfie"
        }
    }
    
    var description: String {
        switch self {
        case .identityPassport:
            return "A valid passport showing your photo, name, and date of birth"
        case .identityDriverLicense:
            return "A valid driver's license showing your photo, name, and date of birth"
        case .identityNationalId:
            return "A government-issued ID card showing your photo, name, and date of birth"
        case .addressUtilityBill:
            return "A utility bill (electricity, water, etc.) showing your name and address, issued within the last 3 months"
        case .addressBankStatement:
            return "A bank statement showing your name and address, issued within the last 3 months"
        case .selfie:
            return "A clear photo of yourself holding your ID document"
        }
    }
    
    var icon: String {
        switch self {
        case .identityPassport:
            return "person.text.rectangle"
        case .identityDriverLicense:
            return "car"
        case .identityNationalId:
            return "creditcard"
        case .addressUtilityBill:
            return "bolt.fill"
        case .addressBankStatement:
            return "building.columns"
        case .selfie:
            return "person.fill.viewfinder"
        }
    }
    
    var verificationStepId: String {
        switch self {
        case .identityPassport, .identityDriverLicense, .identityNationalId:
            return "identity_verification"
        case .addressUtilityBill, .addressBankStatement:
            return "address_verification"
        case .selfie:
            return "selfie_verification"
        }
    }
}

// MARK: - Verification Models

/// Basic identity verification record
struct BasicIdentityVerification: Identifiable {
    let id: String
    let customerName: String
    let customerEmail: String
    let merchantId: String
    let submittedAt: Date
    let status: BasicVerificationStatus
    let notes: String
    let documentType: BasicDocumentType
    
    init(
        id: String = UUID().uuidString,
        customerName: String,
        customerEmail: String,
        merchantId: String,
        submittedAt: Date = Date(),
        status: BasicVerificationStatus = .pending,
        notes: String = "",
        documentType: BasicDocumentType
    ) {
        self.id = id
        self.customerName = customerName
        self.customerEmail = customerEmail
        self.merchantId = merchantId
        self.submittedAt = submittedAt
        self.status = status
        self.notes = notes
        self.documentType = documentType
    }
}

/// Verification step model
struct VerificationStep: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String?
    var isCompleted: Bool
    var timestamp: Date?
}

/// Default verification steps
struct VerificationStepTemplate {
    static let defaultSteps: [VerificationStep] = [
        VerificationStep(id: "personal_information", name: "Personal Information", description: "Provide your basic personal information", isCompleted: false, timestamp: nil),
        VerificationStep(id: "identity_verification", name: "Identity Verification", description: "Upload a government-issued ID", isCompleted: false, timestamp: nil),
        VerificationStep(id: "address_verification", name: "Address Verification", description: "Confirm your residential address", isCompleted: false, timestamp: nil),
        VerificationStep(id: "selfie_verification", name: "Selfie Verification", description: "Take a selfie for facial recognition", isCompleted: false, timestamp: nil),
        VerificationStep(id: "document_verification", name: "Document Verification", description: "Verifying your documents", isCompleted: false, timestamp: nil),
        VerificationStep(id: "aml_screening", name: "AML Screening", description: "Anti-Money Laundering checks", isCompleted: false, timestamp: nil)
    ]
} 