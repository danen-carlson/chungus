import SwiftUI
import SwiftData

struct RebuildPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = RebuildPlanViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                ProgressView(value: viewModel.progress)
                    .tint(.orange)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Step indicator
                Text("Step \(viewModel.currentStep + 1) of \(viewModel.totalSteps)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                // Content
                TabView(selection: $viewModel.currentStep) {
                    RebuildStep1_Basics(viewModel: $viewModel)
                        .tag(0)

                    RebuildStep2_Training(viewModel: $viewModel)
                        .tag(1)

                    RebuildStep3_Goals(viewModel: $viewModel)
                        .tag(2)

                    RebuildStep4_Gateway(viewModel: $viewModel)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Navigation buttons
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    if viewModel.currentStep < viewModel.totalSteps - 1 {
                        Button("Next") {
                            withAnimation { viewModel.nextStep() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(!viewModel.canProceed)
                    } else {
                        Button {
                            Task {
                                await viewModel.completeRebuild(context: modelContext)
                                if viewModel.generationError == nil {
                                    dismiss()
                                }
                            }
                        } label: {
                            if viewModel.isGenerating {
                                HStack {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Generating...")
                                }
                            } else {
                                Text("Generate New Plan 🏋️")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(!viewModel.canProceed || viewModel.isGenerating)
                    }
                }
                .padding()
            }
            .navigationTitle("Rebuild Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadExistingData(context: modelContext)
            }
            .alert("Rebuild Error", isPresented: Binding(
                get: { viewModel.generationError != nil },
                set: { if !$0 { viewModel.generationError = nil } }
            )) {
                Button("OK") { viewModel.generationError = nil }
            } message: {
                Text(viewModel.generationError ?? "Unknown error")
            }
            .overlay {
                if viewModel.isGenerating {
                    GeneratingOverlay()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: viewModel.isGenerating)
        }
    }
}

// MARK: - Step 1: Basics

struct RebuildStep1_Basics: View {
    @Binding var viewModel: RebuildPlanViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Update your basics")
                    .font(.title2.bold())

                Text("Review and update your current stats. The AI will use this along with your workout history to build your new plan.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Age
                VStack(alignment: .leading) {
                    Text("Age")
                        .font(.headline)
                    Stepper("\(viewModel.age) years", value: $viewModel.age, in: 13...99)
                }

                // Sex
                VStack(alignment: .leading) {
                    Text("Sex")
                        .font(.headline)
                    Picker("Sex", selection: $viewModel.sex) {
                        ForEach(AppConstants.SexOption.allCases) { option in
                            Text(option.rawValue).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Height
                VStack(alignment: .leading) {
                    Text("Height")
                        .font(.headline)
                    HStack {
                        Stepper("\(viewModel.heightFeet) ft", value: $viewModel.heightFeet, in: 3...7)
                        Stepper("\(viewModel.heightInches) in", value: $viewModel.heightInches, in: 0...11)
                    }
                }

                // Weight
                VStack(alignment: .leading) {
                    Text("Weight")
                        .font(.headline)
                    HStack {
                        TextField("Weight", value: $viewModel.weightLbs, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Text("lbs")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Step 2: Training

struct RebuildStep2_Training: View {
    @Binding var viewModel: RebuildPlanViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Training experience")
                    .font(.title2.bold())

                // Years of training
                VStack(alignment: .leading) {
                    Text("Years of training")
                        .font(.headline)
                    Stepper(
                        viewModel.yearsTraining == 0 ? "Beginner" : "\(viewModel.yearsTraining, specifier: "%.1f") years",
                        value: $viewModel.yearsTraining,
                        in: 0...30,
                        step: 0.5
                    )
                }

                // Days available
                VStack(alignment: .leading) {
                    Text("Days per week")
                        .font(.headline)
                    HStack {
                        ForEach(1...7, id: \.self) { day in
                            Button {
                                viewModel.daysAvailable = day
                            } label: {
                                Text("\(day)")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        viewModel.daysAvailable == day ? Color.orange : Color(.systemGray5)
                                    )
                                    .foregroundStyle(viewModel.daysAvailable == day ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }

                // Sports played
                VStack(alignment: .leading) {
                    Text("Sports played (comma-separated)")
                        .font(.headline)
                    TextField("e.g. Hockey, Soccer", text: $viewModel.sportsPlayed)
                        .textFieldStyle(.roundedBorder)
                }

                // Specific exercises
                VStack(alignment: .leading) {
                    Text("Exercises to include (optional)")
                        .font(.headline)
                    TextField("e.g. Deadlift, Pull-ups", text: $viewModel.specificExercises)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding()
        }
    }
}

// MARK: - Step 3: Goals

struct RebuildStep3_Goals: View {
    @Binding var viewModel: RebuildPlanViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Goals & Equipment")
                    .font(.title2.bold())

                // Goal
                VStack(alignment: .leading) {
                    Text("Primary goal")
                        .font(.headline)
                    ForEach(AppConstants.Goal.allCases) { goal in
                        Button {
                            viewModel.goal = goal.rawValue
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(goal.rawValue).fontWeight(.medium)
                                    Text(goal.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if viewModel.goal == goal.rawValue {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.orange)
                                }
                            }
                            .padding()
                            .background(
                                viewModel.goal == goal.rawValue
                                ? Color.orange.opacity(0.1)
                                : Color(.systemGray6)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Equipment access
                VStack(alignment: .leading) {
                    Text("Equipment access")
                        .font(.headline)
                    Picker("Equipment", selection: $viewModel.equipmentAccess) {
                        ForEach(AppConstants.EquipmentAccess.allCases) { eq in
                            Text(eq.rawValue).tag(eq.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Equipment preferences
                VStack(alignment: .leading) {
                    Text("Equipment preferences")
                        .font(.headline)
                    ForEach(AppConstants.EquipmentPreference.allCases) { pref in
                        Toggle(pref.rawValue, isOn: Binding(
                            get: { viewModel.equipmentPreference.contains(pref.rawValue) },
                            set: { isOn in
                                if isOn {
                                    viewModel.equipmentPreference.insert(pref.rawValue)
                                } else {
                                    viewModel.equipmentPreference.remove(pref.rawValue)
                                }
                            }
                        ))
                    }
                }

                // Additional notes
                VStack(alignment: .leading) {
                    Text("Anything else? (injuries, limitations)")
                        .font(.headline)
                    TextEditor(text: $viewModel.additionalNotes)
                        .frame(minHeight: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4))
                        )
                }
            }
            .padding()
        }
    }
}

// MARK: - Step 4: Gateway Connection & History Preview

struct RebuildStep4_Gateway: View {
    @Binding var viewModel: RebuildPlanViewModel
    @State private var testState: GatewayTestState = .idle

    enum GatewayTestState: Equatable {
        case idle
        case testing
        case success
        case failure(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Review & Connect")
                    .font(.title2.bold())

                // History Preview
                VStack(alignment: .leading, spacing: 8) {
                    Label("Recent Weight History", systemImage: "chart.bar.fill")
                        .font(.headline)

                    Text("The AI will use these recent weights as a baseline for your new plan:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(viewModel.historySummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .cardStyle()

                // Server Connection
                VStack(alignment: .leading, spacing: 12) {
                    Label("Server Connection", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.headline)

                    Button {
                        testGateway()
                    } label: {
                        HStack(spacing: 6) {
                            switch testState {
                            case .idle:
                                Image(systemName: "bolt.horizontal.circle")
                                Text("Test Connection")
                            case .testing:
                                ProgressView()
                                    .tint(.white)
                                Text("Connecting...")
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                Text("Connected!")
                            case .failure:
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("Retry")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(testButtonColor)
                    .disabled(testState == .testing)

                    if case .failure(let message) = testState {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if case .success = testState {
                        Text("Server is reachable and ready to generate your new plan.")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: 6) {
                    Label("What happens next", systemImage: "info.circle.fill")
                        .font(.headline)
                    Text("• Your old workout plan will be deleted")
                    Text("• Your updated profile will be saved")
                    Text("• A brand new plan will be generated using your history")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .cardStyle()
            }
            .padding()
        }
    }

    private var testButtonColor: Color {
        switch testState {
        case .idle: return .blue
        case .testing: return .gray
        case .success: return .green
        case .failure: return .red
        }
    }

    private func testGateway() {
        testState = .testing
        Task {
            do {
                _ = try await GatewayWorkoutService.shared.healthCheck()
                testState = .success
                viewModel.gatewayConnected = true
            } catch {
                testState = .failure(error.localizedDescription)
            }
        }
    }
}
