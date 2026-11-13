import Foundation
import Security

enum GeminiKey {
    private static var query: [String: Any] {
        var result: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.barury11.recipes.gemini",
            kSecAttrAccount as String: "api-key"
        ]
        if RecipeFiles.shared != nil { result[kSecAttrAccessGroup as String] = RecipeFiles.group }
        return result
    }

    static func load() -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ value: String) throws {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = query
        if clean.isEmpty {
            let status = SecItemDelete(request as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure.storage }
            return
        }
        guard clean.utf8.count <= 256, clean.unicodeScalars.allSatisfy({
            CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_").contains($0)
        }) else { throw Failure.invalid }
        let changes = [kSecValueData as String: Data(clean.utf8)]
        var status = SecItemUpdate(request as CFDictionary, changes as CFDictionary)
        if status == errSecItemNotFound {
            var item = request.merging(changes) { _, value in value }
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
            if status == errSecDuplicateItem {
                status = SecItemUpdate(request as CFDictionary, changes as CFDictionary)
            }
        }
        guard status == errSecSuccess else { throw Failure.storage }
    }

    enum Failure: Error {
        case invalid, storage
    }
}
