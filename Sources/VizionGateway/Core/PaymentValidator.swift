import Foundation

/// Utility class for validating payment-related data
public final class PaymentValidator {
    /// Shared instance for singleton access
    public static let shared = PaymentValidator()
    
    private init() {}
    
    /// Validates a card number using the Luhn algorithm
    /// - Parameter cardNumber: The card number to validate
    /// - Returns: Whether the card number is valid
    public func isValidCardNumber(_ cardNumber: String) -> Bool {
        let sanitizedNumber = cardNumber.replacingOccurrences(of: " ", with: "")
        
        guard sanitizedNumber.count >= 13 && sanitizedNumber.count <= 19,
              sanitizedNumber.allSatisfy({ $0.isNumber }) else {
            return false
        }
        
        // Luhn algorithm implementation
        var sum = 0
        let digits = sanitizedNumber.reversed().map { Int(String($0))! }
        
        for (index, digit) in digits.enumerated() {
            if index % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        
        return sum % 10 == 0
    }
    
    /// Validates a card expiry date
    /// - Parameters:
    ///   - month: The expiry month (1-12)
    ///   - year: The expiry year (YY or YYYY format)
    /// - Returns: Whether the expiry date is valid and not expired
    public func isValidExpiryDate(month: Int, year: Int) -> Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        
        // Convert 2-digit year to 4-digit year if necessary
        let fullYear = year < 100 ? 2000 + year : year
        
        // Check if month is valid
        guard (1...12).contains(month) else {
            return false
        }
        
        // Check if year is valid (not more than 20 years in the future)
        guard fullYear >= currentYear && fullYear <= currentYear + 20 else {
            return false
        }
        
        // Check if card is not expired
        if fullYear == currentYear {
            return month >= currentMonth
        }
        
        return true
    }
    
    /// Validates a CVV/CVC number
    /// - Parameters:
    ///   - cvv: The CVV/CVC number
    ///   - cardType: The type of card (determines expected CVV length)
    /// - Returns: Whether the CVV/CVC is valid
    public func isValidCVV(_ cvv: String, cardType: CardType = .other) -> Bool {
        let expectedLength = cardType == .amex ? 4 : 3
        return cvv.count == expectedLength && cvv.allSatisfy { $0.isNumber }
    }
    
    /// Validates a payment amount
    /// - Parameters:
    ///   - amount: The payment amount
    ///   - currency: The currency code
    /// - Returns: Whether the amount is valid for the currency
    public func isValidAmount(_ amount: Decimal, currency: String) -> Bool {
        // Amount must be positive
        guard amount > 0 else {
            return false
        }
        
        // Get number of decimal places for the currency
        let decimalPlaces: Int
        switch currency.uppercased() {
        case "JPY", "KRW", "VND": // Zero decimal currencies
            decimalPlaces = 0
        case "BHD", "JOD", "KWD", "OMR": // Three decimal currencies
            decimalPlaces = 3
        default: // Most currencies use 2 decimal places
            decimalPlaces = 2
        }
        
        // Check if amount has correct number of decimal places
        let amountString = amount.description
        let components = amountString.split(separator: ".")
        if components.count > 1 {
            return components[1].count <= decimalPlaces
        }
        
        return true
    }
    
    /// Validates a currency code
    /// - Parameter currency: The currency code to validate
    /// - Returns: Whether the currency code is valid
    public func isValidCurrency(_ currency: String) -> Bool {
        // List of supported currencies (ISO 4217)
        let supportedCurrencies = [
            "USD", "EUR", "GBP", "CAD", "AUD", "NZD", "CHF", "JPY",
            "HKD", "SGD", "SEK", "DKK", "PLN", "NOK", "HUF", "CZK",
            "ILS", "MXN", "BRL", "PHP", "THB", "IDR", "INR", "MYR",
            "ZAR", "JMD", "TTD", "BBD", "BSD", "KYD", "XCD"
        ]
        
        return supportedCurrencies.contains(currency.uppercased())
    }
}

/// Represents different card types for validation purposes
public enum CardType {
    case visa
    case mastercard
    case amex
    case discover
    case other
    
    /// Determines the card type based on the card number
    /// - Parameter cardNumber: The card number to check
    /// - Returns: The detected card type
    public static func detect(from cardNumber: String) -> CardType {
        let sanitizedNumber = cardNumber.replacingOccurrences(of: " ", with: "")
        
        switch true {
        case sanitizedNumber.hasPrefix("4"):
            return .visa
        case sanitizedNumber.hasPrefix("5"):
            return .mastercard
        case sanitizedNumber.hasPrefix("34"), sanitizedNumber.hasPrefix("37"):
            return .amex
        case sanitizedNumber.hasPrefix("6"):
            return .discover
        default:
            return .other
        }
    }
} 