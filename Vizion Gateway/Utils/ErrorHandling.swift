import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

// MARK: - AppError Enum

enum VizionAppError: Error, Identifiable, Equatable {
    case networkError(String)
    case authError(String)
    case databaseError(String)
    case validationError(String)
    case transactionError(String)
    case paymentProcessingError(String)
    case permissionError(String)
    case unexpectedError(String)
    
    var id: String {
        switch self {
        case .networkError(let message): return "network_\(message.hashValue)"
        case .authError(let message): return "auth_\(message.hashValue)"
        case .databaseError(let message): return "database_\(message.hashValue)"
        case .validationError(let message): return "validation_\(message.hashValue)"
        case .transactionError(let message): return "transaction_\(message.hashValue)"
        case .paymentProcessingError(let message): return "payment_\(message.hashValue)"
        case .permissionError(let message): return "permission_\(message.hashValue)"
        case .unexpectedError(let message): return "unexpected_\(message.hashValue)"
        }
    }
    
    var message: String {
        switch self {
        case .networkError(let message): return message
        case .authError(let message): return message
        case .databaseError(let message): return message
        case .validationError(let message): return message
        case .transactionError(let message): return message
        case .paymentProcessingError(let message): return message
        case .permissionError(let message): return message
        case .unexpectedError(let message): return message
        }
    }
    
    var title: String {
        switch self {
        case .networkError: return "Network Error"
        case .authError: return "Authentication Error"
        case .databaseError: return "Database Error"
        case .validationError: return "Validation Error"
        case .transactionError: return "Transaction Error"
        case .paymentProcessingError: return "Payment Processing Error"
        case .permissionError: return "Permission Error"
        case .unexpectedError: return "Unexpected Error"
        }
    }
    
    var systemImage: String {
        switch self {
        case .networkError: return "wifi.exclamationmark"
        case .authError: return "lock.shield"
        case .databaseError: return "externaldrive.badge.exclamationmark"
        case .validationError: return "exclamationmark.triangle"
        case .transactionError: return "creditcard.circle.fill"
        case .paymentProcessingError: return "creditcard.slash"
        case .permissionError: return "hand.raised.slash"
        case .unexpectedError: return "xmark.octagon"
        }
    }
    
    var color: Color {
        switch self {
        case .networkError: return .orange
        case .authError: return .red
        case .databaseError: return .yellow
        case .validationError: return .orange
        case .transactionError: return .red
        case .paymentProcessingError: return .red
        case .permissionError: return .red
        case .unexpectedError: return .red
        }
    }
    
    static func == (lhs: VizionAppError, rhs: VizionAppError) -> Bool {
        lhs.id == rhs.id
    }
    
    // Factory method to create AppError from any Error
    static func from(_ error: Error) -> VizionAppError {
        // Check if it's already an AppError
        if let appError = error as? VizionAppError {
            return appError
        }
        
        // Handle Firebase errors
        if let nsError = error as NSError? {
            if let firebaseError = AuthErrorCode(_bridgedNSError: nsError) {
                return .authError(firebaseError.localizedDescription)
            }
            
            let firestoreError = FirestoreErrorCode(_bridgedNSError: nsError)
            if firestoreError != nil {
                return .databaseError(firestoreError!.localizedDescription)
            }
            
            // Other Firebase errors
            if nsError.domain.contains("Firebase") {
                if nsError.code == -8 {
                    return .networkError("Network connection lost. Please check your internet connection.")
                }
                return .databaseError(nsError.localizedDescription)
            }
            
            // Network errors
            if nsError.domain == NSURLErrorDomain {
                return .networkError(nsError.localizedDescription)
            }
        }
        
        // Default to unexpected error
        return .unexpectedError(error.localizedDescription)
    }
}

// MARK: - Error View Modifier

struct ErrorAlertModifier: ViewModifier {
    @Binding var error: VizionAppError?
    
    func body(content: Content) -> some View {
        content
            .alert(item: $error) { appError in
                Alert(
                    title: Text(appError.title),
                    message: Text(appError.message),
                    dismissButton: .default(Text("OK"))
                )
            }
    }
}

// Alternative error display as an in-app toast message
struct ErrorBannerModifier: ViewModifier {
    @Binding var error: VizionAppError?
    @State private var showingBanner = false
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if showingBanner, let error = error {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Image(systemName: error.systemImage)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(error.title)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(error.message)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                self.error = nil
                                showingBanner = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding()
                    .background(error.color)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    .padding()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
                .onAppear {
                    // Auto dismiss after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation {
                            if self.showingBanner {
                                self.error = nil
                                self.showingBanner = false
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: error) { newError in
            withAnimation {
                showingBanner = newError != nil
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Adds an error alert to the view
    func withErrorHandling(_ error: Binding<VizionAppError?>) -> some View {
        self.modifier(ErrorAlertModifier(error: error))
    }
    
    /// Adds an error banner to the view
    func withErrorBanner(_ error: Binding<VizionAppError?>) -> some View {
        self.modifier(ErrorBannerModifier(error: error))
    }
}

// MARK: - Error Logging

class ErrorLogger {
    static let shared = ErrorLogger()
    
    private init() {}
    
    func log(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        // Convert to AppError for consistent format
        let appError = VizionAppError.from(error)
        
        // Log to console
        let fileName = (file as NSString).lastPathComponent
        let errorMessage = "[\(fileName):\(line) \(function)] \(appError.title): \(appError.message)"
        print("🔴 ERROR: \(errorMessage)")
        
        // In a production app, you might want to log to a service like Firebase Crashlytics
        // Crashlytics.crashlytics().record(error: error)
        
        // Additional context
        // Crashlytics.crashlytics().setCustomValue("\(appError.title): \(appError.message)", forKey: "last_error")
    }
} 