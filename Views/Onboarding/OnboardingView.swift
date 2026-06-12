import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = OnboardingViewModel()

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
                    SetupStep1_Basics(viewModel: $viewModel)
                        .tag(0)

                    SetupStep2_Training(viewModel: $viewModel)
                        .tag(1)

                    SetupStep3_Goals(viewModel: $viewModel)
                        .tag(2)

                    SetupStep4_APIKey(viewModel: $viewModel)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Navigation buttons
                HStack {
                    if viewModel.currentStep > 0 {
                        Button("Back") {
                            withAnimation { viewModel.previousStep() }
                        }
                        .buttonStyle(.bordered)
                    }

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
                                await viewModel.completeSetup(context: modelContext)
                            }
                        } label: {
                            if viewModel.isGenerating {
                                HStack {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Generating Plan...")
                                }
                            } else {
                                Text("Generate My Plan 🏋️")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(!viewModel.canProceed || viewModel.isGenerating)
                    }
                }
                .padding()
            }
            .navigationTitle("Welcome to Chungus")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Setup Error", isPresented: .constant(viewModel.generationError != nil)) {
                Button("OK") { viewModel.generationError = nil }
            } message: {
                Text(viewModel.generationError ?? "")
            }
        }
    }
}

// MARK: - Step 1: Basics

struct SetupStep1_Basics: View {
    @Binding var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Tell us about yourself")
                    .font(.title2.bold())

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

struct SetupStep2_Training: View {
    @Binding var viewModel: OnboardingViewModel

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

struct SetupStep3_Goals: View {
    @Binding var viewModel: OnboardingViewModel

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

// MARK: - Step 4: API Key

struct SetupStep4_APIKey: View {
    @Binding var viewModel: OnboardingViewModel
    @State private var testState: KeyTestState = .idle

    enum KeyTestState: Equatable {
        case idle
        case testing
        case success
        case failure(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Connect AI")
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 12) {
                    Label("Gemini API Key", systemImage: "key.fill")
                        .font(.headline)

                    Text("Chungus uses Google Gemini to generate personalized workout plans. You'll need a free API key.")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    SecureField("Paste your Gemini API key", text: $viewModel.geminiAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    HStack {
                        Button {
                            testKey()
                        } label: {
                            HStack(spacing: 6) {
                                switch testState {
                                case .idle:
                                    Image(systemName: "bolt.horizontal.circle")
                                    Text("Test Key")
                                case .testing:
                                    ProgressView()
                                        .tint(.white)
                                    Text("Testing...")
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
                        .disabled(viewModel.geminiAPIKey.trimmingCharacters(in: .whitespaces).isEmpty || testState == .testing)

                        if case .success = testState {
                            // Success state already shown in button
                        }
                    }

                    if case .failure(let message) = testState {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if case .success = testState {
                        Text("API key is valid and ready to go.")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    Link("Get a free API key →", destination: URL(string: "https://aistudio.google.com/apikey")!)
                        .font(.subheadline)
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Label("How it works", systemImage: "brain.head.profile")
                        .font(.headline)

                    Text("• Generates your initial workout plan based on your profile")
                    Text("• Suggests exercise swaps when needed")
                    Text("• Adapts future workouts based on your performance")
                    Text("• Your key is stored securely in Keychain")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .cardStyle()
            }
            .padding()
        }
        .onChange(of: viewModel.geminiAPIKey) { _, _ in
            testState = .idle
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

    private func testKey() {
        let key = viewModel.geminiAPIKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }

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
