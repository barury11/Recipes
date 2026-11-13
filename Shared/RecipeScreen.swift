import SwiftUI
import UIKit

struct RecipeScreen: View {
    let recipe: Recipe
    let onClose: () -> Void

    @State private var sheet: Sheet?
    @State private var checkedIngredients: Set<Recipe.Ingredient.ID> = []
    @State private var ingredientAccent = DishAccent.fallback
    @State private var isCooking = false
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 36

    private enum Sheet: String, Identifiable {
        case ingredients
        case settings

        var id: Self { self }
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if isCooking {
                    CookingScreen(
                        recipe: recipe,
                        onClose: { isCooking = false },
                        onIngredients: { sheet = .ingredients }
                    )
                } else {
                    ViewThatFits(in: .vertical) {
                        recipeLayout

                        ScrollView {
                            recipeLayout.frame(minHeight: geometry.size.height)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                    }
                    .background {
                        backdrop.ignoresSafeArea()
                    }
                    .environment(\.colorScheme, .dark)
                }
            }
            .sheet(item: $sheet) { presented in
                switch presented {
                case .ingredients:
                    IngredientsSheet(recipe: recipe, checked: $checkedIngredients)
                        .presentationDetents([.large])
                        .presentationBackground(Color(uiColor: .systemGroupedBackground))
                case .settings:
                    RecipeSettingsSheet()
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            }
        }
        .preferredColorScheme(isCooking ? .light : .dark)
        .task {
            await updateIngredientAccent()
        }
    }

    private var recipeLayout: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 20)
            footer
        }
        .padding(.horizontal, 17)
        .padding(.top, 9)
        .padding(.bottom, 13)
        .frame(maxHeight: .infinity)
    }

    private func updateIngredientAccent() async {
        ingredientAccent = .fallback
        guard let image = recipe.picture?.cgImage else { return }
        let analysis = Task.detached(priority: .utility) {
            DishAccent.extract(from: image)
        }
        let accent = await withTaskCancellationHandler {
            await analysis.value
        } onCancel: {
            analysis.cancel()
        }
        if !Task.isCancelled, let accent {
            ingredientAccent = accent
        }
    }

    private var backdrop: some View {
        GeometryReader { geometry in
            let photoHeight = geometry.size.height * 0.82

            ZStack(alignment: .top) {
                Color.black

                if let picture = recipe.picture {
                    Image(uiImage: picture)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: photoHeight, alignment: .top)
                        .clipped()
                        .accessibilityHidden(true)
                }

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.48), location: 0),
                        .init(color: .clear, location: 0.20),
                        .init(color: .clear, location: 0.42),
                        .init(color: .black.opacity(0.26), location: 0.57),
                        .init(color: .black.opacity(0.83), location: 0.73),
                        .init(color: .black, location: 0.82)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .accessibilityHidden(true)
    }

    private var header: some View {
        HStack {
            RecipeIconButton("action.close", symbol: "xmark", foreground: .white, action: onClose)
            Spacer()
            RecipeIconButton("settings.title", symbol: "gearshape", foreground: .white) {
                sheet = .settings
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 21) {
            VStack(alignment: .leading, spacing: 7) {
                Text(recipe.name)
                    .font(.system(size: titleSize, weight: .bold))
                    .tracking(-0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 7) {
                        ForEach(recipe.metadata.indices, id: \.self) { index in
                            if index > 0 { Text("·").accessibilityHidden(true) }
                            Text(recipe.metadata[index])
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(recipe.metadata.indices, id: \.self) { index in
                            Text(recipe.metadata[index])
                        }
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.79))
                .accessibilityElement(children: .combine)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 4)

            VStack(spacing: 16) {
                Button {
                    sheet = .ingredients
                } label: {
                    actionLabel(
                        "ingredients.title",
                        symbol: "checklist",
                        foreground: ingredientAccent.labelColor
                    )
                    .background {
                        Capsule()
                            .fill(ingredientAccent.color)
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                }
                .buttonStyle(RecipeButtonStyle())

                Button {
                    isCooking = true
                } label: {
                    actionLabel("cooking.start", symbol: "frying.pan")
                        .background {
                            Capsule()
                                .fill(Color(white: 0.10))
                        }
                        .overlay {
                            Capsule()
                                .strokeBorder(.white.opacity(0.09), lineWidth: 1)
                                .allowsHitTesting(false)
                        }
                }
                .buttonStyle(RecipeButtonStyle())
                .disabled(recipe.steps.isEmpty)
            }
        }
    }

    private func actionLabel(
        _ title: LocalizedStringKey,
        symbol: String,
        foreground: Color = .white
    ) -> some View {
        Label(title, systemImage: symbol)
            .font(.title2.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 82)
            .contentShape(.capsule)
    }
}

struct RecipeIconButton: View {
    static let size: CGFloat = 48

    private let title: LocalizedStringKey
    private let symbol: String
    private let foreground: Color
    private let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    init(
        _ title: LocalizedStringKey,
        symbol: String,
        foreground: Color = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.symbol = symbol
        self.foreground = foreground
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(foreground.opacity(isEnabled ? 1 : 0.35))
                .frame(width: Self.size, height: Self.size)
                .contentShape(.circle)
                .glassEffect(.regular.interactive(isEnabled), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}

private struct RecipeButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.84 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
