import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()
    @State private var testState: KeyTestState = .idle

    enum KeyTestState: Equatable {
        case idle
        case testing
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Profile section
                Section("Profile") {
                    Stepper("Age: \(viewModel.editAge)", value: $viewModel.editAge, in: 13...99)

                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("lbs", value: $viewModel.editWeightLbs, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("lbs")
                            .foregroundStyle(.secondary)
                    }

                    Stepper("Days/week: \(viewModel.editDaysAvailable)", value: $viewModel.editDaysAvailable, in: 1...7)

                    Picker("Goal", selection: $viewModel.editGoal) {
                        ForEach(AppConstants.Goal.allCases) { goal in
                            Text(goal.rawValue).tag(goal.rawValue)
                        }
                    }

                    Picker("Equipment", selection: $viewModel.editEquipmentAccess) {
                        ForEach(AppConstants.EquipmentAccess.allCases) { eq in
                            Text(eq.rawValue).tag(eq.rawValue)
                        }
                    }
                }

                // Notes
                Section("Notes") {
                    TextEditor(text: $viewModel.editAdditionalNotes)
                        .frame(minHeight: 60)
                }

                // API Key
                Section("Gemini API") {
                    HStack {
                        Text("API Key")
                        Spacer()
                        Text(viewModel.apiKeyMasked)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    SecureField("New API key", text: $viewModel.newAPIKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    HStack {
                        Button("Update Key") {
                            viewModel.saveAPIKey()
                            testState = .idle
                        }
                        .disabled(viewModel.newAPIKey.trimmingCharacters(in: .whitespaces).isEmpty)

                        Spacer()

                        Button("Remove", role: .destructive) {
                            viewModel.deleteAPIKey()
                            testState = .idle
                        }
                    }

                    // Test connection
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            switch testState {
                            case .idle:
                                Image(systemName: "dot.radiowaves.left.and.right")
                                Text("Test Connection")
                            case .testing:
                                ProgressView()
                                Text("Testing...")
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                Text("Connection Successful")
                                    .foregroundStyle(.green)
                            case .failure:
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("Connection Failed — Retry")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .disabled(testState == .testing || !KeychainService.hasGeminiKey)

                    if case .failure(let message) = testState {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Save
                Section {
                    Button {
                        viewModel.saveProfile(context: modelContext)
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isSaving {
                                ProgressView()
                            } else {
                                Text("Save Profile")
                            }
                            Spacer()
                        }
                    }
                    .tint(.orange)
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(AppConstants.appVersion)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                viewModel.loadProfile(context: modelContext)
            }
            .alert("Saved", isPresented: .constant(viewModel.saveMessage != nil)) {
                Button("OK") { viewModel.saveMessage = nil }
            } message: {
                Text(viewModel.saveMessage ?? "")
            }
        }
    }

    private func testConnection() {
        guard let key = KeychainService.geminiAPIKey else { return }
        testState = .testing
        Task {
            do {
                _ = try await GeminiService.shared.testConnection(apiKey: key)
                testState = .success
            } catch {
                testState = .failure(error.localizedDescription)
            }
        }
    }
}
