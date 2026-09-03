import AVFoundation
import Combine
import Foundation
import AudioToolbox
import UserNotifications
import WidgetKit

@MainActor
final class AudioManager: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var isAlarmPlaying = false
    @Published private(set) var timerEndDate: Date?
    @Published private(set) var timerIsPaused = false
    @Published private(set) var alarmDate: Date?

    private let audioSession = AVAudioSession.sharedInstance()
    private var audioEngine: AVAudioEngine?
    private var timer: Timer?
    private var pausedRemaining: TimeInterval?
    private var alarmTimer: Timer?
    private var alarmStopTask: Task<Void, Never>?
    private let defaults = UserDefaults(suiteName: "group.com.johannes.still") ?? .standard
    private let timerNotificationID = "still.timer.finished"
    private let alarmNotificationID = "still.alarm.fired"
    private let historyKey = "focusSessionHistory"

    init() {
        configureAudioSession()
        restoreState()
        requestNotificationPermission()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var timerRemaining: TimeInterval {
        if timerIsPaused, let pausedRemaining { return pausedRemaining }
        guard let timerEndDate else { return 0 }
        return max(0, timerEndDate.timeIntervalSinceNow)
    }

    func toggleFocus() {
        isPlaying ? stopFocus() : startFocus()
    }

    func startFocus() {
        guard !isPlaying else { return }
        do {
            try audioSession.setActive(true, options: [])
            let engine = AVAudioEngine()
            let format = engine.mainMixerNode.outputFormat(forBus: 0)
            let source = AVAudioSourceNode { _, _, frameCount, audioBufferList in
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for buffer in buffers {
                    memset(buffer.mData, 0, Int(buffer.mDataByteSize))
                }
                return noErr
            }
            engine.attach(source)
            engine.connect(source, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = 1
            try engine.start()
            audioEngine = engine
            isPlaying = true
            defaults.set(true, forKey: "focusIsActive")
            WidgetCenter.shared.reloadAllTimelines()
            StillActivityCoordinator.shared.showFocus()
        } catch {
            audioEngine = nil
            isPlaying = false
            print("Still audio could not start: \(error.localizedDescription)")
        }
    }

    func stopFocus() {
        audioEngine?.stop()
        audioEngine = nil
        isPlaying = false
        defaults.set(false, forKey: "focusIsActive")
        WidgetCenter.shared.reloadAllTimelines()
        if !isAlarmPlaying {
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func startTimer(duration: TimeInterval) {
        guard duration > 0 else { return }
        startFocus()
        timer?.invalidate()
        timerEndDate = Date().addingTimeInterval(duration)
        pausedRemaining = nil
        timerIsPaused = false
        defaults.set(duration, forKey: "timerDuration")
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateTimer() }
        }
        scheduleNotification(
            identifier: timerNotificationID,
            title: "Timer beendet",
            body: "Deine Still-Session ist abgeschlossen.",
            date: timerEndDate!
        )
        persistState()
        StillActivityCoordinator.shared.showTimer(endDate: timerEndDate!, isPaused: false)
    }

    func pauseTimer() {
        guard let timerEndDate else { return }
        timer?.invalidate()
        timer = nil
        pausedRemaining = max(0, timerEndDate.timeIntervalSinceNow)
        timerIsPaused = true
        removeNotification(withIdentifier: timerNotificationID)
        persistState()
        StillActivityCoordinator.shared.updateTimer(endDate: Date().addingTimeInterval(pausedRemaining!), isPaused: true)
    }

    func resumeTimer() {
        guard timerEndDate != nil else { return }
        timerEndDate = Date().addingTimeInterval(pausedRemaining ?? timerRemaining)
        pausedRemaining = nil
        timerIsPaused = false
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateTimer() }
        }
        scheduleNotification(
            identifier: timerNotificationID,
            title: "Timer beendet",
            body: "Deine Still-Session ist abgeschlossen.",
            date: timerEndDate!
        )
        persistState()
        StillActivityCoordinator.shared.updateTimer(endDate: timerEndDate!, isPaused: false)
    }

    func cancelTimer() {
        timer?.invalidate()
        timer = nil
        timerEndDate = nil
        pausedRemaining = nil
        timerIsPaused = false
        defaults.removeObject(forKey: "timerDuration")
        removeNotification(withIdentifier: timerNotificationID)
        persistState()
        if !isAlarmPlaying { stopFocus() }
        StillActivityCoordinator.shared.finish()
    }

    func scheduleAlarm(at date: Date) {
        alarmTimer?.invalidate()
        alarmDate = date
        startFocus()
        scheduleNotification(
            identifier: alarmNotificationID,
            title: "Still-Wecker",
            body: "Dein Wecker ist fällig.",
            date: date
        )
        persistState()
        StillActivityCoordinator.shared.showAlarm(date: date)
        let delay = max(0, date.timeIntervalSinceNow)
        alarmTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.fireAlarm() }
        }
    }

    func cancelAlarm() {
        alarmTimer?.invalidate()
        alarmTimer = nil
        alarmDate = nil
        removeNotification(withIdentifier: alarmNotificationID)
        persistState()
        if !isAlarmPlaying && timerEndDate == nil { stopFocus() }
        StillActivityCoordinator.shared.finish()
    }

    private func updateTimer() {
        guard timerEndDate != nil else { return }
        if timerRemaining <= 0 {
            recordSession(duration: defaults.double(forKey: "timerDuration"))
            cancelTimer()
        }
    }

    private func fireAlarm() {
        alarmTimer = nil
        alarmDate = nil
        persistState()
        stopFocus()
        guard defaults.bool(forKey: "soundEnabled") else { return }
        if defaults.bool(forKey: "vibrationEnabled") {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        isAlarmPlaying = true
        do {
            try audioSession.setActive(true, options: [])
            let engine = AVAudioEngine()
            let sampleRate = audioSession.sampleRate > 0 ? audioSession.sampleRate : 44_100
            var phase = 0.0
            let source = AVAudioSourceNode { _, _, frameCount, audioBufferList in
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let increment = 2.0 * Double.pi * 880 / sampleRate
                for frame in 0..<Int(frameCount) {
                    let sample = Float(sin(phase) * 0.18)
                    phase += increment
                    for buffer in buffers {
                        buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample
                    }
                }
                return noErr
            }
            let format = engine.mainMixerNode.outputFormat(forBus: 0)
            engine.attach(source)
            engine.connect(source, to: engine.mainMixerNode, format: format)
            try engine.start()
            audioEngine = engine
            alarmStopTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.stopAlarm() }
            }
        } catch {
            stopAlarm()
        }
    }

    private func stopAlarm() {
        alarmStopTask?.cancel()
        alarmStopTask = nil
        audioEngine?.stop()
        audioEngine = nil
        isAlarmPlaying = false
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func configureAudioSession() {
        do {
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.allowBluetoothHFP, .allowBluetoothA2DP, .mixWithOthers]
            )
        } catch {
            print("Still audio session could not be configured: \(error.localizedDescription)")
        }
    }

    private func restoreState() {
        if let timestamp = defaults.object(forKey: "timerEndDate") as? Double {
            let endDate = Date(timeIntervalSince1970: timestamp)
            timerEndDate = endDate
            timerIsPaused = defaults.bool(forKey: "timerIsPaused")
            pausedRemaining = defaults.object(forKey: "timerPausedRemaining") as? Double

            if timerIsPaused {
                if pausedRemaining ?? 0 > 0 {
                    startFocus()
                } else {
                    cancelTimer()
                }
            } else if endDate > Date() {
                startFocus()
                timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.updateTimer() }
                }
                scheduleNotification(
                    identifier: timerNotificationID,
                    title: "Timer beendet",
                    body: "Deine Still-Session ist abgeschlossen.",
                    date: endDate
                )
            } else {
                cancelTimer()
            }
        }

        if let timestamp = defaults.object(forKey: "alarmDate") as? Double {
            let date = Date(timeIntervalSince1970: timestamp)
            if date > Date() {
                alarmDate = date
                startFocus()
                alarmTimer = Timer.scheduledTimer(withTimeInterval: date.timeIntervalSinceNow, repeats: false) { [weak self] _ in
                    Task { @MainActor in self?.fireAlarm() }
                }
                scheduleNotification(
                    identifier: alarmNotificationID,
                    title: "Still-Wecker",
                    body: "Dein Wecker ist fällig.",
                    date: date
                )
            } else {
                defaults.removeObject(forKey: "alarmDate")
            }
        }
    }

    private func persistState() {
        if let timerEndDate {
            defaults.set(timerEndDate.timeIntervalSince1970, forKey: "timerEndDate")
        } else {
            defaults.removeObject(forKey: "timerEndDate")
        }
        defaults.set(timerIsPaused, forKey: "timerIsPaused")
        if let pausedRemaining {
            defaults.set(pausedRemaining, forKey: "timerPausedRemaining")
        } else {
            defaults.removeObject(forKey: "timerPausedRemaining")
        }
        if let alarmDate {
            defaults.set(alarmDate.timeIntervalSince1970, forKey: "alarmDate")
        } else {
            defaults.removeObject(forKey: "alarmDate")
        }
    }

    private func requestNotificationPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            center.setNotificationCategories([
                UNNotificationCategory(
                    identifier: "STILL_TIMER",
                    actions: [
                        UNNotificationAction(identifier: "STILL_RESUME", title: "Fortsetzen"),
                        UNNotificationAction(identifier: "STILL_CANCEL", title: "Beenden", options: [.destructive])
                    ],
                    intentIdentifiers: []
                ),
                UNNotificationCategory(
                    identifier: "STILL_ALARM",
                    actions: [UNNotificationAction(identifier: "STILL_CANCEL", title: "Beenden", options: [.destructive])],
                    intentIdentifiers: []
                )
            ])
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    private func scheduleNotification(identifier: String, title: String, body: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = defaults.bool(forKey: "soundEnabled") ? .default : nil
        content.categoryIdentifier = identifier == alarmNotificationID ? "STILL_ALARM" : "STILL_TIMER"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(request)
    }

    private func removeNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private func recordSession(duration: TimeInterval) {
        let completedDuration = max(0, duration)
        guard completedDuration > 0 else { return }
        var history = defaults.array(forKey: historyKey) as? [[String: Any]] ?? []
        history.append(["date": Date().timeIntervalSince1970, "duration": completedDuration])
        defaults.set(Array(history.suffix(50)), forKey: historyKey)
    }

    @objc private func handleRouteChange() {
        guard isPlaying, audioEngine?.isRunning == false else { return }
        startFocus()
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard isPlaying,
              let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue),
              type == .ended else { return }
        startFocus()
    }
}