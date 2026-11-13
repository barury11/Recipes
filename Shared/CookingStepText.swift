import SwiftUI
import UIKit

struct CookingStepText: UIViewRepresentable {
    let step: CookingStep
    let onTimer: (Int) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.overrideUserInterfaceStyle = .light
        view.delegate = context.coordinator
        return view
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTimer: onTimer)
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.onTimer = onTimer
        let textSize = UIContentSizeCategory(dynamicTypeSize) ?? .large
        let font = UIFontMetrics(forTextStyle: .title2).scaledFont(
            for: .systemFont(ofSize: 26),
            compatibleWith: UITraitCollection(preferredContentSizeCategory: textSize)
        )
        let timerFont = UIFont.systemFont(ofSize: font.pointSize, weight: .semibold)
        let timerColor = UIColor(red: 0.60, green: 0.33, blue: 0.07, alpha: 1)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 23

        let text = NSMutableAttributedString()
        let regularAttributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label]
        for (index, paragraph) in step.paragraphs.enumerated() {
            if index > 0 { text.append(NSAttributedString(string: "\n", attributes: regularAttributes)) }
            for segment in paragraph {
                let start = text.length
                if let seconds = segment.timerSeconds, let url = URL(string: "recipes-timer://start/\(seconds)") {
                    let symbolConfig = UIImage.SymbolConfiguration(pointSize: font.pointSize * 0.76, weight: .semibold)
                    if let icon = UIImage(systemName: "timer", withConfiguration: symbolConfig) {
                        let attachment = NSTextAttachment()
                        attachment.image = icon.withTintColor(timerColor, renderingMode: .alwaysOriginal)
                        attachment.bounds = CGRect(x: 0, y: -1, width: icon.size.width, height: icon.size.height)
                        text.append(NSAttributedString(attachment: attachment))
                        text.append(NSAttributedString(string: "\u{00A0}"))
                    }
                    text.append(NSAttributedString(string: segment.text.replacingOccurrences(of: " ", with: "\u{00A0}")))
                    let range = NSRange(location: start, length: text.length - start)
                    text.addAttributes([.link: url, .font: timerFont], range: range)
                } else {
                    text.append(NSAttributedString(string: segment.text, attributes: regularAttributes))
                }
            }
        }
        let range = NSRange(location: 0, length: text.length)
        text.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        view.linkTextAttributes = [.foregroundColor: timerColor, .underlineStyle: 0]
        if view.attributedText != text { view.attributedText = text }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let height = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        return CGSize(width: width, height: ceil(height))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onTimer: (Int) -> Void

        init(onTimer: @escaping (Int) -> Void) {
            self.onTimer = onTimer
        }

        func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
            guard textItem.range.location < textView.textStorage.length,
                  let url = textView.textStorage.attribute(
                    .link, at: textItem.range.location, effectiveRange: nil
                  ) as? URL,
                  url.scheme == "recipes-timer", url.host == "start",
                  let seconds = Int(url.lastPathComponent) else { return nil }
            return UIAction { [weak self] _ in self?.onTimer(seconds) }
        }

        func textView(
            _ textView: UITextView,
            menuConfigurationFor textItem: UITextItem,
            defaultMenu: UIMenu
        ) -> UITextItem.MenuConfiguration? {
            nil
        }
    }
}
