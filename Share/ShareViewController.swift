import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let host = UIHostingController(rootView: RecipeImportView(
            readPage: { [weak self] in
                guard let self else { throw CancellationError() }
                return try await self.readPage()
            },
            fromShare: true,
            onSave: RecipeFiles.enqueue,
            onClose: { [weak self] in self?.extensionContext?.completeRequest(returningItems: nil) }
        ))
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    private func readPage() async throws -> RecipePage {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) {
            if let item = try? await load(provider, type: .propertyList),
               let plist = item as? [String: Any],
               let content = plist[NSExtensionJavaScriptPreprocessingResultsKey] as? [String: Any],
               let page = try? RecipePage(content),
               !page.text.isEmpty || !page.jsonLD.isEmpty {
                return page
            }
        }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let item = try? await load(provider, type: .url),
               let address = (item as? URL)?.absoluteString ?? (item as? String),
               let url = RecipePage.webURL(address) {
                return try await RecipePage.fetch(url)
            }
        }
        throw RecipeImportError.page
    }

    private func load(_ provider: NSItemProvider, type: UTType) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: item) }
            }
        }
    }
}
