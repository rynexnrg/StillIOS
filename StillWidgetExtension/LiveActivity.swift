import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct StillActivityAttributes: ActivityAttributes {
    enum Mode: String, Codable, Hashable { case focus, timer, alarm }
    var mode: Mode
    var title: String
    struct ContentState: Codable, Hashable {
        var isActive: Bool
        var endDate: Date?
        var alarmDate: Date?
        var isPaused: Bool
    }
}

private let appGroup = "group.com.johannes.still"

struct PauseTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Timer pausieren"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: appGroup)?.set("pauseTimer", forKey: "pendingCommand")
        return .result()
    }
}

struct ResumeTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Timer fortsetzen"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: appGroup)?.set("resumeTimer", forKey: "pendingCommand")
        return .result()
    }
}

struct CancelStillIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Beenden"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: appGroup)?.set("cancelAll", forKey: "pendingCommand")
        return .result()
    }
}

struct StillLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StillActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: context.attributes.mode == .alarm ? "bell.fill" : "waveform")
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading) {
                    Text(context.attributes.title).font(.headline)
                    if context.attributes.mode == .alarm, let date = context.state.alarmDate {
                        Text(date, style: .time).font(.caption)
                    } else if let endDate = context.state.endDate {
                        Text(timerInterval: Date()...endDate, countsDown: true).font(.caption.monospacedDigit())
                    } else {
                        Text(context.state.isActive ? "Aktiv" : "Beendet").font(.caption)
                    }
                }
                Spacer()
                if context.state.endDate != nil {
                    if context.state.isPaused {
                        Button(intent: ResumeTimerIntent()) { Image(systemName: "play.fill") }
                    } else {
                        Button(intent: PauseTimerIntent()) { Image(systemName: "pause.fill") }
                    }
                }
                Button(intent: CancelStillIntent()) { Image(systemName: "xmark") }
            }
            .padding()
            .activityBackgroundTint(Color(red: 0.05, green: 0.07, blue: 0.11))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.mode == .alarm ? "bell.fill" : "waveform").foregroundStyle(.cyan)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title).font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.endDate != nil {
                        if context.state.isPaused {
                            Button(intent: ResumeTimerIntent()) { Image(systemName: "play.fill") }
                        } else {
                            Button(intent: PauseTimerIntent()) { Image(systemName: "pause.fill") }
                        }
                    }
                    Button(intent: CancelStillIntent()) { Image(systemName: "xmark") }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let endDate = context.state.endDate {
                        Text(timerInterval: Date()...endDate, countsDown: true).font(.title3.monospacedDigit())
                    } else if let alarmDate = context.state.alarmDate {
                        Text(alarmDate, style: .time).font(.title3)
                    } else {
                        Text(context.state.isActive ? "Fokus aktiv" : "Bereit")
                    }
                }
            } compactLeading: {
                Image(systemName: "waveform").foregroundStyle(.cyan)
            } compactTrailing: {
                if let endDate = context.state.endDate { Text(timerInterval: Date()...endDate, countsDown: true).monospacedDigit() } else { Text("Still") }
            } minimal: {
                Image(systemName: "waveform").foregroundStyle(.cyan)
            }
        }
    }
}
