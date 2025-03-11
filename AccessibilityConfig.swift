import SwiftUI

struct AccessibilityConfig {
    // MARK: - Text Sizes
    struct TextSize {
        static let small: CGFloat = 14
        static let medium: CGFloat = 16
        static let large: CGFloat = 18
        static let extraLarge: CGFloat = 24
        
        static func scaledSize(_ baseSize: CGFloat) -> CGFloat {
            if UIAccessibility.isBoldTextEnabled {
                return baseSize * 1.2
            }
            return baseSize
        }
    }
    
    // MARK: - Animation Durations
    struct AnimationDuration {
        static var standard: Double {
            UIAccessibility.isReduceMotionEnabled ? 0 : 0.3
        }
        
        static var long: Double {
            UIAccessibility.isReduceMotionEnabled ? 0 : 0.5
        }
    }
    
    // MARK: - Semantic Actions
    struct Actions {
        static let delete = LocalizedStringKey("accessibility_action_delete")
        static let close = LocalizedStringKey("accessibility_action_close")
        static let edit = LocalizedStringKey("accessibility_action_edit")
        static let save = LocalizedStringKey("accessibility_action_save")
        static let cancel = LocalizedStringKey("accessibility_action_cancel")
    }
    
    // MARK: - Haptic Feedback
    enum HapticFeedback {
        static func success() {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        
        static func error() {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        static func warning() {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        
        static func selection() {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

// MARK: - View Modifiers

struct AccessibleButton: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
}

struct AccessibleImage: ViewModifier {
    let label: String
    let hint: String?
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isImage)
    }
}

struct AccessibleGroup: ViewModifier {
    let label: String
    let hint: String?
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
}

// MARK: - View Extensions

extension View {
    func accessibleButton(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = .isButton
    ) -> some View {
        modifier(AccessibleButton(label: label, hint: hint, traits: traits))
    }
    
    func accessibleImage(
        label: String,
        hint: String? = nil
    ) -> some View {
        modifier(AccessibleImage(label: label, hint: hint))
    }
    
    func accessibleGroup(
        label: String,
        hint: String? = nil
    ) -> some View {
        modifier(AccessibleGroup(label: label, hint: hint))
    }
    
    func reduceMotionDisabled() -> some View {
        self.transaction { transaction in
            if UIAccessibility.isReduceMotionEnabled {
                transaction.animation = nil
            }
        }
    }
    
    func scaledFont(_ size: CGFloat) -> some View {
        self.font(.system(size: AccessibilityConfig.TextSize.scaledSize(size)))
    }
} 