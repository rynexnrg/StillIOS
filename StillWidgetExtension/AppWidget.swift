import AppIntents
import SwiftUI
import WidgetKit

private let appGroup = "group.com.johannes.still"

struct WidgetState {
    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }
    static var focusIsActive: Bool { defaults.bool(forKey: "focusIsActive") }
}

struct ToggleFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Fokus umschalten"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        let defaults = WidgetState.defaults
        defaults.set(!defaults.bool(forKey: "focusIsActive"), forKey: "focusIsActive")
        defaults.set("toggleFocus", forKey: "pendingCommand")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct StartTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Timer starten"
    static var openAppWhenRun = true

    @Parameter(title: "Minuten") var minutes: Int

    init() { minutes = 5 }
    init(minutes: Int) { self.minutes = minutes }

    func perform() async throws -> some IntentResult {
        let defaults = WidgetState.defaults
        defaults.set(max(1, minutes) * 60, forKey: "pendingTimerSeconds")
        defaults.set("startTimer", forKey: "pendingCommand")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct StillProvider: TimelineProvider {
    func placeholder(in context: Context) -> StillEntry { StillEntry(date: Date(), focusIsActive: false) }
    func getSnapshot(in context: Context, completion: @escaping (StillEntry) -> Void) { completion(StillEntry(date: Date(), focusIsActive: WidgetState.focusIsActive)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StillEntry>) -> Void) {
        let entry = StillEntry(date: Date(), focusIsActive: WidgetState.focusIsActive)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60))))
    }
}

struct StillEntry: TimelineEntry {
    let date: Date
    let focusIsActive: Bool
}

struct StillWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StillWidget", provider: StillProvider()) { entry in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("STILL").font(.caption.weight(.medium)).tracking(1.5)
                    Spacer()
                    Circle().fill(entry.focusIsActive ? .cyan : .white.opacity(0.3)).frame(width: 8, height: 8)
                }
                Text(entry.focusIsActive ? "Fokus aktiv" : "Bereit").font(.headline)
                HStack(spacing: 8) {
                    Button(intent: ToggleFocusIntent()) { Label(entry.focusIsActive ? "Stop" : "Fokus", systemImage: entry.focusIsActive ? "pause.fill" : "waveform") }
                    Button(intent: StartTimerIntent(minutes: 5)) { Text("5 min") }
                    Button(intent: StartTimerIntent(minutes: 30)) { Text("30 min") }
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
            .containerBackground(for: .widget) { Color(red: 0.05, green: 0.07, blue: 0.11) }
        }
        .configurationDisplayName("Still")
        .description("Fokus und Timer direkt starten.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
