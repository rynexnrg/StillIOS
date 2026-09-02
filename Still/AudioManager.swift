import Foundation
import AVFoundation
import MediaPlayer

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    @Published var isFocusActive: Bool = false
    @Published var remainingTimerTime: TimeInterval = 0
    @Published var isTimerRunning: Bool = false
    @Published var alarmTime: Date? = nil
    
    private var audioPlayer: AVAudioPlayer?
    private var alarmPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var alarmCheckTimer: Timer?
    
    init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            // Ermöglicht die Wiedergabe im Hintergrund und die Ausgabe an Bluetooth-Geräte (.allowBluetoothHFP ersetzt .allowBluetooth)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetoothHFP, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioSession Fehler: \(error)")
        }
    }
    
    // Generiert ein digitales, unhörbares Signal (nahezu stumm)
    private func createSilentAudioPlayer() -> AVAudioPlayer? {
        let sampleRate = 44100.0
        let duration = 5.0
        let numSamples = Int(sampleRate * duration)
        
        var samples = [Float](repeating: 0.0, count: numSamples)
        // Sehr geringe Amplitude, um für Menschen unhörbar zu bleiben, aber den Datenstrom aktiv zu halten
        for i in 0..<numSamples {
            samples[i] = Float.random(in: -0.00001...0.00001)
        }
        
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(numSamples)
        
        let channels = buffer.floatChannelData![0]
        for i in 0..<numSamples {
            channels[i] = samples[i]
        }
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: true
        ]
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("silent.wav")
        
        do {
            let audioFile = try AVAudioFile(forWriting: tempURL, settings: settings)
            try audioFile.write(from: buffer)
            let player = try AVAudioPlayer(contentsOf: tempURL)
            player.numberOfLoops = -1 // Endlosschleife
            return player
        } catch {
            print("Fehler beim Erstellen des Stumm-Audio-Players: \(error)")
            return nil
        }
    }
    
    // MARK: - Fokus-Modus
    func startFocus() {
        stopAll()
        audioPlayer = createSilentAudioPlayer()
        audioPlayer?.play()
        isFocusActive = true
    }
    
    func stopFocus() {
        audioPlayer?.stop()
        isFocusActive = false
    }
    
    // MARK: - Timer
    func startTimer(duration: TimeInterval) {
        stopAll()
        remainingTimerTime = duration
        isTimerRunning = true
        
        audioPlayer = createSilentAudioPlayer()
        audioPlayer?.play()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.remainingTimerTime > 1 {
                self.remainingTimerTime -= 1
            } else {
                self.stopTimer()
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        audioPlayer?.stop()
        isTimerRunning = false
        remainingTimerTime = 0
    }
    
    // MARK: - Wecker
    func setAlarm(targetTime: Date) {
        stopAll()
        alarmTime = targetTime
        
        audioPlayer = createSilentAudioPlayer()
        audioPlayer?.play()
        
        alarmCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let target = self.alarmTime else { return }
            if Date() >= target {
                self.triggerAlarm()
            }
        }
    }
    
    private func triggerAlarm() {
        alarmCheckTimer?.invalidate()
        alarmCheckTimer = nil
        audioPlayer?.stop()
        
        // Hier den Weckton über das Bluetooth-Gerät abspielen
        playAlarmSound()
    }
    
    private func playAlarmSound() {
        guard let url = Bundle.main.url(forResource: "alarm", withExtension: "mp3") else { return }
        do {
            alarmPlayer = try AVAudioPlayer(contentsOf: url)
            alarmPlayer?.play()
        } catch {
            print("Fehler beim Weckton: \(error)")
        }
    }
    
    func cancelAlarm() {
        alarmCheckTimer?.invalidate()
        alarmCheckTimer = nil
        audioPlayer?.stop()
        alarmPlayer?.stop()
        alarmTime = nil
    }
    
    func stopAll() {
        stopFocus()
        stopTimer()
        cancelAlarm()
    }
}