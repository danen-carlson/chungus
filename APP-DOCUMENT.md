# Chungus — App Architecture Document

## Overview

**Name:** Chungus  
**Purpose:** AI-powered workout app for building muscle. Generates personalized workout plans, suggests starting weights/sets/reps, and adapts over time based on user performance.  
**Platform:** iOS (Xcode, SwiftUI) + Apple Watch (WatchKit)  
**AI Engine:** Google Gemini (user-provided API key)  
**Data:** Stored on-device (SwiftData) + HealthKit integration  
**Target Market:** United States (v1) — Defaults to Lbs for weight, Feet/Inches for height.  

---

## Setup Questionnaire (Onboarding)

Fields collected during first launch:

| Field | Type | Notes |
|-------|------|-------|
| Age | Number | |
| Sex/Gender | Selection | Male, Female, Prefer not to say |
| Height | Measurement | Feet/Inches (US default) |
| Weight | Measurement | Lbs (US default) |
| Time constraint | Duration | Default: none. If set, workouts must fit within this (e.g. under 60 min) |
| Days available | 1–7 | Number of workout days per week |
| Sports played | Multi-select / text | Ongoing sports that affect recovery/fatigue |
| Years of training | Number | 0 = beginner, helps set starting weights |
| Specific workouts to add | Text / multi-select | User-requested exercises to include |
| Goal | Selection | Hypertrophy, Strength, Endurance, Mixed, Athletic Performance |
| Equipment Access | Selection | Full Gym, No Equipment, Home Gym, Specific Equipment (text field) |
| Equipment Preference | Multi-select | Free weights, Machines, Cable machines |
| Anything else | Free text | Catch-all for injuries, specific limitations |

### ❓ Remaining Onboarding Questions

1. **Injury history** — Should this be a structured field (body part + severity) within "Anything else" so the AI explicitly avoids problematic exercises?
2. **Re-onboarding** — Can the user redo setup later if their situation changes? (e.g. injury, new gym, schedule change)

---

## Workout Plan Generation

### Split Strategy

**Decision:** The AI decides the split by default to give the best results based on the user's profile, goals, and available days. The user can specifically request a different split, but the AI default is preferred.

Example 4-day split: Legs, Push, Pull, Accessory/Sports-specific.

### AI Generation & Regeneration Flow (Dynamic)

The AI rebuilds the *next* workout of a specific type *after* the current one is completed.

```
1. Initial Setup:
   User Profile → Gemini API → Generates initial WorkoutPlan (e.g., 4 workouts: Legs, Push, Pull, Accessory)
   ↓
2. User completes a workout (e.g., Legs):
   App records: weights, reps, sets, and notes ("too easy", "too hard")
   ↓
3. AI Regeneration Trigger:
   App sends completed Legs workout data + User Profile to Gemini
   ↓
4. Gemini generates the *next* Legs workout:
   Adjusts weights, reps, sets, or exercises based on performance and notes.
   ↓
5. App slots the new Legs workout into the queue (after the remaining 3 workouts).
```

### ❓ Remaining Plan Questions

7. **Deload weeks** — Should the app schedule deload weeks (reduced volume/intensity) periodically? Standard is every 4th week. (AI can handle this if prompted).
8. **Exercise variety** — Should the AI rotate exercises over time to prevent staleness? (Likely yes, handled by the regeneration prompt).

---

## Data Models

### User Profile
```swift
struct UserProfile {
    var age: Int
    var sex: String?             // "Male", "Female", "Prefer not to say"
    var heightFeet: Int          // US default
    var heightInches: Int        // US default
    var weightLbs: Double        // US default
    var timeConstraintMin: Int?  // nil = no limit
    var daysAvailable: Int       // 1-7
    var sportsPlayed: [String]
    var yearsTraining: Double
    var specificExercises: [String]
    var goal: String             // Hypertrophy, Strength, Endurance, Mixed, Athletic
    var equipmentAccess: String  // Full Gym, No Equipment, Home Gym, Specific
    var equipmentPreference: [String] // Free weights, Machines, Cable machines
    var additionalNotes: String
}
```

### Workout Plan
```swift
struct WorkoutPlan {
    var id: UUID
    var createdAt: Date
    var splitType: String        // "PPL", "Upper/Lower", "Full Body"
    var workouts: [WorkoutTemplate]
    var weekNumber: Int          // for multi-week programs
}
```

### Workout Template (the plan)
```swift
struct WorkoutTemplate {
    var id: UUID
    var name: String             // "Push Day", "Leg Day"
    var targetMuscles: [String]  // ["chest", "shoulders", "triceps"]
    var exercises: [ExerciseTemplate]
    var estimatedDurationMin: Int
}
```

