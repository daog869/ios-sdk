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
        firebaseId: String? = nil
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
        self.firebaseId = firebaseId
    }
    
    // Firebase Dictionary Conversion
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "firstName": firstName,
            "lastName": lastName,
            "email": email,
            "role": role.rawValue,
            "isActive": isActive,
            "createdAt": createdAt.timeIntervalSince1970
        ]
        
        if let phone = phone {
            dict["phone"] = phone
        }
        
        if let lastLogin = lastLogin {
            dict["lastLogin"] = lastLogin.timeIntervalSince1970
        }
        
        return dict
    }
    
    // Initialize from Firebase document
    static func fromDictionary(_ dict: [String: Any], id: String) -> User? {
        guard 
            let firstName = dict["firstName"] as? String,
            let lastName = dict["lastName"] as? String,
            let email = dict["email"] as? String,
            let roleString = dict["role"] as? String,
            let role = UserRole(rawValue: roleString),
            let isActive = dict["isActive"] as? Bool,
            let createdAtTimestamp = dict["createdAt"] as? TimeInterval
        else {
            return nil
        }
        
        let phone = dict["phone"] as? String
        let lastLoginTimestamp = dict["lastLogin"] as? TimeInterval
        let lastLogin = lastLoginTimestamp.map { Date(timeIntervalSince1970: $0) }
        
        return User(
            id: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            role: role,
            isActive: isActive,
            createdAt: Date(timeIntervalSince1970: createdAtTimestamp),
            lastLogin: lastLogin,
            firebaseId: id
        )
    }
}

// The UserRole enum is defined in the UserManagementView.swift file 