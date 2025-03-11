import SwiftUI
import Combine

class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()
    
    @Published var isVoiceOverRunning: Bool = UIAccessibility.isVoiceOverRunning
    @Published var isSwitchControlRunning: Bool = UIAccessibility.isSwitchControlRunning
    @Published var isReduceMotionEnabled: Bool = UIAccessibility.isReduceMotionEnabled
    @Published var isDarkerSystemColorsEnabled: Bool = UIAccessibility.isDarkerSystemColorsEnabled
    @Published var isBoldTextEnabled: Bool = UIAccessibility.isBoldTextEnabled
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        // Voice Over status
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
            }
            .store(in: &cancellables)
        
        // Switch Control status
        NotificationCenter.default.publisher(for: UIAccessibility.switchControlStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isSwitchControlRunning = UIAccessibility.isSwitchControlRunning
            }
            .store(in: &cancellables)
        
        // Reduce Motion status
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
            }
            .store(in: &cancellables)
        
        // Darker System Colors status
        NotificationCenter.default.publisher(for: UIAccessibility.darkerSystemColorsStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isDarkerSystemColorsEnabled = UIAccessibility.isDarkerSystemColorsEnabled
            }
            .store(in: &cancellables)
        
        // Bold Text status
        NotificationCenter.default.publisher(for: UIAccessibility.boldTextStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
            }
            .store(in: &cancellables)
    }
}

// MARK: - Accessibility View Modifiers

extension View {
    func accessibilityAction(named name: String, action: @escaping () -> Void) -> some View {
        self.accessibilityAction {
            UIAccessibility.post(notification: .announcement, argument: name)
            action()
        }
    }
    
    func accessibilityValue(_ value: String) -> some View {
        self.accessibilityValue(Text(value))
    }
    
    func accessibilityLabel(_ label: String) -> some View {
        self.accessibilityLabel(Text(label))
    }
    
    func accessibilityHint(_ hint: String) -> some View {
        self.accessibilityHint(Text(hint))
    }
}

// MARK: - Dynamic Type Support

extension View {
    func dynamicTypeSize(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(.system(size: size, weight: weight, design: .default))
            .minimumScaleFactor(0.5)
            .lineLimit(nil)
    }
}

// MARK: - Semantic Accessibility Traits

extension View {
    func accessibilityTraitButton() -> some View {
        self.accessibilityAddTraits(.isButton)
    }
    
    func accessibilityTraitHeader() -> some View {
        self.accessibilityAddTraits(.isHeader)
    }
    
    func accessibilityTraitSelected(_ isSelected: Bool) -> some View {
        self.accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    func accessibilityTraitToggle(_ isOn: Bool) -> some View {
        self.accessibilityAddTraits(.isButton)
            .accessibilityValue(isOn ? "On" : "Off")
    }
}

// MARK: - Accessibility Groups

struct AccessibilityGroup<Content: View>: View {
    let label: String
    let content: Content
    
    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }
    
    var body: some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
    }
}

// MARK: - Accessibility Actions

enum AccessibilityAction: String {
    case increment = "Increment"
    case decrement = "Decrement"
    case delete = "Delete"
    case close = "Close"
    case confirm = "Confirm"
    case cancel = "Cancel"
    
    var announcement: String {
        switch self {
        case .increment: return "Value increased"
        case .decrement: return "Value decreased"
        case .delete: return "Item deleted"
        case .close: return "Closed"
        case .confirm: return "Confirmed"
        case .cancel: return "Cancelled"
        }
    }
}

extension View {
    func accessibilityCustomAction(_ action: AccessibilityAction, perform: @escaping () -> Void) -> some View {
        self.accessibilityAction(named: action.rawValue) {
            perform()
            UIAccessibility.post(notification: .announcement, argument: action.announcement)
        }
    }
}

// MARK: - Accessibility Focus Management

class AccessibilityFocusState: ObservableObject {
    @Published var currentFocus: String?
    
    func focus(_ identifier: String) {
        currentFocus = identifier
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }
}

struct AccessibilityFocused: ViewModifier {
    let id: String
    @ObservedObject var state: AccessibilityFocusState
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(state.currentFocus == id ? .isSelected : [])
    }
} 