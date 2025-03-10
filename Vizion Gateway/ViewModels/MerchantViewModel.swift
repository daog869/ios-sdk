import Foundation
import Combine
import FirebaseFirestore
import SwiftUI

class MerchantViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var merchants: [Merchant] = []
    @Published var selectedMerchant: Merchant?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var successMessage: String?
    @Published var showSuccess: Bool = false
    
    // MARK: - Form Fields
    @Published var merchantName: String = ""
    @Published var businessType: String = ""
    @Published var merchantType: MerchantType = .api
    @Published var contactEmail: String = ""
    @Published var contactPhone: String = ""
    @Published var address: String = ""
    @Published var island: Island = .stKitts
    @Published var taxId: String = ""
    @Published var websiteUrl: String = ""
    @Published var businessDescription: String = ""
    @Published var settlementPeriod: Int = 1
    @Published var transactionFeePercentage: Decimal = 0.029
    @Published var flatFeeCents: Int = 30
    
    // Bank account details
    @Published var bankName: String = ""
    @Published var bankType: BankType = .nationalBank
    @Published var accountNumber: String = ""
    @Published var accountName: String = ""
    @Published var routingNumber: String = ""
    @Published var iban: String = ""
    @Published var swift: String = ""
    
    // MARK: - Services
    private let merchantManager = MerchantManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Set up additional subscribers if needed
    }
    
    // MARK: - Merchant Operations
    
    /// Load all merchants
    func loadMerchants() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let loadedMerchants = try await merchantManager.getMerchants()
                
                await MainActor.run {
                    self.merchants = loadedMerchants
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load merchants: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Load details for a specific merchant
    func loadMerchantDetails(id: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let merchant = try await merchantManager.getMerchantDetails(id: id)
                
                await MainActor.run {
                    self.selectedMerchant = merchant
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load merchant details: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Create a new merchant
    func createMerchant() {
        guard validateForm() else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Create bank account if all fields are filled
        var bankAccount: BankAccount? = nil
        if !accountNumber.isEmpty && !accountName.isEmpty {
            bankAccount = BankAccount(
                bankName: bankName,
                bankType: bankType,
                accountNumber: accountNumber,
                accountName: accountName,
                routingNumber: routingNumber.isEmpty ? nil : routingNumber,
                iban: iban.isEmpty ? nil : iban,
                swift: swift.isEmpty ? nil : swift
            )
        }
        
        // Create merchant
        let merchant = Merchant(
            name: merchantName,
            businessType: businessType,
            merchantType: merchantType,
            contactEmail: contactEmail,
            contactPhone: contactPhone.isEmpty ? nil : contactPhone,
            address: address.isEmpty ? nil : address,
            island: island,
            taxId: taxId.isEmpty ? nil : taxId,
            bankAccount: bankAccount,
            websiteUrl: websiteUrl.isEmpty ? nil : websiteUrl,
            businessDescription: businessDescription.isEmpty ? nil : businessDescription,
            settlementPeriod: settlementPeriod,
            transactionFeePercentage: transactionFeePercentage,
            flatFeeCents: flatFeeCents
        )
        
        Task {
            do {
                let createdMerchant = try await merchantManager.createMerchant(merchant)
                
                await MainActor.run {
                    self.merchants.insert(createdMerchant, at: 0)
                    self.selectedMerchant = createdMerchant
                    self.successMessage = "Merchant created successfully!"
                    self.showSuccess = true
                    self.isLoading = false
                    self.resetForm()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to create merchant: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Update an existing merchant
    func updateMerchant() {
        guard let selectedMerchant = selectedMerchant else { return }
        guard validateForm() else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Update merchant properties
        selectedMerchant.name = merchantName
        selectedMerchant.businessType = businessType
        selectedMerchant.merchantType = merchantType
        selectedMerchant.contactEmail = contactEmail
        selectedMerchant.contactPhone = contactPhone.isEmpty ? nil : contactPhone
        selectedMerchant.address = address.isEmpty ? nil : address
        selectedMerchant.island = island
        selectedMerchant.taxId = taxId.isEmpty ? nil : taxId
        selectedMerchant.websiteUrl = websiteUrl.isEmpty ? nil : websiteUrl
        selectedMerchant.businessDescription = businessDescription.isEmpty ? nil : businessDescription
        selectedMerchant.settlementPeriod = settlementPeriod
        selectedMerchant.transactionFeePercentage = transactionFeePercentage
        selectedMerchant.flatFeeCents = flatFeeCents
        selectedMerchant.updatedAt = Date()
        
        // Update bank account if all fields are filled
        if !accountNumber.isEmpty && !accountName.isEmpty {
            selectedMerchant.bankAccount = BankAccount(
                bankName: bankName,
                bankType: bankType,
                accountNumber: accountNumber,
                accountName: accountName,
                routingNumber: routingNumber.isEmpty ? nil : routingNumber,
                iban: iban.isEmpty ? nil : iban,
                swift: swift.isEmpty ? nil : swift
            )
        }
        
        Task {
            do {
                try await merchantManager.updateMerchant(selectedMerchant)
                
                await MainActor.run {
                    // Update merchants list
                    if let index = self.merchants.firstIndex(where: { $0.id == selectedMerchant.id }) {
                        self.merchants[index] = selectedMerchant
                    }
                    
                    self.successMessage = "Merchant updated successfully!"
                    self.showSuccess = true
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to update merchant: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Suspend a merchant
    func suspendMerchant(id: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await merchantManager.suspendMerchant(id: id)
                
                await MainActor.run {
                    // Update status in local data
                    if let index = self.merchants.firstIndex(where: { $0.id == id }) {
                        self.merchants[index].status = .suspended
                    }
                    
                    if let selectedMerchant = self.selectedMerchant, selectedMerchant.id == id {
                        self.selectedMerchant?.status = .suspended
                    }
                    
                    self.successMessage = "Merchant suspended successfully"
                    self.showSuccess = true
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to suspend merchant: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Activate a merchant
    func activateMerchant(id: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await merchantManager.activateMerchant(id: id)
                
                await MainActor.run {
                    // Update status in local data
                    if let index = self.merchants.firstIndex(where: { $0.id == id }) {
                        self.merchants[index].status = .active
                    }
                    
                    if let selectedMerchant = self.selectedMerchant, selectedMerchant.id == id {
                        self.selectedMerchant?.status = .active
                    }
                    
                    self.successMessage = "Merchant activated successfully"
                    self.showSuccess = true
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to activate merchant: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - API Key Operations
    
    func generateApiKey(for merchantId: String, name: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let apiKey = try await merchantManager.generateAPIKey(for: merchantId, name: name)
                
                await MainActor.run {
                    // Add to selected merchant's API keys
                    if let selectedMerchant = self.selectedMerchant, selectedMerchant.id == merchantId {
                        if self.selectedMerchant?.apiKeys == nil {
                            self.selectedMerchant?.apiKeys = []
                        }
                        self.selectedMerchant?.apiKeys?.append(apiKey)
                    }
                    
                    self.successMessage = "API key generated successfully"
                    self.showSuccess = true
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to generate API key: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    func revokeApiKey(id: String, merchantId: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await merchantManager.revokeAPIKey(id: id)
                
                await MainActor.run {
                    // Update selected merchant's API keys
                    if let selectedMerchant = self.selectedMerchant, selectedMerchant.id == merchantId {
                        if let index = self.selectedMerchant?.apiKeys?.firstIndex(where: { $0.id == id }) {
                            self.selectedMerchant?.apiKeys?[index].active = false
                        }
                    }
                    
                    self.successMessage = "API key revoked successfully"
                    self.showSuccess = true
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to revoke API key: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Form Handling
    
    /// Populate form fields with selected merchant data
    func populateFormWithSelectedMerchant() {
        guard let merchant = selectedMerchant else { return }
        
        merchantName = merchant.name
        businessType = merchant.businessType
        merchantType = merchant.merchantType
        contactEmail = merchant.contactEmail
        contactPhone = merchant.contactPhone ?? ""
        address = merchant.address ?? ""
        island = merchant.island
        taxId = merchant.taxId ?? ""
        websiteUrl = merchant.websiteUrl ?? ""
        businessDescription = merchant.businessDescription ?? ""
        settlementPeriod = merchant.settlementPeriod
        transactionFeePercentage = merchant.transactionFeePercentage
        flatFeeCents = merchant.flatFeeCents
        
        // Bank account details
        if let bankAccount = merchant.bankAccount {
            bankName = bankAccount.bankName
            bankType = bankAccount.bankType
            accountNumber = bankAccount.accountNumber
            accountName = bankAccount.accountName
            routingNumber = bankAccount.routingNumber ?? ""
            iban = bankAccount.iban ?? ""
            swift = bankAccount.swift ?? ""
        } else {
            resetBankAccountForm()
        }
    }
    
    /// Reset form fields
    func resetForm() {
        merchantName = ""
        businessType = ""
        merchantType = .api
        contactEmail = ""
        contactPhone = ""
        address = ""
        island = .stKitts
        taxId = ""
        websiteUrl = ""
        businessDescription = ""
        settlementPeriod = 1
        transactionFeePercentage = 0.029
        flatFeeCents = 30
        
        resetBankAccountForm()
    }
    
    /// Reset only bank account fields
    private func resetBankAccountForm() {
        bankName = ""
        bankType = .nationalBank
        accountNumber = ""
        accountName = ""
        routingNumber = ""
        iban = ""
        swift = ""
    }
    
    /// Validate form fields
    private func validateForm() -> Bool {
        // Basic validation
        if merchantName.isEmpty {
            errorMessage = "Merchant name is required"
            showError = true
            return false
        }
        
        if businessType.isEmpty {
            errorMessage = "Business type is required"
            showError = true
            return false
        }
        
        if contactEmail.isEmpty {
            errorMessage = "Contact email is required"
            showError = true
            return false
        }
        
        // Email validation
        if !isValidEmail(contactEmail) {
            errorMessage = "Please enter a valid email address"
            showError = true
            return false
        }
        
        return true
    }
    
    /// Validate email format
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
} 