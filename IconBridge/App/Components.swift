import SwiftUI
import UIKit

struct ShareFile: Identifiable { let id = UUID(); let url: URL }
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
struct IconImage: View {
    let data: Data
    var size: CGFloat = 60
    var body: some View {
        Group {
            if let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill() }
            else { Image(systemName: "photo").resizable().scaledToFit().padding(14).background(.quaternary) }
        }
        .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.23))
        .accessibilityHidden(true)
    }
}
struct InfoCard: View {
    let title: String
    let text: String
    var symbol: String = "info.circle"
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }.padding(18).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
}
