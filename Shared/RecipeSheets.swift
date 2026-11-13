import SwiftUI
import UIKit

struct IngredientsSheet: View {
    let recipe: Recipe
    @Binding var checked: Set<Recipe.Ingredient.ID>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(recipe.ingredients) { ingredient in
                let isChecked = checked.contains(ingredient.id)

                Button {
                    if isChecked {
                        checked.remove(ingredient.id)
                    } else {
                        checked.insert(ingredient.id)
                    }
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isChecked ? Color.orange : Color.secondary)
                            .accessibilityHidden(true)
                        Text(ingredient.text)
                            .foregroundStyle(isChecked ? Color.secondary : Color.primary)
                            .strikethrough(isChecked)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 7)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isChecked ? .isSelected : [])
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("ingredients.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }
                }
            }
        }
    }
}

enum AIProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case google = "Google Gemini"
    case custom = "settings.provider.custom"

    var id: Self { self }
}

private enum RecipeAppearance: String {
    case classic
    case smart
}

struct RecipeSettingsSheet: View {
    @AppStorage("recipeAppearance") private var appearance: RecipeAppearance = .classic
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = GeminiKey.load() ?? ""
    @State private var keyError: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("settings.appearance", selection: $appearance) {
                        Text("settings.appearance.classic").tag(RecipeAppearance.classic)
                        Text("settings.appearance.smart").tag(RecipeAppearance.smart)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("settings.appearance")
                } footer: {
                    if appearance == .smart { Text("settings.appearance.smart.preview") }
                }

                Section("settings.provider") {
                    Label("Google Gemini", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.primary)
                    ForEach([AIProvider.openAI, .anthropic, .custom]) { provider in
                        Text(LocalizedStringKey(provider.rawValue))
                            .foregroundStyle(.tertiary)
                            .accessibilityHint(Text("settings.provider.unavailable"))
                    }
                }

                Section {
                    SecureField("settings.key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    LabeledContent("settings.model") { Text("Gemini 3.5 Flash-Lite") }
                } footer: {
                    Text("settings.gemini.help")
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") {
                        do {
                            try GeminiKey.save(apiKey)
                            dismiss()
                        } catch GeminiKey.Failure.invalid {
                            keyError = "import.error.invalidKey"
                        } catch {
                            keyError = "settings.key.error"
                        }
                    }
                }
            }
            .alert("import.failed", isPresented: Binding(
                get: { keyError != nil },
                set: { if !$0 { keyError = nil } }
            )) {
                Button("action.done", role: .cancel) {}
            } message: {
                if let keyError { Text(keyError) }
            }
        }
    }
}
