import SwiftUI
import UIKit

@main
struct RecipesApp: App {
    var body: some Scene {
        WindowGroup {
            RecipeLibrary()
        }
    }
}

private struct RecipeLibrary: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var recipes: [SavedRecipe] = []
    @State private var selection: RecipeSelection?
    @State private var settings = false
    @State private var pasteLink = false
    @State private var link = ""
    @State private var importURL: ImportURL?
    @State private var importFailure = false
    @State private var storageFailure = false

    var body: some View {
        Group {
            if let selection {
                RecipeScreen(recipe: selection.recipe) { self.selection = nil }
                    .id(selection.id)
            } else {
                NavigationStack {
                    List {
                        if recipes.isEmpty {
                            Section {
                                Button {
                                    selection = .sample
                                } label: {
                                    Label("library.sample", systemImage: "book")
                                }
                            } footer: {
                                Text("library.safari.hint")
                            }
                        }
                        ForEach(recipes) { recipe in
                            Button {
                                selection = RecipeSelection(id: recipe.id, recipe: Recipe(saved: recipe))
                            } label: {
                                HStack(spacing: 14) {
                                    if let data = recipe.photo, let image = UIImage(data: data) {
                                        Image(uiImage: image).resizable().scaledToFill()
                                            .frame(width: 48, height: 48)
                                            .clipShape(.rect(cornerRadius: 10))
                                            .accessibilityHidden(true)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(verbatim: recipe.title)
                                        if let host = recipe.sourceURL.host() {
                                            Text(verbatim: host).font(.footnote).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .navigationTitle("app.name")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("library.addLink", systemImage: "plus") { pasteLink = true }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("settings.title", systemImage: "gearshape") { settings = true }
                        }
                    }
                }
                .preferredColorScheme(.dark)
            }
        }
        .task { refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
        .sheet(isPresented: $settings) { RecipeSettingsSheet().preferredColorScheme(.dark) }
        .sheet(item: $importURL, onDismiss: { refresh() }) { item in
            RecipeImportView(
                readPage: { try await RecipePage.fetch(item.url) },
                fromShare: false,
                onSave: { recipe in
                    try RecipeFiles.save(recipe)
                    return true
                },
                onClose: { importURL = nil }
            )
        }
        .alert("library.addLink", isPresented: $pasteLink) {
            TextField("library.link", text: $link).textInputAutocapitalization(.never)
                .keyboardType(.URL).autocorrectionDisabled()
            Button("import.title") {
                if let url = RecipePage.webURL(link.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    importURL = ImportURL(url: url)
                    link = ""
                } else {
                    importFailure = true
                }
            }
            Button("action.cancel", role: .cancel) {}
        }
        .alert("import.failed", isPresented: $importFailure) {
            Button("action.done", role: .cancel) {}
        } message: {
            Text("import.error.link")
        }
        .alert("import.failed", isPresented: $storageFailure) {
            Button("action.done", role: .cancel) {}
        } message: {
            Text("import.error.storage")
        }
    }

    private func refresh() {
        do { recipes = try RecipeFiles.load() }
        catch { storageFailure = true }
    }

    private struct RecipeSelection {
        let id: String
        let recipe: Recipe
        static let sample = Self(id: "sample", recipe: .sample)
    }

    private struct ImportURL: Identifiable {
        let url: URL
        var id: URL { url }
    }
}
