import ActivityKit
import Foundation

@MainActor
final class StillActivityCoordinator {
    static let shared = StillActivityCoordinator()
    private var activity: Activity<StillActivityAttributes>?

    func showFocus() {
        request(mode: .focus, title: "Fokus", state: .init(isActive: true, endDate: nil, alarmDate: nil, isPaused: false))
    }

    func showTimer(endDate: Date, isPaused: Bool) {
        update(title: "Timer", state: .init(isActive: true, endDate: endDate, alarmDate: nil, isPaused: isPaused))
    }

    func showAlarm(date: Date) {
        request(mode: .alarm, title: "Wecker", state: .init(isActive: true, endDate: nil, alarmDate: date, isPaused: false))
    }

    func updateTimer(endDate: Date, isPaused: Bool) {
        update(title: "Timer", state: .init(isActive: true, endDate: endDate, alarmDate: nil, isPaused: isPaused))
    }

    func finish() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    private func request(mode: StillActivityAttributes.Mode, title: String, state: StillActivityAttributes.ContentState) {
        Task {
            if let activity { await activity.end(nil, dismissalPolicy: .immediate) }
            do {
                self.activity = try Activity.request(
                    attributes: StillActivityAttributes(mode: mode, title: title),
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
            } catch {
                print("Still Live Activity could not start: \(error.localizedDescription)")
            }
        }
    }

    private func update(title: String, state: StillActivityAttributes.ContentState) {
        guard let activity else {
            request(mode: state.alarmDate == nil ? .timer : .alarm, title: title, state: state)
            return
        }
        Task { await activity.update(ActivityContent(state: state, staleDate: state.endDate)) }
    }
}