### Exercise Template (within a plan)
```swift
struct ExerciseTemplate {
    var id: UUID
    var name: String             // "Barbell Bench Press"
    var muscleGroup: String      // "chest"
    var sets: Int
    var reps: Int                // or range "8-12"
    var targetWeight: Double?    // nil for first workout (user fills in)
    var restSeconds: Int         // Confirmed: Rest timer between sets (e.g., 90s)
    var tips: String?            // AI-generated tips/thoughts to keep in mind for this exercise
    var imageUrl: String?        // URL to a static image demonstrating the exercise (Nice to have)
    var alternatives: [String]?  // pre-computed swap options, or generate on demand
}
```

### Workout Session (actual completed workout)
```swift
struct WorkoutSession {
    var id: UUID
    var templateId: UUID         // links back to the template
    var startedAt: Date
    var completedAt: Date?
    var exercises: [ExerciseSession]
    var overallNotes: String?
}
```

### Exercise Session (actual performed exercise)
```swift
struct ExerciseSession {
    var id: UUID
    var templateExerciseId: UUID
    var name: String
    var sets: [SetRecord]
    var notes: String?           // "too easy", "too hard", "shoulder felt weird"
    var wasSwapped: Bool         // was this swapped from the original?
    var originalExerciseName: String?
}
```

### Set Record
```swift
struct SetRecord {
    var id: UUID
    var setNumber: Int
    var weightLbs: Double?       // nil = bodyweight or not recorded
    var reps: Int
    var completed: Bool          // can mark as not done
    var isWarmup: Bool           // ❓ track warm-up sets separately?
    var isDropSet: Bool          // ❓ support drop sets / supersets?
}
```

### ❓ Remaining Data Questions

12. **Rep ranges vs fixed reps** — Should the AI give "3×10" or "3×8-12"? If a range, how does the user record? Actual reps done?
13. **Warm-up sets** — Should warm-up sets be part of the plan, or user-added only?
14. **Drop sets / supersets / giant sets** — Support these advanced techniques?
15. **Cardio** — Is this purely a lifting app, or should cardio sessions be tracked too?

---

## Screens & Navigation

### Screen Flow

```
┌─────────────┐
│  Onboarding  │ (first launch only)
│  (multi-step)│
└──────┬──────┘
       ↓
┌─────────────┐
│  Dashboard   │ ← main screen after setup
│  (upcoming   │
│   workouts)  │
└──────┬──────┘
       ↓
┌─────────────┐
│  Workout     │ ← shows all exercises for this workout
│  Detail      │
└──────┬──────┘
       ↓
┌─────────────┐
│  Exercise    │ ← active tracking: sets, reps, weights, notes, tips
│  Execution   │
└──────┬──────┘
       ↓
┌─────────────┐
│  Workout     │ ← summary after completing all exercises
│  Summary     │
└──────┘──────┘

Also accessible:
┌─────────────┐
│  History     │ ← past completed workouts
└─────────────┘
┌─────────────┐
│  Settings    │ ← edit profile, API key, preferences
└─────────────┘
```

### Dashboard Screen

- Shows the next X workouts where X = number needed to complete a full body cycle
- Each workout card shows: name, target muscles, exercise count, estimated duration
- Tapping a workout → Workout Detail
- ❓ Should it show the full week view (Mon: Push, Tue: Pull, etc.) or just the next workout?
- ❓ Should there be a "rest day" indicator between workout days?

### Workout Detail Screen

- Lists all exercises in the workout
- Each exercise shows: name, sets × reps, target weight (if available)
- **Swap button** on each exercise → calls Gemini to suggest an alternative
- **Start Workout** button → navigates to first Exercise Execution
- ❓ Should the user be able to reorder exercises (drag to rearrange)?
- ❓ Can the user add extra exercises not in the plan?

### Exercise Execution Screen

This is the core of the app. For each exercise:

- Exercise name and target (e.g. "Barbell Bench Press — 4×8-10")
- **Exercise Image** — Static image demonstrating the exercise (Nice to have)
- **Exercise Tips** — AI-generated tips/thoughts to keep in mind for this specific exercise
- Set-by-set tracking table:
  | Set | Weight (lbs) | Reps | ✓ Done |
  |-----|--------------|------|--------|
  | 1   | 135          | 10   | ✅     |
  | 2   | 135          | 8    | ✅     |
  | 3   | 135          | —    | ❌ (skipped) |
  | 4   | —            | —    | (up next) |
