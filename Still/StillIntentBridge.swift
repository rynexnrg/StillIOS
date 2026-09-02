import Foundation

@MainActor
enum StillIntentBridge {
    private static let defaults = UserDefaults(suiteName: "group.com.johannes.still") ?? .standard

    static func consumePendingCommands(audio: AudioManager) {
        guard let command = defaults.string(forKey: "pendingCommand") else { return }
        defaults.removeObject(forKey: "pendingCommand")

        switch command {
        case "toggleFocus": audio.toggleFocus()
        case "startTimer": audio.startTimer(duration: defaults.double(forKey: "pendingTimerSeconds"))
        case "pauseTimer": audio.pauseTimer()
        case "resumeTimer": audio.resumeTimer()
        case "cancelAll":
            audio.cancelTimer()
            audio.cancelAlarm()
            audio.stopFocus()
        default: break
        }
    }
}
