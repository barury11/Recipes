import SwiftUI

struct CookingScreen: View {
    let recipe: Recipe
    let onClose: () -> Void
    let onIngredients: () -> Void

    @State private var stepIndex = 0
    @State private var isStartingTimer = false
    @State private var timerConfirmation: UUID?
    @State private var timerError: LocalizedStringKey?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Step \(stepIndex + 1)")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)

                    CookingStepText(step: recipe.steps[stepIndex], onTimer: startTimer)
                }
                .frame(maxWidth: 580, alignment: .leading)
                .padding(.horizontal, 26)
                .padding(.top, 13)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .id(stepIndex)

            HStack {
                RecipeIconButton("ingredients.title", symbol: "checklist", action: onIngredients)
                Spacer(minLength: 12)
                if timerConfirmation != nil {
                    Label("timer.started", systemImage: "timer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .padding(.horizontal, 17)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .alert(
            "timer.error.title",
            isPresented: Binding(
                get: { timerError != nil },
                set: { if !$0 { timerError = nil } }
            )
        ) {
            Button("action.done", role: .cancel) {}
        } message: {
            if let timerError {
                Text(timerError)
            }
        }
        .task(id: timerConfirmation) {
            guard timerConfirmation != nil else { return }
            do {
                try await Task.sleep(for: .seconds(3))
                timerConfirmation = nil
            } catch {}
        }
    }

    private var header: some View {
        ZStack {
            VStack(spacing: 6) {
                Text(recipe.name)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: 5) {
                    ForEach(visibleSteps, id: \.self) { index in
                        Circle()
                            .fill(index == stepIndex ? Color.primary : Color.primary.opacity(0.22))
                            .frame(width: 6, height: 6)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Step \(stepIndex + 1) of \(recipe.steps.count)"))
            }
            .padding(.horizontal, RecipeIconButton.size * 2 + 8)

            HStack {
                RecipeIconButton("cooking.close", symbol: "xmark", action: onClose)
                Spacer()
                HStack(spacing: 3) {
                    RecipeIconButton("cooking.previous", symbol: "chevron.left") {
                        stepIndex = max(0, stepIndex - 1)
                    }
                        .disabled(stepIndex == 0)
                    RecipeIconButton("cooking.next", symbol: "chevron.right") {
                        stepIndex = min(recipe.steps.count - 1, stepIndex + 1)
                    }
                    .disabled(stepIndex == recipe.steps.count - 1)
                }
            }
        }
    }

    private var visibleSteps: Range<Int> {
        let count = recipe.steps.count
        let lower = max(0, min(stepIndex - 3, count - 7))
        return lower..<min(lower + 7, count)
    }

    private func startTimer(seconds: Int) {
        guard !isStartingTimer else { return }
        isStartingTimer = true
        Task {
            defer { isStartingTimer = false }
            do {
                try await CookingTimer.start(seconds: seconds)
                timerConfirmation = UUID()
                AccessibilityNotification.Announcement(String(localized: "timer.started")).post()
            } catch CookingTimer.Error.denied {
                timerError = "timer.error.permission"
            } catch {
                timerError = "timer.error.unavailable"
            }
        }
    }
}