- **First workout:** Weight column is blank, user types in what they used
- **Subsequent workouts:** Weight pre-filled from previous session, user can adjust
- **Mark set as not done** — toggle ✓/❌
- **Add set** — button to add an extra set
- **Notes field** — per-exercise notes ("too easy", "too hard", "left knee bother")
- **Swap exercise** — button to AI-swap this exercise mid-workout
- **Navigation:**
  - **Next →** — moves to next exercise
  - **← Back** — go back to previous exercise (for accidental "next")
  - Jump-to-exercise list (tap any exercise name to go directly) — *Recommended*

### ❓ Remaining Screen Questions

17. **Rest timer** — Confirmed: Starts automatically when a set is marked done, but user can pause/restart.
18. **Exercise images** — Built-in local database of exercise images, or fetched via external API?
19. **Workout timer** — Total elapsed time for the workout session? *(Recommended: Yes)*
20. **Music/audio** — Any integration, or leave that to Apple Music/Spotify?
21. **Lock screen / background** — Should the workout stay active with screen off? Live Activity on lock screen? *(Recommended: Yes, Live Activity is great for workouts)*

---

## Exercise Swap (AI)

When the user taps "Swap Exercise":

```
Current exercise + user profile + workout context
    ↓
Gemini API call:
  "Suggest an alternative to [Barbell Bench Press] targeting [chest]
   for a [30yo male, 2 years experience] doing a [Push day].
   Maintain similar difficulty. Return: exercise name, sets, reps, 
   target weight (if available from context), and brief form cue."
    ↓
Display suggestion with Accept / Try Another / Cancel
    ↓
Accept → replaces exercise in current workout
```

### ❓ Unanswered Swap Questions

22. **Swap scope** — Should swaps be within the same muscle group only, or allow cross-category? (e.g. swap a chest exercise for a different chest exercise only)
23. **Swap history** — Remember that the user doesn't like certain exercises so they don't get suggested again?
24. **Equipment-aware swaps** — If the user said "dumbbells only" in setup, swaps must respect that
25. **Multiple suggestions** — Show 1 alternative or give a choice of 2-3?

---

## Weight Progression

### How it works:
1. **First workout** — All weight fields blank. User enters what they actually lifted.
2. **Next workout** — Weights pre-filled from previous session for same exercises.
3. **AI adaptation** — On plan regeneration or exercise swap, Gemini uses historical performance to suggest appropriate weights.

### ❓ Remaining Progression Questions

26. **Plateau detection** — If the user hasn't increased weight in 3+ sessions on an exercise, flag it? (AI can handle this during regeneration).
27. **1RM estimation** — Calculate estimated one-rep max from working sets? (Epley formula: weight × (1 + reps/30))
28. **Weight granularity** — What increments? 2.5 lbs? 5 lbs? User-configurable?

---

## History & Persistence

### What's stored on-device:
- User profile
- All generated workout plans
- All completed workout sessions (with full set-by-set data)
- Exercise swap history
- User notes

### ❓ Remaining History Questions

31. **iCloud sync** — Sync workout history across devices via CloudKit?
32. **Export** — Export workout history as CSV/JSON/PDF?
33. **HealthKit integration** — Confirmed: Yes. Write completed workouts to Apple Health (Shows up in Fitness app, contributes to activity rings).
34. **Stats/Charts** — Progress charts over time? (e.g. bench press weight over 12 weeks, total volume per week) *(Recommended: Yes, nice to have)*

---

## Gemini API Integration

### API Key Management
- User provides their own Gemini API key
- ❓ Where to store it? **Keychain** (secure) vs **UserDefaults** (simple, not secure) vs **in-app Settings screen**
- Recommendation: **Keychain** — even though it's the user's own key, storing API keys in UserDefaults is visible in backups

### API Call Patterns

| Trigger | Prompt Purpose |
|---------|---------------|
| After onboarding | Generate initial workout plan |
| Exercise swap | Suggest alternative exercise |
| Plan regeneration | Create new plan based on progress |
| ❓ Weight suggestion | Suggest weights for next workout |
| ❓ Form check | Answer questions about exercise form |

### Error Handling
- ❓ What happens when API calls fail? (no internet, rate limited, key expired)
- Recommendation: Cache the last generated plan. Show error + retry button. Never block the workout flow — user should always be able to complete a workout even if AI is unreachable.
- ❓ **Offline fallback** — If Gemini is down, should the app have a basic exercise database to pull swaps from?

### ❓ Remaining API Questions

