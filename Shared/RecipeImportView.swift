import SwiftUI
import UIKit

struct RecipeImportView: View {
    let readPage: () async throws -> RecipePage
    let fromShare: Bool
    let onSave: (SavedRecipe) throws -> Bool
    let onClose: () -> Void

    @State private var page: RecipePage?
    @State private var saved: SavedRecipe?
    @State private var error: LocalizedStringKey?
    @State private var retry = 0
    @State private var settings = false
    @State private var export: ExportedRecipe?
    @State private var exported = false
    @State private var preparedRecipe: Recipe?

    var body: some View {
        Group {
            if let preparedRecipe {
                RecipeScreen(recipe: preparedRecipe, onClose: onClose)
            } else {
                NavigationStack {
                    Group {
                        if let error {
                            ContentUnavailableView {
                                Label("import.failed", systemImage: "exclamationmark.circle")
                            } description: {
                                Text(error)
                            } actions: {
                                Button("import.retry") { retry += 1 }
                                    .buttonStyle(.borderedProminent)
                                Button("settings.title") { settings = true }
                            }
                        } else if let saved {
                            ContentUnavailableView {
                                Label {
                                    Text(verbatim: saved.title)
                                } icon: {
                                    Image(systemName: exported ? "checkmark.circle" : "doc")
                                }
                            } description: {
                                Text(exported ? "import.export.done" : "import.export.help")
                            } actions: {
                                if !exported {
                                    Button("import.export") { prepareExport(saved) }
                                        .buttonStyle(.borderedProminent)
                                }
                                Button("import.preview") { preparedRecipe = Recipe(saved: saved) }
                            }
                        } else {
                            VStack(spacing: 15) {
                                ProgressView().controlSize(.large)
                                Text("import.loading").font(.headline)
                                if let page, let host = page.url.host() {
                                    Text(verbatim: host).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .navigationTitle("import.title")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("action.close", action: onClose)
                        }
                    }
                }
                .preferredColorScheme(.dark)
            }
        }
        .task(id: retry) { await importRecipe() }
        .sheet(isPresented: $settings, onDismiss: {
            if GeminiKey.load() != nil { retry += 1 }
        }) {
            RecipeSettingsSheet()
        }
        .sheet(item: $export, onDismiss: {
            if let saved, exported { preparedRecipe = Recipe(saved: saved) }
        }) { item in
            RecipeExportPicker(url: item.url) { success in
                exported = success
                try? FileManager.default.removeItem(at: item.url.deletingLastPathComponent())
                export = nil
            }
            .interactiveDismissDisabled()
        }
    }

    @MainActor private func importRecipe() async {
        error = nil
        do {
            let recipe: SavedRecipe
            if let saved {
                recipe = saved
            } else {
                let source: RecipePage
                if let page {
                    source = page
                } else {
                    source = try await readPage()
                    page = source
                }
                recipe = try await RecipeImporter.run(page: source)
                try Task.checkCancellation()
                saved = recipe
            }
            do {
                if try onSave(recipe) { preparedRecipe = Recipe(saved: recipe) }
            } catch {
                throw RecipeImportError.storage
            }
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            self.error = switch error as? RecipeImportError {
            case .missingKey: fromShare && RecipeFiles.shared == nil ? "import.error.key.share" : "import.error.key"
            case .invalidKey: "import.error.invalidKey"
            case .quota: "import.error.quota"
            case .noRecipe: "import.error.noRecipe"
            case .invalidResponse: "import.error.response"
            case .storage: "import.error.storage"
            case .service: "import.error.service"
            default: "import.error.page"
            }
        }
    }

    private func prepareExport(_ recipe: SavedRecipe) {
        do {
            let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appending(path: recipe.filename)
            try recipe.encoded().write(to: url, options: .atomic)
            export = ExportedRecipe(url: url)
        } catch {
            self.error = "import.error.storage"
        }
    }

    private struct ExportedRecipe: Identifiable {
        let url: URL
        var id: URL { url }
    }
}

private struct RecipeExportPicker: UIViewControllerRepresentable {
    let url: URL
    let onDismiss: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDismiss: (Bool) -> Void
        init(onDismiss: @escaping (Bool) -> Void) { self.onDismiss = onDismiss }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onDismiss(!urls.isEmpty)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { onDismiss(false) }
    }
}
