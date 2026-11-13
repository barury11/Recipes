import SwiftUI

struct RecipeScreen: View {
    let recipe: Recipe
    let onClose: () -> Void

    @State private var sheet: Sheet?
    @State private var checkedIngredients: Set<Recipe.Ingredient.ID> = []
    @State private var selectedProvider: AIProvider = .openAI
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 36

    private enum Sheet: String, Identifiable {
        case ingredients
        case settings

        var id: Self { self }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 68)
                    footer
                }
                .padding(.horizontal, 17)
                .padding(.top, 9)
                .padding(.bottom, 13)
                .frame(minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .background {
            backdrop.ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .sheet(item: $sheet) { presented in
            switch presented {
            case .ingredients:
                IngredientsSheet(recipe: recipe, checked: $checkedIngredients)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            case .settings:
                AISettingsSheet(provider: $selectedProvider)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var backdrop: some View {
        GeometryReader { geometry in
            let photoHeight = geometry.size.height * 0.82

            ZStack(alignment: .top) {
                Color.black

                Image(recipe.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: photoHeight, alignment: .top)
                    .clipped()
                    .accessibilityHidden(true)

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
            roundButton("action.close", symbol: "xmark", action: onClose)
            Spacer()
            roundButton("settings.title", symbol: "gearshape") {
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
                        Text(recipe.category)
                        Text("·").accessibilityHidden(true)
                        Text(recipe.time)
                        Text("·").accessibilityHidden(true)
                        Text(recipe.servings)
                    }
                    .fixedSize(horizontal: true, vertical: false)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.category)
                        Text(recipe.time)
                        Text(recipe.servings)
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
                    actionLabel("ingredients.title", symbol: "checklist")
                        .background {
                            Capsule()
                                .fill(Color(red: 1, green: 0.58, blue: 0.20))
                        }
                        .overlay {
                            Capsule()
                                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                                .allowsHitTesting(false)
                        }
                }
                .buttonStyle(RecipeButtonStyle())

                Button(action: {}) {
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
                .accessibilityHint(Text("cooking.preview.hint"))
            }
        }
    }

    private func roundButton(
        _ title: LocalizedStringKey,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .contentShape(.circle)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }

    private func actionLabel(_ title: LocalizedStringKey, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.title2.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 82)
            .contentShape(.capsule)
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