36. **Gemini model** — `gemini-2.5-flash` (fast, cheap) is recommended for workout generation and swaps.
37. **Rate limiting** — Any concern about how many API calls per workout? (Each swap = 1 call, each post-workout regen = 1 call)
38. **Structured output** — Use Gemini's JSON mode for reliable parsing. *(Recommended: Yes)*
39. **Context window** — Send the last 2-3 sessions of the specific workout type + user profile for regeneration.
40. **Cost awareness** — Flash model is very cheap, but should the app show API usage/cost to the user?

---

## ❓ Remaining General Questions

41. **Apple Watch** — Confirmed: Yes, companion app for tracking sets during workouts (highly valuable since phone might be in a locker).
42. **Notifications** — Workout reminders? ("It's Push Day! 💪")
43. **App Icon** — Design direction? (The name "Chungus" has meme energy — lean into it or go clean/professional?)
44. **Accessibility** — VoiceOver support, Dynamic Type, dark mode?
45. **Localization** — English only (US v1), or multi-language?
46. **Testing** — Unit tests? UI tests? TestFlight for beta?
47. **Analytics** — Any usage tracking, or fully private?
*(Note: Monetization and iPad support are explicitly out of scope for v1).*

---

## Recommended Tech Stack

| Layer | Choice | Why |
|-------|--------|-----|
| UI (iOS) | SwiftUI | Modern, declarative, less code |
| UI (Watch) | WatchKit / SwiftUI | Native Apple Watch support |
| Persistence | SwiftData | Confirmed: iOS 17+ native, integrates with SwiftUI |
| Networking | URLSession + async/await | Native, no dependencies |
| AI | Gemini API (REST) | User-provided key |
| Key storage | Keychain | Secure API key storage |
| Architecture | MVVM | Standard for SwiftUI |
| Health | HealthKit | Confirmed: Write workouts to Apple Health |
| ❓ Charts | Swift Charts | Native iOS 16+ charting |

---

## Project Structure (Proposed)

```
Chungus/
├── ChungusApp.swift              # App entry point
├── Models/
│   ├── UserProfile.swift
│   ├── WorkoutPlan.swift
│   ├── WorkoutTemplate.swift
│   ├── ExerciseTemplate.swift
│   ├── WorkoutSession.swift
│   ├── ExerciseSession.swift
│   └── SetRecord.swift
├── Views/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   ├── SetupStep1_Basics.swift
│   │   ├── SetupStep2_Training.swift
│   │   └── SetupStep3_Goals.swift
│   ├── Dashboard/
│   │   └── DashboardView.swift
│   ├── Workout/
│   │   ├── WorkoutDetailView.swift
│   │   ├── ExerciseExecutionView.swift
│   │   ├── SetTrackingView.swift
│   │   └── WorkoutSummaryView.swift
│   ├── History/
│   │   └── HistoryView.swift
│   └── Settings/
│       └── SettingsView.swift
├── WatchApp/                     # Apple Watch Companion
│   ├── WatchApp.swift
│   ├── Views/
│   │   └── ActiveWorkoutView.swift
│   └── ViewModels/
│       └── WatchWorkoutViewModel.swift
├── ViewModels/
│   ├── OnboardingViewModel.swift
│   ├── DashboardViewModel.swift
│   ├── WorkoutViewModel.swift
│   └── SettingsViewModel.swift
├── Services/
│   ├── GeminiService.swift       # API calls to Gemini
│   ├── WorkoutGenerator.swift    # Plan generation logic
│   ├── WeightProgression.swift   # Weight suggestion logic
│   ├── HealthKitService.swift    # Confirmed: Apple Health integration
│   └── KeychainService.swift     # Secure API key storage
├── Utilities/
│   ├── Constants.swift
│   └── Extensions.swift
└── Resources/
    ├── Assets.xcassets
    └── ExerciseImages/           # Local exercise images (or fetched via API)
```

---

## Priority Build Order

1. **Xcode project setup** — SwiftUI app, SwiftData, folder structure, Watch app target
2. **Data models** — All the structs above, SwiftData @Model classes
3. **Onboarding flow** — Collect user info, save profile
4. **Gemini service** — API integration, plan generation
5. **Dashboard** — Show upcoming workouts
6. **Workout Detail** — Exercise list with swap button
7. **Exercise Execution** — Set tracking, weight entry, notes, next/back navigation, rest timer
8. **Workout History** — Past sessions, browse and review
9. **Weight progression** — Pre-fill weights from previous sessions
10. **Apple Watch Companion** — Sync active workout, basic set tracking
11. **HealthKit Integration** — Write completed workouts to Apple Health
12. **Settings** — Edit profile, manage API key
13. **Polish** — Charts, notifications, exercise images

---

*Document updated: 2026-06-11*  
*Status: Draft — awaiting answers to remaining ❓ questions*