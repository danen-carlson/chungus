import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()
    @State private var gatewayTestState: GatewayTestState = .idle
    @State private var showRebuildPlan = false

    enum GatewayTestState: Equatable {
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

                // Workout Plan
                Section("Workout Plan") {
                    Button {
                        showRebuildPlan = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(.orange)
                            Text("Rebuild Workout Plan")
                                .foregroundStyle(.orange)
                        }
                    }
                    Text("Start fresh with a new AI-generated plan based on your updated profile and recent workout history.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Server Connection
                Section("AI Server") {
                    Button {
                        testGateway()
                    } label: {
                        HStack {
                            switch gatewayTestState {
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

                    if case .failure(let message) = gatewayTestState {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    HStack {
                        Text("Server")
                        Spacer()
                        Text("fitness.hankbot.online")
                            .foregroundStyle(.secondary)
                            .font(.caption)
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
            .sheet(isPresented: $showRebuildPlan) {
                RebuildPlanView()
            }
        }
    }

    private func testGateway() {
        gatewayTestState = .testing
        Task {
            do {
                _ = try await GatewayWorkoutService.shared.healthCheck()
                gatewayTestState = .success
            } catch {
                gatewayTestState = .failure(error.localizedDescription)
            }
        }
    }
}
