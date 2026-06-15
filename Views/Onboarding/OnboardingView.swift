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

                    SetupStep4_Gateway(viewModel: $viewModel)
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
            .alert("Setup Error", isPresented: Binding(
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

/// Full-screen overlay shown while generating the workout plan
struct GeneratingOverlay: View {
    @State private var dots = ""
    @State private var dotTimer: Timer?

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Animated dumbbell
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse, options: .repeating)

                VStack(spacing: 8) {
                    Text("Generating Your Workout Plan")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text("AI is building your personalized program\(dots)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .animation(.none, value: dots)
                }

                ProgressView()
                    .tint(.orange)
                    .scaleEffect(1.5)
                    .padding(.top, 8)

                Text("This can take up to a minute")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(40)
        }
        .onAppear {
            dotTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                Task { @MainActor in
                    if dots.count < 3 {
                        dots += "."
                    } else {
                        dots = ""
                    }
                }
            }
        }
        .onDisappear {
            dotTimer?.invalidate()
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

// MARK: - Step 4: Gateway Connection

struct SetupStep4_Gateway: View {
    @Binding var viewModel: OnboardingViewModel
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
                Text("Connect AI")
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 12) {
                    Label("Server Connection", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.headline)

                    Text("Chungus connects to a cloud AI server to generate personalized workout plans backed by fitness research. No API key needed.")
                        .font(.body)
                        .foregroundStyle(.secondary)

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
                        Text("Server is reachable and ready to generate your plan.")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Label("How it works", systemImage: "brain.head.profile")
                        .font(.headline)

                    Text("• Generates your initial workout plan based on your profile")
                    Text("• Backed by evidence-based fitness research (RAG)")
                    Text("• Suggests exercise swaps when needed")
                    Text("• Adapts future workouts based on your performance")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .cardStyle()

                VStack(alignment: .leading, spacing: 6) {
                    Label("Heads up", systemImage: "clock.fill")
                        .font(.headline)
                    Text("After you tap Generate, the AI will take up to a minute to build your personalized workout plan. Grab a coffee! ☕")
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
