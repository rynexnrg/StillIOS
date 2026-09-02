import AVFoundation
import Combine
import Foundation

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

    init() {
        configureAudioSession()
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
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateTimer() }
        }
        StillActivityCoordinator.shared.showTimer(endDate: timerEndDate!, isPaused: false)
    }

    func pauseTimer() {
        guard let timerEndDate else { return }
        timer?.invalidate()
        timer = nil
        pausedRemaining = max(0, timerEndDate.timeIntervalSinceNow)
        timerIsPaused = true
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
        StillActivityCoordinator.shared.updateTimer(endDate: timerEndDate!, isPaused: false)
    }

    func cancelTimer() {
        timer?.invalidate()
        timer = nil
        timerEndDate = nil
        pausedRemaining = nil
        timerIsPaused = false
        if !isAlarmPlaying { stopFocus() }
        StillActivityCoordinator.shared.finish()
    }

    func scheduleAlarm(at date: Date) {
        alarmTimer?.invalidate()
        alarmDate = date
        startFocus()
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
        if !isAlarmPlaying && timerEndDate == nil { stopFocus() }
        StillActivityCoordinator.shared.finish()
    }

    private func updateTimer() {
        guard timerEndDate != nil else { return }
        if timerRemaining <= 0 {
            cancelTimer()
        }
    }

    private func fireAlarm() {
        alarmTimer = nil
        alarmDate = nil
        stopFocus()
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
                options: [.allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]
            )
        } catch {
            print("Still audio session could not be configured: \(error.localizedDescription)")
        }
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