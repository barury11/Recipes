import AlarmKit
import AppIntents
import Foundation

struct StopCookingTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "timer.stop"

    @Parameter(title: "Timer ID")
    var timerID: String

    init() {}

    init(id: UUID) {
        timerID = id.uuidString
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: timerID) {
            try AlarmManager.shared.cancel(id: id)
        }
        return .result()
    }
}
