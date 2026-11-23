import Foundation

public enum ProfileBuilder {
    /// Only removable Web Clips. No MDM, certificates, VPN, restrictions or layout payload.
    public static func build(pack: IconPack) throws -> Data {
        guard !pack.icons.isEmpty else { throw BridgeError.invalid("Paczka jest pusta.") }
        guard pack.icons.count <= 200 else { throw BridgeError.invalid("Maksymalnie 200 ikon w paczce.") }
        let prefix = "com.barury11.iconbridge.pack.\(pack.id.uuidString.lowercased())"
        let payloads: [[String: Any]] = try pack.icons.map { icon in
            guard let target = icon.target else {
                throw BridgeError.invalid("Najpierw przypisz aplikację do ikony „\(icon.name)”.")
            }
            guard icon.image.count <= 1024 * 1024,
                  icon.image.starts(with: [137,80,78,71,13,10,26,10]) else {
                throw BridgeError.invalid("Nieprawidłowy obraz ikony „\(icon.name)”.")
            }
            return [
                "PayloadType": "com.apple.webClip.managed", "PayloadVersion": 1,
                "PayloadIdentifier": "\(prefix).\(icon.id.uuidString.lowercased())",
                "PayloadUUID": icon.id.uuidString,
                "PayloadDisplayName": icon.name,
                "Label": icon.name, "URL": try target.resolvedURL().absoluteString,
                "Icon": icon.image, "IsRemovable": true, "Precomposed": true,
                "FullScreen": false
            ]
        }
        let profile: [String: Any] = [
            "PayloadType": "Configuration", "PayloadVersion": 1,
            "PayloadIdentifier": prefix, "PayloadUUID": pack.id.uuidString,
            "PayloadDisplayName": "IconBridge · \(pack.name)",
            "PayloadOrganization": "IconBridge",
            "PayloadDescription": "Dodaje \(pack.icons.count) ikon. Nie zmienia oryginalnych aplikacji. Usunięcie profilu usuwa dodane ikony. Otwieranie aplikacji przez Web Clip może wymagać potwierdzenia i zależy od wersji iOS.",
            "PayloadRemovalDisallowed": false,
            "PayloadContent": payloads
        ]
        return try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
    }
}

public enum BridgeLinks {
    public static func runShortcut(_ name: String, input: String? = nil) throws -> URL {
        let url = try LaunchTarget(kind: .shortcut, value: name).resolvedURL()
        guard let input else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "input", value: "text"), URLQueryItem(name: "text", value: input)
        ]
        return components.url!
    }
}

/// Pure parser shared with tests; HTTP delivery accepts only one exact, random path.
public enum LocalRequest {
    public static func accepts(_ header: String, token: String, filename: String) -> Bool {
        guard header.utf8.count <= 8192, header.contains("\r\n\r\n"),
              let first = header.components(separatedBy: "\r\n").first else { return false }
        let parts = first.split(separator: " ", omittingEmptySubsequences: false)
        return parts.count == 3 && parts[0] == "GET" && parts[1] == "/\(token)/\(filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename)" && parts[2] == "HTTP/1.1"
    }
}
