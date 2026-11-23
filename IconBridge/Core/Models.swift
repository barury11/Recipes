import Foundation

public enum BridgeError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let reason): return reason }
    }
}

public enum LaunchKind: String, Codable, CaseIterable, Sendable {
    case shortcut, url
}

public struct LaunchTarget: Codable, Equatable, Sendable {
    public var kind: LaunchKind
    public var value: String
    public init(kind: LaunchKind, value: String) { self.kind = kind; self.value = value }
    public func resolvedURL() throws -> URL {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 2048 else {
            throw BridgeError.invalid("Wpisz nazwę skrótu lub adres aplikacji (maks. 2048 znaków).")
        }
        if kind == .shortcut {
            var parts = URLComponents()
            parts.scheme = "shortcuts"; parts.host = "run-shortcut"
            parts.queryItems = [URLQueryItem(name: "name", value: text)]
            guard let url = parts.url else { throw BridgeError.invalid("Nieprawidłowa nazwa skrótu.") }
            return url
        }
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased(),
              scheme.range(of: "^[a-z][a-z0-9+.-]*$", options: .regularExpression) != nil,
              !["file", "data", "javascript", "vbscript", "iconbridge"].contains(scheme),
              !text.contains(where: { $0.isNewline || $0.isWhitespace }) else {
            throw BridgeError.invalid("Podaj pełny adres, np. spotify:// lub https://example.com. Ten typ adresu nie jest obsługiwany.")
        }
        if ["http", "https"].contains(scheme), url.host?.isEmpty != false {
            throw BridgeError.invalid("Adres strony musi zawierać nazwę serwera.")
        }
        guard url.user == nil, url.password == nil else {
            throw BridgeError.invalid("Nie zapisuj loginu ani hasła w adresie ikony.")
        }
        return url
    }
}

public struct IconItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var image: Data
    public var target: LaunchTarget?
    public var prepared: Bool
    public init(id: UUID = UUID(), name: String, image: Data, target: LaunchTarget? = nil, prepared: Bool = false) {
        self.id = id; self.name = name; self.image = image; self.target = target; self.prepared = prepared
    }
}

public struct IconPack: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var icons: [IconItem]
    public init(id: UUID = UUID(), name: String, icons: [IconItem] = []) {
        self.id = id; self.name = name; self.icons = icons
    }
    public var readyCount: Int { icons.filter { (try? $0.target?.resolvedURL()) != nil }.count }
}

public struct PackArchive: Codable, Sendable {
    public var version: Int = 1
    public var pack: IconPack
    public init(pack: IconPack) { self.pack = pack }
    public static let maximumBytes = 32 * 1024 * 1024
    public static func decode(_ data: Data) throws -> IconPack {
        guard data.count <= maximumBytes else { throw BridgeError.invalid("Paczka przekracza 32 MB.") }
        let archive = try JSONDecoder().decode(Self.self, from: data)
        guard archive.version == 1 else { throw BridgeError.invalid("Nieobsługiwana wersja paczki.") }
        guard !archive.pack.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              archive.pack.name.count <= 100, archive.pack.icons.count <= 200 else {
            throw BridgeError.invalid("Paczka wymaga nazwy do 100 znaków i maksymalnie 200 ikon.")
        }
        guard Set(archive.pack.icons.map(\.id)).count == archive.pack.icons.count else {
            throw BridgeError.invalid("Paczka zawiera powtórzone identyfikatory ikon.")
        }
        for item in archive.pack.icons {
            guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  item.name.count <= 100, item.image.count <= 1024 * 1024,
                  item.image.starts(with: [137,80,78,71,13,10,26,10]) else {
                throw BridgeError.invalid("Ikony muszą mieć nazwy do 100 znaków i format PNG do 1 MB.")
            }
            if let target = item.target { _ = try target.resolvedURL() }
        }
        return archive.pack
    }
}

public struct CatalogApp: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var bundleID: String
    public var symbol: String
    public var shortcutName: String { "IconBridge - \(name)" }
    public var resourceName: String { id }
    public var target: LaunchTarget { .init(kind: .shortcut, value: shortcutName) }
}
