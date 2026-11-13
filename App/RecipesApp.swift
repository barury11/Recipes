import SwiftUI

@main
struct RecipesApp: App {
    var body: some Scene {
        WindowGroup {
            RecipeLibrary()
                .preferredColorScheme(.dark)
        }
    }
}

private struct RecipeLibrary: View {
    @State private var showRecipe = true
    private let recipe = Recipe.sample

    var body: some View {
        if showRecipe {
            RecipeScreen(recipe: recipe) { showRecipe = false }
        } else {
            NavigationStack {
                List {
                    Button {
                        showRecipe = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(recipe.image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 54, height: 54)
                                .clipShape(.rect(cornerRadius: 12))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recipe.name)
                                    .font(.headline)
                                Text(recipe.category)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .padding(.vertical, 3)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
                .navigationTitle("app.name")
            }
        }
    }
}
