import Foundation
import SwiftUI

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "AppLanguage")
            Bundle.setLanguage(currentLanguage.rawValue)
            objectWillChange.send()
        }
    }
    
    private init() {
        // Load saved language or use device language
        if let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage"),
           let language = Language(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // Use device language or default to English
            let preferredLanguage = Bundle.main.preferredLocalizations.first ?? "en"
            self.currentLanguage = Language(rawValue: preferredLanguage) ?? .english
        }
    }
    
    // MARK: - Language Management
    
    func setLanguage(_ language: Language) {
        currentLanguage = language
    }
    
    func localizedString(for key: String, arguments: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        if arguments.isEmpty {
            return format
        }
        return String(format: format, arguments: arguments)
    }
}

// MARK: - Supporting Types

enum Language: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        }
    }
    
    var locale: Locale {
        return Locale(identifier: rawValue)
    }
}

// MARK: - Bundle Extension

extension Bundle {
    private static var bundle: Bundle?
    
    static func setLanguage(_ language: String) {
        let path = Bundle.main.path(forResource: language, ofType: "lproj")
        bundle = path.flatMap(Bundle.init)
    }
    
    static func localizedBundle() -> Bundle {
        return bundle ?? Bundle.main
    }
}

// MARK: - String Extension

extension String {
    var localized: String {
        return NSLocalizedString(self, bundle: Bundle.localizedBundle(), comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        let format = NSLocalizedString(self, bundle: Bundle.localizedBundle(), comment: "")
        return String(format: format, arguments: arguments)
    }
}

// MARK: - View Extension

extension View {
    func localized() -> some View {
        return environmentObject(LocalizationManager.shared)
    }
} 