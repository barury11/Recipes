import CryptoKit
import Foundation

struct SavedRecipe: Codable, Identifiable {
    let title: String
    let category: String?
    let prepMinutes: Int?
    let totalMinutes: Int?
    let servings: String?
    let ingredients: [String]
    let steps: [CookingStep]
    let sourceURL: URL
    let photo: Data?
    let importedAt: Date

    var id: String {
        SHA256.hash(data: Data(sourceURL.absoluteString.utf8)).prefix(10)
            .map { String(format: "%02x", $0) }.joined()
    }

    var filename: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let cleanTitle = title.components(separatedBy: allowed.inverted).joined()
        let stem = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines).prefix(55)
        return stem.isEmpty ? "Recipe-\(id).json" : "\(stem)-\(id).json"
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

enum RecipeFiles {
    static let group = "group.com.barury11.recipes"
    static var shared: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
    }

    static var documents: URL {
        URL.documentsDirectory
    }

    static func enqueue(_ recipe: SavedRecipe) throws -> Bool {
        guard let shared else { return false }
        let inbox = shared.appending(path: "Inbox", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        try recipe.encoded().write(to: inbox.appending(path: "\(UUID().uuidString).json"), options: .atomic)
        return true
    }

    static func save(_ recipe: SavedRecipe) throws {
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        try save(recipe, in: documents, index: try jsonFiles(in: documents))
    }

    private static func save(_ recipe: SavedRecipe, in folder: URL, index: [URL]) throws {
        let known = index.filter { $0.lastPathComponent.hasSuffix("-\(recipe.id).json") }
        if known.contains(where: { decode($0).map { $0.importedAt >= recipe.importedAt } == true }) { return }
        let target = folder.appending(path: recipe.filename)
        try recipe.encoded().write(to: target, options: .atomic)
        for old in known where old != target {
            try? FileManager.default.removeItem(at: old)
        }
    }

    static func load() throws -> [SavedRecipe] {
        let files = FileManager.default
        try files.createDirectory(at: documents, withIntermediateDirectories: true)
        let marker = documents.appending(path: ".recipes")
        if !files.fileExists(atPath: marker.path) {
            try Data().write(to: marker, options: .atomic)
        }
        if let inbox = shared?.appending(path: "Inbox"), files.fileExists(atPath: inbox.path) {
            for url in try jsonFiles(in: inbox) {
                guard let recipe = decode(url) else { continue }
                try save(recipe)
                try files.removeItem(at: url)
            }
        }
        var newest: [String: SavedRecipe] = [:]
        for url in try jsonFiles(in: documents) {
            guard let recipe = decode(url) else { continue }
            if newest[recipe.id].map({ $0.importedAt >= recipe.importedAt }) != true {
                newest[recipe.id] = recipe
            }
        }
        return newest.values.sorted { $0.importedAt > $1.importedAt }
    }

    private static func jsonFiles(in directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles
        ).filter { $0.pathExtension.lowercased() == "json" }
    }

    private static func decode(_ url: URL) -> SavedRecipe? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 4_000_000,
              let data = try? Data(contentsOf: url),
              let recipe = try? JSONDecoder().decode(SavedRecipe.self, from: data),
              !recipe.title.isEmpty, !recipe.ingredients.isEmpty, !recipe.steps.isEmpty else { return nil }
        return recipe
    }
}
