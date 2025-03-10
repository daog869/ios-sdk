import Foundation
import SwiftData

// Define UserRole enum here to ensure proper persistence support
enum UserRole: String, Codable, CaseIterable {
    case admin = "Admin"
    case merchant = "Merchant"
    case customer = "Customer"
    case bank = "Bank"
    case manager = "Manager"
    case analyst = "Analyst" 
    case viewer = "Viewer"
}

// Define Caribbean islands
enum Island: String, Codable, CaseIterable, Identifiable {
    case stKitts = "St. Kitts"
    case nevis = "Nevis"
    case antigua = "Antigua"
    case barbuda = "Barbuda"
    case anguilla = "Anguilla"
    case grenada = "Grenada"
    case dominica = "Dominica"
    case stLucia = "St. Lucia"
    
    var id: String { rawValue }
}

@Model
final class User {
    var id: String
    var firstName: String
    var lastName: String
    var email: String
    var phone: String?
    var role: UserRole
    var isActive: Bool
    var createdAt: Date
    var lastLogin: Date?
    var island: Island?  // Added island field
    var address: String?  // Added address field
    var businessName: String?  // For merchant users
    var isVerified: Bool = false  // Track KYC/AML verification status
    var verificationDate: Date?   // When the user was verified
    var profileImageURL: String?  // URL to the user's profile image
    
    // Firebase identifiers
    var firebaseId: String?
    
    // Computed properties
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    // Default initializer
    init(
        id: String = UUID().uuidString,
        firstName: String,
        lastName: String,
        email: String,
        phone: String? = nil,
        role: UserRole = .viewer,
        isActive: Bool = true,
        createdAt: Date = Date(),
        lastLogin: Date? = nil,
        island: Island? = nil,
        address: String? = nil,
        businessName: String? = nil,
        firebaseId: String? = nil,
        isVerified: Bool = false,
        verificationDate: Date? = nil,
        profileImageURL: String? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.role = role
        self.isActive = isActive
        self.createdAt = createdAt
        self.lastLogin = lastLogin
        self.island = island
        self.address = address
        self.businessName = businessName
        self.firebaseId = firebaseId
        self.isVerified = isVerified
        self.verificationDate = verificationDate
        self.profileImageURL = profileImageURL
    }
    
    // Note: Firebase serialization methods (toDictionary and fromDictionary) 
    // are implemented in FirebaseSerializable.swift through protocol extensions
}

// The UserRole enum is defined in the UserManagementView.swift file 