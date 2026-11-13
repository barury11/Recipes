import SwiftUI
import UIKit

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        let host = UIHostingController(
            rootView: RecipeScreen(recipe: .sample) { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        )
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
}
