import Foundation

struct RecipePage {
    let url: URL
    let title: String
    let image: String
    let text: String
    let jsonLD: [String]

    init(_ values: [String: Any]) throws {
        guard let address = values["url"] as? String, let url = Self.webURL(address) else {
            throw RecipeImportError.page
        }
        self.url = url
        title = String((values["title"] as? String ?? "").prefix(500))
        image = String((values["image"] as? String ?? "").prefix(4_096))
        text = String((values["text"] as? String ?? "").prefix(32_000))
        jsonLD = Array((values["jsonLD"] as? [String] ?? []).prefix(16)).filter { $0.utf8.count <= 420_000 }
    }

    static func webURL(_ address: String, relativeTo base: URL? = nil) -> URL? {
        guard let url = URL(string: address, relativeTo: base)?.absoluteURL,
              let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = url.host(), !host.isEmpty, url.user == nil, url.password == nil else { return nil }
        return url
    }

    var sourceURL: URL {
        var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        parts?.fragment = nil
        parts?.queryItems = parts?.queryItems?.filter {
            !$0.name.lowercased().hasPrefix("utm_") && !["fbclid", "gclid"].contains($0.name.lowercased())
        }
        if parts?.queryItems?.isEmpty == true { parts?.query = nil }
        return parts?.url ?? url
    }

    func metadata(from candidates: [String]) -> RecipeFields? {
        for block in candidates {
            guard let node = try? JSONSerialization.jsonObject(with: Data(block.utf8)) else { continue }
            if let item = Self.findRecipe(node) {
                return RecipeFields(
                    title: Self.clean(item["name"]),
                    category: Self.strings(item["recipeCategory"]).first,
                    prepMinutes: Self.minutes(item["prepTime"]),
                    totalMinutes: Self.minutes(item["totalTime"]),
                    servings: Self.strings(item["recipeYield"]).first,
                    ingredients: Self.strings(item["recipeIngredient"]),
                    instructions: Self.instructions(item["recipeInstructions"]),
                    imageURL: Self.imageAddress(item["image"])
                )
            }
        }
        return nil
    }

