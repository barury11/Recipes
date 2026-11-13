import AlarmKit
import SwiftUI

enum CookingTimer {
    enum Error: Swift.Error {
        case denied
        case invalidDuration
    }

    @MainActor
    static func start(seconds: Int) async throws {
        guard seconds > 0 else { throw Error.invalidDuration }

        let manager = AlarmManager.shared
        let authorization = if manager.authorizationState == .notDetermined {
            try await manager.requestAuthorization()
        } else {
            manager.authorizationState
        }
        guard authorization == .authorized else { throw Error.denied }

        let title: LocalizedStringResource = "timer.name"
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(title: title)
        } else {
            alert = AlarmPresentation.Alert(
                title: title,
                stopButton: AlarmButton(text: "timer.stop", textColor: .white, systemImageName: "stop.fill")
            )
        }
        let presentation = AlarmPresentation(
            alert: alert,
            countdown: .init(title: title, pauseButton: nil)
        )
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: CookingTimerMetadata(name: String(localized: "timer.name")),
            tintColor: .orange
        )
        let configuration = AlarmManager.AlarmConfiguration.timer(
            duration: TimeInterval(seconds),
            attributes: attributes
        )
        _ = try await manager.schedule(id: UUID(), configuration: configuration)
    }
}
