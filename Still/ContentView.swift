import SwiftUI

private struct AlarmSound {
    let id: String
    let name: String
}

struct ContentView: View {
    @StateObject private var audio = AudioManager()
    @State private var selectedTab = 0
    @State private var showingSettings = false
    private let appGroup = UserDefaults(suiteName: "group.com.johannes.still")
    @AppStorage("timerMinutes", store: UserDefaults(suiteName: "group.com.johannes.still")) private var timerMinutes = 5.0
    @AppStorage("alarmTime", store: UserDefaults(suiteName: "group.com.johannes.still")) private var alarmTime = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
    @AppStorage("soundEnabled", store: UserDefaults(suiteName: "group.com.johannes.still")) private var soundEnabled = true
    @AppStorage("vibrationEnabled", store: UserDefaults(suiteName: "group.com.johannes.still")) private var vibrationEnabled = true
    @AppStorage("alarmSound", store: UserDefaults(suiteName: "group.com.johannes.still")) private var alarmSound = "ios-26"
    @State private var timerHours = 0
    @State private var timerWheelMinutes = 5
    @State private var timerSeconds = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.05, blue: 0.08), Color(red: 0.12, green: 0.16, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text("Still").font(.system(size: 25, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.9))
                    Spacer()
                }
                .padding(.top, 18)
                .padding(.horizontal, 8)
                Spacer(minLength: 22)
                Group { switch selectedTab { case 1: timerView; case 2: alarmView; default: focusView } }
                    .frame(maxWidth: 520)
                Spacer(minLength: 18)
                modePicker
                    .padding(.horizontal, 2)
                    .padding(.bottom, 4)
            }
            .padding(.horizontal, 22)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingSettings) { settingsView }
    }

    private var modePicker: some View {
        HStack(spacing: 2) {
            modeButton("Fokus", tag: 0)
            modeButton("Timer", tag: 1)
            modeButton("Wecker", tag: 2)
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 42, height: 38)
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5))
    }

    private func modeButton(_ title: String, tag: Int) -> some View {
        Button(title) { withAnimation(.easeInOut(duration: 0.25)) { selectedTab = tag } }
            .font(.system(size: 14, weight: selectedTab == tag ? .medium : .regular))
            .foregroundStyle(selectedTab == tag ? .black : .white.opacity(0.8))
            .frame(maxWidth: .infinity).padding(.vertical, 11)
            .background(selectedTab == tag ? Color.white : .clear, in: Capsule())
    }

    private var focusView: some View {
        VStack(spacing: 24) {
            statusLabel(audio.isPlaying ? "Fokus aktiv" : "Bereit")
            Button { withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { audio.toggleFocus() } } label: {
                ZStack {
                    Circle().stroke(.white.opacity(0.08), lineWidth: 1).frame(width: 238, height: 238)
                    Circle().stroke(audio.isPlaying ? .cyan.opacity(0.55) : .white.opacity(0.18), lineWidth: 2).frame(width: 216, height: 216)
                    Circle().fill(.ultraThinMaterial).frame(width: 190, height: 190)
                        .overlay(Circle().fill(audio.isPlaying ? .cyan.opacity(0.26) : .white.opacity(0.08)))
                        .overlay(Circle().stroke(LinearGradient(colors: [.white.opacity(0.65), .cyan.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                        .shadow(color: audio.isPlaying ? .cyan.opacity(0.5) : .black.opacity(0.35), radius: 30, y: 14)
                    VStack(spacing: 10) {
                        Image(systemName: audio.isPlaying ? "pause.fill" : "waveform")
                            .font(.system(size: 28, weight: .medium))
                        Text(audio.isPlaying ? elapsedString(audio.focusElapsed) : "START")
                            .font(.system(size: audio.isPlaying ? 17 : 10, weight: .medium, design: .monospaced)).tracking(audio.isPlaying ? 1 : 2)
                    }.foregroundStyle(.white)
                }
            }.buttonStyle(.plain)
            Text(audio.isPlaying ? "Deaktivieren" : "Aktivieren").font(.system(size: 17, weight: .light, design: .rounded)).foregroundStyle(.white.opacity(0.72))
        }
    }

    private var timerView: some View {
        VStack(spacing: 28) {
            statusLabel(audio.timerEndDate == nil ? "Timer" : (audio.timerIsPaused ? "Pausiert" : "Läuft"))
            Text(timerDisplay)
                .font(.system(size: 58, weight: .ultraLight, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                .contentTransition(.numericText())
            if audio.timerEndDate == nil {
                HStack(spacing: 0) {
                    timerWheel(title: "Std.", value: $timerHours, range: 0...99)
                    Text(":").font(.title2).foregroundStyle(.secondary)
                    timerWheel(title: "Min.", value: $timerWheelMinutes, range: 0...99)
                    Text(":").font(.title2).foregroundStyle(.secondary)
                    timerWheel(title: "Sek.", value: $timerSeconds, range: 0...99)
                }.frame(height: 120).clipped()
                HStack {
                    presetButton("30 s", hours: 0, minutes: 0, seconds: 30)
                    presetButton("5 min", hours: 0, minutes: 5, seconds: 0)
                    presetButton("30 min", hours: 0, minutes: 30, seconds: 0)
                    presetButton("2 h", hours: 2, minutes: 0, seconds: 0)
                }
            }
            HStack(spacing: 12) {
                if audio.timerEndDate == nil {
                    actionButton("Start", systemImage: "play.fill") { audio.startTimer(duration: selectedTimerDuration) }
                } else {
                    actionButton(audio.timerIsPaused ? "Fortsetzen" : "Pause", systemImage: audio.timerIsPaused ? "play.fill" : "pause.fill") { audio.timerIsPaused ? audio.resumeTimer() : audio.pauseTimer() }
                    actionButton("Abbrechen", systemImage: "xmark") { audio.cancelTimer() }
                }
            }
        }
    }

    private var alarmView: some View {
        VStack(spacing: 30) {
            statusLabel(audio.alarmDate == nil ? "Wecker" : "Wecker aktiv")
            DatePicker("Zeit", selection: $alarmTime, displayedComponents: .hourAndMinute).datePickerStyle(.wheel).labelsHidden().frame(height: 150).clipped()
            if audio.isAlarmPlaying {
                statusLabel("Wecker klingelt")
                actionButton("Wecker stoppen", systemImage: "bell.slash.fill") { audio.stopAlarm() }
            } else if let alarmDate = audio.alarmDate {
                Text(alarmDate, style: .time).font(.system(size: 17, weight: .light, design: .rounded)).foregroundStyle(.white.opacity(0.72))
                actionButton("Abbrechen", systemImage: "xmark") { audio.cancelAlarm() }
            } else {
                actionButton("Wecker stellen", systemImage: "bell.fill") { audio.scheduleAlarm(at: nextOccurrence(for: alarmTime)) }
            }
        }
    }

    private var settingsView: some View {
        NavigationStack {
            Form {
                Section("Benachrichtigungen") {
                    Toggle("Ton", isOn: $soundEnabled)
                    Toggle("Vibration", isOn: $vibrationEnabled)
                }
                Section("Weckton") {
                    Picker("Ton auswählen", selection: $alarmSound) {
                        ForEach(alarmSounds, id: \.id) { sound in Text(sound.name).tag(sound.id) }
                    }
                }
                Section("Standard-Timer") {
                    Stepper(value: $timerMinutes, in: 0.5...120, step: 0.5) {
                        Text(timerMinutes < 1 ? "30 Sekunden" : "\(timerMinutes, specifier: "%g") Minuten")
                    }
                }
                Section("Sessions") {
                    LabeledContent("Abgeschlossen", value: "\(completedSessions)")
                    LabeledContent("Gesamt", value: formattedTotalDuration)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }

    private var sessionHistory: [[String: Any]] {
        (appGroup?.array(forKey: "focusSessionHistory") as? [[String: Any]]) ?? []
    }

    private var timerDisplay: String {
        _ = audio.timerTick
        return timeString(audio.timerRemaining > 0 ? audio.timerRemaining : timerMinutes * 60)
    }

    private var selectedTimerDuration: TimeInterval { max(1, TimeInterval(timerHours * 3600 + timerWheelMinutes * 60 + timerSeconds)) }
    private let alarmSounds = [AlarmSound(id: "ios-26", name: "IOS Wecker"), AlarmSound(id: "Morning-Coffee", name: "Morning Coffee"), AlarmSound(id: "hava-nagila-1-hours-0", name: "Hava Nagila"), AlarmSound(id: "SpongeBob-Schwammkopf", name: "SpongBob"), AlarmSound(id: "Pacman", name: "Pacman"), AlarmSound(id: "Monte-Wecker", name: "Wecker"), AlarmSound(id: "michael-jackson-billie-jean", name: "Micael Jackson"), AlarmSound(id: "2017-youtube-background-music-low-quality", name: "High Quality Backround Music")]

    private func timerWheel(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View { VStack(spacing: 0) { Picker(title, selection: value) { ForEach(range, id: \.self) { Text(String(format: "%02d", $0)).tag($0) } }.pickerStyle(.wheel).labelsHidden(); Text(title).font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth: .infinity) }
    private func presetButton(_ title: String, hours: Int, minutes: Int, seconds: Int) -> some View { Button(title) { timerHours = hours; timerWheelMinutes = minutes; timerSeconds = seconds }.font(.caption.weight(.semibold)).foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 8).background(.white.opacity(0.1), in: Capsule()).overlay(Capsule().stroke(.white.opacity(0.2))) }
    private func elapsedString(_ seconds: TimeInterval) -> String { let total = max(0, Int(seconds)); return String(format: "%02d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60) }

    private var completedSessions: Int { sessionHistory.count }

    private var formattedTotalDuration: String {
        let total = sessionHistory.reduce(0.0) { result, session in
            result + (session["duration"] as? Double ?? 0)
        }
        let minutes = Int(total / 60)
        return minutes < 60 ? "\(minutes) Min." : "\(minutes / 60) Std. \(minutes % 60) Min."
    }

    private func statusLabel(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 12, weight: .medium, design: .monospaced)).tracking(1.5).foregroundStyle(.white.opacity(0.6))
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage).font(.system(size: 15, weight: .medium)).foregroundStyle(.black)
                .padding(.horizontal, 20).padding(.vertical, 13).background(.white, in: Capsule())
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60)
    }

    private func nextOccurrence(for date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute], from: date)
        components.second = 0
        var result = calendar.date(from: components) ?? date
        if result <= Date() { result = calendar.date(byAdding: .day, value: 1, to: result) ?? result }
        return result
    }
}