    static func fetch(_ url: URL) async throws -> Self {
        let (html, finalURL) = try await RecipeHTTP.download(url, limit: 2_000_000)
        guard let raw = String(data: html, encoding: .utf8) ?? String(data: html, encoding: .isoLatin1) else {
            throw RecipeImportError.page
        }
        let json = captures(#"(?is)<script\b[^>]*\btype\s*=\s*["']application/ld\+json["'][^>]*>(.*?)</script\s*>"#, in: raw)
        let title = captures(#"(?is)<title\b[^>]*>(.*?)</title>"#, in: raw).first ?? ""
        let image = captures(#"(?is)<meta\b(?=[^>]*\b(?:property|name)\s*=\s*["']og:image["'])(?=[^>]*\bcontent\s*=\s*["']([^"']+)["'])[^>]*>"#, in: raw).first ?? ""
        var body = raw.replacingOccurrences(of: #"(?is)<(script|style|nav|footer|aside|form|noscript|svg|head)\b[^>]*>.*?</\1\s*>"#, with: "", options: .regularExpression)
        body = body.replacingOccurrences(of: #"(?i)</?(?:p|li|h[1-6]|div|br|section)\b[^>]*>"#, with: "\n", options: .regularExpression)
        body = body.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        body = decodeEntities(body).split(whereSeparator: \.isNewline)
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty }.joined(separator: "\n")
        return try Self(["url": finalURL.absoluteString, "title": decodeEntities(title),
                         "image": decodeEntities(image), "text": body, "jsonLD": json])
    }

    private static func findRecipe(_ value: Any, depth: Int = 0) -> [String: Any]? {
        guard depth <= 12 else { return nil }
        if let entries = value as? [Any] {
            return entries.lazy.compactMap { findRecipe($0, depth: depth + 1) }.first
        }
        guard let object = value as? [String: Any] else { return nil }
        if strings(object["@type"]).contains(where: {
            $0 == "Recipe" || $0.hasSuffix("/Recipe") || $0 == "schema:Recipe"
        }) { return object }
        for key in ["mainEntity", "@graph", "mainEntityOfPage"] {
            if let value = object[key], let recipe = findRecipe(value, depth: depth + 1) { return recipe }
        }
        return nil
    }

    private static func instructions(_ value: Any?, depth: Int = 0) -> [String] {
        guard depth <= 12 else { return [] }
        if let rows = value as? [Any] { return rows.flatMap { instructions($0, depth: depth + 1) } }
        if let row = value as? [String: Any] {
            if let children = row["itemListElement"] { return instructions(children, depth: depth + 1) }
            return instructions(row["text"] ?? row["item"], depth: depth + 1)
        }
        guard let value = value as? String else { return [] }
        let lines = value.replacingOccurrences(of: #"(?i)</?(?:p|li|br)\b[^>]*>"#, with: "\n", options: .regularExpression)
        return lines.split(whereSeparator: \.isNewline).compactMap { clean(String($0)) }
    }

    private static func imageAddress(_ value: Any?) -> String? {
        if let str = value as? String { return str }
        if let row = value as? [String: Any] { return (row["url"] ?? row["contentUrl"]) as? String }
        if let rows = value as? [Any] { return rows.lazy.compactMap { imageAddress($0) }.first }
        return nil
    }

    private static func strings(_ value: Any?) -> [String] {
        if let list = value as? [Any] { return list.compactMap(clean) }
        return clean(value).map { [$0] } ?? []
    }

    private static func clean(_ value: Any?) -> String? {
        let value = (value as? String) ?? (value as? NSNumber)?.stringValue ?? ""
        let cleaned = decodeEntities(value.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func minutes(_ value: Any?) -> Int? {
        guard let value = value as? String else { return nil }
        let pattern = #"^P(?:(\d{1,3})D)?T?(?:(\d{1,3})H)?(?:(\d{1,4})M)?(?:(\d{1,4})S)?$"#
        guard let parts = matches(pattern, in: value.uppercased()).first else { return nil }
        let total = (Int(parts[1]) ?? 0) * 1440 + (Int(parts[2]) ?? 0) * 60 + (Int(parts[3]) ?? 0)
        let seconds = Int(parts[4]) ?? 0
        return total > 0 || seconds > 0 ? total + (seconds + 59) / 60 : nil
    }

    static func decodeEntities(_ input: String) -> String {
        let values = ["amp":"&", "quot":"\"", "apos":"'", "nbsp":" ", "lt":"<", "gt":">", "deg":"°",
                      "ndash":"–", "mdash":"—", "frac12":"½", "frac14":"¼", "frac34":"¾", "rsquo":"’"]
        let expression = try! NSRegularExpression(pattern: #"&(#x[0-9A-Fa-f]{1,6}|#[0-9]{1,7}|[a-zA-Z][a-zA-Z0-9]{1,10});"#)
        let text = NSMutableString(string: input)
        for match in expression.matches(in: input, range: NSRange(input.startIndex..., in: input)).reversed() {
            let group = (input as NSString).substring(with: match.range(at: 1))
            let replacement: String?
            if group.hasPrefix("#x") {
                replacement = UInt32(group.dropFirst(2), radix: 16).flatMap(UnicodeScalar.init).map(String.init)
            } else if group.hasPrefix("#") {
                replacement = UInt32(group.dropFirst()).flatMap(UnicodeScalar.init).map(String.init)
            } else {
                replacement = values[group]
            }
            if let replacement { text.replaceCharacters(in: match.range, with: replacement) }
        }
        return text as String
    }

    private static func captures(_ pattern: String, in text: String) -> [String] {
        matches(pattern, in: text).map { $0[1] }
    }

    private static func matches(_ pattern: String, in text: String) -> [[String]] {
        let expression = try! NSRegularExpression(pattern: pattern)
        let source = text as NSString
        return expression.matches(in: text, range: NSRange(location: 0, length: source.length)).map { match in
            (0..<match.numberOfRanges).map {
                let range = match.range(at: $0)
                return range.location == NSNotFound ? "" : source.substring(with: range)
            }
        }
    }
}

struct RecipeFields: Decodable {
    let title: String?
    let category: String?
    let prepMinutes: Int?
    let totalMinutes: Int?
    let servings: String?
    let ingredients: [String]
    let instructions: [String]
    var imageURL: String? = nil

    var complete: Bool {
        title?.isEmpty == false && !ingredients.isEmpty && !instructions.isEmpty
    }
}
