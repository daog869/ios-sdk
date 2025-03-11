import Foundation

/// Utility class for formatting payment-related data
public final class PaymentFormatter {
    /// Shared instance for singleton access
    public static let shared = PaymentFormatter()
    
    private let currencyFormatter: NumberFormatter
    
    private init() {
        self.currencyFormatter = NumberFormatter()
        self.currencyFormatter.numberStyle = .currency
        self.currencyFormatter.locale = Locale(identifier: "en_US")
    }
    
    /// Formats a card number with proper spacing
    /// - Parameters:
    ///   - cardNumber: The card number to format
    ///   - cardType: The type of card (determines spacing pattern)
    /// - Returns: The formatted card number
    public func formatCardNumber(_ cardNumber: String, cardType: CardType = .other) -> String {
        let sanitizedNumber = cardNumber.replacingOccurrences(of: " ", with: "")
        
        var formattedNumber = ""
        var index = sanitizedNumber.startIndex
        
        // Different card types have different grouping patterns
        let groupings: [Int]
        switch cardType {
        case .amex:
            groupings = [4, 6, 5] // XXXX XXXXXX XXXXX
        default:
            groupings = [4, 4, 4, 4] // XXXX XXXX XXXX XXXX
        }
        
        for groupSize in groupings {
            guard index < sanitizedNumber.endIndex else { break }
            
            if !formattedNumber.isEmpty {
                formattedNumber += " "
            }
            
            let endIndex = sanitizedNumber.index(index, offsetBy: min(groupSize, sanitizedNumber.distance(from: index, to: sanitizedNumber.endIndex)))
            formattedNumber += String(sanitizedNumber[index..<endIndex])
            index = endIndex
        }
        
        // Add any remaining digits
        if index < sanitizedNumber.endIndex {
            if !formattedNumber.isEmpty {
                formattedNumber += " "
            }
            formattedNumber += String(sanitizedNumber[index...])
        }
        
        return formattedNumber
    }
    
    /// Formats a card expiry date
    /// - Parameters:
    ///   - month: The expiry month (1-12)
    ///   - year: The expiry year
    ///   - format: The desired format (default: MM/YY)
    /// - Returns: The formatted expiry date
    public func formatExpiryDate(month: Int, year: Int, format: ExpiryDateFormat = .shortYear) -> String {
        let monthString = String(format: "%02d", month)
        
        switch format {
        case .shortYear:
            let shortYear = year % 100
            return "\(monthString)/\(String(format: "%02d", shortYear))"
        case .fullYear:
            return "\(monthString)/\(year)"
        }
    }
    
    /// Formats a monetary amount with currency symbol
    /// - Parameters:
    ///   - amount: The amount to format
    ///   - currency: The currency code
    /// - Returns: The formatted amount with currency symbol
    public func formatAmount(_ amount: Decimal, currency: String) -> String {
        currencyFormatter.currencyCode = currency
        
        // Handle special cases for currencies with different decimal places
        switch currency.uppercased() {
        case "JPY", "KRW", "VND":
            currencyFormatter.maximumFractionDigits = 0
        case "BHD", "JOD", "KWD", "OMR":
            currencyFormatter.maximumFractionDigits = 3
        default:
            currencyFormatter.maximumFractionDigits = 2
        }
        
        return currencyFormatter.string(from: amount as NSDecimalNumber) ?? "\(amount) \(currency)"
    }
    
    /// Formats a masked card number for display
    /// - Parameter cardNumber: The full card number
    /// - Returns: The masked card number (e.g., "•••• •••• •••• 1234")
    public func maskCardNumber(_ cardNumber: String) -> String {
        let sanitizedNumber = cardNumber.replacingOccurrences(of: " ", with: "")
        
        guard sanitizedNumber.count >= 4 else {
            return sanitizedNumber
        }
        
        let lastFourStart = sanitizedNumber.index(sanitizedNumber.endIndex, offsetBy: -4)
        let lastFour = String(sanitizedNumber[lastFourStart...])
        
        let cardType = CardType.detect(from: sanitizedNumber)
        let maskLength = sanitizedNumber.count - 4
        
        var maskedNumber = String(repeating: "•", count: maskLength) + lastFour
        return formatCardNumber(maskedNumber, cardType: cardType)
    }
    
    /// Formats a CVV/CVC number with proper masking
    /// - Parameter cvv: The CVV/CVC number
    /// - Returns: The masked CVV/CVC (e.g., "•••")
    public func maskCVV(_ cvv: String) -> String {
        return String(repeating: "•", count: cvv.count)
    }
}

/// Format options for expiry dates
public enum ExpiryDateFormat {
    case shortYear // MM/YY
    case fullYear  // MM/YYYY
} 