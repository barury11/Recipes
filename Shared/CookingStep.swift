import Foundation

struct CookingStep: Codable {
    struct Segment: Codable {
        let text: String
        let timerSeconds: Int?

        init(_ text: String, timerSeconds: Int? = nil) {
            self.text = text
            self.timerSeconds = timerSeconds
        }
    }

    let paragraphs: [[Segment]]

    static let soup: [Self] = [
        .init(paragraphs: [
            [.init(String(localized: "soup.step1.prepare"))],
            [.init(String(localized: "soup.step1.sauté.before")),
             .init(String(localized: "soup.step1.sauté.time"), timerSeconds: 300),
             .init(String(localized: "soup.step1.sauté.after"))]
        ]),
        .init(paragraphs: [
            [.init(String(localized: "soup.step2.stock"))],
            [.init(String(localized: "soup.step2.simmer.before")),
             .init(String(localized: "soup.step2.simmer.time"), timerSeconds: 1_200),
             .init(String(localized: "soup.step2.simmer.after"))]
        ]),
        .init(paragraphs: [
            [.init(String(localized: "soup.step3.blend.before")),
             .init(String(localized: "soup.step3.blend.time"), timerSeconds: 45),
             .init(String(localized: "soup.step3.blend.after"))],
            [.init(String(localized: "soup.step3.serve"))]
        ])
    ]
}
