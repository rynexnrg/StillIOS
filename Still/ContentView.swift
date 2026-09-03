import SwiftUI

struct ContentView: View {
    @StateObject private var audio = AudioManager()
    @State private var selectedTab = 0
    @State private var showingSettings = false
    private let appGroup = UserDefaults(suiteName: "group.com.johannes.still")
    @AppStorage("timerMinutes", store: UserDefaults(suiteName: "group.com.johannes.still")) private var timerMinutes = 5.0
    @AppStorage("alarmTime", store: UserDefaults(suiteName: "group.com.johannes.still")) private var alarmTime = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
    @AppStorage("soundEnabled", store: UserDefaults(suiteName: "group.com.johannes.still")) private var soundEnabled = true
    @AppStorage("vibrationEnabled", store: UserDefaults(suiteName: "group.com.johannes.still")) private var vibrationEnabled = true

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.05, blue: 0.08), Color(red: 0.12, green: 0.16, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("S T I L L").font(.system(size: 21, weight: .light, design: .monospaced)).foregroundStyle(.white.opacity(0.82))
                    Spacer()
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape").font(.system(size: 17, weight: .medium)).foregroundStyle(.white.opacity(0.82))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 18)
                modePicker.padding(.top, 28)
                Spacer(minLength: 28)
                Group { switch selectedTab { case 1: timerView; case 2: alarmView; default: focusView } }
                    .frame(maxWidth: 520)
                Spacer(minLength: 28)
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
        VStack(spacing: 34) {
            statusLabel(audio.isPlaying ? "Fokus aktiv" : "Bereit")
            Button { withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { audio.toggleFocus() } } label: {
                ZStack {
                    Circle().fill(.ultraThinMaterial).frame(width: 220, height: 220)
                        .overlay(Circle().fill(audio.isPlaying ? .cyan.opacity(0.32) : .white.opacity(0.1)))
                        .overlay(Circle().stroke(.white.opacity(0.48), lineWidth: 1))
                        .shadow(color: audio.isPlaying ? .cyan.opacity(0.42) : .black.opacity(0.3), radius: 28, y: 12)
                    Image(systemName: audio.isPlaying ? "pause.fill" : "waveform").font(.system(size: 30, weight: .light)).foregroundStyle(.white)
                }
            }.buttonStyle(.plain)
            Text(audio.isPlaying ? "Deaktivieren" : "Aktivieren").font(.system(size: 17, weight: .light, design: .rounded)).foregroundStyle(.white.opacity(0.72))
        }
    }

    private var timerView: some View {
        VStack(spacing: 28) {
            statusLabel(audio.timerEndDate == nil ? "Timer" : (audio.timerIsPaused ? "Pausiert" : "Läuft"))
            Text(timeString(audio.timerRemaining > 0 ? audio.timerRemaining : timerMinutes * 60))
                .font(.system(size: 58, weight: .ultraLight, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                .contentTransition(.numericText())
            if audio.timerEndDate == nil {
                Slider(value: $timerMinutes, in: 0.5...120, step: 0.5).tint(.cyan)
                HStack {
                    ForEach([0.5, 5.0, 30.0, 120.0], id: \.self) { value in
                        Button(value < 1 ? "30 s" : value == 120 ? "2 h" : "\(Int(value)) min") { timerMinutes = value }
                            .font(.caption).foregroundStyle(.white.opacity(0.72))
                    }
                }
            }
            HStack(spacing: 12) {
                if audio.timerEndDate == nil {
                    actionButton("Start", systemImage: "play.fill") { audio.startTimer(duration: timerMinutes * 60) }
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
            if let alarmDate = audio.alarmDate {
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
