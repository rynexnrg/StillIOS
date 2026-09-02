import ActivityKit

struct StillActivityAttributes: ActivityAttributes {
    enum Mode: String, Codable, Hashable {
        case focus
        case timer
        case alarm
    }

    var mode: Mode
    var title: String

    struct ContentState: Codable, Hashable {
        var isActive: Bool
        var endDate: Date?
        var alarmDate: Date?
        var isPaused: Bool
    }
}
