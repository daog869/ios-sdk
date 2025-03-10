import SwiftUI

struct AMLScreeningView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AMLScreeningViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        Text("AML Screening")
                            .font(.title2.bold())
                            .padding(.horizontal)
                        
                        Text("Please provide the following information to complete your verification. This helps us comply with Anti-Money Laundering (AML) regulations.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        // Form
                        VStack(spacing: 16) {
                            // Date of Birth
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date of Birth")
                                    .font(.headline)
                                
                                DatePicker("", selection: $viewModel.dateOfBirth, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .padding()
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            
                            // Nationality
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Nationality")
                                    .font(.headline)
                                
                                Picker("Select your nationality", selection: $viewModel.nationality) {
                                    ForEach(viewModel.countries, id: \.self) { country in
                                        Text(country).tag(country)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            
                            // Occupation
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Occupation")
                                    .font(.headline)
                                
                                TextField("Your occupation", text: $viewModel.occupation)
                                    .padding()
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            
                            // Source of funds
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Source of Funds")
                                    .font(.headline)
                                
                                Picker("Select primary source of funds", selection: $viewModel.sourceOfFunds) {
                                    ForEach(viewModel.fundingSources, id: \.self) { source in
                                        Text(source).tag(source)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            
                            // Expected monthly transaction volume
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Expected Monthly Transaction Volume")
                                    .font(.headline)
                                
                                Picker("Select expected transaction volume", selection: $viewModel.transactionVolume) {
                                    ForEach(viewModel.volumeRanges, id: \.self) { range in
                                        Text(range).tag(range)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            
                            // PEP status
                            VStack(alignment: .leading, spacing: 8) {
                                Text("PEP Status")
                                    .font(.headline)
                                
                                Text("Are you a Politically Exposed Person (PEP) or related to one?")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                Toggle("I am a PEP or closely related to a PEP", isOn: $viewModel.isPep)
                                    .padding()
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                                
                                if viewModel.isPep {
                                    Text("Please provide details about your PEP status:")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    TextField("PEP details", text: $viewModel.pepDetails)
                                        .padding()
                                        .background(Color(.secondarySystemGroupedBackground))
                                        .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Additional notes
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Additional Notes (Optional)")
                                    .font(.headline)
                                
                                TextEditor(text: $viewModel.additionalNotes)
                                    .frame(minHeight: 100)
                                    .padding(4)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Certification
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Certification")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Toggle("I certify that the information provided is true and accurate to the best of my knowledge", isOn: $viewModel.isCertified)
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                        
                        // Submit button
                        Button(action: submitScreening) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            } else {
                                Text("Submit")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(viewModel.isSubmitEnabled ? Color.blue : Color.gray)
                                    .cornerRadius(10)
                            }
                        }
                        .disabled(!viewModel.isSubmitEnabled || viewModel.isLoading)
                        .padding()
                    }
                    .padding(.vertical)
                }
                
                if viewModel.isLoading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .overlay(
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(1.5)
                                .tint(.white)
                        )
                }
            }
            .navigationTitle("AML Screening")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text(viewModel.alertTitle),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if viewModel.isSuccess {
                            dismiss()
                        }
                    }
                )
            }
        }
    }
    
    private func submitScreening() {
        Task {
            if let userId = AuthorizationManager.shared.currentUser?.id {
                await viewModel.submitScreening(userId: userId)
            }
        }
    }
}

class AMLScreeningViewModel: ObservableObject {
    @Published var dateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @Published var nationality = "Saint Kitts and Nevis"
    @Published var occupation = ""
    @Published var sourceOfFunds = "Employment Income"
    @Published var transactionVolume = "$0 - $1,000"
    @Published var isPep = false
    @Published var pepDetails = ""
    @Published var additionalNotes = ""
    @Published var isCertified = false
    
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var isSuccess = false
    
    let countries = ["Saint Kitts and Nevis", "United States", "Canada", "United Kingdom", "Jamaica", "Barbados", "Antigua and Barbuda", "Other Caribbean", "Other"]
    
    let fundingSources = [
        "Employment Income",
        "Business Income",
        "Savings/Investments",
        "Retirement Funds",
        "Inheritance",
        "Gift",
        "Sale of Property/Assets",
        "Loan",
        "Other"
    ]
    
    let volumeRanges = [
        "$0 - $1,000",
        "$1,001 - $5,000",
        "$5,001 - $10,000",
        "$10,001 - $25,000",
        "$25,001 - $50,000",
        "Over $50,000"
    ]
    
    var isSubmitEnabled: Bool {
        !occupation.isEmpty && isCertified && (!isPep || (isPep && !pepDetails.isEmpty))
    }
    
    func submitScreening(userId: String) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let userData = UserScreeningData(
                fullName: "\(AuthorizationManager.shared.currentUser?.firstName ?? "") \(AuthorizationManager.shared.currentUser?.lastName ?? "")",
                dateOfBirth: dateOfBirth,
                nationality: nationality,
                address: AuthorizationManager.shared.currentUser?.address ?? "No address provided",
                occupation: occupation,
                sourceOfFunds: sourceOfFunds,
                isPep: isPep
            )
            
            try await AMLKYCManager.shared.performAMLScreening(userId: userId, userData: userData)
            
            await MainActor.run {
                isLoading = false
                isSuccess = true
                alertTitle = "Screening Submitted"
                alertMessage = "Your AML screening information has been submitted successfully. We will review your information and update your verification status accordingly."
                showAlert = true
            }
        } catch {
            await MainActor.run {
                isLoading = false
                isSuccess = false
                alertTitle = "Submission Failed"
                alertMessage = "Failed to submit screening: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}

#Preview {
    AMLScreeningView()
} 