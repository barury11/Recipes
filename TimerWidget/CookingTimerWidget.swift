import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

@main
struct CookingTimerWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<CookingTimerMetadata>.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .foregroundStyle(context.attributes.tintColor)
                Text(timerName(context))
                    .font(.headline)
                Spacer(minLength: 8)
                countdown(context)
                    .frame(minWidth: 60, alignment: .trailing)
                stopButton(context)
            }
            .padding(14)
            .activityBackgroundTint(Color(uiColor: .secondarySystemBackground))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(timerName(context), systemImage: "timer")
                        .font(.subheadline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    stopButton(context)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(context.attributes.tintColor)
            } compactTrailing: {
                countdown(context)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(context.attributes.tintColor)
            }
        }
    }

    private func timerName(_ context: ActivityViewContext<AlarmAttributes<CookingTimerMetadata>>) -> String {
        context.attributes.metadata?.name ?? String(localized: "timer.name")
    }

    @ViewBuilder
    private func countdown(_ context: ActivityViewContext<AlarmAttributes<CookingTimerMetadata>>) -> some View {
        if case .countdown(let countdown) = context.state.mode {
            Text(timerInterval: min(countdown.startDate, countdown.fireDate)...countdown.fireDate, countsDown: true)
                .monospacedDigit()
                .lineLimit(1)
        } else {
            Text("0:00").monospacedDigit()
        }
    }

    private func stopButton(_ context: ActivityViewContext<AlarmAttributes<CookingTimerMetadata>>) -> some View {
        Button(intent: StopCookingTimerIntent(id: context.state.alarmID)) {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .frame(width: 34, height: 34)
                .contentShape(.circle)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .accessibilityLabel(Text("timer.stop"))
    }
}
