import SwiftUI
import UIKit
import ImageIO

@MainActor final class IconStore: ObservableObject {
    static let shared = IconStore()
    @Published private(set) var packs: [IconPack] = []
    @Published var problem: String?
    @Published var clipboardImport: Data?
    @Published var requestedPack: UUID?
    let catalog: [CatalogApp]
    private let stateURL: URL

    init(directory: URL? = nil) {
        let root = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        stateURL = root.appendingPathComponent("IconBridge.json")
        catalog = Bundle.main.url(forResource: "catalog", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode([CatalogApp].self, from: $0) } ?? []
        if FileManager.default.fileExists(atPath: stateURL.path) {
            do { packs = try JSONDecoder().decode([IconPack].self, from: Data(contentsOf: stateURL)) }
            catch { problem = "Nie udało się odczytać zapisanych paczek. Plik został zachowany. \(error.localizedDescription)" }
        }
    }
    func pack(_ id: UUID) -> IconPack? { packs.first { $0.id == id } }
    private func commit(_ updated: [IconPack]) throws {
        try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(updated).write(to: stateURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        packs = updated
    }
    @discardableResult func addPack(name: String) throws -> UUID {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 100 else { throw BridgeError.invalid("Nazwa paczki musi mieć od 1 do 100 znaków.") }
        let pack = IconPack(name: name)
        try commit(packs + [pack]); return pack.id
    }
    func save(_ pack: IconPack) throws {
        guard let index = packs.firstIndex(where: { $0.id == pack.id }) else { return }
        var next = packs; next[index] = pack; try commit(next)
    }
    func removePack(_ id: UUID) throws { try commit(packs.filter { $0.id != id }) }
    func addImage(_ data: Data, name: String, to id: UUID) throws {
        guard var pack = pack(id) else { throw BridgeError.invalid("Nie znaleziono paczki.") }
        guard pack.icons.count < 200 else { throw BridgeError.invalid("Paczka może zawierać najwyżej 200 ikon.") }
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        let match = catalog.first { normalize($0.name) == normalize(clean) || $0.id == normalize(clean) }
        pack.icons.append(IconItem(name: clean.isEmpty ? "Nowa ikona" : clean,
                                   image: try Self.normalizedImage(data), target: match?.target))
        try save(pack)
    }
    private func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))
            .filter { $0.isLetter || $0.isNumber }
    }
    static func normalizedImage(_ data: Data) throws -> Data {
        guard data.count <= 20 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 800
              ] as CFDictionary) else { throw BridgeError.invalid("Nie można odczytać obrazu (maks. 20 MB).") }
        let uiImage = UIImage(cgImage: image)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400), format: format).image { context in
            UIColor.black.setFill(); context.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
            let scale = max(400 / uiImage.size.width, 400 / uiImage.size.height)
            let size = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
            uiImage.draw(in: CGRect(x: (400 - size.width) / 2, y: (400 - size.height) / 2, width: size.width, height: size.height))
        }
        guard let png = rendered.pngData(), png.count <= 1024 * 1024 else { throw BridgeError.invalid("Nie udało się przygotować ikony.") }
        return png
    }
    func importArchive(_ data: Data) throws -> UUID {
        var imported = try PackArchive.decode(data)
        // Imported files are copies: avoid overwriting another pack/profile with a matching UUID.
        imported.id = UUID()
        for index in imported.icons.indices {
            imported.icons[index].id = UUID()
            imported.icons[index].image = try Self.normalizedImage(imported.icons[index].image)
            imported.icons[index].prepared = false
        }
        try commit(packs + [imported]); return imported.id
    }
    func move(icon: UUID, from source: UUID, to destination: UUID) throws {
        guard source != destination, let s = packs.firstIndex(where: { $0.id == source }),
              let d = packs.firstIndex(where: { $0.id == destination }),
              let i = packs[s].icons.firstIndex(where: { $0.id == icon }) else { return }
        guard packs[d].icons.count < 200 else { throw BridgeError.invalid("Paczka docelowa jest pełna.") }
        var next = packs; let item = next[s].icons.remove(at: i); next[d].icons.append(item); try commit(next)
    }
    func handle(_ url: URL) {
        do {
            if url.isFileURL {
                let scope = url.startAccessingSecurityScopedResource(); defer { if scope { url.stopAccessingSecurityScopedResource() } }
                guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= PackArchive.maximumBytes else {
                    throw BridgeError.invalid("Plik jest za duży.")
                }
                requestedPack = try importArchive(Data(contentsOf: url)); return
            }
            guard url.scheme == "iconbridge" else { return }
            if url.host == "import-clipboard" {
                guard let image = UIPasteboard.general.image, let data = image.pngData() else {
                    throw BridgeError.invalid("Schowek nie zawiera obrazu. Uruchom skrót „IconBridge - Importuj”.")
                }
                clipboardImport = try Self.normalizedImage(data)
            } else if url.host == "pack", let id = UUID(uuidString: url.lastPathComponent), pack(id) != nil {
                requestedPack = id
            }
        } catch { problem = error.localizedDescription }
    }
    func writeTemporary(_ data: Data, filename: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent(filename); try data.write(to: url, options: .atomic); return url
    }
    func launcherURL(id: String) -> URL? {
        let name = id == "import" ? "IconBridge - Importuj" : catalog.first { $0.id == id }?.shortcutName
        guard let name else { return nil }
        return Bundle.main.url(forResource: name, withExtension: "shortcut", subdirectory: "Launchers")
    }
}
