import XCTest
@testable import IconBridgeCore

final class CoreTests: XCTestCase {
    let png = Data([137,80,78,71,13,10,26,10,0])
    func icon(_ target: LaunchTarget? = .init(kind: .shortcut, value: "A&B + #? ą")) -> IconItem {
        IconItem(name: "A & B <Ikona>", image: png, target: target)
    }
    func testShortcutNamesRoundTrip() throws {
        for name in ["A&B + #? ą", "Zdjęcia", "100% gotowe", "foo/bar"] {
            let url = try LaunchTarget(kind: .shortcut, value: name).resolvedURL()
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            XCTAssertEqual(components.scheme, "shortcuts")
            XCTAssertEqual(components.queryItems, [URLQueryItem(name: "name", value: name)])
        }
    }
    func testRejectedURLs() {
        for url in ["", "file:///etc/passwd", "javascript:alert(1)", "data:text/plain,x", "iconbridge://import-clipboard", "https:///", "foo bar://x", "https://user:secret@example.com"] {
            XCTAssertThrowsError(try LaunchTarget(kind: .url, value: url).resolvedURL(), url)
        }
    }
    func testAcceptedURLs() throws {
        for url in ["spotify://", "https://example.com/path?q=1", "shortcuts://run-shortcut?name=Foo"] {
            XCTAssertNoThrow(try LaunchTarget(kind: .url, value: url).resolvedURL())
        }
    }
    func testProfileOnlyContainsRemovableWebClips() throws {
        let pack = IconPack(name: "Test <&>", icons: [icon(), icon(.init(kind: .url, value: "spotify://"))])
        let data = try ProfileBuilder.build(pack: pack)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(plist["PayloadUUID"] as? String, pack.id.uuidString)
        XCTAssertEqual(plist["PayloadRemovalDisallowed"] as? Bool, false)
        let payloads = try XCTUnwrap(plist["PayloadContent"] as? [[String: Any]])
        XCTAssertEqual(payloads.count, 2)
        for item in payloads {
            XCTAssertEqual(item["PayloadType"] as? String, "com.apple.webClip.managed")
            XCTAssertEqual(item["IsRemovable"] as? Bool, true)
            XCTAssertNil(item["TargetApplicationBundleIdentifier"])
            XCTAssertEqual(item["Icon"] as? Data, png)
        }
        XCTAssertEqual(payloads[0]["Label"] as? String, "A & B <Ikona>")
        XCTAssertEqual(try ProfileBuilder.build(pack: pack), data, "Exporting the same pack must not create duplicate profile identities")
    }
    func testUnboundAndEmptyPacksRejected() {
        XCTAssertThrowsError(try ProfileBuilder.build(pack: IconPack(name: "Empty")))
        XCTAssertThrowsError(try ProfileBuilder.build(pack: IconPack(name: "Unbound", icons: [icon(nil)])))
    }
    func testArchiveValidationAndRoundtrip() throws {
        let pack = IconPack(name: "Test", icons: [icon()])
        let data = try JSONEncoder().encode(PackArchive(pack: pack))
        XCTAssertEqual(try PackArchive.decode(data), pack)
        var invalid = PackArchive(pack: pack); invalid.version = 999
        XCTAssertThrowsError(try PackArchive.decode(JSONEncoder().encode(invalid)))
        invalid = PackArchive(pack: IconPack(name: "Dup", icons: [pack.icons[0], pack.icons[0]]))
        XCTAssertThrowsError(try PackArchive.decode(JSONEncoder().encode(invalid)))
        invalid = PackArchive(pack: IconPack(name: "Invalid PNG", icons: [IconItem(name: "X", image: Data([1,2]))]))
        XCTAssertThrowsError(try PackArchive.decode(JSONEncoder().encode(invalid)))
    }
    func testCompanionInputRoundtrip() throws {
        let input = "http://127.0.0.1:123/a/icons.mobileconfig?foo=1&bar=2"
        let url = try BridgeLinks.runShortcut("A + B & ą", input: input)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "text" })?.value, input)
    }
    func testHTTPParserRequiresExactTokenPathAndGET() {
        XCTAssertTrue(LocalRequest.accepts("GET /abc/icons.mobileconfig HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n", token: "abc", filename: "icons.mobileconfig"))
        XCTAssertTrue(LocalRequest.accepts("GET /abc/IconBridge%20-%20Safari.shortcut HTTP/1.1\r\n\r\n", token: "abc", filename: "IconBridge - Safari.shortcut"))
        for request in ["GET /wrong/icons.mobileconfig HTTP/1.1\r\n\r\n", "POST /abc/icons.mobileconfig HTTP/1.1\r\n\r\n", "GET /abc/../icons.mobileconfig HTTP/1.1\r\n\r\n", "GET /abc/icons.mobileconfig HTTP/1.1\r\n"] {
            XCTAssertFalse(LocalRequest.accepts(request, token: "abc", filename: "icons.mobileconfig"))
        }
    }
}
